import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/course_cache.dart';
import '../auth/course_detail.dart';
import '../auth/odoo_api.dart';
import '../auth/offline.dart';
import '../auth/page_cache.dart';
import '../auth/portal_api.dart';
import '../auth/student_portal.dart' show PortalCourse;

/// Per-course hub state: the 7 portal tabs for one course.
///
/// Dashboard `infoUrl` gives the course id → [CourseTabRoutes].
/// Each tab lazily fetches its own page on first open
/// (memory → disk → network, same 3-tier as other portal screens).
class CourseDetailController extends ChangeNotifier {
  final PortalCourse portalCourse;
  final String? sessionId;
  final Map<String, String>? debugHtml;

  CourseDetailController({
    required this.portalCourse,
    this.sessionId,
    this.debugHtml,
  });

  String tab = 'news';
  bool loading = true;
  bool expired = false;
  String? error;
  bool refreshFailed = false;
  bool cachedOffline = false;
  int? cachedAt;

  CourseTabRoutes? get routes =>
      courseTabsFromInfoUrl(portalCourse.infoUrl);

  String get courseId => routes?.id ?? '';

  String? routeFor(String t) {
    final r = routes;
    if (r == null) return null;
    switch (t) {
      case 'news':
        return r.news;
      case 'outline':
        return r.outline;
      case 'material':
        return r.material;
      case 'assessments':
        return r.assessments;
      case 'submission':
        return r.submission;
      case 'grades':
        return r.gradebook;
      case 'attendance':
        return r.attendance;
      default:
        return null;
    }
  }

  bool hasData(String t) {
    final id = courseId;
    if (id.isEmpty) return false;
    switch (t) {
      case 'news':
        return CourseDetailCache.news.containsKey(id);
      case 'outline':
        return CourseDetailCache.outline.containsKey(id);
      case 'material':
        return CourseDetailCache.material.containsKey(id);
      case 'assessments':
        return CourseDetailCache.assessments.containsKey(id);
      case 'submission':
        return CourseDetailCache.submissions.containsKey(id);
      case 'grades':
        return CourseDetailCache.gradebook.containsKey(id);
      case 'attendance':
        return CourseDetailCache.attendance.containsKey(id);
      default:
        return false;
    }
  }

  Future<String> _fetch(String path, String t) {
    final dbg = debugHtml;
    if (dbg != null) {
      final key = t == 'grades' ? 'gradebook' : t;
      final html = dbg[key] ?? dbg[t];
      if (html != null) return Future.value(html);
    }
    final sid = sessionId;
    if (sid == null || sid.isEmpty) {
      return Future.error(OdooApiException('no portal session'));
    }
    return PortalApi().fetchPage(path, sid);
  }

  void storeParsed(String id, String t, String html) {
    switch (t) {
      case 'news':
        CourseDetailCache.putNews(id, parseCourseNews(html));
        break;
      case 'outline':
        CourseDetailCache.putOutline(id, parseCourseOutline(html));
        break;
      case 'material':
        CourseDetailCache.putMaterial(id, parseCourseMaterial(html));
        break;
      case 'assessments':
        CourseDetailCache.putAssessments(id, parseCourseAssessments(html));
        break;
      case 'submission':
        CourseDetailCache.putSubmissions(id, parseCourseSubmissions(html));
        break;
      case 'grades':
        CourseDetailCache.putGradebook(id, parseCourseGradebook(html));
        break;
      case 'attendance':
        CourseDetailCache.putAttendance(id, parseCourseAttendance(html));
        break;
    }
  }

  Future<void> loadTab(String t) async {
    tab = t;
    loading = true;
    if (!hasData(t)) {
      error = null;
      expired = false;
      cachedOffline = false;
      cachedAt = null;
    }
    refreshFailed = false;
    notifyListeners();
    final id = courseId;
    final route = routeFor(t);
    if (id.isEmpty || route == null) {
      loading = false;
      error = 'This course has no portal link — open it from the Web view.';
      notifyListeners();
      return;
    }
    if (!hasData(t) && debugHtml == null) {
      final snap = await PageCache.loadPage('course_${id}_$t');
      if (tab != t) return;
      if (snap != null) {
        try {
          storeParsed(id, t, snap.html);
          cachedOffline = true;
          cachedAt = snap.savedAtMs;
          notifyListeners();
        } catch (_) {}
      }
    }
    if (debugHtml == null && OfflineMonitor.instance.isOffline) {
      loading = false;
      if (!hasData(t)) error = offlineMessage;
      notifyListeners();
      return;
    }
    try {
      final html = await _fetch(route, t);
      if (tab != t) return;
      storeParsed(id, t, html);
      unawaited(PageCache.savePage('course_${id}_$t', html));
      loading = false;
      cachedOffline = false;
      cachedAt = null;
      notifyListeners();
    } on OdooApiException catch (e) {
      if (tab != t) return;
      final dead = e.message.contains('expired') ||
          e.message.contains('login') ||
          e.message.contains('no portal session');
      loading = false;
      if (dead && !hasData(t)) {
        expired = true;
      } else if (!hasData(t)) {
        error = e.message;
      } else {
        refreshFailed = true;
      }
      notifyListeners();
    } catch (_) {
      if (tab != t) return;
      loading = false;
      if (!hasData(t)) {
        error = 'Could not load $t. Check connection.';
      } else {
        refreshFailed = true;
      }
      notifyListeners();
    }
  }
}
