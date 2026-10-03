import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucp/community/fake_community_service.dart';
import 'package:ucp/screens/community.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

import 'package:ucp/data/seed.dart';

Widget wrap(Widget child) {
  final colors = AppColors.of(AppPalette.skater, false);
  return AppScope(
    colors: colors,
    palette: AppPalette.skater,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('composer draft survives feed refresh and Post still works',
      (tester) async {
    final svc = FakeCommunityService();
    await tester.pumpWidget(wrap(
        CommunityScreen(service: svc, myEmail: 'tester@ucp.edu.pk')));
    await tester.pumpAndSettle();

    // Open composer via header Post button.
    await tester.tap(find.text(' Post'));
    await tester.pumpAndSettle();
    expect(find.text('Create post'), findsOneWidget);

    // Type title + body.
    await tester.enterText(
        find.byKey(const ValueKey('composer-title')), 'My test title');
    await tester.enterText(
        find.byKey(const ValueKey('composer-body')), 'hello body');
    await tester.pump();

    // Simulate a realtime feed refresh WHILE composing (vote fires
    // updates -> _reload -> parent setState). Before the fix this reset
    // the composer locals so Post did nothing.
    final posts = await svc.fetchPosts(myEmail: 'tester@ucp.edu.pk');
    await svc.setVote(
        postId: posts.first.id, myEmail: 'other@ucp.edu.pk', value: 1);
    await tester.pumpAndSettle();

    // Composer must still be open with draft intact.
    expect(find.text('Create post'), findsOneWidget);
    expect(find.text('My test title'), findsOneWidget);

    // Post must still work.
    await tester.tap(find.byKey(const ValueKey('composer-post-button')));
    await tester.pumpAndSettle();

    // Composer closes and new post is on top (sort switched to New).
    expect(find.text('Create post'), findsNothing);
    expect(find.text('My test title'), findsOneWidget);
    svc.dispose();
  });

  testWidgets('empty title shows validation instead of dead button',
      (tester) async {
    final svc = FakeCommunityService();
    await tester.pumpWidget(wrap(
        CommunityScreen(service: svc, myEmail: 'tester@ucp.edu.pk')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(' Post'));
    await tester.pumpAndSettle();

    final before = (await svc.fetchPosts(myEmail: 'tester@ucp.edu.pk')).length;
    await tester.tap(find.byKey(const ValueKey('composer-post-button')));
    await tester.pumpAndSettle();

    expect(find.text('Add a title before posting.'), findsOneWidget);
    final after = (await svc.fetchPosts(myEmail: 'tester@ucp.edu.pk')).length;
    expect(after, before);
    svc.dispose();
  });

  testWidgets('failed publish keeps draft and shows retry',
      (tester) async {
    final svc = _FailingCreateService();
    await tester.pumpWidget(wrap(
        CommunityScreen(service: svc, myEmail: 'tester@ucp.edu.pk')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(' Post'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('composer-title')), 'Keep me');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('composer-post-button')));
    await tester.pumpAndSettle();
    expect(find.text('Could not publish. Check connection and retry.'),
        findsOneWidget);
    // Draft preserved so user can retry.
    expect(find.text('Keep me'), findsOneWidget);
    expect(find.text('Create post'), findsOneWidget);
    svc.dispose();
  });
}

class _FailingCreateService extends FakeCommunityService {
  @override
  Future<Post> createPost(
      {required String myEmail,
      required String authorName,
      required String title,
      required String body,
      required String flair,
      String? imageUrl}) async {
    throw Exception('network down');
  }
}
