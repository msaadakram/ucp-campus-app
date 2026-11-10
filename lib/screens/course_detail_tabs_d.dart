import 'package:flutter/material.dart';

import '../auth/course_detail.dart';
import '../auth/portal_dates.dart';
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
///
/// [downloaded] carries the file names that already exist on disk — the
/// button renders as "Open" for those (a second tap never re-fetches).
Widget courseMaterialBody(
  AppColors c,
  List<CourseMaterialItem> items,
  String? busyUrl,
  void Function(CourseMaterialItem) onDownload, {
  Set<String> downloaded = const {},
}) {
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
                    if (downloaded.contains(m.fileName)) ...[
                      const SizedBox(height: 4),
                      courseChip(c, 'Saved · tap Open',
                          bg: c.teal.withValues(alpha: 0.10),
                          fg: c.tealDeep),
                    ],
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
                _downloadButton(c, m, busyUrl, onDownload,
                    saved: downloaded.contains(m.fileName)),
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
  void Function(CourseMaterialItem) onDownload, {
  bool saved = false,
}) {
  return Tooltip(
    message: saved ? 'Open saved file' : 'Download',
    child: GestureDetector(
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
              : Icon(saved ? Icons.open_in_new_rounded : Icons.download,
                  color: Colors.white, size: 18),
        ),
      ),
    ),
  );
}

/// Icon for an assessment type, keyword-matched (the portal
/// re-states the type as free text).
IconData _typeIcon(String type) {
  final t = type.toLowerCase();
  if (t.contains('quiz')) return Icons.quiz_outlined;
  if (t.contains('assign')) return Icons.assignment_outlined;
  if (t.contains('lab')) return Icons.science_outlined;
  if (t.contains('project')) return Icons.cases_outlined;
  if (t.contains('present') || t.contains('seminar')) {
    return Icons.slideshow_outlined;
  }
  if (t.contains('final')) return Icons.school_outlined;
  if (t.contains('mid')) return Icons.event_note_outlined;
  if (t.contains('activity') || t.contains('participation')) {
    return Icons.groups_outlined;
  }
  if (t.contains('cp')) return Icons.verified_outlined;
  return Icons.task_alt_outlined;
}

/// Colour tone for a type icon (stable across the list).
Color _typeTone(AppColors c, String type) {
  final t = type.toLowerCase();
  if (t.contains('final') || t.contains('mid')) return c.board;
  if (t.contains('quiz')) return c.teal;
  if (t.contains('activity') || t.contains('participation')) {
    return c.clay;
  }
  return c.teal;
}

/// Short countdown label + tone for a due timestamp.
({String text, Color tone}) _dueInfo(AppColors c, DateTime? due) {
  const none = Color(0xFF8A8F96);
  if (due == null) {
    return (text: 'No due date set', tone: none);
  }
  final now = DateTime.now();
  final delta = dueDayDelta(now, due);
  final time = formatPortalTime(due);
  if (delta < 0) {
    final days = -delta;
    final label = days == 1 ? 'day' : 'days';
    // Overdue by years: keep the pill short; the date is spelled out
    // next to it anyway.
    return days > 60
        ? (text: 'Late by $days days', tone: c.clay)
        : (
            text: 'Late by $days $label · $time',
            tone: c.clay,
          );
  }
  if (delta == 0) return (text: 'Today · $time', tone: c.clay);
  if (delta == 1) return (text: 'Tomorrow · $time', tone: c.board);
  if (delta <= 7) {
    return (
      text: 'In $delta days · $time',
      tone: c.board,
    );
  }
  return (text: 'In $delta days', tone: c.teal);
}

/// Caption telling when the row was posted (parsed to a date when
/// possible); otherwise just the raw cell text.
String _postedLabel(CourseAssessment a) {
  final p = a.posted;
  if (p != null) return 'Posted ${formatPortalDay(p)}';
  if (a.date.isNotEmpty) return 'Posted ${a.date}';
  return '';
}

/// Assessments tab body: headline stats, then due/soon/upcoming sections
/// grouped with the type kept inline.
Widget courseAssessBody(AppColors c, List<CourseAssessment> items) {
  if (items.isEmpty) {
    return courseEmptyCard(
        c, Icons.assignment_outlined, 'No assessments posted yet.');
  }
  final now = DateTime.now();
  final overdue = <CourseAssessment>[];
  final dueSoon = <CourseAssessment>[];
  final upcoming = <CourseAssessment>[];
  final unscheduled = <CourseAssessment>[];
  for (final a in items) {
    if (a.due == null) {
      unscheduled.add(a);
      continue;
    }
    final delta = dueDayDelta(now, a.due!);
    if (delta < 0) {
      overdue.add(a);
    } else if (delta <= 7) {
      dueSoon.add(a);
    } else {
      upcoming.add(a);
    }
  }
  int byDue(CourseAssessment a, CourseAssessment b) =>
      a.due!.compareTo(b.due!);
  overdue.sort(byDue);
  dueSoon.sort(byDue);
  upcoming.sort(byDue);
  int uploadable =
      items.where((a) => a.canUpload).length;

  Widget card(CourseAssessment a) {
    final posted = _postedLabel(a);
    final due = _dueInfo(c, a.due);
    return courseCard(
      c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              courseIconTile(c, _typeIcon(a.type), _typeTone(c, a.type)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: body(c, size: 14, weight: FontWeight.w800)),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (a.type.isNotEmpty)
                          courseChip(c, a.type,
                              bg: c.teal.withValues(alpha: 0.10),
                              fg: c.tealDeep),
                        if (posted.isNotEmpty) courseChip(c, posted),
                        courseStatusPill(
                          c,
                          text: a.canUpload ? 'Upload open' : 'Upload closed',
                          tone: a.canUpload ? c.teal : Color(0xFF8A8F96),
                          icon: a.canUpload
                              ? Icons.upload_rounded
                              : Icons.lock_outline,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.cream2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.dustSoft.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 15, color: due.tone),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        a.due != null
                            ? 'Due ${formatPortalStamp(a.due!)}'
                            : 'Due date not published',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: body(c,
                            size: 12,
                            weight: FontWeight.w800,
                            color: c.tealInk),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                courseStatusPill(c,
                    text: due.text, tone: due.tone, icon: Icons.hourglass_top),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget section(String title, List<CourseAssessment> list, {Color? tone}) {
    if (list.isEmpty) return const SizedBox();
    return Column(
      children: [
        courseSectionHeader(c, title, trailing: '${list.length}'),
        for (final a in list) card(a),
      ],
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      courseCard(
        c,
        child: Row(
          children: [
            Expanded(
              child: courseStat(
                  c, '${overdue.length}', 'Overdue',
                  tone: overdue.isEmpty ? c.teal : c.clay),
            ),
            Expanded(child: courseStat(c, '${dueSoon.length}', 'Due this week', tone: c.board)),
            Expanded(child: courseStat(c, '${items.length}', 'Posted', tone: c.tealDeep)),
            Expanded(
              child: courseStat(c, '$uploadable', 'Upload open',
                  tone: uploadable > 0 ? c.teal : const Color(0xFF8A8F96)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      section('Overdue', overdue),
      section('Due this week', dueSoon),
      section('Upcoming', upcoming),
      section('Unscheduled', unscheduled),
    ],
  );
}

/// Submissions tab body: stat strip, then a card per window with the
/// open/upcoming/closed state, the full window bounds and a window
/// progress line. [onDownload] opens the portal file attachment via the
/// same pipeline the Material tab uses (used when the attachment cell
/// carried a link).
Widget courseSubmissionBody(AppColors c, List<CourseSubmission> items,
    {void Function(CourseMaterialItem)? onDownload}) {
  if (items.isEmpty) {
    return courseEmptyCard(c, Icons.upload_outlined,
        'No submissions required right now.');
  }
  String stateOf(CourseSubmission s) => s.windowState;
  final counts = <String, int>{'open': 0, 'upcoming': 0, 'closed': 0};
  for (final s in items) {
    counts[stateOf(s)] = (counts[stateOf(s)] ?? 0) + 1;
  }

  Widget cardFor(CourseSubmission s) {
    final state = stateOf(s);
    final tone = switch (state) {
      'upcoming' => c.board,
      'closed' => c.clay,
      _ => c.teal,
    };
    final pill = switch (state) {
      'upcoming' => 'Upcoming',
      'closed' => 'Closed',
      _ => 'Open now',
    };
    final pillIcon = switch (state) {
      'upcoming' => Icons.hourglass_empty_rounded,
      'closed' => Icons.lock_outline_rounded,
      _ => Icons.lock_open_rounded,
    };

    // Window progress: 0 before open, 1 after close, fractional inside.
    double fill = 0;
    double daysLeft = 0;
    if (s.from != null && s.to != null && s.to!.isAfter(s.from!)) {
      final now = DateTime.now();
      if (now.isBefore(s.from!)) {
        fill = 0;
      } else if (now.isAfter(s.to!)) {
        fill = 1;
      } else {
        fill = now.difference(s.from!).inSeconds /
            s.to!.difference(s.from!).inSeconds;
        daysLeft = s.to!.difference(now).inHours / 24;
      }
    }

    String windowLine(String label, DateTime? dt, String raw) {
      if (dt != null) return '$label ${formatPortalStamp(dt)}';
      return raw.isNotEmpty ? '$label $raw' : '$label —';
    }

    return courseCard(
      c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              courseIconTile(c, Icons.upload_outlined, tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(s.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: body(c, size: 14, weight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 8),
                        courseStatusPill(c,
                            text: pill, tone: tone, icon: pillIcon),
                      ],
                    ),
                    if (s.attachmentName.isNotEmpty || s.hasAttachment) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.attach_file_rounded,
                              size: 14, color: c.teal),
                          const SizedBox(width: 4),
                          Expanded(child: Text('Attachment included',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: body(c,
                                  size: 11.5,
                                  weight: FontWeight.w700,
                                  color: c.teal))),
                        ],
                      ),
                    ],
                    if (s.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(s.description,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: body(c,
                              size: 12,
                              color: c.tealInk.withValues(alpha: 0.68))),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (s.attachmentUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: c.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: c.dustSoft.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  courseIconTile(c, _fileIcon(s.attachmentName), c.teal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.attachmentName.isNotEmpty
                              ? s.attachmentName
                              : 'Attached file',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(c, size: 12.5, weight: FontWeight.w800),
                        ),
                        Text(
                          'Save / open in the app',
                          style: body(c,
                              size: 10,
                              color: c.tealInk.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ),
                  if (onDownload != null)
                    _downloadButton(
                      c,
                      CourseMaterialItem(
                        fileName: s.attachmentName.isNotEmpty
                            ? s.attachmentName
                            : 'attachment',
                        description: s.name,
                        downloadUrl: s.attachmentUrl,
                      ),
                      null,
                      onDownload,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 11),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.cream2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.dustSoft.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.play_arrow_rounded,
                        size: 15, color: c.teal),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(windowLine('Opens', s.from, s.startDate),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(c,
                              size: 12,
                              weight: FontWeight.w700,
                              color: c.tealInk.withValues(alpha: 0.8))),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 13,
                          color: c.tealInk.withValues(alpha: 0.35)),
                    ),
                    Icon(Icons.schedule_rounded, size: 15, color: c.clay),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(windowLine('Closes', s.to, s.dueDate),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(c,
                              size: 12,
                              weight: FontWeight.w800,
                              color: c.clay)),
                    ),
                  ],
                ),
                if (s.from != null && s.to != null && s.to!.isAfter(s.from!)) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fill.clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: c.dustSoft.withValues(alpha: 0.6),
                      valueColor: AlwaysStoppedAnimation(tone),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state == 'upcoming'
                        ? 'Opens ${s.from != null ? formatPortalStamp(s.from!) : s.startDate}'
                        : state == 'closed'
                            ? 'Window closed ${s.to != null ? formatPortalStamp(s.to!) : s.dueDate}'
                            : '${daysLeft.ceil()} day${daysLeft.ceil() == 1 ? '' : 's'} left · ${(fill * 100).toStringAsFixed(0)}% of the window used',
                    style: body(c,
                        size: 10.5,
                        weight: FontWeight.w700,
                        color: c.tealInk.withValues(alpha: 0.55)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      courseCard(c,
          child: Row(
        children: [
          Expanded(
              child: courseStat(c, '${counts['open']}', 'Open now',
                  tone: c.teal)),
          Expanded(
              child: courseStat(c, '${counts['upcoming']}', 'Upcoming',
                  tone: c.board)),
          Expanded(
              child: courseStat(c, '${counts['closed']}', 'Closed',
                  tone: counts['closed']! > 0 ? c.clay : Color(0xFF8A8F96))),
          Expanded(
              child: courseStat(c, '${items.length}', 'Total',
                  tone: c.tealDeep)),
        ],
      )),
      const SizedBox(height: 4),
      for (final s in items) cardFor(s),
    ],
  );
}
