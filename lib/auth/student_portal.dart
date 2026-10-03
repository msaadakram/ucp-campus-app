/// Student portal pages: routes, models and exact HTML parsers.
///
/// Route map reverse-engineered from the portal sidebar links:
/// dashboard, attendance, class/schedule, invoices, results,
/// exam/datesheet, profile. Selector mapping was verified against real
/// saved pages (Odoo 15 + Altair admin theme):
///
/// - timetable : `.cd-schedule__group` per weekday; each
///   `li.cd-schedule__event > a[data-start][data-end]` holds spans in
///   fixed order: teacher, subject, section code, room.
/// - attendance: `h3` = "{Course} Attendance: {pct}%" (title in a div
///   row) + `table.uk-table`: Sr. no | Date | Status | Fine.
/// - invoices  : `table.uk-table-nowrap.table_check`: Invoice Date | Due
///   Date | Term | Semester | Challan Type | Challan ID | Scholarship % |
///   Payable Amount | Status | Print/Save | Action | Paid Date.
/// - results   : `table.table_tree` #1 mixes 8-cell term summaries
///   (Term | Grade Points | Cumulative GP | Attempted | Earned |
///   Cumulative CH | SGPA | CGPA) with 4-cell course rows (Course |
///   Credit Hours | Grade Pts | Final Grade); table #2 is PLO
///   (Code | Points | Level | Attainment | Description).
/// - datesheet : empty state ("No Exam DateSheet Notified") or a table.
///
/// Every parser is total: unknown markup yields empty data, never throws.
library;

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

String _clean(String? s) => (s ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// ------------------------------- routes -------------------------------

class PortalRoutes {
  static const dashboard = '/student/dashboard';
  static const attendance = '/student/attendance';
  static const timetable = '/student/class/schedule';
  static const invoices = '/student/invoices';
  static const results = '/student/results';
  static const datesheet = '/student/exam/datesheet';
  static const profile = '/student/profile';
}

/// ------------------------------ timetable ------------------------------

class TimetableSlot {
  final String day;
  final String start; // "08:00"
  final String end; // "08:55"
  final String subject;
  final String teacher;
  final String section;
  final String room;
  const TimetableSlot({
    required this.day,
    required this.start,
    required this.end,
    required this.subject,
    required this.teacher,
    required this.section,
    required this.room,
  });

  bool get isLab =>
      subject.toLowerCase().contains('lab') ||
      room.toLowerCase().contains('lab');
}

class TimetableData {
  final String term;
  final String month;
  final List<TimetableSlot> slots;
  const TimetableData({
    this.term = '',
    this.month = '',
    this.slots = const [],
  });
}

TimetableData parseTimetable(String html) {
  final Document doc;
  try {
    doc = html_parser.parse(html);
  } catch (_) {
    return const TimetableData();
  }
  String term = '';
  String month = '';
  final bodyText = _clean(doc.body?.text);
  final termMatch = RegExp(r'Term\s*:\s*([A-Za-z]+\s+\d{4})').firstMatch(bodyText);
  if (termMatch != null) term = termMatch.group(1)!;
  final monthMatch = RegExp(r'Month\s*:\s*([A-Za-z]+)').firstMatch(bodyText);
  if (monthMatch != null) month = monthMatch.group(1)!;

  final slots = <TimetableSlot>[];
  for (final group in doc.querySelectorAll('.cd-schedule__group')) {
    final day = _clean(group.querySelector('.cd-schedule__top-info')?.text);
    for (final a in group.querySelectorAll('li.cd-schedule__event > a')) {
      final parts = a
          .querySelectorAll('em, span')
          .map((e) => _clean(e.text))
          .where((t) => t.isNotEmpty)
          .toList();
      String at(int i) => i < parts.length ? parts[i] : '';
      var subject = at(1);
      // Portal truncates long names with ".." — restore the known full name.
      if (subject.startsWith('Computer Organization and Assembly')) {
        subject = 'Computer Organization and Assembly Language';
      }
      slots.add(TimetableSlot(
        day: day,
        start: a.attributes['data-start'] ?? '',
        end: a.attributes['data-end'] ?? '',
        teacher: at(0),
        subject: subject,
        section: at(2),
        room: at(3),
      ));
    }
  }
  slots.removeWhere((s) => s.subject.isEmpty || s.start.isEmpty);
  return TimetableData(term: term, month: month, slots: slots);
}

/// ------------------------------ attendance -----------------------------

class AttendanceRecord {
  final String date; // "2026-09-28"
  final String status; // Present | Absent | Leave
  final String fine;
  const AttendanceRecord({
    required this.date,
    required this.status,
    required this.fine,
  });
}

class AttendanceCourse {
  final String name;
  final double percent;
  final List<AttendanceRecord> records;
  const AttendanceCourse({
    required this.name,
    required this.percent,
    this.records = const [],
  });
}

AttendanceCourse? _parseAttendanceBlock(Element h3, Element? table) {
  final title = _clean(h3.text);
  final m = RegExp(r'^(.*?)Attendance:\s*([0-9]+\.?[0-9]*)%?\s*$').firstMatch(title);
  if (m == null) return null;
  final records = <AttendanceRecord>[];
  if (table != null) {
    final rows = table.querySelectorAll('tr');
    for (final r in rows.skip(1)) {
      final cells =
          r.querySelectorAll('td').map((e) => _clean(e.text)).toList();
      if (cells.length >= 3) {
        records.add(AttendanceRecord(
          date: cells[1],
          status: cells[2],
          fine: cells.length > 3 ? cells[3] : '-',
        ));
      }
    }
  }
  return AttendanceCourse(
    name: m.group(1)!.trim(),
    percent: double.tryParse(m.group(2)!) ?? 0,
    records: records,
  );
}

/// Finds the data table belonging to a heading: the heading's following
/// siblings (directly or nested), then one level up. Total: never throws.
Element? _tableAfter(Element h3) {
  Element? scope = h3.nextElementSibling;
  var hops = 0;
  while (scope != null && hops < 8) {
    if (scope.localName == 'table') return scope;
    final nested = scope.querySelector('table');
    if (nested != null) return nested;
    scope = scope.nextElementSibling;
    hops++;
  }
  Element? parent = h3.parent;
  var ups = 0;
  while (parent != null && ups < 3) {
    Element? sibling = parent.nextElementSibling;
    var hops2 = 0;
    while (sibling != null && hops2 < 4) {
      if (sibling.localName == 'table') return sibling;
      final nested = sibling.querySelector('table');
      if (nested != null) return nested;
      sibling = sibling.nextElementSibling;
      hops2++;
    }
    parent = parent.parent;
    ups++;
  }
  return null;
}

List<AttendanceCourse> parseAttendance(String html) {
  final Document doc;
  try {
    doc = html_parser.parse(html);
  } catch (_) {
    return const [];
  }
  final courses = <AttendanceCourse>[];
  for (final h3 in doc.querySelectorAll('h3')) {
    final course = _parseAttendanceBlock(h3, _tableAfter(h3));
    if (course != null) courses.add(course);
  }
  return courses;
}

/// ------------------------------- invoices ------------------------------

class Invoice {
  final String date;
  final String due;
  final String term;
  final String type;
  final String challanId;
  final String scholarship;
  final String amount;
  final String status;
  final String paidDate;
  const Invoice({
    required this.date,
    required this.due,
    required this.term,
    required this.type,
    required this.challanId,
    required this.scholarship,
    required this.amount,
    required this.status,
    required this.paidDate,
  });

  bool get isPaid => status.toLowerCase() == 'paid';
}

List<Invoice> parseInvoices(String html) {
  final Document doc;
  try {
    doc = html_parser.parse(html);
  } catch (_) {
    return const [];
  }
  final out = <Invoice>[];
  for (final table in doc.querySelectorAll('table')) {
    final rows = table.querySelectorAll('tr');
    if (rows.isEmpty) continue;
    final head = rows.first
        .querySelectorAll('th, td')
        .map((e) => _clean(e.text).toLowerCase())
        .toList();
    if (!(head.contains('challan id') && head.contains('payable amount'))) {
      continue;
    }
    for (final r in rows.skip(1)) {
      final c =
          r.querySelectorAll('td').map((e) => _clean(e.text)).toList();
      if (c.length < 12) continue;
      out.add(Invoice(
        date: c[0],
        due: c[1],
        term: c[2],
        type: c[4],
        challanId: c[5],
        scholarship: c[6],
        amount: c[7],
        status: c[8],
        paidDate: c[11],
      ));
    }
  }
  return out;
}

/// -------------------------------- results ------------------------------

class ResultCourse {
  final String name;
  final String credits;
  final String gradePts;
  final String grade;
  const ResultCourse({
    required this.name,
    required this.credits,
    required this.gradePts,
    required this.grade,
  });
}

class ResultTerm {
  final String term;
  final String sgpa;
  final String cgpa;
  final String attempted;
  final String earned;
  final List<ResultCourse> courses;
  const ResultTerm({
    required this.term,
    required this.sgpa,
    required this.cgpa,
    required this.attempted,
    required this.earned,
    this.courses = const [],
  });
}

class PloEntry {
  final String code;
  final String attainment;
  final String description;
  const PloEntry({
    required this.code,
    required this.attainment,
    required this.description,
  });
}

class ResultsData {
  final List<ResultTerm> terms;
  final List<PloEntry> plos;
  const ResultsData({this.terms = const [], this.plos = const []});
  bool get isEmpty => terms.isEmpty && plos.isEmpty;
}

ResultsData parseResults(String html) {
  final Document doc;
  try {
    doc = html_parser.parse(html);
  } catch (_) {
    return const ResultsData();
  }
  final terms = <ResultTerm>[];
  final plos = <PloEntry>[];
  for (final table in doc.querySelectorAll('table.table_tree')) {
    final rows = table.querySelectorAll('tr').map((r) => r
        .querySelectorAll('th, td')
        .map((e) => _clean(e.text))
        .toList()).toList();
    if (rows.isEmpty) continue;
    final head = rows.first.map((e) => e.toLowerCase()).toList();
    if (head.contains('term') && head.contains('sgpa')) {
      ResultTerm? current;
      final courses = <ResultCourse>[];
      void flush() {
        if (current != null) {
          terms.add(ResultTerm(
            term: current!.term,
            sgpa: current!.sgpa,
            cgpa: current!.cgpa,
            attempted: current!.attempted,
            earned: current!.earned,
            courses: List.of(courses),
          ));
          courses.clear();
        }
      }

      for (final cells in rows.skip(1)) {
        if (cells.length >= 8) {
          flush();
          current = ResultTerm(
            term: cells[0],
            sgpa: cells[6],
            cgpa: cells[7],
            attempted: cells[3],
            earned: cells[4],
            courses: const [],
          );
        } else if (cells.length == 4 &&
            cells[0].toLowerCase() != 'course' &&
            current != null) {
          courses.add(ResultCourse(
            name: cells[0],
            credits: cells[1],
            gradePts: cells[2],
            grade: cells[3],
          ));
        }
      }
      flush();
    } else if (head.contains('code') && head.contains('attainment')) {
      for (final cells in rows.skip(1)) {
        if (cells.length >= 5) {
          final att = double.tryParse(cells[3]);
          plos.add(PloEntry(
            code: cells[0],
            attainment: att == null
                ? cells[3]
                : '${att.toStringAsFixed(1)}%',
            description: cells[4],
          ));
        }
      }
    }
  }
  return ResultsData(terms: terms, plos: plos);
}

/// ------------------------------- datesheet -----------------------------

class DatesheetExam {
  final List<String> cells;
  const DatesheetExam(this.cells);
}

class DatesheetData {
  final String notice;
  final List<String> headers;
  final List<DatesheetExam> exams;
  const DatesheetData({
    this.notice = '',
    this.headers = const [],
    this.exams = const [],
  });
  bool get isEmpty => exams.isEmpty;
}

DatesheetData parseDatesheet(String html) {
  final Document doc;
  try {
    doc = html_parser.parse(html);
  } catch (_) {
    return const DatesheetData();
  }
  String notice = '';
  for (final h in doc.querySelectorAll('h1, h2, h3')) {
    final t = _clean(h.text);
    if (t.toLowerCase().contains('datesheet') && t.length < 120) {
      // The empty-state heading itself; the message sits nearby.
      final parent = _clean(h.parent?.text);
      final m = RegExp(
              r'(Currently[^.]*DateSheet[^.]*\.|No Exam[^.]*notified[^.]*)',
              caseSensitive: false)
          .firstMatch(parent);
      if (m != null) notice = m.group(1)!;
    }
  }
  final headers = <String>[];
  final exams = <DatesheetExam>[];
  for (final table in doc.querySelectorAll('table')) {
    final rows = table.querySelectorAll('tr');
    if (rows.length < 2) continue;
    final head = rows.first
        .querySelectorAll('th, td')
        .map((e) => _clean(e.text))
        .where((t) => t.isNotEmpty)
        .toList();
    if (head.length < 2) continue;
    headers.addAll(head);
    for (final r in rows.skip(1)) {
      final cells = r
          .querySelectorAll('td')
          .map((e) => _clean(e.text))
          .toList();
      if (cells.any((e) => e.isNotEmpty)) exams.add(DatesheetExam(cells));
    }
    if (exams.isNotEmpty) break;
  }
  return DatesheetData(notice: notice, headers: headers, exams: exams);
}
