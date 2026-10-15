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
    expect(find.text('Relogin now'), findsOneWidget);
    expect(find.textContaining('laptop'), findsOneWidget);

    // "Stay logged out" dismisses without logging out.
    await tester.tap(find.text('Stay logged out'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Session expired'), findsNothing);
    expect(find.text('My courses'), findsOneWidget);
  });

  testWidgets('staying without live stops cookie refresh, keeps relaunch',
      (WidgetTester tester) async {
    final backend = _MemoryBackend(
      sid: 'dead-1',
      email: 'a@ucp.edu.pk',
      savedAt: _recentMs(),
    );
    var renews = 0;
    await tester.pumpWidget(CampusApp(
      authHooks: AuthTestHooks(
        backend: backend,
        validate: (_) async => false,
        renew: (_) async {
          renews++;
          return RenewOutcome(failCode: 'login_required');
        },
        monitorInterval: const Duration(milliseconds: 200),
        startAuthed: true,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Session expired'), findsOneWidget);
    await tester.tap(find.text('Stay logged out'));
    await tester.pump(const Duration(milliseconds: 100));
    final frozen = renews;
    // Heartbeats keep validating but never mint cookies again…
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(renews, frozen);
    // …never re-pops, stays usable, and keeps the stored session…
    expect(find.text('Session expired'), findsNothing);
    expect(find.text('My courses'), findsOneWidget);
    expect(backend.sid, 'dead-1');
    // …so a fresh launch retries auto sign-in on its own.
    await tester.pumpWidget(CampusApp(
      authHooks: AuthTestHooks(
        backend: backend,
        validate: (_) async => true,
        monitorInterval: const Duration(minutes: 5),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('My courses'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('dead session pops choice without silent heal',
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
          return false;
        },
        renew: (_) async => RenewOutcome(sessionId: 'fresh-9'),
        monitorInterval: const Duration(milliseconds: 200),
        startAuthed: true,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    // No silent heal mid-use: the choice popup appears, cookies untouched.
    expect(find.text('Session expired'), findsOneWidget);
    expect(find.text('Relogin now'), findsOneWidget);
    expect(find.text('Stay logged out'), findsOneWidget);
    expect(backend.sid, 'dead-2');
    expect(validated, greaterThanOrEqualTo(1));
  });
}
