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

import '../data/seed.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

String _clean(String? s) => (s ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// ------------------------------- courses -------------------------------
/// The dashboard's "Classes, Grades and Attendance" section holds one
/// linked card per enrolled course:
/// `<a href="/student/course/info/<id>">` > `.card` > `.card-header`
/// (name) + `.card-body` > `h6.card-title` (teacher),
/// `span.sub-heading` (code), `Credits : <n>`, `Attendance: <pct>%`.

class PortalCourse {
  final String name;
  final String teacher;
  final String code;
  final double credits;
  final double attendance;
  final String infoUrl;
  const PortalCourse({
    required this.name,
    required this.teacher,
    required this.code,
    required this.credits,
    required this.attendance,
    required this.infoUrl,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'teacher': teacher,
        'code': code,
        'credits': credits,
        'attendance': attendance,
        'infoUrl': infoUrl,
      };

  factory PortalCourse.fromJson(Map<String, dynamic> json) => PortalCourse(
        name: '${json['name'] ?? ''}',
        teacher: '${json['teacher'] ?? ''}',
        code: '${json['code'] ?? ''}',
        credits: (json['credits'] is num)
            ? (json['credits'] as num).toDouble()
            : double.tryParse('${json['credits']}') ?? 0,
        attendance: (json['attendance'] is num)
            ? (json['attendance'] as num).toDouble()
            : double.tryParse('${json['attendance']}') ?? 0,
        infoUrl: '${json['infoUrl'] ?? ''}',
      );
}

String _subjectBase(String s) =>
    s.replaceAll(RegExp(r'\s*-\s*Lab\s*$'), '').trim().toLowerCase();

/// Overall attendance across enrolled courses, weighted by credits (a
/// 3-credit course counts 3x a 1-credit lab). Courses with no credit info
/// fall back to weight 1. Returns 0-100. Pure and unit-tested.
double overallAttendance(List<PortalCourse> courses) {
  if (courses.isEmpty) return 0;
  var weighted = 0.0;
  var weights = 0.0;
  for (final c in courses) {
    final w = c.credits > 0 ? c.credits : 1.0;
    weighted += c.attendance.clamp(0, 100) * w;
    weights += w;
  }
  if (weights == 0) return 0;
  return (weighted / weights).clamp(0, 100);
}

/// `38.888` -> `38.9%`, `50.0` -> `50%`. Pure and unit-tested.
String formatPercent(double v) {
  final one = (v.clamp(0, 100) * 10).round() / 10;
  final s = one.toStringAsFixed(1);
  return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}%';
}
/// model: ring shows live attendance, room/time come from the real weekly
/// schedule, tone cycles the palette. Pure and unit-tested.
/// Maps a portal course (+ timetable slots) onto the Home course card
/// model: ring shows live attendance, room/time come from the real weekly
/// schedule, tone cycles the palette. Pure and unit-tested.
Course portalCourseToCourse(
  PortalCourse pc,
  List<TimetableSlot> slots,
  int index,
) {
  final mine = slots
      .where((s) => _subjectBase(s.subject) == _subjectBase(pc.name))
      .toList()
    ..sort((a, b) {
      const order = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      final day = order.indexOf(a.day).compareTo(order.indexOf(b.day));
      return day != 0 ? day : a.start.compareTo(b.start);
    });
  final rooms = <String>{};
  for (final s in mine) {
    if (s.room.isNotEmpty) rooms.add(s.room);
  }
  String time;
  if (mine.isEmpty) {
    time = 'See timetable';
  } else {
    final first = mine.first;
    final days = <String>[];
    for (final s in mine) {
      final abbr = s.day.length >= 3 ? s.day.substring(0, 3) : s.day;
      if (!days.contains(abbr)) days.add(abbr);
    }
    time = '${days.join(' · ')} ${first.start}';
  }

  const tones = [
    CourseTone.teal,
    CourseTone.clay,
    CourseTone.board,
    CourseTone.dust,
  ];
  return Course(
    code: pc.code.isEmpty ? '—' : pc.code,
    title: pc.name,
    prof: pc.teacher.isEmpty ? 'TBA' : pc.teacher,
    room: rooms.isEmpty ? 'See timetable' : rooms.join(' · '),
    time: time,
    credits: pc.credits.round(),
    progress: pc.attendance.clamp(0, 100).round(),
    grade: '–',
    tone: tones[index % tones.length],
  );
}

List<PortalCourse> parseCourses(String html) {
  final Document doc;
  try {
    doc = html_parser.parse(html);
  } catch (_) {
    return const [];
  }
  final out = <PortalCourse>[];
  final seen = <String>{};
  for (final a in doc.querySelectorAll('a[href*="/student/course/info/"]')) {
    final card = a.querySelector('.card');
    if (card == null) continue;
    final name =
        _clean(card.querySelector('.card-header span')?.text);
    if (name.isEmpty || !seen.add(name)) continue;
    final teacher = _clean(card.querySelector('h6.card-title')?.text);
    final subs = card
        .querySelectorAll('span.sub-heading')
        .map((e) => _clean(e.text))
        .where((t) => t.isNotEmpty)
        .toList();
    final code = subs.isNotEmpty ? subs.first : '';
    final bodyText = _clean(card.querySelector('.card-body')?.text);
    final credits = RegExp(r'Credits\s*:\s*([0-9]+\.?[0-9]*)')
            .firstMatch(bodyText)
            ?.group(1) ??
        '0';
    final att = RegExp(r'Attendance:\s*([0-9]+\.?[0-9]*)')
            .firstMatch(bodyText)
            ?.group(1) ??
        '0';
    out.add(PortalCourse(
      name: name,
      teacher: teacher,
      code: code,
      credits: double.tryParse(credits) ?? 0,
      attendance: double.tryParse(att) ?? 0,
      infoUrl: a.attributes['href'] ?? '',
    ));
  }
  return out;
}

/// Full weekday names, Monday-first (matches [TimetableSlot.day]).
const weekdayOrder = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];

/// Weekday name for a date, e.g. `weekdayName(DateTime(2026,9,28))` is
/// `"Monday"`. Pure and unit-tested.
String weekdayName(DateTime d) => weekdayOrder[(d.weekday - 1).clamp(0, 6)];

/// Enrolled courses that have at least one class today. Pure, unit-tested.
List<PortalCourse> coursesToday(
    List<PortalCourse> courses, List<TimetableSlot> slots, DateTime now) {
  final today = weekdayName(now);
  return courses
      .where((c) => slotsForCourse(c.name, slots).any((s) => s.day == today))
      .toList();
}

/// Enrolled courses scheduled at any point this week (the complete weekly
/// subject list). Pure and unit-tested.
List<PortalCourse> coursesThisWeek(
    List<PortalCourse> courses, List<TimetableSlot> slots) {
  return courses
      .where((c) => slotsForCourse(c.name, slots).isNotEmpty)
      .toList();
}
/// Weekly slots belonging to a course title (matches "X" and "X - Lab").
List<TimetableSlot> slotsForCourse(
    String title, List<TimetableSlot> slots) {
  final base = _subjectBase(title);
  return slots
      .where((s) => _subjectBase(s.subject) == base)
      .toList()
    ..sort((a, b) {
      const order = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      final day = order.indexOf(a.day).compareTo(order.indexOf(b.day));
      return day != 0 ? day : a.start.compareTo(b.start);
    });
}

/// Next upcoming class: the class in progress right now if any, else
/// today's next slot by start time, else the earliest slot on the following
/// days (wraps around the week). Null when there are no slots at all.
TimetableSlot? nextClass(List<TimetableSlot> slots, DateTime now) {
  final up = upcomingClasses(slots, now, 1);
  return up.isEmpty ? null : up.first;
}

/// True while a class is in session: same weekday and
/// `start <= now < end`. Pure and unit-tested.
bool isSlotLive(TimetableSlot s, DateTime now) {
  final hm =
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  return s.day == weekdayName(now) &&
      s.start.compareTo(hm) <= 0 &&
      hm.compareTo(s.end) < 0;
}

/// The next [count] upcoming classes in chronological order: the class in
/// progress right now (if any) first, then today's remaining slots, then
/// the following days (wraps the week). Empty when there are no slots.
List<TimetableSlot> upcomingClasses(
    List<TimetableSlot> slots, DateTime now, [
  int count = 3,
]) {
  if (slots.isEmpty || count <= 0) return const [];
  const order = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  String hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final today = order[(now.weekday - 1).clamp(0, 6)];
  final nowHm = hm(now);
  final out = <TimetableSlot>[];
  // Started-but-unfinished today (in progress) plus later today.
  out.addAll(slots.where(
      (s) => s.day == today && s.end.compareTo(nowHm) > 0));
  for (var d = 1; d <= 7 && out.length < count; d++) {
    final name = order[(order.indexOf(today) + d) % 7];
    out.addAll(slots.where((s) => s.day == name));
  }
  out.sort((a, b) {
    // In-progress class first, then today's leftovers, then day order.
    int rank(TimetableSlot s) {
      if (s.day == today && s.end.compareTo(nowHm) > 0) {
        return s.start.compareTo(nowHm) <= 0 ? -9 : -8;
      }
      return (order.indexOf(s.day) - order.indexOf(today) + 7) % 7;
    }
    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : a.start.compareTo(b.start);
  });
  return out.take(count).toList();
}

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
  final String cumCh;
  final String cumGp;
  final List<ResultCourse> courses;
  const ResultTerm({
    required this.term,
    required this.sgpa,
    required this.cgpa,
    required this.attempted,
    required this.earned,
    this.cumCh = '',
    this.cumGp = '',
    this.courses = const [],
  });

  double get sgpaValue => double.tryParse(sgpa) ?? 0;
  double get cgpaValue => double.tryParse(cgpa) ?? 0;
  double get cumChValue => double.tryParse(cumCh) ?? 0;
}

/// Latest term in a results payload, or null when no terms exist.
/// The calculator uses its CGPA + cumulative CH as the previous base.
ResultTerm? latestResultTerm(ResultsData data) =>
    data.terms.isEmpty ? null : data.terms.last;

/// Previous-record base derived from portal results:
/// (prevCgpa, prevCr). Falls back to [fallback] when unparseable.
(double, int) prevBaseFromResults(
  ResultsData data, {
  double fallbackCgpa = 0,
  int fallbackCr = 0,
}) {
  final t = latestResultTerm(data);
  if (t == null) return (fallbackCgpa, fallbackCr);
  final cgpa = double.tryParse(t.cgpa) ?? fallbackCgpa;
  final cr = t.cumChValue > 0
      ? t.cumChValue.round()
      : (double.tryParse(t.earned)?.round() ?? fallbackCr);
  return (cgpa, cr);
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
            cumCh: current!.cumCh,
            cumGp: current!.cumGp,
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
            cumCh: cells[5],
            cumGp: cells[2],
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
