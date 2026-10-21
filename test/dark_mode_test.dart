/* Theme render sweep: every major screen must build in LIGHT and in DARK
 * mode, with the real Material theme applied (so dialogs, sheets,
 * switches, inputs and snackbars follow the mode too) and WITHOUT layout
 * exceptions.
 *
 * Colour-token correctness is enforced structurally: screens read their
 * colours from AppColors via AppScope and the palette provides the light
 * and dark variants for all six palettes (see palette.test.dart).
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/app.dart';
import 'package:ucp/auth/student_portal.dart' show PortalCourse;
import 'package:ucp/community/fake_community_service.dart';
import 'package:ucp/leaderboard/leaderboard_service.dart'
    show
        LeaderboardService,
        LeaderboardResult,
        LeaderboardRoster,
        LeaderboardEntry,
        LeaderboardPrivacy;
import 'package:ucp/screens/attendance.dart';
import 'package:ucp/screens/auth_home.dart';
import 'package:ucp/screens/community.dart';
import 'package:ucp/screens/fee_board.dart';
import 'package:ucp/screens/gpa_timetable.dart';
import 'package:ucp/screens/leaderboard.dart';
import 'package:ucp/screens/materials_web.dart';
import 'package:ucp/screens/profile.dart';
import 'package:ucp/screens/results.dart';
import 'package:ucp/screens/teachers.dart';
import 'package:ucp/teachers/teacher_service.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

Widget _wrap(
  Widget child, {
  AppPalette palette = AppPalette.skater,
  bool dark = true,
}) {
  final colors = AppColors.of(palette, dark);
  return AppScope(
    colors: colors,
    palette: palette,
    child: MaterialApp(
      theme: themeFor(colors),
      darkTheme: themeFor(colors),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(body: child),
    ),
  );
}

const _ttHtml =
    '<div><b>Term :</b><span>Fall 2026</span>'
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

const _attHtml =
    '<h3><div><span>Multivariable Calculus</span>'
    '<div><span>Attendance: 33.0%</span></div></div></h3>'
    '<table class="uk-table"><tr><th>Sr. no</th><th>Date</th><th>Status</th><th>Fine</th></tr>'
    '<tr><td>1</td><td>2026-09-28</td><td>Absent</td><td>-</td></tr>'
    '<tr><td>2</td><td>2026-09-29</td><td>Present</td><td>-</td></tr></table>';

const _feeHtml =
    '<table class="uk-table uk-table-nowrap table_check">'
    '<tr><th>Invoice Date</th><th>Due Date</th><th>Term</th><th>Semester</th>'
    '<th>Challan Type</th><th>Challan ID</th><th>Scholarship %</th>'
    '<th>Payable Amount</th><th>Status</th><th>Print/Save</th><th>Action</th>'
    '<th>Paid Date</th></tr>'
    '<tr><td>2026-09-29</td><td>2026-10-15</td><td>Fall 2026</td><td>-</td>'
    '<td>Main Challan</td><td>145830580658</td><td>50.0</td><td>86800</td>'
    '<td>Unpaid</td><td></td><td></td><td>-</td></tr></table>';

const _resHtml =
    '<table class="uk-table table_tree">'
    '<tr><th>Term</th><th>Grade Points</th><th>Cumulative GP</th>'
    '<th>Attempted CH</th><th>Earned CH</th><th>Cumulative CH</th>'
    '<th>SGPA</th><th>CGPA</th></tr>'
    '<tr><td>Fall 2025</td><td>46.64</td><td>46.64</td><td>15.0</td>'
    '<td>15.0</td><td>15.0</td><td>3.11</td><td>3.11</td></tr>'
    '<tr><td>Course</td><td>Credit Hours</td><td>Grade Pts</td>'
    '<td>Final Grade</td></tr>'
    '<tr><td>Functional English</td><td>3.0</td><td>9.0</td><td>B</td></tr>'
    '</table>';

/// Minimal offline backend for the render sweep.
class _FakeLeaderboardService extends LeaderboardService {
  @override
  Future<List<String>> fetchCourses({String? studentId}) async => const [
    'Data Structures (CP233-R26)',
  ];
  @override
  Future<LeaderboardRoster> fetchRoster({
    required String courseName,
    String? studentId,
    String? courseCode,
  }) async =>
      const LeaderboardRoster(rosterSize: 0, classmates: 0, youAreIn: false);
  @override
  Future<void> syncTimetable({
    required String studentId,
    required List<Map<String, String>> rows,
  }) async {}
  @override
  Future<void> syncGrades({
    required String studentId,
    required String studentName,
    required String courseName,
    required String courseCode,
    required double overallPercentage,
    required String grade,
    required List<Map<String, dynamic>> assessments,
  }) async {}
  @override
  Future<LeaderboardResult> fetchLeaderboard({
    required String courseName,
    String? studentId,
    String? courseCode,
  }) async => const LeaderboardResult(
    entries: [
      LeaderboardEntry(
        rank: 1,
        studentName: 'Classmate',
        studentId: 'OTHER',
        imageUrl: '',
        percentage: 80.0,
        grade: 'A',
      ),
    ],
    free: true,
  );
  @override
  Future<LeaderboardPrivacy> fetchPrivacy(String studentId) async =>
      const LeaderboardPrivacy();
  @override
  Future<LeaderboardPrivacy> savePrivacy(
    String studentId, {
    required bool hideName,
    required bool hidePhoto,
  }) async => LeaderboardPrivacy(hideName: hideName, hidePhoto: hidePhoto);
  @override
  void dispose() {}
}

void main() {
  for (final dark in [true, false]) {
    final mode = dark ? 'dark' : 'light';

    group('the app renders every screen in $mode mode', () {
      testWidgets('home + bottom stack', (tester) async {
        await tester.pumpWidget(
          CampusApp(
            skipLogin: true,
            initialPrefs: ProfilePrefs(
              theme: dark ? ThemeModePref.dark : ThemeModePref.light,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('My courses'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('login form', (tester) async {
        await tester.pumpWidget(
          _wrap(LoginScreen(onMicrosoftSignIn: (_) {}), dark: dark),
        );
        await tester.pumpAndSettle();
        expect(find.text('Hey, welcome back.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('teachers list', (tester) async {
        tester.view.physicalSize = const Size(320 * 3, 2000 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final svc = FakeTeacherService();
        await tester.pumpWidget(
          _wrap(
            TeachersScreen(service: svc, myEmail: 't@ucp.edu.pk'),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Usman Aamer'), findsWidgets);
        expect(tester.takeException(), isNull);
        svc.dispose();
      });

      testWidgets('community feed', (tester) async {
        final svc = FakeCommunityService();
        await tester.pumpWidget(
          _wrap(
            CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk'),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('r/campus'), findsOneWidget);
        expect(tester.takeException(), isNull);
        svc.dispose();
      });

      testWidgets('timetable + datesheet', (tester) async {
        await tester.pumpWidget(
          _wrap(
            TimetableScreen(
              fetchHtml: (path) async =>
                  path.contains('datesheet') ? _dsEmpty : _ttHtml,
            ),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Object Oriented Programming - Lab'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('attendance', (tester) async {
        await tester.pumpWidget(
          _wrap(AttendanceScreen(debugHtml: _attHtml), dark: dark),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Multivariable Calculus'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('fee challan', (tester) async {
        await tester.pumpWidget(
          _wrap(FeeChallanScreen(debugHtml: _feeHtml), dark: dark),
        );
        await tester.pumpAndSettle();
        expect(find.text('Fee challan'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('results', (tester) async {
        await tester.pumpWidget(
          _wrap(ResultsScreen(debugHtml: _resHtml), dark: dark),
        );
        await tester.pumpAndSettle();
        expect(find.text('Results'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('profile', (tester) async {
        await tester.pumpWidget(
          _wrap(
            ProfileScreen(
              logout: () {},
              prefs: ProfilePrefs(
                theme: dark ? ThemeModePref.dark : ThemeModePref.light,
              ),
              onPrefs: (_) {},
              studentName: 'Test Student',
              email: 't@ucp.edu.pk',
              earnedCredits: 30.0,
            ),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Test Student'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('web view shell', (tester) async {
        await tester.pumpWidget(
          _wrap(
            const WebViewScreen(sessionId: 'sid', renderWebView: false),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Portal preview unavailable in tests'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('leaderboard', (tester) async {
        await tester.pumpWidget(
          _wrap(
            LiveLeaderboardScreen(
              service: _FakeLeaderboardService(),
              studentId: 'ME',
              portalCourses: const [
                PortalCourse(
                  name: 'Data Structures',
                  teacher: 'T',
                  code: 'CP233',
                  credits: 3,
                  attendance: 0,
                  infoUrl: '/student/course/info/AAA111',
                ),
              ],
              back: () {},
            ),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Leaderboard'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
