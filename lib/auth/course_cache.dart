import 'course_detail.dart';

/// Last-good per-course tab data for the current app session, so the
/// Course Detail screen keeps showing real content when the device
/// goes offline. Mirrors [PortalCache]: in-memory only (cleared on
/// logout), keyed by course id + tab name.
///
/// Raw course pages are ~1.4 MB of HTML each — far too big for secure
/// storage — so this keeps the small parsed models instead. On-disk
/// snapshots live in [PageCache] under `course_<id>_<tab>`.
class CourseDetailCache {
  static final Map<String, List<CourseNewsItem>> news = {};
  static final Map<String, CourseOutlineData> outline = {};
  static final Map<String, List<CourseMaterialItem>> material = {};
  static final Map<String, List<CourseAssessment>> assessments = {};
  static final Map<String, List<CourseSubmission>> submissions = {};
  static final Map<String, CourseGradebook> gradebook = {};
  static final Map<String, List<CourseAttendanceRow>> attendance = {};

  /// Epoch millis of each successful tab load, keyed `"<id>/<tab>"`.
  static final Map<String, int> savedAt = {};

  static void _stamp(String id, String tab) =>
      savedAt['$id/$tab'] = DateTime.now().millisecondsSinceEpoch;

  static void putNews(String id, List<CourseNewsItem> v) {
    news[id] = v;
    _stamp(id, 'news');
  }

  static void putOutline(String id, CourseOutlineData v) {
    outline[id] = v;
    _stamp(id, 'outline');
  }

  static void putMaterial(String id, List<CourseMaterialItem> v) {
    material[id] = v;
    _stamp(id, 'material');
  }

  static void putAssessments(String id, List<CourseAssessment> v) {
    assessments[id] = v;
    _stamp(id, 'assessments');
  }

  static void putSubmissions(String id, List<CourseSubmission> v) {
    submissions[id] = v;
    _stamp(id, 'submissions');
  }

  static void putGradebook(String id, CourseGradebook v) {
    gradebook[id] = v;
    _stamp(id, 'gradebook');
  }

  static void putAttendance(String id, List<CourseAttendanceRow> v) {
    attendance[id] = v;
    _stamp(id, 'attendance');
  }

  static void clear() {
    news.clear();
    outline.clear();
    material.clear();
    assessments.clear();
    submissions.clear();
    gradebook.clear();
    attendance.clear();
    savedAt.clear();
  }
}
