import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../data/seed.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});
  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  String sel = courses[0].code;
  String view = 'files';
  String kind = 'All';
  final Set<String> done = {};
  Course get c => courses.firstWhere((x) => x.code == sel);

  final papers = const [
    ['Final', 'Fall 2025', '3 hrs · 100 marks', true],
    ['Midterm', 'Fall 2025', '90 min · 40 marks', true],
    ['Quiz', 'Fall 2025', 'Quiz 2 · 15 marks', false],
    ['Final', 'Spring 2025', '3 hrs · 100 marks', true],
    ['Midterm', 'Spring 2025', '90 min · 40 marks', false],
    ['Final', 'Fall 2024', '3 hrs · 100 marks', false],
  ];
  final items = const [
    ['PDF', 'Lecture 6 — slides', '2.4 MB', 0],
    ['VID', 'Recorded lecture · Week 5', '48 min', 1],
    ['DOC', 'Assignment 3 brief', '310 KB', 2],
    ['PDF', 'Reading list', '120 KB', 3],
    ['ZIP', 'Lab starter files', '5.1 MB', 4],
  ];

  @override
  Widget build(BuildContext context) {
    final ac = AppScope.colorsOf(context);
    final shown = papers.where((p) => kind == 'All' || p[0] == kind).toList();
    final bgTones = [ac.clay, ac.teal, ac.board, ac.dust, ac.tealInk];
    return UHead(
      height: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Course material', style: display(ac, size: 28, color: Colors.white)),
          Text('Slides, recordings and files for every class', style: body(ac, size: 14, color: Colors.white.withValues(alpha: 0.78))),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final x in courses)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => sel = x.code),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: sel == x.code ? ac.tealInk : ac.dustSoft, borderRadius: BorderRadius.circular(20)),
                        child: Text(x.code, style: body(ac, size: 14, weight: FontWeight.w600, color: sel == x.code ? ac.cream : ac.tealInk.withValues(alpha: 0.7))),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: toneBg(c.tone, ac), borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c.code} · ${c.prof}'.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
                Text(c.title, style: display(ac, size: 22, color: c.tone == CourseTone.board ? ac.tealInk : Colors.white)),
                Text(view == 'files' ? '${items.length} files · updated 2 days ago' : '${papers.length} past papers · ${done.where((d) => d.startsWith(sel)).length} practiced',
                    style: TextStyle(fontSize: 14, color: (c.tone == CourseTone.board ? ac.tealInk : Colors.white).withValues(alpha: 0.8))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: ac.dustSoft, borderRadius: BorderRadius.circular(30)),
            child: Row(
              children: [
                for (final v in ['files', 'papers'])
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => view = v),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(color: view == v ? ac.tealInk : Colors.transparent, borderRadius: BorderRadius.circular(24)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(v == 'files' ? Icons.book_outlined : Icons.assignment_outlined, size: 16, color: view == v ? ac.cream : ac.tealInk.withValues(alpha: 0.65)),
                            const SizedBox(width: 6),
                            Text(v == 'files' ? 'Materials' : 'Past papers', style: body(ac, size: 14, weight: FontWeight.bold, color: view == v ? ac.cream : ac.tealInk.withValues(alpha: 0.65))),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (view == 'papers') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (final k in ['All', 'Final', 'Midterm', 'Quiz'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => kind = k),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: kind == k ? ac.teal : Colors.transparent,
                          border: Border.all(color: kind == k ? ac.teal : ac.dustSoft, width: 2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(k, style: body(ac, size: 12, weight: FontWeight.bold, color: kind == k ? Colors.white : ac.tealInk.withValues(alpha: 0.65))),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (final p in shown)
              Builder(builder: (_) {
                final id = '$sel-${p[0]}-${p[1]}';
                final ok = done.contains(id);
                final sol = p[3] == true;
                Color badge = p[0] == 'Final' ? ac.clay : p[0] == 'Midterm' ? ac.teal : ac.dust;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: ac.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(alignment: Alignment.center, width: 48, height: 48, decoration: BoxDecoration(color: badge, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.description_outlined, color: Colors.white)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${c.code} ${p[0]} · ${p[1]}', style: body(ac, size: 14, weight: FontWeight.w600)), Text(p[2] as String, style: body(ac, size: 12, color: ac.tealInk.withValues(alpha: 0.55)))])),
                          Container(alignment: Alignment.center, width: 40, height: 40, decoration: BoxDecoration(color: ac.dustSoft, shape: BoxShape.circle), child: Icon(Icons.download_outlined, size: 18, color: ac.tealInk)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: ac.dustSoft))),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: sol ? ac.board.withValues(alpha: 0.4) : ac.dustSoft, borderRadius: BorderRadius.circular(12)),
                              child: Text(sol ? 'Solution included' : 'Questions only', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            const Spacer(),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => ok ? done.remove(id) : done.add(id)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(color: ok ? ac.teal : Colors.transparent, border: Border.all(color: ok ? ac.teal : ac.dustSoft, width: 2), borderRadius: BorderRadius.circular(20)),
                                child: Row(children: [const Icon(Icons.check, size: 13), Text(ok ? 'Practiced' : 'Mark practiced', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ok ? Colors.white : ac.tealInk.withValues(alpha: 0.65)))]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ] else ...[
            const SizedBox(height: 16),
            for (final it in items)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: ac.white, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Container(width: 48, height: 48, decoration: BoxDecoration(color: bgTones[it[3] as int], borderRadius: BorderRadius.circular(12)), child: Center(child: Text(it[0] as String, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(it[1] as String, style: body(ac, size: 14, weight: FontWeight.w600)), Text(it[2] as String, style: body(ac, size: 12, color: ac.tealInk.withValues(alpha: 0.55)))])),
                    Container(alignment: Alignment.center, width: 40, height: 40, decoration: BoxDecoration(color: ac.dustSoft, shape: BoxShape.circle), child: Icon(Icons.download_outlined, size: 18, color: ac.tealInk)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}

/// Real Horizon portal inside the app, authenticated with the captured
/// `session_id` cookie.
///
/// The cookie is injected into the WebView store before the first load, so
/// the portal opens already signed in — no second login. If the portal
/// bounces to `/web/login` (session died), an inline notice offers
/// re-login, which triggers [onSessionExpired] (the watchdog validates,
/// renews or pops up — same as everywhere else).
class WebViewScreen extends StatefulWidget {
  final String? sessionId;
  final VoidCallback? onSessionExpired;
  /// False in widget tests: platform WebViews don't exist headlessly, so a
  /// lightweight placeholder renders instead (title/chips stay identical).
  final bool renderWebView;
  const WebViewScreen(
      {super.key, this.sessionId, this.onSessionExpired, this.renderWebView = true});
  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  static const _host = 'horizon.ucp.edu.pk';
  static const _shortcuts = [
    ['Dashboard', '/student/dashboard'],
    ['Profile', '/student/profile'],
    ['Portal', '/my/home'],
  ];

  WebViewController? _controller;
  String _path = '/student/dashboard';
  double _progress = 0;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    if (widget.renderWebView) _initController();
  }

  @override
  void didUpdateWidget(WebViewScreen old) {
    super.didUpdateWidget(old);
    // Session healed in the background while this tab is open: re-seed the
    // cookie and reload so the portal never shows a stale login page.
    if (widget.sessionId != null &&
        widget.sessionId != old.sessionId &&
        _controller != null) {
      _loadPortal(_path);
    }
  }

  Future<void> _initController() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p / 100);
          },
          onUrlChange: _onUrl,
        ),
      );
    _controller = controller;
    await _loadPortal(_path);
  }

  Future<void> _loadPortal(String path) async {
    final sid = widget.sessionId;
    final controller = _controller;
    if (controller == null) return;
    if (sid != null && sid.isNotEmpty) {
      try {
        await WebViewCookieManager().setCookie(
          WebViewCookie(name: 'session_id', value: sid, domain: _host, path: '/'),
        );
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _path = path;
      _expired = false;
    });
    await controller.loadRequest(Uri.https(_host, path));
  }

  void _onUrl(UrlChange change) {
    final uri = change.url == null ? null : Uri.tryParse(change.url!);
    if (uri == null || !mounted) return;
    if (uri.host == _host && uri.path.startsWith('/web/login')) {
      setState(() {
        _expired = true;
        _path = uri.path;
      });
    } else if (uri.host == _host) {
      setState(() {
        _path = uri.path;
        _expired = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return UHead(
      height: 108,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Web view', style: display(c, size: 28, color: Colors.white)),
          Text('Horizon portal · signed in with your session',
              style: body(c,
                  size: 13, color: Colors.white.withValues(alpha: 0.78))),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in _shortcuts)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (widget.renderWebView) {
                          _loadPortal(s[1]);
                        } else {
                          setState(() => _path = s[1]);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _path == s[1] ? c.teal : c.dustSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(s[0],
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _path == s[1]
                                    ? Colors.white
                                    : c.tealInk)),
                      ),
                    ),
                  ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (widget.renderWebView) {
                      _controller?.reload();
                    } else {
                      setState(() {});
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.tealInk,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.refresh, size: 14, color: Colors.white),
                        Text(' Reload',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 600,
            decoration: BoxDecoration(
              color: c.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: c.dustSoft, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  if (widget.renderWebView && _controller != null)
                    WebViewWidget(controller: _controller!)
                  else
                    Container(
                      color: c.dustSoft.withValues(alpha: 0.4),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.language_outlined,
                                size: 40,
                                color: c.tealInk.withValues(alpha: 0.4)),
                            const SizedBox(height: 8),
                            Text(
                              widget.renderWebView
                                  ? 'Loading portal…'
                                  : 'Portal preview unavailable in tests',
                              style: body(
                                c,
                                size: 13,
                                color: c.tealInk.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_progress > 0 && _progress < 1)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: c.dustSoft,
                        valueColor: AlwaysStoppedAnimation(c.clay),
                        minHeight: 3,
                      ),
                    ),
                  if (_expired)
                    Positioned.fill(
                      child: Container(
                        color: c.cream2.withValues(alpha: 0.97),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline,
                                size: 36, color: c.clay),
                            const SizedBox(height: 12),
                            Text('Portal session expired',
                                style: display(c, size: 18),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 6),
                            Text(
                              'Sign in again to keep browsing the portal here.',
                              style: body(
                                c,
                                size: 13,
                                color:
                                    c.tealInk.withValues(alpha: 0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ClayButton(
                              label: 'Re-login now',
                              colors: c,
                              height: 48,
                              fontSize: 15,
                              onPressed: widget.onSessionExpired != null
                                  ? () {
                                      setState(() => _expired = false);
                                      widget.onSessionExpired!();
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
