import 'package:flutter/material.dart';
import '../data/seed.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';

class GroupsScreen extends StatefulWidget {
  final ValueChanged<GroupInfo> onChat;
  const GroupsScreen({super.key, required this.onChat});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final Set<String> joined = {for (final g in groupList.where((g) => g.joined)) g.name};
  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return UHead(
      height: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Groups', style: display(c, size: 28, color: Colors.white)),
          Text('Study circles, clubs and class chats', style: body(c, size: 14, color: Colors.white.withValues(alpha: 0.78))),
          const SizedBox(height: 16),
          for (final g in groupList)
            Builder(builder: (_) {
              final on = joined.contains(g.name);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(24)),
                child: Row(
                  children: [
                    Container(width: 56, height: 56, decoration: BoxDecoration(color: toneBg(g.tone, c), borderRadius: BorderRadius.circular(16)), child: Center(child: Text(g.name[0], style: display(c, size: 20, color: g.tone == CourseTone.board ? c.tealInk : Colors.white)))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: on ? () => widget.onChat(g) : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g.name, style: body(c, size: 15, weight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                            Text(on ? g.last : g.meta, style: body(c, size: 12, color: c.tealInk.withValues(alpha: 0.55)), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                    if (on && g.unread > 0) Container(width: 24, height: 24, decoration: BoxDecoration(color: c.clay, shape: BoxShape.circle), child: Center(child: Text('${g.unread}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => on ? widget.onChat(g) : setState(() => joined.add(g.name)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: on ? c.dustSoft : c.tealInk, borderRadius: BorderRadius.circular(20)),
                        child: Text(on ? 'Chat' : 'Join', style: TextStyle(fontWeight: FontWeight.bold, color: on ? c.tealInk : c.cream)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class ChatMsg {
  final int id;
  final String from;
  final String text;
  final String time;
  final String? reply;
  final String? file;
  final ChatPoll? poll;
  String? react;
  ChatMsg({required this.id, required this.from, required this.text, required this.time, this.reply, this.file, this.poll, this.react});
}

class ChatPoll {
  final String q;
  final List<String> opts;
  final List<int> votes;
  int? voted;
  ChatPoll({required this.q, required this.opts, required this.votes, this.voted});
}

class GroupChatScreen extends StatefulWidget {
  final GroupInfo group;
  final VoidCallback back;
  const GroupChatScreen({super.key, required this.group, required this.back});
  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  late List<ChatMsg> msgs;
  String text = '';
  ChatMsg? replyTo;
  int? picker;
  bool attach = false;
  String? typing;
  int uid = 50;
  final ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    msgs = [
      ChatMsg(id: 1, from: 'Sara M.', text: 'Welcome to ${widget.group.name}! Pinned the plan for this week.', time: '08:12'),
      ChatMsg(id: 2, from: 'Omar K.', text: 'Uploaded my graph notes here', time: '08:20', file: 'Graphs_BFS_DFS.pdf · 2.4 MB'),
      ChatMsg(id: 3, from: 'Hana I.', text: 'Which time works for Thursday?', time: '08:31', poll: ChatPoll(q: 'Thursday session', opts: const ['5:00 pm', '6:00 pm', '7:30 pm'], votes: [4, 7, 2])),
      ChatMsg(id: 4, from: 'You', text: '6pm works for me, lab ends at 5:40', time: '08:34', reply: 'Hana I.: Which time works for Thursday?', react: 'like'),
      ChatMsg(id: 5, from: 'Leo B.', text: 'Bringing snacks, someone bring a marker for the whiteboard', time: '08:40'),
    ];
  }

  void send({String? file, ChatPoll? poll}) {
    if (text.trim().isEmpty && file == null && poll == null) return;
    final now = TimeOfDay.now();
    final t = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    setState(() {
      msgs.add(ChatMsg(id: uid++, from: 'You', text: text.trim(), time: t, reply: replyTo != null ? '${replyTo!.from}: ${replyTo!.text.isEmpty ? replyTo!.file ?? '' : replyTo!.text}' : null, file: file, poll: poll));
      text = ''; ctrl.clear(); replyTo = null; attach = false;
    });
    final who = ['Sara M.', 'Omar K.', 'Hana I.', 'Leo B.'][uid % 4];
    Future.delayed(const Duration(milliseconds: 700), () => mounted ? setState(() => typing = who) : null);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() {
        typing = null;
        msgs.add(ChatMsg(id: uid++, from: who, text: ['Sounds good!', 'On my way to the library now', 'Can someone share the slides?', 'Haha same', 'Count me in!'][uid % 5], time: t));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 48, 12, 12),
          decoration: BoxDecoration(color: c.cream2, border: Border(bottom: BorderSide(color: c.dustSoft))),
          child: Row(
            children: [
              GestureDetector(onTap: widget.back, child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.arrow_back))),
              Container(width: 40, height: 40, decoration: BoxDecoration(color: toneBg(widget.group.tone, c), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(widget.group.name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)))),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.group.name, style: display(c, size: 15), overflow: TextOverflow.ellipsis), Text(typing != null ? '$typing is typing…' : '5 online', style: TextStyle(fontSize: 12, color: typing != null ? c.teal : c.tealInk.withValues(alpha: 0.55)))])),
              const Icon(Icons.phone_outlined), const SizedBox(width: 12), const Icon(Icons.videocam_outlined),
            ],
          ),
        ),
        Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: c.board.withValues(alpha: 0.25),
          child: const Row(children: [Icon(Icons.push_pin_outlined, size: 14), SizedBox(width: 6), Expanded(child: Text('Pinned: Thu · Library room 3 — trees, heaps, graphs', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))]),
        ),
        Expanded(
          child: Container(
            color: c.cream,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
              itemCount: msgs.length + (typing != null ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (typing != null && i == msgs.length) {
                  return const Row(children: [Text('typing… ')]);
                }
                final m = msgs[i];
                final mine = m.from == 'You';
                final first = i == 0 || msgs[i - 1].from != m.from;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!mine && first) CircleAvatar(radius: 14, backgroundColor: c.teal, child: Text(m.from[0], style: const TextStyle(fontSize: 11, color: Colors.white))),
                      if (!mine && !first) const SizedBox(width: 28),
                      const SizedBox(width: 6),
                      Flexible(
                        child: GestureDetector(
                          onTap: () => setState(() => picker = picker == m.id ? null : m.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(color: mine ? c.teal : c.white, borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(mine ? 16 : 4), bottomRight: Radius.circular(mine ? 4 : 16))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!mine && first) Text(m.from, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.teal)),
                                if (m.reply != null) Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: mine ? Colors.white.withValues(alpha: 0.15) : c.dustSoft.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: mine ? c.board : c.teal, width: 4))), child: Text(m.reply!, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                if (m.file != null) Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: mine ? Colors.white.withValues(alpha: 0.15) : c.dustSoft.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)), child: Row(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: c.clay, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.description_outlined, color: Colors.white, size: 17)), const SizedBox(width: 8), Expanded(child: Text(m.file!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))])),
                                if (m.poll != null)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [const Icon(Icons.bar_chart_outlined, size: 15), Text(' ${m.poll!.q}', style: const TextStyle(fontWeight: FontWeight.bold))]),
                                      const SizedBox(height: 8),
                                      for (int k = 0; k < m.poll!.opts.length; k++)
                                        Builder(builder: (_) {
                                          final total = m.poll!.votes.fold(0, (a, b) => a + b);
                                          final sel = m.poll!.voted == k;
                                          return GestureDetector(
                                            onTap: () => setState(() {
                                              final p = m.poll!;
                                              if (p.voted == k) { p.votes[k]--; p.voted = null; } else { if (p.voted != null) p.votes[p.voted!]--; p.votes[k]++; p.voted = k; }
                                            }),
                                            child: Container(
                                              margin: const EdgeInsets.only(bottom: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(border: Border.all(color: sel ? c.teal : c.dustSoft, width: 2), borderRadius: BorderRadius.circular(8)),
                                              child: Stack(
                                                children: [
                                                  Positioned.fill(child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: m.poll!.votes[k] / (total == 0 ? 1 : total), child: Container(color: c.board.withValues(alpha: 0.4)))),
                                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(m.poll!.opts[k], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)), Text('${m.poll!.votes[k]}', style: const TextStyle(fontSize: 12))]),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                    ],
                                  ),
                                if (m.text.isNotEmpty) Text(m.text, style: TextStyle(color: mine ? Colors.white : c.tealInk)),
                                Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text(m.time, style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : c.tealInk.withValues(alpha: 0.45))), if (mine) const Icon(Icons.done_all, size: 13, color: Colors.white70)]),
                                if (picker == m.id)
                                  Row(
                                    children: [
                                      for (final r in ['👍', '❤️', '😂', '🔥', '🎉'])
                                        GestureDetector(onTap: () => setState(() { m.react = r; picker = null; }), child: Padding(padding: const EdgeInsets.all(4), child: Text(r, style: const TextStyle(fontSize: 18)))),
                                      GestureDetector(onTap: () => setState(() { replyTo = m; picker = null; }), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: c.tealInk, shape: BoxShape.circle), child: const Icon(Icons.reply, size: 15, color: Colors.white))),
                                    ],
                                  ),
                                if (m.react != null) Text(m.react!, style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.cream2, border: Border(top: BorderSide(color: c.dustSoft))),
          child: Column(
            children: [
              if (replyTo != null)
                Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: c.teal, width: 4))), child: Row(children: [Expanded(child: Text('${replyTo!.from} · ${replyTo!.text.isEmpty ? replyTo!.file ?? '' : replyTo!.text}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)), GestureDetector(onTap: () => setState(() => replyTo = null), child: const Icon(Icons.close, size: 16))])),
              if (attach)
                Row(
                  children: [
                    for (final a in [['File', Icons.description_outlined, 0], ['Photo', Icons.camera_alt_outlined, 1], ['Poll', Icons.bar_chart_outlined, 2], ['Location', Icons.location_on_outlined, 3]])
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (a[0] == 'File') send(file: 'Lecture_07_Heaps.pdf · 1.1 MB');
                            else if (a[0] == 'Photo') send(file: 'IMG_2026_whiteboard.jpg · 840 KB');
                            else if (a[0] == 'Poll') send(poll: ChatPoll(q: 'Meet online or in person?', opts: const ['Library', 'Zoom'], votes: [0, 0]));
                            else setState(() { text = 'Meet at: Library · Room 3'; ctrl.text = text; attach = false; });
                          },
                          child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(16)), child: Column(children: [Icon(a[1] as IconData, size: 17), Text(a[0] as String, style: const TextStyle(fontSize: 11))])),
                        ),
                      ),
                  ],
                ),
              Row(
                children: [
                  GestureDetector(onTap: () => setState(() => attach = !attach), child: Container(width: 40, height: 40, decoration: BoxDecoration(color: attach ? c.tealInk : c.dustSoft, shape: BoxShape.circle), child: Icon(Icons.add, color: attach ? c.cream : c.tealInk))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(24)),
                      child: TextField(controller: ctrl, onChanged: (v) => text = v, decoration: const InputDecoration(hintText: 'Message the group…', border: InputBorder.none)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: text.trim().isEmpty ? null : () => send(),
                    child: Opacity(
                      opacity: text.trim().isEmpty ? 0.4 : 1,
                      child: Container(width: 44, height: 44, decoration: BoxDecoration(color: c.teal, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.clay, offset: const Offset(0, 4))]), child: const Icon(Icons.send, color: Colors.white, size: 18)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
