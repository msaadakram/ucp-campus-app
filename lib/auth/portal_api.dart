import 'package:http/http.dart' as http;

import 'odoo_api.dart';

/// Authenticated portal page fetcher: same `session_id` cookie the login
/// flow captures, sent as a plain HTTPS GET.
///
/// Odoo answers two ways when the session is dead: a 303 redirect to
/// `/web/login`, or (some configs) a 200 login form. Both map to
/// [OdooApiException] so callers funnel into the existing renew-then-retry
/// handling instead of parsing a login page as data.
class PortalApi {
  static const host = OdooApi.host;

  final http.Client _client;
  PortalApi([http.Client? client]) : _client = client ?? http.Client();

  Future<String> fetchPage(String path, String sessionId) async {
    final res = await _client
        .get(
          Uri.https(host, path),
          headers: {
            'Cookie': 'session_id=$sessionId',
            'User-Agent': 'UCP-Campus-App/1.0',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 301 ||
        res.statusCode == 302 ||
        res.statusCode == 303 ||
        res.statusCode == 307) {
      final location = res.headers['location'] ?? '';
      if (location.contains('/web/login')) {
        throw OdooApiException('session expired (redirected to login)');
      }
      throw OdooApiException('unexpected redirect: $location');
    }
    if (res.statusCode != 200) {
      throw OdooApiException('HTTP ${res.statusCode} from $path');
    }
    if (res.body.contains('oe_login_form') ||
        res.body.contains('action="/web/login"')) {
      throw OdooApiException('session expired (login form returned)');
    }
    return res.body;
  }

  Future<String> fetchDashboard(String sessionId) =>
      fetchPage('/student/dashboard', sessionId);

  void close() => _client.close();
}
