import 'dart:async';
import 'dart:typed_data';

import '../data/seed.dart';

/// Community backend contract: live Supabase in production, seeded fake in
/// widget tests, setup notice when unconfigured. The UI only speaks this
/// interface, so all three modes share every pixel.
abstract class CommunityService {
  /// Latest posts (newest first), each carrying its total score, the
  /// viewer's own vote, and its full comment tree.
  Future<List<Post>> fetchPosts({required String myEmail});

  /// Toggle my vote on a post: 1 = up, -1 = down, null = remove.
  Future<void> setVote({
    required String postId,
    required String myEmail,
    required int? value,
  });

  /// Toggle my vote on a comment. Same contract as [setVote].
  Future<void> setCommentVote({
    required String commentId,
    required String myEmail,
    required int? value,
  });

  /// Append a top-level comment (or a reply when [parentId] is set).
  Future<CComment> addComment({
    required String postId,
    required String? parentId,
    required String myEmail,
    required String authorName,
    required String text,
  });

  /// Publish a post, optionally with an already-uploaded [imageUrl].
  Future<Post> createPost({
    required String myEmail,
    required String authorName,
    required String title,
    required String body,
    required String flair,
    String? imageUrl,
  });

  /// Upload raw image bytes, returning the public URL for [createPost].
  Future<String> uploadImage({
    required Uint8List bytes,
    required String contentType,
    required String extension,
  });

  /// Fires whenever posts, comments or votes change upstream (realtime in
  /// the live backend; manual bumps in the fake). UI refetches on events.
  Stream<void> get updates;

  /// True when the backend pushes live changes (Supabase realtime).
  bool get supportsRealtime;

  /// Starts the realtime subscription; [onEvent] refetches. No-op when
  /// [supportsRealtime] is false.
  Future<void> ensureRealtime(Future<void> Function() onEvent);

  void dispose();
}

/// Human "12m / 3h / 2d" label + sort-age minutes for a timestamp.
({String label, int ageMinutes}) timeAgo(DateTime createdAt, DateTime now) {
  final mins = now.difference(createdAt).inMinutes.clamp(0, 1 << 30);
  if (mins < 1) return (label: 'now', ageMinutes: 0);
  if (mins < 60) return (label: '${mins}m', ageMinutes: mins);
  final hours = mins ~/ 60;
  if (hours < 24) return (label: '${hours}h', ageMinutes: mins);
  return (label: '${hours ~/ 24}d', ageMinutes: mins);
}

/// Display handle for a UCP email: `l1f25bscs0577@ucp.edu.pk` -> `l1f25bscs0577`.
String handleForEmail(String email) {
  final handle = email.split('@').first.trim();
  return handle.isEmpty ? 'student' : handle;
}
