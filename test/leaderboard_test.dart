import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ucp/auth/student_portal.dart' show PortalCourse;
import 'package:ucp/leaderboard/leaderboard_service.dart';
import 'package:ucp/leaderboard/sync.dart';
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
  String lastStudentImage = '';
  List<Map<String, String>>? lastTimetableRows;
  String? lastGrade;
  /// Course code sent with the last board/roster request.
  String? lastCourseCode;
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
    String? courseCode,
  }) async {
    lastCourseCode = courseCode;
    return roster;
  }

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
    String studentImage = '',
  }) async {
    lastStudentImage = studentImage;
    gradeSyncs++;
    lastGrade = grade;
    lastOverall = overallPercentage;
  }

  @override
  Future<LeaderboardResult> fetchLeaderboard(
      {required String courseName,
      String? studentId,
      String? courseCode}) async {
    boardCalls++;
    lastCourseCode = courseCode;
    if (throwOnBoard != null) {
      throw throwOnBoard!; // ignore: avoid_catching_errors
    }
    final entries = <LeaderboardEntry>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final id = '${r['studentId'] ?? ''}';
      final marks = <LeaderboardAssessment>[];
      for (final a in (r['assessments'] as List? ?? const [])) {
        if (a is! Map) continue;
        marks.add(LeaderboardAssessment(
          name: '${a['name'] ?? 'Assessment'}',
          totalMarks: (a['totalMarks'] as num?)?.toDouble() ?? 0,
          obtainedMarks: (a['obtainedMarks'] as num?)?.toDouble() ?? 0,
          percentage: (a['percentage'] as num?)?.toDouble() ?? 0,
          weightage: (a['weightage'] as num?)?.toDouble() ?? 0,
          classAverage: (a['classAverage'] as num?)?.toDouble() ?? 0,
        ));
      }
      entries.add(LeaderboardEntry(
        rank: i + 1,
        studentName: '${r['studentName'] ?? ''}',
        studentId: id,
        imageUrl: '${r['studentImage'] ?? ''}',
        percentage: (r['overallPercentage'] as num?)?.toDouble() ?? 0,
        grade: '${r['grade'] ?? ''}',
        // A privacy-masked row can carry studentId 'hidden' while the
        // server still flags it as the viewer's own row.
        isMe: r['isMe'] == true ||
            ((studentId ?? '').isNotEmpty && id == studentId),
        assessments: marks,
        classAverage: (r['classAverage'] as num?)?.toDouble() ?? 0,
      ));
    }
    return LeaderboardResult(entries: entries, remainingCredits: credits);
  }

  bool savedHideName = false;
  bool savedHidePhoto = false;
  int privacySaves = 0;

  @override
  Future<LeaderboardPrivacy> fetchPrivacy(String studentId) async =>
      LeaderboardPrivacy(hideName: savedHideName, hidePhoto: savedHidePhoto);

  @override
  Future<LeaderboardPrivacy> savePrivacy(
    String studentId, {
    required bool hideName,
    required bool hidePhoto,
  }) async {
    privacySaves++;
    savedHideName = hideName;
    savedHidePhoto = hidePhoto;
    return LeaderboardPrivacy(hideName: hideName, hidePhoto: hidePhoto);
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
    test('syncGrades publishes the avatar when one is available',
        () async {
      Map<String, dynamic>? body;
      final s = svc(MockClient((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('{"ok":true}', 201);
      }));
      await s.syncGrades(
        studentId: 'L1F25BSCS0577',
        studentName: 'Saad',
        studentImage: 'data:image/jpeg;base64,/9j/4AAQSkZJRg==',
        courseName: 'OOP (CP223)',
        courseCode: 'CP223-R26-BS-SE-F24-SED1',
        overallPercentage: 84,
        grade: 'B+',
        assessments: const [],
      );
      expect(body, isNotNull);
      expect(body!['studentImage'],
          'data:image/jpeg;base64,/9j/4AAQSkZJRg==');
      s.dispose();
    });

    test('syncGrades omits the avatar key entirely when empty', () async {
      Map<String, dynamic>? body;
      final s = svc(MockClient((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('{"ok":true}', 201);
      }));
      await s.syncGrades(
        studentId: 'L1F25BSCS0577',
        studentName: 'Saad',
        courseName: 'OOP (CP223)',
        courseCode: 'CP223',
        overallPercentage: 84,
        grade: 'B+',
        assessments: const [],
      );
      expect(body, isNotNull);
      expect(body!.containsKey('studentImage'), isFalse);
      s.dispose();
    });
  });

  group('LiveLeaderboardScreen', () {
    testWidgets('rows, me-row, stats and course chips render', (tester) async {
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
      expect(find.text('Ali'), findsOneWidget); // a row
      expect(find.text('You'), findsOneWidget); // me-row
      expect(find.text('Anonymous'), findsOneWidget);
      expect(find.text('48 credits'), findsOneWidget);
      // Production default is the row-wise list; the podium is one tap
      // away and not mounted yet.
      expect(find.text('Rows'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium), findsNothing);
      // The stats strip shows MY rank, and every row carries its rank.
      expect(find.text('#4'), findsOneWidget);
      expect(find.text('4'), findsWidgets);
      expect(find.text('80.0%'), findsOneWidget);
    });

    testWidgets('a privacy-masked row still shows your row as You',
        (tester) async {
      // The server flags the viewing student's own row as isMe (the
      // studentId is masked to 'hidden' on the wire). The rank chip and
      // the stats strip must put you on top.
      final svc = FakeLeaderboardService(
        rows: const [
          {
            'studentId': 'hidden',
            'studentName': 'Anonymous',
            'overallPercentage': 92.5,
            'grade': 'A',
            'isMe': true,
          },
          {
            'studentId': 'L2',
            'studentName': 'Someone Else',
            'overallPercentage': 80.0,
            'grade': 'B+',
          },
        ],
      );
      await tester.pumpWidget(_wrap(LiveLeaderboardScreen(
        service: svc,
        studentId: 'L1TEST',
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
      )));
      await tester.pumpAndSettle();
      expect(find.text('You'), findsOneWidget);
      // The masked row never shows someone else's name; it shows "You".
      expect(find.text('Anonymous'), findsNothing);
      expect(find.text('Someone Else'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
    });

    testWidgets('privacy sheet flips name and photo on the board',
        (tester) async {
      final svc = FakeLeaderboardService(
        rows: const [
          {
            'studentId': 'ME',
            'studentName': 'Saad',
            'overallPercentage': 92.0,
            'grade': 'A',
          },
        ],
      );
      await tester.pumpWidget(_wrap(LiveLeaderboardScreen(
        service: svc,
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
      )));
      await tester.pumpAndSettle();
      // Header shield is the entry point.
      final privacy = find.byIcon(Icons.privacy_tip_outlined);
      expect(privacy, findsOneWidget);
      await tester.tap(privacy);
      await tester.pumpAndSettle();
      expect(find.text('Your privacy'), findsOneWidget);
      expect(find.text('Hide my name on leaderboards'), findsOneWidget);
      expect(find.text('Hide my photo on leaderboards'), findsOneWidget);
      final initialBoardCalls = svc.boardCalls;

      // Flip the name toggle.
      final nameRow = find.ancestor(
        of: find.text('Hide my name on leaderboards'),
        matching: find.byType(SettingRow),
      );
      final nameToggle =
          find.descendant(of: nameRow, matching: find.byType(AppToggle));
      await tester.ensureVisible(nameToggle);
      await tester.pumpAndSettle();
      await tester.tap(nameToggle, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(svc.privacySaves, 1);
      expect(svc.savedHideName, isTrue);
      expect(svc.savedHidePhoto, isFalse);
      // The board re-read the roster after the change.
      expect(svc.boardCalls, greaterThan(initialBoardCalls));

      // Flip the photo toggle: the name is left untouched.
      final photoRow = find.ancestor(
        of: find.text('Hide my photo on leaderboards'),
        matching: find.byType(SettingRow),
      );
      final photoToggle =
          find.descendant(of: photoRow, matching: find.byType(AppToggle));
      await tester.ensureVisible(photoToggle);
      await tester.pumpAndSettle();
      await tester.tap(photoToggle, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(svc.privacySaves, 2);
      expect(svc.savedHideName, isTrue);
      expect(svc.savedHidePhoto, isTrue);
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

    testWidgets('the board requires the portal sign-in before syncing', (
        tester) async {
      var sessionChecks = 0;
      var syncs = 0;
      final svc = FakeLeaderboardService();
      await tester.pumpWidget(_wrap(LiveLeaderboardScreen(
        service: svc,
        studentId: 'L1TEST',
        // The student is not signed in to the portal.
        onEnsureSession: () async {
          sessionChecks++;
          return false;
        },
        onSyncClass: ({onProgress, target}) async {
          syncs++;
          return const LeaderboardSyncReport(
            timetableRows: 22,
            subjectsSynced: 8,
          );
        },
        back: () {},
      )));
      await tester.pumpAndSettle();
      // The sign-in gate is shown and NOTHING was published yet.
      expect(find.text('Sign in to sync your class'), findsOneWidget);
      expect(sessionChecks, greaterThanOrEqualTo(1));
      expect(syncs, 0);
      expect(svc.timetableSyncs, 0);
      expect(svc.gradeSyncs, 0);
    });

    testWidgets('a signed-in student syncs the class, then sees the board', (
        tester) async {
      final stages = <SyncStepKind>[];
      var syncs = 0;
      final svc = FakeLeaderboardService(
        rows: const [
          {'studentId': 'L1TEST', 'studentName': 'Me', 'overallPercentage': 88.0},
          {'studentId': 'L1OTHER', 'studentName': 'Other', 'overallPercentage': 70.0},
        ],
      );
      await tester.pumpWidget(_wrap(LiveLeaderboardScreen(
        service: svc,
        studentId: 'L1TEST',
        onEnsureSession: () async => true,
        onSyncClass: ({onProgress, target}) async {
          syncs++;
          onProgress?.call(const SyncStepUpdate(
            key: 'session',
            kind: SyncStepKind.session,
            label: 'Checking your portal sign-in',
            detail: 'Signed in',
            state: SyncStepState.done,
          ));
          onProgress?.call(const SyncStepUpdate(
            key: 'timetable',
            kind: SyncStepKind.timetable,
            label: 'Getting your timetable',
            detail: '22 slots sent to the server',
            state: SyncStepState.done,
          ));
          onProgress?.call(const SyncStepUpdate(
            key: 'grade:CP233',
            kind: SyncStepKind.grade,
            label: 'Getting the grade page',
            detail: 'Data Structures \u00b7 parsed and sent to the server',
            state: SyncStepState.done,
          ));
          stages.addAll(const [
            SyncStepKind.session,
            SyncStepKind.timetable,
            SyncStepKind.grade,
          ]);
          return const LeaderboardSyncReport(
            timetableRows: 22,
            subjectsSynced: 8,
          );
        },
        back: () {},
      )));
      await tester.pumpAndSettle();
      // The pipeline ran in the right order...
      expect(syncs, 1);
      expect(stages, [
        SyncStepKind.session,
        SyncStepKind.timetable,
        SyncStepKind.grade,
      ]);
      // ...the finished pipeline collapses to one summary line...
      expect(find.textContaining('Synced: 22 slots'), findsOneWidget);
      // ...expand it and every step is visible to the student...
      await tester.tap(find.textContaining('Synced: 22 slots'));
      await tester.pumpAndSettle();
      expect(find.text('Checking your portal sign-in'), findsOneWidget);
      expect(find.text('Getting your timetable'), findsOneWidget);
      expect(find.text('Getting the grade page'), findsOneWidget);
      // ...the board request is a step as well...
      expect(find.text('Loading the leaderboard'), findsOneWidget);
      // ...and the board itself is loaded.
      expect(svc.boardCalls, greaterThanOrEqualTo(1));
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('the board appears while the class sync is still running', (
        tester) async {
      final svc = FakeLeaderboardService(
        rows: const [
          {'studentId': 'L1OTHER', 'studentName': 'Other', 'overallPercentage': 70.0},
        ],
      );
      final gate = Completer<LeaderboardSyncReport>();
      await tester.pumpWidget(_wrap(LiveLeaderboardScreen(
        service: svc,
        studentId: 'L1TEST',
        onEnsureSession: () async => true,
        // The sync never finishes during the test.
        onSyncClass: ({onProgress, target}) => gate.future,
        back: () {},
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // The board was fetched even though the sync is still pending.
      expect(svc.boardCalls, greaterThanOrEqualTo(1));
      expect(find.text('Other'), findsOneWidget);
      // The sync is visible while it runs.
      expect(find.text('Syncing your class'), findsOneWidget);
      gate.complete(const LeaderboardSyncReport());
    });

    testWidgets('an unreachable portal is a network problem, not a sign-in', (
        tester) async {
      final svc = FakeLeaderboardService(
        rows: const [
          {'studentId': 'L1OTHER', 'studentName': 'Other', 'overallPercentage': 70.0},
        ],
      );
      await tester.pumpWidget(_wrap(LiveLeaderboardScreen(
        service: svc,
        studentId: 'L1TEST',
        onEnsureSession: () async => true,
        onSyncClass: ({onProgress, target}) async {
          // The portal could not be reached.
          return const LeaderboardSyncReport(
            sessionState: PortalSessionState.unreachable,
          );
        },
        back: () {},
      )));
      await tester.pumpAndSettle();
      // No sign-in demand — the student is told to check the connection.
      expect(find.text('Sign in to sync your class'), findsNothing);
      expect(find.textContaining('Could not reach the UCP portal'),
          findsOneWidget);
      // The board still loads (it comes from the server).
      expect(svc.boardCalls, greaterThanOrEqualTo(1));
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('the board queries the exact section, not just the code', (
        tester) async {
      final svc = FakeLeaderboardService();
      await tester.pumpWidget(_wrap(LiveLeaderboardScreen(
        service: svc,
        studentId: 'L1TEST',
        initialCourse: 'Computer Organization and Assembly Language - Lab',
        initialCourseCode: 'AR221',
        portalCourses: const [
          PortalCourse(
            name: 'Computer Organization and Assembly Language - Lab',
            teacher: 'T',
            code: 'AR221',
            credits: 1,
            attendance: 0,
            infoUrl: '/student/course/info/BBB222',
          ),
        ],
        // The course card shows "AR221"; the timetable carries the full
        // section. The full code is what scopes the board.
        sectionCodes: const {
          'AR221': 'AR221-F26-BS-CS-F25-C1',
        },
        back: () {},
      )));
      await tester.pumpAndSettle();
      expect(svc.lastCourseCode, 'AR221-F26-BS-CS-F25-C1');
    });

    testWidgets('rows are the default view and podium keeps every student', (
        tester) async {
      final svc = FakeLeaderboardService(
        rows: const [
          {'studentId': 'TOP', 'studentName': 'Top Student',
            'overallPercentage': 96.0, 'grade': 'A'},
          {'studentId': 'MID', 'studentName': 'Mid Student',
            'overallPercentage': 88.0, 'grade': 'A-'},
          {'studentId': 'LOW', 'studentName': 'Low Student',
            'overallPercentage': 70.0, 'grade': 'B'},
          {'studentId': 'ME', 'studentName': 'Me',
            'overallPercentage': 60.0, 'grade': 'C'},
        ],
      );
      await tester.pumpWidget(_wrap(LiveLeaderboardScreen(
        service: svc,
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
      )));
      await tester.pumpAndSettle();
      // Production default: every student is a ROW (your own reads "You").
      expect(find.text('Rows'), findsOneWidget);
      expect(find.text('Podium'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Top Student'), findsOneWidget);
      expect(find.text('Mid Student'), findsOneWidget);
      expect(find.text('Low Student'), findsOneWidget);
      expect(find.text('4 students ranked in this section'), findsOneWidget);
      // The toggle reports the count in both modes.
      expect(find.text('4 ranked'), findsOneWidget);
      // Switch to the podium: the top three become cards, the fourth is
      // still a row.
      await tester.tap(find.text('Podium'));
      await tester.pumpAndSettle();
      expect(find.text('Top Student'), findsOneWidget);
      expect(find.text('4 students ranked in this section'), findsNothing);
      expect(find.byIcon(Icons.workspace_premium), findsOneWidget);
      // Back to rows: all four are rows again.
      await tester.tap(find.text('Rows'));
      await tester.pumpAndSettle();
      expect(find.text('4 students ranked in this section'), findsOneWidget);
      expect(find.text('Top Student'), findsOneWidget);
    });

    testWidgets('phone width: rows fit and tapping one expands the marks',
        (tester) async {
      // A 340 dp surface is narrower than most Androids in the wild. The
      // row layout (rank + avatar + name + grade + score + percentage)
      // must fit without overflowing, and the inline marks table must
      // stay readable when expanded.
      await tester.binding.setSurfaceSize(const Size(340, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final svc = FakeLeaderboardService(
        credits: 12,
        rows: const [
          {
            'studentId': 'TOP',
            'studentName': 'Ayesha Khan',
            'overallPercentage': 94.5,
            'grade': 'A',
          },
          {
            'studentId': 'ME',
            'studentName': 'Saad Akram',
            'overallPercentage': 81.0,
            'grade': 'B+',
            'classAverage': 76.5,
            'assessments': [
              {
                'name': 'Quiz 1',
                'totalMarks': 20,
                'obtainedMarks': 18,
                'percentage': 90,
                'weightage': 10,
              },
              {
                'name': 'Class Activity',
                'totalMarks': 100,
                'obtainedMarks': 72,
                'percentage': 72,
                'weightage': 5,
              },
            ],
          },
        ],
      );
      await tester.pumpWidget(_wrap(LiveLeaderboardScreen(
        service: svc,
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
      )));
      await tester.pumpAndSettle();
      // Nothing overflowed at phone width.
      expect(tester.takeException(), isNull);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Ayesha Khan'), findsOneWidget);

      // Tap the row: the marks table expands inline.
      await tester.ensureVisible(find.text('You'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('You'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('ASSESSMENT'), findsOneWidget);
      expect(find.text('Quiz 1'), findsOneWidget);
      expect(find.text('18/20'), findsOneWidget);
      expect(find.text('90%'), findsOneWidget);
      expect(find.text('10% weight'), findsOneWidget);
      expect(find.text('Class Activity'), findsOneWidget);
      expect(find.text('72/100'), findsOneWidget);
      expect(find.text('Class average 76.5%'), findsOneWidget);
    });

    testWidgets('theory and lab are separate subjects in the picker', (
        tester) async {
      final svc = FakeLeaderboardService(
        courses: const [
          'Computer Organization and Assembly Language (AR221-F26-BS-CS-F25-C1)',
          'Computer Organization and Assembly Language (AR223-F26-BS-CS-F25-C1)',
        ],
      );
      await tester.pumpWidget(_wrap(LiveLeaderboardScreen(
        service: svc,
        studentId: 'L1TEST',
        initialCourse: 'Computer Organization and Assembly Language',
        initialCourseCode: 'AR223',
        portalCourses: const [
          PortalCourse(
            name: 'Computer Organization and Assembly Language',
            teacher: 'T',
            code: 'AR223',
            credits: 3,
            attendance: 0,
            infoUrl: '/student/course/info/AAA111',
          ),
          PortalCourse(
            name: 'Computer Organization and Assembly Language - Lab',
            teacher: 'T',
            code: 'AR221',
            credits: 1,
            attendance: 0,
            infoUrl: '/student/course/info/BBB222',
          ),
        ],
        back: () {},
      )));
      await tester.pumpAndSettle();
      // Both subjects are offered — theory and lab are NOT merged.
      expect(
        find.text('Computer Organization and Assembly Language'),
        findsOneWidget,
      );
      expect(
        find.text('Computer Organization and Assembly Language - Lab'),
        findsOneWidget,
      );
      // The tapped theory course is selected and its code is sent, so the
      // server can keep the lab section on its own roster.
      expect(svc.lastCourseCode, 'AR223');
    });

    testWidgets('picker keeps portal course names and matches by code',
        (tester) async {
      final svc = FakeLeaderboardService(
        courses: ['Computer Organization and Assembly Language (AR221-F26-BS-CS-F25-C1)'],
      );
      await tester.pumpWidget(_wrap(LiveLeaderboardScreen(
        service: svc,
        studentId: 'L1TEST',
        // The portal title carries "- Lab"; the ext label does not — the
        // course CODE is what disambiguates them.
        initialCourse: 'Computer Organization and Assembly Language - Lab',
        initialCourseCode: 'AR221',
        portalCourses: const [
          PortalCourse(
            name: 'Computer Organization and Assembly Language - Lab',
            teacher: 'T',
            code: 'AR221',
            credits: 1,
            attendance: 0,
            infoUrl: '/student/course/info/ABC123',
          ),
        ],
        back: () {},
      )));
      await tester.pumpAndSettle();
      // The board is opened on the LAB course (portal name preserved).
      expect(svc.boardCalls, greaterThanOrEqualTo(1));
      expect(
        find.text('Computer Organization and Assembly Language - Lab'),
        findsOneWidget,
      );
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
