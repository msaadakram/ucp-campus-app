import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/app.dart';
import 'package:ucp/auth/dashboard_parser.dart';
import 'package:ucp/auth/offline.dart';
import 'package:ucp/auth/session_manager.dart';
import 'package:ucp/auth/session_monitor.dart';
import 'package:ucp/auth/student_portal.dart';
import 'package:ucp/data/seed.dart';
import 'package:ucp/screens/auth_home.dart';
import 'package:ucp/screens/materials_web.dart';
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

  testWidgets('session-expired popup offers login-now or stay-without-live',
      (WidgetTester tester) async {    var loginNow = false;
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
              detail: 'login_required',
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
    expect(find.textContaining('login_required'), findsOneWidget);
    await tester.tap(find.text('Login here now'));
    await tester.pumpAndSettle();
    expect(loginNow, isTrue);
    expect(later, isFalse);
    await tester.tap(find.text('Stay without live'));
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
    expect(find.text('BS Computer Science · Year 2'), findsOneWidget);
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

  testWidgets('saved session opens home instantly, no blocking animation',
      (WidgetTester tester) async {
    // Hermetic: earlier production-mode boots leave the global probe
    // offline in this isolate; the background engine reads that flag.
    OfflineMonitor.resetDebug();
    final backend = _HookDashBackend();
    await backend.save(sessionId: 'live-sid', email: 's@ucp.edu.pk');
    var validations = 0;
    await tester.pumpWidget(CampusApp(
      authHooks: AuthTestHooks(
        backend: backend,
        validate: (_) async {
          validations++;
          return true;
        },
        monitorInterval: const Duration(minutes: 5),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Home immediately — never the blocking "Signing you in…" screen.
    expect(find.text('My courses'), findsOneWidget);
    expect(find.text('Signing you in…'), findsNothing);
    expect(find.text('Hey, welcome back.'), findsNothing);
    await tester.pumpAndSettle();
    expect(validations, 1); // engine verified in the background
    expect(find.text('My courses'), findsOneWidget);
    expect(find.text('Try again'), findsNothing); // success: no banner
  });

  testWidgets('dead saved session keeps app usable with retry banner',
      (WidgetTester tester) async {
    OfflineMonitor.resetDebug();
    final backend = _HookDashBackend();
    await backend.save(sessionId: 'dead-sid', email: 's@ucp.edu.pk');
    var validations = 0;
    await tester.pumpWidget(CampusApp(
      authHooks: AuthTestHooks(
        backend: backend,
        validate: (_) async {
          validations++;
          return false;
        },
        renew: (_) async => RenewOutcome(failCode: 'login_required'),
        monitorInterval: const Duration(minutes: 5),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Still usable instantly on the saved world.
    expect(find.text('My courses'), findsOneWidget);
    await tester.pumpAndSettle();
    // Banner offers retry / fresh sign-in; app stays on home.
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('My courses'), findsOneWidget);
    final before = validations;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(validations, greaterThan(before));
  });

  testWidgets('offline saved-data pill shows above the tab bar',
      (WidgetTester tester) async {
    OfflineMonitor.debugOverride(OfflineMonitor.debug());
    addTearDown(OfflineMonitor.resetDebug);
    OfflineMonitor.instance.offline.value = true;
    await tester.pumpWidget(const CampusApp(skipLogin: true));
    await tester.pumpAndSettle();
    expect(find.text('You’re offline — showing saved data'),
        findsOneWidget);
    // Tab bar still present underneath the pill.
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('signing pill shows above the tab bar while verifying',
      (WidgetTester tester) async {
    OfflineMonitor.resetDebug();
    final backend = _HookDashBackend();
    await backend.save(sessionId: 'slow-sid', email: 's@ucp.edu.pk');
    final gate = Completer<bool>();
    await tester.pumpWidget(CampusApp(
      authHooks: AuthTestHooks(
        backend: backend,
        validate: (_) => gate.future,
        monitorInterval: const Duration(minutes: 5),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Home usable instantly, pill proving the engine is working.
    expect(find.text('My courses'), findsOneWidget);
    expect(find.text('Trying to sign in…'), findsOneWidget);
    gate.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Trying to sign in…'), findsNothing);
    expect(find.text('My courses'), findsOneWidget);
  });

  testWidgets('startup paints in the saved theme from the first frame',
      (WidgetTester tester) async {
    await tester.pumpWidget(CampusApp(
      skipLogin: true,
      initialPrefs: ProfilePrefs(theme: ThemeModePref.dark),
    ));
    await tester.pumpAndSettle();
    final scaffold =
        tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor,
        AppColors.of(AppPalette.skater, true).cream2);
  });

  testWidgets('greeting matches the time of day', (WidgetTester tester) async {
    expect(greetingForHour(0), 'Good night,');
    expect(greetingForHour(4), 'Good night,');
    expect(greetingForHour(5), 'Good morning,');
    expect(greetingForHour(8), 'Good morning,');
    expect(greetingForHour(11), 'Good morning,');
    expect(greetingForHour(12), 'Good afternoon,');
    expect(greetingForHour(16), 'Good afternoon,');
    expect(greetingForHour(17), 'Good evening,');
    expect(greetingForHour(20), 'Good evening,');
    expect(greetingForHour(21), 'Good night,');
    expect(greetingForHour(23), 'Good night,');
  });

  testWidgets('web tab renders portal shell in test mode',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WebViewScreen(
            sessionId: 'sid',
            renderWebView: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Browser toolbar shows the live URL (domain emphasized via RichText).
    Finder urlWith(String part) => find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains(part),
        );
    expect(urlWith('horizon.ucp.edu.pk'), findsOneWidget);
    expect(urlWith('/student/dashboard'), findsOneWidget);
    expect(find.text('Portal preview unavailable in tests'), findsOneWidget);
    // No shortcut chips or reload button on the web view.
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Portal'), findsNothing);
    expect(find.text('Reload'), findsNothing);
    // No profile shortcut on the web view.
    expect(find.text('Profile'), findsNothing);
    // Tapping the address bar opens the editor; go loads the new URL.
    await tester.tap(urlWith('horizon.ucp.edu.pk'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'example.com/portal');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(urlWith('example.com'), findsOneWidget);
    expect(urlWith('/portal'), findsOneWidget);
  });

  testWidgets('home explore grid opens every menu page',
      (WidgetTester tester) async {
    final hits = <String>[];
    final colors = AppColors.of(AppPalette.skater, false);
    await tester.pumpWidget(
      AppScope(
        colors: colors,
        palette: AppPalette.skater,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeScreen(
                onOpen: (_) {},
                toProfile: () => hits.add('profile'),
                onMenu: () {},
                onGpa: () => hits.add('gpa'),
                onBoard: (_) {},
                onAttend: () => hits.add('attendance'),
                onTimetable: () => hits.add('timetable'),
                onTeachers: () => hits.add('teachers'),
                onMaterial: () => hits.add('material'),
                onFee: () => hits.add('fee'),
                onResults: () => hits.add('results'),
                onCommunity: () => hits.add('community'),
                onWeb: () => hits.add('web'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Explore campus'), findsOneWidget);
    for (final label in [
      'Teacher reviews',
      'Timetable',
      'Attendance',
      'Course material',
      'GPA calculator',
      'Fee challan',
      'Results',
      'Community',
      'Web view',
      'Profile & settings',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.ensureVisible(find.text('Results'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Results'));
    await tester.ensureVisible(find.text('Community'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Community'));
    expect(hits, ['results', 'community']);
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

  testWidgets('home shows real portal courses from dashboard',
      (WidgetTester tester) async {
    const data = DashboardData(
      studentName: 'Test Student',
      stats: [
        DashboardStat('CGPA', '3.13'),
        DashboardStat('Earned Cr', '30.0'),
        DashboardStat('Total Cr', '0.0'),
      ],
      courses: [
        PortalCourse(
            name: 'Object Oriented Programming',
            teacher: 'Aasma Abdul Waheed',
            code: 'CP223',
            credits: 3.0,
            attendance: 67.0,
            infoUrl: '/student/course/info/x'),
        PortalCourse(
            name: 'Multivariable Calculus',
            teacher: 'Seema Mazhar',
            code: 'MAT243',
            credits: 3.0,
            attendance: 33.0,
            infoUrl: '/student/course/info/y'),
      ],
    );
    const slots = [
      TimetableSlot(
          day: 'Monday',
          start: '08:00',
          end: '08:55',
          subject: 'Object Oriented Programming - Lab',
          teacher: 'S X',
          section: 'CP221',
          room: 'B-CL203 ( Lab )'),
    ];
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
              timetableSlots: slots,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Object Oriented Programming'), findsOneWidget);
    expect(find.text('Multivariable Calculus'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    // Third tile is the overall attendance of both courses:
    // (67*3 + 33*3) / 6 = 50%. The portal's useless "0.0 Total Cr" is gone.
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('0.0'), findsNothing);
    // No mock course cards leak through.
    expect(find.text('Data Structures'), findsNothing);
  });

  testWidgets('home UP NEXT shows next class plus following ones',
      (WidgetTester tester) async {
    const data = DashboardData(studentName: 'Test Student');
    const slots = [
      TimetableSlot(
          day: 'Monday',
          start: '08:00',
          end: '08:55',
          subject: 'Alpha Class',
          teacher: 'T A',
          section: 'S1',
          room: 'R1'),
      TimetableSlot(
          day: 'Monday',
          start: '10:00',
          end: '10:55',
          subject: 'Beta Class',
          teacher: 'T B',
          section: 'S2',
          room: 'R2'),
      TimetableSlot(
          day: 'Wednesday',
          start: '09:00',
          end: '09:55',
          subject: 'Gamma Class',
          teacher: 'T C',
          section: 'S3',
          room: 'R3'),
    ];
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
              timetableSlots: slots,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Hero shows the soonest class; the next two appear as follow-ups.
    expect(find.text('Alpha Class'), findsOneWidget);
    expect(find.text('Beta Class'), findsWidgets);
    expect(find.text('Gamma Class'), findsWidgets);
    // Hero header is UP NEXT, or NOW while the class is in session.
    expect(find.textContaining(RegExp(r'^(NOW|UP NEXT) ·')), findsOneWidget);
  });

  testWidgets("home today section lists all of today classes with date",
      (WidgetTester tester) async {
    const data = DashboardData(studentName: 'Test Student');
    // Same two classes every weekday: today always has exactly 2 rows,
    // whatever day the test runs.
    final slots = <TimetableSlot>[
      for (final day in [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ]) ...[
        TimetableSlot(
            day: day,
            start: '08:00',
            end: '08:55',
            subject: 'Morning Class',
            teacher: 'T A',
            section: 'S1',
            room: 'R1'),
        TimetableSlot(
            day: day,
            start: '10:00',
            end: '10:55',
            subject: 'Midday Class',
            teacher: 'T B',
            section: 'S2',
            room: 'R2'),
      ],
    ];
    var wentToTimetable = false;
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
              timetableSlots: slots,
              onTimetable: () => wentToTimetable = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Today's classes"), findsOneWidget);
    expect(find.text(formatDay(DateTime.now())), findsOneWidget);
    expect(find.text('Morning Class'), findsWidgets);
    expect(find.text('Midday Class'), findsWidgets);
    expect(find.text('R1 · T A'), findsWidgets);
    // Count pill, or LIVE NOW while a class is in session.
    expect(find.textContaining(RegExp(r'^(2 today|• LIVE NOW)$')),
        findsOneWidget);
    // Footer navigates to the full timetable.
    await tester.ensureVisible(find.text('See full week ›'));
    await tester.tap(find.text('See full week ›'));
    await tester.pumpAndSettle();
    expect(wentToTimetable, isTrue);
  });

  testWidgets('home today section hides without schedule data',
      (WidgetTester tester) async {
    const data = DashboardData(studentName: 'Test Student');
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
    expect(find.text("Today's classes"), findsNothing);
    expect(find.text('See full week ›'), findsNothing);
  });

  testWidgets('Ongoing shows today courses, Almost done the whole week',
      (WidgetTester tester) async {
    const data = DashboardData(
      studentName: 'Test Student',
      courses: [
        PortalCourse(
            name: 'Alpha',
            teacher: 'T A',
            code: 'A101',
            credits: 3.0,
            attendance: 90.0,
            infoUrl: ''),
        PortalCourse(
            name: 'Beta',
            teacher: 'T B',
            code: 'B101',
            credits: 3.0,
            attendance: 80.0,
            infoUrl: ''),
        PortalCourse(
            name: 'Gamma',
            teacher: 'T C',
            code: 'C101',
            credits: 3.0,
            attendance: 70.0,
            infoUrl: ''),
      ],
    );
    // Alpha runs every weekday (so always "today"); Beta only Monday;
    // Gamma has no slots at all.
    final slots = [
      for (final day in [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ])
        TimetableSlot(
            day: day,
            start: '08:00',
            end: '08:55',
            subject: 'Alpha',
            teacher: '',
            section: '',
            room: ''),
      TimetableSlot(
          day: 'Monday',
          start: '10:00',
          end: '10:55',
          subject: 'Beta',
          teacher: '',
          section: '',
          room: ''),
    ];
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
              timetableSlots: slots,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Ongoing -> today's courses: Alpha always, Gamma never.
    await tester.ensureVisible(find.text('Ongoing'));
    await tester.tap(find.text('Ongoing'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsWidgets);
    expect(find.text('Gamma'), findsNothing);
    // Almost done -> complete weekly subjects: Alpha + Beta, never Gamma.
    await tester.ensureVisible(find.text('Almost done'));
    await tester.tap(find.text('Almost done'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsWidgets);
    expect(find.text('Beta'), findsWidgets);
    expect(find.text('Gamma'), findsNothing);
  });

  testWidgets('Ongoing with no classes today shows empty state',
      (WidgetTester tester) async {
    const data = DashboardData(
      studentName: 'Test Student',
      courses: [
        PortalCourse(
            name: 'Gamma',
            teacher: 'T C',
            code: 'C101',
            credits: 3.0,
            attendance: 70.0,
            infoUrl: ''),
      ],
    );
    const slots = [
      TimetableSlot(
          day: 'Monday',
          start: '08:00',
          end: '08:55',
          subject: 'Other',
          teacher: '',
          section: '',
          room: ''),
    ];
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
              timetableSlots: slots,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ongoing'));
    await tester.tap(find.text('Ongoing'));
    await tester.pumpAndSettle();
    expect(find.text('Gamma'), findsNothing);
    // Filter empty state (exact text without emoji; the timeline section
    // shows its own day-off card above it).
    expect(find.text('No classes today — enjoy the day off'),
        findsOneWidget);
  });

  testWidgets('course detail shows live weekly classes',
      (WidgetTester tester) async {
    const course = Course(
      code: 'CP223',
      title: 'Object Oriented Programming',
      prof: 'Aasma Abdul Waheed',
      room: 'B-CL203 ( Lab )',
      time: 'Mon 08:00',
      credits: 3,
      progress: 67,
      grade: '–',
      tone: CourseTone.teal,
    );
    const slots = [
      TimetableSlot(
          day: 'Monday',
          start: '08:00',
          end: '08:55',
          subject: 'Object Oriented Programming',
          teacher: 'Aasma Abdul Waheed',
          section: 'CP223',
          room: 'C-301'),
      TimetableSlot(
          day: 'Wednesday',
          start: '09:00',
          end: '09:55',
          subject: 'Object Oriented Programming - Lab',
          teacher: 'S X',
          section: 'CP221',
          room: 'B-CL203 ( Lab )'),
    ];
    final colors = AppColors.of(AppPalette.skater, false);
    await tester.pumpWidget(
      AppScope(
        colors: colors,
        palette: AppPalette.skater,
        child: MaterialApp(
          home: Scaffold(
            body: DetailScreen(
                course: course, slots: slots, isLive: true, back: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This week'), findsOneWidget);
    expect(find.textContaining('Monday'), findsWidgets);
    // The lab slot belongs to the Lab course, not the theory detail.
    expect(find.textContaining('Wednesday'), findsNothing);
    expect(find.text('Assignment 3'), findsNothing);
  });
}
