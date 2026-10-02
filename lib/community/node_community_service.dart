import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../data/seed.dart';
import 'community_service.dart';

/// Community backend speaking to the Node API (`backend/`) instead of
/// Supabase directly. Session travels as `x-ucp-session`; author identity
/// is resolved server-side from the Odoo portal, so votes/comments/posts
/// cannot be forged. Live updates arrive over SSE (`GET /api/stream`).
class NodeCommunityService extends CommunityService {
  final String baseUrl;
  final String? Function() sessionOf;
  final http.Client _client;

  final _updates = StreamController<void>.broadcast();
  bool _sseActive = false;
  bool _disposed = false;
  int _sseGeneration = 0;

  NodeCommunityService({
    required this.baseUrl,
    required this.sessionOf,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    final sid = sessionOf();
    if (sid != null && sid.isNotEmpty) headers['x-ucp-session'] = sid;
    return headers;
  }

  Never _throwFor(http.Response res) {
    String message = 'request failed (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] is String) {
        message = body['error'] as String;
      }
    } catch (_) {}
    throw CommunityException(message);
  }

  @override
  Stream<void> get updates => _updates.stream;

  @override
  bool get supportsRealtime => true;

  @override
  Future<void> ensureRealtime(Future<void> Function() onEvent) async {
    if (_sseActive || _disposed) return;
    _sseActive = true;
    _listen(onEvent);
  }

  Future<void> _listen(Future<void> Function() onEvent) async {
    final generation = ++_sseGeneration;
    try {
      final req =
          http.Request('GET', Uri.parse('$baseUrl/api/stream'));
      req.headers.addAll(_headers());
      final streamed = await _client.send(req);
      if (streamed.statusCode != 200) {
        throw CommunityException('stream unavailable');
      }
      await for (final line in streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (_disposed || generation != _sseGeneration) return;
        if (line.startsWith('data:')) {
          await onEvent();
          if (!_updates.isClosed) _updates.add(null);
        }
      }
    } catch (_) {
      // Fall through to reconnect below.
    }
    if (_disposed || generation != _sseGeneration) return;
    await Future<void>.delayed(const Duration(seconds: 5));
    if (_disposed || generation != _sseGeneration) return;
    _listen(onEvent);
  }

  @override
  Future<List<Post>> fetchPosts({required String myEmail}) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/posts?limit=60'),
      headers: _headers(),
    );
    if (res.statusCode != 200) _throwFor(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['posts'] as List?) ?? [];
    // ignore: avoid_dynamic_calls
    return [for (final p in items) mapPostJson(p as Map<String, dynamic>)];
  }

  /// Pure mapping shared by feed posts: server JSON -> UI model.
  static Post mapPostJson(Map<String, dynamic> json) {
    final comments = ((json['comments'] as List?) ?? [])
        .whereType<Map>()
        .map((c) => Map<String, dynamic>.from(c))
        .toList();
    return Post(
      id: '${json['id']}',
      author: '${json['author'] ?? 'student'}',
      flair: '${json['flair'] ?? 'Study'}',
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? ''}',
      time: _timeLabel(json),
      age: _ageMinutes(json),
      score: _asInt(json['score']),
      vote: _asInt(json['vote']),
      imageUrl: json['imageUrl']?.toString() ?? json['image_url']?.toString(),
      comments: nestEmbedded(comments),
    );
  }

  static String _timeLabel(Map<String, dynamic> json) {
    if (json['time'] is String && (json['time'] as String).isNotEmpty) {
      return json['time'] as String;
    }
    return timeAgo(
      DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
      DateTime.now(),
    ).label;
  }

  static int _ageMinutes(Map<String, dynamic> json) {
    final created = DateTime.tryParse('${json['created_at']}');
    if (created == null) return 0;
    return DateTime.now().difference(created).inMinutes.clamp(0, 1 << 30);
  }

  /// Flat embedded comment rows (already carrying score/vote) -> thread.
  static List<CComment> nestEmbedded(List<Map<String, dynamic>> rows) {
    final nodes = <String, CComment>{};
    final roots = <CComment>[];
    for (final r in rows) {
      final id = '${r['id']}';
      nodes[id] = CComment(
        id: id,
        author: '${r['author_name'] ?? r['author'] ?? 'student'}',
        text: '${r['text'] ?? ''}',
        time: '${r['time'] ?? 'now'}',
        score: _asInt(r['score']),
        vote: _asInt(r['vote']),
      );
    }
    for (final r in rows) {
      final id = '${r['id']}';
      final parent = r['parent_id']?.toString() ?? r['parentId']?.toString();
      final node = nodes[id]!;
      if (parent != null && parent.isNotEmpty && nodes.containsKey(parent)) {
        nodes[parent]!.replies.add(node);
      } else {
        roots.add(node);
      }
    }
    return roots;
  }

  static int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

  Future<Map<String, dynamic>> _postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(json: true),
      body: jsonEncode(body ?? {}),
    );
    if (res.statusCode != 200 && res.statusCode != 201) _throwFor(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  @override
  Future<void> setVote({
    required String postId,
    required String myEmail,
    required int? value,
  }) async {
    await _postJson('/api/posts/$postId/vote',
        body: value == null ? {} : {'value': value});
  }

  @override
  Future<void> setCommentVote({
    required String commentId,
    required String myEmail,
    required int? value,
  }) async {
    await _postJson('/api/comments/$commentId/vote',
        body: value == null ? {} : {'value': value});
  }

  @override
  Future<CComment> addComment({
    required String postId,
    required String? parentId,
    required String myEmail,
    required String authorName,
    required String text,
  }) async {
    final body = await _postJson('/api/posts/$postId/comments', body: {
      'text': text,
      if (parentId != null) 'parentId': parentId,
    });
    final c = (body['comment'] as Map).cast<String, dynamic>();
    final flat = nestEmbedded([c]);
    return flat.isEmpty
        ? CComment(
            id: '${c['id']}', author: authorName, text: text, time: 'now', score: 0)
        : flat.first;
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
    final res = await _postJson('/api/posts', body: {
      'title': title,
      'body': body,
      'flair': flair,
      if (imageUrl != null) 'imageUrl': imageUrl,
    });
    return mapPostJson((res['post'] as Map).cast<String, dynamic>());
  }

  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    required String contentType,
    required String extension,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/upload'))
      ..headers.addAll(_headers())
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: 'upload.$extension',
        contentType: _mediaType(contentType),
      ));
    final streamed = await _client.send(req);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200 && res.statusCode != 201) _throwFor(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final url = body['url']?.toString() ?? '';
    if (url.isEmpty) throw CommunityException('upload returned no url');
    return url;
  }

  static MediaType _mediaType(String contentType) {
    try {
      return MediaType.parse(contentType);
    } catch (_) {
      return MediaType('image', 'jpeg');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sseGeneration++;
    _sseActive = false;
    _updates.close();
    _client.close();
  }
}

class CommunityException implements Exception {
  final String message;
  CommunityException(this.message);
  @override
  String toString() => 'CommunityException: $message';
}
