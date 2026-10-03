import 'package:flutter/material.dart';

import '../auth/odoo_api.dart';
import '../auth/portal_api.dart';
import '../auth/student_portal.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/portal_state.dart';

/// Semester results + PLO attainment, parsed live from `/student/results`.
class ResultsScreen extends StatefulWidget {
  final String? sessionId;
  final VoidCallback? onSessionExpired;
  /// Test seam: canned page HTML (skips all network).
  final String? debugHtml;
  const ResultsScreen(
      {super.key, this.sessionId, this.onSessionExpired, this.debugHtml});
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  ResultsData? data;
  bool loading = true;
  bool expired = false;
  String? error;
  int termIdx = 0;
  bool showPlos = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String> _fetch() {
    if (widget.debugHtml != null) return Future.value(widget.debugHtml);
    final sid = widget.sessionId;
    if (sid == null || sid.isEmpty) {
      return Future.error(OdooApiException('no portal session'));
    }
    return PortalApi().fetchPage(PortalRoutes.results, sid);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
      expired = false;
    });
    try {
      final html = await _fetch();
      if (!mounted) return;
      final parsed = parseResults(html);
      setState(() {
        data = parsed;
        loading = false;
        termIdx = 0;
      });
    } on OdooApiException catch (e) {
      if (!mounted) return;
      final dead = e.message.contains('expired') ||
          e.message.contains('login') ||
          e.message.contains('no portal session');
      setState(() {
        loading = false;
        expired = dead;
        error = dead ? null : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Could not load results. Check connection.';
      });
    }
  }

  Color _gradeTone(String grade, AppColors c) {
    if (grade.startsWith('A')) return c.teal;
    if (grade.startsWith('B')) return c.board;
    if (grade.startsWith('C')) return c.clay;
    return c.tealInk;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    if (loading) {
      return const PortalLoading(
          title: 'Results', subtitle: 'Loading your results…');
    }
    if (error != null || expired) {
      return PortalError(
        title: 'Results',
        message: expired
            ? 'Your portal session expired — sign in again to reload results.'
            : error!,
        onRetry: _load,
        onRelogin: expired ? widget.onSessionExpired : null,
      );
    }
    final terms = data!.terms;
    if (terms.isEmpty) {
      return UHead(
        height: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Results',
                style: display(c, size: 28, color: Colors.white)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: c.white,
                  borderRadius: BorderRadius.circular(24)),
              child: Text('No results published yet.',
                  textAlign: TextAlign.center,
                  style: body(c,
                      size: 14,
                      color: c.tealInk.withValues(alpha: 0.55))),
            ),
          ],
        ),
      );
    }
    final term = terms[termIdx.clamp(0, terms.length - 1)];
    return UHead(
      height: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Results',
              style: display(c, size: 28, color: Colors.white)),
          Text('Semester grades and PLO attainment',
              style: body(c,
                  size: 14, color: Colors.white.withValues(alpha: 0.78))),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < terms.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => termIdx = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                            color: termIdx == i
                                ? c.white
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(terms[i].term,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: termIdx == i
                                    ? c.tealInk
                                    : Colors.white)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: c.tealInk,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: c.clay, offset: const Offset(0, 6))
                ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(term.term.toUpperCase(),
                    style: TextStyle(
                        fontSize: 12, color: c.cream.withValues(alpha: 0.7))),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SGPA',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: c.cream.withValues(alpha: 0.7))),
                          Text(term.sgpa,
                              style: display(c, size: 36, color: c.cream)),
                        ]),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('CGPA',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: c.cream.withValues(alpha: 0.7))),
                          Text(term.cgpa,
                              style: display(c, size: 28, color: c.board)),
                        ]),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                    'Attempted ${term.attempted} · Earned ${term.earned} credit hours',
                    style: TextStyle(
                        fontSize: 12,
                        color: c.cream.withValues(alpha: 0.75))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Courses', style: display(c, size: 20)),
          const SizedBox(height: 12),
          for (final course in term.courses)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: c.white,
                  borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          color: _gradeTone(course.grade, c),
                          borderRadius: BorderRadius.circular(14)),
                      child: Center(
                          child: Text(course.grade,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(course.name,
                              style: body(c,
                                  size: 14, weight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                          Text(
                              '${course.credits} cr · ${course.gradePts} grade pts',
                              style: body(c,
                                  size: 12,
                                  color: c.tealInk
                                      .withValues(alpha: 0.55))),
                        ]),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => showPlos = !showPlos),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('PLO attainment', style: display(c, size: 20)),
                Icon(
                    showPlos
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: c.tealInk.withValues(alpha: 0.5)),
              ],
            ),
          ),
          if (showPlos) ...[
            const SizedBox(height: 12),
            if (data!.plos.isEmpty)
              Text('No PLO data published.',
                  style: body(c,
                      size: 14,
                      color: c.tealInk.withValues(alpha: 0.55))),
            for (final p in data!.plos)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: c.white,
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(p.code,
                            style: body(c,
                                size: 14, weight: FontWeight.bold)),
                        Text(p.attainment,
                            style: body(c,
                                size: 13,
                                weight: FontWeight.bold,
                                color: c.teal)),
                      ],
                    ),
                    Text(p.description,
                        style: body(c,
                            size: 12,
                            color:
                                c.tealInk.withValues(alpha: 0.55))),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (double.tryParse(p.attainment
                                        .replaceAll('%', '')) ??
                                    0)
                                .clamp(0.0, 100.0) /
                            100.0,
                        backgroundColor: c.dustSoft,
                        valueColor: AlwaysStoppedAnimation(c.teal),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}
