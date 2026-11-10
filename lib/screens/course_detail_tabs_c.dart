import 'package:flutter/material.dart';

import '../auth/course_detail.dart';
import '../theme/palette.dart';
import 'course_detail_widgets.dart';

const _bookTones = [
  Color(0xFF1789B8),
  Color(0xFFF4A82A),
  Color(0xFF8FAE6E),
  Color(0xFFEE6A24),
];

/// Outline tab part 2: weekly plan timeline + books.
Widget courseOutlinePlan(AppColors c, CourseOutlineData o) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (o.weeks.isNotEmpty) ...[
        courseSectionHeader(c, 'Weekly plan',
            trailing: '${o.weeks.length} teaching week${o.weeks.length == 1 ? '' : 's'}'),
        courseCard(
          c,
          padding: const EdgeInsets.all(13),
          child: Column(
            children: [
              for (var i = 0; i < o.weeks.length; i++)
                _weekRow(c, o.weeks[i], i == o.weeks.length - 1),
            ],
          ),
        ),
      ],
      if (o.textbooks.isNotEmpty)
        _booksSection(
            c, 'Textbooks', o.textbooks, 'Core reading for this course'),
      if (o.references.isNotEmpty)
        _booksSection(
            c, 'Reference books', o.references, 'Optional but useful'),
    ],
  );
}

/// One week on the timeline: week chip on a connecting rail, topics and
/// the activity chip if the portal recorded one.
Widget _weekRow(AppColors c, CourseWeek w, bool last) {
  final activity = w.activity.trim();
  return IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c.tealDeep, c.teal]),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text('${int.tryParse(w.week) ?? w.week}',
                  maxLines: 1,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ),
            if (!last)
              Expanded(
                child: Container(
                  width: 2.5,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: c.dustSoft.withValues(alpha: 0.8),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.contents,
                    style: body(c, size: 12.5, weight: FontWeight.w600,
                        color: c.tealInk)),
                if (w.activity.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.bolt_outlined, size: 13, color: Color(0xFFEE6A24)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(activity,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: body(c,
                                size: 11.5,
                                weight: FontWeight.w700,
                                color: c.clay)),
                      ),
                      if (w.hasFiles) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.attach_file_rounded,
                            size: 13, color: Color(0xFF8FAE6E)),
                      ],
                    ],
                  ),
                ],
                if (w.activity.isEmpty && w.hasFiles) ...[
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(Icons.attach_file_rounded,
                          size: 13, color: Color(0xFF8FAE6E)),
                      SizedBox(width: 4),
                      Text('Lecture files published',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8FAE6E))),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _booksSection(
  AppColors c,
  String title,
  List<CourseBook> books,
  String subtitle,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      courseSectionHeader(c, title, trailing: '${books.length}'),
      Text(subtitle,
          style: body(c,
              size: 11,
              color: c.tealInk.withValues(alpha: 0.5))),
      const SizedBox(height: 8),
      for (var i = 0; i < books.length; i++)
        courseBookTile(
          c,
          index: i,
          title: books[i].title,
          authors: books[i].authors,
          edition: books[i].edition,
          publisher: books[i].publisher,
          year: books[i].year,
          description: books[i].description,
          tone: _bookTones[i % _bookTones.length],
        ),
      const SizedBox(height: 4),
    ],
  );
}
