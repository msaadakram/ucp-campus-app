import 'package:flutter/material.dart';

import '../auth/course_detail.dart';
import '../theme/palette.dart';
import 'course_detail_widgets.dart';

/// Outline tab part 2: weekly plan timeline + books.
Widget courseOutlinePlan(AppColors c, CourseOutlineData o) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (o.weeks.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text('Weekly plan',
              style: display(c, size: 17, color: c.tealInk)),
        ),
        for (final w in o.weeks)
          courseCard(
            c,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stable saturated teal: readable with white text in
                // light AND dark mode (tealInk flips light in dark).
                Container(
                  alignment: Alignment.center,
                  width: 34,
                  decoration: BoxDecoration(
                    color: c.teal,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text('W${w.week}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11)),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.contents,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: body(c,
                            size: 13, weight: FontWeight.w600)),
                    if (w.activity.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.bolt_outlined,
                              size: 13, color: c.clay),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(w.activity,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: body(c,
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color: c.clay)),
                          ),
                        ],
                      ),
                    ],
                  ],
                )),
              ],
            ),
          ),
      ],
      if (o.textbooks.isNotEmpty)
        courseKvCard(c, 'Textbooks', [
          for (final b in o.textbooks) [b.title, '${b.authors} · ${b.edition}']
        ]),
      if (o.references.isNotEmpty)
        courseKvCard(c, 'Reference books', [
          for (final b in o.references) [b.title, '${b.authors} · ${b.edition}']
        ]),
    ],
  );
}
