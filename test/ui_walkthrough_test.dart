import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/app.dart';

Future<void> _login(WidgetTester tester) async {
  await tester.pumpWidget(const CampusApp());
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, 'ayaan.w@ucp.edu.pk');
  await tester.enterText(find.byType(TextField).at(1), '1234');
  await tester.pump();
  final loginBtn = find.text('Log in');
  await tester.ensureVisible(loginBtn);
  await tester.pumpAndSettle();
  await tester.tap(loginBtn, warnIfMissed: false);
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

/// Community bottom tab opens the picker; choose the Community card.
Future<void> _openCommunityFeed(WidgetTester tester) async {
  await _tapNav(tester, 'Community');
  await tester.tap(find.text('Campus feed & posts'), warnIfMissed: false);
  await tester.pumpAndSettle();
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
    await _tapNav(tester, 'Profile');
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
    await openDrawer();
    for (final label in ['Timetable', 'GPA calculator', 'Fee challan']) {
      final item = find.text(label).first;
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      await tester.tap(item, warnIfMissed: false);
      await tester.pumpAndSettle();
      // reopen drawer for next page (menu lives on Home)
      if (label != 'Fee challan') {
        await openDrawer();
      }
    }
    expect(find.text('Fee challan'), findsOneWidget);
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

  testWidgets('UI walkthrough: groups + chat render', (WidgetTester tester) async {
    await _login(tester);
    await tester.tap(find.byIcon(Icons.menu).first, warnIfMissed: false);
    await tester.pumpAndSettle();
    final drawerList = find.ancestor(of: find.text('Timetable'), matching: find.byType(ListView));
    await tester.drag(drawerList, const Offset(0, -400));
    await tester.pumpAndSettle();
    await _tapNav(tester, 'Groups & chats');
    expect(find.text('Groups'), findsWidgets);
    // join-free chat open: tap first Chat button
    final chatBtn = find.text('Chat').first;
    await tester.ensureVisible(chatBtn);
    await tester.pumpAndSettle();
    await tester.tap(chatBtn, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Message the group…'), findsOneWidget);
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
