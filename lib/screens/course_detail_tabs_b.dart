import 'package:flutter/material.dart';

import '../auth/course_detail.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import 'course_detail_widgets.dart';

/// Outline tab body: weightage breakdown with bars + CLO cards.
Widget courseOutlineBody(AppColors c, CourseOutlineData? o) {
  if (o == null || o.isEmpty) {
    return courseEmptyCard(
        c, Icons.menu_book_outlined, 'No outline published yet.');
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (o.weightages.isNotEmpty) ...[
        const _Section('Grading breakdown'),
        courseCard(
          c,
          child: Column(
            children: [
              for (var i = 0; i < o.weightages.length; i++)
                _weightRow(c, o.weightages[i],
                    [c.teal, c.clay, c.board][i % 3]),
            ],
          ),
        ),
      ],
      if (o.clos.isNotEmpty) ...[
        const _Section('Learning outcomes'),
        for (final clo in o.clos)
          courseCard(
            c,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  alignment: Alignment.center,
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: c.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(clo.clo,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: c.tealDeep)),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clo.statement,
                        style: body(c,
                            size: 13, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    courseChip(c, '${clo.bloom} · PLO ${clo.plo}'),
                  ],
                )),
              ],
            ),
          ),
      ],
    ],
  );
}

/// One weightage line: name, "top n" hint, weight pill + weight bar.
Widget _weightRow(AppColors c, CourseWeightage w, Color tone) {
  // Pill text must stay exactly '<weight>%' — tab tests match it.
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(w.type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(c, size: 13, weight: FontWeight.w700))),
            if (w.considerTop > 0) ...[
              Text('top ${w.considerTop} · ',
                  style: body(c,
                      size: 11,
                      color: c.tealInk.withValues(alpha: 0.55))),
            ],
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: tone,
                  borderRadius: BorderRadius.circular(12)),
              child: Text('${w.weight}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (w.weight / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: c.dustSoft.withValues(alpha: 0.7),
            valueColor: AlwaysStoppedAnimation(tone),
          ),
        ),
      ],
    ),
  );
}

/// Small section heading inside the scroll (kept visually identical to
/// [SectionLabel] but const-friendly here).
class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(text,
          style: display(c, size: 17, color: c.tealInk)),
    );
  }
}
