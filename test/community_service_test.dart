import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/community/community_service.dart';
import 'package:ucp/community/fake_community_service.dart';
import 'package:ucp/community/supabase_service.dart';
import 'package:ucp/screens/community.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

void main() {
  group('helpers', () {
    test('timeAgo labels', () {
      final now = DateTime(2026, 10, 1, 12);
      expect(timeAgo(now, now).label, 'now');
      expect(
        timeAgo(now.subtract(const Duration(minutes: 12)), now).label,
        '12m',
      );
      expect(
        timeAgo(now.subtract(const Duration(hours: 3)), now).label,
        '3h',
      );
      expect(
        timeAgo(now.subtract(const Duration(days: 2)), now).label,
        '2d',
      );
    });

    test('handleForEmail', () {
      expect(handleForEmail('l1f25bscs0577@ucp.edu.pk'), 'l1f25bscs0577');
      expect(handleForEmail(''), 'student');
      expect(handleForEmail('a@b'), 'a');
    });
  });

  group('FakeCommunityService', () {
    test('seed content loads with zeroed personal votes', () async {
      final svc = FakeCommunityService();
      final posts = await svc.fetchPosts(myEmail: 'me@ucp.edu.pk');
      expect(posts.length, 4);
      expect(posts.first.title, contains('Data Structures'));
      expect(posts.every((p) => p.vote == 0), isTrue);
      svc.dispose();
    });

    test('vote toggle math mirrors UI score+vote', () async {
      final svc = FakeCommunityService();
      const me = 'me@ucp.edu.pk';
      var posts = await svc.fetchPosts(myEmail: me);
      final base = posts.first.score;
      await svc.setVote(postId: posts.first.id, myEmail: me, value: 1);
      posts = await svc.fetchPosts(myEmail: me);
      expect(posts.first.vote, 1);
      expect(posts.first.score + posts.first.vote, base + 1);
      // Toggle off.
      await svc.setVote(postId: posts.first.id, myEmail: me, value: 1);
      posts = await svc.fetchPosts(myEmail: me);
      expect(posts.first.vote, 0);
      expect(posts.first.score, base);
      svc.dispose();
    });

    test('nested replies attach to the right parent', () async {
      final svc = FakeCommunityService();
      const me = 'me@ucp.edu.pk';
      final posts = await svc.fetchPosts(myEmail: me);
      final post = posts.first;
      final before = post.comments.length;
      final parent = post.comments.first;
      final childCount = parent.replies.length;
      await svc.addComment(
        postId: post.id,
        parentId: parent.id,
        myEmail: me,
        authorName: 'me',
        text: 'nested hello',
      );
      final fresh = await svc.fetchPosts(myEmail: me);
      expect(fresh.first.comments.length, before);
      expect(fresh.first.comments.first.replies.length, childCount + 1);
      expect(fresh.first.comments.first.replies.last.text, 'nested hello');
      svc.dispose();
    });

    test('composer insert lands newest-first with image url', () async {
      final svc = FakeCommunityService();
      final url = await svc.uploadImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        contentType: 'image/jpeg',
        extension: 'jpg',
      );
      expect(url, startsWith('https://fake.cdn/'));
      final post = await svc.createPost(
        myEmail: 'me@ucp.edu.pk',
        authorName: 'me',
        title: 'Hello campus',
        body: 'first!',
        flair: 'Study',
        imageUrl: url,
      );
      expect(post.imageUrl, url);
      final posts = await svc.fetchPosts(myEmail: 'me@ucp.edu.pk');
      expect(posts.first.id, post.id);
      svc.dispose();
    });

    test('updates stream fires on mutation', () async {
      final svc = FakeCommunityService();
      var events = 0;
      final sub = svc.updates.listen((_) => events++);
      final posts = await svc.fetchPosts(myEmail: 'me@ucp.edu.pk');
      await svc.setVote(
          postId: posts.first.id, myEmail: 'me@ucp.edu.pk', value: 1);
      expect(events, 1);
      await sub.cancel();
      svc.dispose();
    });
  });

  group('SupabaseCommunityService mappers (no network)', () {
    final now = DateTime(2026, 10, 1, 12);

    test('mapPostList aggregates scores excluding my vote', () {
      final posts = SupabaseCommunityService.mapPostList(
        rows: [
          {
            'id': 'p1',
            'author_name': 'sara',
            'flair': 'Study',
            'title': 'T',
            'body': 'B',
            'image_url': 'https://cdn/x.jpg',
            'created_at': '2026-10-01T11:48:00',
          },
        ],
        votes: [
          {'post_id': 'p1', 'author_email': 'other@x', 'value': 1},
          {'post_id': 'p1', 'author_email': 'other@x', 'value': 1},
          {'post_id': 'p1', 'author_email': 'me@ucp.edu.pk', 'value': -1},
        ],
        comments: const [],
        commentVotes: const [],
        myEmail: 'me@ucp.edu.pk',
        now: now,
      );
      expect(posts.length, 1);
      expect(posts.first.score, 2); // 2 + (-1) total, minus my -1
      expect(posts.first.vote, -1);
      expect(posts.first.time, '12m');
      expect(posts.first.imageUrl, 'https://cdn/x.jpg');
    });

    test('buildCommentTree nests replies, orphans to roots', () {
      final tree = SupabaseCommunityService.buildCommentTree(
        rows: [
          {
            'id': 'c1',
            'post_id': 'p',
            'parent_id': null,
            'author_name': 'a',
            'text': 'top',
            'created_at': '2026-10-01T11:00:00'
          },
          {
            'id': 'c2',
            'post_id': 'p',
            'parent_id': 'c1',
            'author_name': 'b',
            'text': 'reply',
            'created_at': '2026-10-01T11:05:00'
          },
          {
            'id': 'c3',
            'post_id': 'p',
            'parent_id': 'missing',
            'author_name': 'c',
            'text': 'orphan',
            'created_at': '2026-10-01T11:06:00'
          },
        ],
        commentVotes: [
          {'comment_id': 'c1', 'author_email': 'me@ucp.edu.pk', 'value': 1},
        ],
        myEmail: 'me@ucp.edu.pk',
        now: now,
      );
      expect(tree.length, 2); // c1 + orphan c3
      expect(tree.first.replies.length, 1);
      expect(tree.first.replies.first.text, 'reply');
      expect(tree.first.score, 0); // my +1 excluded
      expect(tree.first.vote, 1);
    });
  });

  group('CommunityScreen modes', () {
    testWidgets('null service shows setup notice, not feed',
        (WidgetTester tester) async {
      final colors = AppColors.of(AppPalette.skater, false);
      await tester.pumpWidget(
        AppScope(
          colors: colors,
          palette: AppPalette.skater,
          child: const MaterialApp(
            home: Scaffold(
              body: CommunityScreen(service: null),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Community backend not connected'), findsOneWidget);
      expect(find.text('r/campus'), findsOneWidget);
    });

    testWidgets('fake service renders seed feed with images support',
        (WidgetTester tester) async {
      final colors = AppColors.of(AppPalette.skater, false);
      final svc = FakeCommunityService();
      await tester.pumpWidget(
        AppScope(
          colors: colors,
          palette: AppPalette.skater,
          child: MaterialApp(
            home: Scaffold(
              body: CommunityScreen(
                  service: svc, myEmail: 'tester@ucp.edu.pk'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Study group for the Data Structures midterm?'),
        findsOneWidget,
      );
      svc.dispose();
    });
  });
}
