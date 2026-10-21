import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'auth/odoo_api.dart';
import 'auth/microsoft_oauth.dart';
import 'auth/dashboard_parser.dart';
import 'auth/portal_api.dart';
import 'auth/session_manager.dart';
import 'auth/offline.dart';
import 'auth/page_cache.dart';
import 'auth/portal_cache.dart';
import 'auth/course_cache.dart';
import 'auth/course_detail.dart'
    show courseIdFromUrl, parseCourseGradebook, CourseGradebook;
import 'auth/prefs_store.dart';
import 'auth/session_monitor.dart';
import 'auth/session_store.dart';
import 'auth/student_portal.dart';
import 'community/backend_config.dart';
import 'community/community_service.dart';
import 'community/fake_community_service.dart';
import 'community/node_community_service.dart';
import 'leaderboard/leaderboard_service.dart';
import 'leaderboard/sync.dart';
import 'teachers/teacher_service.dart';
import 'data/seed.dart';
import 'screens/attendance.dart';
import 'screens/auth_home.dart';
import 'screens/community.dart';
import 'screens/course_detail.dart';
import 'screens/fee_board.dart';
import 'screens/leaderboard.dart';
import 'screens/teachers.dart';
import 'screens/gpa_timetable.dart';
import 'gpa_vault/vault_home_screen.dart';
import 'screens/materials_web.dart';
import 'screens/oauth_webview.dart';
import 'screens/profile.dart';
import 'screens/results.dart';
import 'screens/silent_renew_webview.dart';
import 'widgets/offline_banner.dart';
import 'widgets/session_expired_dialog.dart';
import 'theme/palette.dart';
import 'widgets/common.dart';

@visibleForTesting
class FakeValidatingApi extends OdooApi {
  final Future<bool> Function(String sid) fn;
  FakeValidatingApi(this.fn);
  @override
  Future<bool> isSessionValid(String sid) => fn(sid);
}

/// Test-only seams for driving auth flows in widget tests without network
/// or platform WebViews: a fake session store, a fake validator, a fake
/// renewer, and a short monitor interval.
@visibleForTesting
class AuthTestHooks {
  final SessionBackend backend;
  final Future<bool> Function(String sid)? validate;
  final Future<RenewOutcome> Function(String email)? renew;
  final Duration monitorInterval;
  final bool startAuthed;
  const AuthTestHooks({
    required this.backend,
    this.validate,
    this.renew,
    this.monitorInterval = const Duration(milliseconds: 200),
    this.startAuthed = false,
  });
}

class CampusApp extends StatefulWidget {
  /// Test-only shortcut: when true, the app starts logged in with a mock
  /// session so widget tests can exercise post-login screens without
  /// performing the interactive Microsoft sign-in (which needs a real
  /// browser, real credentials and network).
  final bool skipLogin;
  final AuthTestHooks? authHooks;
  /// Theme snapshot read from device storage before the first frame, so
  /// startup paints in the saved theme. Null in tests → light defaults.
  final ProfilePrefs? initialPrefs;
  const CampusApp({super.key, this.skipLogin = false, this.authHooks, this.initialPrefs});
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
  bool courseLive = false;
  /// Live portal course backing the open course hub (null = bundled
  /// sample: fall back to the old static detail screen).
  PortalCourse? portalCourse;
  /// First hub tab to open ('news' unless the bottom-bar Material
  /// directory sent us straight to 'material').
  String _hubInitialTab = 'news';

  /// Subject the leaderboard should preselect (from a course card or
  /// the hub's "Leaderboard" button).
  String? _boardCourse;
  /// Course code of the preselected subject (e.g. "AR221") — disambiguates
  /// lab vs theory when names alone don't.
  String? _boardCourseCode;

  /// Unique course names from the app's own parsed portal timetable —
  /// the leaderboard's course picker fallback.
  List<String> get _portalCourseNames {
    final seen = <String>{};
    final out = <String>[];
    for (final s in timetableSlots) {
      final name = s.subject.trim();
      if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
      out.add(name);
    }
    return out;
  }

  /// Timetable rows in the extension's format (course name carries the
  /// section, exactly like the extension's scraper) so app and extension
  /// produce the SAME class-roster keys on the server.
  /// Timetable slots with the FULL course name restored.
  ///
  /// The portal's schedule grid truncates long course names ("Computer
  /// Organization and Assembly ..") and the truncation also hides the
  /// "- Lab" suffix — the exact thing that separates the lab board from
  /// the theory board. The course list carries the full name and the
  /// course code, and the slot carries the section code, so the two are
  /// joined by code instead of by guessing.
  List<TimetableSlot> _resolveSlots(List<TimetableSlot> slots) {
    final courses = dashboard?.courses ?? const <PortalCourse>[];
    if (courses.isEmpty) return slots;
    final byCode = <String, String>{
      for (final pc in courses)
        if (pc.code.trim().isNotEmpty)
          pc.code.trim().toUpperCase(): pc.name.trim(),
    };
    return [
      for (final s in slots)
        () {
          final short = s.section.split('-').first.trim().toUpperCase();
          final full = byCode[short];
          if (full == null || full.isEmpty || full == s.subject.trim()) {
            return s;
          }
          return TimetableSlot(
            day: s.day,
            start: s.start,
            end: s.end,
            subject: full,
            teacher: s.teacher,
            section: s.section,
            room: s.room,
          );
        }(),
    ];
  }

  /// Course code -> FULL section code for every portal course.
  Map<String, String> get _sectionCodesByCourse {
    final out = <String, String>{};
    for (final pc in dashboard?.courses ?? const <PortalCourse>[]) {
      final full = _resolveSectionCode(pc);
      final key = pc.code.trim().toUpperCase();
      if (key.isEmpty) continue;
      if (full != null && full.isNotEmpty) out[key] = full;
    }
    return out;
  }

  /// FULL section code of a portal course ("AR221" ->
  /// "AR221-F26-BS-CS-F25-C1"). The course card only shows the short
  /// code; the timetable carries the full one. The full code is the only
  /// identity every client agrees on, so it is what we publish with.
  String? _resolveSectionCode(PortalCourse pc) {
    final short = pc.code.trim().toUpperCase();
    if (short.isEmpty) return null;
    final candidates = <String>[];
    for (final s in timetableSlots) {
      final sec = s.section.trim();
      if (sec.isEmpty) continue;
      if (!sec.toUpperCase().startsWith('$short-')) continue;
      if (!candidates.contains(sec)) candidates.add(sec);
    }
    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first;
    // Several sections share the course code — pick the one whose
    // (resolved) subject matches the course name.
    final want = _courseLooseKey(pc.name);
    for (final sec in candidates) {
      final slot = timetableSlots.firstWhere(
        (s) => s.section.trim() == sec,
        orElse: () => const TimetableSlot(
          day: '',
          start: '',
          end: '',
          subject: '',
          teacher: '',
          section: '',
          room: '',
        ),
      );
      if (_courseLooseKey(slot.subject) == want) return sec;
    }
    return candidates.first;
  }

  List<Map<String, String>> get _timetableSyncRows {
    final rows = <Map<String, String>>[];
    for (final s in timetableSlots) {
      final name = s.section.isNotEmpty
          ? '${s.subject.trim()} (${s.section.trim()})'
          : s.subject.trim();
      if (name.isEmpty || s.day.isEmpty || s.start.isEmpty) continue;
      rows.add({
        'day': s.day,
        'time': '${s.start} - ${s.end}',
        'courseName': name,
        'teacher': s.teacher,
        'room': s.room,
      });
    }
    return rows;
  }
  Course boardOf = courses[0];
  ProfilePrefs prefs = ProfilePrefs();
  bool menu = false;

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
  /// Weekly class slots backing Home's real course cards.
  List<TimetableSlot> timetableSlots = const [];
  /// True once this session published the student's timetable + marks to
  /// the community backend (the app-first path).
  bool _communitySynced = false;
  /// Resolves when an interactive Microsoft sign-in started by
  /// [ensurePortalSession] finishes (true = signed in, false = cancelled).
  Completer<bool>? _signInWaiter;

  /// True while the cold-start auto-login attempt is running: the login
  /// screen shows a short "Signing you in…" animation instead of the form.
  /// This only covers the instant local store read — the session itself is
  /// verified in the background AFTER Home paints (see [_backgroundVerify]),
  /// so this never blocks the app.
  bool _restoring = false;

  /// Background sign-in engine: true while the saved session is being
  /// verified/renewed off the critical path. A small non-blocking pill
  /// shows it; the app stays fully usable meanwhile.
  bool _signingIn = false;

  /// Background sign-in failed (session dead, interaction needed): banner
  /// with Try again / Sign in. The saved world stays usable underneath.
  bool _signInFailed = false;
  String? _signInFailMessage;

  /// "Stay logged out": the user dismissed the expiry popup and keeps
  /// using saved data. While set, no renewal is attempted and no cookies
  /// are minted or overwritten. In-memory only — a fresh app launch starts
  /// again at false and retries auto sign-in with the kept session.
  bool _stayWithoutLive = false;

  /// Stale-run guard for overlapping background verify passes.
  int _bgRun = 0;

  /// Community backend, chosen once. Priority: Node API (session-verified
  /// writes) > direct Supabase > seeded fake in widget-test modes >
  /// null (= setup notice) in unconfigured production.
  CommunityService? _community;

  /// Teacher reviews backend (Supabase `teachers` + `teacher_reviews`
  /// via Node API). Same selection policy as community: fake in tests,
  /// Node when configured, null (setup notice) otherwise.
  TeacherService? _teachers;

  /// Foreground liveness watchdog. Never started in `skipLogin` test mode
  /// (real timers + real network would hang widget tests).
  SessionMonitor? _monitor;

  CommunityService? _communityService() {
    // Widget tests always use deterministic seed data (never network),
    // even though production defaults are configured.
    _community ??= ((widget.skipLogin || widget.authHooks != null)
        ? FakeCommunityService()
        : isNodeConfigured
            ? NodeCommunityService(
                baseUrl: nodeApiUrl,
                sessionOf: () => sessionId,
              )
            : null);
    return _community;
  }

  TeacherService? _teacherService() {
    if (widget.skipLogin || widget.authHooks != null) {
      _teachers ??= FakeTeacherService();
      return _teachers;
    }
    if (isNodeConfigured && isSupabaseConfigured) {
      _teachers ??= HybridTeacherService(
        primary: NodeTeacherService(
          baseUrl: nodeApiUrl,
          sessionOf: () => sessionId,
        ),
        fallback: SupabaseTeacherService(
          url: supabaseUrl,
          anonKey: supabaseAnonKey,
        ),
      );
      return _teachers;
    }
    if (isNodeConfigured) {
      _teachers ??= NodeTeacherService(
        baseUrl: nodeApiUrl,
        sessionOf: () => sessionId,
      );
      return _teachers;
    }
    if (isSupabaseConfigured) {
      _teachers ??= SupabaseTeacherService(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      return _teachers;
    }
    return null;
  }

  /// Brief "session refreshed" banner after a silent heal. Auto-dismissed.
  bool _healNotice = false;
  Timer? _healTimer;

  /// Storage + validation seams: test hooks override both in widget tests.
  SessionBackend get _backend => widget.authHooks?.backend ?? SessionStore();

  Future<bool> _validateSession(String sid) {
    final v = widget.authHooks?.validate;
    if (v != null) return v(sid);
    return OdooApi().isSessionValid(sid);
  }

  /// Renewal seam: test hooks resolve without mounting a (platform) WebView.
  Future<RenewOutcome> _performRenew(String email) async {
    // "Stay logged out": never mint cookies until the user explicitly
    // asks (Try again / Login now). The watchdog treats this as a quiet
    // non-interaction failure, so no popup re-fires for the dead session.
    if (_stayWithoutLive) {
      return RenewOutcome(failCode: 'stayed-offline');
    }
    // Offline: never mount the silent WebView or pop anything — the next
    // heartbeat after reconnect retries automatically.
    if (OfflineMonitor.instance.isOffline) {
      return RenewOutcome(failCode: 'timeout');
    }
    final r = widget.authHooks?.renew;
    if (r != null) return r(email);
    final sid = await _renewViaWebView(email);
    if (sid != null && sid.isNotEmpty) return RenewOutcome(sessionId: sid);
    return RenewOutcome(failCode: _silentFailCode ?? 'timeout');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Saved theme applies from the very first frame (preloaded in main).
    if (widget.initialPrefs != null) prefs = widget.initialPrefs!;
    // Platform channels don't exist in widget tests: only probe real
    // connectivity in production runs.
    if (!widget.skipLogin && widget.authHooks == null) {
      OfflineMonitor.instance.start();
    }
    if (widget.skipLogin) {
      authed = true;
      sessionId = 'test-session';
      sessionEmail = 'tester@ucp.edu.pk';
    } else if (widget.authHooks != null && widget.authHooks!.startAuthed) {
      authed = true;
      sessionId = 'hook-session';
      sessionEmail = 'hook@ucp.edu.pk';
      _loadCachedDashboard();
      _loadCachedSlots();
      _startMonitor();
    } else {
      _restoring = true;
      _loadCachedDashboard();
      _loadCachedSlots();
      _restoreSession();
    }
  }

  @override
  void dispose() {
    _healTimer?.cancel();
    _monitor?.stop();
    OfflineMonitor.instance.stop();
    _community?.dispose();
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
        OfflineMonitor.instance.refresh();
        _checkSessionNow();
      }
    } else {
      _monitor?.stop();
    }
  }

  /// Cold start: open the saved world INSTANTLY (no blocking sign-in
  /// animation), then verify/renew the session in the background while the
  /// user already uses the app. First launch ever (no saved session) shows
  /// the login form immediately.
  Future<void> _restoreSession() async {
    final store = _backend;
    // Bounded: a hung keystore must never trap the splash screen.
    final saved = await store
        .load()
        .timeout(const Duration(seconds: 8), onTimeout: () => null);
    if (!mounted) return;
    if (saved == null) {
      setState(() => _restoring = false);
      return; // first launch ever: login form, no animation
    }
    setState(() {
      _restoring = false;
      sessionId = saved.sessionId;
      sessionEmail = saved.email;
      authed = true;
      _expiredForSid = null;
      _expiredMessage = null;
      _expiredCode = null;
      _signInFailed = false;
      _signInFailMessage = null;
    });
    _startMonitor();
    _loadDashboard();
    // Fire-and-forget liveness probe (production only: the channel never
    // resolves in widget tests and would leak a pending timer). The cached
    // flag below + the watchdog cover offline.
    if (widget.authHooks == null) {
      unawaited(OfflineMonitor.instance.refresh());
    }
    if (!mounted || !authed) return;
    // Offline: stay on the cached world; the watchdog retries on reconnect.
    if (OfflineMonitor.instance.isOffline) return;
    unawaited(_backgroundVerify());
  }

  /// The background sign-in engine: proves the opened session is still
  /// alive and silently renews it when stale — all without blocking the UI.
  /// Success is silent (the pill just disappears); failure raises the
  /// retry banner while the app stays usable on cached data.
  Future<void> _backgroundVerify() async {
    final run = ++_bgRun;
    if (!mounted || !authed) return;
    if (OfflineMonitor.instance.isOffline) return;
    final sid = sessionId;
    if (sid == null) return;
    _silentFailCode = null;
    setState(() {
      _signingIn = true;
      _signInFailed = false;
      _signInFailMessage = null;
    });
    try {
      final manager = SessionManager(
        store: _backend,
        api: FakeValidatingApi(_validateSession),
      );
      final valid = await manager.ensureValidSession(
        renew: (email) async {
          final outcome = await _performRenew(email);
          return outcome.sessionId;
        },
      );
      if (!mounted || run != _bgRun || !authed) return;
      final changed = valid.sessionId != sessionId;
      setState(() {
        sessionId = valid.sessionId;
        sessionEmail = valid.email;
        _signingIn = false;
        _signInFailed = false;
        _signInFailMessage = null;
        _expiredForSid = null;
        _expiredMessage = null;
        _expiredCode = null;
      });
      _startMonitor();
      if (changed || dashboard == null) _loadDashboard();
    } on AuthRequired {
      if (!mounted || run != _bgRun || !authed) return;
      // Went offline mid-verify: stay quiet, the watchdog retries.
      if (OfflineMonitor.instance.isOffline) {
        setState(() => _signingIn = false);
        return;
      }
      setState(() {
        _signingIn = false;
        _signInFailed = true;
        _signInFailMessage = MicrosoftOAuth.renewFailureMessage(
          _silentFailCode ?? 'login_required',
        );
      });
    } catch (_) {
      if (!mounted || run != _bgRun || !authed) return;
      if (OfflineMonitor.instance.isOffline) {
        setState(() => _signingIn = false);
        return;
      }
      setState(() {
        _signingIn = false;
        _signInFailed = true;
        _signInFailMessage =
            'Couldn\'t reach the portal — will retry automatically.';
      });
    }
  }

  /// Loads the last dashboard snapshot from the phone so Home paints
  /// instantly, then the live fetch in [_loadDashboard] refreshes it.
  Future<void> _loadCachedDashboard() async {
    try {
      final raw = await _backend
          .loadDashboard()
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      if (raw == null || !mounted) return;
      final parsed = DashboardData.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (!parsed.isEmpty) setState(() => dashboard = parsed);
    } catch (_) {}
  }

  /// Timetable slots from the on-disk snapshot so Home's timeline and
  /// UP NEXT work before (and without) any network. Silent: missing or
  /// corrupt cache simply leaves the sample fallback in place.
  Future<void> _loadCachedSlots() async {
    try {
      final snap = await PageCache.loadPage('timetable');
      if (snap == null || !mounted) return;
      final slots = parseTimetable(snap.html).slots;
      if (slots.isNotEmpty && mounted) {
        setState(() => timetableSlots = _resolveSlots(slots));
      }
    } catch (_) {}
  }

  /// Pulls `/student/dashboard` (+ timetable for course schedules) with
  /// the live session and parses them for Home. Saves a fresh snapshot to
  /// the phone on success. Never throws: on any failure the previous data
  /// (or the bundled sample content) stays on screen. Stale runs discarded.
  Future<void> _loadDashboard() async {
    final sid = sessionId;
    if (sid == null || !mounted) return;
    if (OfflineMonitor.instance.isOffline) return;
    final run = ++_dashRun;
    try {
      final api = PortalApi();
      final results = await Future.wait([
        api.fetchDashboard(sid),
        api.fetchPage(PortalRoutes.timetable, sid).catchError((_) => ''),
      ]);
      if (!mounted || run != _dashRun) return;
      final parsed = parseDashboard(results[0] as String);
      if (parsed.isEmpty) return;
      final slots = (results[1] as String).isEmpty
          ? const <TimetableSlot>[]
          : parseTimetable(results[1] as String).slots;
      setState(() {
        dashboard = parsed;
        timetableSlots = _resolveSlots(slots);
      });
      unawaited(_backend.saveDashboard(jsonEncode(parsed.toJson())));
      unawaited(PageCache.savePage('timetable', results[1] as String));
      // Publish this student's class + marks so classmates (app-only or
      // extension) see them. Background, non-blocking.
      unawaited(_runCommunitySync());
    } catch (_) {
      // Keep previous data / sample fallback; next login or resume retries.
    }
  }
  /// Pull-to-refresh on Home: refetches EVERY portal page backing the app
  /// (dashboard, timetable, datesheet, attendance, invoices, results) in
  /// parallel, parses each, and updates live Home state plus the memory
  /// and on-disk caches — so Home repaints and every other tab opens on
  /// new data. Never throws: failures keep previous data; an expired
  /// session routes to the watchdog (relogin popup). Stale runs discarded.
  Future<void> _refreshAllPortal() async {
    final sid = sessionId;
    if (sid == null || !mounted) return;
    if (OfflineMonitor.instance.isOffline) return;
    final run = ++_dashRun;
    // An explicit refresh re-publishes the student's timetable + marks, so
    // classmates see the latest numbers (the automatic pass stays
    // once-per-session).
    _communitySynced = false;
    try {
      final api = PortalApi();
      final results = await Future.wait([
        api.fetchDashboard(sid),
        api.fetchPage(PortalRoutes.timetable, sid).catchError((_) => ''),
        api.fetchPage(PortalRoutes.attendance, sid).catchError((_) => ''),
        api.fetchPage(PortalRoutes.invoices, sid).catchError((_) => ''),
        api.fetchPage(PortalRoutes.results, sid).catchError((_) => ''),
        api.fetchPage(PortalRoutes.datesheet, sid).catchError((_) => ''),
      ]);
      if (!mounted || run != _dashRun) return;
      final dashHtml = results[0] as String;
      final ttHtml = results[1] as String;
      final attHtml = results[2] as String;
      final invHtml = results[3] as String;
      final resHtml = results[4] as String;
      final dsHtml = results[5] as String;

      final parsed = parseDashboard(dashHtml);
      List<TimetableSlot> slots = timetableSlots;
      if (ttHtml.isNotEmpty) {
        final tt = parseTimetable(ttHtml);
        slots = tt.slots;
        final ds = dsHtml.isNotEmpty
            ? parseDatesheet(dsHtml)
            : PortalCache.datesheet;
        PortalCache.putTimetable(tt, ds ?? const DatesheetData());
        unawaited(PageCache.savePage('timetable', ttHtml));
        unawaited(PageCache.savePage('datesheet', dsHtml));
      }
      if (attHtml.isNotEmpty) {
        PortalCache.putAttendance(parseAttendance(attHtml));
        unawaited(PageCache.savePage('attendance', attHtml));
      }
      if (invHtml.isNotEmpty) {
        PortalCache.putInvoices(parseInvoices(invHtml));
        unawaited(PageCache.savePage('invoices', invHtml));
      }
      if (resHtml.isNotEmpty) {
        PortalCache.putResults(parseResults(resHtml));
        unawaited(PageCache.savePage('results', resHtml));
      }
      if (!parsed.isEmpty) {
        setState(() {
          dashboard = parsed;
          timetableSlots = _resolveSlots(slots);
        });
        unawaited(_backend.saveDashboard(jsonEncode(parsed.toJson())));
      } else if (mounted) {
        setState(() => timetableSlots = _resolveSlots(slots));
      }
    } on OdooApiException catch (e) {
      if (e.message.contains('expired') || e.message.contains('login')) {
        _checkSessionNow();
      }
      // Otherwise keep previous data; spinner dismisses regardless.
    } catch (_) {
      // Keep previous data / sample fallback.
    }
  }
  /// Fetches the portal gradebook for the opened course and publishes it,
  /// so the student's own row is on the leaderboard (app-only users).
  Future<void> _ensureCourseGrades(String courseName) async {
    if (!isExtConfigured) return;
    final sid = (dashboard?.studentId ?? '').trim();
    final dash = dashboard;
    if (sid.isEmpty || dash == null || dash.courses.isEmpty) return;
    // Match the board's label to a portal course. The PORTAL name is the
    // one the grades must be published under: it keeps the "- Lab"
    // suffix, which is the same key the extension used — publishing under
    // the ext label would file lab marks into the theory board.
    final match = _matchPortalCourse(courseName);
    if (match == null) return;
    final courseId = courseIdFromUrl(match.infoUrl) ?? '';
    if (courseId.isEmpty) return;
    var gb = CourseDetailCache.gradebook[courseId];
    if (gb == null || gb.isEmpty) {
      try {
        final html = await PortalApi().fetchPage(
          '/student/course/gradebook/$courseId',
          sid,
        );
        gb = parseCourseGradebook(html);
        CourseDetailCache.putGradebook(courseId, gb);
      } catch (_) {
        return;
      }
    }
    if (gb == null || gb.isEmpty) return;
    await _syncOwnGrades(match, match.name, gb);
  }

  /// The full "class sync" pipeline.
  ///
  /// Runs in the order the student experiences it:
  ///   1. the portal session (Microsoft sign-in) must be alive — the
  ///      session cookie is what reads the portal;
  ///   2. the TIMETABLE is fetched with that cookie and published, so
  ///      the server knows which sections this student is in (this is
  ///      what builds the class roster);
  ///   3. every subject's GRADE PAGE is fetched, parsed and published,
  ///      so the student's marks reach the server;
  ///   4. the caller then loads the class boards.
  ///
  /// App-only users used to stay invisible: the timetable was published
  /// only when a leaderboard was opened, and the marks only for the one
  /// subject whose board was open.
  Future<LeaderboardSyncReport> syncClassToServer({
    void Function(SyncStepUpdate update)? onProgress,
  }) async {
    if (!isExtConfigured) {
      return const LeaderboardSyncReport();
    }
    final sid = (dashboard?.studentId ?? '').trim();
    if (sid.isEmpty) return const LeaderboardSyncReport();

    // ---- 1) sign-in check (the session cookie) ----
    onProgress?.call(const SyncStepUpdate(
      key: 'session',
      kind: SyncStepKind.session,
      label: 'Checking your portal sign-in',
      detail: 'Verifying your Microsoft session',
      state: SyncStepState.active,
    ));
    // A dead session means nothing can be read — the caller shows the
    // sign-in prompt.
    if (!await _portalSessionAlive(sid)) {
      onProgress?.call(const SyncStepUpdate(
        key: 'session',
        kind: SyncStepKind.session,
        label: 'Checking your portal sign-in',
        detail: 'Sign-in required',
        state: SyncStepState.failed,
      ));
      return const LeaderboardSyncReport();
    }
    onProgress?.call(const SyncStepUpdate(
      key: 'session',
      kind: SyncStepKind.session,
      label: 'Checking your portal sign-in',
      detail: 'Signed in',
      state: SyncStepState.done,
    ));

    // ---- 2) timetable: read with the cookie, then send it ----
    onProgress?.call(const SyncStepUpdate(
      key: 'timetable',
      kind: SyncStepKind.timetable,
      label: 'Getting your timetable',
      detail: 'Reading the portal schedule',
      state: SyncStepState.active,
    ));
    var rows = _timetableSyncRows;
    try {
      final html = await PortalApi().fetchPage(PortalRoutes.timetable, sid);
      final slots = parseTimetable(html).slots;
      if (slots.isNotEmpty) {
        if (mounted) setState(() => timetableSlots = _resolveSlots(slots));
        rows = _timetableSyncRows;
        await PageCache.savePage('timetable', html);
      }
    } catch (_) {
      // Keep the slots we already have (cached snapshot).
    }
    if (rows.isNotEmpty) {
      try {
        // The student id goes with it — the server groups the student
        // into the sections of this timetable.
        await NodeLeaderboardService()
            .syncTimetable(studentId: sid, rows: rows);
      } catch (_) {
        // Best effort — the board still works without the roster.
      }
    }
    onProgress?.call(SyncStepUpdate(
      key: 'timetable',
      kind: SyncStepKind.timetable,
      label: 'Getting your timetable',
      detail: '${rows.length} slots sent to the server',
      state: SyncStepState.done,
    ));

    // ---- 3) every subject's grade page ----
    final courses = dashboard?.courses ?? const <PortalCourse>[];
    var synced = 0;
    var failed = 0;
    final failures = <String>[];
    for (var i = 0; i < courses.length; i++) {
      if (!mounted) break;
      final pc = courses[i];
      final key = 'grade:${pc.code.isEmpty ? pc.name : pc.code}';
      onProgress?.call(SyncStepUpdate(
        key: key,
        kind: SyncStepKind.grade,
        label: 'Getting the grade page',
        detail: '${pc.name} \u00b7 ${i + 1} of ${courses.length}',
        state: SyncStepState.active,
      ));
      final courseId = courseIdFromUrl(pc.infoUrl) ?? '';
      if (courseId.isEmpty) continue;
      try {
        var gb = CourseDetailCache.gradebook[courseId];
        if (gb == null || gb.isEmpty) {
          final html = await PortalApi().fetchPage(
            '/student/course/gradebook/$courseId',
            sid,
          );
          gb = parseCourseGradebook(html);
          CourseDetailCache.putGradebook(courseId, gb);
        }
        if (gb == null || gb.isEmpty) {
          onProgress?.call(SyncStepUpdate(
            key: key,
            kind: SyncStepKind.grade,
            label: 'Getting the grade page',
            detail: '${pc.name} \u00b7 no gradebook published',
            state: SyncStepState.failed,
          ));
          continue;
        }
        await _syncOwnGrades(pc, pc.name, gb);
        synced++;
        onProgress?.call(SyncStepUpdate(
          key: key,
          kind: SyncStepKind.grade,
          label: 'Getting the grade page',
          detail: '${pc.name} \u00b7 parsed and sent to the server',
          state: SyncStepState.done,
        ));
      } catch (_) {
        // One subject without a gradebook must not stop the rest.
        failed++;
        failures.add(pc.name);
        onProgress?.call(SyncStepUpdate(
          key: key,
          kind: SyncStepKind.grade,
          label: 'Getting the grade page',
          detail: '${pc.name} \u00b7 could not be read',
          state: SyncStepState.failed,
        ));
      }
    }

    return LeaderboardSyncReport(
      timetableRows: rows.length,
      subjectsSynced: synced,
      subjectsFailed: failed,
      failures: failures,
    );
  }

  /// Makes sure the student is signed in to the portal before anything
  /// is read.
  ///
  /// The leaderboard needs the Horizon session cookie (obtained through
  /// the Microsoft account sign-in) to read the timetable and the grade
  /// pages. When the session is missing or dead, the Microsoft sign-in
  /// is started and awaited; the sign-in UI takes over the screen and
  /// the leaderboard continues as soon as it completes.
  Future<bool> ensurePortalSession() async {
    if (!mounted) return false;
    final sid = sessionId;
    if (authed && sid != null && sid.isNotEmpty) {
      if (await _portalSessionAlive(sid)) return true;
      if (!mounted) return false;
      // The portal session died (expired elsewhere) — drop it and let
      // the Microsoft sign-in mint a fresh one.
      setState(() {
        sessionId = null;
        authed = false;
      });
    }
    // Start the Microsoft sign-in (the shell shows the sign-in UI).
    final email = sessionEmail ?? await _backend.readEmail() ?? '';
    if (email.isEmpty) {
      // No known account: the login screen asks for it.
      if (mounted) {
        setState(() {
          authed = false;
          authError = null;
        });
      }
      return false;
    }
    final waiter = Completer<bool>();
    _signInWaiter = waiter;
    if (!mounted) return false;
    setState(() {
      oauthEmail = email;
      authError = null;
      _signingIn = true;
      _signInFailed = false;
      _signInFailMessage = null;
    });
    return waiter.future;
  }

  /// Completes a pending [ensurePortalSession] wait.
  void _completeSignInWait(bool ok) {
    final waiter = _signInWaiter;
    _signInWaiter = null;
    if (waiter != null && !waiter.isCompleted) waiter.complete(ok);
  }

  /// True when the portal still accepts the session cookie.
  Future<bool> _portalSessionAlive(String sid) async {
    try {
      final html = await PortalApi().fetchDashboard(sid);
      return html.isNotEmpty && !html.contains('oe_login_form');
    } catch (_) {
      return false;
    }
  }

  /// Publishes the student's timetable and gradebooks to the community
  /// backend so their classmates see them — WITHOUT the extension.
  /// Runs in the background right after the dashboard loads.
  Future<void> _runCommunitySync() async {
    if (!isExtConfigured) return;
    if (_communitySynced) return;
    _communitySynced = true;
    await syncClassToServer();
  }

  /// Portal course matching a board label. Exact name first, then the
  /// identity key (section dropped, "- Lab" KEPT so theory and lab stay
  /// apart), then the course code, then a loose match.
  PortalCourse? _matchPortalCourse(String courseName) {
    final dash = dashboard;
    if (dash == null || dash.courses.isEmpty) return null;
    final wanted = courseName.trim().toLowerCase();
    for (final pc in dash.courses) {
      if (pc.name.trim().toLowerCase() == wanted) return pc;
    }
    final key = _courseIdentityKey(courseName);
    for (final pc in dash.courses) {
      if (_courseIdentityKey(pc.name) == key) return pc;
    }
    final code = _courseCodeOf(courseName).toLowerCase();
    for (final pc in dash.courses) {
      if (code.isNotEmpty && pc.code.toLowerCase() == code) return pc;
    }
    for (final pc in dash.courses) {
      final k = _courseLooseKey(pc.name);
      if (k.isNotEmpty && (k.contains(key) || key.contains(k))) return pc;
    }
    return null;
  }

  /// Identity key: the section suffix is dropped, the "- Lab" suffix is
  /// KEPT — theory and lab are different subjects.
  static String _courseIdentityKey(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '')
      .trim();

  /// Loose key (section AND "- Lab" dropped) — fallback matching only.
  static String _courseLooseKey(String name) => _courseIdentityKey(name)
      .replaceAll(RegExp(r'\s*[-–—]\s*lab\s*$'), '')
      .trim();

  /// Course code inside a board label's section code, e.g.
  /// "Computer Org (AR221-R26-BS-CS-S25-C2)" -> "AR221".
  static String _courseCodeOf(String label) {
    final m = RegExp(r'\(([^)]*)\)').firstMatch(label);
    if (m == null) return '';
    final inner = m.group(1)!.trim();
    final code = inner.split('-').first.trim();
    return code;
  }

  /// Publishes the app's own gradebook for a course to the backend, so
  /// the student's row shows on the board (app-only users, no extension).
  Future<void> _syncOwnGrades(
      PortalCourse pc, String courseName, [CourseGradebook? cached]) async {
    if (!isExtConfigured) return;
    final sid = (dashboard?.studentId ?? '').trim();
    if (sid.isEmpty) return;
    final courseId = courseIdFromUrl(pc.infoUrl) ?? '';
    if (courseId.isEmpty) return;
    final gb = cached ?? CourseDetailCache.gradebook[courseId];
    if (gb == null) return;
    if (gb.isEmpty) return;
    // Weighted overall across the published types (same formula the
    // board shows).
    var weighted = 0.0;
    var weights = 0.0;
    for (final t in gb.types) {
      final w = t.weight > 0 ? t.weight : 1.0;
      weighted += t.obtained.clamp(0, 100) * w;
      weights += w;
    }
    if (weights == 0) return;
    final overall = weighted / weights;
    final grade = _letterFor(overall);
    final assessments = [
      for (final t in gb.types)
        {
          'name': t.type,
          'totalMarks': 100,
          'obtainedMarks': t.obtained,
          'percentage': t.obtained,
          'weightage': t.weight,
          'classAverage': null,
        },
    ];
    try {
      await (NodeLeaderboardService()).syncGrades(
        studentId: sid,
        studentName: dashboard?.studentName ?? '',
        courseName: courseName,
        // The FULL section code — identical in every client, so the app
        // and the extension write onto the same record.
        courseCode: _resolveSectionCode(pc) ?? pc.code,
        overallPercentage: overall,
        grade: grade,
        assessments: assessments,
      );
    } catch (_) {
      // Best-effort: the board still loads.
    }
  }

  /// Grade letter from an overall percentage (UCP scale).
  static String _letterFor(double pct) {
    if (pct >= 86) return 'A';
    if (pct >= 82) return 'A-';
    if (pct >= 78) return 'B+';
    if (pct >= 74) return 'B';
    if (pct >= 70) return 'B-';
    if (pct >= 66) return 'C+';
    if (pct >= 62) return 'C';
    if (pct >= 58) return 'C-';
    if (pct >= 54) return 'D+';
    if (pct >= 50) return 'D';
    return 'F';
  }

  /// Builds (or rebuilds) the foreground watchdog. Called whenever the app
  /// becomes authenticated; stopped on logout/dispose.
  /// Mid-use policy: NO silent renewal while the user works — a dead
  /// session pops the relogin / stay-logged-out choice instead.
  void _startMonitor() {
    _monitor?.stop();
    if (widget.skipLogin) return;
    final backend = _backend;
    final monitor = SessionMonitor(
      readSession: () async {
        final saved = await backend.load();
        if (saved == null) return null;
        return MonitorSnapshot(saved.sessionId, saved.email);
      },
      validate: _validateSession,
      renew: _performRenew,
      onRenewed: (sid, email) async {
        await backend.save(sessionId: sid, email: email);
        if (!mounted) return;
        setState(() {
          sessionId = sid;
          sessionEmail = email;
          _expiredForSid = null;
          _expiredMessage = null;
          _expiredCode = null;
          // A background heal also clears any stale sign-in banner.
          _signingIn = false;
          _signInFailed = false;
          _signInFailMessage = null;
        });
        _flashHealNotice();
        if (widget.authHooks == null) _loadDashboard();
      },
      onDead: (message, code) => _handleSessionDead(message, code),
      interval: widget.authHooks?.monitorInterval ?? SessionMonitor.heartbeat,
      autoRenew: false,
    );
    _monitor = monitor;
    monitor.start();
  }

  /// Brief non-blocking banner proving the background heal ran ("Session
  /// refreshed automatically"). Auto-dismissed; never steals taps.
  void _flashHealNotice() {
    if (!mounted) return;
    setState(() => _healNotice = true);
    _healTimer?.cancel();
    _healTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _healNotice = false);
    });
  }

  /// Popup state for a session that died mid-use (laptop login, timeout).
  /// [_expiredForSid] stops the popup re-firing for the same dead session
  /// on every 30 s tick; it resets on the next successful authentication.
  String? _expiredMessage;
  String? _expiredCode;
  String? _expiredForSid;

  /// Last back-press time for double-press-to-exit on the home root.
  DateTime? _lastBackPress;

  /// In-app back stack: overlays → detail → tab → double-press exit.
  /// Returns true when the press was consumed and the app must stay open.
  bool _onBackPressed(BuildContext ctx) {
    if (_expiredMessage != null) {
      setState(() => _expiredMessage = null);
      return true;
    }
    if (menu) {
      setState(() => menu = false);
      return true;
    }
    if (course != null || portalCourse != null) {
      setState(() {
        course = null;
        courseLive = false;
        portalCourse = null;
        _hubInitialTab = 'news';
      });
      return true;
    }
    if (!authed) {
      if (oauthEmail != null) {
        setState(() {
          oauthEmail = null;
          authError = null;
        });
        return true;
      }
      return false;
    }
    if (tab != 'home') {
      go('home');
      return true;
    }
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
      return true;
    }
    return false;
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

  /// One immediate watchdog pass: proves the live session, heals it
  /// silently when stale, or pops the re-login dialog when truly dead.
  /// Safe from resume hooks and portal 401 handlers (concurrent passes
  /// are skipped inside the monitor). Stays silent while offline.
  void _checkSessionNow() {
    if (OfflineMonitor.instance.isOffline) return;
    if (!authed || _monitor == null) return;
    unawaited(_monitor!.checkNow());
  }

  void go(String t) => setState(() { tab = t; course = null; courseLive = false; portalCourse = null; _hubInitialTab = 'news'; menu = false; });

  /// The watchdog proved the portal session dead and silent renewal failed:
  /// show the "someone logged in elsewhere?" popup instead of silently
  /// dumping the user to the login screen.
  Future<void> _handleSessionDead(String message, String code) async {
    if (!mounted || !authed || oauthEmail != null) return;
    final sid = sessionId;
    if (sid != null && _expiredForSid == sid) return; // already notified
    setState(() {
      _expiredForSid = sid;
      _expiredMessage = message;
      _expiredCode = code;
    });
  }

  /// "Relogin now": keep the (still valid) Microsoft cookies, drop only
  /// the dead Horizon session, and open the interactive sign-in. A fresh
  /// success clears the popup guard.
  Future<void> _reloginNow() async {
    final email =
        sessionEmail ?? await _backend.readEmail() ?? '';
    await _backend.clear();
    if (!mounted) return;
    setState(() {
      sessionId = null;
      authed = false;
      oauthEmail = email.isNotEmpty ? email : null;
      authError = null;
      _expiredMessage = null;
      _signingIn = false;
      _signInFailed = false;
      _signInFailMessage = null;
      _stayWithoutLive = false; // explicit fresh sign-in: live again
      _bgRun++;
      tab = 'home';
      menu = false;
    });
  }

  Future<void> _logout({String? message}) async {
    _monitor?.stop();
    PortalCache.clear();
    CourseDetailCache.clear();
    _healTimer?.cancel();
    _healNotice = false;
    _finishSilentRenew(null); // abort any background renewal
    _bgRun++; // invalidate any in-flight background verify
    await _backend.clear();
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
      _expiredMessage = null;
      _expiredCode = null;
      _expiredForSid = null;
      _signingIn = false;
      _signInFailed = false;
      _signInFailMessage = null;
      _stayWithoutLive = false;
      dashboard = null;
      timetableSlots = const [];
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
    final pc0 = portalCourse;
    if (course != null || pc0 != null) {
      if (pc0 != null && pc0.infoUrl.isNotEmpty) {
        // Live per-course hub (dashboard infoUrl → 7 portal tabs).
        screen = CourseDetailScreen(
          portalCourse: pc0,
          sessionId: sessionId,
          initialTab: _hubInitialTab,
          onSessionExpired: () => _checkSessionNow(),
          onOpenLeaderboard: (courseName) {
            // Publish our own gradebook for this subject, then jump to
            // the board: our row exists even without the extension.
            unawaited(_syncOwnGrades(pc0, courseName));
            setState(() {
              // Jump to the live board for THIS subject.
              _boardCourse = courseName;
              _boardCourseCode = pc0.code;
              portalCourse = null;
              course = null;
              courseLive = false;
              tab = 'board';
            });
          },
          back: () => setState(() {
            course = null;
            courseLive = false;
            portalCourse = null;
            _hubInitialTab = 'news';
          }),
        );
      } else {
        screen = DetailScreen(course: course!, slots: timetableSlots, isLive: courseLive, back: () => setState(() { course = null; courseLive = false; portalCourse = null; }));
      }
    } else {
      switch (tab) {
        case 'home':
          screen = HomeScreen(onOpen: (c) {
            // Match the tapped card back to its live portal course so
            // the hub can fetch the 7 per-course tabs. Bundled sample
            // cards (offline/tests) have no portal match → static detail.
            PortalCourse? match;
            final dash = dashboard;
            if (dash != null && dash.courses.isNotEmpty) {
              final key = c.title.trim().toLowerCase();
              for (final pc in dash.courses) {
                if (pc.name.trim().toLowerCase() == key) {
                  match = pc;
                  break;
                }
              }
            }
            setState(() { course = c; courseLive = dashboard != null && dashboard!.courses.isNotEmpty; portalCourse = match; });
          }, toProfile: () => go('profile'), onMenu: () => setState(() => menu = true), onGpa: () => go('gpa'), onBoard: (c) { setState(() { boardOf = c; _boardCourse = c.title; _boardCourseCode = c.code; tab = 'board'; }); }, dashboard: dashboard, timetableSlots: timetableSlots, onAttend: () => go('attendance'), onTimetable: () => go('timetable'), onTeachers: () => go('teachers'), onMaterial: () => go('material'), onFee: () => go('fee'), onResults: () => go('results'), onCommunity: () => go('community'), onWeb: () => go('web'), onRefreshAll: _refreshAllPortal);
          break;
        case 'material':
          // LIVE: a directory of per-course material pages (tap → hub
          // opens straight on its Material tab). Falls back to the
          // bundled sample content while signed out / offline.
          screen = MaterialsScreen(
            portalCourses: (dashboard?.courses ?? const [])
                .where((pc) => pc.infoUrl.isNotEmpty)
                .toList(),
            onOpenCourse: (pc) => setState(() {
              portalCourse = pc;
              course = null;
              _hubInitialTab = 'material';
            }),
          );
          break;
        case 'community':
          screen = CommunityScreen(
            service: _communityService(),
            myEmail: sessionEmail ?? '',
          );
          break;
        case 'teachers':
          screen = TeachersScreen(
            service: _teacherService(),
            myEmail: sessionEmail ?? '',
          );
          break;
        case 'gpa':
          screen = const VaultHomeScreen(initialTab: 1);
          break;
        case 'vault':
          // Legacy alias: older menu state may still reference 'vault'.
          screen = const VaultHomeScreen(initialTab: 1);
          break;
        case 'timetable':
          screen = TimetableScreen(
            sessionId: sessionId,
            onSessionExpired: () => _checkSessionNow(),
          );
          break;
        case 'attendance':
          screen = AttendanceScreen(
            sessionId: sessionId,
            onSessionExpired: () => _checkSessionNow(),
            portalCourses: dashboard?.courses ?? const [],
          );
          break;
        case 'results':
          screen = ResultsScreen(
            sessionId: sessionId,
            onSessionExpired: () => _checkSessionNow(),
          );
          break;
        case 'fee':
          screen = FeeChallanScreen(
            sessionId: sessionId,
            onSessionExpired: () => _checkSessionNow(),
          );
          break;
        case 'board':
          // Live leaderboard when the ext backend is configured (real
          // ranks, credits, privacy); the deterministic demo board is the
          // offline / unconfigured fallback.
          screen = LiveLeaderboardScreen(
            service: isExtConfigured ? NodeLeaderboardService() : null,
            studentId: dashboard?.studentId,
            initialCourse: _boardCourse,
            initialCourseCode: _boardCourseCode,
            // The student's REAL portal courses drive the picker (their
            // names carry "- Lab" etc., matching the published grades).
            portalCourses: dashboard?.courses ?? const [],
            // Full section codes: the board queries the exact section
            // instead of guessing from the (truncated) course name.
            sectionCodes: _sectionCodesByCourse,
            // Portal-timetable fallback: the app already parsed the real
            // weekly schedule, so the picker works before the extension
            // has posted anything.
            fallbackCourses: _portalCourseNames,
            // App-first: publish our own timetable so the server builds
            // our class roster (app-only users group with extension
            // users).
            timetableRows: _timetableSyncRows,
            studentName: dashboard?.studentName,
            // Publish our own marks for the opened subject so our row is
            // on the board even without the extension.
            onEnsureGrades: _ensureCourseGrades,
            // The class pipeline: portal sign-in -> timetable -> grade
            // pages -> publish, then the class boards.
            onEnsureSession: ensurePortalSession,
            onSyncClass: syncClassToServer,
            back: () => go('home'),
            fallback: LeaderboardScreen(start: boardOf.code, back: () => go('home')),
          );
          break;
        case 'web':
          // Platform WebViews don't exist in widget tests: render the
          // placeholder shell there, the live portal everywhere else.
          final bool testMode =
              widget.skipLogin || widget.authHooks != null;
          screen = WebViewScreen(
            sessionId: sessionId,
            renderWebView: !testMode,
            onSessionExpired: () => _checkSessionNow(),
          );
          break;
        default:
          screen = ProfileScreen(
            logout: _logout,
            prefs: prefs,
            onPrefs: (p) {
              setState(() => prefs = p);
              // Permanent until the user changes it again (survives
              // restarts and logout).
              unawaited(PrefsStore().savePrefs(p));
            },
            studentName: dashboard?.studentName,
            studentId: dashboard?.studentId,
            faculty: dashboard?.faculty,
            email: sessionEmail,
            earnedCredits: dashboard == null
                ? null
                : statValue(dashboard!.stats, 'Earned Cr'),
          );
      }
    }

    final bool showNav = authed && oauthEmail == null;

    return AppScope(
      colors: colors,
      palette: prefs.palette,
      child: MaterialApp(
        title: 'UCP University',
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
            child: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return;
                if (!_onBackPressed(ctx)) SystemNavigator.pop();
              },
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
                                        _signingIn = false;
                                        _signInFailed = false;
                                        _signInFailMessage = null;
                                        _stayWithoutLive = false;
                                        _expiredForSid = null;
                                        _expiredMessage = null;
                                        _expiredCode = null;
                                      });
                                      _completeSignInWait(true);
                                      _startMonitor();
                                      _loadDashboard();
                                    },
                                    onCancelled: () {
                                      _completeSignInWait(false);
                                      setState(() {
                                        oauthEmail = null;
                                        authError = null;
                                        _signingIn = false;
                                      });
                                    },
                                    onError: (msg) {
                                      _completeSignInWait(false);
                                      setState(() {
                                        oauthEmail = null;
                                        authError = msg;
                                        _signingIn = false;
                                      });
                                    },
                                  )
                                : LoginScreen(
                                    restoring: _restoring,
                                    authError: authError,
                                    onMicrosoftSignIn: (email) {
                                      if (OfflineMonitor
                                          .instance.isOffline) {
                                        setState(() {
                                          authError = offlineLoginMessage;
                                        });
                                        return;
                                      }
                                      setState(
                                        () {
                                          oauthEmail = email;
                                          authError = null;
                                        },
                                      );
                                    },
                                  )
                            : SafeArea(top: true, bottom: false, child: screen),
                      ),
                      // Offline pill on the login screen only — the signed-in
                      // world shows status above the tab bar.
                      if (!authed &&
                          !widget.skipLogin &&
                          widget.authHooks == null)
                        const Positioned(
                          top: 8,
                          left: 16,
                          right: 16,
                          child: OfflineBanner(),
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
                                      for (final it in [['home', 'Home', Icons.home_outlined], ['teachers', 'Teacher reviews', Icons.star_outlined], ['timetable', 'Timetable', Icons.calendar_month_outlined], ['attendance', 'Attendance', Icons.fact_check_outlined], ['material', 'Course material', Icons.book_outlined], ['gpa', 'GPA calculator', Icons.calculate_outlined], ['fee', 'Fee challan', Icons.receipt_outlined], ['results', 'Results', Icons.workspace_premium_outlined], ['community', 'Community', Icons.forum_outlined], ['web', 'Web view', Icons.language_outlined], ['profile', 'Profile & settings', Icons.person_outline]])
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
                      // Dead-session popup sits above menu: "someone
                      // logged in elsewhere?" + Login-here-now option.
                      if (authed &&
                          oauthEmail == null &&
                          _expiredMessage != null)
                        Positioned.fill(
                          child: SessionExpiredDialog(
                            message: _expiredMessage!,
                            detail: _expiredCode,
                            onLoginNow: _reloginNow,
                            onLater: () => setState(() {
                              // Stay logged out: usable on saved data,
                              // no cookie refresh; the kept session lets
                              // the next launch retry auto sign-in.
                              _expiredMessage = null;
                              _stayWithoutLive = true;
                            }),
                          ),
                        ),
                      // Bottom stack above the tab bar: sign-in-failed
                      // banner / silent-heal notice / "trying to sign in"
                      // pill, plus the persistent offline saved-data pill.
                      if (authed)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: ValueListenableBuilder<bool>(
                            valueListenable:
                                OfflineMonitor.instance.offline,
                            builder: (_, off, __) {
                              final showFail = _signInFailed &&
                                  !_signingIn &&
                                  _expiredMessage == null;
                              final showHeal = !showFail &&
                                  _healNotice &&
                                  _expiredMessage == null;
                              final showSigning = _signingIn &&
                                  _expiredMessage == null;
                              if (!showFail &&
                                  !showHeal &&
                                  !showSigning &&
                                  !off) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showFail)
                                    _signInFailBanner(colors),
                                  if (showHeal) _healCard(colors),
                                  if (showSigning) _signingPill(),
                                  if (off) ...[
                                    if (showFail ||
                                        showHeal ||
                                        showSigning)
                                      const SizedBox(height: 8),
                                    const OfflineBanner(),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
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
                                    _navItem(ctx, colors, 'community', 'Community', Icons.group_outlined),
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
                                              child: Icon(Icons.home_outlined, color: colors.cream, size: 26),
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
            ),
          );
        }),
      ),
    );
  }

  /// Tiny "Trying to sign in…" pill: proof the background session engine
  /// is working. Non-interactive, lives in the bottom stack above tabs.
  Widget _signingPill() {
    return IgnorePointer(
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Trying to sign in…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Retry / fresh-sign-in card for a failed background sign-in.
  Widget _signInFailBanner(AppColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: colors.tealInk,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 18,
                color: colors.cream,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _signInFailMessage ?? 'Couldn\'t sign you in.',
                  style: body(
                    colors,
                    size: 13,
                    weight: FontWeight.w600,
                    color: colors.cream,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _signInFailed = false),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: colors.cream.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _signingIn
                      ? null
                      : () {
                          // Explicit live request.
                          setState(
                              () => _stayWithoutLive = false);
                          _backgroundVerify();
                        },
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.cream,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Try again',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colors.tealDeep,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _reloginNow,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: colors.cream.withValues(alpha: 0.7)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Sign in',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colors.cream,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Brief proof the background heal ran. Non-interactive.
  Widget _healCard(AppColors colors) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.tealInk,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 18,
              color: colors.cream,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Session refreshed automatically — you stay signed in.',
                style: body(
                  colors,
                  size: 13,
                  weight: FontWeight.w600,
                  color: colors.cream,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(BuildContext ctx, AppColors c, String key, String label, IconData icon) {
    final on = tab == key && course == null;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => go(key),
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
