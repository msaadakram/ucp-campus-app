import 'package:flutter/material.dart';

import '../auth/course_detail.dart';
import '../theme/palette.dart';
import 'course_detail_widgets.dart';

/// File-type icon + tint for material rows.
IconData _fileIcon(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
  if (n.endsWith('.doc') || n.endsWith('.docx')) {
    return Icons.description_outlined;
  }
  if (n.endsWith('.xls') || n.endsWith('.xlsx')) {
    return Icons.table_chart_outlined;
  }
  if (n.endsWith('.ppt') || n.endsWith('.pptx')) {
    return Icons.slideshow_outlined;
  }
  if (n.endsWith('.zip') || n.endsWith('.rar')) {
    return Icons.folder_zip_outlined;
  }
  if (n.endsWith('.cpp') || n.endsWith('.c') || n.endsWith('.py') ||
      n.endsWith('.java')) {
    return Icons.code_outlined;
  }
  return Icons.insert_drive_file_outlined;
}

/// Material tab body: subject-wise sections, each file keeping its
/// download wired to the parsed `/student/class/material/download/…`
/// link (grouping is derived — see [materialSubject]).
Widget courseMaterialBody(
  AppColors c,
  List<CourseMaterialItem> items,
  String? busyUrl,
  void Function(CourseMaterialItem) onDownload,
) {
  if (items.isEmpty) {
    return courseEmptyCard(
        c, Icons.folder_open_outlined, 'No files uploaded yet.');
  }
  // Group by subject, preserving the portal's upload order.
  final groups = <String, List<CourseMaterialItem>>{};
  for (final m in items) {
    (groups[m.subject.isEmpty ? 'Lecture Files' : m.subject] ??= []).add(m);
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final entry in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(entry.key,
                    style: display(c, size: 17, color: c.tealInk)),
              ),
              const SizedBox(width: 6),
              courseChip(c,
                  '${entry.value.length} file${entry.value.length == 1 ? '' : 's'}',
                  bg: c.teal.withValues(alpha: 0.10), fg: c.tealDeep),
            ],
          ),
        ),
        for (final m in entry.value)
          courseCard(
            c,
            child: Row(
              children: [
                courseIconTile(c, _fileIcon(m.fileName), c.teal),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: body(c,
                            size: 13, weight: FontWeight.w700)),
                    if (m.description.isNotEmpty)
                      Text(m.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: body(c,
                              size: 12,
                              color: c.tealInk.withValues(alpha: 0.55))),
                  ],
                )),
                const SizedBox(width: 8),
                _downloadButton(c, m, busyUrl, onDownload),
              ],
            ),
          ),
      ],
    ],
  );
}

Widget _downloadButton(
  AppColors c,
  CourseMaterialItem m,
  String? busyUrl,
  void Function(CourseMaterialItem) onDownload,
) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: busyUrl == null && m.downloadUrl.isNotEmpty
        ? () => onDownload(m)
        : null,
    child: Opacity(
      opacity: m.downloadUrl.isEmpty ? 0.4 : 1,
      child: Container(
        alignment: Alignment.center,
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [c.tealDeep, c.teal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: c.teal.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: busyUrl == m.downloadUrl
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation(Colors.white)))
            : const Icon(Icons.download, color: Colors.white, size: 18),
      ),
    ),
  );
}

/// Assessments tab body: due dates emphasized, type chip, posted muted.
Widget courseAssessBody(AppColors c, List<CourseAssessment> items) {
  if (items.isEmpty) {
    return courseEmptyCard(
        c, Icons.assignment_outlined, 'No assessments posted yet.');
  }
  return Column(
    children: [
      for (final a in items)
        courseCard(
          c,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              courseIconTile(c, Icons.event_outlined, c.clay),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: body(c, size: 14, weight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(child: courseChip(c, a.type)),
                      if (a.date.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                            child: courseChip(c, 'Posted ${a.date}')),
                      ],
                    ],
                  ),
                  if (a.dueDate.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule_outlined,
                            size: 14, color: c.clay),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text('Due ${a.dueDate}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: body(c,
                                  size: 12,
                                  weight: FontWeight.w800,
                                  color: c.clay)),
                        ),
                      ],
                    ),
                  ],
                ],
              )),
            ],
          )),
    ],
  );
}

/// Submissions tab body: window cards with start → due flow.
Widget courseSubmissionBody(AppColors c, List<CourseSubmission> items) {
  if (items.isEmpty) {
    return courseEmptyCard(c, Icons.upload_outlined,
        'No submissions required right now.');
  }
  return Column(
    children: [
      for (final s in items)
        courseCard(
          c,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              courseIconTile(c, Icons.upload_outlined, c.board),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: body(c, size: 14, weight: FontWeight.w800)),
                  if (s.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(s.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: body(c,
                            size: 13,
                            color: c.tealInk.withValues(alpha: 0.7))),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.play_arrow_outlined,
                          size: 14, color: c.teal),
                      const SizedBox(width: 3),
                      Flexible(
                          child: Text(s.startDate,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: body(c,
                                  size: 12,
                                  color: c.tealInk
                                      .withValues(alpha: 0.6)))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward,
                            size: 13, color: c.tealInk.withValues(alpha: 0.4)),
                      ),
                      Icon(Icons.schedule_outlined,
                          size: 14, color: c.clay),
                      const SizedBox(width: 3),
                      Flexible(
                          child: Text(s.dueDate,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: body(c,
                                  size: 12,
                                  weight: FontWeight.w700,
                                  color: c.clay))),
                    ],
                  ),
                ],
              )),
            ],
          )),
    ],
  );
}
