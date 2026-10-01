import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../auth/microsoft_oauth.dart';
import '../auth/odoo_api.dart';

/// Invisible `prompt=none` renewal: new portal session, zero taps.
///
/// Mounted at 1x1 px inside an [IgnorePointer] by the app shell whenever a
/// silent renewal is needed (cold start with a stale session, resume with a
/// stale session, expired-session API failure). Either [onRenewed] with a
/// verified `session_id` or [onInteractionRequired] fires exactly once, then
/// the shell unmounts this widget. A [timeout] guards against hanging loads.
class SilentRenewWebView extends StatefulWidget {
  final String email;
  final void Function(String sessionId) onRenewed;
  final VoidCallback onInteractionRequired;
  final Duration timeout;

  const SilentRenewWebView({
    super.key,
    required this.email,
    required this.onRenewed,
    required this.onInteractionRequired,
    this.timeout = const Duration(seconds: 25),
  });

  @override
  State<SilentRenewWebView> createState() => _SilentRenewWebViewState();
}

class _SilentRenewWebViewState extends State<SilentRenewWebView> {
  late final WebViewController _controller;
  final WebViewCookieManager _cookies = WebViewCookieManager();
  final OdooApi _api = OdooApi();
  Timer? _timer;
  bool _done = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(onUrlChange: _onUrl),
      )
      ..loadRequest(MicrosoftOAuth.buildSilentUrl(loginHint: widget.email));
    _timer = Timer(widget.timeout, () => _finish(interaction: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _api.close();
    super.dispose();
  }

  void _finish({required bool interaction, String? sessionId}) {
    if (_done || !mounted) return;
    _done = true;
    _timer?.cancel();
    if (interaction || sessionId == null) {
      widget.onInteractionRequired();
    } else {
      widget.onRenewed(sessionId);
    }
  }

  Future<void> _onUrl(UrlChange change) async {
    final uri = change.url == null ? null : Uri.tryParse(change.url!);
    if (uri == null || _done) return;

    final outcome = MicrosoftOAuth.callbackOutcome(uri);
    if (outcome != null) {
      // Any error under prompt=none means "ask the user" — including
      // access_denied. A code is consumed by Odoo; the landing follows.
      if (outcome['status'] == 'error') {
        _finish(interaction: true);
      }
      return;
    }

    if (!MicrosoftOAuth.isPortalLanding(uri)) return;
    if (_busy) return;
    _busy = true;
    try {
      String? sessionId;
      final cookies = await _cookies.getCookies(
        domain: Uri.https(MicrosoftOAuth.redirectHost),
      );
      for (final c in cookies) {
        if (c.name == 'session_id' && c.value.isNotEmpty) {
          sessionId = c.value;
          break;
        }
      }
      if (sessionId != null && await _api.isSessionValid(sessionId)) {
        _finish(interaction: false, sessionId: sessionId);
      }
      // Else: keep waiting for the landing/cookie (or the timeout).
    } catch (_) {
      // Transient network failure: keep waiting for the timeout.
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1x1 px: keeps a real layout box so the page (and its JavaScript)
    // actually runs, while staying invisible. The parent wraps this in an
    // IgnorePointer so it can never steal taps.
    return SizedBox(
      width: 1,
      height: 1,
      child: WebViewWidget(controller: _controller),
    );
  }
}
