/// Microsoft OAuth (Authorization Code flow) against UCP's Odoo portal.
///
/// Deep analysis of UCP's production login link (verified live on
/// https://horizon.ucp.edu.pk/web/login):
///
///   https://login.microsoftonline.com/common/oauth2/v2.0/authorize
///     ?client_id=4a6562df-f309-48d2-94c2-16d03a5c3644
///     &response_type=code
///     &redirect_uri=https%3A%2F%2Fhorizon.ucp.edu.pk%2Fauth_oauth%2Fmicrosoft%2Fsignin
///     &prompt=select_account
///     &scope=User.Read+Mail.Read+User.ReadWrite.All+Contacts.ReadWrite
///
/// Meaning of each parameter:
/// - authority `.../common/...`       : multi-tenant; accepts any Microsoft
///   account, UCP then matches the `@ucp.edu.pk` domain on its backend.
/// - `client_id`                      : UCP Horizon's app registration in
///   Entra ID. Public identifier, safe to ship in the app.
/// - `response_type=code`             : server-side Authorization Code flow.
///   The secret (`client_secret`) lives on Odoo; the app never sees it.
/// - `redirect_uri`                   : Odoo's `auth_oauth` callback. Microsoft
///   returns `?code=...` here, Odoo exchanges the code for tokens, creates
///   the user session and answers with `Set-Cookie: session_id=...`.
/// - `prompt=select_account`          : always show the account picker.
/// - `scope`                          : Microsoft Graph permissions the UCP app
///   registration requests (read profile + mail + read/write users/contacts).
///
/// What the app ADDS (and why it is safe):
/// - `login_hint=<typed email>`       : official Microsoft parameter that only
///   PRE-FILLS the username box. No password ever travels in a URL.
/// - Nothing else. In particular there is NO `state`: UCP's production link
///   carries none, so the backend tolerates stateless callbacks; sending a
///   custom state could break their handler.
///
/// What the app MUST NOT do:
/// - It cannot and must not "enter the password into the URL". OAuth has no
///   password parameter; the password is typed by the USER on Microsoft's
///   own page (MFA/conditional-access safe). Automating that page is bot-like,
///   triggers Microsoft risk blocks, and would force the app to handle raw
///   passwords — a security anti-pattern.
///
/// After login, "the token on horizon.ucp.edu.pk" is Odoo's `session_id`
/// cookie, captured from the WebView cookie store and used for JSON-RPC.
library;

class MicrosoftOAuth {
  static const authorityHost = 'login.microsoftonline.com';
  static const authorizePath = '/common/oauth2/v2.0/authorize';
  static const clientId = '4a6562df-f309-48d2-94c2-16d03a5c3644';
  static const redirectHost = 'horizon.ucp.edu.pk';
  static const redirectPath = '/auth_oauth/microsoft/signin';
  static const prompt = 'select_account';

  /// Exact scopes from UCP's production login link.
  static const scopes = [
    'User.Read',
    'Mail.Read',
    'User.ReadWrite.All',
    'Contacts.ReadWrite',
  ];

  /// Home-realm hint so Microsoft routes `@ucp.edu.pk` straight to the
  /// right sign-in path (skips realm discovery; ignored for managed
  /// domains). Safe on both interactive and silent URLs.
  static const domainHint = 'ucp.edu.pk';

  /// Builds the authorization URL. Mirrors production bit-for-bit, plus an
  /// optional `login_hint` pre-fill (consumed by Microsoft only; never
  /// echoed back to Odoo, so the backend flow is unaffected).
  static Uri buildAuthorizeUrl({String? loginHint}) {
    final params = <String, String>{
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': 'https://$redirectHost$redirectPath',
      'prompt': prompt,
      'scope': scopes.join(' '),
      'domain_hint': domainHint,
      if (loginHint != null && loginHint.trim().isNotEmpty)
        'login_hint': loginHint.trim(),
    };
    return Uri.https(authorityHost, authorizePath, params);
  }

  /// Silent-renewal URL (OpenID Connect `prompt=none`).
  ///
  /// Loads invisibly in a background WebView: if the user still has a live
  /// Microsoft SSO session, Microsoft immediately redirects back with a
  /// fresh `code` — no taps, no password. Otherwise it returns an
  /// `interaction_required`-style error and the app falls back to the
  /// interactive sign-in. `login_hint` is REQUIRED here so Microsoft can
  /// pick the right account without asking.
  static Uri buildSilentUrl({required String loginHint}) {
    return Uri.https(authorityHost, authorizePath, {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': 'https://$redirectHost$redirectPath',
      'prompt': 'none',
      'scope': scopes.join(' '),
      'domain_hint': domainHint,
      'login_hint': loginHint.trim(),
    });
  }

  /// Microsoft error codes that mean "I cannot proceed silently — show UI".
  static bool isInteractionError(String code) {
    return const {
      'interaction_required',
      'login_required',
      'consent_required',
      'account_selection_needed',
    }.contains(code);
  }

  /// User-facing message when a silent renewal fails.
  ///
  /// [code] is the Microsoft error, `'timeout'` when Microsoft never
  /// answered, or `'no_session'` when Odoo consumed the code but issued no
  /// session cookie.
  static String renewFailureMessage(String code) {
    if (isInteractionError(code)) {
      return 'Your Microsoft sign-in expired (about a month old). '
          'Please sign in again — then you are silent for another month.';
    }
    switch (code) {
      case 'timeout':
        return 'Could not reach Microsoft. Check your connection and try again.';
      case 'no_session':
        return 'The portal did not create a session. Please sign in again.';
      default:
        return 'Automatic sign-in failed ($code). Please sign in again.';
    }
  }

  static bool isMicrosoftHost(Uri uri) =>
      uri.host.toLowerCase() == authorityHost;

  /// True when [uri] is Odoo's OAuth callback (Microsoft redirected back
  /// with `?code=...` or `?error=...`).
  static bool isCallbackUrl(Uri uri) =>
      uri.host.toLowerCase() == redirectHost && uri.path == redirectPath;

  /// Outcome of a callback URL, or null when it carries neither.
  /// Returns {'status': 'code'|'error', 'value': ..., 'description': ...?}.
  static Map<String, String>? callbackOutcome(Uri uri) {
    if (!isCallbackUrl(uri)) return null;
    final error = uri.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      return {
        'status': 'error',
        'value': error,
        'description': uri.queryParameters['error_description'] ?? '',
      };
    }
    final code = uri.queryParameters['code'];
    if (code != null && code.isNotEmpty) {
      return {'status': 'code', 'value': code};
    }
    return null;
  }

  /// True when the WebView has landed back on the portal OUTSIDE the
  /// callback/login pages — i.e. Odoo consumed the code and let the user in.
  /// The caller must still confirm a `session_id` cookie exists.
  static bool isPortalLanding(Uri uri) {
    if (uri.host.toLowerCase() != redirectHost) return false;
    if (uri.path == redirectPath) return false;
    if (uri.path.startsWith('/web/login')) return false;
    return true;
  }
}
