import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucp/community/community_service.dart';
import 'package:ucp/community/fake_community_service.dart';
import 'package:ucp/data/seed.dart';
import 'package:ucp/screens/community.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

Widget wrap(Widget child) {
  final colors = AppColors.of(AppPalette.skater, false);
  return AppScope(
    colors: colors,
    palette: AppPalette.skater,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

/// Old backend without GET /api/stats: fetchStats always 404s.
class _NoStatsService extends FakeCommunityService {
  @override
  Future<CommunityStats> fetchStats() async {
    throw CommunityExceptionForTest();
  }
}

class CommunityExceptionForTest implements Exception {}

/// Slow backend to prove optimistic UI (2s like delay).
class _SlowLikeService extends FakeCommunityService {
  @override
  Future<void> setVote(
      {required String postId,
      required String myEmail,
      required int? value}) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    return super.setVote(postId: postId, myEmail: myEmail, value: value);
  }

  @override
  Future<void> setCommentVote(
      {required String commentId,
      required String myEmail,
      required int? value}) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    return super
        .setCommentVote(commentId: commentId, myEmail: myEmail, value: value);
  }
}

Future<void> openThread(WidgetTester tester) async {
  final title = find.text('Study group for the Data Structures midterm?');
  await tester.ensureVisible(title);
  await tester.pumpAndSettle();
  await tester.tap(title);
  await tester.pumpAndSettle();
}

void main() {
  test('localStatsFromPosts derives real members from feed', () {
    final posts = seedPosts();
    final stats = localStatsFromPosts(posts);
    expect(stats.members, greaterThanOrEqualTo(4));
    expect(formatCommunityStats(stats), contains('students'));
  });

  testWidgets('header never sticks on Connecting when stats endpoint missing',
      (tester) async {
    final svc = _NoStatsService();
    await tester.pumpWidget(
        wrap(CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk')));
    await tester.pumpAndSettle();
    final text = tester
        .widget<Text>(find.byKey(const ValueKey('community-stats')))
        .data!;
    expect(text, isNot(equals('Connecting…')));
    expect(text, contains('students'));
    expect(text, contains('online'));
    svc.dispose();
  });

  testWidgets('vote UI is like-only, no up/down arrows', (tester) async {
    final svc = FakeCommunityService();
    await tester.pumpWidget(
        wrap(CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_circle_up_outlined), findsNothing);
    expect(find.byIcon(Icons.arrow_circle_down_outlined), findsNothing);
    expect(find.byIcon(Icons.favorite_outline), findsWidgets);
    await openThread(tester);
    expect(find.byIcon(Icons.arrow_circle_up_outlined), findsNothing);
    expect(find.byIcon(Icons.arrow_circle_down_outlined), findsNothing);
    svc.dispose();
  });

  testWidgets('post like fills instantly even on slow network',
      (tester) async {
    final svc = _SlowLikeService();
    await tester.pumpWidget(
        wrap(CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsNothing);
    await tester.ensureVisible(find.byIcon(Icons.favorite_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.favorite_outline).first);
    // One frame: optimistic fill, WITHOUT waiting 2s backend.
    await tester.pump();
    expect(find.byIcon(Icons.favorite), findsWidgets);
    // Advance past the slow network delay, then settle the reconcile.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    svc.dispose();
  });

  testWidgets('comment send clears box and confirms sent', (tester) async {
    final svc = FakeCommunityService();
    await tester.pumpWidget(
        wrap(CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk')));
    await tester.pumpAndSettle();
    await openThread(tester);
    await tester.enterText(
        find.byKey(const ValueKey('comment-field')), 'Hello campus');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('comment-send')));
    await tester.pump();
    // Box cleared immediately.
    expect(
        tester.widget<TextField>(find.byKey(const ValueKey('comment-field')))
            .controller!
            .text,
        isEmpty);
    await tester.pumpAndSettle();
    expect(find.text('Comment posted'), findsOneWidget);
    expect(find.text('Hello campus'), findsWidgets);
    svc.dispose();
  });
}
