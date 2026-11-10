// Throwaway screenshot dump: renders every major screen in dark and
// light mode at phone width and writes PNGs to /tmp/opencode/shots/.
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/app.dart';
import 'package:ucp/auth/course_cache.dart';
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
import 'package:ucp/screens/consent.dart';
import 'package:ucp/screens/fee_board.dart';
import 'package:ucp/screens/gpa_timetable.dart';
import 'package:ucp/gpa_vault/vault_home_screen.dart';
import 'package:ucp/gpa_vault/vault_semesters_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ucp/gpa_vault/vault_grading_screen.dart';
import 'package:ucp/screens/leaderboard.dart';
import 'package:ucp/screens/community.dart';
import 'package:ucp/screens/course_detail.dart';
import 'package:ucp/screens/profile.dart';
import 'package:ucp/screens/results.dart';
import 'package:ucp/screens/teachers.dart';
import 'package:ucp/teachers/teacher_service.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

class _DumpComparator extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final f = File('/tmp/opencode/shots/${golden.pathSegments.last}')
      ..createSync(recursive: true);
    await f.writeAsBytes(imageBytes);
    return true; // never fail — we only want the bytes
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    await File('/tmp/opencode/shots/${golden.pathSegments.last}')
        .writeAsBytes(imageBytes);
  }
}

Widget _wrap(
  Widget child, {
  bool dark = true,
}) {
  const palette = AppPalette.leap;
  final colors = AppColors.of(palette, dark);
  return AppScope(
    colors: colors,
    palette: palette,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeFor(colors),
      darkTheme: themeFor(colors),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(body: child),
    ),
  );
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  // GoogleFonts loads from the asset bundle asynchronously — the fake
  // test clock does not wait for it (partially rendered glyph sets).
  // Let the real event loop drain, then settle and capture.
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 900)));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('$name.png'),
  );
}

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
      const LeaderboardRoster(
        rosterSize: 42,
        classmates: 41,
        youAreIn: true,
        sections: ['CP233-R26-BS-SE-F24-SED1'],
      );
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
    String studentImage = '',
  }) async {}
  @override
  Future<LeaderboardResult> fetchLeaderboard({
    required String courseName,
    String? studentId,
    String? courseCode,
  }) async =>
      LeaderboardResult(
        entries: [
          const LeaderboardEntry(rank: 1, studentName: 'Hira Shahzad', studentId: 'H1', imageUrl: '', percentage: 91.3, grade: 'A'),
          const LeaderboardEntry(rank: 2, studentName: 'Test Student', studentId: 'ME', imageUrl: '', percentage: 87.25, grade: 'A', isMe: true),
          const LeaderboardEntry(rank: 3, studentName: 'Anonymous', studentId: 'hidden', imageUrl: '', percentage: 74.0, grade: 'B'),
          const LeaderboardEntry(rank: 4, studentName: 'Usman Aamer', studentId: 'U4', imageUrl: '', percentage: 66.5, grade: 'C+'),
          const LeaderboardEntry(rank: 5, studentName: 'Bilal Khan', studentId: 'B5', imageUrl: '', percentage: 52.2, grade: 'D+'),
        ],
        remainingCredits: 42,
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
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    // MaterialIcons are not rasterized by the test binding by default —
    // load the SDK's own copy so icons render in the dumps.
    const sdkFonts =
        '/home/ubuntu/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    final bytes = File(sdkFonts).existsSync()
        ? File(sdkFonts).readAsBytesSync()
        : Uint8List(0);
    if (File(sdkFonts).existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future<ByteData>.value(
            ByteData.view(Uint8List.fromList(bytes).buffer)));
      await loader.load();
    }

    // Default-family text (plain TextStyle) rasterizes as tofu in tests
    // unless a Roboto is registered — load the SDK copies.
    const sdkm =
        '/home/ubuntu/flutter/bin/cache/artifacts/material_fonts';
    if (Directory(sdkm).existsSync()) {
      Future<ByteData> bytesOf(String f) async => ByteData.view(
          Uint8List.fromList(File('$sdkm/$f').readAsBytesSync()).buffer);
      final roboto = FontLoader('Roboto');
      for (final f in const [
        'Roboto-Regular.ttf',
        'Roboto-Medium.ttf',
        'Roboto-Bold.ttf',
        'Roboto-Black.ttf',
        'Roboto-Light.ttf',
        'Roboto-Thin.ttf',
      ]) {
        roboto.addFont(bytesOf(f));
      }
      await roboto.load();
    }
    Directory('/tmp/opencode/shots').createSync(recursive: true);
    goldenFileComparator = _DumpComparator();
  });

  for (final dark in [true, false]) {
    final mode = dark ? 'dark' : 'light';
    const size = Size(390, 844); // phone portrait

    testWidgets('leaderboard $mode', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      await _shot(tester, 'leaderboard_$mode');
    });

    testWidgets('home $mode', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        CampusApp(
          skipLogin: true,
          initialPrefs: ProfilePrefs(
            theme: dark ? ThemeModePref.dark : ThemeModePref.light,
          ),
        ),
      );
      await _shot(tester, 'home_$mode');
    });

    testWidgets('consent $mode', (tester) async {
      await tester.pumpWidget(_wrap(ConsentScreen(onAccept: _asyncNoop, onDecline: _asyncNoop), dark: dark));
      await _shot(tester, 'consent_$mode');
    });

    testWidgets('profile $mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProfileScreen(
            logout: () {},
            prefs: ProfilePrefs(
              theme: dark ? ThemeModePref.dark : ThemeModePref.light,
            ),
            onPrefs: (_) {},
            studentName: 'Ayaan Warraich',
            email: 't@ucp.edu.pk',
            earnedCredits: 30.0,
          ),
          dark: dark,
        ),
      );
      await _shot(tester, 'profile_$mode');
    });

    const attHtml =
        '<h3><div><span>Data Structures</span>'
        '<div><span>Attendance: 83.0%</span></div></div></h3>'
        '<table class="uk-table"><tr><th>Sr. no</th><th>Date</th><th>Status</th><th>Fine</th></tr>'
        '<tr><td>1</td><td>2026-09-28</td><td>Absent</td><td>-</td></tr>'
        '<tr><td>2</td><td>2026-09-29</td><td>Present</td><td>-</td></tr>'
        '<tr><td>3</td><td>2026-10-01</td><td>Present</td><td>-</td></tr></table>';
    testWidgets('attendance $mode', (tester) async {
      await tester.pumpWidget(_wrap(AttendanceScreen(debugHtml: attHtml), dark: dark));
      await _shot(tester, 'attendance_$mode');
    });

    const feeHtml =
        '<table class="uk-table uk-table-nowrap table_check">'
        '<tr><th>Invoice Date</th><th>Due Date</th><th>Term</th><th>Semester</th>'
        '<th>Challan Type</th><th>Challan ID</th><th>Scholarship %</th>'
        '<th>Payable Amount</th><th>Status</th><th>Print/Save</th><th>Action</th>'
        '<th>Paid Date</th></tr>'
        '<tr><td>2026-09-29</td><td>2026-10-15</td><td>Fall 2026</td><td>-</td>'
        '<td>Main Challan</td><td>145830580658</td><td>50.0</td><td>86800</td>'
        '<td>Unpaid</td><td></td><td></td><td>-</td></tr></table>';
    testWidgets('fee $mode', (tester) async {
      await tester.pumpWidget(_wrap(FeeChallanScreen(debugHtml: feeHtml), dark: dark));
      await _shot(tester, 'fee_$mode');
    });

    const resHtml =
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
    testWidgets('results $mode', (tester) async {
      await tester.pumpWidget(_wrap(ResultsScreen(debugHtml: resHtml), dark: dark));
      await _shot(tester, 'results_$mode');
    });

    testWidgets('teachers $mode', (tester) async {
      await tester.pumpWidget(
        _wrap(TeachersScreen(service: FakeTeacherService(), myEmail: 't@ucp.edu.pk'), dark: dark),
      );
      await _shot(tester, 'teachers_$mode');
    });

    const newsHtml = '<table><thead><tr><th>Sr No.</th><th>Subject</th>'
        '<th>Date</th><th>Description</th><th>Attachment</th></tr></thead>'
        '<tbody><tr><td>1</td><td>Midterm venue</td>'
        '<td>2026-10-10</td><td>Room C-301</td><td></td></tr></tbody></table>';

    const gradeHtml = '<table><tr class="table-parent-row show_child_row">'
        '<td><a href="#" class="js-toggle-children-row toggle-childrens">'
        ' Quiz <div class="uk-badge md-bg-orange-800"> 15.0 % </div>'
        ' </a> </td> <td>80.00</td></tr>'
        '<tr class="table-child-row md-bg-blue-grey-800"><th>Assessment</th><th>Max Mark</th><th>Obtained Marks</th><th>Class Average</th><th>Percentage</th></tr>'
        '<tr class="table-child-row"><td>Quiz 1</td><td>20</td><td>16.00</td><td>12.00</td><td>80.00</td></tr>'
        '<tr class="table-parent-row show_child_row">'
        '<td><a href="#" class="js-toggle-children-row toggle-childrens">'
        ' Final <div class="uk-badge md-bg-orange-800"> 40.0 % </div>'
        ' </a> </td> <td>72.00</td></tr>'
        '<tr class="table-child-row md-bg-blue-grey-800"><th>Assessment</th><th>Max Mark</th><th>Obtained Marks</th><th>Class Average</th><th>Percentage</th></tr>'
        '<tr class="table-child-row"><td>Final Exam</td><td>100</td><td>72.00</td><td>60.00</td><td>72.00</td></tr></table>';

    const outlineHtml =
        '<h5>Course Objectives:</h5>'
        '<ul>'
        '<li>Understand fundamental data structures and algorithms including arrays, linked lists, stacks, queues, trees and graphs along with their proofs of correctness.</li>'
        '<li>Analyze the time and space complexity of algorithmic solutions using Big-O notation and compare alternative designs.</li>'
        '<li>Design and implement complete solutions using appropriate data structures in C++ or Java with proper testing.</li>'
        '</ul>'
        '<h5>Learning Outcomes:</h5>'
        '<table><thead><tr><th>CLO</th><th>Statement</th><th>Bloom</th><th>PLO</th></tr></thead>'
        '<tbody>'
        '<tr><td>CLO1</td><td>Apply fundamental concepts of linear and non-linear data structures</td><td>Apply</td><td>PLO2</td></tr>'
        '<tr><td>CLO2</td><td>Design efficient algorithms for complex problem solving tasks</td><td>Analyze</td><td>PLO4</td></tr>'
        '<tr><td>CLO3</td><td>Evaluate complexity tradeoffs between competing implementations</td><td>Evaluate</td><td>PLO6</td></tr>'
        '</tbody></table>'
        '<h5>Text Books:</h5>'
        '<table><thead><tr><th>Sr</th><th>Title</th><th>Authors</th><th>Edition</th><th>Publisher</th><th>Year</th></tr></thead>'
        '<tbody>'
        '<tr><td>1</td><td>Data Structures and Algorithms in C++</td><td>Goodrich, Tamassia, Goldwasser</td><td>2nd</td><td>Wiley</td><td>2014</td></tr>'
        '<tr><td>2</td><td>The Algorithm Design Manual</td><td>Skiena, S.</td><td>3rd</td><td>Springer</td><td>2020</td></tr>'
        '</tbody></table>'
        '<h5>Weekly Plan:</h5>'
        '<table><thead><tr><th>Week</th><th>Contents</th><th>Activity</th><th>Files</th></tr></thead>'
        '<tbody>'
        '<tr><td>1</td><td>Introduction to data structures and algorithm analysis</td><td>Lecture</td><td></td></tr>'
        '<tr><td>2</td><td>Arrays, stacks, queues and linked lists</td><td>Lecture + Lab</td><td>chapter2.pdf</td></tr>'
        '<tr><td>3</td><td>Trees, heaps and hash tables</td><td>Lecture + Lab</td><td></td></tr>'
        '<tr><td>4</td><td>Graphs, shortest paths and minimum spanning trees</td><td>Lecture</td><td></td></tr>'
        '</tbody></table>'
        '<h5>Assessment and Evaluation:</h5>'
        '<table><thead><tr><th>Assessment Type</th><th>Weightage %</th><th>Consider Top</th></tr></thead>'
        '<tbody>'
        '<tr><td>Final Term</td><td>40.0</td><td>0</td></tr>'
        '<tr><td>Midterm</td><td>25.0</td><td>0</td></tr>'
        '<tr><td>Class Quizzes</td><td>15.0</td><td>3</td></tr>'
        '<tr><td>Assignments</td><td>10.0</td><td>0</td></tr>'
        '<tr><td>Labs</td><td>10.0</td><td>0</td></tr>'
        '</tbody></table>';

    const submissionsHtml =
        '<table><thead><tr><th>Sr</th><th>Name</th><th>Description</th><th>Start Date</th><th>Due Date</th><th>Attachment</th></tr></thead>'
        '<tbody>'
        '<tr><td>1</td><td>Assignment 3 — Balanced Trees</td><td>Implement an AVL tree with insertion, deletion and in-order traversal. Submit the source code along with a brief complexity analysis of each tree operation, justifying the O(log n) bound with rotations explained.</td><td>2026-11-01 09:00:00</td><td>2026-12-14 23:59:00</td><td><a href="/student/class/material/download/a1">assignment3-spec.pdf</a></td></tr>'
        '<tr><td>2</td><td>Lab Report 5 — Hashing</td><td>Hashing lab with chaining and linear probing analysis</td><td>2026-11-20 09:00:00</td><td>2026-11-27 23:59:00</td><td></td></tr>'
        '<tr><td>3</td><td>Quiz 3 — Trees and Graphs</td><td>Closed book quiz covering tree traversals and BFS/DFS</td><td>2026-10-15 09:00:00</td><td>2026-10-22 23:59:00</td><td></td></tr>'
        '</tbody></table>';

    CourseDetailScreen buildCourse(Map<String, String> html) => CourseDetailScreen(
          portalCourse: const PortalCourse(
            name: 'Object Oriented Programming',
            teacher: 'Aasma Abdul Waheed',
            code: 'CP223',
            credits: 3.0,
            attendance: 75.0,
            infoUrl: '/student/course/info/pBG3ykar5ZOkdJ8v4NYV',
          ),
          back: _noop,
          debugHtml: html,
        );

    testWidgets('course outline $mode', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      CourseDetailCache.clear();
      await tester.pumpWidget(
        _wrap(buildCourse({'outline': outlineHtml, 'news': newsHtml}), dark: dark),
      );
      await tester.pumpAndSettle();
      final tab = find.text('Outline');
      if (tab.evaluate().isNotEmpty) {
        await tester.tap(tab.first, warnIfMissed: false);
        await tester.pumpAndSettle();
      }
      await _shot(tester, 'course_outline_$mode');
    });

    testWidgets('course submissions $mode', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      CourseDetailCache.clear();
      await tester.pumpWidget(
        _wrap(buildCourse({'submission': submissionsHtml, 'news': newsHtml}), dark: dark),
      );
      await tester.pumpAndSettle();
      final tab = find.text('Submit');
      if (tab.evaluate().isNotEmpty) {
        await tester.ensureVisible(tab.first);
        await tester.pumpAndSettle();
        await tester.tap(tab.first, warnIfMissed: false);
        await tester.pumpAndSettle();
      }
      await _shot(tester, 'course_submissions_$mode');
    });

    testWidgets('course grades $mode', (tester) async {
      CourseDetailCache.clear();
      await tester.pumpWidget(
        _wrap(
          const CourseDetailScreen(
            portalCourse: PortalCourse(
              name: 'Object Oriented Programming',
              teacher: 'Aasma Abdul Waheed',
              code: 'CP223',
              credits: 3.0,
              attendance: 75.0,
              infoUrl: '/student/course/info/pBG3ykar5ZOkdJ8v4NYV',
            ),
            back: _noop,
            debugHtml: {
              'news': '<table><thead><tr><th>Sr No.</th><th>Subject</th>'
                  '<th>Date</th><th>Description</th><th>Attachment</th></tr></thead>'
                  '<tbody><tr><td>1</td><td>Midterm venue</td>'
                  '<td>2026-10-10</td><td>Room C-301</td><td></td></tr></tbody></table>',
              'gradebook': gradeHtml,
            },
          ),
          dark: dark,
        ),
      );
      await tester.pumpAndSettle();
      // The grades tab carries the ring hero.
      final gradesTab = find.text('Grades');
      if (gradesTab.evaluate().isNotEmpty) {
        await tester.tap(gradesTab.first, warnIfMissed: false);
        await tester.pumpAndSettle();
      }
      await _shot(tester, 'course_grades_$mode');
    });

    testWidgets('community $mode', (tester) async {
      final svc = FakeCommunityService();
      await tester.pumpWidget(
        _wrap(CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk'), dark: dark),
      );
      await _shot(tester, 'community_$mode');
      svc.dispose();
    });

    const ttHtml =
        '<div><b>Term :</b> <span>Fall 2026</span></div>'
        '<div><b>Month :</b> <span>October </span></div>'
        '<li class="cd-schedule__group">'
        '<div class="cd-schedule__top-info"><span>Monday</span></div><ul>'
        '<li class="cd-schedule__event"><a data-start="08:00" data-end="08:55">'
        '<em>Dr. A Khan</em>'
        '<span>Object Oriented Programming - Lab</span>'
        '<span>CP221-F26</span><span>B-CL203 ( Lab )</span>'
        '</a></li></ul></li>';
    const dsHtml =
        '<h3>DateSheet</h3><div><h3>Currently No Exam DateSheet Notified!</h3></div>';

    testWidgets('timetable $mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TimetableScreen(
            fetchHtml: (path) async =>
                path.contains('datesheet') ? dsHtml : ttHtml,
          ),
          dark: dark,
        ),
      );
      await _shot(tester, 'timetable_$mode');
    });

    testWidgets('vault semesters $mode', (tester) async {
      await tester.pumpWidget(
        _wrap(const VaultSemestersScreen(), dark: dark),
      );
      await _shot(tester, 'vault_semesters_$mode');
    });

    testWidgets('vault grading $mode', (tester) async {
      await tester.pumpWidget(
        _wrap(const VaultGradingScreen(), dark: dark),
      );
      await _shot(tester, 'vault_grading_$mode');
    });

    testWidgets('vault (live gpa tab) $mode', (tester) async {
      await tester.pumpWidget(
        _wrap(const VaultHomeScreen(initialTab: 1), dark: dark),
      );
      await _shot(tester, 'vaultcalc_$mode');
    });

    testWidgets('gpa $mode', (tester) async {
      await tester.pumpWidget(_wrap(const GpaCalcScreen(), dark: dark));
      await _shot(tester, 'gpa_$mode');
    });
  }
}

void _noop() {}
Future<void> _asyncNoop() async {}
