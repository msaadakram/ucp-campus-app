import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../leaderboard/leaderboard_service.dart';
import '../leaderboard/sync.dart';
import '../auth/student_portal.dart' show PortalCourse;
import '../theme/palette.dart';
import '../widgets/common.dart';

/// Identity key for a course: the section suffix is dropped, but the
/// "- Lab" suffix is KEPT — theory and lab are different subjects with
/// different boards.
String courseIdentityKey(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();

/// Loose key (section AND "- Lab" dropped) — fallback matching only,
/// for the extension's labels that lose the lab suffix.
String courseLooseKey(String name) =>
    courseIdentityKey(name)
        .replaceAll(RegExp(r'\s*[-–—]\s*lab\s*$'), '')
        .trim();

/// Course code inside a section label: "… (AR221-F26-BS-CS-F25-C1)" ->
/// "AR221".
String courseCodeFromLabel(String label) {
  final m = RegExp(r'\(([^)]*)\)').firstMatch(label);
  if (m == null) return '';
  return m.group(1)!.trim().split('-').first.trim();
}

/// One entry of the course picker: display/query name + course code
/// (the code keeps theory and lab apart on the server).
class LeaderboardCourse {
  final String name;
  final String code;
  const LeaderboardCourse(this.name, [this.code = '']);

  @override
  bool operator ==(Object other) =>
      other is LeaderboardCourse && other.name == name && other.code == code;

  @override
  int get hashCode => Object.hash(name, code);
}

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

  /// Code of the tapped course (e.g. "AR221"): the ext labels carry the
  /// section code, so this disambiguates lab vs theory reliably.
  final String? initialCourseCode;

  /// The student's REAL portal courses (name carries "- Lab" etc.). Used
  /// as the primary picker source so the board queries the same course
  /// key the extension published.
  final List<PortalCourse> portalCourses;

  /// Course code -> FULL section code (e.g. "AR221" ->
  /// "AR221-F26-BS-CS-F25-C1"). The full code scopes the board to one
  /// exact section, whoever published the data.
  final Map<String, String> sectionCodes;

  /// Bare course names from the app's own portal timetable — the picker
  /// source when the extension has posted no timetable yet.
  final List<String> fallbackCourses;

  /// The student's portal timetable rows, published to the server on the
  /// first open so app-only users join the class roster.
  final List<Map<String, String>> timetableRows;

  /// Display name of the signed-in student (for grade sync).
  final String? studentName;

  /// Publishes the student's own grades for the opened course (the app
  /// fetches the portal gradebook and posts it), so their row exists on
  /// the board even without the extension.
  final Future<void> Function(String courseName)? onEnsureGrades;

  /// Makes sure the student is signed in to the portal (Microsoft
  /// account -> session cookie). Returns true when the session is ready
  /// to read the timetable and the grade pages.
  final Future<bool> Function()? onEnsureSession;

  /// The full class sync: session -> timetable -> grade pages ->
  /// publish. Reports progress so the screen can show what it is doing.
  final Future<LeaderboardSyncReport> Function({
    void Function(SyncStepUpdate update)? onProgress,
    String? priorityCode,
  })?
  onSyncClass;

  /// Bumped by the app every time the student signs in again. The board
  /// watches it and resumes its sync on its own (no extra tap).
  final int sessionGeneration;
  final VoidCallback? back;

  /// Shown when live data is unavailable (no key / hard failure).
  final Widget? fallback;

  const LiveLeaderboardScreen({
    super.key,
    required this.service,
    this.studentId,
    this.studentName,
    this.initialCourse,
    this.initialCourseCode,
    this.portalCourses = const [],
    this.sectionCodes = const {},
    this.fallbackCourses = const [],
    this.timetableRows = const [],
    this.onEnsureGrades,
    this.onEnsureSession,
    this.onSyncClass,
    this.sessionGeneration = 0,
    this.back,
    this.fallback,
  });

  @override
  State<LiveLeaderboardScreen> createState() => _LiveLeaderboardScreenState();
}

class _LiveLeaderboardScreenState extends State<LiveLeaderboardScreen> {
  List<LeaderboardCourse> courses = [];
  LeaderboardCourse? course;
  List<LeaderboardEntry> entries = [];
  int? credits;

  /// True when this view was free (the app never spends credits).
  bool freeView = false;
  bool loading = true;
  bool loadingBoard = false;

  /// True when the course list came from the app's portal timetable
  /// (the extension has not posted one yet) — shown as a small hint.
  bool _fromPortal = false;

  /// Roster verification for the selected course (who shares the section).
  LeaderboardRoster? roster;

  /// True while the app publishes its own timetable to the server.
  bool syncing = false;

  /// True while the student's own grades are being published.
  bool _syncingGrades = false;

  /// The visible pipeline steps (sign-in -> timetable -> each subject's
  /// grade page -> the board request).
  final List<SyncStepUpdate> _steps = [];

  /// Student ids whose marks are expanded in the list.
  final Set<String> _expanded = {};

  /// How the board is shown: podium cards or a full ranked LIST.
  bool listView = false;

  /// True when the portal sign-in is required before anything can be
  /// read (the session really expired).
  bool _needsSignIn = false;

  /// True when the portal could not be reached — a network problem, not
  /// a sign-in problem. The board still loads; only the live sync waits.
  bool _networkProblem = false;

  /// Result of the last class sync.
  LeaderboardSyncReport? _syncReport;

  /// True once the class pipeline ran in this screen session — switching
  /// subjects reuses it (the grades are already on the server).
  bool _classSyncDone = false;

  /// The finished step list collapses to one line; tap to expand.
  bool _stepsCollapsed = false;

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
      final extList = await _svc!.fetchCourses(studentId: widget.studentId);
      if (!mounted) return;
      // The portal course list is authoritative: it keeps theory and lab
      // apart ("X" and "X - Lab") and carries the course code. Ext labels
      // fill in anything the portal list is missing (they may drop the
      // "- Lab" suffix, so they are matched loosely).
      final list = <LeaderboardCourse>[];
      final seen = <String>{};
      void add(String raw, {String code = ''}) {
        final n = raw.trim();
        if (n.isEmpty) return;
        final id = courseIdentityKey(n);
        if (id.isEmpty) return;
        if (!seen.add(id)) return;
        list.add(LeaderboardCourse(n, code));
      }

      for (final pc in widget.portalCourses) {
        final full = widget.sectionCodes[pc.code.trim().toUpperCase()];
        add(pc.name, code: (full != null && full.isNotEmpty) ? full : pc.code);
      }
      for (final n in extList) {
        final loose = courseLooseKey(n);
        final covered = list.any((e) => courseLooseKey(e.name) == loose);
        if (covered) continue;
        add(n, code: courseCodeFromLabel(n));
      }
      var fromPortal = widget.portalCourses.isNotEmpty;
      if (list.isEmpty && widget.fallbackCourses.isNotEmpty) {
        for (final n in widget.fallbackCourses) {
          add(n, code: courseCodeFromLabel(n));
        }
        fromPortal = true;
      }
      if (list.isEmpty) {
        setState(() {
          loading = false;
          error =
              'No class data yet — the leaderboard fills once students '
              'open the extension.';
        });
        return;
      }
      // Preselect the tapped subject: exact identity first (lab kept
      // apart), then the course code, then a loose match.
      final hint = (widget.initialCourse ?? '').trim();
      final hintId = courseIdentityKey(hint);
      final hintLoose = courseLooseKey(hint);
      final hintCode = (widget.initialCourseCode ?? '').trim().toLowerCase();
      LeaderboardCourse? pick;
      if (hintId.isNotEmpty) {
        pick = list.firstWhere(
          (e) => courseIdentityKey(e.name) == hintId,
          orElse: () => list.firstWhere(
            (e) =>
                hintCode.isNotEmpty &&
                (e.code.toLowerCase() == hintCode ||
                    e.name.toLowerCase().contains(hintCode)),
            orElse: () => list.firstWhere(
              (e) => courseLooseKey(e.name) == hintLoose,
              orElse: () => list.first,
            ),
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
      await _svc!.syncTimetable(studentId: sid, rows: widget.timetableRows);
    } catch (_) {
      // Sync is best-effort; the board still loads.
    }
    if (mounted) setState(() => syncing = false);
  }

  /// Runs the class-sync pipeline before the board is fetched:
  /// sign-in check -> timetable -> grade pages -> publish.
  ///
  /// This is the "app-first" path: the app reads the portal with the
  /// student's own session (no extension needed) and publishes what it
  /// finds, so the student appears on their class board with their real
  /// marks, and their classmates see them.
  Future<void> _runClassSync({bool force = false}) async {
    final sync = widget.onSyncClass;
    final ensureSession = widget.onEnsureSession;
    if (sync == null && ensureSession == null) return;
    if (_classSyncDone && !force) return;
    setState(() {
      _steps.clear();
      _needsSignIn = false;
      _networkProblem = false;
    });
    try {
      // 1) sign-in gate — the student sees the check happen.
      _pushStep(
        const SyncStepUpdate(
          key: 'session',
          kind: SyncStepKind.session,
          label: 'Checking your portal sign-in',
          detail: 'Verifying your Microsoft session',
          state: SyncStepState.active,
        ),
      );
      if (ensureSession != null) {
        final ready = await ensureSession();
        if (!mounted) return;
        if (!ready) {
          _pushStep(
            const SyncStepUpdate(
              key: 'session',
              kind: SyncStepKind.session,
              label: 'Checking your portal sign-in',
              detail: 'Session expired \u00b7 sign in again',
              state: SyncStepState.failed,
            ),
          );
          setState(() => _needsSignIn = true);
          return;
        }
      }
      // 2) timetable + 3) grade pages (read with the session cookie and
      //    published to the server, with the student's id).
      if (sync != null) {
        final report = await sync(
          onProgress: (update) {
            _pushStep(update);
          },
          // The subject on screen first — their own row shows up fast.
          priorityCode: course?.code,
        );
        if (!mounted) return;
        setState(() {
          _syncReport = report;
          _classSyncDone = true;
          _stepsCollapsed = true;
          // A portal we could not reach is a network problem — the
          // student does NOT need to sign in again.
          if (report.sessionState == PortalSessionState.unreachable) {
            _networkProblem = true;
          }
        });
        // The marks just landed — refresh the board so the student's own
        // row (and any classmate who synced meanwhile) is included.
        if (!mounted || _needsSignIn) return;
        await _loadBoard(refreshOnly: true);
      }
    } catch (_) {
      if (!mounted) return;
    }
  }

  /// Marks the board step as failed (so the spinner never spins on).
  void _failBoardStep(LeaderboardCourse sel, String why) {
    _pushStep(
      SyncStepUpdate(
        key: 'board:${sel.code.isEmpty ? sel.name : sel.code}',
        kind: SyncStepKind.board,
        label: 'Loading the leaderboard',
        detail: '${sel.name} \u00b7 $why',
        state: SyncStepState.failed,
      ),
    );
  }

  /// Merges a step update into the visible list (by key, keeping order).
  void _pushStep(SyncStepUpdate update) {
    if (!mounted) return;
    setState(() {
      final i = _steps.indexWhere((s) => s.key == update.key);
      if (i == -1) {
        _steps.add(update);
      } else {
        _steps[i] = update;
      }
    });
  }

  /// Roster verification for the selected course.
  Future<void> _loadRoster() async {
    final sel = course;
    if (_svc == null || sel == null) return;
    try {
      final r = await _svc!.fetchRoster(
        courseName: sel.name,
        studentId: (widget.studentId ?? '').trim().isEmpty
            ? null
            : widget.studentId,
        courseCode: sel.code,
      );
      if (!mounted) return;
      setState(() => roster = r);
    } catch (_) {
      // Verification is informational only.
    }
  }

  Future<void> _loadBoard({bool refreshOnly = false}) async {
    final sel = course;
    if (_svc == null || sel == null) return;
    setState(() {
      if (!refreshOnly) loadingBoard = true;
      error = null;
      noCredits = false;
    });
    try {
      // The class sync (sign-in -> timetable -> grade pages -> publish)
      // runs in the BACKGROUND: the board appears right away and is
      // refreshed when the marks land. Waiting for every grade page
      // first meant a blank screen for ~10s on mobile data.
      if (!refreshOnly) {
        unawaited(_runClassSync());
        // A dead session must not show a stale board.
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        if (_needsSignIn) {
          setState(() => loadingBoard = false);
          return;
        }
      }
      final ensure = widget.onEnsureGrades;
      if (ensure != null) {
        try {
          await ensure(sel.name);
        } catch (_) {
          // Grade publishing is best-effort.
        }
      }
      // The board request carries the SUBJECT and the STUDENT ID, so the
      // server answers with the classmates' grades AND the student's own
      // grade (same contract the extension uses).
      final boardKey = 'board:${sel.code.isEmpty ? sel.name : sel.code}';
      _pushStep(
        SyncStepUpdate(
          key: boardKey,
          kind: SyncStepKind.board,
          label: 'Loading the leaderboard',
          detail: '${sel.name} \u00b7 your class',
          state: SyncStepState.active,
        ),
      );
      final res = await _svc!.fetchLeaderboard(
        courseName: sel.name,
        studentId: widget.studentId,
        courseCode: sel.code,
      );
      if (!mounted) return;
      _pushStep(
        SyncStepUpdate(
          key: boardKey,
          kind: SyncStepKind.board,
          label: 'Loading the leaderboard',
          detail: '${sel.name} \u00b7 ${res.entries.length} students ranked',
          state: SyncStepState.done,
        ),
      );
      setState(() {
        entries = res.entries;
        credits = res.remainingCredits;
        freeView = res.free;
        loadingBoard = false;
      });
      await _loadRoster();
    } on NoCredits {
      if (!mounted) return;
      _failBoardStep(sel, 'No credits left');
      setState(() {
        loadingBoard = false;
        noCredits = true;
        entries = const [];
      });
    } on LeaderboardException catch (e) {
      if (!mounted) return;
      _failBoardStep(sel, e.message);
      setState(() {
        loadingBoard = false;
        error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      _failBoardStep(sel, 'Could not load this leaderboard');
      setState(() {
        loadingBoard = false;
        error = 'Could not load this leaderboard. Tap retry.';
      });
    }
  }

  @override
  void didUpdateWidget(covariant LiveLeaderboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The student just signed in again — resume the sync by itself.
    if (widget.sessionGeneration != oldWidget.sessionGeneration &&
        _needsSignIn) {
      setState(() => _needsSignIn = false);
      _runClassSync(force: true);
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
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, color: Colors.white, size: 16),
                        Text(
                          '  Back',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              if (credits != null || freeView)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        freeView ? Icons.bolt_outlined : Icons.toll_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        freeView ? 'Free' : '$credits credits',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Leaderboard', style: display(c, size: 26, color: Colors.white)),
          Text(
            'Live class ranks · overall % · updated by students',
            style: body(
              c,
              size: 13,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            _statusCard(
              c,
              icon: Icons.cloud_off_outlined,
              text: error!,
              action: 'Retry',
              onAction: course == null ? _loadCourses : _loadBoard,
            )
          else ...[
            _courseBar(c),
            if (_fromPortal) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 13,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Courses from your portal timetable — classmates '
                        'appear once the extension syncs.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
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
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Syncing your timetable…',
                      style: body(c, size: 11.5, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            if (_steps.isNotEmpty) _stepList(c),
            if (_needsSignIn) _signInCard(c),
            if (_networkProblem) _networkCard(c),
            if (roster != null) _rosterLine(c, roster!),
            if (loadingBoard)
              _boardSkeleton(c)
            else if (noCredits)
              _statusCard(
                c,
                icon: Icons.toll_outlined,
                text:
                    "You're out of credits — each leaderboard view "
                    'costs 1 credit. Earn more via referrals.',
                action: 'Retry',
                onAction: _loadBoard,
              )
            else if (entries.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statusCard(
                    c,
                    icon: Icons.emoji_events_outlined,
                    text: 'No ranks published for this subject yet.',
                  ),
                  if (widget.onEnsureGrades != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _publishButton(c),
                    ),
                ],
              )
            else ...[
              _viewToggle(c),
              const SizedBox(height: 12),
              if (!listView) _podium(c, entries.take(3).toList()),
              if (!listView) const SizedBox(height: 14),
              // Rows fade and slide in staggered — the board fills in
              // instead of snapping into place.
              for (var i = 0; i < entries.length; i++) ...[
                if (listView || i >= 3) _enterRow(c, entries[i], i),
              ],
              if (listView && entries.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Center(
                    child: Text(
                      '${entries.length} students ranked in this section',
                      style: body(
                        c,
                        size: 11.5,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 96),
            ],
          ],
        ],
      ),
    );
  }

  /// The visible pipeline: "Checking your portal sign-in" -> "Getting
  /// your timetable" -> one line per subject's grade page -> "Loading
  /// the leaderboard". Every line shows what is happening right now.
  Widget _stepList(AppColors c) {
    final running = _steps.any((s) => s.state == SyncStepState.active);
    final report = _syncReport;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _stepsCollapsed = !_stepsCollapsed),
            child: Row(
              children: [
                Icon(
                  running ? Icons.sync_rounded : Icons.check_circle_outline,
                  size: 16,
                  color: running ? c.teal : c.tealInk.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    running
                        ? 'Syncing your class'
                        : (report != null && report.ok
                              ? 'Synced: ${report.timetableRows} slots \u00b7 '
                                    '${report.subjectsSynced} subjects sent'
                              : 'Class sync'),
                    style: body(
                      c,
                      size: 12.5,
                      weight: FontWeight.w800,
                      color: c.tealInk,
                    ),
                  ),
                ),
                Icon(
                  _stepsCollapsed
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  size: 18,
                  color: c.tealInk.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
          if (!_stepsCollapsed) ...[
            const SizedBox(height: 8),
            for (final step in _steps) _stepRow(c, step),
          ],
        ],
      ),
    );
  }

  /// One line of the pipeline with its state.
  Widget _stepRow(AppColors c, SyncStepUpdate step) {
    IconData icon;
    Color tint;
    switch (step.state) {
      case SyncStepState.active:
        icon = Icons.pending_outlined;
        tint = c.teal;
        break;
      case SyncStepState.done:
        icon = Icons.check_circle;
        tint = const Color(0xFF2FA36B);
        break;
      case SyncStepState.failed:
        icon = Icons.error_outline;
        tint = const Color(0xFFD9534F);
        break;
      case SyncStepState.pending:
        icon = Icons.circle_outlined;
        tint = c.tealInk.withValues(alpha: 0.35);
        break;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step.state == SyncStepState.active)
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: tint),
            )
          else
            Icon(icon, size: 15, color: tint),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  style: body(
                    c,
                    size: 12.5,
                    weight: FontWeight.w700,
                    color: c.tealInk,
                  ),
                ),
                if ((step.detail ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      step.detail!,
                      style: body(
                        c,
                        size: 11,
                        color: c.tealInk.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The portal could not be reached: a network problem, NOT a sign-in
  /// problem. The board still works (it comes from the server); only the
  /// live sync of the timetable/grades waits for the connection.
  Widget _networkCard(AppColors c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_off_outlined, size: 18, color: c.tealInk),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Could not reach the UCP portal \u2014 your ranks are up to '
                'date, but the live sync of your timetable and grades '
                'needs a connection.',
                style: body(
                  c,
                  size: 12,
                  color: c.tealInk.withValues(alpha: 0.75),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _networkProblem = false);
                _runClassSync(force: true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c.tealDeep, c.teal]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Retry',
                  style: body(
                    c,
                    size: 12.5,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The sign-in gate: the portal (Microsoft account -> session cookie)
  /// is required to read the timetable and the grade pages.
  Widget _signInCard(AppColors c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_person_outlined, size: 20, color: c.tealInk),
                const SizedBox(width: 8),
                Text(
                  'Sign in to sync your class',
                  style: display(c, size: 17, color: c.tealInk),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your timetable and grade pages are read from the UCP '
              'portal with your Microsoft account. Sign in once and the '
              'app publishes your class so the leaderboard can rank you '
              'with your section.',
              style: body(
                c,
                size: 12.5,
                color: c.tealInk.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final ensure = widget.onEnsureSession;
                if (ensure == null) return;
                final ok = await ensure();
                if (!mounted) return;
                if (!ok) return;
                setState(() => _needsSignIn = false);
                await _loadBoard();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c.tealDeep, c.teal]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.login, size: 17, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Sign in with Microsoft',
                      style: body(
                        c,
                        size: 14,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Publish my marks" — pushes the student's own portal gradebook for
  /// this subject to the server, then reloads the board.
  Widget _publishButton(AppColors c) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _syncingGrades
          ? null
          : () async {
              setState(() => _syncingGrades = true);
              try {
                // Full re-sync: re-read the timetable + every grade page
                // with the session and publish them again.
                await _runClassSync(force: true);
                await widget.onEnsureGrades?.call(course?.name ?? '');
              } catch (_) {
                // Fall through to the reload below.
              }
              if (mounted) setState(() => _syncingGrades = false);
              await _loadBoard();
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c.tealDeep, c.teal]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_syncingGrades)
              const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(
                Icons.cloud_upload_outlined,
                size: 17,
                color: Colors.white,
              ),
            const SizedBox(width: 8),
            Text(
              'Publish my marks',
              style: body(
                c,
                size: 14,
                weight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
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
                color: Colors.white.withValues(alpha: 0.9),
              ),
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
          for (final entry in courses)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (course == entry || loadingBoard) return;
                  setState(() => course = entry);
                  _loadBoard();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    gradient: course == entry
                        ? LinearGradient(colors: [c.tealDeep, c.teal])
                        : null,
                    color: course == entry ? null : c.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: course == entry
                          ? Colors.transparent
                          : c.dustSoft.withValues(alpha: 0.7),
                    ),
                    boxShadow: course == entry
                        ? [
                            BoxShadow(
                              color: c.teal.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _shortName(entry.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: course == entry ? Colors.white : c.tealInk,
                    ),
                  ),
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

  Widget _statusCard(
    AppColors c, {
    required IconData icon,
    required String text,
    String? action,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: c.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: c.teal),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: body(c, size: 14, color: c.tealInk.withValues(alpha: 0.7)),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c.tealDeep, c.teal]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  action,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
        // Tap a podium card to see the marks behind the score.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showMarks(c, e),
          child: Column(
            children: [
              if (podium == 1)
                const Icon(
                  Icons.workspace_premium,
                  color: Color(0xFFFFC53D),
                  size: 26,
                ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(shape: BoxShape.circle, color: tone),
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
                            fontWeight: FontWeight.w800,
                            color: tone,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                e.isAnonymous ? 'Anonymous' : e.studentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(c, size: 13, weight: FontWeight.w800),
              ),
              Text(
                e.grade.isNotEmpty
                    ? '${e.grade} · ${e.percentage.toStringAsFixed(1)}%'
                    : '${e.percentage.toStringAsFixed(1)}%',
                style: body(c, size: 12, weight: FontWeight.w700, color: tone),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '#${e.rank}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: tone,
                  ),
                ),
              ),
            ],
          ),
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
    final open = _expanded.contains(e.studentId);
    final hasMarks = e.assessments.isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hasMarks
          ? () => setState(() {
              if (open) {
                _expanded.remove(e.studentId);
              } else {
                _expanded.add(e.studentId);
              }
            })
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: me ? c.teal.withValues(alpha: 0.10) : c.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: me ? c.teal : c.dustSoft.withValues(alpha: 0.6),
            width: me ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  alignment: Alignment.center,
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: me ? c.teal : c.dustSoft.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    '${e.rank}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: me ? Colors.white : c.tealInk,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: c.dustSoft,
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
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
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
                        style: body(c, size: 14, weight: FontWeight.w700),
                      ),
                      if (e.grade.isNotEmpty)
                        // Grade AND percentage — one used to hide the other.
                        Text(
                          'Grade ${e.grade} · '
                          '${e.percentage.toStringAsFixed(1)}%',
                          style: body(
                            c,
                            size: 12,
                            color: c.tealInk.withValues(alpha: 0.55),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${e.percentage.toStringAsFixed(1)}%',
                  style: display(c, size: 16, color: c.teal),
                ),
              ],
            ),
            if (open && hasMarks) _marksPanel(c, e),
          ],
        ),
      ),
    );
  }

  /// Podium / LIST switch.
  Widget _viewToggle(AppColors c) {
    return Row(
      children: [
        _viewChip(
          c,
          label: 'Podium',
          icon: Icons.emoji_events_outlined,
          selected: !listView,
          onTap: () => setState(() => listView = false),
        ),
        const SizedBox(width: 8),
        _viewChip(
          c,
          label: 'List',
          icon: Icons.view_agenda_outlined,
          selected: listView,
          onTap: () => setState(() => listView = true),
        ),
        const Spacer(),
        if (entries.length > 1)
          Text(
            '${entries.length} ranked',
            style: body(
              c,
              size: 11.5,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
      ],
    );
  }

  Widget _viewChip(
    AppColors c, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 13,
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A row entering the list: fade + slide up, staggered by rank.
  Widget _enterRow(AppColors c, LeaderboardEntry e, int index) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 260),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, t, child) {
        final eased = Curves.easeOutCubic.transform(t);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - eased)),
            child: child,
          ),
        );
      },
      child: _rankRow(c, e),
    );
  }

  /// Shimmer skeleton while the board loads — modern, no bare spinner.
  Widget _boardSkeleton(AppColors c) {
    return Column(
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _Shimmer(
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The marks behind a score: every assessment with obtained/total,
  /// weight and (when reported) the class average.
  Widget _marksPanel(AppColors c, LeaderboardEntry e) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 2, right: 2),
      child: Column(
        children: [
          for (final a in e.assessments)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body(
                        c,
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: c.tealInk,
                      ),
                    ),
                  ),
                  if (a.weightage > 0)
                    Text(
                      '${a.weightage.toStringAsFixed(0)}% w',
                      style: body(
                        c,
                        size: 11,
                        color: c.tealInk.withValues(alpha: 0.5),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Text(
                    a.marksLabel,
                    style: body(
                      c,
                      size: 12.5,
                      weight: FontWeight.w800,
                      color: c.tealInk,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${a.percentage.toStringAsFixed(0)}%',
                      textAlign: TextAlign.right,
                      style: body(
                        c,
                        size: 12.5,
                        weight: FontWeight.w800,
                        color: c.teal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (e.classAverage > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 13,
                    color: c.tealInk.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Class average ${e.classAverage.toStringAsFixed(1)}%',
                    style: body(
                      c,
                      size: 11.5,
                      color: c.tealInk.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Marks sheet for the podium cards (the list expands inline).
  void _showMarks(AppColors c, LeaderboardEntry e) {
    if (e.assessments.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _marksSheet(c, e),
    );
  }

  Widget _marksSheet(AppColors c, LeaderboardEntry e) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: c.dustSoft,
                  foregroundImage: e.imageUrl.isNotEmpty
                      ? NetworkImage(e.imageUrl)
                      : null,
                  child: e.imageUrl.isNotEmpty
                      ? null
                      : Text(
                          e.isAnonymous
                              ? '?'
                              : (e.studentName.isNotEmpty
                                    ? e.studentName[0].toUpperCase()
                                    : '?'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.isMe ? 'You' : e.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: display(c, size: 18, color: c.tealInk),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${e.percentage.toStringAsFixed(1)}% overall\u00b7 '
              '${e.grade.isNotEmpty ? 'grade ${e.grade}' : 'no grade'}\u00b7 '
              'rank ${e.rank}',
              style: body(
                c,
                size: 12.5,
                color: c.tealInk.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Marks',
              style: body(
                c,
                size: 12,
                weight: FontWeight.w800,
                color: c.tealInk.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 6),
            for (final a in e.assessments)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: body(
                          c,
                          size: 13,
                          weight: FontWeight.w700,
                          color: c.tealInk,
                        ),
                      ),
                    ),
                    if (a.weightage > 0)
                      Text(
                        '${a.weightage.toStringAsFixed(0)}% w',
                        style: body(
                          c,
                          size: 11,
                          color: c.tealInk.withValues(alpha: 0.5),
                        ),
                      ),
                    const SizedBox(width: 10),
                    Text(
                      a.marksLabel,
                      style: body(
                        c,
                        size: 13,
                        weight: FontWeight.w800,
                        color: c.tealInk,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 46,
                      child: Text(
                        '${a.percentage.toStringAsFixed(0)}%',
                        textAlign: TextAlign.right,
                        style: body(
                          c,
                          size: 13,
                          weight: FontWeight.w800,
                          color: c.teal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (e.classAverage > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      size: 14,
                      color: c.tealInk.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Class average ${e.classAverage.toStringAsFixed(1)}%',
                      style: body(
                        c,
                        size: 12,
                        color: c.tealInk.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// A shimmering placeholder (modern loading animation).
class _Shimmer extends StatefulWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final w = bounds.width;
            final dx = (w * 2) * _c.value - w * 0.5;
            return LinearGradient(
              colors: const [
                Color(0x22FFFFFF),
                Color(0x66FFFFFF),
                Color(0x22FFFFFF),
              ],
              stops: const [0.35, 0.5, 0.65],
              transform: GradientTranslation(dx),
            ).createShader(Rect.fromLTWH(0, 0, w, bounds.height));
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Slide for the shimmer gradient.
class GradientTranslation implements GradientTransform {
  final double x;
  const GradientTranslation(this.x);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(x, 0, 0);
}
