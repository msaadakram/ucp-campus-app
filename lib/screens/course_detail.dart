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

  /// Test seam: downloader override (fakes record calls; production
  /// creates a real one lazily).
  final PortalDownloader? downloader;

  /// Test seam: file-opener override. Null (production) opens via
  /// OpenFilex. Set to record auto-opens in widget tests.
  final Future<void> Function(String path)? onOpenFile;

  /// First tab to load ('news' by default). The bottom-bar Material
  /// entry opens the hub straight on 'material'.
  final String initialTab;

  /// Opens the live leaderboard for this course (Grades tab button).
  final void Function(String courseName)? onOpenLeaderboard;

  const CourseDetailScreen({
    super.key,
    required this.portalCourse,
    required this.back,
    this.sessionId,
    this.onSessionExpired,
    this.debugHtml,
    this.downloader,
    this.onOpenFile,
    this.initialTab = 'news',
    this.onOpenLeaderboard,
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
    ctl.loadTab(_validTab(widget.initialTab));
  }

  static String _validTab(String t) =>
      courseDetailTabs.contains(t) ? t : 'news';

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
      ctl.loadTab(_validTab(widget.initialTab));
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
    _downloader ??= widget.downloader ?? PortalDownloader();
    // Already in storage from an earlier download? Open it directly —
    // no re-fetch. "Download again" in the snackbar forces a fresh copy.
    final saved =
        item.fileName.isEmpty ? null : await _downloader!.findDownloaded(item.fileName);
    if (saved != null) {
      if (!mounted) return;
      _openFile(saved);
      final c = AppScope.colorsOf(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening saved ${item.fileName}'),
          backgroundColor: c.teal,
          action: SnackBarAction(
            label: 'Download again',
            textColor: Colors.white,
            onPressed: () => _fetchAndOpen(item),
          ),
        ),
      );
      return;
    }
    await _fetchAndOpen(item);
  }

  /// Downloads the file, then AUTO-OPENS it once (the requested
  /// "open after one-time download" behavior).
  Future<void> _fetchAndOpen(CourseMaterialItem item) async {
    if (_busyDownload != null) return;
    var url = item.downloadUrl;
    if (url.isEmpty) return;
    if (url.startsWith('/')) url = 'https://horizon.ucp.edu.pk$url';
    setState(() => _busyDownload = item.downloadUrl);
    try {
      _downloader ??= widget.downloader ?? PortalDownloader();
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
        _openFile(dl.filePath!); // auto-open right after the download
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
    final opener = widget.onOpenFile;
    if (opener != null) {
      try {
        await opener(path);
      } catch (_) {}
      return;
    }
    try {
      await OpenFilex.open(path);
    } catch (_) {}
  }

  /// Soft translucent disc for the hero band (same motif as Teachers).
  Widget _deco(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: alpha),
          shape: BoxShape.circle,
        ),
      );

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
    final sel = ctl.tab;
    return UHead(
      height: 258,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero band: glass back pill + code chips + title + tab bar.
          Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                  right: -40, top: -50, child: _deco(140, 0.07)),
              Positioned(
                  left: 60, top: -60, child: _deco(110, 0.05)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.back,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back,
                              color: Colors.white, size: 16),
                          Text('  Courses',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (pc.code.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(pc.code.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (pc.credits > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${pc.credits} cr',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(pc.name.isEmpty ? 'Course' : pc.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: display(c, size: 25, color: Colors.white)),
                  if (pc.teacher.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(pc.teacher,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: body(c,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.8))),
                  ],
                  const SizedBox(height: 14),
                  _tabBar(c, sel),
                ],
              ),
            ],
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

  /// Frosted pill bar; selected = white pill with tealDeep text (readable
  /// in dark mode too — tealInk flips light there) + soft elevation.
  Widget _tabBar(AppColors c, String sel) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in courseDetailTabs)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ctl.loadTab(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: t == sel ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: t == sel
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(_tabIcon(t),
                            size: 14,
                            color:
                                t == sel ? c.tealDeep : Colors.white),
                        const SizedBox(width: 5),
                        Text(courseTabLabel(t),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: t == sel
                                    ? c.tealDeep
                                    : Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
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
        return courseGradesBody(
          c,
          CourseDetailCache.gradebook[id],
          widget.onOpenLeaderboard == null
              ? null
              : () => widget.onOpenLeaderboard!(ctl.portalCourse.name),
        );
      default:
        return courseAttendanceBody(
            c, CourseDetailCache.attendance[id] ?? const []);
    }
  }

  @override
  Widget build(BuildContext context) => buildScaffold(context);
}
