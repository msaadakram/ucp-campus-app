import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/auth/course_detail.dart';

String? _fixture2(String name) {
  final f = File('/home/ubuntu/ucp/z_pages/$name');
  return f.existsSync() ? f.readAsStringSync() : null;
}

void main() {
  group('synthetic markup part 2', () {
    test('gradebook summary splits weight from type', () {
      const html = '<table><thead><tr><th>Assessment Type</th>'
          '<th>Obtained Percentage</th></tr></thead><tbody><tr>'
          '<td>Class Activity 10.0 %</td><td>25.00</td></tr></tbody></table>'
          '<table><thead><tr><th>Assessment</th><th>Max Mark</th>'
          '<th>Obtained Marks</th><th>Class Average</th><th>Percentage</th>'
          '</tr></thead><tbody><tr><td>Class Activity 1</td><td>20.0</td>'
          '<td>5.00</td><td>11.92</td><td>25.00</td></tr></tbody></table>';
      final gb = parseCourseGradebook(html);
      expect(gb.types.length, 1);
      expect(gb.types.first.type, 'Class Activity');
      expect(gb.types.first.weight, 10.0);
      expect(gb.types.first.obtained, 25.0);
      expect(gb.rows.length, 1);
      expect(gb.rows.first.maxMarks, 20.0);
      expect(gb.rows.first.classAverage, 11.92);
    });

    test('empty states yield empty lists, never throw', () {
      expect(parseCourseNews(''), isEmpty);
      expect(parseCourseAssessments('garbage'), isEmpty);
      expect(parseCourseSubmissions('<div>none</div>'), isEmpty);
      expect(parseCourseMaterial(''), isEmpty);
      expect(parseCourseOutline(''), isEmpty);
      expect(parseCourseGradebook('').isEmpty, isTrue);
      expect(parseCourseAttendance(''), isEmpty);
      expect(courseAttendancePercent([]), 0);
    });

    test('attendance percent', () {
      const html = '<table><thead><tr><th>Sr. no</th><th>Date</th>'
          '<th>Status</th><th>Fine</th></tr></thead><tbody>'
          '<tr><td>1</td><td>2026-10-01</td><td>Present</td><td>-</td></tr>'
          '<tr><td>2</td><td>2026-10-02</td><td>Absent</td><td>-</td></tr>'
          '</tbody></table>';
      final rows = parseCourseAttendance(html);
      expect(rows.length, 2);
      expect(courseAttendancePercent(rows), 50.0);
    });
  });

  group('real saved pages (z_pages fixtures)', () {
    test('assessments page: Class Activity 1', () {
      final html = _fixture2('assements.html');
      if (html == null) return;
      final list = parseCourseAssessments(html);
      expect(list.length, 1);
      expect(list.first.name, 'Class Activity 1');
      expect(list.first.type, 'Class Activity');
      expect(list.first.date, contains('2026-10-08'));
      expect(list.first.dueDate, contains('13:00'));
    });

    test('attendance page: rows with present/absent', () {
      final html = _fixture2('attendenece.html');
      if (html == null) return;
      final rows = parseCourseAttendance(html);
      expect(rows.length, greaterThanOrEqualTo(5));
      expect(rows.first.date, contains('2026-10-01'));
      expect(rows.map((r) => r.status).toSet(),
          containsAll(['Present', 'Absent']));
      expect(courseAttendancePercent(rows), greaterThan(0));
    });

    test('gradebook page: summary plus detail', () {
      final html = _fixture2('grade.html');
      if (html == null) return;
      final gb = parseCourseGradebook(html);
      expect(gb.types, isNotEmpty);
      expect(gb.types.first.type, contains('Class Activity'));
      expect(gb.types.first.weight, 10.0);
      expect(gb.types.first.obtained, 25.0);
      expect(gb.rows, isNotEmpty);
      expect(gb.rows.first.assessment, 'Class Activity 1');
      expect(gb.rows.first.maxMarks, 20.0);
      expect(gb.rows.first.obtainedMarks, 5.0);
    });

    test('material page: files with download links', () {
      final html = _fixture2('material.html');
      if (html == null) return;
      final items = parseCourseMaterial(html);
      expect(items.length, greaterThanOrEqualTo(3));
      expect(items.first.fileName, contains('CP223'));
      expect(items.first.downloadUrl, contains('material/download/'));
      expect(items.map((e) => e.fileName).join('|'), contains('Deitel'));
    });

    test('material page: subject-wise grouping is derived per row', () {
      final html = _fixture2('material.html');
      if (html == null) return;
      final items = parseCourseMaterial(html);
      final subjects = items.map((e) => e.subject).toSet();
      expect(subjects, containsAll(['Course Outline', 'Text Books', 'Week 1']));
      // Section order follows first appearance: outline, books, then weeks.
      expect(items.first.subject, 'Course Outline');
      final week1 = items.where((e) => e.subject == 'Week 1');
      expect(week1.length, greaterThanOrEqualTo(4));
      expect(week1.every((e) =>
          e.fileName.toLowerCase().contains('week') ||
          e.description.toLowerCase().contains('week')), isTrue);
    });

    test('materialSubject heuristics', () {
      expect(materialSubject('OOP-WEEK1.cpp', ''), 'Week 1');
      expect(materialSubject('WEEK NO 1.pptx', 'Slides'), 'Week 1');
      expect(materialSubject('x', 'topics of Week 2 covered'), 'Week 2');
      expect(materialSubject('Week10-notes.pdf', ''), 'Week 10');
      expect(materialSubject('CP223 - Theory (Outline).docx', 'Course Outline'),
          'Course Outline');
      expect(materialSubject('Book 1_ Paul Deitel.pdf', 'Text Book'),
          'Text Books');
      expect(materialSubject('Lecture notes.txt', 'random desc'),
          'Lecture Files');
      expect(materialSubject('', ''), 'Lecture Files');
    });

    test('news plus submission empty states', () {
      final news = _fixture2('news.html');
      if (news != null) expect(parseCourseNews(news), isEmpty);
      final sub = _fixture2('submission.html');
      if (sub != null) expect(parseCourseSubmissions(sub), isEmpty);
    });

    test('outline page: clos, books, weightages, weeks', () {
      final html = _fixture2('outline.html');
      if (html == null) return;
      final o = parseCourseOutline(html);
      expect(o.isEmpty, isFalse);
      expect(
          o.weightages.map((w) => w.type).join('|'), contains('Final Term'));
      final total = o.weightages.fold<double>(0, (s, w) => s + w.weight);
      expect(total, 100.0);
      expect(o.weeks.length, greaterThanOrEqualTo(9));
      expect(o.weeks.first.week, '1');
      expect(o.textbooks.map((b) => b.authors).join('|'), contains('Deitel'));
    });
  });
}
