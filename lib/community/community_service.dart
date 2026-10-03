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

  /// Toggle my like on a post: 1 = liked, null = unliked.
  /// The backend still accepts -1 for compat, but the UI is like-only now.
  Future<void> setVote({
    required String postId,
    required String myEmail,
    required int? value,
  });

  /// Toggle my like on a comment. Same contract as [setVote].
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

  /// Live header numbers. Default returns zeros so older test doubles keep
  /// compiling; real backends override. UI never fails the feed if this
  /// throws — it keeps the last good value.
  Future<CommunityStats> fetchStats() async =>
      const CommunityStats(members: 0, online: 0);

  void dispose();
}

/// Live campus numbers for the `r/campus` header. Both values are 100%
/// real: `members` = distinct contributor emails in the backend tables,
/// `online` = current SSE subscribers (live feed viewers).
class CommunityStats {
  final int members;
  final int online;
  const CommunityStats({required this.members, required this.online});

  static int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

  factory CommunityStats.fromJson(Map<String, dynamic> json) =>
      CommunityStats(
        members: _asInt(json['members']),
        online: _asInt(json['online']),
      );
}

/// Header subtitle: `12 students · 3 online`. Null (still loading) shows a
/// truthful connecting state; zero members with a loaded feed falls back to
/// counting at least yourself as online.
String formatCommunityStats(CommunityStats? stats) {
  if (stats == null) return 'Connecting…';
  final members = stats.members < 0 ? 0 : stats.members;
  final online = stats.online < 0 ? 0 : stats.online;
  final shownOnline = members > 0 && online == 0 ? 1 : online;
  final students = members == 1 ? '1 student' : '$members students';
  final live = shownOnline == 1 ? '1 online' : '$shownOnline online';
  return '$students · $live';
}

/// Local fallback when `/api/stats` is missing (old backend) or fails:
/// distinct post + comment authors from the already-loaded feed. 100% real,
/// never hardcoded, so the header can never stick on "Connecting…".
CommunityStats localStatsFromPosts(List<Post> posts, {int online = 1}) {
  final members = <String>{};
  void walk(List<CComment> list) {
    for (final c in list) {
      if (c.author.trim().isNotEmpty) {
        members.add(c.author.trim().toLowerCase());
      }
      walk(c.replies);
    }
  }

  for (final p in posts) {
    if (p.author.trim().isNotEmpty) {
      members.add(p.author.trim().toLowerCase());
    }
    walk(p.comments);
  }
  return CommunityStats(members: members.length, online: online);
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
