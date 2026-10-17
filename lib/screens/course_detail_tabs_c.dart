import 'package:flutter/material.dart';

import '../auth/course_detail.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import 'course_detail_widgets.dart';

/// Outline tab part 2: weekly plan + books.
Widget courseOutlinePlan(AppColors c, CourseOutlineData o) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (o.weeks.isNotEmpty) ...[
        const SectionLabel('Weekly plan'),
        for (final w in o.weeks)
          courseRowCard(
            c,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  alignment: Alignment.center,
                  width: 34,
                  decoration: BoxDecoration(
                      color: c.tealInk,
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text('W${w.week}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.contents,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: body(c, size: 13)),
                    if (w.activity.isNotEmpty)
                      Text(w.activity,
                          style: body(c,
                              size: 12,
                              weight: FontWeight.w600,
                              color: c.teal)),
                  ],
                )),
              ],
            ),
          ),
      ],
      if (o.textbooks.isNotEmpty)
        courseKvCard(c, 'Textbooks', [
          for (final b in o.textbooks)
            [b.title, '${b.authors} · ${b.edition}']
        ]),
      if (o.references.isNotEmpty)
        courseKvCard(c, 'Reference books', [
          for (final b in o.references)
            [b.title, '${b.authors} · ${b.edition}']
        ]),
    ],
  );
}
