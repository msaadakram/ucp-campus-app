import 'package:flutter/material.dart';

import '../auth/course_detail.dart';
import '../theme/palette.dart';
import 'course_detail_widgets.dart';

/// News tab body: announcement cards with icon tile, date pill, body.
Widget courseNewsBody(AppColors c, List<CourseNewsItem> items) {
  if (items.isEmpty) {
    return courseEmptyCard(
        c, Icons.campaign_outlined, 'No announcements for this course.');
  }
  return Column(
    children: [
      for (final n in items)
        courseCard(
          c,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              courseIconTile(c, Icons.campaign_outlined, c.teal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(n.subject,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: body(c,
                                    size: 15, weight: FontWeight.w800))),
                        if (n.hasAttachment)
                          Icon(Icons.attach_file,
                              size: 16, color: c.teal),
                      ],
                    ),
                    if (n.date.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      courseChip(c, n.date,
                          bg: c.teal.withValues(alpha: 0.10),
                          fg: c.tealDeep),
                    ],
                    if (n.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(n.description,
                          style: body(c,
                              size: 13,
                              color: c.tealInk.withValues(alpha: 0.75))),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
