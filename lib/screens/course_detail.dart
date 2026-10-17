import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../auth/course_cache.dart';
import '../auth/course_detail.dart';
import '../auth/student_portal.dart' show PortalCourse;
import '../theme/palette.dart';
import '../web/portal_downloader.dart';
import '../widgets/common.dart';
import '../widgets/portal_state.dart';
import 'course_detail_state.dart';
import 'course_detail_tabs_a.dart';
import 'course_detail_tabs_b.dart';
import 'course_detail_tabs_c.dart';
import 'course_detail_tabs_d.dart';
import 'course_detail_tabs_e.dart';

/// Per-course hub: the 7 portal tabs for one course as native UI.
///
/// Opened from the Home course cards. Each tab lazily fetches its own
/// page on first open (memory → disk → network), so opening the hub
/// is instant and offline restarts still show real content.
class CourseDetailScreen extends StatefulWidget {
  final PortalCourse portalCourse;
  final String? sessionId;
  final VoidCallback? onSessionExpired;
  final VoidCallback back;

  /// Test seam: canned page HTML per tab key, skips all network.
  final Map<String, String>? debugHtml;

  const CourseDetailScreen({
    super.key,
    required this.portalCourse,
    required this.back,
    this.sessionId,
    this.onSessionExpired,
    this.debugHtml,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

const courseDetailTabs = [
  'news',
  'outline',
  'material',
  'assessments',
  'submission',
  'grades',
  'attendance',
];

String courseTabLabel(String t) {
  switch (t) {
    case 'news':
      return 'News';
    case 'outline':
      return 'Outline';
    case 'material':
      return 'Material';
    case 'assessments':
      return 'Assess';
    case 'submission':
      return 'Submit';
    case 'grades':
      return 'Grades';
    default:
      return 'Attend';
  }
}

IconData _tabIcon(String t) {
  switch (t) {
    case 'news':
      return Icons.campaign_outlined;
    case 'outline':
      return Icons.menu_book_outlined;
    case 'material':
      return Icons.folder_open_outlined;
    case 'assessments':
      return Icons.assignment_outlined;
    case 'submission':
      return Icons.upload_outlined;
    case 'grades':
      return Icons.grade_outlined;
    default:
      return Icons.fact_check_outlined;
  }
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late CourseDetailController ctl;
  PortalDownloader? _downloader;
  String? _busyDownload;

  @override
  void initState() {
    super.initState();
    ctl = CourseDetailController(
      portalCourse: widget.portalCourse,
      sessionId: widget.sessionId,
      debugHtml: widget.debugHtml,
    );
    ctl.addListener(_onCtl);
    ctl.loadTab('news');
  }

  @override
  void didUpdateWidget(CourseDetailScreen old) {
    super.didUpdateWidget(old);
    // CourseDetailController holds an immutable snapshot; rebuild it
    // when the course or session changes (e.g. silent renewal).
    if (widget.portalCourse.infoUrl != old.portalCourse.infoUrl ||
        widget.sessionId != old.sessionId) {
      ctl.removeListener(_onCtl);
      ctl.dispose();
      ctl = CourseDetailController(
        portalCourse: widget.portalCourse,
        sessionId: widget.sessionId,
        debugHtml: widget.debugHtml,
      );
      ctl.addListener(_onCtl);
      ctl.loadTab('news');
    }
  }

  void _onCtl() {
    if (!mounted) return;
    setState(() {});
    if (ctl.expired) widget.onSessionExpired?.call();
  }

  @override
  void dispose() {
    ctl.removeListener(_onCtl);
    ctl.dispose();
    _downloader?.dispose();
    super.dispose();
  }

  Future<void> _download(CourseMaterialItem item) async {
    if (_busyDownload != null) return;
    var url = item.downloadUrl;
    if (url.isEmpty) return;
    if (url.startsWith('/')) url = 'https://horizon.ucp.edu.pk$url';
    setState(() => _busyDownload = item.downloadUrl);
    try {
      _downloader ??= PortalDownloader();
      final dl = await _downloader!.start(
        url: url,
        sessionId: widget.sessionId,
        fileName: item.fileName.isEmpty ? null : item.fileName,
      );
      if (!mounted) return;
      setState(() => _busyDownload = null);
      final c = AppScope.colorsOf(context);
      final ok = dl.status == DownloadStatus.complete && dl.filePath != null;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved ${dl.fileName}'),
            backgroundColor: c.teal,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => _openFile(dl.filePath!),
            ),
          ),
        );
      } else if (dl.sessionExpired) {
        widget.onSessionExpired?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired — sign in again.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dl.error ?? 'Download failed.')),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _busyDownload = null);
    }
  }

  Future<void> _openFile(String path) async {
    try {
      await OpenFilex.open(path);
    } catch (_) {}
  }

  Widget buildScaffold(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final pc = ctl.portalCourse;
    if (ctl.loading && !ctl.hasData(ctl.tab)) {
      return PortalLoading(
          title: pc.name.isEmpty ? 'Course' : pc.name,
          subtitle: 'Loading ${courseTabLabel(ctl.tab)}…');
    }
    if (ctl.expired || (ctl.error != null && !ctl.hasData(ctl.tab))) {
      return PortalError(
        title: pc.name.isEmpty ? 'Course' : pc.name,
        message: ctl.expired
            ? 'Your portal session expired — sign in again.'
            : ctl.error!,
        onRetry: () => ctl.loadTab(ctl.tab),
        onRelogin: widget.onSessionExpired,
      );
    }
    return UHead(
      height: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.back,
            child: Row(
              children: [
                const Icon(Icons.arrow_back,
                    color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Text('Courses',
                    style: body(c,
                        size: 14,
                        weight: FontWeight.w600,
                        color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(pc.name.isEmpty ? 'Course' : pc.name,
              style: display(c, size: 24, color: Colors.white)),
          Text(
              '${pc.code} · ${pc.teacher}${pc.credits > 0 ? ' · ${pc.credits} cr' : ''}',
              style: body(c,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.8))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final t in courseDetailTabs)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => ctl.loadTab(t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: ctl.tab == t
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            children: [
                              Icon(_tabIcon(t),
                                  size: 14,
                                  color: ctl.tab == t
                                      ? c.tealInk
                                      : Colors.white),
                              const SizedBox(width: 4),
                              Text(courseTabLabel(t),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: ctl.tab == t
                                          ? c.tealInk
                                          : Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (ctl.loading) const PortalLoadingBar(),
          if (ctl.refreshFailed)
            PortalRefreshFailed(onRetry: () => ctl.loadTab(ctl.tab)),
          const SizedBox(height: 8),
          _tabBody(c),
          if (ctl.cachedAt != null)
            PortalCachedNotice(savedAtMs: ctl.cachedAt!),
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  Widget _tabBody(AppColors c) {
    final id = ctl.courseId;
    switch (ctl.tab) {
      case 'news':
        return courseNewsBody(c, CourseDetailCache.news[id] ?? const []);
      case 'outline':
        final o = CourseDetailCache.outline[id];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            courseOutlineBody(c, o),
            if (o != null && !o.isEmpty) courseOutlinePlan(c, o),
          ],
        );
      case 'material':
        return courseMaterialBody(
            c, CourseDetailCache.material[id] ?? const [],
            _busyDownload, _download);
      case 'assessments':
        return courseAssessBody(
            c, CourseDetailCache.assessments[id] ?? const []);
      case 'submission':
        return courseSubmissionBody(
            c, CourseDetailCache.submissions[id] ?? const []);
      case 'grades':
        return courseGradesBody(c, CourseDetailCache.gradebook[id]);
      default:
        return courseAttendanceBody(
            c, CourseDetailCache.attendance[id] ?? const []);
    }
  }

  @override
  Widget build(BuildContext context) => buildScaffold(context);
}
