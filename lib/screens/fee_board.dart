import 'dart:async';

import 'package:flutter/material.dart';
import '../auth/odoo_api.dart';
import '../auth/offline.dart';
import '../auth/page_cache.dart';
import '../auth/portal_api.dart';
import '../auth/portal_cache.dart';
import '../auth/student_portal.dart';
import '../data/seed.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/portal_state.dart';


class FeeChallanScreen extends StatefulWidget {
  final String? sessionId;
  final VoidCallback? onSessionExpired;
  /// Test seam: canned page HTML (skips all network).
  final String? debugHtml;
  const FeeChallanScreen(
      {super.key, this.sessionId, this.onSessionExpired, this.debugHtml});
  @override
  State<FeeChallanScreen> createState() => _FeeChallanScreenState();
}

class _FeeChallanScreenState extends State<FeeChallanScreen> {
  List<Invoice>? invoices;
  bool loading = true;
  bool expired = false;
  String? error;
  bool cachedOffline = false;
  int? cachedAt;
  bool refreshFailed = false;

  @override
  void initState() {
    super.initState();
    OfflineMonitor.instance.offline.addListener(_onConnectivity);
    _load();
  }

  @override
  void dispose() {
    OfflineMonitor.instance.offline.removeListener(_onConnectivity);
    super.dispose();
  }

  /// Auto-retry the moment the device is back online.
  void _onConnectivity() {
    if (!OfflineMonitor.instance.isOffline &&
        mounted &&
        !loading &&
        error != null &&
        invoices == null) {
      _load();
    }
  }

  Future<String> _fetch() {
    if (widget.debugHtml != null) return Future.value(widget.debugHtml);
    final sid = widget.sessionId;
    if (sid == null || sid.isEmpty) {
      return Future.error(OdooApiException('no portal session'));
    }
    return PortalApi().fetchPage(PortalRoutes.invoices, sid);
  }

  Future<void> _load() async {
    if (!mounted) return;
    // Instant paint: memory first, then the on-disk snapshot. Only a first
    // paint with nothing saved shows the skeleton / error states below.
    if (invoices == null && widget.debugHtml == null) {
      final mem = PortalCache.invoices;
      if (mem != null) {
        setState(() {
          invoices = mem;
          cachedOffline = true;
          cachedAt = PortalCache.savedAt['invoices'];
        });
      } else {
        final snap = await PageCache.loadPage('invoices');
        if (!mounted) return;
        if (snap != null) {
          try {
            final parsed = parseInvoices(snap.html);
            PortalCache.putInvoices(parsed);
            setState(() {
              invoices = parsed;
              cachedOffline = true;
              cachedAt = snap.savedAtMs;
            });
          } catch (_) {}
        }
      }
    }
    // Offline: stop here — error only when nothing is on screen.
    if (widget.debugHtml == null && OfflineMonitor.instance.isOffline) {
      if (!mounted) return;
      setState(() {
        loading = false;
        if (invoices == null) error = offlineMessage;
      });
      return;
    }
    // Refresh. Silent when data is already visible: just the top line bar.
    setState(() {
      loading = true;
      refreshFailed = false;
      if (invoices == null) {
        error = null;
        expired = false;
        cachedOffline = false;
        cachedAt = null;
      }
    });
    try {
      final html = await _fetch();
      if (!mounted) return;
      final parsed = parseInvoices(html);
      PortalCache.putInvoices(parsed);
      unawaited(PageCache.savePage('invoices', html));
      setState(() {
        invoices = parsed;
        loading = false;
        cachedOffline = false;
        cachedAt = null;
      });
    } on OdooApiException catch (e) {
      if (!mounted) return;
      final dead = e.message.contains('expired') ||
          e.message.contains('login') ||
          e.message.contains('no portal session');
      setState(() {
        loading = false;
        if (dead) {
          expired = true;
        } else if (invoices == null) {
          error = e.message;
        } else {
          refreshFailed = true;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        if (invoices == null) {
          error = 'Could not load invoices. Check connection.';
        } else {
          refreshFailed = true;
        }
      });
    }
  }


  static double _amount(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  static String _rs(double n) {
    final whole = n.round() == n;
    final digits = whole ? n.toInt().toString() : n.toStringAsFixed(2);
    final buf = StringBuffer();
    final chars = digits.split('').reversed.toList();
    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) buf.write(',');
      buf.write(chars[i]);
    }
    return 'Rs ${buf.toString().split('').reversed.join()}';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    if (loading && invoices == null) {
      return const PortalLoading(
          title: 'Fee challan', subtitle: 'Loading your invoices…');
    }
    if (expired || (error != null && invoices == null)) {
      return PortalError(
        title: 'Fee challan',
        message: expired
            ? 'Your portal session expired — sign in again to reload invoices.'
            : error!,
        onRetry: _load,
        onRelogin: expired ? widget.onSessionExpired : null,
      );
    }
    final list = invoices!;
    final due = list.where((i) => !i.isPaid).toList();
    final dueTotal = due.fold<double>(0, (s, i) => s + _amount(i.amount));
    final allPaid = list.isNotEmpty && due.isEmpty;
    return UHead(
      height: 144,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading) ...[
            const PortalLoadingBar(),
            const SizedBox(height: 12),
          ],
          if (refreshFailed) PortalRefreshFailed(onRetry: _load),
          Text('Fee challan',
              style: display(c, size: 28, color: Colors.white)),
          Text(
              list.isEmpty
                  ? 'No invoices published'
                  : allPaid
                      ? 'All clear · ${list.length} paid'
                      : '${due.length} unpaid · ${_rs(dueTotal)} due',
              style: body(c,
                  size: 14, color: Colors.white.withValues(alpha: 0.78))),
          const SizedBox(height: 20),
          if (cachedOffline && cachedAt != null)
            PortalCachedNotice(savedAtMs: cachedAt!),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: allPaid ? c.teal : c.tealInk,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('FEE STATUS',
                        style: TextStyle(
                            fontSize: 12,
                            color: c.cream.withValues(alpha: 0.7))),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: allPaid ? Colors.white : c.clay,
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Icon(
                            allPaid
                                ? Icons.check_circle
                                : Icons.warning_amber_outlined,
                            size: 13,
                            color: allPaid ? c.teal : Colors.white),
                        Text(allPaid ? ' Paid' : ' Dues pending',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: allPaid ? c.teal : Colors.white)),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                    list.isEmpty
                        ? 'No invoices yet'
                        : allPaid
                            ? '${list.length} challans paid'
                            : _rs(dueTotal),
                    style: display(c, size: 32, color: c.cream)),
                Text(
                    list.isEmpty
                        ? 'Published challans will appear here.'
                        : allPaid
                            ? 'Thank you — nothing outstanding.'
                            : 'Pay before the earliest due date below.',
                    style: TextStyle(
                        fontSize: 14,
                        color: c.cream.withValues(alpha: 0.8))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Invoices', style: display(c, size: 20)),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: c.white,
                  borderRadius: BorderRadius.circular(24)),
              child: Text('No challans published for your account.',
                  textAlign: TextAlign.center,
                  style: body(c,
                      size: 14,
                      color: c.tealInk.withValues(alpha: 0.55))),
            ),
          for (final inv in list)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: c.white,
                  borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${inv.term} · ${inv.type}',
                                style: body(c,
                                    size: 14, weight: FontWeight.w700)),
                            Text('Challan ${inv.challanId}',
                                style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: c.tealInk
                                        .withValues(alpha: 0.55))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: inv.isPaid ? c.teal : c.clay,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(inv.status,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Payable',
                                style: body(c,
                                    size: 11,
                                    color: c.tealInk
                                        .withValues(alpha: 0.55))),
                            Text(_rs(_amount(inv.amount)),
                                style: display(c, size: 20)),
                          ]),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                                inv.isPaid
                                    ? 'Paid ${inv.paidDate}'
                                    : 'Due ${inv.due}',
                                style: body(c,
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color: inv.isPaid
                                        ? c.tealInk.withValues(alpha: 0.6)
                                        : c.clay)),
                            if (inv.scholarship.isNotEmpty &&
                                inv.scholarship != '0' &&
                                inv.scholarship != '0.0')
                              Text('Scholarship ${inv.scholarship}%',
                                  style: body(c,
                                      size: 12, color: c.teal)),
                          ]),
                    ],
                  ),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: c.cream, borderRadius: BorderRadius.circular(24)),
            child: Row(
              children: [
                Icon(Icons.account_balance_outlined,
                    size: 22, color: c.teal),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                      'Download the challan from the Web tab to pay at the bank.',
                      style: body(c, size: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 96),
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
              GestureDetector(onTap: widget.back, child: Container(alignment: Alignment.center, width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.arrow_back, color: Colors.white))),
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
                      behavior: HitTestBehavior.opaque,
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
                      behavior: HitTestBehavior.opaque,
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
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}
