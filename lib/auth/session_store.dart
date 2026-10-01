import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted on-device storage for the Horizon portal session.
///
/// Only the Odoo `session_id` (opaque session cookie) and the login email
/// are kept. The user's Microsoft password is NEVER stored — it is typed
/// once on Microsoft's own page and never touches the app.
class SessionStore {
  static const _kSessionId = 'ucp_horizon_session_id';
  static const _kEmail = 'ucp_login_email';

  final FlutterSecureStorage _storage;
  SessionStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveSession({required String sessionId, required String email}) async {
    await _storage.write(key: _kSessionId, value: sessionId);
    await _storage.write(key: _kEmail, value: email);
  }

  Future<String?> readSessionId() => _storage.read(key: _kSessionId);
  Future<String?> readEmail() => _storage.read(key: _kEmail);

  Future<void> clear() async {
    await _storage.delete(key: _kSessionId);
    await _storage.delete(key: _kEmail);
  }
}
