import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'auth/odoo_api.dart';
import 'auth/microsoft_oauth.dart';
import 'auth/dashboard_parser.dart';
import 'auth/portal_api.dart';
import 'auth/session_manager.dart';
import 'auth/session_monitor.dart';
import 'auth/session_store.dart';
import 'data/seed.dart';
import 'screens/auth_home.dart';
import 'screens/community.dart';
import 'screens/fee_board.dart';
import 'screens/gpa_timetable.dart';
import 'screens/groups_chat.dart';
import 'screens/materials_web.dart';
import 'screens/oauth_webview.dart';
import 'screens/profile.dart';
import 'screens/silent_renew_webview.dart';
import 'theme/palette.dart';
import 'widgets/common.dart';

class CampusApp extends StatefulWidget {
  /// Test-only shortcut: when true, the app starts logged in with a mock
  /// session so widget tests can exercise post-login screens without
  /// performing the interactive Microsoft sign-in (which needs a real
  /// browser, real credentials and network).
  final bool skipLogin;
  const CampusApp({super.key, this.skipLogin = false});
  @override
  State<CampusApp> createState() => _CampusAppState();
}

class _CampusAppState extends State<CampusApp> with WidgetsBindingObserver {
  bool authed = false;
  String? sessionId;
  String? sessionEmail;
  String? oauthEmail;
  String? authError;
  String tab = 'home';
  Course? course;
  Course boardOf = courses[0];
  ProfilePrefs prefs = ProfilePrefs();
  bool picker = false;
  bool menu = false;
  GroupInfo? chat;

  /// Active background renewal: mounting [SilentRenewWebView] for this email.
  /// Null when no renewal is running.
  String? _silentEmail;
  int _silentRunId = 0;
  Completer<String?>? _silentCompleter;
  /// Microsoft error / 'timeout' / 'no_session' from the last silent run.
  String? _silentFailCode;

  /// Live portal data for the current session. Null = not loaded yet (or
  /// load failed); Home falls back to bundled sample content meanwhile.
  DashboardData? dashboard;
  int _dashRun = 0;

  /// Foreground liveness watchdog. Never started in `skipLogin` test mode
  /// (real timers + real network would hang widget tests).
  SessionMonitor? _monitor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.skipLogin) {
      authed = true;
      sessionId = 'test-session';
      sessionEmail = 'tester@ucp.edu.pk';
    } else {
      _restoreSession();
    }
  }

  @override
  void dispose() {
    _monitor?.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Timers freeze while backgrounded, so: stop the heartbeat off-screen,
    // and on return restart it plus run one immediate liveness pass. That
    // immediate pass is the "reopen after close" check (cold starts go
    // through _restoreSession instead).
    if (widget.skipLogin) return;
    if (state == AppLifecycleState.resumed) {
      if (authed) {
        _monitor?.start();
        _monitor?.checkNow();
      }
    } else {
      _monitor?.stop();
    }
  }

  /// Resume a previously stored portal session: fresh sessions are validated
  /// directly, stale ones are silently renewed first — this is the auto-login.
  /// If silent renewal reports the Microsoft session dead, the login screen
  /// explains that a fresh sign-in is needed (roughly monthly).
  Future<void> _restoreSession() async {
    final store = SessionStore();
    if (await store.load() == null) return; // first launch ever: no message
    final manager = SessionManager(store: store, api: OdooApi());
    try {
      final valid = await manager.ensureValidSession(renew: _renewViaWebView);
      if (!mounted) return;
      setState(() {
        sessionId = valid.sessionId;
        sessionEmail = valid.email;
        authed = true;
      });
      _startMonitor();
      _loadDashboard();
    } on AuthRequired {
      await store.clear();
      if (!mounted) return;
      setState(() {
        authError = MicrosoftOAuth.renewFailureMessage(
          _silentFailCode ?? 'login_required',
        );
      });
    } catch (_) {
      // Offline etc: stay on the login screen; user retries by opening app.
    }
  }

  /// Pulls `/student/dashboard` with the live session and parses it for
  /// Home. Never throws: on any failure the previous data (or the bundled
  /// sample content) stays on screen. Stale runs are discarded.
  Future<void> _loadDashboard() async {
    final sid = sessionId;
    if (sid == null || !mounted) return;
    final run = ++_dashRun;
    try {
      final html = await PortalApi().fetchDashboard(sid);
      if (!mounted || run != _dashRun) return;
      final parsed = parseDashboard(html);
      setState(() => dashboard = parsed.isEmpty ? null : parsed);
    } catch (_) {
      // Keep previous data / sample fallback; next login or resume retries.
    }
  }
  /// Builds (or rebuilds) the foreground watchdog. Called whenever the app
  /// becomes authenticated; stopped on logout/dispose.
  void _startMonitor() {
    _monitor?.stop();
    if (widget.skipLogin) return;
    final monitor = SessionMonitor(
      readSession: () async {
        final saved = await SessionStore().load();
        if (saved == null) return null;
        return MonitorSnapshot(saved.sessionId, saved.email);
      },
      validate: (sid) => OdooApi().isSessionValid(sid),
      renew: (email) async {
        final sid = await _renewViaWebView(email);
        if (sid != null && sid.isNotEmpty) {
          return RenewOutcome(sessionId: sid);
        }
        return RenewOutcome(failCode: _silentFailCode ?? 'timeout');
      },
      onRenewed: (sid, email) async {
        await SessionStore().save(sessionId: sid, email: email);
        if (!mounted) return;
        setState(() {
          sessionId = sid;
          sessionEmail = email;
        });
        _loadDashboard();
      },
      onDead: (message) => _logout(message: message),
    );
    _monitor = monitor;
    monitor.start();
  }

  /// Mounts the hidden `prompt=none` WebView and resolves with the renewed
  /// `session_id`, or null when the user must sign in interactively.
  Future<String?> _renewViaWebView(String email) {
    final completer = Completer<String?>();
    if (!mounted) return Future.value(null);
    _silentCompleter = completer;
    setState(() {
      _silentEmail = email;
      _silentRunId++;
    });
    return completer.future;
  }

  void _finishSilentRenew(String? sessionId, {String? failCode}) {
    if (failCode != null) _silentFailCode = failCode;
    final completer = _silentCompleter;
    _silentCompleter = null;
    if (mounted) setState(() => _silentEmail = null); // unmounts WebView
    if (completer != null && !completer.isCompleted) {
      completer.complete(sessionId);
    }
  }

  void go(String t) => setState(() { tab = t; course = null; picker = false; menu = false; chat = null; });

  Future<void> _logout({String? message}) async {
    _monitor?.stop();
    _finishSilentRenew(null); // abort any background renewal
    await SessionStore().clear();
    try {
      await WebViewCookieManager().clearCookies();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      authed = false;
      sessionId = null;
      sessionEmail = null;
      oauthEmail = null;
      authError = message;
      dashboard = null;
      tab = 'home';
      menu = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final dark = prefs.theme == ThemeModePref.dark || (prefs.theme == ThemeModePref.system && brightness == Brightness.dark);
    final colors = AppColors.of(prefs.palette, dark);

    Widget screen;
    if (chat != null) {
      screen = GroupChatScreen(group: chat!, back: () => setState(() => chat = null));
    } else if (course != null) {
      screen = DetailScreen(course: course!, back: () => setState(() => course = null));
    } else {
      switch (tab) {
        case 'home':
          screen = HomeScreen(onOpen: (c) => setState(() { course = c; }), toProfile: () => go('profile'), onMenu: () => setState(() => menu = true), onGpa: () => go('gpa'), onBoard: (c) { setState(() { boardOf = c; tab = 'board'; }); }, dashboard: dashboard);
          break;
        case 'material':
          screen = const MaterialsScreen();
          break;
        case 'community':
          screen = const CommunityScreen();
          break;
        case 'groups':
          screen = GroupsScreen(onChat: (g) => setState(() => chat = g));
          break;
        case 'gpa':
          screen = const GpaCalcScreen();
          break;
        case 'timetable':
          screen = const TimetableScreen();
          break;
        case 'fee':
          screen = const FeeChallanScreen();
          break;
        case 'board':
          screen = LeaderboardScreen(start: boardOf.code, back: () => go('home'));
          break;
        case 'web':
          screen = const WebViewScreen();
          break;
        default:
          screen = ProfileScreen(logout: _logout, prefs: prefs, onPrefs: (p) => setState(() => prefs = p));
      }
    }

    final bool showNav = authed && chat == null && oauthEmail == null;

    return AppScope(
      colors: colors,
      palette: prefs.palette,
      child: MaterialApp(
        title: 'campus.',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: colors.cream2,
          colorScheme: ColorScheme.fromSeed(seedColor: colors.teal),
          useMaterial3: true,
        ),
        home: Builder(builder: (ctx) {
          final mq = MediaQuery.of(ctx);
          final scaled = prefs.big ? mq.copyWith(textScaler: const TextScaler.linear(1.08)) : mq;
          return MediaQuery(
            data: scaled,
            child: Scaffold(
              backgroundColor: colors.cream2,
              resizeToAvoidBottomInset: true,
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: !authed
                            ? oauthEmail != null
                                ? OAuthWebView(
                                    email: oauthEmail!,
                                    onAuthenticated: (sid) async {
                                      await SessionStore().saveSession(
                                        sessionId: sid,
                                        email: oauthEmail!,
                                      );
                                      if (!mounted) return;
                                      setState(() {
                                        sessionId = sid;
                                        sessionEmail = oauthEmail;
                                        oauthEmail = null;
                                        authError = null;
                                        authed = true;
                                      });
                                      _startMonitor();
                                      _loadDashboard();
                                    },
                                    onCancelled: () => setState(() {
                                      oauthEmail = null;
                                      authError = null;
                                    }),
                                    onError: (msg) => setState(() {
                                      oauthEmail = null;
                                      authError = msg;
                                    }),
                                  )
                                : LoginScreen(
                                    authError: authError,
                                    onMicrosoftSignIn: (email) => setState(
                                      () {
                                        oauthEmail = email;
                                        authError = null;
                                      },
                                    ),
                                  )
                            : SafeArea(top: true, bottom: false, child: screen),
                      ),
                      // Background silent renewal (1x1 px, touch-transparent).
                      if (_silentEmail != null)
                        Positioned(
                          top: 0,
                          left: 0,
                          child: IgnorePointer(
                            child: SilentRenewWebView(
                              key: ValueKey('silent-$_silentRunId'),
                              email: _silentEmail!,
                              onRenewed: (sid) =>
                                  _finishSilentRenew(sid),
                              onInteractionRequired: (code) =>
                                  _finishSilentRenew(null,
                                      failCode: code),
                            ),
                          ),
                        ),
                      if (authed && picker) ...[
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => picker = false),
                            child: Container(color: colors.tealInk.withValues(alpha: 0.4)),
                          ),
                        ),
                        Positioned(
                          left: 16, right: 16, bottom: 16,
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => go('community'),
                                  child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: colors.teal, borderRadius: BorderRadius.circular(24)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.forum_outlined, color: Colors.white), SizedBox(height: 24), Text('Community', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)), Text('Campus feed & posts', style: TextStyle(color: Colors.white70, fontSize: 12))])),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => go('groups'),
                                  child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: colors.clay, borderRadius: BorderRadius.circular(24)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.group_outlined, color: Colors.white), SizedBox(height: 24), Text('Groups', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)), Text('Study circles & clubs', style: TextStyle(color: Colors.white70, fontSize: 12))])),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (authed && menu) ...[
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => menu = false),
                            child: Container(color: colors.tealInk.withValues(alpha: 0.4)),
                          ),
                        ),
                        Positioned(
                          top: 0, bottom: 0, left: 0,
                          width: MediaQuery.of(ctx).size.width * 0.82 > 353 ? 353 : MediaQuery.of(ctx).size.width * 0.82,
                          child: Container(
                            decoration: BoxDecoration(color: colors.cream2, borderRadius: const BorderRadius.horizontal(right: Radius.circular(32))),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [colors.tealDeep, colors.teal]),
                                    borderRadius: const BorderRadius.only(topRight: Radius.circular(32)),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(radius: 28, backgroundImage: AssetImage(prefs.palette.heroAsset)),
                                      const SizedBox(width: 12),
                                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Ayaan Warraich', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)), Text('BS Computer Science · Year 2', style: TextStyle(color: Colors.white70, fontSize: 12))])),
                                      GestureDetector(onTap: () => setState(() => menu = false), child: Container(alignment: Alignment.center, width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white))),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView(
                                    padding: const EdgeInsets.all(12),
                                    children: [
                                      for (final it in [['home', 'Home', Icons.home_outlined], ['timetable', 'Timetable', Icons.calendar_month_outlined], ['material', 'Course material', Icons.book_outlined], ['gpa', 'GPA calculator', Icons.calculate_outlined], ['fee', 'Fee challan', Icons.receipt_outlined], ['community', 'Community', Icons.forum_outlined], ['groups', 'Groups & chats', Icons.group_outlined], ['web', 'Web view', Icons.language_outlined], ['profile', 'Profile & settings', Icons.person_outline]])
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => go(it[0] as String),
                                          child: Container(
                                            margin: const EdgeInsets.only(bottom: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            decoration: BoxDecoration(color: tab == it[0] && course == null ? colors.teal : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                                            child: Row(
                                              children: [
                                                Container(alignment: Alignment.center, width: 36, height: 36, decoration: BoxDecoration(color: tab == it[0] && course == null ? Colors.white.withValues(alpha: 0.2) : colors.dustSoft, borderRadius: BorderRadius.circular(12)), child: Icon(it[2] as IconData, size: 18, color: tab == it[0] && course == null ? Colors.white : colors.tealInk)),
                                                const SizedBox(width: 12),
                                                Expanded(child: Text(it[1] as String, style: TextStyle(fontWeight: FontWeight.w600, color: tab == it[0] && course == null ? Colors.white : colors.tealInk))),
                                                Icon(Icons.chevron_right, size: 17, color: (tab == it[0] && course == null ? Colors.white : colors.tealInk).withValues(alpha: 0.5)),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() => menu = false);
                                      _logout();
                                    },
                                    child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: colors.dustSoft, borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(Icons.logout, color: colors.clay), Text(' Log out', style: TextStyle(fontWeight: FontWeight.w600, color: colors.clay))])),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              bottomNavigationBar: showNav
                  ? SafeArea(
                      top: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 430),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                                decoration: BoxDecoration(color: colors.white, border: Border(top: BorderSide(color: colors.dustSoft))),
                                child: Row(
                                  children: [
                                    _navItem(ctx, colors, 'material', 'Material', Icons.book_outlined),
                                    _navItem(ctx, colors, 'community', tab == 'groups' ? 'Groups' : 'Community', Icons.group_outlined, isCommunity: true),
                                    Expanded(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => go('home'),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              alignment: Alignment.center,
                                              transform: Matrix4.translationValues(0, -12, 0),
                                              width: 52, height: 52,
                                              decoration: BoxDecoration(color: (tab == 'home' && course == null) ? colors.teal : colors.tealInk, shape: BoxShape.circle, border: Border.all(color: colors.cream2, width: 4), boxShadow: [BoxShadow(color: colors.clay, offset: const Offset(0, 6))]),
                                              child: const Icon(Icons.home_outlined, color: Colors.white, size: 26),
                                            ),
                                            Text('Home', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: (tab == 'home' && course == null) ? colors.tealInk : colors.tealInk.withValues(alpha: 0.55))),
                                          ],
                                        ),
                                      ),
                                    ),
                                    _navItem(ctx, colors, 'web', 'Web', Icons.language_outlined),
                                    _navItem(ctx, colors, 'profile', 'Profile', Icons.person_outline),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : null,
            ),
          );
        }),
      ),
    );
  }

  Widget _navItem(BuildContext ctx, AppColors c, String key, String label, IconData icon, {bool isCommunity = false}) {
    final on = (tab == key || (isCommunity && tab == 'groups')) && course == null && chat == null;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => isCommunity ? setState(() => picker = !picker) : go(key),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              alignment: Alignment.center,
              width: 56, height: 30,
              decoration: BoxDecoration(color: on ? c.teal : Colors.transparent, borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, size: 20, color: on ? Colors.white : c.tealInk.withValues(alpha: 0.55)),
            ),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: on ? c.tealInk : c.tealInk.withValues(alpha: 0.55))),
          ],
        ),
      ),
    );
  }
}
