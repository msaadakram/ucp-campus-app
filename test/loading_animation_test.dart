import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucp/community/community_service.dart';
import 'package:ucp/community/fake_community_service.dart';
import 'package:ucp/data/seed.dart';
import 'package:ucp/screens/community.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';
import 'package:ucp/widgets/loading.dart';
import 'package:ucp/widgets/portal_state.dart';
import 'dart:typed_data';

class _HangingService extends CommunityService {
  @override
  Future<List<Post>> fetchPosts({required String myEmail}) =>
      Completer<List<Post>>().future;
  @override
  Future<void> setVote(
          {required String postId,
          required String myEmail,
          required int? value}) async {}
  @override
  Future<void> setCommentVote(
          {required String commentId,
          required String myEmail,
          required int? value}) async {}
  @override
  Future<CComment> addComment(
          {required String postId,
          required String? parentId,
          required String myEmail,
          required String authorName,
          required String text}) async =>
      throw UnimplementedError();
  @override
  Future<Post> createPost(
          {required String myEmail,
          required String authorName,
          required String title,
          required String body,
          required String flair,
          String? imageUrl}) async =>
      throw UnimplementedError();
  @override
  Future<String> uploadImage(
          {required Uint8List bytes,
          required String contentType,
          required String extension}) async =>
      throw UnimplementedError();
  @override
  Stream<void> get updates => Stream<void>.empty();
  @override
  bool get supportsRealtime => false;
  @override
  Future<void> ensureRealtime(Future<void> Function() onEvent) async {}
  @override
  void dispose() {}
}

Widget wrap(Widget child) {
  final colors = AppColors.of(AppPalette.skater, false);
  return AppScope(
    colors: colors,
    palette: AppPalette.skater,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('ModernLoader renders bouncing dots + message',
      (tester) async {
    await tester.pumpWidget(wrap(const ModernLoader(message: 'Wait…')));
    expect(find.text('Wait…'), findsOneWidget);
    expect(find.byType(ModernLoader), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('PortalLoading shows skeleton, not bare spinner',
      (tester) async {
    await tester.pumpWidget(wrap(
        const PortalLoading(title: 'Timetable', subtitle: 'Loading…')));
    expect(find.text('Timetable'), findsOneWidget);
    expect(find.byType(ModernLoader), findsOneWidget);
    expect(find.byType(ShimmerBlock), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('Community loading keeps Post buttons + shows skeleton',
      (tester) async {
    await tester.pumpWidget(
        wrap(CommunityScreen(service: _HangingService())));
    await tester.pump(const Duration(milliseconds: 100));
    // Post entry points never disappear, even while hanging.
    expect(find.text(' Post'), findsOneWidget);
    expect(find.text('Share something with campus…'), findsOneWidget);
    // Modern skeleton instead of bare CircularProgressIndicator.
    expect(find.byType(CommunityFeedSkeleton), findsOneWidget);
    expect(find.byType(ModernLoader), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Community feed resolves skeleton -> real posts',
      (tester) async {
    final svc = FakeCommunityService();
    await tester.pumpWidget(wrap(
        CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityFeedSkeleton), findsNothing);
    expect(
        find.text('Study group for the Data Structures midterm?'),
        findsOneWidget);
    svc.dispose();
  });
}
