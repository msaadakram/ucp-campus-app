import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/app.dart';
import 'package:ucp/auth/session_manager.dart';
import 'package:ucp/auth/session_monitor.dart';

class _MemoryBackend implements SessionBackend {
  String? sid;
  String? email;
  int? savedAt;
  _MemoryBackend({this.sid, this.email, this.savedAt});

  @override
  Future<void> clear() async {
    sid = null;
    email = null;
    savedAt = null;
  }

  @override
  Future<({String email, String sessionId})?> load() async =>
      (sid == null || email == null) ? null : (sessionId: sid!, email: email!);

  @override
  Future<String?> readEmail() async => email;

  @override
  Future<void> save({required String sessionId, required String email}) async {
    sid = sessionId;
    this.email = email;
    savedAt = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  Future<int?> savedAtMs() async => savedAt;

  String? dashboardJson;

  @override
  Future<void> saveDashboard(String json) async {
    dashboardJson = json;
  }

  @override
  Future<String?> loadDashboard() async => dashboardJson;
}

int _recentMs() =>
    DateTime.now().millisecondsSinceEpoch -
    const Duration(minutes: 1).inMilliseconds;

/// Drives the REAL app shell (Stack, overlays, monitor) with a fake backend:
/// proves the laptop-login-kill -> popup wiring end to end. Manual pumps
/// only — pumpAndSettle would never settle with the live heartbeat timer.
void main() {
  testWidgets('dead session + failed renew shows the expired popup',
      (WidgetTester tester) async {
    final backend = _MemoryBackend(
      sid: 'dead-1',
      email: 'a@ucp.edu.pk',
      savedAt: _recentMs(),
    );
    await tester.pumpWidget(CampusApp(
      authHooks: AuthTestHooks(
        backend: backend,
        validate: (_) async => false,
        renew: (_) async => RenewOutcome(failCode: 'login_required'),
        monitorInterval: const Duration(milliseconds: 200),
        startAuthed: true,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Session expired'), findsOneWidget);
    expect(find.text('Login here now'), findsOneWidget);
    expect(find.textContaining('laptop'), findsOneWidget);

    // "Later" dismisses without logging out.
    await tester.tap(find.text('Later'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Session expired'), findsNothing);
    expect(find.text('My courses'), findsOneWidget);
  });

  testWidgets('silent heal shows banner instead of popup',
      (WidgetTester tester) async {
    final backend = _MemoryBackend(
      sid: 'dead-2',
      email: 'a@ucp.edu.pk',
      savedAt: _recentMs(),
    );
    var validated = 0;
    await tester.pumpWidget(CampusApp(
      authHooks: AuthTestHooks(
        backend: backend,
        validate: (_) async {
          validated++;
          // First validation (old sid) fails; post-renew sid passes.
          return validated > 1;
        },
        renew: (_) async => RenewOutcome(sessionId: 'fresh-9'),
        monitorInterval: const Duration(milliseconds: 200),
        startAuthed: true,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Session expired'), findsNothing);
    expect(
      find.textContaining('Session refreshed automatically'),
      findsOneWidget,
    );
    expect(backend.sid, 'fresh-9');
  });
}
