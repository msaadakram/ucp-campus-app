import 'dart:async';

import 'microsoft_oauth.dart';

/// Live session watchdog: proves the Horizon `session_id` is still alive
/// while the app is used, and heals it silently when it dies.
///
/// Why polling at all: Odoo kills the session server-side (15-minute
/// lifetime, or a login from the laptop), so no local timestamp can prove
/// liveness. The only source of truth is one tiny
/// `/web/session/get_session_info` call: `uid` int = alive, anything else
/// (usually `SessionExpiredException`) = dead.
///
/// Cadence: [interval] (default 30 s — a 3 s poll would hold the mobile
/// radio awake and hit Odoo 20x/minute for zero UX gain; a laptop-login
/// kill is additionally caught instantly by any failing API call). Each
/// tick is a single cheap call when alive; the heavier silent renewal runs
/// only after a death is observed.
class MonitorSnapshot {
  final String sessionId;
  final String email;
  MonitorSnapshot(this.sessionId, this.email);
}

class RenewOutcome {
  final String? sessionId;
  final String? failCode; // MS error, 'timeout', or 'no_session'
  RenewOutcome({this.sessionId, this.failCode});
}

class SessionMonitor {
  static const heartbeat = Duration(seconds: 30);

  final Future<MonitorSnapshot?> Function() readSession;
  final Future<bool> Function(String sessionId) validate;
  final Future<RenewOutcome> Function(String email) renew;
  final Future<void> Function(String sessionId, String email) onRenewed;
  final Future<void> Function(String message) onDead;
  final Duration interval;

  Timer? _timer;
  bool _checking = false;

  SessionMonitor({
    required this.readSession,
    required this.validate,
    required this.renew,
    required this.onRenewed,
    required this.onDead,
    this.interval = heartbeat,
  });

  void start({bool immediate = false}) {
    stop();
    _timer = Timer.periodic(interval, (_) => checkNow());
    if (immediate) checkNow();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  bool get running => _timer != null;

  /// One liveness pass. Safe to call from timers, resume hooks and API
  /// error handlers — concurrent passes are skipped.
  Future<void> checkNow() async {
    if (_checking) return;
    _checking = true;
    try {
      final snap = await readSession();
      if (snap == null) return;
      if (await validate(snap.sessionId)) return; // alive: nothing to do

      final outcome = await renew(snap.email);
      final fresh = outcome.sessionId;
      if (fresh != null && fresh.isNotEmpty) {
        await onRenewed(fresh, snap.email);
        return;
      }
      final code = outcome.failCode ?? 'timeout';
      if (MicrosoftOAuth.isInteractionError(code) || code == 'no_session') {
        // Microsoft session truly dead too: confirm the old Horizon
        // session is really gone before forcing a logout...
        final stillAlive = await validate(snap.sessionId).catchError((_) => false);
        if (!stillAlive) {
          await onDead(MicrosoftOAuth.renewFailureMessage(code));
        }
      }
      // ...otherwise (timeout/offline): stay logged in, retry next tick.
    } finally {
      _checking = false;
    }
  }
}
