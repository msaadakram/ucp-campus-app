import 'package:flutter/material.dart';

import '../auth/course_detail.dart';
import '../theme/palette.dart';
import 'course_detail_widgets.dart';

/// News tab body.
Widget courseNewsBody(AppColors c, List<CourseNewsItem> items) {
  if (items.isEmpty) {
    return courseEmptyCard(
        c, Icons.campaign_outlined, 'No announcements for this course.');
  }
  return Column(
    children: [
      for (final n in items)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: c.white, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(n.subject,
                          style: body(c,
                              size: 15, weight: FontWeight.bold))),
                  if (n.hasAttachment)
                    Icon(Icons.attach_file, size: 16, color: c.teal),
                ],
              ),
              if (n.date.isNotEmpty)
                Text(n.date,
                    style: body(c,
                        size: 12,
                        color: c.tealInk.withValues(alpha: 0.55))),
              if (n.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(n.description, style: body(c, size: 13)),
              ],
            ],
          ),
        ),
    ],
  );
}
