import 'student_portal.dart';

/// Last-good portal data for the current app session, so tabs keep showing
/// real content when the device goes offline.
///
/// Raw portal pages are ~1.4 MB of HTML — far too big for secure storage —
/// so this keeps the small parsed models in memory instead. It survives tab
/// switches (which dispose each screen's State) but not app restarts; Home
/// additionally keeps its dashboard snapshot in encrypted storage.
/// Cleared on logout. Pure data holder, unit-tested via its API.
class PortalCache {
  static TimetableData? timetable;
  static DatesheetData? datesheet;
  static List<AttendanceCourse>? attendance;
  static List<Invoice>? invoices;
  static ResultsData? results;

  /// Epoch millis of each successful load, keyed like the fields above.
  static final Map<String, int> savedAt = {};

  static void putTimetable(TimetableData data, DatesheetData ds) {
    timetable = data;
    datesheet = ds;
    savedAt['timetable'] = DateTime.now().millisecondsSinceEpoch;
  }

  static void putAttendance(List<AttendanceCourse> list) {
    attendance = list;
    savedAt['attendance'] = DateTime.now().millisecondsSinceEpoch;
  }

  static void putInvoices(List<Invoice> list) {
    invoices = list;
    savedAt['invoices'] = DateTime.now().millisecondsSinceEpoch;
  }

  static void putResults(ResultsData data) {
    results = data;
    savedAt['results'] = DateTime.now().millisecondsSinceEpoch;
  }

  static void clear() {
    timetable = null;
    datesheet = null;
    attendance = null;
    invoices = null;
    results = null;
    savedAt.clear();
  }
}
