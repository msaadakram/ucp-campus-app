/// All WebView work stays in the UI layer. This class is pure logic over a
/// tiny storage interface, so it is fully unit-testable.
library;

import 'odoo_api.dart';

/// Thrown when the user must see the interactive sign-in (no stored
/// session, silent renewal refused/failed, network down, ...).
class AuthRequired implements Exception {
  final String reason;
  AuthRequired(this.reason);
  @override
  String toString() => 'AuthRequired: $reason';
}

/// Minimal storage contract (implemented by [SecureSessionBackend]).
abstract class SessionBackend {
  Future<void> save({required String sessionId, required String email});
  Future<({String sessionId, String email})?> load();
  Future<int?> savedAtMs();
  Future<void> clear();
}

/// Result of [SessionManager.ensureValidSession].
class ValidSession {
  final String sessionId;
  final String email;
  /// True when the session came from a fresh silent renewal.
  final bool renewed;
  ValidSession(this.sessionId, this.email, {this.renewed = false});
}

class SessionManager {
  /// Portal sessions die after ~15 minutes; refresh proactively at 10 so a
  /// renewal is (almost) never user-visible.
  static const staleAfter = Duration(minutes: 10);

  final SessionBackend store;
  final OdooApi api;

  SessionManager({required this.store, required this.api});

  bool isStale(int? savedAtMs, DateTime now) {
    if (savedAtMs == null) return true;
    return now.millisecondsSinceEpoch - savedAtMs > staleAfter.inMilliseconds;
  }

  /// Returns a usable session, renewing silently when needed.
  ///
  /// [renew] runs the hidden `prompt=none` WebView and resolves with the new
  /// `session_id`, or `null` when interaction is required. Anything that
  /// cannot be resolved without the user throws [AuthRequired].
  Future<ValidSession> ensureValidSession({
    required Future<String?> Function(String email) renew,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final saved = await store.load();
    if (saved == null) throw AuthRequired('no stored session');

    if (!isStale(await store.savedAtMs(), current)) {
      if (await api.isSessionValid(saved.sessionId)) {
        return ValidSession(saved.sessionId, saved.email);
      }
      // Looks fresh but the server rejects it (restart/wipe) → renew once.
    }

    final fresh = await renew(saved.email);
    if (fresh == null || fresh.isEmpty) {
      throw AuthRequired('silent renewal needs interaction');
    }
    await store.save(sessionId: fresh, email: saved.email);
    return ValidSession(fresh, saved.email, renewed: true);
  }
}
