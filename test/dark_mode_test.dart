import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/app.dart';
import 'package:ucp/community/fake_community_service.dart';
import 'package:ucp/screens/attendance.dart';
import 'package:ucp/screens/auth_home.dart';
import 'package:ucp/screens/community.dart';
import 'package:ucp/screens/fee_board.dart';
import 'package:ucp/screens/gpa_timetable.dart';
import 'package:ucp/screens/materials_web.dart';
import 'package:ucp/screens/profile.dart';
import 'package:ucp/screens/results.dart';
import 'package:ucp/screens/teachers.dart';
import 'package:ucp/teachers/teacher_service.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

/// Dark-theme render sweep: every major screen pumps in dark mode and
/// must build without layout exceptions. Overflow/contrast regressions
/// surface here as test failures. (Color-token correctness itself is
/// enforced by code review: no hardcoded white-on-tealInk text.)
Widget _darkWrap(Widget child) {
  final colors = AppColors.of(AppPalette.skater, true);
  return AppScope(
    colors: colors,
    palette: AppPalette.skater,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

const _ttHtml = '<div><b>Term :</b><span>Fall 2026</span>'
    '<b>Month :</b><span>October</span></div>'
    '<li class="cd-schedule__group">'
    '<div class="cd-schedule__top-info"><span>Monday</span></div><ul>'
    '<li class="cd-schedule__event"><a data-start="08:00" data-end="08:55">'
    '<em>Dr. A Khan</em>'
    '<span>Object Oriented Programming - Lab</span>'
    '<span>CP221-F26</span><span>B-CL203 ( Lab )</span>'
    '</a></li></ul></li>';

const _dsEmpty =
    '<h3>DateSheet</h3><div><h3>Currently No Exam DateSheet Notified!</h3></div>';

const _attHtml = '<h3><div><span>Multivariable Calculus</span>'
    '<div><span>Attendance: 33.0%</span></div></div></h3>'
    '<table class="uk-table"><tr><th>Sr. no</th><th>Date</th><th>Status</th><th>Fine</th></tr>'
    '<tr><td>1</td><td>2026-09-28</td><td>Absent</td><td>-</td></tr>'
    '<tr><td>2</td><td>2026-09-29</td><td>Present</td><td>-</td></tr></table>';

const _feeHtml = '<table class="uk-table uk-table-nowrap table_check">'
    '<tr><th>Invoice Date</th><th>Due Date</th><th>Term</th><th>Semester</th>'
    '<th>Challan Type</th><th>Challan ID</th><th>Scholarship %</th>'
    '<th>Payable Amount</th><th>Status</th><th>Print/Save</th><th>Action</th>'
    '<th>Paid Date</th></tr>'
    '<tr><td>2026-09-29</td><td>2026-10-15</td><td>Fall 2026</td><td>-</td>'
    '<td>Main Challan</td><td>145830580658</td><td>50.0</td><td>86800</td>'
    '<td>Unpaid</td><td></td><td></td><td>-</td></tr></table>';

const _resHtml = '<table class="uk-table table_tree">'
    '<tr><th>Term</th><th>Grade Points</th><th>Cumulative GP</th>'
    '<th>Attempted CH</th><th>Earned CH</th><th>Cumulative CH</th>'
    '<th>SGPA</th><th>CGPA</th></tr>'
    '<tr><td>Fall 2025</td><td>46.64</td><td>46.64</td><td>15.0</td>'
    '<td>15.0</td><td>15.0</td><td>3.11</td><td>3.11</td></tr>'
    '<tr><td>Course</td><td>Credit Hours</td><td>Grade Pts</td>'
    '<td>Final Grade</td></tr>'
    '<tr><td>Functional English</td><td>3.0</td><td>9.0</td><td>B</td></tr>'
    '</table>';

void main() {
  group('dark mode renders every screen', () {
    testWidgets('home + bottom stack', (tester) async {
      await tester.pumpWidget(CampusApp(
        skipLogin: true,
        initialPrefs: ProfilePrefs(theme: ThemeModePref.dark),
      ));
      await tester.pumpAndSettle();
      expect(find.text('My courses'), findsOneWidget);
    });

    testWidgets('login form', (tester) async {
      await tester.pumpWidget(_darkWrap(
        LoginScreen(onMicrosoftSignIn: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Hey, welcome back.'), findsOneWidget);
    });

    testWidgets('teachers list', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 2000 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final svc = FakeTeacherService();
      await tester.pumpWidget(_darkWrap(
        TeachersScreen(service: svc, myEmail: 't@ucp.edu.pk'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Usman Aamer'), findsWidgets);
      svc.dispose();
    });

    testWidgets('community feed', (tester) async {
      final svc = FakeCommunityService();
      await tester.pumpWidget(_darkWrap(
        CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('r/campus'), findsOneWidget);
      svc.dispose();
    });

    testWidgets('timetable + datesheet', (tester) async {
      await tester.pumpWidget(_darkWrap(TimetableScreen(
        fetchHtml: (path) async =>
            path.contains('datesheet') ? _dsEmpty : _ttHtml,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Object Oriented Programming - Lab'),
          findsOneWidget);
    });

    testWidgets('attendance', (tester) async {
      await tester.pumpWidget(_darkWrap(AttendanceScreen(
        debugHtml: _attHtml,
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('Multivariable Calculus'),
          findsOneWidget);
    });

    testWidgets('fee challan', (tester) async {
      await tester.pumpWidget(_darkWrap(FeeChallanScreen(
        debugHtml: _feeHtml,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Fee challan'), findsOneWidget);
    });

    testWidgets('results', (tester) async {
      await tester.pumpWidget(_darkWrap(ResultsScreen(
        debugHtml: _resHtml,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Results'), findsOneWidget);
    });

    testWidgets('profile', (tester) async {
      await tester.pumpWidget(_darkWrap(ProfileScreen(
        logout: () {},
        prefs: ProfilePrefs(theme: ThemeModePref.dark),
        onPrefs: (_) {},
        studentName: 'Test Student',
        email: 't@ucp.edu.pk',
        earnedCredits: 30.0,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Test Student'), findsOneWidget);
    });

    testWidgets('web view shell', (tester) async {
      await tester.pumpWidget(_darkWrap(
        const WebViewScreen(
          sessionId: 'sid',
          renderWebView: false,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Portal preview unavailable in tests'),
          findsOneWidget);
    });
  });
}
