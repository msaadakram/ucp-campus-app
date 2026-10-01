import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_manager.dart';

/// Encrypted on-device storage for the Horizon portal session.
///
/// Only the Odoo `session_id` (opaque session cookie) and the login email
/// are kept. The user's Microsoft password is NEVER stored — it is typed
/// once on Microsoft's own page and never touches the app.
class SessionStore implements SessionBackend {
  static const _kSessionId = 'ucp_horizon_session_id';
  static const _kEmail = 'ucp_login_email';
  static const _kSavedAt = 'ucp_horizon_session_saved_at_ms';
  static const _kDashboard = 'ucp_horizon_dashboard_json';

  final FlutterSecureStorage _storage;
  SessionStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveSession({required String sessionId, required String email}) async {
    await save(sessionId: sessionId, email: email);
  }

  @override
  Future<void> save({required String sessionId, required String email}) async {
    await _storage.write(key: _kSessionId, value: sessionId);
    await _storage.write(key: _kEmail, value: email);
    await _storage.write(
      key: _kSavedAt,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  @override
  Future<({String sessionId, String email})?> load() async {
    final sid = await _storage.read(key: _kSessionId);
    final email = await _storage.read(key: _kEmail);
    if (sid == null || sid.isEmpty || email == null || email.isEmpty) {
      return null;
    }
    return (sessionId: sid, email: email);
  }

  Future<String?> readSessionId() => _storage.read(key: _kSessionId);
  Future<String?> readEmail() => _storage.read(key: _kEmail);

  /// Epoch millis when the session was last saved, or null if unknown.
  @override
  Future<int?> savedAtMs() async {
    final raw = await _storage.read(key: _kSavedAt);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<int?> readSavedAtMs() => savedAtMs();

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kSessionId);
    await _storage.delete(key: _kEmail);
    await _storage.delete(key: _kSavedAt);
    await _storage.delete(key: _kDashboard);
  }

  @override
  Future<void> saveDashboard(String json) =>
      _storage.write(key: _kDashboard, value: json);

  @override
  Future<String?> loadDashboard() => _storage.read(key: _kDashboard);
}
