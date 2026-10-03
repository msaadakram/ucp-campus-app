import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../community/community_service.dart';
import '../data/seed.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';

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

  String get _email => widget.myEmail;
  String get _handle => handleForEmail(
      _email.isEmpty ? 'ayaan.w@ucp.edu.pk' : _email);

  @override
  void initState() {
    super.initState();
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
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final svc = widget.service;
    if (svc == null || !mounted) return;
    try {
      final fresh = await svc.fetchPosts(myEmail: _email);
      if (!mounted) return;
      setState(() {
        posts = fresh;
        loading = false;
        error = null;
        if (openId != null && !fresh.any((p) => p.id == openId)) {
          openId = null;
          replyTo = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Could not load the campus feed. Check connection and retry.';
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
    if (svc == null) return;
    await svc.setVote(
        postId: p.id, myEmail: _email, value: p.vote == v ? null : v);
    await _reload();
  }

  Future<void> _voteComment(CComment cm, int v) async {
    final svc = widget.service;
    if (svc == null) return;
    // Comment id is unique across the feed in both backends.
    await svc.setCommentVote(
        commentId: cm.id, myEmail: _email, value: cm.vote == v ? null : v);
    await _reload();
  }

  Future<void> _sendComment(Post post) async {
    final svc = widget.service;
    if (svc == null || draft.trim().isEmpty) return;
    await svc.addComment(
      postId: post.id,
      parentId: replyTo?.id,
      myEmail: _email,
      authorName: _handle,
      text: draft.trim(),
    );
    if (!mounted) return;
    setState(() {
      draft = '';
      replyTo = null;
    });
    await _reload();
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
            const SizedBox(height: 24),
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator())),
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
                Expanded(child: GestureDetector(onTap: () => setState(() => composing = false), child: Container(color: Colors.black.withValues(alpha: 0.4)))),
                _ComposerSheet(
                  service: widget.service!,
                  myEmail: _email,
                  authorName: _handle,
                  onClose: () => setState(() => composing = false),
                  onPosted: () {
                    if (!mounted) return;
                    setState(() {
                      composing = false;
                      sort = 'New';
                      flair = 'All';
                    });
                    _reload();
                  },
                ),
              ],
            ),
          ),
      ],
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
                    Text('4.2k students · 138 online', style: body(c, size: 14, color: Colors.white.withValues(alpha: 0.78)), overflow: TextOverflow.ellipsis),
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
              _votes(c, p.score, p.vote, (v) => _votePost(p, v)),
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

  Widget _votes(AppColors c, int score, int vote, ValueChanged<int> onVote) {
    return Container(
      decoration: BoxDecoration(color: c.dustSoft.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          IconButton(icon: Icon(Icons.arrow_circle_up_outlined, color: vote == 1 ? c.clay : c.tealInk.withValues(alpha: 0.6)), onPressed: () => onVote(1), iconSize: 20, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
          Text('${score + vote}', style: TextStyle(fontWeight: FontWeight.bold, color: vote == 1 ? c.clay : vote == -1 ? c.teal : c.tealInk)),
          IconButton(icon: Icon(Icons.arrow_circle_down_outlined, color: vote == -1 ? c.teal : c.tealInk.withValues(alpha: 0.6)), onPressed: () => onVote(-1), iconSize: 20, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
        ],
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => draft = v,
                      decoration: InputDecoration(hintText: replyTo != null ? 'Write a reply…' : 'Add a comment…', filled: true, fillColor: c.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _sendComment(post),
                    child: Container(alignment: Alignment.center, width: 44, height: 44, decoration: BoxDecoration(color: c.teal, shape: BoxShape.circle), child: const Icon(Icons.send, color: Colors.white, size: 18)),
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
                _votes(c, cm.score, cm.vote, (v) => _voteComment(cm, v)),
                _miniAction(
                  c,
                  icon: cm.vote == 1
                      ? Icons.favorite
                      : Icons.favorite_outline,
                  label: 'Like',
                  active: cm.vote == 1,
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
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  String _flair = 'Study';
  Uint8List? _imageBytes;
  String _imageExt = 'jpg';
  String _imageType = 'image/jpeg';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _bodyCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    if (_busy) return;
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Add a title before posting.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? imageUrl;
      if (_imageBytes != null) {
        imageUrl = await widget.service.uploadImage(
          bytes: _imageBytes!,
          contentType: _imageType,
          extension: _imageExt,
        );
      }
      await widget.service.createPost(
        myEmail: widget.myEmail,
        authorName: widget.authorName,
        title: title,
        body: _bodyCtrl.text.trim(),
        flair: _flair,
        imageUrl: imageUrl,
      );
      if (!mounted) return;
      widget.onPosted();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not publish. Check connection and retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: c.cream2,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32))),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                      onTap: _busy ? null : widget.onClose,
                      child: Container(
                          alignment: Alignment.center,
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              color: c.dustSoft, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 18))),
                  Text('Create post', style: display(c, size: 18)),
                  GestureDetector(
                    key: const ValueKey('composer-post-button'),
                    behavior: HitTestBehavior.opaque,
                    // Always tappable (unless busy) so validation can show
                    // an inline error instead of a dead button.
                    onTap: _busy ? null : _submit,
                    child: Opacity(
                      opacity: _busy ? 0.4 : 1,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                              color: c.teal,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(_busy ? 'Posting…' : 'Post',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final f in _flairs.skip(1))
                    GestureDetector(
                        onTap: _busy
                            ? null
                            : () => setState(() => _flair = f),
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: _flair == f
                                    ? _flairColor(f, c)
                                    : c.dustSoft,
                                borderRadius: BorderRadius.circular(16)),
                            child: Text(f,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _flair == f
                                        ? Colors.white
                                        : c.tealInk)))),
                ],
              ),
              TextField(
                  key: const ValueKey('composer-title'),
                  controller: _titleCtrl,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                      hintText: 'An interesting title',
                      border: InputBorder.none),
                  style: display(c, size: 20)),
              TextField(
                  key: const ValueKey('composer-body'),
                  controller: _bodyCtrl,
                  enabled: !_busy,
                  maxLines: 4,
                  decoration: InputDecoration(
                      hintText: 'Say more (optional)',
                      filled: true,
                      fillColor: c.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              if (_imageBytes != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(_imageBytes!,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover),
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: c.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.dustSoft, width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_outlined,
                            size: 18, color: c.teal),
                        Text('  Add a photo (optional)',
                            style: body(c,
                                size: 13,
                                weight: FontWeight.w600,
                                color: c.teal)),
                      ],
                    ),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: body(c,
                        size: 13,
                        weight: FontWeight.w600,
                        color: c.clay)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
