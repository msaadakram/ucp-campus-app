/* Contract tests for the single-backend system.
 *
 * These lock in the fixes that keep the app, the extension and the one
 * Heroku deployment working as one system:
 *
 *   1. ONE backend client for the whole app (no socket-pool leak);
 *   2. the app asks the timetable endpoint for ITS OWN rows only;
 *   3. the app copes with a roster response that carries no class ids;
 *   4. the app's privacy toggle never re-reveals a hidden photo;
 *   5. the board paints while the class sync is still running.
 */


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ucp/app.dart';
import 'package:ucp/auth/portal_api.dart';
import 'package:ucp/auth/student_portal.dart' show PortalCourse;
import 'package:ucp/screens/leaderboard.dart';
import 'package:ucp/community/backend_config.dart';
import 'package:ucp/auth/session_manager.dart';
import 'package:ucp/leaderboard/leaderboard_service.dart';
import 'package:ucp/screens/profile.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

Widget _wrap(Widget child) {
  final colors = AppColors.of(AppPalette.skater, false);
  return AppScope(
    colors: colors,
    palette: AppPalette.skater,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

/// A fake service that records what the app asked for.
class RecordingService extends LeaderboardService {
  final List<String> calls = [];
  List<String> rosterQuery = [];
  bool hidePhotoOnDisk = true;
  String? savedHidePhoto;

  @override
  Future<List<String>> fetchCourses({String? studentId}) async {
    calls.add('fetchCourses:$studentId');
    return const ['Data Structures (CP233-R26-BS-SE-F24-SED1)'];
  }

  @override
  Future<LeaderboardRoster> fetchRoster({
    required String courseName,
    String? studentId,
    String? courseCode,
  }) async {
    rosterQuery = [courseName, '$studentId', '$courseCode'];
    return const LeaderboardRoster(
      rosterSize: 5,
      classmates: 4,
      youAreIn: true,
      sections: ['cp233-r26-bs-se-f24-sed1'],
    );
  }

  @override
  Future<void> syncTimetable({
    required String studentId,
    required List<Map<String, String>> rows,
  }) async =>
      calls.add('syncTimetable:$studentId');

  @override
  Future<void> syncGrades({
    required String studentId,
    required String studentName,
    required String courseName,
    required String courseCode,
    required double overallPercentage,
    required String grade,
    required List<Map<String, dynamic>> assessments,
  }) async =>
      calls.add('syncGrades:$studentId:$courseName');

  @override
  Future<LeaderboardResult> fetchLeaderboard({
    required String courseName,
    String? studentId,
    String? courseCode,
  }) async {
    calls.add('fetchLeaderboard:$courseName:$studentId:$courseCode');
    return const LeaderboardResult(
      entries: [
        LeaderboardEntry(
          rank: 1,
          studentName: 'Marks Holder',
          studentId: 'L1MARKS',
          imageUrl: '',
          percentage: 86.5,
          grade: 'A',
          isMe: true,
          assessments: [
            LeaderboardAssessment(
                name: 'Quiz 1', totalMarks: 20, obtainedMarks: 18,
                percentage: 90, weightage: 10),
            LeaderboardAssessment(
                name: 'Assignment 2', totalMarks: 10, obtainedMarks: 9.5,
                percentage: 95, weightage: 5),
          ],
          classAverage: 61.2,
        ),
      ],
      free: true,
    );
  }

  @override
  Future<LeaderboardPrivacy> fetchPrivacy(String studentId) async =>
      LeaderboardPrivacy(hideName: false, hidePhoto: hidePhotoOnDisk);

  @override
  Future<LeaderboardPrivacy> savePrivacy(
    String studentId, {
    required bool hideName,
    required bool hidePhoto,
  }) async {
    savedHidePhoto = '$hidePhoto';
    return LeaderboardPrivacy(hideName: hideName, hidePhoto: hidePhoto);
  }

  @override
  void dispose() {}
}

class FakeBackend extends SessionBackend {
  @override
  Future<void> save({required String sessionId, required String email}) async {}
  @override
  Future<({String sessionId, String email})?> load() async =>
      (sessionId: 'real-session-cookie', email: 'tester@ucp.edu.pk');
  @override
  Future<String?> readEmail() async => 'tester@ucp.edu.pk';
  @override
  Future<int?> savedAtMs() async => DateTime.now().millisecondsSinceEpoch;
  @override
  Future<void> clear() async {}
  @override
  Future<void> saveDashboard(String json) async {}
  @override
  Future<String?> loadDashboard() async => null;
}

/// Minimal portal dashboard HTML that parses into a student.
const _fakeDashboardHtml = '''
<html><body>
<h2 class="heading_b"><span class="sub-heading">L1F25BSCS0577</span>Saad Akram</h2>
<a href="/student/course/info/ABCD1234abcd"><div class="card">
  <div class="card-header"><span>Data Structures</span></div>
  <h6 class="card-title">Ali Haider</h6>
  <span class="sub-heading">CP233</span>
  <div class="card-body">Credits: 3 Attendance: 75%</div>
</div></a>
</body></html>
''';

/// Portal timetable HTML: one Monday slot that parses into a course.
const _fakeTimetableHtml = '''
<html><body>
<div class="cd-schedule__group">
  <div class="cd-schedule__top-info"><span>Monday</span></div>
  <ul>
    <li class="cd-schedule__event"><a data-start="08:00" data-end="08:55">
      <em class="cd-schedule__name">Ali Haider Arif</em>
      <span class="cd-schedule__name">Data Structures</span>
      <span class="cd-schedule__name">CP233-R26-BS-SE-F24-SED1</span>
      <span class="cd-schedule__name">A-101</span>
    </a></li>
  </ul>
</div>
</body></html>
''';

void main() {
  group('single backend contracts', () {
    testWidgets('the app keeps ONE backend client alive', (tester) async {
      final before = NodeLeaderboardService.instances;
      var built = 0;
      await tester.pumpWidget(_wrap(CampusApp(
        skipLogin: true,
        serviceFactory: () {
          built++;
          return RecordingService();
        },
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      // One service for the whole app — no socket pool per rebuild.
      expect(built, 1);
      expect(NodeLeaderboardService.instances, before);
    });

    test('the timetable request carries the student id', () async {
      Uri? seen;
      final svc = NodeLeaderboardService(
        client: MockClient((req) async {
          seen = req.url;
          return http.Response('[]', 200);
        }),
      );
      await svc.fetchCourses(studentId: 'L1F25BSCS0577');
      expect(seen!.queryParameters['studentId'], 'L1F25BSCS0577');
      svc.dispose();
    });

    test('a roster without class ids still gives the counts', () async {
      final svc = NodeLeaderboardService(
        client: MockClient((req) async {
          // The server no longer returns the class ids by default.
          return http.Response(
            '{"courseName":"X","sections":["s1"],"rosterSize":5,'
            '"classmates":4,"youAreIn":true}',
            200,
          );
        }),
      );
      final roster = await svc.fetchRoster(
        courseName: 'X',
        studentId: 'L1TEST',
      );
      expect(roster.rosterSize, 5);
      expect(roster.classmates, 4);
      expect(roster.youAreIn, isTrue);
      expect(roster.sections, ['s1']);
      svc.dispose();
    });

    testWidgets('the privacy toggle never re-reveals a hidden photo', (
        tester) async {
      final svc = RecordingService()..hidePhotoOnDisk = true;
      await tester.pumpWidget(_wrap(ProfileScreen(
        logout: () {},
        prefs: ProfilePrefs(),
        onPrefs: (_) {},
        studentId: 'L1F25BSCS0577',
        service: svc,
      )));
      await tester.pumpAndSettle();
      // The name toggle is on screen and the photo stays hidden.
      expect(find.text('Hide my name on leaderboards'), findsOneWidget);
      // Flip the privacy switch inside ITS row (the profile has many
      // toggles, so target the one next to the privacy label).
      final row = find.ancestor(
        of: find.text('Hide my name on leaderboards'),
        matching: find.byType(SettingRow),
      );
      final toggle = find.descendant(of: row, matching: find.byType(AppToggle));
      expect(toggle, findsOneWidget);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      // The write kept the photo hidden.
      expect(svc.savedHidePhoto, 'true');
    });

    testWidgets('the leaderboard shows the marks behind each score',
        (tester) async {
      final svc = RecordingService();
      await tester.pumpWidget(_wrap(LiveLeaderboardScreen(
        service: svc,
        studentId: 'L1MARKS',
        portalCourses: const [
          PortalCourse(
            name: 'Data Structures',
            teacher: 'Ali Haider',
            code: 'CP233',
            credits: 3,
            attendance: 80,
            infoUrl: '/student/course/info/TEST1234abcd',
          ),
        ],
        back: () {},
      )));
      await tester.pumpAndSettle();
      // The podium shows the grade AND the percentage together...
      expect(find.text('A · 86.5%'), findsOneWidget);
      // ...and tapping a podium card opens the marks sheet.
      await tester.tap(find.text('Marks Holder'));
      await tester.pumpAndSettle();
      expect(find.text('Quiz 1'), findsOneWidget);
      expect(find.text('18/20'), findsOneWidget);
      expect(find.textContaining('Class average'), findsOneWidget);
      expect(find.textContaining('86.5% overall'), findsOneWidget);
    });

    testWidgets('the photo privacy toggle writes the photo setting', (
        tester) async {
      final svc = RecordingService()..hidePhotoOnDisk = false;
      await tester.pumpWidget(_wrap(ProfileScreen(
        logout: () {},
        prefs: ProfilePrefs(),
        onPrefs: (_) {},
        studentId: 'L1F25BSCS0577',
        service: svc,
      )));
      await tester.pumpAndSettle();
      // Both switches are present.
      expect(find.text('Hide my name on leaderboards'), findsOneWidget);
      expect(find.text('Hide my photo on leaderboards'), findsOneWidget);
      // Flip the PHOTO switch (the second privacy row).
      final rows = find.ancestor(
        of: find.text('Hide my photo on leaderboards'),
        matching: find.byType(SettingRow),
      );
      final toggle = find.descendant(of: rows, matching: find.byType(AppToggle));
      expect(toggle, findsOneWidget);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(svc.savedHidePhoto, 'true');
    });

    testWidgets('the app shell builds exactly one backend service', (
        tester) async {
      var built = 0;
      await tester.pumpWidget(_wrap(CampusApp(
        skipLogin: true,
        serviceFactory: () {
          built++;
          return RecordingService();
        },
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Rebuilds must not build another service (socket-pool leak).
      expect(built, 1);
    });

    testWidgets('portal reads carry the SESSION cookie, not the student id', (
        tester) async {
      // The regression: the class-sync pipeline read the portal with the
      // student's REGISTRATION NUMBER instead of the Horizon session
      // cookie — the portal answered with its login page and the student
      // was told their session expired.
      final cookies = <String>[];
      final portal = PortalApi(MockClient((req) async {
        cookies.add(req.headers['cookie'] ?? '');
        final path = req.url.path;
        if (path.endsWith('/class/schedule')) {
          return http.Response(_fakeTimetableHtml, 200);
        }
        return http.Response(_fakeDashboardHtml, 200);
      }));
      // The class-sync pipeline only runs when the backend key is
      // configured (release builds ship it via --dart-define).
      if (extApiKey.length < 16) {
        // ignore: avoid_print
        print('SKIP: run with --dart-define=EXT_API_KEY=... to exercise '
            'the class-sync pipeline');
        return;
      }
      final svc = RecordingService();
      final app = CampusApp(
        authHooks: AuthTestHooks(
          backend: FakeBackend(),
          validate: (_) async => true,
        ),
        serviceFactory: () => svc,
        portalApiFactory: () => portal,
      );
      await tester.pumpWidget(_wrap(app));
      await tester.pump();
      // Let the restored session load the dashboard.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 600));
      // Run the class-sync pipeline directly (it is what the leaderboard
      // runs first).
      final dynamic state = tester.state(find.byType(CampusApp));
      await state.syncClassToServer();
      await tester.pump(const Duration(milliseconds: 300));
      // A session cookie was sent on every portal read...
      expect(cookies, isNotEmpty);
      for (final c in cookies) {
        expect(c.contains('session_id=real-session-cookie'), isTrue);
        // ...and it is NEVER the registration number.
        expect(c.contains('L1F25BSCS0577'), isFalse);
        expect(c.contains('tester@ucp.edu.pk'), isFalse);
      }
      // The publishes carry the STUDENT id.
      expect(svc.calls.any((c) => c.startsWith('syncTimetable:')), isTrue);
    });
  });
}
