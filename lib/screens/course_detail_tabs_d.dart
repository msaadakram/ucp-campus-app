import 'package:flutter/material.dart';

import '../auth/course_detail.dart';
import '../theme/palette.dart';
import 'course_detail_widgets.dart';

/// Material tab body with download buttons.
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
  return Column(
    children: [
      for (final m in items)
        courseRowCard(
          c,
          Row(
            children: [
              Container(
                alignment: Alignment.center,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: c.dustSoft,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.insert_drive_file_outlined,
                    color: c.tealInk, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: body(c, size: 13, weight: FontWeight.w600)),
                  if (m.description.isNotEmpty)
                    Text(m.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: body(c,
                            size: 12,
                            color: c.tealInk.withValues(alpha: 0.55))),
                ],
              )),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: busyUrl == null && m.downloadUrl.isNotEmpty
                    ? () => onDownload(m)
                    : null,
                child: Container(
                  alignment: Alignment.center,
                  width: 40,
                  height: 40,
                  decoration:
                      BoxDecoration(color: c.teal, shape: BoxShape.circle),
                  child: busyUrl == m.downloadUrl
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white)))
                      : const Icon(Icons.download,
                          color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// Assessments tab body.
Widget courseAssessBody(AppColors c, List<CourseAssessment> items) {
  if (items.isEmpty) {
    return courseEmptyCard(
        c, Icons.assignment_outlined, 'No assessments posted yet.');
  }
  return Column(
    children: [
      for (final a in items)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: c.white, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(a.name,
                          style: body(c,
                              size: 14, weight: FontWeight.bold))),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: c.dustSoft,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(a.type,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: c.tealInk)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Posted ${a.date}',
                  style: body(c,
                      size: 12,
                      color: c.tealInk.withValues(alpha: 0.55))),
              Text('Due ${a.dueDate}',
                  style: body(c,
                      size: 12, weight: FontWeight.w600, color: c.clay)),
            ],
          ),
        ),
    ],
  );
}

/// Submissions tab body.
Widget courseSubmissionBody(AppColors c, List<CourseSubmission> items) {
  if (items.isEmpty) {
    return courseEmptyCard(c, Icons.upload_outlined,
        'No submissions required right now.');
  }
  return Column(
    children: [
      for (final s in items)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: c.white, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.name,
                  style: body(c, size: 14, weight: FontWeight.bold)),
              if (s.description.isNotEmpty)
                Text(s.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: body(c, size: 13)),
              const SizedBox(height: 6),
              Text('${s.startDate} → ${s.dueDate}',
                  style: body(c,
                      size: 12,
                      color: c.tealInk.withValues(alpha: 0.55))),
            ],
          ),
        ),
    ],
  );
}
