
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ucp/auth/student_portal.dart' show PortalCourse;
import 'package:ucp/community/backend_config.dart';
import 'package:ucp/leaderboard/leaderboard_service.dart';
import 'package:ucp/screens/course_detail.dart';
import 'package:ucp/screens/leaderboard.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

const _pc2 = PortalCourse(
  name: 'Object Oriented Programming',
  teacher: 'Aasma Abdul Waheed',
  code: 'CP223',
  credits: 3.0,
  attendance: 75.0,
  infoUrl: '/student/course/info/TEST1234abcd',
);

Widget _wrap(Widget child) {
  final colors = AppColors.of(AppPalette.skater, false);
  return AppScope(
    colors: colors,
    palette: AppPalette.skater,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

/// In-memory backend for widget tests.
class FakeLeaderboardService extends LeaderboardService {
  List<String> courses;
  List<Map<String, dynamic>> rows;
  Object? throwOnBoard;
  int? credits;
  int boardCalls = 0;
  int timetableSyncs = 0;
  int gradeSyncs = 0;
  List<Map<String, String>>? lastTimetableRows;
  String? lastGrade;
  double lastOverall = 0;
  LeaderboardRoster roster = const LeaderboardRoster(
    rosterSize: 0,
    classmates: 0,
    youAreIn: false,
  );

  FakeLeaderboardService({
    this.courses = const [
      'Data Structures (CP233-R26-BS-SE-F24-SED1)',
      'OOP (CP223-R26)',
    ],
    this.rows = const [],
    this.credits,
    this.roster = const LeaderboardRoster(
      rosterSize: 0,
      classmates: 0,
      youAreIn: false,
    ),
  });

  @override
  Future<List<String>> fetchCourses({String? studentId}) async => courses;

  @override
  Future<LeaderboardRoster> fetchRoster({
    required String courseName,
    String? studentId,
  }) async =>
      roster;

  @override
  Future<void> syncTimetable({
    required String studentId,
    required List<Map<String, String>> rows,
  }) async {
    timetableSyncs++;
    lastTimetableRows = rows;
  }

  @override
  Future<void> syncGrades({
    required String studentId,
    required String studentName,
    required String courseName,
    required String courseCode,
    required double overallPercentage,
    required String grade,
    required List<Map<String, dynamic>> assessments,
  }) async {
    gradeSyncs++;
    lastGrade = grade;
    lastOverall = overallPercentage;
  }

  @override
  Future<LeaderboardResult> fetchLeaderboard(
      {required String courseName, String? studentId}) async {
    boardCalls++;
    if (throwOnBoard != null) {
      throw throwOnBoard!; // ignore: avoid_catching_errors
    }
    final entries = <LeaderboardEntry>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final id = '${r['studentId'] ?? ''}';
      entries.add(LeaderboardEntry(
        rank: i + 1,
        studentName: '${r['studentName'] ?? ''}',
        studentId: id,
        imageUrl: '${r['studentImage'] ?? ''}',
        percentage: (r['overallPercentage'] as num?)?.toDouble() ?? 0,
        grade: '${r['grade'] ?? ''}',
        isMe: (studentId ?? '').isNotEmpty && id == studentId,
      ));
    }
    return LeaderboardResult(entries: entries, remainingCredits: credits);
  }

  @override
  void dispose() {}
}

void main() {
  group('NodeLeaderboardService (mocked backend)', () {
    // Non-empty injected key: http drops empty header values, and the
    // const env key is '' in tests — so both call sites get asserted
    // through this seam.
    NodeLeaderboardService svc(http.Client client) =>
        NodeLeaderboardService(
            client: client, apiKey: 'test-key-1234567890abcdef');

    test('fetchCourses sends the x-api-key header (regression)',
        () async {
      var sawHeader = false;
      final s = svc(MockClient((req) async {
        expect(req.headers['x-api-key'], 'test-key-1234567890abcdef');
        sawHeader = true;
        return http.Response('[]', 200);
      }));
      await s.fetchCourses();
      expect(sawHeader, isTrue);
      s.dispose();
    });

    test('leaderboard call ALSO sends the header (the 401 bug)',
        () async {
      var sawHeader = false;
      final s = svc(MockClient((req) async {
        expect(req.headers['x-api-key'], 'test-key-1234567890abcdef');
        sawHeader = true;
        return http.Response('{"grades":[]}', 200);
      }));
      await s.fetchLeaderboard(courseName: 'X (CODE1)');
      expect(sawHeader, isTrue);
      s.dispose();
    });

    test('fetchCourses keeps unique names in first-seen order', () async {
      final s = svc(MockClient((_) async => http.Response(
            '[{"courseName":"Data Structures (CP233)"},'
            '{"courseName":"OOP (CP223)"},'
            '{"courseName":"Data Structures (CP233)"}]',
            200,
          )));
      final courses = await s.fetchCourses();
      expect(courses, ['Data Structures (CP233)', 'OOP (CP223)']);
      s.dispose();
    });

    test('fetchCourses scopes to my classes and skips Room: rows',
        () async {
      final s = svc(MockClient((_) async => http.Response(
            '[{"courseName":"Data Structures (CP233)","studentID":"L1F25BSCS0577"},'
            '{"courseName":"Room: A-102 (Makeup Class (Lecture))","studentID":"L1F25BSCS0577"},'
            '{"courseName":"OOP (CP223)","studentID":"L1F25BSCS0577"},'
            '{"courseName":"OOP (CP223)","studentID":"L1F25BSCS0577"},'
            '{"courseName":"Other Course (XX1)","studentID":"L1F99"}]',
            200,
          )));
      // Scoped: only my rows, Room: dropped, duplicates collapsed.
      expect(await s.fetchCourses(studentId: 'L1F25BSCS0577'),
          ['Data Structures (CP233)', 'OOP (CP223)']);
      // No id or unknown id: whole catalogue (minus Room: rows).
      expect((await s.fetchCourses()).length, 3);
      s.dispose();
    });

    test('leaderboard maps ranks, credits and me-flag', () async {
      final s = svc(MockClient((req) async {
        expect(req.url.queryParameters['courseName'], 'OOP (CP223)');
        expect(req.url.queryParameters['studentId'], 'L1F25BSCS0577');
        return http.Response(
          '{"grades":['
          '{"studentName":"Ali","studentId":"L1F24BSSE0001","overallPercentage":92.5,"grade":"A"},'
          '{"studentName":"Anonymous","studentId":"hidden","overallPercentage":88,"grade":"A-"},'
          '{"studentName":"Saad","studentId":"L1F25BSCS0577","overallPercentage":84.0,"grade":"B+"}'
          '],"remainingCredits":49}',
          200,
        );
      }));
      final res = await s.fetchLeaderboard(
        courseName: 'OOP (CP223)',
        studentId: 'L1F25BSCS0577',
      );
      expect(res.remainingCredits, 49);
      expect(res.entries.length, 3);
      expect(res.entries[0].rank, 1); // server order = rank formula
      expect(res.entries[0].percentage, 92.5);
      expect(res.entries[1].isAnonymous, isTrue);
      expect(res.entries[2].isMe, isTrue);
      expect(res.entries[1].isMe, isFalse); // hidden ids never match
      s.dispose();
    });

    test('402 maps to NoCredits, server errors carry the message',
        () async {
      final s = svc(MockClient((req) async => http.Response(
            '{"error":"No credits remaining","code":"NO_CREDITS","credits":0}',
            402,
          )));
      await expectLater(
        s.fetchLeaderboard(courseName: 'x'),
        throwsA(isA<NoCredits>()),
      );
      final s2 = svc(MockClient((_) async => http.Response(
            '{"error":"Leaderboard is not deployed on this backend."}',
            404,
          )));
      await expectLater(
        s2.fetchLeaderboard(courseName: 'x'),
        throwsA(isA<LeaderboardException>()
            .having((e) => e.message, 'message', contains('not deployed'))),
      );
      s.dispose();
      s2.dispose();
    });
  });

  group('LiveLeaderboardScreen', () {
    testWidgets('podium, ranked list, me-row and course chips render',
        (tester) async {
      final svc = FakeLeaderboardService(
        credits: 48,
        rows: [
          {'studentName': 'Ali', 'studentId': 'L1', 'overallPercentage': 92.5, 'grade': 'A'},
          {'studentName': 'Sara', 'studentId': 'L2', 'overallPercentage': 90.0, 'grade': 'A'},
          {'studentName': 'Anonymous', 'studentId': 'hidden', 'overallPercentage': 88.0, 'grade': 'A-'},
          {'studentName': 'Saad', 'studentId': 'ME', 'overallPercentage': 84.0, 'grade': 'B+'},
          {'studentName': 'Omar', 'studentId': 'L5', 'overallPercentage': 80.0, 'grade': 'B'},
        ],
      );
      await tester.pumpWidget(_wrap(LiveLeaderboardScreen(
        service: svc,
        studentId: 'ME',
        initialCourse: 'Data Structures (CP233-R26-BS-SE-F24-SED1)',
        back: () {},
        fallback: const SizedBox(),
      )));
      await tester.pumpAndSettle();
      // Course preselected by initial match, board fetched with my id.
      expect(svc.boardCalls, 1);
      expect(find.text('Data Structures'), findsOneWidget); // short chip
      expect(find.text('Ali'), findsWidgets); // podium + (no list row)
      expect(find.text('You'), findsOneWidget); // me-row
      expect(find.text('Anonymous'), findsWidgets);
      expect(find.text('48 credits'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium), findsOneWidget);
      // Rank 4/5 rows below the podium.
      expect(find.text('#4'), findsNothing); // rank shown as square "4"
      expect(find.text('4'), findsWidgets);
      expect(find.text('80.0%'), findsOneWidget);
    });

    testWidgets('no-credits state explains the cost', (tester) async {
      final svc = FakeLeaderboardService()
        ..throwOnBoard = const NoCredits();
      await tester.pumpWidget(_wrap(LiveLeaderboardScreen(
        service: svc,
        studentId: 'x',
        back: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('out of credits'), findsOneWidget);
      expect(find.textContaining('costs 1 credit'), findsOneWidget);
    });

    testWidgets('null service renders the fallback board', (tester) async {
      await tester.pumpWidget(_wrap(LiveLeaderboardScreen(
        service: null,
        fallback: const Text('DEMO_BOARD'),
      )));
      await tester.pumpAndSettle();
      expect(find.text('DEMO_BOARD'), findsOneWidget);
    });

    testWidgets('empty ext courses fall back to the portal timetable',
        (tester) async {
      final svc = FakeLeaderboardService(courses: []);
      await tester.pumpWidget(_wrap(LiveLeaderboardScreen(
        service: svc,
        studentId: 'ME',
        initialCourse: 'Data Structures',
        fallbackCourses: const ['Data Structures', 'OOP'],
        back: () {},
      )));
      await tester.pumpAndSettle();
      // Picker populated from the portal fallback, tapped subject preselected.
      expect(find.text('Data Structures'), findsOneWidget);
      expect(find.text('OOP'), findsOneWidget);
      // Hint explains where the list came from.
      expect(find.textContaining('portal timetable'), findsOneWidget);
    });

    testWidgets('app publishes its timetable and shows roster verification',
        (tester) async {
      final svc = FakeLeaderboardService(
        courses: ['Data Structures (CP233)'],
        roster: const LeaderboardRoster(
          rosterSize: 12,
          classmates: 11,
          youAreIn: true,
          sections: ['cp233'],
        ),
      );
      await tester.pumpWidget(_wrap(LiveLeaderboardScreen(
        service: svc,
        studentId: 'L1TEST',
        studentName: 'Test Student',
        timetableRows: const [
          {
            'day': 'Monday',
            'time': '08:00 - 08:55',
            'courseName': 'Data Structures (CP233)',
            'teacher': 'Prof X',
            'room': 'A-101',
          },
        ],
        back: () {},
      )));
      await tester.pumpAndSettle();
      // Timetable published to the server (app-only users join the roster).
      expect(svc.timetableSyncs, 1);
      expect(svc.lastTimetableRows!.first['courseName'],
          'Data Structures (CP233)');
      // Roster verification line: you + N classmates in this section.
      expect(find.textContaining('11 classmates'), findsOneWidget);
      expect(find.textContaining('cp233'), findsOneWidget);
    });

    testWidgets('own grades are published before the board loads',
        (tester) async {
      final svc = FakeLeaderboardService(
        courses: ['Data Structures (CP233)'],
      );
      final ensured = <String>[];
      await tester.pumpWidget(_wrap(LiveLeaderboardScreen(
        service: svc,
        studentId: 'L1TEST',
        initialCourse: 'Data Structures',
        onEnsureGrades: (name) async => ensured.add(name),
        back: () {},
      )));
      await tester.pumpAndSettle();
      // The app publishes the portal gradebook for the opened subject so
      // the student's own row is on the board.
      expect(ensured, ['Data Structures (CP233)']);
      expect(svc.boardCalls, greaterThanOrEqualTo(1));
    });
  });

  group('CourseDetailScreen grades → leaderboard', () {
    testWidgets('grades tab offers the class leaderboard action',
        (tester) async {
      final opened = <String>[];
      const gradeHtml = '<table><thead><tr><th>Assessment Type</th>'
          '<th>Obtained Percentage</th></tr></thead><tbody><tr>'
          '<td>Quiz 15.0 %</td><td>80.00</td></tr></tbody></table>';
      await tester.pumpWidget(_wrap(CourseDetailScreen(
        portalCourse: _pc2,
        back: () {},
        initialTab: 'grades',
        debugHtml: const {'gradebook': gradeHtml},
        onOpenLeaderboard: (name) => opened.add(name),
      )));
      await tester.pumpAndSettle();
      expect(find.text('See class leaderboard'), findsOneWidget);
      await tester.tap(find.text('See class leaderboard'));
      await tester.pumpAndSettle();
      expect(opened, ['Object Oriented Programming']);
    });
  });
}
