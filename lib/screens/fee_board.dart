import 'package:flutter/material.dart';
import '../data/seed.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';

class FeeChallanScreen extends StatefulWidget {
  const FeeChallanScreen({super.key});
  @override
  State<FeeChallanScreen> createState() => _FeeChallanScreenState();
}

class _FeeChallanScreenState extends State<FeeChallanScreen> {
  bool paid = false;
  String method = 'wallet';
  bool paying = false;
  bool open = true;
  void pay() {
    setState(() => paying = true);
    Future.delayed(const Duration(milliseconds: 1400), () => mounted ? setState(() { paying = false; paid = true; }) : null);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final amt = challanTotal(currentChallan);
    final allHistory = [...(paid ? [Challan(id: currentChallan.id, term: currentChallan.term, due: currentChallan.due, items: currentChallan.items, paid: 'Today')] : []), ...challanHistory];
    return UHead(
      height: 144,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fee challan', style: display(c, size: 28, color: Colors.white)),
          Text('Check dues, pay and download receipts', style: body(c, size: 14, color: Colors.white.withValues(alpha: 0.78))),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(24)),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: paid ? c.teal : c.tealInk, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(currentChallan.term.toUpperCase(), style: TextStyle(fontSize: 12, color: c.cream.withValues(alpha: 0.7)))),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: paid ? Colors.white : c.clay, borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(paid ? Icons.check_circle : Icons.warning_amber_outlined, size: 13, color: paid ? c.teal : Colors.white), Text(paid ? ' Paid' : ' Unpaid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: paid ? c.teal : Colors.white))])),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(rs(amt), style: display(c, size: 36, color: c.cream)),
                      Text(paid ? 'Paid today · thank you!' : 'Due ${currentChallan.due} · 15 days left', style: TextStyle(color: c.cream.withValues(alpha: 0.8))),
                      if (!paid) ...[
                        const SizedBox(height: 12),
                        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: 0.5, backgroundColor: Colors.white.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation(c.board), minHeight: 6)),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.dustSoft, style: BorderStyle.solid))),
                  child: Row(children: [Text('Challan #  ', style: body(c, size: 12, color: c.tealInk.withValues(alpha: 0.55))), Expanded(child: Text(currentChallan.id, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 13))), Text('Copy', style: body(c, size: 13, weight: FontWeight.bold, color: c.teal))]),
                ),
                GestureDetector(
                  onTap: () => setState(() => open = !open),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Fee breakdown', style: TextStyle(fontWeight: FontWeight.bold)), Icon(open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down)])),
                ),
                if (open)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      children: [
                        for (final it in currentChallan.items)
                          Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(it.key, style: TextStyle(color: c.tealInk.withValues(alpha: 0.65))), Text(it.value < 0 ? '− ${rs(-it.value)}' : rs(it.value), style: TextStyle(fontWeight: FontWeight.w600, color: it.value < 0 ? c.teal : c.tealInk))])),
                        Container(padding: const EdgeInsets.only(top: 8), decoration: BoxDecoration(border: Border(top: BorderSide(color: c.dustSoft))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Payable', style: TextStyle(fontWeight: FontWeight.bold)), Text(rs(amt), style: const TextStyle(fontWeight: FontWeight.bold))])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!paid) ...[
            const SizedBox(height: 20),
            Text('Pay with', style: display(c, size: 20)),
            const SizedBox(height: 12),
            for (final m in [['bank', 'Bank branch', 'HBL, MCB, Meezan', Icons.account_balance_outlined], ['wallet', 'JazzCash / Easypaisa', 'Pay with mobile wallet', Icons.smartphone_outlined], ['card', 'Debit / credit card', 'Visa, Mastercard', Icons.credit_card_outlined]])
              GestureDetector(
                onTap: () => setState(() => method = m[0] as String),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: c.white, border: Border.all(color: method == m[0] ? c.teal : Colors.transparent, width: 2), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Container(width: 44, height: 44, decoration: BoxDecoration(color: method == m[0] ? c.teal : c.dustSoft, borderRadius: BorderRadius.circular(12)), child: Icon(m[3] as IconData, color: method == m[0] ? Colors.white : c.tealInk)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m[1] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(m[2] as String, style: TextStyle(fontSize: 12, color: c.tealInk.withValues(alpha: 0.55)))])),
                      Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: method == m[0] ? c.teal : c.dustSoft, width: 2), color: method == m[0] ? c.teal : null), child: method == m[0] ? const Center(child: SizedBox(width: 8, height: 8, child: DecoratedBox(decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle)))) : null),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(width: 56, height: 56, decoration: BoxDecoration(color: c.dustSoft, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.download_outlined)),
                const SizedBox(width: 8),
                Expanded(child: ClayButton(label: paying ? 'Processing…' : method == 'bank' ? 'Generate bank voucher' : 'Pay ${rs(amt)}', colors: c, onPressed: paying ? null : pay)),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text('History', style: display(c, size: 20)),
          const SizedBox(height: 12),
          for (final ch in allHistory)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Container(width: 44, height: 44, decoration: BoxDecoration(color: c.board.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.receipt_outlined, size: 19)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(ch.term, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis), Text('Paid ${ch.paid}', style: TextStyle(fontSize: 12, color: (ch.paid ?? '').contains('late') ? c.clay : c.tealInk.withValues(alpha: 0.55)))])),
                  Text(rs(challanTotal(ch)), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: c.dustSoft, shape: BoxShape.circle), child: const Icon(Icons.download_outlined, size: 16)),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class LeaderboardScreen extends StatefulWidget {
  final String start;
  final VoidCallback back;
  const LeaderboardScreen({super.key, required this.start, required this.back});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late String code;
  String metric = 'Overall';
  @override
  void initState() {
    super.initState();
    code = widget.start;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final hero = AppScope.paletteOf(context).heroAsset;
    final list = board(code, metric);
    final myRank = list.indexWhere((e) => e.me) + 1;
    final podium = [list[1], list[0], list[2]];
    final sub = courses.firstWhere((x) => x.code == code);
    return UHead(
      height: 304,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(onTap: widget.back, child: Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.arrow_back, color: Colors.white))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Leaderboard', style: display(c, size: 22, color: Colors.white)), Text('$code · ${sub.title}', style: body(c, size: 13, color: Colors.white.withValues(alpha: 0.78),)) ])),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final x in courses)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => code = x.code),
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: code == x.code ? Colors.white : Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)), child: Text(x.code, style: TextStyle(fontWeight: FontWeight.bold, color: code == x.code ? c.tealInk : Colors.white))),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < 3; i++)
                Builder(builder: (_) {
                  final e = podium[i];
                  final rank = i == 1 ? 1 : i == 0 ? 2 : 3;
                  return Expanded(
                    child: Column(
                      children: [
                        if (rank == 1) const Icon(Icons.workspace_premium, color: Colors.amber, size: 22),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: rank == 1 ? c.board : Colors.white70, width: 4)),
                          child: e.me
                              ? CircleAvatar(radius: rank == 1 ? 32 : 24, backgroundImage: AssetImage(hero))
                              : CircleAvatar(radius: rank == 1 ? 32 : 24, backgroundColor: [c.teal, c.clay, c.tealDeep, c.dust, c.board][e.name.length % 5], child: Text(e.name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        ),
                        Text(e.me ? 'You' : e.name.split(' ')[0], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          height: rank == 1 ? 80 : rank == 2 ? 56 : 40,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                          child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${e.score}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)), Text('#$rank', style: const TextStyle(color: Colors.white70, fontSize: 10))])),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: c.dustSoft, borderRadius: BorderRadius.circular(30)),
            child: Row(
              children: [
                for (final m in ['Overall', 'Quizzes', 'Assignments', 'Attendance'])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => metric = m),
                      child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: metric == m ? c.tealInk : Colors.transparent, borderRadius: BorderRadius.circular(20)), child: Center(child: Text(m, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: metric == m ? c.cream : c.tealInk.withValues(alpha: 0.6))))),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: c.tealInk, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: c.clay, offset: const Offset(0, 6))]),
            child: Row(
              children: [
                Icon(Icons.emoji_events_outlined, size: 26, color: c.board),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Your rank in $code', style: TextStyle(fontSize: 12, color: c.cream.withValues(alpha: 0.7))), Text('#$myRank of ${list.length}', style: display(c, size: 22, color: c.cream))])),
                Text(myRank > 1 ? '${list[myRank - 2].score - list[myRank - 1].score + 1} pts to\npass #${myRank - 1}' : 'Top of class!', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: c.cream.withValues(alpha: 0.8))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 3; i < list.length; i++)
            Builder(builder: (_) {
              final e = list[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: e.me ? c.teal : c.white, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    SizedBox(width: 24, child: Text('${i + 1}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: e.me ? Colors.white70 : c.tealInk.withValues(alpha: 0.7)))),
                    e.me
                        ? CircleAvatar(radius: 20, backgroundImage: AssetImage(hero))
                        : CircleAvatar(backgroundColor: [c.teal, c.clay, c.tealDeep, c.dust, c.board][e.name.length % 5], child: Text(e.name[0], style: const TextStyle(color: Colors.white))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e.me ? 'You' : e.name, style: TextStyle(fontWeight: FontWeight.w600, color: e.me ? Colors.white : c.tealInk)), Text('🔥 ${e.streak}-day streak', style: TextStyle(fontSize: 12, color: e.me ? Colors.white70 : c.tealInk.withValues(alpha: 0.55)))])),
                    Text(e.move > 0 ? '▲${e.move.abs()}' : e.move < 0 ? '▼${e.move.abs()}' : '–', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: e.move > 0 ? (e.me ? c.board : c.teal) : e.move < 0 ? c.clay : c.tealInk.withValues(alpha: 0.4))),
                    const SizedBox(width: 8),
                    Text('${e.score}', style: display(c, size: 18, color: e.me ? Colors.white : c.tealInk)),
                  ],
                ),
              );
            }),
          Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Updated weekly by ${sub.prof}', style: body(c, size: 12, color: c.tealInk.withValues(alpha: 0.5))))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
