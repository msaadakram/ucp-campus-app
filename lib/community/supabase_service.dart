import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/seed.dart';
import 'community_service.dart';
import 'supabase_config.dart';

/// Live Supabase backend. Row mapping is factored into pure statics so unit
/// tests cover it with canned rows — no network needed.
class SupabaseCommunityService extends CommunityService {
  static const postsTable = 'community_posts';
  static const commentsTable = 'community_comments';
  static const votesTable = 'community_votes';
  static const commentVotesTable = 'community_comment_votes';
  static const imagesBucket = 'community-images';

  bool _ready = false;
  RealtimeChannel? _channel;
  final _updates = StreamController<void>.broadcast();
  int _refreshSeq = 0;

  Future<SupabaseClient> _client() async {
    if (!_ready) {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      _ready = true;
    }
    return Supabase.instance.client;
  }

  /// Subscribes once per service lifetime; every insert/update/delete on the
  /// four tables schedules a UI refetch (debounced).
  Future<void> ensureRealtime(Future<void> Function() onEvent) async {
    if (_channel != null) return;
    final client = await _client();
    _channel = client
        .channel('campus-community')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: postsTable,
          callback: (_) => _bump(onEvent),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: commentsTable,
          callback: (_) => _bump(onEvent),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: votesTable,
          callback: (_) => _bump(onEvent),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: commentVotesTable,
          callback: (_) => _bump(onEvent),
        )
        .subscribe();
  }

  Future<void> _bump(Future<void> Function() onEvent) async {
    final run = ++_refreshSeq;
    // Debounce the typical insert+vote double-fire.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (run != _refreshSeq) return;
    await onEvent();
    if (!_updates.isClosed) _updates.add(null);
  }

  @override
  Stream<void> get updates => _updates.stream;

  @override
  bool get supportsRealtime => true;

  @override

  @override
  Future<List<Post>> fetchPosts({required String myEmail}) async {
    final client = await _client();
    final now = DateTime.now();
    final rows = await client
        .from(postsTable)
        .select()
        .order('created_at', ascending: false)
        .limit(60);
    final postIds = rows.map((r) => r['id'] as String).toList();
    if (postIds.isEmpty) return [];

    final votes = await client
        .from(votesTable)
        .select('post_id, author_email, value')
        .inFilter('post_id', postIds);
    final commentRows = await client
        .from(commentsTable)
        .select()
        .inFilter('post_id', postIds)
        .order('created_at', ascending: true);
    final commentVotes = await client
        .from(commentVotesTable)
        .select('comment_id, author_email, value');

    return mapPostList(
      rows: List<Map<String, dynamic>>.from(rows),
      votes: List<Map<String, dynamic>>.from(votes),
      comments: List<Map<String, dynamic>>.from(commentRows),
      commentVotes: List<Map<String, dynamic>>.from(commentVotes),
      myEmail: myEmail,
      now: now,
    );
  }

  /// Pure mapping: rows + votes + flat comments -> UI models.
  ///
  /// Scores EXCLUDE the viewer's own vote: the UI renders `score + vote`,
  /// so the same widgets work for live and fake backends.
  static List<Post> mapPostList({
    required List<Map<String, dynamic>> rows,
    required List<Map<String, dynamic>> votes,
    required List<Map<String, dynamic>> comments,
    required List<Map<String, dynamic>> commentVotes,
    required String myEmail,
    required DateTime now,
  }) {
    final scoreByPost = <String, int>{};
    final myVoteByPost = <String, int>{};
    for (final v in votes) {
      final pid = '${v['post_id']}';
      scoreByPost[pid] = (scoreByPost[pid] ?? 0) + _asInt(v['value']);
      if ('${v['author_email']}' == myEmail) {
        myVoteByPost[pid] = _asInt(v['value']);
      }
    }
    final byPost = <String, List<Map<String, dynamic>>>{};
    for (final c in comments) {
      byPost.putIfAbsent('${c['post_id']}', () => []).add(c);
    }
    return [
      for (final r in rows)
        mapPostRow(
          row: r,
          score: (scoreByPost['${r['id']}'] ?? 0) -
              (myVoteByPost['${r['id']}'] ?? 0),
          myVote: myVoteByPost['${r['id']}'] ?? 0,
          comments: buildCommentTree(
            rows: byPost['${r['id']}'] ?? const [],
            commentVotes: commentVotes,
            myEmail: myEmail,
            now: now,
          ),
          now: now,
        ),
    ];
  }

  static Post mapPostRow({
    required Map<String, dynamic> row,
    required int score,
    required int myVote,
    required List<CComment> comments,
    required DateTime now,
  }) {
    final created =
        DateTime.tryParse('${row['created_at']}')?.toLocal() ?? now;
    final t = timeAgo(created, now);
    return Post(
      id: '${row['id']}',
      author: '${row['author_name'] ?? 'student'}',
      flair: '${row['flair'] ?? 'Study'}',
      title: '${row['title'] ?? ''}',
      body: '${row['body'] ?? ''}',
      time: t.label,
      age: t.ageMinutes,
      score: score,
      vote: myVote,
      imageUrl: row['image_url']?.toString(),
      comments: comments,
    );
  }

  /// Flat comment rows (with parent_id) -> nested thread, oldest first.
  static List<CComment> buildCommentTree({
    required List<Map<String, dynamic>> rows,
    required List<Map<String, dynamic>> commentVotes,
    required String myEmail,
    required DateTime now,
  }) {
    final scoreByComment = <String, int>{};
    final myVoteByComment = <String, int>{};
    for (final v in commentVotes) {
      final cid = '${v['comment_id']}';
      scoreByComment[cid] = (scoreByComment[cid] ?? 0) + _asInt(v['value']);
      if ('${v['author_email']}' == myEmail) {
        myVoteByComment[cid] = _asInt(v['value']);
      }
    }
    final nodes = <String, CComment>{};
    final roots = <CComment>[];
    for (final r in rows) {
      final id = '${r['id']}';
      final created =
          DateTime.tryParse('${r['created_at']}')?.toLocal() ?? now;
      nodes[id] = CComment(
        id: id,
        author: '${r['author_name'] ?? 'student'}',
        text: '${r['text'] ?? ''}',
        time: timeAgo(created, now).label,
        score: (scoreByComment[id] ?? 0) - (myVoteByComment[id] ?? 0),
        vote: myVoteByComment[id] ?? 0,
      );
    }
    for (final r in rows) {
      final id = '${r['id']}';
      final parent = r['parent_id']?.toString();
      final node = nodes[id]!;
      if (parent != null && parent.isNotEmpty && nodes.containsKey(parent)) {
        nodes[parent]!.replies.add(node);
      } else {
        roots.add(node);
      }
    }
    return roots;
  }

  static int _asInt(dynamic v) =>
      v is int ? v : int.tryParse('$v') ?? 0;

  @override
  Future<void> setVote({
    required String postId,
    required String myEmail,
    required int? value,
  }) async {
    final client = await _client();
    if (value == null) {
      await client
          .from(votesTable)
          .delete()
          .eq('post_id', postId)
          .eq('author_email', myEmail);
    } else {
      await client.from(votesTable).upsert(
        {'post_id': postId, 'author_email': myEmail, 'value': value},
        onConflict: 'post_id,author_email',
      );
    }
  }

  @override
  Future<void> setCommentVote({
    required String commentId,
    required String myEmail,
    required int? value,
  }) async {
    final client = await _client();
    if (value == null) {
      await client
          .from(commentVotesTable)
          .delete()
          .eq('comment_id', commentId)
          .eq('author_email', myEmail);
    } else {
      await client.from(commentVotesTable).upsert(
        {'comment_id': commentId, 'author_email': myEmail, 'value': value},
        onConflict: 'comment_id,author_email',
      );
    }
  }

  @override
  Future<CComment> addComment({
    required String postId,
    required String? parentId,
    required String myEmail,
    required String authorName,
    required String text,
  }) async {
    final client = await _client();
    final row = await client
        .from(commentsTable)
        .insert({
          'post_id': postId,
          'parent_id': parentId,
          'author_email': myEmail,
          'author_name': authorName,
          'text': text,
        })
        .select()
        .single();
    final now = DateTime.now();
    return CComment(
      id: '${row['id']}',
      author: authorName,
      text: text,
      time: 'now',
      score: 0,
      vote: 0,
    );
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
    final client = await _client();
    final row = await client
        .from(postsTable)
        .insert({
          'author_email': myEmail,
          'author_name': authorName,
          'title': title,
          'body': body,
          'flair': flair,
          'image_url': imageUrl,
        })
        .select()
        .single();
    return Post(
      id: '${row['id']}',
      author: authorName,
      flair: flair,
      title: title,
      body: body,
      time: 'now',
      age: 0,
      score: 0,
      imageUrl: imageUrl,
    );
  }

  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    required String contentType,
    required String extension,
  }) async {
    final client = await _client();
    final path =
        'posts/${DateTime.now().millisecondsSinceEpoch}_${bytes.length}.$extension';
    await client.storage.from(imagesBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return client.storage.from(imagesBucket).getPublicUrl(path);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _updates.close();
  }
}
