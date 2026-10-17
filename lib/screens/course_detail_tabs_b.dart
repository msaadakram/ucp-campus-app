import 'package:flutter/material.dart';

import '../auth/course_detail.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import 'course_detail_widgets.dart';

/// Outline tab body: weightages, CLOs, weekly plan, books.
Widget courseOutlineBody(AppColors c, CourseOutlineData? o) {
  if (o == null || o.isEmpty) {
    return courseEmptyCard(
        c, Icons.menu_book_outlined, 'No outline published yet.');
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (o.weightages.isNotEmpty) ...[
        const SectionLabel('Grading breakdown'),
        WhiteCard(
          child: Column(
            children: [
              for (final w in o.weightages)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(w.type,
                              style: body(c,
                                  size: 13, weight: FontWeight.w600))),
                      if (w.considerTop > 0)
                        Text('top ${w.considerTop} · ',
                            style: body(c,
                                size: 11,
                                color:
                                    c.tealInk.withValues(alpha: 0.55))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: c.teal,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text('${w.weight}%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      if (o.clos.isNotEmpty) ...[
        const SectionLabel('Learning outcomes'),
        for (final clo in o.clos)
          courseRowCard(
            c,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  alignment: Alignment.center,
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: c.dustSoft,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(clo.clo,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: c.tealInk)),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clo.statement, style: body(c, size: 13)),
                    const SizedBox(height: 4),
                    Text('${clo.bloom} · PLO ${clo.plo}',
                        style: body(c,
                            size: 11,
                            color: c.tealInk.withValues(alpha: 0.55))),
                  ],
                )),
              ],
            ),
          ),
      ],
    ],
  );
}
