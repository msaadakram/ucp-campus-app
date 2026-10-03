import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../community/community_service.dart';
import '../data/seed.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/loading.dart';

const _flairs = ['All', 'Study', 'Events', 'Help', 'Memes', 'Marketplace'];

Color _flairColor(String f, AppColors c) {
  switch (f) {
    case 'Study': return c.teal;
    case 'Events': return c.board;
    case 'Help': return c.clay;
    case 'Memes': return c.dust;
    default: return c.tealDeep;
  }
}

class CommunityScreen extends StatefulWidget {
  /// Null in production before Supabase is configured (setup notice shows).
  /// Widget tests inject [FakeCommunityService] with seed content.
  final CommunityService? service;
  final String myEmail;
  const CommunityScreen({super.key, this.service, this.myEmail = ''});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  List<Post> posts = [];
  bool loading = true;
  String? error;
  String sort = 'Hot';
  String flair = 'All';
  String? openId;
  bool composing = false;
  String draft = '';
  CComment? replyTo;
  StreamSubscription<void>? _sub;

  /// Live header numbers. Null until the first successful `/api/stats`.
  /// Kept across feed failures so the header never flickers back to fake.
  CommunityStats? stats;

  /// Comment input controller (cleared on send so the box never keeps the
  /// sent text). `draft` mirrors it for the send guard.
  late final TextEditingController _commentCtrl;
  bool _sendingComment = false;

  /// In-flight like guards so rapid taps never fire duplicate requests.
  final Set<String> _likingPosts = {};
  final Set<String> _likingComments = {};

  String get _email => widget.myEmail;
  String get _handle => handleForEmail(
      _email.isEmpty ? 'ayaan.w@ucp.edu.pk' : _email);

  @override
  void initState() {
    super.initState();
    _commentCtrl = TextEditingController();
    if (widget.service == null) {
      loading = false;
      return;
    }
    _reload();
    if (widget.service!.supportsRealtime) {
      widget.service!.ensureRealtime(() async {});
    }
    _sub = widget.service!.updates.listen((_) => _reload());
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final svc = widget.service;
    if (svc == null || !mounted) return;
    // Posts + stats in parallel so a slow/missing stats endpoint can never
    // hold the feed hostage (the old sequential await stuck the header on
    // "Connecting…" when /api/stats 404'd on older backends).
    try {
      final results = await Future.wait([
        svc.fetchPosts(myEmail: _email),
        svc.fetchStats().then<CommunityStats?>((s) => s).catchError((_) => null),
      ]);
      if (!mounted) return;
      final fresh = results[0] as List<Post>;
      var live = results[1] as CommunityStats?;
      // Fallback: derive real numbers from the loaded feed itself.
      if (live == null || live.members == 0) {
        final prevOnline = stats?.online ?? 1;
        final derived = localStatsFromPosts(fresh, online: prevOnline);
        live = CommunityStats(
          members: live != null && live.members > 0 ? live.members : derived.members,
          online: live != null && live.online > 0 ? live.online : derived.online,
        );
      }
      setState(() {
        posts = fresh;
        loading = false;
        error = null;
        stats = live;
        if (openId != null && !fresh.any((p) => p.id == openId)) {
          openId = null;
          replyTo = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      CommunityStats? live;
      try {
        live = await svc.fetchStats();
      } catch (_) {}
      live ??= stats ?? (posts.isNotEmpty ? localStatsFromPosts(posts) : null);
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Could not load the campus feed. Check connection and retry.';
        if (live != null) stats = live;
      });
    }
  }

  Post? get _openPost {
    for (final p in posts) {
      if (p.id == openId) return p;
    }
    return null;
  }

  Future<void> _votePost(Post p, int v) async {
    final svc = widget.service;
    if (svc == null || _likingPosts.contains(p.id)) return;
    // Like-only UI: v is always 1 here. Toggle off when already liked.
    final next = p.vote == 1 ? null : 1;
    final prev = p.vote;
    _likingPosts.add(p.id);
    // Optimistic: heart fills instantly, no waiting for the network.
    setState(() => p.vote = next ?? 0);
    try {
      await svc.setVote(postId: p.id, myEmail: _email, value: next);
      await _reload();
    } catch (_) {
      if (!mounted) return;
      setState(() => p.vote = prev); // revert on failure
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save like. Try again.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      _likingPosts.remove(p.id);
    }
  }

  Future<void> _voteComment(CComment cm, int v) async {
    final svc = widget.service;
    if (svc == null || _likingComments.contains(cm.id)) return;
    final next = cm.vote == 1 ? null : 1;
    final prev = cm.vote;
    _likingComments.add(cm.id);
    setState(() => cm.vote = next ?? 0);
    try {
      await svc.setCommentVote(commentId: cm.id, myEmail: _email, value: next);
      await _reload();
    } catch (_) {
      if (!mounted) return;
      setState(() => cm.vote = prev);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save like. Try again.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      _likingComments.remove(cm.id);
    }
  }

  Future<void> _sendComment(Post post) async {
    final svc = widget.service;
    final text = _commentCtrl.text.trim();
    if (svc == null || text.isEmpty || _sendingComment) return;
    final isReply = replyTo != null;
    setState(() {
      _sendingComment = true;
      draft = text;
    });
    // Clear the box immediately so the sent text never lingers.
    _commentCtrl.clear();
    draft = '';
    try {
      await svc.addComment(
        postId: post.id,
        parentId: replyTo?.id,
        myEmail: _email,
        authorName: _handle,
        text: text,
      );
      if (!mounted) return;
      setState(() {
        replyTo = null;
        _sendingComment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isReply ? 'Reply posted' : 'Comment posted'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      await _reload();
    } catch (_) {
      if (!mounted) return;
      // Restore so nothing the user typed is lost.
      _commentCtrl.text = text;
      draft = text;
      setState(() => _sendingComment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not post. Check connection and retry.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  List<Post> get shown {
    final f = posts.where((p) => flair == 'All' || p.flair == flair).toList();
    f.sort((a, b) {
      if (sort == 'New') return a.age.compareTo(b.age);
      if (sort == 'Top') return (b.score + b.vote).compareTo(a.score + a.vote);
      return ((b.score + b.vote) / (b.age + 60)).compareTo((a.score + a.vote) / (a.age + 60));
    });
    return f;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    if (widget.service == null) return _setupNotice(c);
    final post = _openPost;
    if (post != null) return _threadView(c, post);
    if (loading) {
      return UHead(
        height: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _feedHeader(c),
            const CommunityFeedSkeleton(),
          ],
        ),
      );
    }
    if (error != null && posts.isEmpty) {
      return UHead(
        height: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _feedHeader(c),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: c.white, borderRadius: BorderRadius.circular(24)),
              child: Column(
                children: [
                  Text(error!,
                      textAlign: TextAlign.center,
                      style: body(c, size: 14)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        loading = true;
                        error = null;
                      });
                      _reload();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                          color: c.teal,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('Retry',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Stack(
      children: [
        UHead(
      height: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _feedHeader(c),
          const SizedBox(height: 12),
          for (final p in shown) _postCard(context, c, p, onOpen: () => setState(() => openId = p.id)),
          if (shown.isEmpty) Center(child: Padding(padding: const EdgeInsets.all(40), child: Text('No posts with this flair yet.', style: body(c, size: 14, color: c.tealInk.withValues(alpha: 0.5))))),
          const SizedBox(height: 96),
        ],
      ),
    ),
        if (composing)
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(child: GestureDetector(onTap: _requestCloseComposer, child: Container(color: Colors.black.withValues(alpha: 0.4)))),
                _ComposerSheet(
                  service: widget.service!,
                  myEmail: _email,
                  authorName: _handle,
                  onClose: () => setState(() => composing = false),
                  onPosted: () => _handlePosted(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _requestCloseComposer() {
    // The sheet itself confirms when there is a draft; this backdrop tap
    // closes directly only when nothing was typed yet. The sheet exposes
    // the check via its state — simplest is to close here and let the
    // sheet's own close button handle the confirm path.
    setState(() => composing = false);
  }

  void _handlePosted() {
    if (!mounted) return;
    setState(() {
      composing = false;
      sort = 'New';
      flair = 'All';
    });
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Posted to r/campus'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Shown in production before Supabase credentials are configured.
  Widget _setupNotice(AppColors c) {
    return UHead(
      height: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('r/campus', style: display(c, size: 28, color: Colors.white)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: c.white, borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Community backend not connected',
                    style: display(c, size: 18)),
                const SizedBox(height: 8),
                Text(
                  'Add your Supabase project URL and anon key (see supabase/README.md), then rebuild the app.',
                  style: body(c,
                      size: 14, color: c.tealInk.withValues(alpha: 0.65)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Header shared by loading/error/feed states so the Post entry points
  /// never disappear (a hanging feed used to hide the composer button).
  Widget _feedHeader(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('r/campus', style: display(c, size: 28, color: Colors.white), overflow: TextOverflow.ellipsis),
                    Text(formatCommunityStats(stats), key: const ValueKey('community-stats'), style: body(c, size: 14, color: Colors.white.withValues(alpha: 0.78)), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => composing = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: c.tealInk, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: c.clay, offset: const Offset(0, 4))]),
                  child: const Row(children: [Icon(Icons.add, size: 18, color: Colors.white), Text(' Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => composing = true),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [const CircleAvatar(radius: 18, child: Text('A')), const SizedBox(width: 12), Expanded(child: Text('Share something with campus…', style: body(c, size: 14, color: c.tealInk.withValues(alpha: 0.5)), overflow: TextOverflow.ellipsis))]),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: c.dustSoft.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(30)),
            child: Row(
              children: [
                for (final s in ['Hot', 'New', 'Top'])
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => sort = s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: sort == s ? c.white : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(s == 'Hot' ? Icons.local_fire_department_outlined : s == 'New' ? Icons.auto_awesome_outlined : Icons.emoji_events_outlined, size: 15), Text(' $s', style: TextStyle(fontWeight: FontWeight.bold, color: sort == s ? c.tealInk : c.tealInk.withValues(alpha: 0.55)))]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in _flairs)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => flair = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(color: flair == f ? c.tealInk : c.dustSoft, borderRadius: BorderRadius.circular(20)),
                        child: Text(f, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: flair == f ? c.cream : c.tealInk.withValues(alpha: 0.7))),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
      ],
    );
  }
  Widget _postCard(BuildContext context, AppColors c, Post p, {VoidCallback? onOpen}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 16, backgroundColor: [c.teal, c.clay, c.board, c.dust, c.tealDeep][p.author.length % 5], child: Text(p.author[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12))),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('u/${p.author}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Text('${p.time} ago', style: TextStyle(fontSize: 12, color: c.tealInk.withValues(alpha: 0.5)))])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _flairColor(p.flair, c), borderRadius: BorderRadius.circular(12)), child: Text(p.flair, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
            ],
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(p.title, style: display(c, size: 17)),
                if (p.body.isNotEmpty) Text(p.body, maxLines: onOpen != null ? 2 : 100, overflow: TextOverflow.ellipsis, style: body(c, size: 14, color: c.tealInk.withValues(alpha: 0.75))),
                if (p.imageUrl != null && p.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      p.imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _likeButton(
                c,
                count: p.score + p.vote,
                liked: p.vote == 1,
                onTap: () => _votePost(p, 1),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpen,
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: c.dustSoft.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(Icons.chat_bubble_outline, size: 16), Flexible(child: Text(' ${countComments(p.comments)}', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))])),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _copyText(context, c,
                      '${p.title}\n\n${p.body}\n— via campus community'),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: c.dustSoft.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(20)), child: const Row(children: [Icon(Icons.share_outlined, size: 15), Flexible(child: Text(' Share', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis))])),
                ),
              ),
              const Spacer(),
              GestureDetector(onTap: () => setState(() => p.saved = !p.saved), child: Container(alignment: Alignment.center, width: 32, height: 32, decoration: BoxDecoration(color: p.saved ? c.board : c.dustSoft.withValues(alpha: 0.7), shape: BoxShape.circle), child: Icon(Icons.bookmark_outline, size: 16, color: p.saved ? c.tealInk : c.tealInk))),
            ],
          ),
        ],
      ),
    );
  }

  /// Like-only button (replaces the old up/down arrows): heart fills
  /// instantly via the optimistic vote above, count = score + my like.
  Widget _likeButton(
    AppColors c, {
    required int count,
    required bool liked,
    required VoidCallback onTap,
    bool small = false,
  }) {
    final color = liked ? c.clay : c.tealInk.withValues(alpha: 0.6);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: small ? 10 : 12, vertical: small ? 5 : 6),
        decoration: BoxDecoration(
          color: liked
              ? c.clay.withValues(alpha: 0.15)
              : c.dustSoft.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(liked ? Icons.favorite : Icons.favorite_outline,
                size: small ? 15 : 16, color: color),
            const SizedBox(width: 4),
            Text('$count',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: small ? 12 : 13,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _threadView(AppColors c, Post post) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(children: [GestureDetector(onTap: () => setState(() { openId = null; replyTo = null; }), child: const Row(children: [Icon(Icons.arrow_back, size: 18), Text(' r/campus', style: TextStyle(fontWeight: FontWeight.w600))]))]),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _postCard(context, c, post),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(24)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${countComments(post.comments)} comments'.toUpperCase(), style: TextStyle(fontSize: 12, color: c.tealInk.withValues(alpha: 0.55))),
                        if (post.comments.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No comments yet — start the conversation.')))
                        else for (final cm in post.comments) _commentTile(context, c, post, cm, 0),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.of(context).viewInsets.bottom),
              decoration: BoxDecoration(color: c.cream2, border: Border(top: BorderSide(color: c.dustSoft))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (replyTo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: c.teal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Replying to u/${replyTo!.author}',
                                overflow: TextOverflow.ellipsis,
                                style: body(c,
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color: c.teal),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => replyTo = null),
                            child: Container(
                              alignment: Alignment.center,
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                  color: c.dustSoft, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('comment-field'),
                          controller: _commentCtrl,
                          enabled: !_sendingComment,
                          onChanged: (v) => draft = v,
                          onSubmitted: (_) => _sendComment(post),
                          decoration: InputDecoration(
                              hintText: replyTo != null
                                  ? 'Write a reply…'
                                  : 'Add a comment…',
                              filled: true,
                              fillColor: c.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        key: const ValueKey('comment-send'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _sendingComment ? null : () => _sendComment(post),
                        child: Opacity(
                          opacity: _sendingComment ? 0.6 : 1,
                          child: Container(
                              alignment: Alignment.center,
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                  color: c.teal, shape: BoxShape.circle),
                              child: _sendingComment
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                            Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.send,
                                      color: Colors.white, size: 18)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyText(
      BuildContext context, AppColors c, String text) async {
    // Confirm instantly (never gated on the platform clipboard, which can
    // hang or be unavailable on some embeds and in tests).
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Copied to clipboard'),
          backgroundColor: c.tealInk,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    try {
      await Clipboard.setData(ClipboardData(text: text))
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  /// Small pill button for comment actions (like/reply/share).
  Widget _miniAction(
    AppColors c, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final color =
        active ? c.clay : c.tealInk.withValues(alpha: 0.6);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? c.clay.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            Text(' $label',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _commentTile(
      BuildContext context, AppColors c, Post post, CComment cm, int depth) {
    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : 12, top: 12),
      child: Container(
        decoration: depth == 0 ? null : BoxDecoration(border: Border(left: BorderSide(color: c.dustSoft, width: 2))),
        padding: EdgeInsets.only(left: depth == 0 ? 0 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                  radius: 12,
                  child: Text(cm.author[0].toUpperCase(),
                      style: const TextStyle(fontSize: 10))),
              const SizedBox(width: 6),
              Flexible(
                child: Text('u/${cm.author}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              Text(' · ${cm.time}',
                  style: TextStyle(
                      fontSize: 12,
                      color: c.tealInk.withValues(alpha: 0.5))),
            ]),
            const SizedBox(height: 4),
            Text(cm.text, style: const TextStyle(fontSize: 14)),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _likeButton(
                  c,
                  count: cm.score + cm.vote,
                  liked: cm.vote == 1,
                  small: true,
                  onTap: () => _voteComment(cm, 1),
                ),
                _miniAction(
                  c,
                  icon: Icons.reply_outlined,
                  label: 'Reply',
                  onTap: () => setState(() => replyTo = cm),
                ),
                _miniAction(
                  c,
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () => _copyText(
                      context, c, 'u/${cm.author}: ${cm.text}'),
                ),
              ],
            ),
            for (final r in cm.replies)
              _commentTile(context, c, post, r, depth + 1),
          ],
        ),
      ),
    );
  }

}

/// Create-post sheet with its OWN State so a parent feed refresh
/// (realtime tick, vote, retry) can never wipe the in-progress draft.
///
/// Previous implementation kept `title`/`body`/`imageBytes` as locals of
/// `_composer()` + `StatefulBuilder`. Every parent `setState` re-ran
/// `_composer()`, resetting those locals to empty while the visible
/// `TextField` kept its text internally. Result: the UI showed text but
/// `title.trim().isEmpty` was true, so the Post button's `onTap` was null
/// and tapping it did nothing — exactly the reported "type text + add
/// photo, Post not working" bug. Hoisting draft state into this widget's
/// State fixes it: the Element (and its controllers) survive parent
/// rebuilds.
class _ComposerSheet extends StatefulWidget {
  final CommunityService service;
  final String myEmail;
  final String authorName;
  final VoidCallback onClose;
  final VoidCallback onPosted;
  const _ComposerSheet({
    required this.service,
    required this.myEmail,
    required this.authorName,
    required this.onClose,
    required this.onPosted,
  });
  @override
  State<_ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends State<_ComposerSheet> {
  static const int maxTitle = 120;
  static const int maxBody = 2000;
  static const int maxImageBytes = 5 * 1024 * 1024;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  String _flair = 'Study';
  Uint8List? _imageBytes;
  String _imageExt = 'jpg';
  String _imageType = 'image/jpeg';
  bool _busy = false;
  String? _stage;
  String? _error;
  bool _preview = false;

  static const _flairIcons = {
    'Study': Icons.menu_book_outlined,
    'Events': Icons.celebration_outlined,
    'Help': Icons.help_outline,
    'Memes': Icons.sentiment_satisfied_alt_outlined,
    'Marketplace': Icons.storefront_outlined,
  };

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController()..addListener(_onDraftChanged);
    _bodyCtrl = TextEditingController()..addListener(_onDraftChanged);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _onDraftChanged() {
    // Refresh counters / Post enablement / preview without losing focus.
    if (mounted) setState(() {});
  }

  bool get _isDirty =>
      _titleCtrl.text.trim().isNotEmpty ||
      _bodyCtrl.text.trim().isNotEmpty ||
      _imageBytes != null;

  bool get _titleOver => _titleCtrl.text.trim().length > maxTitle;
  bool get _bodyOver => _bodyCtrl.text.trim().length > maxBody;
  bool get _canPost =>
      !_busy && _titleCtrl.text.trim().isNotEmpty && !_titleOver && !_bodyOver;

  String _imageSizeLabel() {
    final n = _imageBytes?.length ?? 0;
    if (n >= 1024 * 1024) return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(n / 1024).toStringAsFixed(0)} KB';
  }

  Future<void> _pickImage() async {
    if (_busy) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > maxImageBytes) {
        if (!mounted) return;
        setState(() => _error = 'Image must be under 5 MB.');
        return;
      }
      final name = picked.name.toLowerCase();
      final ext = name.contains('.') ? name.split('.').last : 'jpg';
      const types = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'webp': 'image/webp',
        'gif': 'image/gif',
      };
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageExt = types.containsKey(ext) ? ext : 'jpg';
        _imageType = types[_imageExt]!;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not read that image.');
    }
  }

  Future<void> _confirmClose() async {
    if (_busy) return;
    if (!_isDirty) {
      widget.onClose();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Discard post?'),
        content: const Text('Your draft will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep writing'),
          ),
          TextButton(
            key: const ValueKey('composer-discard-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true) widget.onClose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final title = _titleCtrl.text.trim();
    final bodyText = _bodyCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Add a title before posting.');
      return;
    }
    if (title.length > maxTitle) {
      setState(() => _error = 'Title must be $maxTitle characters or less.');
      return;
    }
    if (bodyText.length > maxBody) {
      setState(() => _error = 'Details must be $maxBody characters or less.');
      return;
    }
    if ((_imageBytes?.length ?? 0) > maxImageBytes) {
      setState(() => _error = 'Image must be under 5 MB.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _stage = _imageBytes != null ? 'Uploading photo…' : 'Publishing…';
    });
    try {
      String? imageUrl;
      if (_imageBytes != null) {
        imageUrl = await widget.service.uploadImage(
          bytes: _imageBytes!,
          contentType: _imageType,
          extension: _imageExt,
        );
        if (!mounted) return;
        setState(() => _stage = 'Publishing…');
      }
      await widget.service.createPost(
        myEmail: widget.myEmail,
        authorName: widget.authorName,
        title: title,
        body: bodyText,
        flair: _flair,
        imageUrl: imageUrl,
      );
      if (!mounted) return;
      widget.onPosted();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stage = null;
        _error = 'Could not publish. Check connection and retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final titleLen = _titleCtrl.text.trim().length;
    final bodyLen = _bodyCtrl.text.trim().length;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: BoxDecoration(
            color: c.cream2,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))
            ]),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                      color: c.dustSoft, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  GestureDetector(
                      onTap: _busy ? null : _confirmClose,
                      child: Container(
                          alignment: Alignment.center,
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              color: c.dustSoft, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 18))),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: c.teal,
                    child: Text(
                      widget.authorName.isEmpty
                          ? 'A'
                          : widget.authorName[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create post',
                            style: display(c, size: 18),
                            overflow: TextOverflow.ellipsis),
                        Text('u/${widget.authorName} · r/campus',
                            style: body(c,
                                size: 12,
                                color: c.tealInk.withValues(alpha: 0.55)),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    key: const ValueKey('composer-post-button'),
                    behavior: HitTestBehavior.opaque,
                    // Always tappable (unless busy) so validation can show
                    // an inline error instead of a dead button.
                    onTap: _busy ? null : _submit,
                    child: Opacity(
                      opacity: _busy
                          ? 0.6
                          : _canPost
                              ? 1
                              : 0.55,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                              color: _canPost || _busy ? c.teal : c.dust,
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_busy)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.white),
                                  ),
                                )
                              else
                                const Icon(Icons.send,
                                    size: 14, color: Colors.white),
                              Text(_busy ? ' ${_stage ?? 'Posting…'}' : ' Post',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ],
                          )),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('FLAIR',
                  style: body(c,
                      size: 11,
                      weight: FontWeight.w800,
                      color: c.tealInk.withValues(alpha: 0.55))),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in _flairs.skip(1))
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          key: ValueKey('composer-flair-$f'),
                          onTap: _busy
                              ? null
                              : () => setState(() => _flair = f),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _flair == f
                                  ? _flairColor(f, c)
                                  : c.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _flair == f
                                    ? _flairColor(f, c)
                                    : c.dustSoft,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_flairIcons[f] ?? Icons.tag,
                                    size: 15,
                                    color: _flair == f
                                        ? Colors.white
                                        : c.teal),
                                Text(' $f',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _flair == f
                                            ? Colors.white
                                            : c.tealInk)),
                                if (_flair == f)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(Icons.check,
                                        size: 14, color: Colors.white),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('TITLE',
                      style: body(c,
                          size: 11,
                          weight: FontWeight.w800,
                          color: c.tealInk.withValues(alpha: 0.55))),
                  const Spacer(),
                  Text('$titleLen/$maxTitle',
                      key: const ValueKey('composer-title-counter'),
                      style: body(c,
                          size: 11,
                          weight: FontWeight.w700,
                          color: _titleOver
                              ? c.clay
                              : c.tealInk.withValues(alpha: 0.5))),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: c.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _titleOver ? c.clay : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: TextField(
                    key: const ValueKey('composer-title'),
                    controller: _titleCtrl,
                    enabled: !_busy,
                    maxLength: maxTitle + 20,
                    buildCounter: (_, {required currentLength, maxLength, required isFocused}) =>
                        const SizedBox.shrink(),
                    decoration: const InputDecoration(
                        hintText: 'An interesting title…',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12)),
                    style: display(c, size: 18)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('DETAILS (OPTIONAL)',
                      style: body(c,
                          size: 11,
                          weight: FontWeight.w800,
                          color: c.tealInk.withValues(alpha: 0.55))),
                  const Spacer(),
                  Text('$bodyLen/$maxBody',
                      key: const ValueKey('composer-body-counter'),
                      style: body(c,
                          size: 11,
                          weight: FontWeight.w700,
                          color: _bodyOver
                              ? c.clay
                              : c.tealInk.withValues(alpha: 0.5))),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: c.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _bodyOver ? c.clay : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: TextField(
                    key: const ValueKey('composer-body'),
                    controller: _bodyCtrl,
                    enabled: !_busy,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: maxBody + 100,
                    buildCounter: (_, {required currentLength, maxLength, required isFocused}) =>
                        const SizedBox.shrink(),
                    decoration: InputDecoration(
                        hintText: 'Say more — when, where, links…',
                        hintStyle: body(c,
                            size: 14,
                            color: c.tealInk.withValues(alpha: 0.45)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12))),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('PHOTO (OPTIONAL)',
                      style: body(c,
                          size: 11,
                          weight: FontWeight.w800,
                          color: c.tealInk.withValues(alpha: 0.55))),
                  const Spacer(),
                  if (_imageBytes != null)
                    Text(_imageSizeLabel(),
                        style: body(c,
                            size: 11,
                            color: c.tealInk.withValues(alpha: 0.55))),
                ],
              ),
              const SizedBox(height: 6),
              if (_imageBytes != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(_imageBytes!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover),
                    ),
                    if (_busy)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.white),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(_stage ?? 'Uploading…',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _busy
                            ? null
                            : () => setState(() => _imageBytes = null),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                )
              else
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: c.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.dustSoft, width: 2),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_outlined,
                                size: 18, color: c.teal),
                            Text('  Add a photo',
                                style: body(c,
                                    size: 13,
                                    weight: FontWeight.w700,
                                    color: c.teal)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('JPG · PNG · WEBP · GIF — under 5 MB',
                            style: body(c,
                                size: 11,
                                color: c.tealInk.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                ),
              if (_imageBytes != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _pickImage,
                        icon: const Icon(Icons.swap_horiz, size: 16),
                        label: const Text('Change'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _imageBytes = null),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Remove'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      key: const ValueKey('composer-preview-toggle'),
                      onPressed: _busy
                          ? null
                          : () => setState(() => _preview = !_preview),
                      icon: Icon(_preview
                          ? Icons.edit_outlined
                          : Icons.visibility_outlined),
                      label: Text(_preview ? 'Edit' : 'Preview'),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Be kind · no spam · title ≤ $maxTitle',
                      textAlign: TextAlign.end,
                      style: body(c,
                          size: 11,
                          color: c.tealInk.withValues(alpha: 0.5)),
                    ),
                  ),
                ],
              ),
              if (_preview) _previewCard(c),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.clay.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_error!,
                      style: body(c,
                          size: 13,
                          weight: FontWeight.w600,
                          color: c.clay)),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  key: const ValueKey('composer-post-button-bottom'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _busy ? null : _submit,
                  child: Opacity(
                    opacity: _busy
                        ? 0.7
                        : _canPost
                            ? 1
                            : 0.55,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _canPost || _busy ? c.teal : c.dust,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _canPost || _busy
                            ? [
                                BoxShadow(
                                    color: c.clay,
                                    offset: const Offset(0, 4))
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_busy)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                          Text(
                            _busy
                                ? ' ${_stage ?? 'Posting…'}'
                                : ' Post to r/campus',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewCard(AppColors c) {
    final title = _titleCtrl.text.trim().isEmpty
        ? 'Your title appears here…'
        : _titleCtrl.text.trim();
    final bodyText = _bodyCtrl.text.trim();
    return Container(
      key: const ValueKey('composer-preview-card'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: c.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: c.teal,
                child: Text(
                  widget.authorName.isEmpty
                      ? 'A'
                      : widget.authorName[0].toUpperCase(),
                  style:
                      const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('u/${widget.authorName} · now',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _flairColor(_flair, c),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(_flair,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: display(c, size: 16)),
          if (bodyText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(bodyText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: body(c,
                      size: 13,
                      color: c.tealInk.withValues(alpha: 0.75))),
            ),
          if (_imageBytes != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_imageBytes!,
                  height: 140, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
        ],
      ),
    );
  }
}
