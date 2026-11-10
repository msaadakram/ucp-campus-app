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

  /// Raw bytes of a portal resource with the session cookie attached.
  ///
  /// Used for the dashboard avatar: portal images typically require the
  /// session, so classmates can't just be handed the `/web/image/…` URL.
  /// Absolute http(s) URLs and root-relative paths are both accepted.
  /// Returns null on any failure (anonymous 404, expired session, etc.).
  Future<List<int>?> fetchBytes(String url, String sessionId) async {
    final uri = url.startsWith('http')
        ? Uri.tryParse(url)
        : Uri.https(OdooApi.host, url);
    if (uri == null) return null;
    final res = await _client
        .get(
          uri,
          headers: {
            'Cookie': 'session_id=$sessionId',
            'User-Agent': 'UCP-Campus-App/1.0',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) return null;
    if (res.bodyBytes.isEmpty) return null;
    return res.bodyBytes;
  }

  /// MIME sniff for portal image bytes. Defaults to JPEG (what the
  /// portal serves) — the four signatures cover JPEG/PNG/WebP/GIF.
  static String sniffImageMime(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    if (bytes.length >= 4 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'GIF8') {
      return 'image/gif';
    }
    return 'image/jpeg';
  }

  void close() => _client.close();
}
