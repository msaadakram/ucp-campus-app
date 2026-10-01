import 'dart:async';
import 'dart:typed_data';

import '../data/seed.dart';
import 'community_service.dart';

int _uid = 100;
CComment _c(String author, String text, String time, int score,
        [List<CComment>? replies]) =>
    CComment(
        id: 'c${_uid++}',
        author: author,
        text: text,
        time: time,
        score: score,
        replies: replies);

/// Seed content powering widget tests (and nothing else in production).
List<Post> seedPosts() => [
      Post(
          id: 'p1',
          author: 'sara.malik',
          flair: 'Study',
          title: 'Study group for the Data Structures midterm?',
          body:
              'Thinking Library room 3, Thursday 5pm. We can split topics — trees, heaps, graphs. Drop a comment if you want in.',
          time: '12m',
          age: 12,
          score: 42,
          comments: [
            _c('omar.k', "I'm in! I can take graphs + BFS/DFS.", '10m', 12,
                [_c('sara.malik', 'Perfect, adding you to the list.', '8m', 5)]),
            _c('hana.i', 'Can we do 6pm? Lab runs late.', '6m', 3)
          ]),
      Post(
          id: 'p2',
          author: 'codingclub',
          flair: 'Events',
          title: 'Hack Night this Friday — pizza, prizes & mentors',
          body:
              'Studio 3, 7pm till late. Teams of up to 4. Beginners very welcome. Sign up on the student portal.',
          time: '1h',
          age: 60,
          score: 128,
          comments: [
            _c('leo.b', 'Is there a theme this time?', '48m', 9, [
              _c('codingclub', 'Campus life tools! Revealed at kickoff.',
                  '40m', 14)
            ])
          ]),
      Post(
          id: 'p3',
          author: 'omar.k',
          flair: 'Help',
          title: 'Eigenvalues finally clicked — sharing my notes',
          body:
              'Uploaded handwritten notes on eigenvalues/eigenvectors to the MA 201 material folder. Hope it helps someone before the quiz.',
          time: '3h',
          age: 180,
          score: 86,
          comments: [_c('ayaan.w', 'Legend. Page 3 saved me.', '2h', 7)]),
      Post(
          id: 'p4',
          author: 'zainab.r',
          flair: 'Marketplace',
          title: 'Selling: Casio fx-991 + Linear Algebra textbook',
          body:
              'Both in great condition. Rs 3,500 for the pair, can meet at the cafeteria.',
          time: '5h',
          age: 300,
          score: 17),
    ];

/// In-memory community backend used by widget tests. Mirrors the exact
/// seed content and the exact local rules the UI had before Supabase:
/// instant votes, nested replies, newest-first composer inserts.
class FakeCommunityService extends CommunityService {
  int _nextPost = 1000;
  int _nextComment = 5000;
  final _updates = StreamController<void>.broadcast(sync: true);

  late List<Post> _posts = seedPosts();
  final Map<String, Map<String, int>> _postVotes = {};
  final Map<String, Map<String, int>> _commentVotes = {};
  final Map<String, String> _images = {};
  int _imageSeq = 0;

  /// Resets to seed content (fresh state per test).
  void reset() {
    _posts = seedPosts();
    _postVotes.clear();
    _commentVotes.clear();
    _images.clear();
  }

  @override
  Stream<void> get updates => _updates.stream;

  @override
  bool get supportsRealtime => false;

  @override
  Future<void> ensureRealtime(Future<void> Function() onEvent) async {}

  @override
  Future<List<Post>> fetchPosts({required String myEmail}) async {
    for (final p in _posts) {
      p.vote = _postVotes[p.id]?[myEmail] ?? 0;
      _applyCommentVotes(p.comments, myEmail);
    }
    return _posts;
  }

  void _applyCommentVotes(List<CComment> list, String myEmail) {
    for (final c in list) {
      c.vote = _commentVotes[c.id]?[myEmail] ?? 0;
      _applyCommentVotes(c.replies, myEmail);
    }
  }

  @override
  Future<void> setVote({
    required String postId,
    required String myEmail,
    required int? value,
  }) async {
    // `score` always excludes my own vote (UI renders score + vote), so
    // only the vote marker moves here — matching the live mapper.
    final post = _posts.firstWhere((p) => p.id == postId);
    final mine = _postVotes.putIfAbsent(postId, () => {});
    final before = mine[myEmail] ?? 0;
    if (value == null || value == before) {
      mine.remove(myEmail);
      post.vote = 0;
    } else {
      mine[myEmail] = value;
      post.vote = value;
    }
    _updates.add(null);
  }

  @override
  Future<void> setCommentVote({
    required String commentId,
    required String myEmail,
    required int? value,
  }) async {
    final target = _findComment(commentId);
    if (target == null) return;
    final mine = _commentVotes.putIfAbsent(commentId, () => {});
    final before = mine[myEmail] ?? 0;
    if (value == null || value == before) {
      mine.remove(myEmail);
      target.vote = 0;
    } else {
      mine[myEmail] = value;
      target.vote = value;
    }
    _updates.add(null);
  }

  CComment? _findComment(String id) {
    CComment? walk(List<CComment> list) {
      for (final c in list) {
        if (c.id == id) return c;
        final nested = walk(c.replies);
        if (nested != null) return nested;
      }
      return null;
    }

    for (final p in _posts) {
      final found = walk(p.comments);
      if (found != null) return found;
    }
    return null;
  }

  @override
  Future<CComment> addComment({
    required String postId,
    required String? parentId,
    required String myEmail,
    required String authorName,
    required String text,
  }) async {
    final post = _posts.firstWhere((p) => p.id == postId);
    final comment = CComment(
      id: 'c${_nextComment++}',
      author: authorName,
      text: text,
      time: 'now',
      score: 1,
    );
    if (parentId == null) {
      post.comments.insert(0, comment);
    } else {
      final parent = _findComment(parentId);
      parent?.replies.add(comment);
    }
    _updates.add(null);
    return comment;
  }

  @override
  Future<Post> createPost({
    required String myEmail,
    required String authorName,
    required String title,
    required String body,
    required String flair,
    String? imageUrl,
  }) async {
    final post = Post(
      id: 'p${_nextPost++}',
      author: authorName,
      flair: flair,
      title: title,
      body: body,
      time: 'now',
      age: 0,
      score: 1,
      imageUrl: imageUrl,
    );
    _posts.insert(0, post);
    _updates.add(null);
    return post;
  }

  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    required String contentType,
    required String extension,
  }) async {
    final url = 'https://fake.cdn/posts/img_${_imageSeq++}.$extension';
    _images[url] = String.fromCharCodes(bytes.take(4));
    return url;
  }

  @override
  void dispose() => _updates.close();
}
