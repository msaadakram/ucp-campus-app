import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/auth/microsoft_oauth.dart';

void main() {
  group('authorize URL (mirrors UCP production login link)', () {
    test('exact parameters without login hint', () {
      final url = MicrosoftOAuth.buildAuthorizeUrl();
      expect(url.scheme, 'https');
      expect(url.host, 'login.microsoftonline.com');
      expect(url.path, '/common/oauth2/v2.0/authorize');
      final q = url.queryParameters;
      expect(q['client_id'], '4a6562df-f309-48d2-94c2-16d03a5c3644');
      expect(q['response_type'], 'code');
      expect(
        q['redirect_uri'],
        'https://horizon.ucp.edu.pk/auth_oauth/microsoft/signin',
      );
      expect(q['prompt'], 'select_account');
      expect(
        q['scope'],
        'User.Read Mail.Read User.ReadWrite.All Contacts.ReadWrite',
      );
      expect(q.containsKey('login_hint'), isFalse);
      expect(q.containsKey('state'), isFalse);
    });

    test('login hint is appended and encoded', () {
      final url = MicrosoftOAuth.buildAuthorizeUrl(
        loginHint: 'l1f25bscs0577@ucp.edu.pk',
      );
      expect(
        url.queryParameters['login_hint'],
        'l1f25bscs0577@ucp.edu.pk',
      );
      expect(url.toString(), contains('login_hint='));
      // Base params unchanged.
      expect(url.queryParameters['client_id'], MicrosoftOAuth.clientId);
    });

    test('blank login hint is ignored', () {
      final url = MicrosoftOAuth.buildAuthorizeUrl(loginHint: '   ');
      expect(url.queryParameters.containsKey('login_hint'), isFalse);
    });
  });

  group('silent renewal URL (prompt=none)', () {
    test('uses prompt=none and keeps production params', () {
      final url = MicrosoftOAuth.buildSilentUrl(
        loginHint: 'l1f25bscs0577@ucp.edu.pk',
      );
      final q = url.queryParameters;
      expect(q['prompt'], 'none');
      expect(q['client_id'], MicrosoftOAuth.clientId);
      expect(q['response_type'], 'code');
      expect(
        q['redirect_uri'],
        'https://horizon.ucp.edu.pk/auth_oauth/microsoft/signin',
      );
      expect(
        q['scope'],
        'User.Read Mail.Read User.ReadWrite.All Contacts.ReadWrite',
      );
      expect(q['login_hint'], 'l1f25bscs0577@ucp.edu.pk');
    });

    test('interaction error classification', () {
      for (final code in [
        'interaction_required',
        'login_required',
        'consent_required',
        'account_selection_needed',
      ]) {
        expect(MicrosoftOAuth.isInteractionError(code), isTrue);
      }
      expect(MicrosoftOAuth.isInteractionError('access_denied'), isFalse);
      expect(MicrosoftOAuth.isInteractionError('invalid_request'), isFalse);
    });
  });

  group('URL classifiers', () {
    test('microsoft host detection', () {
      expect(
        MicrosoftOAuth.isMicrosoftHost(Uri.parse(
            'https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=x')),
        isTrue,
      );
      expect(
        MicrosoftOAuth.isMicrosoftHost(
            Uri.parse('https://horizon.ucp.edu.pk/web/login')),
        isFalse,
      );
    });

    test('callback detection + code outcome', () {
      final cb = Uri.parse(
          'https://horizon.ucp.edu.pk/auth_oauth/microsoft/signin?code=AUTHCODE123');
      expect(MicrosoftOAuth.isCallbackUrl(cb), isTrue);
      expect(
        MicrosoftOAuth.callbackOutcome(cb),
        {'status': 'code', 'value': 'AUTHCODE123'},
      );
    });

    test('callback error outcome (user cancelled)', () {
      final cb = Uri.parse(
          'https://horizon.ucp.edu.pk/auth_oauth/microsoft/signin?error=access_denied&error_description=user+cancelled');
      expect(
        MicrosoftOAuth.callbackOutcome(cb),
        {
          'status': 'error',
          'value': 'access_denied',
          'description': 'user cancelled',
        },
      );
    });

    test('non-callback has no outcome', () {
      expect(
        MicrosoftOAuth.callbackOutcome(
            Uri.parse('https://horizon.ucp.edu.pk/web')),
        isNull,
      );
      expect(
        MicrosoftOAuth.callbackOutcome(
            Uri.parse('https://horizon.ucp.edu.pk/auth_oauth/microsoft/signin')),
        isNull,
      );
    });

    test('portal landing detection', () {
      expect(
        MicrosoftOAuth.isPortalLanding(Uri.parse('https://horizon.ucp.edu.pk/web')),
        isTrue,
      );
      expect(
        MicrosoftOAuth.isPortalLanding(Uri.parse(
            'https://horizon.ucp.edu.pk/auth_oauth/microsoft/signin?code=x')),
        isFalse,
      );
      expect(
        MicrosoftOAuth.isPortalLanding(
            Uri.parse('https://horizon.ucp.edu.pk/web/login')),
        isFalse,
      );
      expect(
        MicrosoftOAuth.isPortalLanding(
            Uri.parse('https://login.microsoftonline.com/common/oauth2')),
        isFalse,
      );
    });
  });
}
