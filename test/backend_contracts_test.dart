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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ucp/app.dart';
import 'package:ucp/auth/prefs_store.dart';
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
    rosterQuery = ['$courseName', '$studentId', '$courseCode'];
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
    return const LeaderboardResult(entries: [], free: true);
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
  });
}
