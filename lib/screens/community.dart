import 'package:flutter/material.dart';
import '../data/seed.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';

int _uid = 100;
CComment _c(String author, String text, String time, int score, [List<CComment>? replies]) =>
    CComment(id: _uid++, author: author, text: text, time: time, score: score, replies: replies);

List<Post> seedPosts() => [
      Post(id: 1, author: 'sara.malik', flair: 'Study', title: 'Study group for the Data Structures midterm?', body: 'Thinking Library room 3, Thursday 5pm. We can split topics — trees, heaps, graphs. Drop a comment if you want in.', time: '12m', age: 12, score: 42, comments: [_c('omar.k', "I'm in! I can take graphs + BFS/DFS.", '10m', 12, [_c('sara.malik', 'Perfect, adding you to the list.', '8m', 5)]), _c('hana.i', 'Can we do 6pm? Lab runs late.', '6m', 3)]),
      Post(id: 2, author: 'codingclub', flair: 'Events', title: 'Hack Night this Friday — pizza, prizes & mentors', body: 'Studio 3, 7pm till late. Teams of up to 4. Beginners very welcome. Sign up on the student portal.', time: '1h', age: 60, score: 128, comments: [_c('leo.b', 'Is there a theme this time?', '48m', 9, [_c('codingclub', 'Campus life tools! Revealed at kickoff.', '40m', 14)])]),
      Post(id: 3, author: 'omar.k', flair: 'Help', title: 'Eigenvalues finally clicked — sharing my notes', body: 'Uploaded handwritten notes on eigenvalues/eigenvectors to the MA 201 material folder. Hope it helps someone before the quiz.', time: '3h', age: 180, score: 86, comments: [_c('ayaan.w', 'Legend. Page 3 saved me.', '2h', 7)]),
      Post(id: 4, author: 'zainab.r', flair: 'Marketplace', title: 'Selling: Casio fx-991 + Linear Algebra textbook', body: 'Both in great condition. Rs 3,500 for the pair, can meet at the cafeteria.', time: '5h', age: 300, score: 17),
    ];

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
  const CommunityScreen({super.key});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late List<Post> posts = seedPosts();
  String sort = 'Hot';
  String flair = 'All';
  int? openId;
  bool composing = false;
  String draft = '';
  CComment? replyTo;

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
    final post = openId == null ? null : posts.firstWhere((p) => p.id == openId);
    if (post != null) return _threadView(c, post);
    return UHead(
      height: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('r/campus', style: display(c, size: 28, color: Colors.white)),
                  Text('4.2k students · 138 online', style: body(c, size: 14, color: Colors.white.withValues(alpha: 0.78))),
                ],
              ),
              GestureDetector(
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
            onTap: () => setState(() => composing = true),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [const CircleAvatar(radius: 18, child: Text('A')), const SizedBox(width: 12), Text('Share something with campus…', style: body(c, size: 14, color: c.tealInk.withValues(alpha: 0.5)))]),
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
          for (final p in shown) _postCard(c, p, onOpen: () => setState(() => openId = p.id)),
          if (shown.isEmpty) Center(child: Padding(padding: const EdgeInsets.all(40), child: Text('No posts with this flair yet.', style: body(c, size: 14, color: c.tealInk.withValues(alpha: 0.5))))),
          const SizedBox(height: 100),
          if (composing) _composer(c),
        ],
      ),
    );
  }

  Widget _postCard(AppColors c, Post p, {VoidCallback? onOpen}) {
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
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(p.title, style: display(c, size: 17)),
                if (p.body.isNotEmpty) Text(p.body, maxLines: onOpen != null ? 2 : 100, overflow: TextOverflow.ellipsis, style: body(c, size: 14, color: c.tealInk.withValues(alpha: 0.75))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _votes(c, p.score, p.vote, (v) => setState(() => p.vote = p.vote == v ? 0 : v)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onOpen,
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: c.dustSoft.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(Icons.chat_bubble_outline, size: 16), Text(' ${countComments(p.comments)}', style: const TextStyle(fontWeight: FontWeight.bold))])),
              ),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: c.dustSoft.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(20)), child: const Row(children: [Icon(Icons.share_outlined, size: 15), Text(' Share', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))])),
              const Spacer(),
              GestureDetector(onTap: () => setState(() => p.saved = !p.saved), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: p.saved ? c.board : c.dustSoft.withValues(alpha: 0.7), shape: BoxShape.circle), child: Icon(Icons.bookmark_outline, size: 16, color: p.saved ? c.tealInk : c.tealInk))),
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
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
      child: Column(
        children: [
          Row(children: [GestureDetector(onTap: () => setState(() { openId = null; replyTo = null; }), child: const Row(children: [Icon(Icons.arrow_back, size: 18), Text(' r/campus', style: TextStyle(fontWeight: FontWeight.w600))]))]),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _postCard(c, post),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(24)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${countComments(post.comments)} comments'.toUpperCase(), style: TextStyle(fontSize: 12, color: c.tealInk.withValues(alpha: 0.55))),
                        if (post.comments.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No comments yet — start the conversation.')))
                        else for (final cm in post.comments) _commentTile(c, post, cm, 0),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
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
                  onTap: () {
                    if (draft.trim().isEmpty) return;
                    setState(() {
                      final nc = CComment(id: _uid++, author: 'ayaan.w', text: draft.trim(), time: 'now', score: 1);
                      if (replyTo != null) {
                        post.comments.toList();
                        _insertReply(post.comments, replyTo!.id, nc);
                      } else {
                        post.comments.insert(0, nc);
                      }
                      draft = ''; replyTo = null;
                    });
                  },
                  child: Container(width: 44, height: 44, decoration: BoxDecoration(color: c.teal, shape: BoxShape.circle), child: const Icon(Icons.send, color: Colors.white, size: 18)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _insertReply(List<CComment> list, int id, CComment nc) {
    for (final x in list) {
      if (x.id == id) { x.replies.add(nc); return; }
      _insertReply(x.replies, id, nc);
    }
  }

  Widget _commentTile(AppColors c, Post post, CComment cm, int depth) {
    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : 12, top: 12),
      child: Container(
        decoration: depth == 0 ? null : BoxDecoration(border: Border(left: BorderSide(color: c.dustSoft, width: 2))),
        padding: EdgeInsets.only(left: depth == 0 ? 0 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [CircleAvatar(radius: 12, child: Text(cm.author[0].toUpperCase(), style: const TextStyle(fontSize: 10))), const SizedBox(width: 6), Text('u/${cm.author}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), Text(' · ${cm.time}', style: TextStyle(fontSize: 12, color: c.tealInk.withValues(alpha: 0.5)))]),
            const SizedBox(height: 4),
            Text(cm.text, style: const TextStyle(fontSize: 14)),
            Row(children: [_votes(c, cm.score, cm.vote, (v) => setState(() => cm.vote = cm.vote == v ? 0 : v)), TextButton(onPressed: () => setState(() => replyTo = cm), child: const Text('Reply', style: TextStyle(fontSize: 12)))]),
            for (final r in cm.replies) _commentTile(c, post, r, depth + 1),
          ],
        ),
      ),
    );
  }

  Widget _composer(AppColors c) {
    String title = '';
    String bdy = '';
    String fl = 'Study';
    return StatefulBuilder(builder: (ctx, setS) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: c.cream2, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(onTap: () => setState(() => composing = false), child: Container(width: 36, height: 36, decoration: BoxDecoration(color: c.dustSoft, shape: BoxShape.circle), child: const Icon(Icons.close, size: 18))),
                Text('Create post', style: display(c, size: 18)),
                GestureDetector(
                  onTap: title.trim().isEmpty ? null : () {
                    setState(() {
                      posts.insert(0, Post(id: DateTime.now().millisecondsSinceEpoch, author: 'ayaan.w', flair: fl, title: title.trim(), body: bdy.trim(), time: 'now', age: 0, score: 1));
                      composing = false; sort = 'New'; flair = 'All';
                    });
                  },
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: c.teal, borderRadius: BorderRadius.circular(20)), child: const Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final f in _flairs.skip(1))
                  GestureDetector(onTap: () => setS(() => fl = f), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: fl == f ? _flairColor(f, c) : c.dustSoft, borderRadius: BorderRadius.circular(16)), child: Text(f, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fl == f ? Colors.white : c.tealInk)))),
              ],
            ),
            TextField(onChanged: (v) { title = v; setS(() {}); }, decoration: const InputDecoration(hintText: 'An interesting title', border: InputBorder.none), style: display(c, size: 20)),
            TextField(onChanged: (v) => bdy = v, maxLines: 4, decoration: InputDecoration(hintText: 'Say more (optional)', filled: true, fillColor: c.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
          ],
        ),
      );
    });
  }
}
