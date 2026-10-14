import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../auth/offline.dart';
import '../data/seed.dart';
import '../theme/palette.dart';
import '../web/download_tray.dart';
import '../web/portal_downloader.dart';
import '../web/public_downloads.dart';
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
                Text('${c.code} · ${c.prof}'.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: toneFg(c.tone, ac).withValues(alpha: 0.75))),
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
              Builder(builder: (_) {
                final bg = bgTones[it[3] as int];
                final fg = (bg == ac.board || bg == ac.tealInk)
                    ? ac.cream
                    : Colors.white;
                return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: ac.white, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Container(width: 48, height: 48, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(it[0] as String, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold)))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(it[1] as String, style: body(ac, size: 14, weight: FontWeight.w600)), Text(it[2] as String, style: body(ac, size: 12, color: ac.tealInk.withValues(alpha: 0.55)))])),
                    Container(alignment: Alignment.center, width: 40, height: 40, decoration: BoxDecoration(color: ac.dustSoft, shape: BoxShape.circle), child: Icon(Icons.download_outlined, size: 18, color: ac.tealInk)),
                  ],
                ),
                );
              }),
          ],
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}

class _BlobAssembly {
  final List<String?> chunks;
  final String fileName;
  final String mimeType;
  _BlobAssembly({
    required int total,
    required this.fileName,
    required this.mimeType,
  }) : chunks = List<String?>.filled(total, null);
}

/// In-page download hook: download-flavoured anchors/forms are reported to
/// the `UcpDownload` JS channel instead of navigating the WebView (which
/// has no session-cookie download handling). `blob:` payloads and
/// `Content-Disposition: attachment` fetch responses — both invisible to
/// the native navigation delegate — are fetched, base64-chunked and
/// reassembled in Dart.
///
/// Public (not underscored) so tests can validate the script text: a JS
/// syntax slip here silently disables every in-page download trigger.
const downloadHookJs = '''
(function(){
if(window.__ucpDlHook)return;window.__ucpDlHook=true;
var EXTS=['pdf','doc','docx','xls','xlsx','ppt','pptx','csv','txt','zip','rar','7z','jpg','jpeg','png','gif','webp','mp4','mp3'];
function abs(u){try{return new URL(u,location.href).href;}catch(e){return '';}}
function post(m){try{UcpDownload.postMessage(JSON.stringify(m));}catch(e){}}
function isDl(u){try{var a=document.createElement('a');a.href=u;
var p=(a.pathname||'').toLowerCase();var q=(a.search||'').toLowerCase();
if(p.indexOf('/web/content')===0||p.indexOf('/web/binary')===0)return true;
if(p.indexOf('/report/pdf')===0||p.indexOf('/report/text')===0)return true;
var dot=p.lastIndexOf('.');if(dot>0&&EXTS.indexOf(p.slice(dot+1))>=0)return true;
if(q.indexOf('download')>=0)return true;return false;}catch(e){return false;}}
function sendChunked(id,b64,filename,mime){
var total=Math.ceil(b64.length/200000);if(total<1)total=1;
for(var i=0;i<total;i++){post({blobId:id,index:i,total:total,
chunk:b64.slice(i*200000,(i+1)*200000),filename:filename,mime:mime});}}
function sendBlob(url,filename){var id='b'+Date.now()+Math.floor(Math.random()*1e6);
fetch(url).then(function(r){return r.blob();}).then(function(b){
var rd=new FileReader();rd.onload=function(){var s=String(rd.result||'');
var b64=s.indexOf(',')>=0?s.slice(s.indexOf(',')+1):s;
sendChunked(id,b64,filename,b.type||'');};rd.readAsDataURL(b);}).catch(function(){
post({blobId:id,index:0,total:1,chunk:'',filename:filename,error:'fetch-failed'});});}
document.addEventListener('click',function(e){
var t=e.target&&e.target.closest?e.target.closest('a[href]'):null;if(!t)return;
var href=t.getAttribute('href');if(!href)return;
if(href.indexOf('blob:')===0){e.preventDefault();e.stopPropagation();
sendBlob(href,t.getAttribute('download')||'');return;}
if(t.hasAttribute('download')||isDl(href)){e.preventDefault();e.stopPropagation();
var u=abs(href);if(u)post({url:u,filename:t.getAttribute('download')||''});}
},true);
document.addEventListener('submit',function(e){
var f=e.target;if(!f||!f.action)return;
var a=abs(f.action);if(!a||a.indexOf('blob:')===0)return;
if(!isDl(a))return;
e.preventDefault();e.stopPropagation();
var method=((f.method||'get')+'').toLowerCase();
if(method==='post'){var fd={};try{var d=new FormData(f);
d.forEach(function(v,k){if(typeof v==='string')fd[k]=v;});}catch(err){}
post({url:a,method:'POST',fields:fd});return;}
var q=[];try{Array.prototype.forEach.call(f.elements,function(el){
if(!el.name||el.disabled)return;var t=((el.type||'')+'').toLowerCase();
if((t==='checkbox'||t==='radio')&&!el.checked)return;
if(t==='file'||t==='submit'||t==='button'||t==='image'||t==='reset')return;
q.push(encodeURIComponent(el.name)+'='+encodeURIComponent(el.value));});}catch(err){}
post({url:q.length?a+(a.indexOf('?')>=0?'&':'?')+q.join('&'):a});},true);
if(window.fetch){var rawFetch=window.fetch;
window.fetch=function(input,init){var url=typeof input==='string'?input:(input&&input.url)||'';
return rawFetch.apply(this,arguments).then(function(res){
try{var cd=res.headers.get('content-disposition')||'';
var ct=(res.headers.get('content-type')||'').toLowerCase();
if(cd.toLowerCase().indexOf('attachment')>=0&&ct.indexOf('text/html')<0){
return res.clone().arrayBuffer().then(function(buf){
var bytes=new Uint8Array(buf);var bin='';var CH=32768;var i;
for(i=0;i<bytes.length;i+=CH){bin+=String.fromCharCode.apply(null,bytes.subarray(i,i+CH));}
var b64='';try{b64=btoa(bin);}catch(err){return res;}
var id='f'+Date.now()+Math.floor(Math.random()*1e6);
var name='';var fnRe=new RegExp('filename\\*?=(?:UTF-8\'\'|")?([^";]+)','i');
var m=fnRe.exec(cd);
if(m){try{name=decodeURIComponent(m[1].replace(/"/g,''));}catch(err2){name=m[1];}}
sendChunked(id,b64,name,ct.split(';')[0]);
return new Response('',{status:200,headers:{'content-type':'text/plain'}});});}
}catch(e){}return res;});};}
if(window.open){var rawOpen=window.open;
window.open=function(u){var s=String(u||'');
if(s.indexOf('blob:')===0){sendBlob(s,'');return null;}
var a=abs(s);if(a&&isDl(a)){post({url:a,filename:''});return null;}
return rawOpen.apply(this,arguments);};}
})();
''';

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

  /// Controller cache: app.dart builds one tab screen at a time, so this
  /// State is disposed on every tab switch. The controller + loaded page
  /// survive here instead, and coming back to the tab reuses them with NO
  /// reload. A changed session id still forces a fresh login load.
  static WebViewController? _cachedController;
  static String? _cachedSid;
  static String _cachedPath = '/student/dashboard';
  static String _cachedUrl = 'https://horizon.ucp.edu.pk/student/dashboard';

  WebViewController? _controller;
  String _path = '/student/dashboard';
  String _currentUrl = _cachedUrl;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _editingUrl = false;
  final TextEditingController _urlField = TextEditingController();
  double _progress = 0;
  bool _expired = false;
  String? _resourceError;

  // --- Chrome-style downloads -------------------------------------------
  // The downloader + job list are static so an in-flight download survives
  // tab switches (this State is disposed on every tab change, like the
  // cached WebView controller above).
  static final PortalDownloader _downloader = PortalDownloader();
  static final List<PortalDownload> _downloads = [];
  StreamSubscription<PortalDownload>? _dlSub;
  int _unseenFinished = 0;
  bool _sheetOpen = false;
  String? _barDismissedForId;
  final Map<String, _BlobAssembly> _blobAsm = {};
  /// POST bodies by download URL so form downloads can be retried.
  final Map<String, Map<String, String>> _postSpecs = {};
  /// Last start time by URL for double-report dedupe (click + fetch hooks).
  final Map<String, DateTime> _recentStarts = {};

  @override
  void initState() {
    super.initState();
    _dlSub = _downloader.updates.listen(_onDownloadUpdate);
    if (widget.renderWebView) _initController();
  }

  @override
  void dispose() {
    _dlSub?.cancel();
    _urlField.dispose();
    super.dispose();
  }

  void _onDownloadUpdate(PortalDownload d) {
    final i = _downloads.indexWhere((e) => e.id == d.id);
    if (i >= 0) {
      _downloads[i] = d;
    } else {
      _downloads.add(d);
    }
    if (!d.isActive && !_sheetOpen && mounted) {
      _unseenFinished++;
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(WebViewScreen old) {
    super.didUpdateWidget(old);
    // Session healed in the background while this tab is open: re-seed the
    // cookie and reload so the portal never shows a stale login page.
    if (widget.sessionId != null &&
        widget.sessionId != old.sessionId &&
        _controller != null) {
      final uri = Uri.tryParse(_currentUrl);
      if (uri != null) {
        _loadUri(uri);
      } else {
        _loadPortal(_path);
      }
    }
  }

  Future<void> _initController() async {
    // Tab switch.dispose -> fresh State: reuse the live portal, no reload.
    if (_cachedController != null && _cachedSid == widget.sessionId) {
      if (!mounted) return;
      setState(() {
        _controller = _cachedController;
        _path = _cachedPath;
        _currentUrl = _cachedUrl;
      });
      unawaited(_updateNavState());
      return;
    }
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'UcpDownload',
        onMessageReceived: _onJsDownloadMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p / 100);
          },
          onPageFinished: (_) {
            // Hook in-page download triggers (links, forms, fetch,
            // blob popups). Verified + retried below so taps never die
            // silently; never breaks the page itself.
            unawaited(_injectDownloadHook());
            Future.delayed(const Duration(milliseconds: 800), () async {
              if (!mounted) return;
              try {
                final ok = await _controller
                    ?.runJavaScriptReturningResult(
                        'window.__ucpDlHook===true');
                if (ok != true) await _injectDownloadHook();
              } catch (_) {}
            });
            unawaited(_updateNavState());
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null && isPortalDownloadUrl(uri)) {
              _beginDownload(uri.toString());
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onUrlChange: _onUrl,
          onWebResourceError: (e) {
            // Sub-resource noise (trackers, fonts) is ignored — only a
            // failed main page gets an overlay with Retry.
            if (!mounted || e.isForMainFrame != true) return;
            setState(() {
              _resourceError = OfflineMonitor.instance.isOffline
                  ? offlineMessage
                  : 'Could not load the portal page. Tap Reload to try again.';
            });
          },
        ),
      );
    _controller = controller;
    await _loadPortal(_path);
  }

  /// Loads any URL in the viewport. The portal session cookie is seeded
  /// for Horizon only — never leaked to other sites.
  /// Installs the in-page download hook, then verifies it actually took:
  /// if the flag is missing (slow frame, dropped injection), it retries
  /// once instead of leaving taps silently dead.
  Future<void> _injectDownloadHook() async {
    try {
      await _controller?.runJavaScript(downloadHookJs);
    } catch (_) {}
  }

  Future<void> _loadUri(Uri uri) async {
    final controller = _controller;
    if (controller == null) return;
    if (uri.host == _host) {
      final sid = widget.sessionId;
      if (sid != null && sid.isNotEmpty) {
        try {
          await WebViewCookieManager().setCookie(
            WebViewCookie(
                name: 'session_id', value: sid, domain: _host, path: '/'),
          );
        } catch (_) {}
      }
    }
    if (!mounted) return;
    setState(() {
      _currentUrl = uri.toString();
      _editingUrl = false;
      _expired = false;
      _resourceError = null;
      if (uri.host == _host) _path = uri.path;
    });
    _cachedController = controller;
    _cachedSid = widget.sessionId;
    _cachedUrl = uri.toString();
    if (uri.host == _host) _cachedPath = uri.path;
    await controller.loadRequest(uri);
  }

  Future<void> _loadPortal(String path) async {
    await _loadUri(Uri.https(_host, path));
  }

  void _onUrl(UrlChange change) {
    final uri = change.url == null ? null : Uri.tryParse(change.url!);
    if (uri == null || !mounted) return;
    setState(() => _currentUrl = uri.toString());
    _cachedUrl = uri.toString();
    unawaited(_updateNavState());
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
      _cachedPath = uri.path;
    } else if (mounted) {
      setState(() => _expired = false);
    }
  }

  /// Refreshes back/forward availability after navigations.
  Future<void> _updateNavState() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    try {
      final back = await controller.canGoBack();
      final fwd = await controller.canGoForward();
      if (!mounted) return;
      if (back != _canGoBack || fwd != _canGoForward) {
        setState(() {
          _canGoBack = back;
          _canGoForward = fwd;
        });
      }
    } catch (_) {}
  }

  /// Go button / keyboard action in the URL bar.
  void _goToUrl(String text) {
    var t = text.trim();
    if (t.isEmpty) {
      setState(() => _editingUrl = false);
      return;
    }
    if (!t.contains('://')) t = 'https://$t';
    final uri = Uri.tryParse(t);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid web address.')),
        );
      }
      return;
    }
    if (widget.renderWebView) {
      _loadUri(uri);
    } else {
      setState(() {
        _currentUrl = uri.toString();
        _editingUrl = false;
      });
    }
  }

  // --- Downloads ----------------------------------------------------------

  /// Starts an authenticated download (fire-and-forget; progress arrives
  /// through [_onDownloadUpdate]). The portal cookie session is attached,
  /// so files the anonymous WebView request could never fetch still work.
  /// POST form downloads keep their fields for retry.
  Future<void> _beginDownload(
    String url, {
    String? fileName,
    String method = 'GET',
    Map<String, String>? fields,
    bool force = false,
  }) async {
    // Dedupe: the click hook and the fetch hook can both report the same
    // file within milliseconds — one download, not two bars.
    if (!force) {
      final last = _recentStarts[url];
      if (last != null &&
          DateTime.now().difference(last) < const Duration(seconds: 5)) {
        return;
      }
      _recentStarts[url] = DateTime.now();
    }
    _barDismissedForId = null;
    if (method == 'POST' && fields != null) {
      _postSpecs[url] = Map<String, String>.of(fields);
    }
    // Portal session stays on the portal: other sites download anonymously.
    final target = Uri.tryParse(url);
    final sid =
        (target != null && target.host == _host) ? widget.sessionId : null;
    final done = await _downloader.start(
      url: url,
      sessionId: sid,
      fileName: fileName?.isNotEmpty == true ? fileName : null,
      method: method,
      fields: fields,
    );
    await _afterDownload(done);
  }

  /// Messages from the in-page hook: direct links (downloaded here with the
  /// session cookie) and reassembled `blob:` payloads.
  void _onJsDownloadMessage(JavaScriptMessage message) {
    Map<String, dynamic>? msg;
    try {
      msg = Map<String, dynamic>.from(
          jsonDecode(message.message) as Map);
    } catch (_) {
      return;
    }
    if (msg.containsKey('chunk')) {
      _onBlobChunk(msg);
      return;
    }
    final url = '${msg['url'] ?? ''}';
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return;
    }
    final name = '${msg['filename'] ?? ''}';
    final method =
        '${msg['method'] ?? 'GET'}'.toUpperCase() == 'POST' ? 'POST' : 'GET';
    Map<String, String>? fields;
    final rawFields = msg['fields'];
    if (method == 'POST' && rawFields is Map) {
      fields = <String, String>{};
      rawFields.forEach((k, v) => fields!['$k'] = '$v');
    }
    _beginDownload(url,
        fileName: name.isEmpty ? null : name,
        method: method,
        fields: fields);
  }

  void _onBlobChunk(Map<String, dynamic> msg) async {
    final id = '${msg['blobId'] ?? ''}';
    if (id.isEmpty) return;
    if ('${msg['error'] ?? ''}'.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read that file.')),
        );
      }
      _blobAsm.remove(id);
      return;
    }
    final total = int.tryParse('${msg['total'] ?? 0}') ?? 0;
    final index = int.tryParse('${msg['index'] ?? -1}') ?? -1;
    if (total <= 0 || index < 0 || total > 5000) return;
    final asm = _blobAsm.putIfAbsent(
      id,
      () => _BlobAssembly(
        total: total,
        fileName: '${msg['filename'] ?? ''}',
        mimeType: '${msg['mime'] ?? ''}',
      ),
    );
    if (asm.chunks.length != total || index >= asm.chunks.length) return;
    asm.chunks[index] = '${msg['chunk'] ?? ''}';
    if (asm.chunks.any((c) => c == null)) return;
    _blobAsm.remove(id);
    List<int> bytes;
    try {
      bytes = base64Decode(asm.chunks.whereType<String>().join());
    } catch (_) {
      return;
    }
    _barDismissedForId = null;
    final done = await _downloader.saveBytes(
      url: 'blob:$id',
      bytes: bytes,
      sessionId: widget.sessionId,
      fileName: asm.fileName.isEmpty ? null : asm.fileName,
      mimeType: asm.mimeType,
    );
    await _afterDownload(done);
  }

  /// After the app-private copy lands: mirror into the phone's public
  /// Download folder (best-effort) and surface session death as re-login.
  Future<void> _afterDownload(PortalDownload done) async {
    if (done.status == DownloadStatus.complete && done.filePath != null) {
      final pub = await PublicDownloads.save(
        appFilePath: done.filePath!,
        fileName: done.fileName,
        mimeType: done.mimeType,
      );
      if (pub != null) {
        final i = _downloads.indexWhere((e) => e.id == done.id);
        if (i >= 0) {
          _downloads[i] = _downloads[i].copyWith(publicPath: pub);
          if (mounted) setState(() {});
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${done.fileName} downloaded')),
        );
      }
    } else if (done.sessionExpired) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired — sign in again to download.'),
          ),
        );
      }
      widget.onSessionExpired?.call();
    } else if (done.status == DownloadStatus.failed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(done.error ?? 'Download failed.')),
      );
    }
  }

  Future<void> _openDownload(PortalDownload d) async {
    final path = d.filePath;
    if (path == null) return;
    final res = await OpenFilex.open(path);
    if (!mounted) return;
    if (res.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved as ${d.fileName} — no app to open it.')),
      );
    }
  }

  void _retryDownload(PortalDownload d) {
    final i = _downloads.indexWhere((e) => e.id == d.id);
    if (i >= 0 && mounted) {
      setState(() => _downloads.removeAt(i));
    }
    final fields = _postSpecs[d.url];
    _beginDownload(
      d.url,
      method: fields == null ? 'GET' : 'POST',
      fields: fields,
      force: true,
    );
  }

  Future<void> _deleteDownload(PortalDownload d) async {
    _downloader.cancel(d.id);
    final i = _downloads.indexWhere((e) => e.id == d.id);
    if (i >= 0 && mounted) {
      setState(() => _downloads.removeAt(i));
    }
    final path = d.filePath;
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  PortalDownload? get _trayItem {
    for (var i = _downloads.length - 1; i >= 0; i--) {
      final d = _downloads[i];
      if (d.isActive && _barDismissedForId != d.id) return d;
    }
    for (var i = _downloads.length - 1; i >= 0; i--) {
      final d = _downloads[i];
      if (!d.isActive && _barDismissedForId != d.id) return d;
    }
    return null;
  }

  void _openDownloadsSheet() {
    _sheetOpen = true;
    if (mounted) setState(() => _unseenFinished = 0);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DownloadsSheet(
        initial: List<PortalDownload>.of(_downloads),
        updates: _downloader.updates,
        onOpen: _openDownload,
        onCancel: (d) => _downloader.cancel(d.id),
        onRetry: _retryDownload,
        onDelete: _deleteDownload,
        saveLocationLabel: Platform.isAndroid
            ? 'Downloads/UCP folder'
            : 'app files',
      ),
    ).whenComplete(() {
      _sheetOpen = false;
      if (mounted) setState(() => _unseenFinished = 0);
    });
  }

  /// Firefox-style address bar: compact pill with a readable URL
  /// (domain in bold), tap to edit + go anywhere, reload tucked inside.
  Widget _omnibox(AppColors c) {
    final barColor = Colors.white.withValues(alpha: 0.16);
    if (_editingUrl) {
      return Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
            color: barColor, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            const SizedBox(width: 8),
            const Icon(Icons.search, size: 17, color: Colors.white70),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _urlField,
                autofocus: true,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                style:
                    const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search or enter address',
                  hintStyle:
                      TextStyle(color: Colors.white54, fontSize: 14),
                  isDense: true,
                ),
                onSubmitted: _goToUrl,
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _editingUrl = false),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.close,
                    size: 17, color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }
    final secure = _currentUrl.startsWith('https://');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _urlField.text = _currentUrl;
        _urlField.selection = TextSelection(
            baseOffset: 0, extentOffset: _urlField.text.length);
        setState(() => _editingUrl = true);
      },
      child: Container(
        height: 40,
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
            color: barColor, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Icon(secure ? Icons.lock_outline : Icons.lock_open_outlined,
                size: 14,
                color: secure ? Colors.white : Colors.white70),
            const SizedBox(width: 6),
            Expanded(child: _urlText()),
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                tooltip: 'Reload',
                padding: EdgeInsets.zero,
                iconSize: 17,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(32, 32),
                ),
                color: Colors.white,
                icon: const Icon(Icons.refresh),
                onPressed: widget.renderWebView
                    ? () => _controller?.reload()
                    : () => setState(() {}),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// URL readout with the domain emphasized, Firefox-style.
  Widget _urlText() {
    const shownStyle = TextStyle(color: Colors.white70, fontSize: 14);
    const hostStyle = TextStyle(
        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700);
    final shown = _currentUrl.replaceFirst(RegExp(r'^https?://'), '');
    final uri = Uri.tryParse(_currentUrl);
    final host =
        (uri != null && uri.host.isNotEmpty) ? uri.host : null;
    if (host == null || !shown.startsWith(host)) {
      return Text(shown,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: shownStyle);
    }
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: [
        TextSpan(text: host, style: hostStyle),
        TextSpan(text: shown.substring(host.length), style: shownStyle),
      ]),
    );
  }

  /// Slim flat toolbar button (back / forward).
  Widget _flatNavButton(
      IconData icon, bool enabled, VoidCallback? onTap) {
    return SizedBox(
      width: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 20,
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: const Size(32, 32),
        ),
        color: Colors.white,
        disabledColor: Colors.white38,
        icon: Icon(icon),
        onPressed: enabled ? onTap : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final tray = _trayItem;
    return UHead(
      height: 108,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _flatNavButton(Icons.arrow_back, _canGoBack,
                  () => _controller?.goBack()),
              _flatNavButton(Icons.arrow_forward, _canGoForward,
                  () => _controller?.goForward()),
              Expanded(child: _omnibox(c)),
              const SizedBox(width: 6),
              DownloadIconButton(
                activeCount: _downloads.where((d) => d.isActive).length,
                pendingCount: _unseenFinished,
                onTap: _openDownloadsSheet,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Chrome-style loading bar: full-width, pinned above the
          // viewport (not inside the rounded frame).
          SizedBox(
            height: 3,
            child: (_progress > 0 && _progress < 1)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(c.board),
                      minHeight: 3,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
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
                    WebViewWidget(
                      controller: _controller!,
                      // All touches go to the portal (scroll, tap, pinch):
                      // without this the outer page scroll steals gestures
                      // and the portal feels frozen.
                      gestureRecognizers: {
                        Factory<OneSequenceGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                        ),
                      },
                    )
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
                  if (tray != null)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: DownloadBar(
                        item: tray,
                        onOpen: () => _openDownload(tray),
                        onCancel: () => _downloader.cancel(tray.id),
                        onDismiss: () => setState(
                            () => _barDismissedForId = tray.id),
                        onShowAll: _openDownloadsSheet,
                      ),
                    ),
                  if (_resourceError != null && !_expired)
                    Positioned.fill(
                      child: Container(
                        color: c.cream2.withValues(alpha: 0.97),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off_outlined,
                                size: 36, color: c.clay),
                            const SizedBox(height: 12),
                            Text(_resourceError!,
                                style: display(c, size: 16),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ClayButton(
                              label: 'Retry',
                              colors: c,
                              height: 48,
                              fontSize: 15,
                              onPressed: () => _loadPortal(_path),
                            ),
                          ],
                        ),
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
