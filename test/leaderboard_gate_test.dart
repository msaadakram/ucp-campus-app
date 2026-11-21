import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucp/ads/ad_widgets.dart';
import 'package:ucp/leaderboard/leaderboard_service.dart';
import 'package:ucp/screens/leaderboard.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

/// Minimal service so the board pipeline completes instantly in tests.
class _GateFakeService extends LeaderboardService {
  @override
  Future<List<String>> fetchCourses({String? studentId}) async => ['OOP (CP223)'];

  @override
  Future<LeaderboardRoster> fetchRoster({
    required String courseName,
    String? studentId,
    String? courseCode,
  }) async =>
      const LeaderboardRoster(rosterSize: 12, classmates: 11, youAreIn: true);

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
      const LeaderboardResult(entries: [], free: true);

  @override
  Future<LeaderboardPrivacy> fetchPrivacy(String studentId) async =>
      const LeaderboardPrivacy();

  @override
  Future<LeaderboardPrivacy> savePrivacy(
    String studentId, {
    required bool hideName,
    required bool hidePhoto,
  }) async =>
      const LeaderboardPrivacy();

  @override
  void dispose() {}
}

Widget _wrap(Widget child) {
  final colors = AppColors.of(AppPalette.skater, false);
  return AppScope(
    colors: colors,
    palette: AppPalette.skater,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets(
    'leaderboard is blurred behind the reward gate until an ad is watched',
    (tester) async {
      AdMobService.instance.ready = true;
      addTearDown(() => AdMobService.instance.ready = false);

      await tester.pumpWidget(_wrap(LiveLeaderboardScreen(
        service: _GateFakeService(),
        studentId: 'ME',
        back: () {},
      )));
      await tester.pumpAndSettle();

      // Gate up: the unlock card + a live blurred backdrop under it.
      expect(find.text('Class unlock'), findsOneWidget);
      expect(find.text('Watch the ad'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);

      // Unlock (testing seam: ad watched) → gate disappears, board opens.
      final state = tester.state(find.byType(LiveLeaderboardScreen));
      (state as dynamic).markAdWatchedForTesting();
      await tester.pumpAndSettle();
      expect(find.text('Class unlock'), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
    },
  );
}
