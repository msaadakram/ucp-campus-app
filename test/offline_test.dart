import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/auth/offline.dart';
import 'package:ucp/auth/page_cache.dart';
import 'package:ucp/auth/portal_cache.dart';
import 'package:ucp/auth/student_portal.dart';
import 'package:ucp/screens/attendance.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';
import 'package:ucp/widgets/offline_banner.dart';

Widget _wrap(Widget child) {
  final colors = AppColors.of(AppPalette.skater, false);
  return AppScope(
    colors: colors,
    palette: AppPalette.skater,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  tearDown(() {
    PortalCache.clear();
    PageCache.debugDir = null;
    PageCache.debugPages = null;
    PageCache.diskEnabled = false;
    OfflineMonitor.resetDebug();
  });

  group('timeAgo', () {
    test('labels seconds, minutes, hours, days', () {
      final now = DateTime(2026, 10, 4, 12, 0);
      int ms(DateTime t) => t.millisecondsSinceEpoch;
      expect(timeAgo(ms(now.subtract(const Duration(seconds: 10))), now),
          'just now');
      expect(
          timeAgo(ms(now.subtract(const Duration(minutes: 5))), now),
          '5m ago');
      expect(
          timeAgo(ms(now.subtract(const Duration(hours: 3))), now), '3h ago');
      expect(
          timeAgo(ms(now.subtract(const Duration(days: 2))), now), '2d ago');
    });
  });

  group('OfflineMonitor', () {
    test('no interface means offline without probing', () async {
      var probed = false;
      final m = OfflineMonitor.debug(
        check: () async => [ConnectivityResult.none],
        probe: () async {
          probed = true;
          return true;
        },
      );
      m.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(m.isOffline, isTrue);
      expect(probed, isFalse);
      m.stop();
    });

    test('wifi + reachable probe means online', () async {
      final m = OfflineMonitor.debug(
        check: () async => [ConnectivityResult.wifi],
        probe: () async => true,
      );
      m.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(m.isOffline, isFalse);
      m.stop();
    });

    test('wifi + dead probe means offline; throwing probe too', () async {
      final dead = OfflineMonitor.debug(
        check: () async => [ConnectivityResult.mobile],
        probe: () async => false,
      );
      dead.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(dead.isOffline, isTrue);
      dead.stop();

      final throwing = OfflineMonitor.debug(
        check: () async => [ConnectivityResult.wifi],
        probe: () async => throw const SocketExceptionClosed(),
      );
      throwing.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(throwing.isOffline, isTrue);
      throwing.stop();
    });

    test('connectivity changes flip the state', () async {
      final ctrl = StreamController<List<ConnectivityResult>>();
      addTearDown(ctrl.close);
      var current = [ConnectivityResult.wifi];
      final m = OfflineMonitor.debug(
        check: () async => current,
        changes: ctrl.stream,
        probe: () async => true,
      );
      final seen = <bool>[];
      m.offline.addListener(() => seen.add(m.isOffline));
      m.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(m.isOffline, isFalse);
      current = [ConnectivityResult.none];
      ctrl.add([ConnectivityResult.none]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(m.isOffline, isTrue);
      expect(seen, contains(true));
      m.stop();
    });
  });

  group('PortalCache', () {
    test('put/clear round-trips per screen', () {
      expect(PortalCache.attendance, isNull);
      PortalCache.putAttendance(const []);
      expect(PortalCache.attendance, isNotNull);
      expect(PortalCache.savedAt['attendance'], isNotNull);
      PortalCache.clear();
      expect(PortalCache.attendance, isNull);
      expect(PortalCache.savedAt, isEmpty);
    });
  });

  group('PageCache', () {
    test('memory stand-in serves pages to widget tests', () async {
      PageCache.debugPages = {};
      expect(await PageCache.loadPage('attendance'), isNull);
      await PageCache.savePage('attendance', '<html>hi</html>');
      final snap = await PageCache.loadPage('attendance');
      expect(snap, isNotNull);
      expect(snap!.html, '<html>hi</html>');
      expect(snap.savedAtMs, greaterThan(0));
      await PageCache.savePage('attendance', '');
      expect((await PageCache.loadPage('attendance'))!.html, '<html>hi</html>');
      await PageCache.clear();
      expect(await PageCache.loadPage('attendance'), isNull);
    });

    test('save/load/clear round-trips raw pages on real disk', () async {
      // Plain unit test: real async IO completes here.
      final dir = await Directory.systemTemp.createTemp('ucp_page_cache');
      addTearDown(() => dir.delete(recursive: true));
      PageCache.diskEnabled = true;
      PageCache.debugDir = dir;
      expect(await PageCache.loadPage('attendance'), isNull);
      await PageCache.savePage('attendance', '<html>hi</html>');
      final snap = await PageCache.loadPage('attendance');
      expect(snap, isNotNull);
      expect(snap!.html, '<html>hi</html>');
      expect(snap.savedAtMs, greaterThan(0));
      await PageCache.clear();
      expect(await PageCache.loadPage('attendance'), isNull);
    });

    test('corrupt or missing files read as null, never throw', () async {
      final dir = await Directory.systemTemp.createTemp('ucp_page_empty');
      addTearDown(() => dir.delete(recursive: true));
      PageCache.diskEnabled = true;
      PageCache.debugDir = dir;
      expect(await PageCache.loadPage('nope'), isNull);
      await PageCache.savePage('attendance', '');
      expect(await PageCache.loadPage('attendance'), isNull);
    });
  });

  group('OfflineBanner', () {
    testWidgets('forced states render the pill or nothing',
        (WidgetTester tester) async {
      await tester
          .pumpWidget(_wrap(const OfflineBanner(forceShow: true)));
      await tester.pumpAndSettle();
      expect(find.textContaining('offline'), findsOneWidget);

      await tester
          .pumpWidget(_wrap(const OfflineBanner(forceShow: false)));
      await tester.pumpAndSettle();
      expect(find.textContaining('offline'), findsNothing);
    });
  });

  group('attendance offline', () {
    testWidgets('no connection shows the offline error immediately',
        (WidgetTester tester) async {
      OfflineMonitor.debugOverride(OfflineMonitor.debug(
        check: () async => [ConnectivityResult.none],
      ));
      // Set offline synchronously: Future.delayed never fires in widget
      // tests (fake clock), so drive the notifier directly.
      OfflineMonitor.instance.offline.value = true;

      await tester.pumpWidget(_wrap(const AttendanceScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining("You're offline"), findsOneWidget);
      // Retry is offered, not a session-expired re-login.
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Re-login'), findsNothing);
    });

    testWidgets('cached snapshot shows with age while offline',
        (WidgetTester tester) async {
      PortalCache.putAttendance([
        const AttendanceCourse(
          name: 'Multivariable Calculus',
          percent: 33.0,
          records: [],
        ),
      ]);
      OfflineMonitor.debugOverride(OfflineMonitor.debug(
        check: () async => [ConnectivityResult.none],
      ));
      OfflineMonitor.instance.offline.value = true;

      await tester.pumpWidget(_wrap(const AttendanceScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Multivariable Calculus'), findsOneWidget);
      expect(find.textContaining('Saved '), findsOneWidget);
    });

    testWidgets('back online auto-retries the failed load',
        (WidgetTester tester) async {
      OfflineMonitor.debugOverride(OfflineMonitor.debug(
        check: () async => [ConnectivityResult.none],
      ));
      OfflineMonitor.instance.offline.value = true;

      await tester.pumpWidget(_wrap(const AttendanceScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining("You're offline"), findsOneWidget);

      // Connection returns: the screen retries on its own (no session here
      // so it lands on the expired/session prompt, proving a refetch ran).
      OfflineMonitor.instance.offline.value = false;
      await tester.pumpAndSettle();
      expect(find.textContaining("You're offline"), findsNothing);
      expect(find.textContaining('sign in again'), findsOneWidget);
    });

    testWidgets('disk snapshot paints instantly on offline restart',
        (WidgetTester tester) async {
      // In-memory stand-in: real async IO never completes in widget tests.
      PageCache.debugPages = {'attendance': _diskAttHtml};
      OfflineMonitor.debugOverride(OfflineMonitor.debug(
        check: () async => [ConnectivityResult.none],
      ));
      OfflineMonitor.instance.offline.value = true;

      await tester.pumpWidget(_wrap(const AttendanceScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Disk Course'), findsOneWidget);
      expect(find.textContaining('Saved '), findsOneWidget);
      expect(find.textContaining("You're offline"), findsNothing);
    });
  });
}

const _diskAttHtml = '<h3><div><span>Disk Course</span>'
    '<div><span>Attendance: 75.0%</span></div></div></h3>'
    '<table class="uk-table"><tr><th>Sr. no</th><th>Date</th><th>Status</th><th>Fine</th></tr>'
    '<tr><td>1</td><td>2026-10-01</td><td>Present</td><td>-</td></tr></table>';

class SocketExceptionClosed implements Exception {
  const SocketExceptionClosed();
}
