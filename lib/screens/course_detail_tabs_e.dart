import 'package:flutter/material.dart';

import '../auth/course_detail.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import 'course_detail_widgets.dart';

/// Grades tab body: type summary with progress + detail rows.
Widget courseGradesBody(AppColors c, CourseGradebook? gb) {
  if (gb == null || gb.isEmpty) {
    return courseEmptyCard(
        c, Icons.grade_outlined, 'No grades published yet.');
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (gb.types.isNotEmpty)
        WhiteCard(
          child: Column(
            children: [
              for (final t in gb.types)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text(t.type,
                                  style: body(c,
                                      size: 13,
                                      weight: FontWeight.w600))),
                          Text('${t.obtained}%',
                              style: body(c,
                                  size: 13,
                                  weight: FontWeight.bold,
                                  color: c.teal)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: t.obtained.clamp(0, 100) / 100,
                          backgroundColor: c.dustSoft,
                          valueColor: AlwaysStoppedAnimation(c.teal),
                          minHeight: 7,
                        ),
                      ),
                      Text('weight ${t.weight}%',
                          style: body(c,
                              size: 11,
                              color: c.tealInk.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      if (gb.rows.isNotEmpty) ...[
        const SectionLabel('Assessments'),
        for (final r in gb.rows)
          courseRowCard(
            c,
            Row(
              children: [
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.assessment,
                        style:
                            body(c, size: 13, weight: FontWeight.w600)),
                    Text(
                        '${r.obtainedMarks}/${r.maxMarks} · avg ${r.classAverage}',
                        style: body(c,
                            size: 12,
                            color: c.tealInk.withValues(alpha: 0.55))),
                  ],
                )),
                Text('${r.percentage}%',
                    style: display(c, size: 16, color: c.teal)),
              ],
            ),
          ),
      ],
    ],
  );
}

/// Per-course attendance tab body.
Widget courseAttendanceBody(AppColors c, List<CourseAttendanceRow> rows) {
  if (rows.isEmpty) {
    return courseEmptyCard(c, Icons.fact_check_outlined,
        'No attendance records published.');
  }
  final pct = courseAttendancePercent(rows);
  return Column(
    children: [
      WhiteCard(
        child: Row(
          children: [
            Icon(Icons.fact_check_outlined, color: c.teal, size: 26),
            const SizedBox(width: 12),
            Expanded(
                child: Text('Course attendance',
                    style: body(c, size: 14, weight: FontWeight.w600))),
            Text('${pct.toStringAsFixed(1)}%',
                style: display(c, size: 20, color: c.teal)),
          ],
        ),
      ),
      const SizedBox(height: 12),
      for (final r in rows)
        courseRowCard(
          c,
          Row(
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
                  borderRadius: BorderRadius.circular(12),
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
                      style:
                          body(c, size: 14, weight: FontWeight.w600))),
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
  );
}
