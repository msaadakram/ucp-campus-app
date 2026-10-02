import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ucp/community/community_service.dart';
import 'package:ucp/community/fake_community_service.dart';
import 'package:ucp/community/node_community_service.dart';
import 'package:ucp/data/seed.dart';
import 'package:ucp/screens/community.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

/// Never resolves: proves the UI keeps its Post entry points on a hung feed.
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
      required String text}) async {
    throw UnimplementedError();
  }

  @override
  Future<Post> createPost(
      {required String myEmail,
      required String authorName,
      required String title,
      required String body,
      required String flair,
      String? imageUrl}) async {
    throw UnimplementedError();
  }

  @override
  Future<String> uploadImage(
      {required Uint8List bytes,
      required String contentType,
      required String extension}) async {
    throw UnimplementedError();
  }

  @override
  Stream<void> get updates => Stream<void>.empty();
  @override
  bool get supportsRealtime => false;
  @override
  Future<void> ensureRealtime(Future<void> Function() onEvent) async {}
  @override
  void dispose() {}
}

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

  group('CommunityScreen modes', () {
    testWidgets('post button stays visible while the feed hangs',
        (WidgetTester tester) async {
      final colors = AppColors.of(AppPalette.skater, false);
      await tester.pumpWidget(
        AppScope(
          colors: colors,
          palette: AppPalette.skater,
          child: MaterialApp(
            home: Scaffold(
              body: CommunityScreen(service: _HangingService()),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // Header (with both Post entry points) renders despite no data yet.
      expect(find.text(' Post'), findsOneWidget);
      expect(find.text('Share something with campus…'), findsOneWidget);
      expect(find.text('r/campus'), findsOneWidget);
    });

    Future<void> openThread(WidgetTester tester) async {
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
      final title =
          find.text('Study group for the Data Structures midterm?');
      await tester.ensureVisible(title);
      await tester.pumpAndSettle();
      await tester.tap(title);
      await tester.pumpAndSettle();
    }

    testWidgets('heart likes then unlikes a comment',
        (WidgetTester tester) async {
      await openThread(tester);
      expect(find.byIcon(Icons.favorite), findsNothing);
      await tester.ensureVisible(find.text(' Like').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(' Like').first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      await tester.ensureVisible(find.text(' Like').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(' Like').first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsNothing);
    });

    testWidgets('comment share copies to clipboard',
        (WidgetTester tester) async {
      await openThread(tester);
      await tester.ensureVisible(find.text(' Share').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(' Share').first);
      await tester.pumpAndSettle();
      expect(find.text('Copied to clipboard'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3)); // let snackbar dismiss
    });

    testWidgets('post share copies to clipboard',
        (WidgetTester tester) async {
      final colors = AppColors.of(AppPalette.skater, false);
      await tester.pumpWidget(
        AppScope(
          colors: colors,
          palette: AppPalette.skater,
          child: MaterialApp(
            home: Scaffold(
              body: CommunityScreen(
                  service: FakeCommunityService(),
                  myEmail: 'tester@ucp.edu.pk'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(' Share').first);
      await tester.pumpAndSettle();
      expect(find.text('Copied to clipboard'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3)); // let snackbar dismiss
    });

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

  group('NodeCommunityService (mocked backend)', () {
    const feedBody = '{"posts": [{'
        '"id":"p1","author":"sara","flair":"Study","title":"T","body":"B",'
        '"created_at":"2026-10-01T11:00:00","score":5,"vote":1,'
        '"image_url":null,'
        '"comments":['
        '{"id":"c1","parent_id":null,"author_name":"omar","text":"in!",'
        '"score":2,"vote":0},'
        '{"id":"c2","parent_id":"c1","author_name":"sara","text":"nice",'
        '"score":0,"vote":0}'
        ']}]}';

    NodeCommunityService service(MockClient client) =>
        NodeCommunityService(
          baseUrl: 'https://api.test',
          sessionOf: () => 'sid-1',
          client: client,
        );

    test('feed maps posts and nests embedded comments', () async {
      final svc = service(MockClient((req) async {
        expect(req.headers['x-ucp-session'], 'sid-1');
        expect(req.url.path, '/api/posts');
        return http.Response(
          feedBody,
          200,
          headers: {'content-type': 'application/json'},
        );
      }));
      final posts = await svc.fetchPosts(myEmail: 'me@ucp.edu.pk');
      expect(posts.length, 1);
      expect(posts.first.title, 'T');
      expect(posts.first.score, 5);
      expect(posts.first.vote, 1);
      expect(posts.first.comments.length, 1);
      expect(posts.first.comments.first.replies.length, 1);
      expect(posts.first.comments.first.replies.first.text, 'nice');
      svc.dispose();
    });

    test('server error surfaces message', () async {
      final svc = service(MockClient((_) async => http.Response(
            '{"error":"portal session expired or missing"}',
            401,
          )));
      await expectLater(
        svc.fetchPosts(myEmail: 'x'),
        throwsA(
          isA<CommunityException>().having(
            (e) => e.message,
            'message',
            contains('portal session expired'),
          ),
        ),
      );
      svc.dispose();
    });

    test('vote/create round-trips', () async {
      final calls = <String>[];
      final svc = service(MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        if (req.url.path.endsWith('/vote')) {
          return http.Response('{"ok":true}', 200);
        }
        return http.Response(
          '{"post":{"id":"p9","author":"me","flair":"Help","title":"Q?",'
          '"body":"","created_at":"2026-10-01T11:59:00","score":0,"vote":0,'
          '"image_url":null,"comments":[]}}',
          201,
        );
      }));
      await svc.setVote(postId: 'p1', myEmail: 'm', value: 1);
      final post = await svc.createPost(
        myEmail: 'm',
        authorName: 'me',
        title: 'Q?',
        body: '',
        flair: 'Help',
      );
      expect(post.id, 'p9');
      expect(calls, ['POST /api/posts/p1/vote', 'POST /api/posts']);
      svc.dispose();
    });

    test('upload posts multipart and returns url', () async {
      String? contentType;
      final svc = service(MockClient((req) async {
        contentType = req.headers['content-type'];
        return http.Response('{"url":"https://cdn/x.jpg"}', 201);
      }));
      final url = await svc.uploadImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        contentType: 'image/jpeg',
        extension: 'jpg',
      );
      expect(url, 'https://cdn/x.jpg');
      expect(contentType, contains('multipart/form-data'));
      svc.dispose();
    });
  });
}
