import 'package:flutter/material.dart';

import '../auth/course_detail.dart';
import '../theme/palette.dart';
import 'course_detail_widgets.dart';

/// Weighted overall across published grade types (0 when none):
/// each type contributes its obtained percentage x its weight — the same
/// formula the server and the extension use, so the app's number always
/// matches what the class board ranks on.
double _gradebookOverall(CourseGradebook gb) {
  var overall = 0.0;
  for (final t in gb.types) {
    if (t.weight > 0) overall += t.weightedPercentage;
  }
  return overall.clamp(0, 100);
}

/// Grades tab body: overall ring hero + per-type bars + assessment rows.
/// [onOpenLeaderboard] adds the "see the class ranking" action.
Widget courseGradesBody(AppColors c, CourseGradebook? gb,
    [VoidCallback? onOpenLeaderboard]) {
  if (gb == null || gb.isEmpty) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        courseEmptyCard(
            c, Icons.grade_outlined, 'No grades published yet.'),
        if (onOpenLeaderboard != null) _leaderboardButton(c, onOpenLeaderboard),
      ],
    );
  }
  final overall = _gradebookOverall(gb);
  final tone = overall >= 80
      ? c.teal
      : overall >= 50
          ? c.board
          : c.clay;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Overall hero: ring + big number + label.
      courseCard(
        c,
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: (overall / 100).clamp(0.0, 1.0),
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    backgroundColor: c.dustSoft.withValues(alpha: 0.7),
                    valueColor: AlwaysStoppedAnimation(tone),
                  ),
                  Text('${overall.toStringAsFixed(overall.truncateToDouble() == overall ? 0 : 1)}%',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: tone)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overall so far',
                      style: display(c, size: 16)),
                  Text(
                      'Weighted across ${gb.types.length} published type${gb.types.length == 1 ? '' : 's'}',
                      style: body(c,
                          size: 12,
                          color: c.tealInk.withValues(alpha: 0.55))),
                ],
              ),
            ),
          ],
        ),
      ),
      if (onOpenLeaderboard != null) ...[
        const SizedBox(height: 10),
        _leaderboardButton(c, onOpenLeaderboard),
      ],
      if (gb.types.isNotEmpty) ...[
        const SizedBox(height: 4),
        courseCard(
          c,
          child: Column(
            children: [
              for (var i = 0; i < gb.types.length; i++)
                _typeRow(c, gb.types[i],
                    [c.teal, c.clay, c.board][i % 3]),
            ],
          ),
        ),
      ],
      if (gb.rows.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text('Assessments',
              style: display(c, size: 17, color: c.tealInk)),
        ),
        for (final r in gb.rows)
          courseCard(
            c,
            child: Row(
              children: [
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.assessment,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: body(c,
                            size: 13, weight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('${r.obtainedMarks}/${r.maxMarks} · avg ${r.classAverage}',
                        style: body(c,
                            size: 12,
                            color: c.tealInk.withValues(alpha: 0.55))),
                  ],
                )),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${r.percentage}%',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: c.tealDeep)),
                ),
              ],
            ),
          ),
      ],
    ],
  );
}

/// One grade-type line: name, obtained % (test-matched text) + bar.
Widget _typeRow(AppColors c, CourseGradeType t, Color tone) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(t.type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(c, size: 13, weight: FontWeight.w700))),
            Text('${t.obtained}%',
                style: body(c,
                    size: 13,
                    weight: FontWeight.bold,
                    color: c.tealDeep)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: t.obtained.clamp(0, 100) / 100,
            backgroundColor: c.dustSoft,
            valueColor: AlwaysStoppedAnimation(tone),
            minHeight: 7,
          ),
        ),
        Text('weight ${t.weight}%',
            style: body(c,
                size: 11, color: c.tealInk.withValues(alpha: 0.5))),
      ],
    ),
  );
}

/// "See the class ranking" action (opens the live leaderboard).
Widget _leaderboardButton(AppColors c, VoidCallback onTap) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.tealDeep, c.teal]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: c.teal.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_outlined,
              size: 17, color: Colors.white),
          const SizedBox(width: 8),
          Text('See class leaderboard',
              style: body(c,
                  size: 14, weight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    ),
  );
}

/// Per-course attendance tab body: ring summary + dated status rows.
Widget courseAttendanceBody(AppColors c, List<CourseAttendanceRow> rows) {
  if (rows.isEmpty) {
    return courseEmptyCard(c, Icons.fact_check_outlined,
        'No attendance records published.');
  }
  final pct = courseAttendancePercent(rows);
  final tone =
      pct >= 75 ? c.teal : pct >= 50 ? c.board : c.clay;
  return Column(
    children: [
      courseCard(
        c,
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    backgroundColor: c.dustSoft.withValues(alpha: 0.7),
                    valueColor: AlwaysStoppedAnimation(tone),
                  ),
                  Text('${pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: tone)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Course attendance',
                      style: display(c, size: 16)),
                  Text(
                      pct >= 75
                          ? 'Above the 75% requirement. Keep it up.'
                          : 'Below the 75% requirement — catch up soon.',
                      style: body(c,
                          size: 12,
                          color: c.tealInk.withValues(alpha: 0.6))),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      for (final r in rows)
        courseCard(
          c,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: r.status == 'Present'
                      ? c.teal.withValues(alpha: 0.14)
                      : r.status == 'Absent'
                          ? c.clay.withValues(alpha: 0.14)
                          : c.board.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(r.status,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: r.status == 'Present'
                            ? c.tealDeep
                            : r.status == 'Absent'
                                ? c.clay
                                : c.board)),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(r.date,
                      style:
                          body(c, size: 14, weight: FontWeight.w600))),
              if (r.fine != '-' && r.fine.isNotEmpty)
                courseChip(c, 'Fine ${r.fine}',
                    bg: c.clay.withValues(alpha: 0.12), fg: c.clay),
            ],
          ),
        ),
    ],
  );
}
