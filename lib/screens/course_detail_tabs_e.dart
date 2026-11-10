import 'package:flutter/material.dart';

import '../auth/course_detail.dart';
import '../auth/portal_dates.dart';
import '../gpa_vault/grading.dart';
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

/// Tone for a bar fill at [percent]: teal above 75, amber above 50,
/// terracotta clay otherwise.
Color _toneFor(AppColors c, double percent) => percent >= 75
    ? c.teal
    : percent >= 50
        ? c.board
        : c.clay;

/// Small "letter chip" (A, B+, …) tinted by [tone].
Widget _letterChip(AppColors c, String letter, Color tone, [double size = 40]) {
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [
        tone.withValues(alpha: 0.95),
        tone.withValues(alpha: 0.75),
      ]),
      borderRadius: BorderRadius.circular(size * 0.32),
      boxShadow: [
        BoxShadow(
          color: tone.withValues(alpha: 0.35),
          blurRadius: 7,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Text(letter,
        style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.36)),
  );
}

/// Grades tab body: overall ring hero + per-type cards with the child
/// marks nested inside (everything on one screen, no sheets).
/// [onOpenLeaderboard] adds the "see the class ranking" action.
Widget courseGradesBody(AppColors c, CourseGradebook? gb,
    [VoidCallback? onOpenLeaderboard]) {
  if (gb == null || gb.isEmpty) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        courseEmptyCard(
            c, Icons.grade_outlined, 'No grades published yet.'),
        if (onOpenLeaderboard != null)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _leaderboardButton(c, onOpenLeaderboard)),
      ],
    );
  }
  final overall = _gradebookOverall(gb);
  final letter = vaultGradeForPercent(overall);
  final tone = _toneFor(c, overall);
  final totalWeight =
      gb.types.fold<double>(0, (sum, t) => sum + t.weight);
  final earnedPts = gb.types.fold<double>(0,
      (sum, t) => t.weight > 0 ? sum + t.weightedPercentage : sum);
  // Marks grouped by their parent type (rows carry `type`).
  final rowsByType = <String, List<CourseGradeRow>>{};
  for (final r in gb.rows) {
    rowsByType.putIfAbsent(r.type, () => []).add(r);
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ---------- overall hero ----------
      courseCard(
        c,
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: (overall / 100).clamp(0.0, 1.0),
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: c.dustSoft.withValues(alpha: 0.7),
                    valueColor: AlwaysStoppedAnimation(tone),
                  ),
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('${overall.toStringAsFixed(1)}%',
                            style: display(c, size: 14.5, color: tone)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Overall so far',
                            style: display(c, size: 16)),
                      ),
                      _letterChip(c, letter, tone, 38),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${earnedPts.toStringAsFixed(1)} of '
                    '${totalWeight.toStringAsFixed(0)} weighted points earned',
                    style: body(c,
                        size: 11.5,
                        weight: FontWeight.w700,
                        color: c.tealInk.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Across ${gb.types.length} published type'
                    '${gb.types.length == 1 ? '' : 's'}',
                    style: body(c,
                        size: 10.5,
                        color: c.tealInk.withValues(alpha: 0.45)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (onOpenLeaderboard != null) ...[
        const SizedBox(height: 2),
        _leaderboardButton(c, onOpenLeaderboard),
      ],
      courseSectionHeader(c, 'Breakdown by type',
          trailing: '${gb.types.length}'),
      // ---------- per-type cards ----------
      for (var i = 0; i < gb.types.length; i++)
        _typeCard(c, gb.types[i], rowsByType[gb.types[i].type] ?? const [],
            const [Color(0xFF1789B8), Color(0xFFF4A82A), Color(0xFF8FAE6E),
                Color(0xFFEE6A24)][i % 4]),
      const SizedBox(height: 4),
    ],
  );
}

/// One assessment-type card: obtained vs weight, its share of the course
/// mark, and the individual marks underneath.
Widget _typeCard(AppColors c, CourseGradeType t,
    List<CourseGradeRow> rows, Color tone) {
  final typeTone = _toneFor(c, t.obtained);
  final weighted = t.weightedPercentage;
  final letter = t.obtained > 0 ? vaultGradeForPercent(t.obtained) : '—';
  return courseCard(
    c,
    padding: const EdgeInsets.all(13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _letterChip(c, letter, typeTone, 34),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.type,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body(c, size: 13.5, weight: FontWeight.w800)),
                  Text('Weight ${_trimNum2(t.weight)}% · '
                      'earned ${weighted.toStringAsFixed(1)} pts',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body(c,
                          size: 10.5,
                          color: c.tealInk.withValues(alpha: 0.55))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('${t.obtained.toStringAsFixed(1)}%',
                style: display(c, size: 17, color: typeTone)),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: t.obtained.clamp(0, 100) / 100,
            minHeight: 7,
            backgroundColor: c.dustSoft.withValues(alpha: 0.6),
            valueColor: AlwaysStoppedAnimation(typeTone),
          ),
        ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            height: 1,
            color: c.dustSoft.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 8),
          for (final r in rows) _assessmentRow(c, r),
        ],
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Row(
              children: [
                Icon(Icons.hourglass_empty_rounded,
                    size: 13, color: c.tealInk.withValues(alpha: 0.4)),
                const SizedBox(width: 6),
                Text('Marks not published yet',
                    style: body(c,
                        size: 11,
                        weight: FontWeight.w700,
                        color: c.tealInk.withValues(alpha: 0.45))),
              ],
            ),
          ),
      ],
    ),
  );
}

/// One assessment line inside its type card: name, marks/max, class
/// average and the percentage pill.
Widget _assessmentRow(AppColors c, CourseGradeRow r) {
  final pctTone = _toneFor(c, r.percentage);
  final delta = r.maxMarks > 0
      ? (r.obtainedMarks / r.maxMarks - r.classAverage / r.maxMarks) * 100
      : 0.0;
  final sign = delta >= 0 ? '+' : '−';
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.assessment,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(c, size: 12.5, weight: FontWeight.w700)),              Text(
                'Class avg ${r.classAverage.toStringAsFixed(1)}'
                ' · you $sign${delta.abs().toStringAsFixed(0)}%',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(c, size: 10.5,
                    color: c.tealInk.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text('${_fmtMark(r.obtainedMarks)}/${_fmtMark(r.maxMarks)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: body(c, size: 12, weight: FontWeight.w800,
                  color: c.tealInk)),
        ),
        const SizedBox(width: 6),
        courseStatusPill(c,
            text: '${r.percentage.toStringAsFixed(1)}%',
            tone: pctTone),
      ],
    ),
  );
}

String _trimNum2(double v) =>
    v.truncateToDouble() == v ? v.toInt().toString() : v.toStringAsFixed(1);

/// 16, not 16.0; trims to two decimals when fractional.
String _fmtMark(double v) =>
    v.truncateToDouble() == v ? v.toInt().toString() : v.toStringAsFixed(2);

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

/// Per-course attendance body: ring hero + segmented bar + dated records.
Widget courseAttendanceBody(AppColors c, List<CourseAttendanceRow> rows) {
  if (rows.isEmpty) {
    return courseEmptyCard(c, Icons.fact_check_outlined,
        'No attendance records published.');
  }
  final pct = courseAttendancePercent(rows);
  var present = 0;
  var absent = 0;
  var other = 0;
  var fins = 0;
  for (final r in rows) {
    final s = r.status.toLowerCase();
    if (s == 'present') {
      present++;
    } else if (s == 'absent') {
      absent++;
    } else {
      other++;
    }
    if (r.fine.isNotEmpty && r.fine != '-') fins++;
  }
  final total = rows.length;
  final tone = _toneFor(c, pct);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ---------- hero ----------
      courseCard(
        c,
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: c.dustSoft.withValues(alpha: 0.7),
                    valueColor: AlwaysStoppedAnimation(tone),
                  ),
                  Center(
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('${pct.toStringAsFixed(0)}%',
                            style: display(c, size: 15, color: tone)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Course attendance', style: display(c, size: 16)),
                  const SizedBox(height: 3),
                  Text('$present of $total classes attended',
                      style: body(c,
                          size: 12.5, weight: FontWeight.w800, color: c.tealInk.withValues(alpha: 0.75))),
                  const SizedBox(height: 2),
                  Text(
                    pct >= 75
                        ? 'Above the 75% eligibility requirement.'
                        : 'Below the 75% eligibility requirement',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(c,
                        size: 11,
                        weight: FontWeight.w700,
                        color: pct >= 75 ? c.teal : c.clay),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // ---------- segmented mix bar ----------
      courseCard(
        c,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: courseStat(c, '$present', 'Present', tone: c.teal)),
                Expanded(child: courseStat(c, '$absent', 'Absent', tone: c.clay)),
                Expanded(
                    child: courseStat(c, '$other', 'Leave/Other',
                        tone: c.board)),
                Expanded(
                    child: courseStat(c, '$fins', 'Fines',
                        tone: fins > 0 ? c.clay : const Color(0xFF8A8F96))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _seg(c.teal, present, total),
                const SizedBox(width: 3),
                _seg(c.clay, absent, total),
                const SizedBox(width: 3),
                _seg(c.board, other, total),
              ],
            ),
          ],
        ),
      ),
      courseSectionHeader(c, 'Records', trailing: '$total'),
      // ---------- record rows ----------
      for (final r in rows) _recordRow(c, r),
      const SizedBox(height: 6),
    ],
  );
}

/// One coloured segment of the attendance mix bar (min width fills with
/// a 1px sliver so the bar always reads as a breakdown).
Widget _seg(Color tone, int count, int total) {
  if (total == 0) return const Expanded(child: SizedBox());
  if (count == 0) return const SizedBox(width: 1);
  return Expanded(
    flex: count,
    child: Container(height: 12, decoration: BoxDecoration(
        color: tone, borderRadius: BorderRadius.circular(4))),
  );
}

/// One attendance record: status icon, date, fine chip if any.
Widget _recordRow(AppColors c, CourseAttendanceRow r) {
  final s = r.status.toLowerCase();
  final present = s == 'present';
  final absent = s == 'absent';
  final tone = present
      ? c.teal
      : absent
          ? c.clay
          : c.board;
  final icon = present
      ? Icons.check_circle_rounded
      : absent
          ? Icons.cancel_rounded
          : Icons.event_busy_outlined;
  final d = parsePortalDateTime(r.date);
  final dateText = d != null ? formatPortalDay(d) : r.date;
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: c.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.dustSoft.withValues(alpha: 0.6)),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: tone),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateText,
                  style: body(c, size: 13.5, weight: FontWeight.w800)),
              Text(r.status,
                  style: body(c,
                      size: 10.5,
                      weight: FontWeight.w800,
                      color: tone)),
            ],
          ),
        ),
        if (r.fine.isNotEmpty && r.fine != '-')
          courseStatusPill(c,
              text: 'Fine ${r.fine}',
              tone: c.clay,
              icon: Icons.payments_outlined),
      ],
    ),
  );
}
