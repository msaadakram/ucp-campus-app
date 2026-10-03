import 'package:flutter/material.dart';

import '../auth/odoo_api.dart';
import '../auth/portal_api.dart';
import '../auth/student_portal.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/portal_state.dart';

/// Per-course attendance with expandable daily records, parsed live from
/// `/student/attendance`.
class AttendanceScreen extends StatefulWidget {
  final String? sessionId;
  final VoidCallback? onSessionExpired;
  /// Test seam: canned page HTML (skips all network).
  final String? debugHtml;
  const AttendanceScreen(
      {super.key, this.sessionId, this.onSessionExpired, this.debugHtml});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<AttendanceCourse>? courses;
  bool loading = true;
  bool expired = false;
  String? error;
  final Set<String> open = {};

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
    return PortalApi().fetchPage(PortalRoutes.attendance, sid);
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
      setState(() {
        courses = parseAttendance(html);
        loading = false;
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
        error = 'Could not load attendance. Check connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    if (loading) {
      return const PortalLoading(
          title: 'Attendance', subtitle: 'Loading your attendance…');
    }
    if (error != null || expired) {
      return PortalError(
        title: 'Attendance',
        message: expired
            ? 'Your portal session expired — sign in again to reload attendance.'
            : error!,
        onRetry: _load,
        onRelogin: expired ? widget.onSessionExpired : null,
      );
    }
    final list = courses!;
    final avg = list.isEmpty
        ? 0.0
        : list.map((e) => e.percent).reduce((a, b) => a + b) / list.length;
    return UHead(
      height: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attendance', style: display(c, size: 28, color: Colors.white)),
          Text('${list.length} courses · overall ${avg.toStringAsFixed(1)}%',
              style: body(c,
                  size: 14, color: Colors.white.withValues(alpha: 0.78))),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: c.tealInk, borderRadius: BorderRadius.circular(24)),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: (avg / 100).clamp(0.0, 1.0),
                          strokeWidth: 8,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.2),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(c.board),
                        ),
                      ),
                      Text('${avg.toStringAsFixed(0)}%',
                          style: display(c, size: 16, color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Overall attendance',
                          style: display(c, size: 18, color: Colors.white)),
                      Text(
                          avg >= 75
                              ? 'Above the 75% requirement. Keep it up.'
                              : 'Below the 75% requirement — catch up soon.',
                          style: body(c,
                              size: 13,
                              color: c.cream.withValues(alpha: 0.8))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: c.white,
                  borderRadius: BorderRadius.circular(24)),
              child: Text('No attendance published yet.',
                  textAlign: TextAlign.center,
                  style: body(c,
                      size: 14,
                      color: c.tealInk.withValues(alpha: 0.55))),
            ),
          for (final course in list)
            Builder(builder: (_) {
              final isOpen = open.contains(course.name);
              final tone = course.percent >= 75
                  ? c.teal
                  : course.percent >= 50
                      ? c.board
                      : c.clay;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: c.white,
                    borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => isOpen
                          ? open.remove(course.name)
                          : open.add(course.name)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 52,
                              height: 52,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: CircularProgressIndicator(
                                      value: (course.percent / 100)
                                          .clamp(0.0, 1.0),
                                      strokeWidth: 6,
                                      backgroundColor: c.dustSoft,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(tone),
                                    ),
                                  ),
                                  Text(
                                      '${course.percent.toStringAsFixed(course.percent == course.percent.roundToDouble() ? 0 : 1)}%',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(course.name,
                                      style: body(c,
                                          size: 15,
                                          weight: FontWeight.w700)),
                                  Text(
                                      '${course.records.length} classes marked',
                                      style: body(c,
                                          size: 12,
                                          color: c.tealInk.withValues(
                                              alpha: 0.55))),
                                ],
                              ),
                            ),
                            Icon(
                                isOpen
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color:
                                    c.tealInk.withValues(alpha: 0.5)),
                          ],
                        ),
                      ),
                    ),
                    if (isOpen)
                      Container(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          children: [
                            if (course.records.isEmpty)
                              Text('No daily records published.',
                                  style: body(c,
                                      size: 13,
                                      color: c.tealInk
                                          .withValues(alpha: 0.55))),
                            for (final r in course.records)
                              Container(
                                margin:
                                    const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                    color: c.cream2,
                                    borderRadius:
                                        BorderRadius.circular(14)),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: r.status == 'Present'
                                            ? c.teal
                                            : r.status == 'Absent'
                                                ? c.clay
                                                : c.board,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(r.status,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(r.date,
                                          style: body(c,
                                              size: 14,
                                              weight: FontWeight.w600)),
                                    ),
                                    if (r.fine != '-' && r.fine.isNotEmpty)
                                      Text('Fine ${r.fine}',
                                          style: body(c,
                                              size: 12,
                                              weight: FontWeight.bold,
                                              color: c.clay)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}
