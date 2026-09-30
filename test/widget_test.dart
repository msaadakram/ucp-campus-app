import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/app.dart';

void main() {
  testWidgets('Campus app boots to login', (WidgetTester tester) async {
    await tester.pumpWidget(const CampusApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Hey, welcome back.'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('Login navigates to home', (WidgetTester tester) async {
    await tester.pumpWidget(const CampusApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'ayaan.w@uni.edu');
    await tester.enterText(find.byType(TextField).at(1), '1234');
    await tester.pump();
    final loginBtn = find.text('Log in');
    await tester.ensureVisible(loginBtn);
    await tester.pumpAndSettle();
    await tester.tap(loginBtn, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('My courses'), findsOneWidget);
  });
}
