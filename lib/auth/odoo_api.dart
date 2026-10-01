import 'dart:convert';

import 'package:http/http.dart' as http;

/// Minimal Odoo JSON-RPC client authenticated with the `session_id` cookie
/// captured after Microsoft OAuth.
///
/// Verified live against https://horizon.ucp.edu.pk:
/// - `/web/session/get_lang_list` answers JSON-RPC without auth.
/// - `/web/session/get_session_info` answers 200 with the session cookie and
///   reports `uid` (a real user id when logged in, `false` for anonymous).
class OdooApi {
  static const host = 'horizon.ucp.edu.pk';

  /// Bounds every portal call so auto-login can never hang the UI forever.
  static const apiTimeout = Duration(seconds: 15);

  final http.Client _client;
  OdooApi([http.Client? client]) : _client = client ?? http.Client();

  Uri _uri(String path) => Uri.https(host, path);

  Map<String, String> _headers(String sessionId) => {
        'Content-Type': 'application/json',
        'Cookie': 'session_id=$sessionId',
      };

  Future<Map<String, dynamic>> _call(
    String path,
    Map<String, dynamic> params,
    String sessionId,
  ) async {
    final res = await _client
        .post(
          _uri(path),
          headers: _headers(sessionId),
          body:
              jsonEncode({'jsonrpc': '2.0', 'method': 'call', 'params': params}),
        )
        .timeout(apiTimeout);
    if (res.statusCode != 200) {
      throw OdooApiException('HTTP ${res.statusCode} from $path');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (decoded['error'] != null) {
      throw OdooApiException('Odoo error: ${decoded['error']}');
    }
    return (decoded['result'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Returns session info; `uid` is an int when [sessionId] is a live login.
  Future<Map<String, dynamic>> getSessionInfo(String sessionId) =>
      _call('/web/session/get_session_info', {}, sessionId);

  /// True when the session belongs to a logged-in portal user.
  Future<bool> isSessionValid(String sessionId) async {
    try {
      final info = await getSessionInfo(sessionId);
      return info['uid'] is int;
    } catch (_) {
      return false;
    }
  }

  void close() => _client.close();
}

class OdooApiException implements Exception {
  final String message;
  OdooApiException(this.message);
  @override
  String toString() => 'OdooApiException: $message';
}
