import 'dart:async';

import 'package:flutter/material.dart';

import '../leaderboard/leaderboard_service.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/portal_state.dart';

/// Live class leaderboard: real ranks from the extension backend
/// (overall-percentage desc), podium top-3, course picker from the
/// scraped timetable, credit meter (1 credit per view), privacy-safe
/// Anonymous rows. Falls back to the caller's demo board when the
/// service is null (ext API key not configured) or fails hard.
class LiveLeaderboardScreen extends StatefulWidget {
  final LeaderboardService? service;
  /// Portal student id — scopes the board to the student's class group
  /// and highlights their row (costs 1 credit per view, backend rule).
  final String? studentId;
  /// Course to preselect by exact or partial title match (optional).
  final String? initialCourse;
  /// Bare course names from the app's own portal timetable — the picker
  /// source when the extension has posted no timetable yet.
  final List<String> fallbackCourses;
  /// The student's portal timetable rows, published to the server on the
  /// first open so app-only users join the class roster.
  final List<Map<String, String>> timetableRows;
  /// Display name of the signed-in student (for grade sync).
  final String? studentName;
  final VoidCallback? back;
  /// Shown when live data is unavailable (no key / hard failure).
  final Widget? fallback;

  const LiveLeaderboardScreen({
    super.key,
    required this.service,
    this.studentId,
    this.studentName,
    this.initialCourse,
    this.fallbackCourses = const [],
    this.timetableRows = const [],
    this.back,
    this.fallback,
  });

  @override
  State<LiveLeaderboardScreen> createState() => _LiveLeaderboardScreenState();
}

class _LiveLeaderboardScreenState extends State<LiveLeaderboardScreen> {
  List<String> courses = [];
  String? course;
  List<LeaderboardEntry> entries = [];
  int? credits;
  bool loading = true;
  bool loadingBoard = false;
  /// True when the course list came from the app's portal timetable
  /// (the extension has not posted one yet) — shown as a small hint.
  bool _fromPortal = false;
  /// Roster verification for the selected course (who shares the section).
  LeaderboardRoster? roster;
  /// True while the app publishes its own timetable to the server.
  bool syncing = false;
  /// Timetable is published once per screen session (no repeat traffic).
  bool _timetableSynced = false;
  String? error;
  bool noCredits = false;

  LeaderboardService? get _svc => widget.service;

  @override
  void initState() {
    super.initState();
    if (_svc == null) {
      loading = false;
      return;
    }
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() {
      loading = true;
      error = null;
      noCredits = false;
    });
    try {
      // App-first: publish our own timetable so the server can build the
      // class roster (app-only users then group with extension users).
      await _syncTimetableOnce();
      var list = await _svc!.fetchCourses(studentId: widget.studentId);
      if (!mounted) return;
      // The extension may not have posted a timetable yet — fall back to
      // the app's own portal timetable so the picker still works.
      var fromPortal = false;
      if (list.isEmpty && widget.fallbackCourses.isNotEmpty) {
        list = List<String>.of(widget.fallbackCourses);
        fromPortal = true;
      }
      if (list.isEmpty) {
        setState(() {
          loading = false;
          error = 'No class data yet — the leaderboard fills once students '
              'open the extension.';
        });
        return;
      }
      // Preselect: exact/substring match on the tapped course title.
      final hint = (widget.initialCourse ?? '').trim().toLowerCase();
      String? pick;
      if (hint.isNotEmpty) {
        pick = list.firstWhere(
          (n) => n.toLowerCase() == hint,
          orElse: () => list.firstWhere(
            (n) => n.toLowerCase().contains(hint),
            orElse: () => list.first,
          ),
        );
      }
      setState(() {
        courses = list;
        loading = false;
        course = pick ?? list.first;
        _fromPortal = fromPortal;
      });
      await _loadBoard();
    } on LeaderboardException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Could not reach the leaderboard. Check connection.';
      });
    }
  }

  /// Publishes the portal timetable to the server (once per session).
  /// Failures are silent — the leaderboard still works without it.
  Future<void> _syncTimetableOnce() async {
    if (_timetableSynced) return;
    final sid = (widget.studentId ?? '').trim();
    if (sid.isEmpty || widget.timetableRows.isEmpty) return;
    _timetableSynced = true;
    if (mounted) setState(() => syncing = true);
    try {
      await _svc!.syncTimetable(
        studentId: sid,
        rows: widget.timetableRows,
      );
    } catch (_) {
      // Sync is best-effort; the board still loads.
    }
    if (mounted) setState(() => syncing = false);
  }

  /// Roster verification for the selected course.
  Future<void> _loadRoster() async {
    final name = course;
    if (_svc == null || name == null) return;
    try {
      final r = await _svc!.fetchRoster(
        courseName: name,
        studentId: (widget.studentId ?? '').trim().isEmpty
            ? null
            : widget.studentId,
      );
      if (!mounted) return;
      setState(() => roster = r);
    } catch (_) {
      // Verification is informational only.
    }
  }

  Future<void> _loadBoard() async {
    final name = course;
    if (_svc == null || name == null) return;
    setState(() {
      loadingBoard = true;
      error = null;
      noCredits = false;
    });
    try {
      final res = await _svc!.fetchLeaderboard(
        courseName: name,
        studentId: widget.studentId,
      );
      if (!mounted) return;
      setState(() {
        entries = res.entries;
        credits = res.remainingCredits;
        loadingBoard = false;
      });
      await _loadRoster();
    } on NoCredits {
      if (!mounted) return;
      setState(() {
        loadingBoard = false;
        noCredits = true;
        entries = const [];
      });
    } on LeaderboardException catch (e) {
      if (!mounted) return;
      setState(() {
        loadingBoard = false;
        error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingBoard = false;
        error = 'Could not load this leaderboard. Tap retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    if (_svc == null && widget.fallback != null) return widget.fallback!;
    return UHead(
      height: 168,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.back != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.back,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, color: Colors.white, size: 16),
                        Text('  Back',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              if (credits != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.toll_outlined,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('$credits credits',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Leaderboard',
              style: display(c, size: 26, color: Colors.white)),
          Text('Live class ranks · overall % · updated by students',
              style: body(c,
                  size: 13, color: Colors.white.withValues(alpha: 0.8))),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            _statusCard(c,
                icon: Icons.cloud_off_outlined,
                text: error!,
                action: 'Retry',
                onAction: course == null ? _loadCourses : _loadBoard)
          else ...[
            _courseBar(c),
            if (_fromPortal) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 13, color: Colors.white70),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Courses from your portal timetable — classmates '
                        'appear once the extension syncs.',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (syncing)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    Text('Syncing your timetable…',
                        style: body(c,
                            size: 11.5, color: Colors.white70)),
                  ],
                ),
              ),
            if (roster != null) _rosterLine(c, roster!),
            if (loadingBoard)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (noCredits)
              _statusCard(c,
                  icon: Icons.toll_outlined,
                  text: "You're out of credits — each leaderboard view "
                      'costs 1 credit. Earn more via referrals.',
                  action: 'Retry',
                  onAction: _loadBoard)
            else if (entries.isEmpty)
              _statusCard(c,
                  icon: Icons.emoji_events_outlined,
                  text: 'No entries for this course yet.')
            else ...[
              _podium(c, entries.take(3).toList()),
              const SizedBox(height: 14),
              for (final e in entries.skip(3)) _rankRow(c, e),
              const SizedBox(height: 96),
            ],
          ],
        ],
      ),
    );
  }

  /// "You + N classmates in this section" — proof the roster is real.
  Widget _rosterLine(AppColors c, LeaderboardRoster r) {
    final section = r.sections.isEmpty ? '' : ' · ${r.sections.first}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            r.youAreIn ? Icons.verified_user_outlined : Icons.group_outlined,
            size: 14,
            color: r.youAreIn ? Colors.white : Colors.white70,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              r.youAreIn
                  ? 'You + ${r.classmates} classmate${r.classmates == 1 ? '' : 's'} in this section$section'
                  : '${r.rosterSize} in this section$section — your timetable is not synced yet',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _courseBar(AppColors c) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final n in courses)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (course == n || loadingBoard) return;
                  setState(() => course = n);
                  _loadBoard();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: course == n
                        ? LinearGradient(colors: [c.tealDeep, c.teal])
                        : null,
                    color: course == n ? null : c.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: course == n
                            ? Colors.transparent
                            : c.dustSoft.withValues(alpha: 0.7)),
                    boxShadow: course == n
                        ? [
                            BoxShadow(
                                color: c.teal.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ]
                        : null,
                  ),
                  child: Text(_shortName(n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              course == n ? Colors.white : c.tealInk)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// "Data Structures (CP233-R26-BS-SE-F24-SED1)" -> "Data Structures".
  static String _shortName(String n) {
    final cut = n.indexOf('(');
    return (cut > 0 ? n.substring(0, cut) : n).trim();
  }

  Widget _statusCard(AppColors c,
      {required IconData icon,
      required String text,
      String? action,
      VoidCallback? onAction}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
          color: c.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Icon(icon, size: 32, color: c.teal),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: body(c, size: 14, color: c.tealInk.withValues(alpha: 0.7))),
          if (action != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                    gradient:
                        LinearGradient(colors: [c.tealDeep, c.teal]),
                    borderRadius: BorderRadius.circular(16)),
                child: Text(action,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Top-3 podium: 2nd | 1st (crown) | 3rd.
  Widget _podium(AppColors c, List<LeaderboardEntry> top) {
    Widget slot(LeaderboardEntry e, int podium) {
      final tone = podium == 1
          ? const Color(0xFFFFC53D)
          : podium == 2
              ? const Color(0xFF9FB3C8)
              : const Color(0xFFE2854E);
      return Expanded(
        child: Column(
          children: [
            if (podium == 1)
              const Icon(Icons.workspace_premium,
                  color: Color(0xFFFFC53D), size: 26),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: tone),
              child: CircleAvatar(
                radius: podium == 1 ? 30 : 24,
                backgroundColor: c.white,
                foregroundImage: e.imageUrl.isNotEmpty
                    ? NetworkImage(e.imageUrl)
                    : null,
                child: e.imageUrl.isNotEmpty
                    ? null
                    : Text(
                        e.isAnonymous
                            ? '?'
                            : e.studentName.isNotEmpty
                                ? e.studentName[0].toUpperCase()
                                : '?',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: tone)),
              ),
            ),
            const SizedBox(height: 8),
            Text(e.isAnonymous ? 'Anonymous' : e.studentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(c, size: 13, weight: FontWeight.w800)),
            Text(e.grade.isNotEmpty ? e.grade : '${e.percentage.toStringAsFixed(1)}%',
                style: body(c,
                    size: 12,
                    weight: FontWeight.w700,
                    color: tone)),
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('#${e.rank}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: tone)),
            ),
          ],
        ),
      );
    }

    final order = top.length == 3
        ? [top[1], top[0], top[2]]
        : top; // 2-1-3 when a full podium exists.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.tealDeep, c.teal]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < order.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            slot(order[i], order[i].rank),
          ],
        ],
      ),
    );
  }

  Widget _rankRow(AppColors c, LeaderboardEntry e) {
    final me = e.isMe;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: me ? c.teal.withValues(alpha: 0.10) : c.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: me ? c.teal : c.dustSoft.withValues(alpha: 0.6),
            width: me ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Container(
            alignment: Alignment.center,
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: me ? c.teal : c.dustSoft.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text('${e.rank}',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: me ? Colors.white : c.tealInk)),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 16,
            backgroundColor: c.dustSoft,
            foregroundImage:
                e.imageUrl.isNotEmpty ? NetworkImage(e.imageUrl) : null,
            child: e.imageUrl.isNotEmpty
                ? null
                : Text(
                    e.isAnonymous
                        ? '?'
                        : e.studentName.isNotEmpty
                            ? e.studentName[0].toUpperCase()
                            : '?',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    me
                        ? 'You'
                        : (e.isAnonymous ? 'Anonymous' : e.studentName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(c, size: 14, weight: FontWeight.w700)),
                if (e.grade.isNotEmpty)
                  Text('Grade ${e.grade}',
                      style: body(c,
                          size: 12,
                          color: c.tealInk.withValues(alpha: 0.55))),
              ],
            ),
          ),
          Text('${e.percentage.toStringAsFixed(1)}%',
              style: display(c, size: 16, color: c.teal)),
        ],
      ),
    );
  }
}
