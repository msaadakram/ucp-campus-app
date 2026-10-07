import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/app.dart';

/// Post-login screens are exercised with the documented `skipLogin` test
/// hook: interactive Microsoft sign-in needs a real browser + a real user,
/// so it cannot run inside widget tests. OAuth URL building, redirect
/// classification and session validation are covered by unit tests instead.
Future<void> _login(WidgetTester tester) async {
  await tester.pumpWidget(const CampusApp(skipLogin: true));
  await tester.pumpAndSettle();
  expect(find.text('My courses'), findsOneWidget);
}

Future<void> _tapNav(WidgetTester tester, String label) async {
  final item = find.text(label).first;
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item, warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// Community bottom tab opens the feed directly.
Future<void> _openCommunityFeed(WidgetTester tester) async {
  await _tapNav(tester, 'Community');
  expect(find.text('r/campus'), findsOneWidget);
}

void main() {
  testWidgets('UI walkthrough: all bottom tabs render', (WidgetTester tester) async {
    await _login(tester);
    await _tapNav(tester, 'Material');
    expect(find.text('Course material'), findsOneWidget);
    await _openCommunityFeed(tester);
    await _tapNav(tester, 'Web');
    expect(find.text('Web view'), findsOneWidget);
    // NOTE: the Web tab also has a "Profile" shortcut chip, so the bottom
    // nav item (last in tree order) is tapped explicitly here.
    final profileNav = find.text('Profile').last;
    await tester.ensureVisible(profileNav);
    await tester.pumpAndSettle();
    await tester.tap(profileNav, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Ayaan Warraich'), findsWidgets);
    await _tapNav(tester, 'Home');
    expect(find.text('My courses'), findsOneWidget);
  });

  testWidgets('UI walkthrough: drawer pages render', (WidgetTester tester) async {
    await _login(tester);
    Future<void> openDrawer() async {
      await _tapNav(tester, 'Home');
      await tester.tap(find.byIcon(Icons.menu).first, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    Future<void> tapDrawerItem(String label) async {
      final drawerList = find.ancestor(
        of: find.text('Timetable'),
        matching: find.byType(ListView),
      );
      for (var i = 0; i < 6; i++) {
        if (find.text(label).evaluate().isNotEmpty) break;
        await tester.drag(drawerList, const Offset(0, -200));
        await tester.pumpAndSettle();
      }
      final item = find.text(label).first;
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      await tester.tap(item, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    await openDrawer();
    for (final label in [
      'Timetable',
      'Attendance',
      'GPA calculator',
      'Fee challan',
      'Results'
    ]) {
      await tapDrawerItem(label);
      // reopen drawer for next page (menu lives on Home)
      if (label != 'Results') {
        await openDrawer();
      }
    }
    expect(find.text('Results'), findsWidgets);
  });

  testWidgets('UI walkthrough: course detail + leaderboard', (WidgetTester tester) async {
    await _login(tester);
    // .at(1): .first is the non-tappable "Up next" card title
    final course = find.text('Data Structures').at(1);
    await tester.ensureVisible(course);
    await tester.pumpAndSettle();
    await tester.tap(course, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Upcoming'), findsOneWidget);
    // back to home, open leaderboard strip
    await tester.tap(find.byIcon(Icons.arrow_back).first, warnIfMissed: false);
    await tester.pumpAndSettle();
    final board = find.textContaining('Leaderboard').first;
    await tester.ensureVisible(board);
    await tester.pumpAndSettle();
    await tester.tap(board, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Your rank in CS 214'), findsWidgets);
  });

  testWidgets('UI walkthrough: community thread renders', (WidgetTester tester) async {
    await _login(tester);
    await _openCommunityFeed(tester);
    final post = find.text('Study group for the Data Structures midterm?').first;
    await tester.ensureVisible(post);
    await tester.pumpAndSettle();
    await tester.tap(post, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('COMMENTS'), findsWidgets);
  });
}
