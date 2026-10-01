import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../auth/microsoft_oauth.dart';
import '../auth/odoo_api.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';

/// Hosts the interactive Microsoft sign-in inside the app and captures the
/// resulting Horizon portal session.
///
/// Flow:
/// 1. Loads [MicrosoftOAuth.buildAuthorizeUrl] (with `login_hint`).
/// 2. The USER types their password on Microsoft's own page. The app never
///    sees it and must not automate it.
/// 3. Microsoft redirects to Odoo's callback with `?code=...`; Odoo
///    exchanges the code server-side and answers `Set-Cookie: session_id`.
/// 4. When the WebView lands on the portal, we read `session_id` from the
///    cookie store, verify it with `/web/session/get_session_info`, then
///    report it via [onAuthenticated].
class OAuthWebView extends StatefulWidget {
  final String email;
  final void Function(String sessionId) onAuthenticated;
  final VoidCallback onCancelled;
  final void Function(String message) onError;

  const OAuthWebView({
    super.key,
    required this.email,
    required this.onAuthenticated,
    required this.onCancelled,
    required this.onError,
  });

  @override
  State<OAuthWebView> createState() => _OAuthWebViewState();
}

class _OAuthWebViewState extends State<OAuthWebView> {
  late final WebViewController _controller;
  final WebViewCookieManager _cookies = WebViewCookieManager();
  final OdooApi _api = OdooApi();
  double _progress = 0;
  bool _busy = false;
  bool _done = false;
  bool _sawCallback = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => mounted ? setState(() => _progress = p / 100) : null,
          onUrlChange: _onUrl,
        ),
      )
      ..loadRequest(MicrosoftOAuth.buildAuthorizeUrl(loginHint: widget.email));
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _onUrl(UrlChange change) async {
    final raw = change.url;
    if (raw == null || _done) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;

    final outcome = MicrosoftOAuth.callbackOutcome(uri);
    if (outcome != null) {
      if (outcome['status'] == 'error') {
        _fail(_friendlyError(outcome['value']!, outcome['description'] ?? ''));
        return;
      }
      _sawCallback = true;
      setState(() => _status = 'Verifying with UCP portal…');
      return; // let Odoo consume the code; landing page comes next
    }

    if (MicrosoftOAuth.isPortalLanding(uri)) {
      await _tryComplete();
    }
  }

  Future<void> _tryComplete() async {
    if (_busy || _done || !mounted) return;
    _busy = true;
    try {
      final cookies = await _cookies.getCookies(
        domain: Uri.https(MicrosoftOAuth.redirectHost),
      );
      String? sessionId;
      for (final c in cookies) {
        if (c.name == 'session_id' && c.value.isNotEmpty) {
          sessionId = c.value;
          break;
        }
      }
      if (sessionId == null) {
        if (_sawCallback && mounted) {
          setState(() => _status =
              'Portal did not create a session. Please try again.');
        }
        return;
      }
      final valid = await _api.isSessionValid(sessionId);
      if (!mounted || _done) return;
      if (valid) {
        _done = true;
        widget.onAuthenticated(sessionId);
      } else if (_sawCallback) {
        setState(
            () => _status = 'Session invalid. Please sign in again.');
      }
    } catch (_) {
      if (mounted && _sawCallback && !_done) {
        setState(() => _status = 'Network error. Please try again.');
      }
    } finally {
      _busy = false;
    }
  }

  void _fail(String message) {
    if (_done || !mounted) return;
    _done = true;
    widget.onError(message);
  }

  String _friendlyError(String code, String description) {
    switch (code) {
      case 'access_denied':
        return 'Sign-in was cancelled before completing.';
      case 'login_required':
      case 'interaction_required':
        return 'Microsoft asked for more verification. Please try again.';
      default:
        return description.isNotEmpty
            ? 'Microsoft sign-in failed: $description'
            : 'Microsoft sign-in failed ($code).';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 48, 8, 8),
          decoration: BoxDecoration(
            color: c.cream2,
            border: Border(bottom: BorderSide(color: c.dustSoft)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: widget.onCancelled,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.dustSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('UCP Microsoft sign-in',
                        style: display(c, size: 16)),
                    Text(
                      _status ?? widget.email,
                      style: body(
                        c,
                        size: 12,
                        color: c.tealInk.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.lock_outline, size: 18, color: c.teal),
            ],
          ),
        ),
        if (_progress < 1)
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: c.dustSoft,
            valueColor: AlwaysStoppedAnimation(c.teal),
            minHeight: 3,
          ),
        Expanded(child: WebViewWidget(controller: _controller)),
      ],
    );
  }
}
