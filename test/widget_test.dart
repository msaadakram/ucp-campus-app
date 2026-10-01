import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/app.dart';
import 'package:ucp/auth/dashboard_parser.dart';
import 'package:ucp/auth/session_manager.dart';
import 'package:ucp/screens/auth_home.dart';
import 'package:ucp/screens/profile.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';
import 'package:ucp/widgets/session_expired_dialog.dart';

class _HookDashBackend implements SessionBackend {
  String? sid;
  String? email;
  int? savedAt;
  String? dashboardJson;
  @override
  Future<void> save({required String sessionId, required String email}) async {
    sid = sessionId;
    this.email = email;
    savedAt = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  Future<({String email, String sessionId})?> load() async =>
      (sid == null || email == null) ? null : (sessionId: sid!, email: email!);
  @override
  Future<String?> readEmail() async => email;
  @override
  Future<int?> savedAtMs() async => savedAt;
  @override
  Future<void> clear() async {
    sid = null;
    email = null;
    savedAt = null;
    dashboardJson = null;
  }

  @override
  Future<void> saveDashboard(String json) async => dashboardJson = json;
  @override
  Future<String?> loadDashboard() async => dashboardJson;
}

void main() {
  testWidgets('Campus app boots to UCP login', (WidgetTester tester) async {
    await tester.pumpWidget(const CampusApp());
    await tester.pumpAndSettle();
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

  testWidgets('session-expired popup offers login-here-now and later',
      (WidgetTester tester) async {
    var loginNow = false;
    var later = false;
    final colors = AppColors.of(AppPalette.skater, false);
    await tester.pumpWidget(
      AppScope(
        colors: colors,
        palette: AppPalette.skater,
        child: MaterialApp(
          home: Scaffold(
            body: SessionExpiredDialog(
              message: 'Your portal session expired.',
              onLoginNow: () => loginNow = true,
              onLater: () => later = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Session expired'), findsOneWidget);
    expect(find.text('Your portal session expired.'), findsOneWidget);
    expect(find.textContaining('laptop'), findsOneWidget);
    await tester.tap(find.text('Login here now'));
    await tester.pumpAndSettle();
    expect(loginNow, isTrue);
    expect(later, isFalse);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(later, isTrue);
  });

  testWidgets('profile shows semester, no advisor, earned progress',
      (WidgetTester tester) async {
    final colors = AppColors.of(AppPalette.skater, false);
    await tester.pumpWidget(
      AppScope(
        colors: colors,
        palette: AppPalette.skater,
        child: MaterialApp(
          home: Scaffold(
            body: ProfileScreen(
              logout: () {},
              prefs: ProfilePrefs(),
              onPrefs: (_) {},
              studentName: 'Test Student',
              studentId: 'L1F25BSCS0577',
              faculty: 'Faculty of IT',
              email: 't@ucp.edu.pk',
              earnedCredits: 30.0,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test Student'), findsOneWidget);
    expect(find.text('L1F25BSCS0577'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Semester \d+$')), findsOneWidget);
    expect(find.text('Fall 2025'), findsOneWidget);
    expect(find.text('30 / 132 credits'), findsOneWidget);
    expect(find.text('Advisor'), findsNothing);
    expect(find.text('Dr. Amina Qureshi'), findsNothing);
  });

  testWidgets('restoring flag shows the signing-in animation, not the form',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginScreen(
            restoring: true,
            onMicrosoftSignIn: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Signing you in…'), findsOneWidget);
    expect(find.text('Hey, welcome back.'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('cached dashboard paints instantly in hooks mode',
      (WidgetTester tester) async {
    final backend = _HookDashBackend();
    await backend.saveDashboard(
      '{"name":"Cached Student","id":null,"faculty":null,'
      '"stats":[{"label":"CGPA","value":"3.77"}],"today":null,"news":[]}',
    );
    await backend.save(sessionId: 'cached-sid', email: 'c@ucp.edu.pk');
    await tester.pumpWidget(CampusApp(
      authHooks: AuthTestHooks(
        backend: backend,
        validate: (_) async => true,
        monitorInterval: const Duration(minutes: 5),
        startAuthed: true,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Cached name is on screen even before any network fetch lands.
    expect(find.text('Cached '), findsOneWidget);
    expect(find.text('3.77'), findsOneWidget);
  });

  testWidgets('home shows live dashboard name, stats and badge',
      (WidgetTester tester) async {
    const data = DashboardData(
      studentName: 'Test Student',
      stats: [
        DashboardStat('CGPA', '3.90'),
        DashboardStat('Credits', '60'),
        DashboardStat('Attendance', '98%'),
      ],
    );
    final colors = AppColors.of(AppPalette.skater, false);
    await tester.pumpWidget(
      AppScope(
        colors: colors,
        palette: AppPalette.skater,
        child: MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              onOpen: (_) {},
              toProfile: () {},
              onMenu: () {},
              onGpa: () {},
              onBoard: (_) {},
              dashboard: data,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test '), findsOneWidget);
    expect(find.text('3.90'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
  });
}
