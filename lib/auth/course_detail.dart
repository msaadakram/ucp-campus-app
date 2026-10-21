// ============================================================
// Course detail: per-course portal pages (part 1: routes + news).
//
// Dashboard lists courses (`parseCourses` gives each an `infoUrl`
// like `/student/course/info/<id>`). Every course page carries the
// same tab bar (verified on real saved pages for CP223 OOP Fall 2026):
//
//   Announcement/News -> /student/course/info/<id>
//   Course Outline    -> /student/course/outline/<id>
//   Course Material   -> /student/course/material/<id>
//   Assessments       -> /student/course/assessment/<id>
//   Submission        -> /student/course/submission/<id>
//   Grade Book        -> /student/course/gradebook/<id>
//   Attendance        -> /student/course/attendance/<id>
//
// Every parser is total: unknown markup yields empty data, never throws.
// ============================================================
library;

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

String _clean(String? s) => (s ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

double? _num(String s) {
  final m = RegExp(r'-?\d+(\.\d+)?').firstMatch(s.replaceAll(',', ''));
  return m == null ? null : double.tryParse(m.group(0)!);
}

/// Opaque course id from any course URL or bare id.
/// `/student/course/info/pBG3...` -> `pBG3...`. Null when absent.
String? courseIdFromUrl(String url) {
  final m = RegExp(r'/student/course/(?:info|outline|material|assessment|'
          r'submission|gradebook|attendance)/([A-Za-z0-9]+)')
      .firstMatch(url);
  if (m != null) return m.group(1);
  if (RegExp(r'^[A-Za-z0-9]{8,60}$').hasMatch(url.trim())) {
    return url.trim();
  }
  return null;
}

/// Course tab routes for one course id (mirrors the portal tab bar).
class CourseTabRoutes {
  final String id;
  const CourseTabRoutes(this.id);

  String get news => '/student/course/info/$id';
  String get outline => '/student/course/outline/$id';
  String get material => '/student/course/material/$id';
  String get assessments => '/student/course/assessment/$id';
  String get submission => '/student/course/submission/$id';
  String get gradebook => '/student/course/gradebook/$id';
  String get attendance => '/student/course/attendance/$id';

  List<String> get all => [
        news,
        outline,
        material,
        assessments,
        submission,
        gradebook,
        attendance,
      ];
}

/// Builds [CourseTabRoutes] from a dashboard card `infoUrl`.
/// Null when the url carries no course id.
CourseTabRoutes? courseTabsFromInfoUrl(String infoUrl) {
  final id = courseIdFromUrl(infoUrl);
  return id == null ? null : CourseTabRoutes(id);
}

// ------------------------- news / announcements -------------------------

class CourseNewsItem {
  final String subject;
  final String date;
  final String description;
  final bool hasAttachment;
  const CourseNewsItem({
    required this.subject,
    required this.date,
    required this.description,
    this.hasAttachment = false,
  });
}

/// Parses the Announcement/News table
/// (`Sr No. | Subject | Date | Description | Attachment`).
/// Empty portal state ("No Announcement") yields [].
List<CourseNewsItem> parseCourseNews(String html) {
  final Document doc;
  try {
    doc = html_parser.parse(html);
  } catch (_) {
    return const [];
  }
  final out = <CourseNewsItem>[];
  for (final table in doc.querySelectorAll('table')) {
    final head = table
        .querySelectorAll('th')
        .map((e) => _clean(e.text).toLowerCase())
        .toList();
    if (!(head.any((h) => h.contains('subject')) &&
        head.any((h) => h.contains('description')))) {
      continue;
    }
    for (final tr in table.querySelectorAll('tbody tr')) {
      final cells =
          tr.querySelectorAll('td').map((e) => _clean(e.text)).toList();
      if (cells.isEmpty) continue;
      if (cells.length == 1 &&
          cells.first.toLowerCase().contains('no announcement')) {
        continue;
      }
      String at(int i) => i < cells.length ? cells[i] : '';
      final attach = at(4);
      out.add(CourseNewsItem(
        subject: at(1),
        date: at(2),
        description: at(3),
        hasAttachment: attach.isNotEmpty &&
            !attach.toLowerCase().contains('no '),
      ));
    }
  }
  return out;
}


class CourseOutlineClo {
  final String clo;
  final String statement;
  final String bloom;
  final String plo;
  const CourseOutlineClo({
    required this.clo,
    required this.statement,
    required this.bloom,
    required this.plo,
  });
}

class CourseBook {
  final String title;
  final String authors;
  final String edition;
  final String publisher;
  final String year;
  final String description;
  const CourseBook({
    required this.title,
    required this.authors,
    required this.edition,
    required this.publisher,
    required this.year,
    required this.description,
  });
}

class CourseWeightage {
  final String type;
  final double weight;
  final int considerTop;
  const CourseWeightage({
    required this.type,
    required this.weight,
    this.considerTop = 0,
  });
}

class CourseWeek {
  final String week;
  final String contents;
  final String activity;
  final bool hasFiles;
  const CourseWeek({
    required this.week,
    required this.contents,
    required this.activity,
    this.hasFiles = false,
  });
}

class CourseOutlineData {
  final List<CourseOutlineClo> clos;
  final List<CourseBook> textbooks;
  final List<CourseBook> references;
  final List<CourseWeightage> weightages;
  final List<CourseWeek> weeks;
  final List<String> objectives;
  const CourseOutlineData({
    this.clos = const [],
    this.textbooks = const [],
    this.references = const [],
    this.weightages = const [],
    this.weeks = const [],
    this.objectives = const [],
  });

  bool get isEmpty =>
      clos.isEmpty &&
      textbooks.isEmpty &&
      references.isEmpty &&
      weightages.isEmpty &&
      weeks.isEmpty &&
      objectives.isEmpty;
}

CourseOutlineData parseCourseOutline(String html) {
  final Document doc;
  try {
    doc = html_parser.parse(html);
  } catch (_) {
    return const CourseOutlineData();
  }
  final clos = <CourseOutlineClo>[];
  final textbooks = <CourseBook>[];
  final references = <CourseBook>[];
  final weightages = <CourseWeightage>[];
  final weeks = <CourseWeek>[];

  for (final table in doc.querySelectorAll('table')) {
    // Nearest preceding h4/h5 in document order: walk up the ancestor
    // chain, scanning previous siblings at each level (the portal
    // nests headings and tables at different depths).
    var section = '';
    Element? node = table;
    for (var level = 0; level < 4 && node != null && section.isEmpty; level++) {
      Element? el = node.previousElementSibling;
      var hops = 0;
      while (el != null && hops < 8 && section.isEmpty) {
        final tag = el.localName ?? '';
        if (tag == 'h4' || tag == 'h5') {
          section = _clean(el.text).toLowerCase();
        } else {
          final all = el.querySelectorAll('h4, h5');
          if (all.isNotEmpty) {
            section = _clean(all.last.text).toLowerCase();
          }
        }
        el = el.previousElementSibling;
        hops++;
      }
      node = node.parent;
    }
    final head = table
        .querySelectorAll('th')
        .map((e) => _clean(e.text).toLowerCase())
        .join('|');
    final rows = table.querySelectorAll('tr');
    // Data cells per row: `th` header rows yield [] (skipped below),
    // EXCEPT all-`td` header rows (outline CLO/time-split tables
    // render headers as plain `td`) which are detected via [headTd].
    List<List<String>> cellsOf() => [
          for (final r in rows)
            if (r.querySelectorAll('td').isNotEmpty)
              r.querySelectorAll('td').map((e) => _clean(e.text)).toList()
        ];

    // All-td header signature for tables without any `th`.
    String headTd() {
      if (head.isNotEmpty) return head;
      for (final r in rows) {
        if (r.querySelectorAll('td').isNotEmpty) {
          return r
              .querySelectorAll('td')
              .map((e) => _clean(e.text).toLowerCase())
              .join('|');
        }
      }
      return '';
    }

    final sig = head.isNotEmpty ? head : headTd();
    // Skip the all-td header row itself when iterating data rows.
    List<List<String>> dataCells() {
      final all = cellsOf();
      if (head.isEmpty && all.isNotEmpty) return all.skip(1).toList();
      return all;
    }

    if (section.contains('learning outcome') || sig.startsWith('clo|clo')) {
      for (final c in dataCells()) {
        if (c.length < 4 || c.every((e) => e.isEmpty)) continue;
        clos.add(CourseOutlineClo(
            clo: c[0], statement: c[1], bloom: c[2], plo: c[3]));
      }
    } else if (section.contains('text book') ||
        (section.contains('text') && sig.contains('authors')) ||
        (section.isEmpty && sig.contains('authors') && textbooks.isEmpty)) {
      for (final c in dataCells()) {
        if (c.length < 2 || c[1].isEmpty) continue;
        String at(int i) => i < c.length ? c[i] : '';
        textbooks.add(CourseBook(
            title: at(1),
            authors: at(2),
            edition: at(3),
            publisher: at(4),
            year: at(5),
            description: at(6)));
      }
    } else if (section.contains('reference') ||
        (section.isEmpty &&
            sig.contains('authors') &&
            textbooks.isNotEmpty)) {
      for (final c in dataCells()) {
        if (c.length < 2 || c[1].isEmpty) continue;
        String at(int i) => i < c.length ? c[i] : '';
        references.add(CourseBook(
            title: at(1),
            authors: at(2),
            edition: at(3),
            publisher: at(4),
            year: at(5),
            description: at(6)));
      }
    } else if (section.contains('assessment') ||
        sig.contains('weightage')) {
      for (final c in dataCells()) {
        if (c.isEmpty || c.first.isEmpty) continue;
        if (c.first.toLowerCase().contains('assessment type')) continue;
        weightages.add(CourseWeightage(
          type: c[0],
          weight: c.length > 1 ? (_num(c[1]) ?? 0) : 0,
          considerTop: c.length > 2 ? (_num(c[2]) ?? 0).toInt() : 0,
        ));
      }
    } else if (section.contains('calendar') || sig.startsWith('week')) {
      for (final c in dataCells()) {
        if (c.isEmpty || c.first.isEmpty) continue;
        final files = c.length > 3 ? c[3] : '';
        weeks.add(CourseWeek(
          week: c[0],
          contents: c.length > 1 ? c[1] : '',
          activity: c.length > 2 ? c[2] : '',
          hasFiles: files.isNotEmpty &&
              !files.toLowerCase().contains('no file'),
        ));
      }
    }
  }

  final objectives = <String>[];
  for (final h in doc.querySelectorAll('h4, h5')) {
    if (_clean(h.text).toLowerCase().contains('objective')) {
      Element? el = h.nextElementSibling;
      var hops = 0;
      while (el != null && hops < 4 && objectives.isEmpty) {
        for (final li in el.querySelectorAll('li')) {
          final t = _clean(li.text);
          if (t.length > 10 && objectives.length < 20) objectives.add(t);
        }
        el = el.nextElementSibling;
        hops++;
      }
      if (objectives.isNotEmpty) break;
    }
  }

  return CourseOutlineData(
    clos: clos,
    textbooks: textbooks,
    references: references,
    weightages: weightages,
    weeks: weeks,
    objectives: objectives,
  );
}


class CourseMaterialItem {
  final String fileName;
  final String description;
  final String downloadUrl;
  /// Derived grouping ("Week 3", "Course Outline", "Text Books",
  /// "Lecture Files") so the Material tab can show a subject-wise list.
  final String subject;
  const CourseMaterialItem({
    required this.fileName,
    required this.description,
    required this.downloadUrl,
    this.subject = '',
  });
}

/// Classifies one row into a subject section. Heuristic (the portal has
/// no subject column): week numbers from the file name or description,
/// then outline/books, everything else lands in "Lecture Files". Pure.
String materialSubject(String fileName, String description) {
  final text = '${fileName.toLowerCase()} ${description.toLowerCase()}';
  final m = RegExp(
          r'week\s*no\.?\s*(\d+)|week\s*-?\s*(\d+)|week\s*\(?\s*(\d+)|week(\d+)')
      .firstMatch(text);
  if (m != null) {
    for (final g in [m.group(1), m.group(2), m.group(3), m.group(4)]) {
      if (g != null && g.isNotEmpty) return 'Week $g';
    }
  }
  if (text.contains('outline')) return 'Course Outline';
  if (text.contains('text book') || text.contains('textbook') ||
      RegExp(r'\bbook\b').hasMatch(text) ||
      fileName.toLowerCase().contains('book')) {
    return 'Text Books';
  }
  return 'Lecture Files';
}

/// Material table (`Sr No. | Course Material File | Description |
/// Download`). Hrefs `/student/class/material/download/`<id>`` kept
/// relative like every [PortalRoutes] path. Never throws. Each item
/// carries its derived [CourseMaterialItem.subject] for grouped display.
List<CourseMaterialItem> parseCourseMaterial(String html) {
  final Document doc;
  try {
    doc = html_parser.parse(html);
  } catch (_) {
    return const [];
  }
  final out = <CourseMaterialItem>[];
  for (final table in doc.querySelectorAll('table')) {
    final head = table
        .querySelectorAll('th')
        .map((e) => _clean(e.text).toLowerCase())
        .toList();
    if (!(head.any((h) => h.contains('material file')) &&
        head.any((h) => h.contains('download')))) {
      continue;
    }
    for (final tr in table.querySelectorAll('tbody tr')) {
      final tds = tr.querySelectorAll('td');
      if (tds.length < 3) continue;
      final cells = tds.map((e) => _clean(e.text)).toList();
      if (cells.every((e) => e.isEmpty)) continue;
      var href = '';
      final a = tr.querySelector('a[href*="material/download"]');
      if (a != null) href = (a.attributes['href'] ?? '').trim();
      if (href.startsWith('https://horizon.ucp.edu.pk')) {
        href = href.replaceFirst('https://horizon.ucp.edu.pk', '');
      }
      final name = cells.length > 1 ? cells[1] : '';
      final desc = cells.length > 2 ? cells[2] : '';
      out.add(CourseMaterialItem(
        fileName: name,
        description: desc,
        downloadUrl: href,
        subject: materialSubject(name, desc),
      ));
    }
  }
  return out;
}

class CourseAssessment {
  final String name;
  final String type;
  final String date;
  final String dueDate;
  final bool canUpload;
  const CourseAssessment({
    required this.name,
    required this.type,
    required this.date,
    required this.dueDate,
    this.canUpload = false,
  });
}

/// Assessments table
/// (`Sr No. | Name | Type | Date | Due Date | Upload | Attachments`).
List<CourseAssessment> parseCourseAssessments(String html) {
  final Document doc;
  try {
    doc = html_parser.parse(html);
  } catch (_) {
    return const [];
  }
  final out = <CourseAssessment>[];
  for (final table in doc.querySelectorAll('table')) {
    final head = table
        .querySelectorAll('th')
        .map((e) => _clean(e.text).toLowerCase())
        .toList();
    if (!(head.any((h) => h == 'name') &&
        head.any((h) => h.contains('due date')))) {
      continue;
    }
    for (final tr in table.querySelectorAll('tbody tr')) {
      final cells =
          tr.querySelectorAll('td').map((e) => _clean(e.text)).toList();
      if (cells.isEmpty || cells.every((e) => e.isEmpty)) continue;
      if (cells.length == 1 && cells.first.toLowerCase().contains('no ')) {
        continue;
      }
      String at(int i) => i < cells.length ? cells[i] : '';
      out.add(CourseAssessment(
        name: at(1),
        type: at(2),
        date: at(3),
        dueDate: at(4),
        canUpload: cells.length > 5 && !at(5).toLowerCase().contains('no '),
      ));
    }
  }
  return out;
}

class CourseSubmission {
  final String name;
  final String description;
  final String startDate;
  final String dueDate;
  final bool hasAttachment;
  const CourseSubmission({
    required this.name,
    required this.description,
    required this.startDate,
    required this.dueDate,
    this.hasAttachment = false,
  });
}

/// Submissions table
/// (`Sr No. | Name | Description | Start Date | Due Date | ...`).
/// "No Submission uploaded" yields [].
List<CourseSubmission> parseCourseSubmissions(String html) {
  final Document doc;
  try {
    doc = html_parser.parse(html);
  } catch (_) {
    return const [];
  }
  final out = <CourseSubmission>[];
  for (final table in doc.querySelectorAll('table')) {
    final head = table
        .querySelectorAll('th')
        .map((e) => _clean(e.text).toLowerCase())
        .toList();
    if (!(head.any((h) => h == 'name') &&
        head.any((h) => h.contains('start date')))) {
      continue;
    }
    for (final tr in table.querySelectorAll('tbody tr')) {
      final cells =
          tr.querySelectorAll('td').map((e) => _clean(e.text)).toList();
      if (cells.isEmpty) continue;
      if (cells.length == 1 &&
          cells.first.toLowerCase().contains('no submission')) {
        continue;
      }
      String at(int i) => i < cells.length ? cells[i] : '';
      out.add(CourseSubmission(
        name: at(1),
        description: at(2),
        startDate: at(3),
        dueDate: at(4),
        hasAttachment: cells.length > 5 &&
            at(5).isNotEmpty &&
            !at(5).toLowerCase().contains('no '),
      ));
    }
  }
  return out;
}


class CourseGradeType {
  final String type;
  /// Weightage of this type in the course ("10" for 10%).
  final double weight;
  /// OBTAINED PERCENTAGE of this type, exactly as the portal shows it
  /// (the parent row's second cell: 25.00 for 5/20).
  final double obtained;
  /// Total marks of the type's assessments (sum of the child rows).
  final double total;
  const CourseGradeType({
    required this.type,
    required this.weight,
    required this.obtained,
    this.total = 0,
  });

  /// This type's share of the course mark: percentage x weight — the
  /// same formula the extension publishes with.
  double get weightedPercentage =>
      weight > 0 ? (obtained / 100) * weight : 0;
}

class CourseGradeRow {
  final String assessment;
  final double maxMarks;
  final double obtainedMarks;
  final double classAverage;
  final double percentage;
  const CourseGradeRow({
    required this.assessment,
    required this.maxMarks,
    required this.obtainedMarks,
    required this.classAverage,
    required this.percentage,
  });
}

class CourseGradebook {
  final List<CourseGradeType> types;
  final List<CourseGradeRow> rows;
  const CourseGradebook({this.types = const [], this.rows = const []});
  bool get isEmpty => types.isEmpty && rows.isEmpty;
}

/// Gradebook page: the portal renders ONE table per assessment TYPE.
///
///   <tr class="table-parent-row show_child_row">      ← the TYPE
///       <a class="js-toggle-children-row">Class Activity</a>
///       <span class="uk-badge">10</span>              ← the weight
///   </tr>
///   <tr class="table-child-row">                      ← an assessment
///       <td>Quiz 1</td><td>20</td><td>18</td><td>12</td>   ← name/max/obtained/avg
///   </tr>
///
/// The MARKS live in the child rows; the parent row only names the type
/// and carries its weight. (Parsing the parent rows alone — the earlier
/// approach — yielded one type with zero marks, which is why a published
/// gradebook could arrive as 0%.) Never throws.
CourseGradebook parseCourseGradebook(String html) {
  final Document doc;
  try {
    doc = html_parser.parse(html);
  } catch (_) {
    return const CourseGradebook();
  }
  final types = <CourseGradeType>[];
  final rows = <CourseGradeRow>[];

  /// Parent rows anywhere in the document (the portal wraps them in a
  /// table but the class names are the reliable hook).
  final parents = doc
      .querySelectorAll('tr.show_child_row, tr.table-parent-row')
      .toList();
  for (final tr in parents) {
    // --- the type name: the toggle link's text (before its badge) ---
    final toggle = tr.querySelector('.js-toggle-children-row');
    var name = toggle != null ? _clean(toggle.text) : '';
    // The weight: a `.uk-badge` inside the row ("10.0 %"), else a
    // percentage in the name itself.
    final badge = tr.querySelector('.uk-badge');
    final badgeText = badge != null ? _clean(badge.text) : '';
    var weight = _num(badgeText) ?? 0;
    if (weight <= 0) {
      final m = RegExp(r'(-?\d+(?:\.\d+)?)\s*%').firstMatch(name);
      if (m != null) weight = double.tryParse(m.group(1)!) ?? 0;
    }
    // The name must not keep the badge/percentage text.
    name = name
        .replaceAll(RegExp(r'\s*-?\d+(?:\.\d+)?\s*%\s*$'), '')
        .trim();
    if (name.isEmpty) {
      final cells = tr.querySelectorAll('td');
      if (cells.isNotEmpty) name = cells.first.text.split('\n').first.trim();
    }
    if (name.isEmpty) continue;

    // --- the obtained percentage: the parent row's own second cell ---
    final own = tr.querySelectorAll('td').map((e) => _clean(e.text)).toList();
    final obtainedPct = _num(own.length > 1 ? own[1] : '') ?? 0;

    var total = 0.0;
    var obtainedMarks = 0.0;
    // --- the child rows that follow, until the next non-child row ---
    var next = tr.nextElementSibling;
    while (next != null) {
      final cls = next.className;
      if (!cls.contains('table-child-row')) break;
      if (!cls.contains('md-bg-blue-grey-800')) {
        final cells =
            next.querySelectorAll('td').map((e) => _clean(e.text)).toList();
        if (cells.length >= 4) {
          final max = _num(cells[1]) ?? 0;
          final obt = _num(cells[2]) ?? 0;
          final avg = _num(cells[3]) ?? 0;
          total += max;
          obtainedMarks += obt;
          rows.add(CourseGradeRow(
            assessment: cells[0],
            maxMarks: max,
            obtainedMarks: obt,
            classAverage: avg,
            percentage: max > 0 ? (obt / max) * 100 : 0,
          ));
        }
      }
      next = next.nextElementSibling;
    }

    // Trust the portal's own percentage; fall back to the child rows
    // when the summary cell is missing.
    double obtained = obtainedPct;
    if (obtained <= 0 && total > 0 && obtainedMarks > 0) {
      obtained = (obtainedMarks / total) * 100;
    }
    types.add(CourseGradeType(
      type: name,
      weight: weight,
      obtained: obtained,
      total: total,
    ));
  }
  return CourseGradebook(types: types, rows: rows);
}

class CourseAttendanceRow {
  final String date;
  final String status;
  final String fine;
  const CourseAttendanceRow({
    required this.date,
    required this.status,
    required this.fine,
  });
}

/// Per-course attendance page (`Sr. no | Date | Status | Fine`).
/// Same column shape as aggregate `/student/attendance`; this covers
/// the single-course variant. Never throws.
List<CourseAttendanceRow> parseCourseAttendance(String html) {
  final Document doc;
  try {
    doc = html_parser.parse(html);
  } catch (_) {
    return const [];
  }
  final out = <CourseAttendanceRow>[];
  for (final table in doc.querySelectorAll('table')) {
    final head = table
        .querySelectorAll('th')
        .map((e) => _clean(e.text).toLowerCase())
        .join('|');
    if (!(head.contains('date') &&
        head.contains('status') &&
        head.contains('fine'))) {
      continue;
    }
    for (final tr in table.querySelectorAll('tbody tr')) {
      final cells =
          tr.querySelectorAll('td').map((e) => _clean(e.text)).toList();
      if (cells.length < 3 || cells.every((e) => e.isEmpty)) continue;
      out.add(CourseAttendanceRow(
        date: cells.length > 1 ? cells[1] : cells[0],
        status: cells.length > 2 ? cells[2] : '',
        fine: cells.length > 3 ? cells[3] : '-',
      ));
    }
  }
  return out;
}

/// Present % over per-course attendance rows. 0 when no rows.
double courseAttendancePercent(List<CourseAttendanceRow> rows) {
  if (rows.isEmpty) return 0;
  final present =
      rows.where((r) => r.status.toLowerCase() == 'present').length;
  return present / rows.length * 100;
}
