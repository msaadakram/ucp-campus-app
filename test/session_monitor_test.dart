import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/auth/session_monitor.dart';

class _Harness {
  String? sid;
  final String email = 'a@ucp.edu.pk';
  int validations = 0;
  int renewals = 0;
  String? renewedSid;
  String? deadMessage;
  bool alive;
  RenewOutcome renewOutcome;

  _Harness({
    this.sid = 'sid-1',
    this.alive = true,
    RenewOutcome? renewOutcome,
  }) : renewOutcome = renewOutcome ?? RenewOutcome(sessionId: 'sid-2');

  SessionMonitor build({Duration interval = const Duration(seconds: 30)}) {
    return SessionMonitor(
      readSession: () async =>
          sid == null ? null : MonitorSnapshot(sid!, email),
      validate: (s) async {
        validations++;
        return alive && s == sid;
      },
      renew: (_) async {
        renewals++;
        return renewOutcome;
      },
      onRenewed: (s, e) async {
        renewedSid = s;
        sid = s;
      },
      onDead: (m, _) async => deadMessage = m,
      interval: interval,
    );
  }
}

void main() {
  group('checkNow', () {
    test('alive session: no renew, no logout', () async {
      final h = _Harness();
      final m = h.build();
      await m.checkNow();
      expect(h.validations, 1);
      expect(h.renewals, 0);
      expect(h.renewedSid, isNull);
      expect(h.deadMessage, isNull);
    });

    test('dead session renews and saves', () async {
      final h = _Harness(alive: false);
      final m = h.build();
      // First validate fails; renewal returns sid-2; saved as current.
      // Second validate inside renew? No — monitor trusts validated renew.
      await m.checkNow();
      expect(h.renewals, 1);
      expect(h.renewedSid, 'sid-2');
      expect(h.deadMessage, isNull);
    });

    test('dead session + hard failure + old dead -> logout with message',
        () async {
      final h = _Harness(
        alive: false,
        renewOutcome: RenewOutcome(failCode: 'login_required'),
      );
      final m = h.build();
      await m.checkNow();
      expect(h.renewals, 1);
      expect(h.deadMessage, contains('expired'));
    });

    test('dead session + soft failure (timeout) -> stays, no logout',
        () async {
      final h = _Harness(
        alive: false,
        renewOutcome: RenewOutcome(failCode: 'timeout'),
      );
      final m = h.build();
      await m.checkNow();
      expect(h.renewals, 1);
      expect(h.renewedSid, isNull);
      expect(h.deadMessage, isNull);
    });

    test('no stored session -> quiet no-op', () async {
      final h = _Harness(sid: null);
      final m = h.build();
      await m.checkNow();
      expect(h.validations, 0);
      expect(h.renewals, 0);
      expect(h.deadMessage, isNull);
    });

    test('validate throwing (offline) -> stays logged in, never throws',
        () async {
      final h = _Harness();
      final m = SessionMonitor(
        readSession: () async => MonitorSnapshot('sid-1', h.email),
        validate: (_) async => throw Exception('SocketException'),
        renew: (_) async {
          h.renewals++;
          return h.renewOutcome;
        },
        onRenewed: (s, e) async {},
        onDead: (msg, _) async => h.deadMessage = msg,
      );
      await m.checkNow();
      expect(h.renewals, 0);
      expect(h.deadMessage, isNull);
    });

    test('concurrent passes are skipped', () async {
      final h = _Harness();
      final m = h.build();
      await Future.wait([m.checkNow(), m.checkNow()]);
      expect(h.validations, 1);
    });
  });

  group('heartbeat timer', () {
    test('ticks on interval, stops on stop()', () {
      FakeAsync().run((async) {
        final h = _Harness();
        final m = h.build(interval: const Duration(seconds: 30));
        expect(m.running, isFalse);
        m.start();
        expect(m.running, isTrue);
        async.elapse(const Duration(seconds: 65));
        expect(h.validations, greaterThanOrEqualTo(2));
        m.stop();
        expect(m.running, isFalse);
        final seen = h.validations;
        async.elapse(const Duration(minutes: 10));
        expect(h.validations, seen);
      });
    });
  });
}
