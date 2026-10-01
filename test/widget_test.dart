import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/app.dart';
import 'package:ucp/screens/auth_home.dart';

void main() {
  testWidgets('Campus app boots to UCP login', (WidgetTester tester) async {
    await tester.pumpWidget(const CampusApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Hey, welcome back.'), findsOneWidget);
    expect(find.text('Continue with Microsoft'), findsOneWidget);
    // No password field: the password is typed on Microsoft's page only.
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Microsoft button is disabled without @ucp.edu.pk email',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CampusApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'someone@gmail.com');
    await tester.pump();
    await tester.tap(find.text('Continue with Microsoft'),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    // Still on login: no webview opened, still seeing the login screen.
    expect(find.text('Hey, welcome back.'), findsOneWidget);
  });

  testWidgets('Microsoft button forwards the typed email',
      (WidgetTester tester) async {
    String? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginScreen(onMicrosoftSignIn: (e) => captured = e),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).first, 'l1f25bscs0577@ucp.edu.pk');
    await tester.pump();
    await tester.tap(find.text('Continue with Microsoft'));
    await tester.pumpAndSettle();
    expect(captured, 'l1f25bscs0577@ucp.edu.pk');
  });

  testWidgets('skipLogin test hook opens home directly',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CampusApp(skipLogin: true));
    await tester.pumpAndSettle();
    expect(find.text('My courses'), findsOneWidget);
  });

  testWidgets('login screen shows the re-sign-in notice when provided',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginScreen(
            onMicrosoftSignIn: (_) {},
            authError: 'Your Microsoft sign-in expired. Please sign in again.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('expired'), findsOneWidget);
  });
}
