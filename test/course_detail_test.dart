import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/auth/course_detail.dart';

String? _fixture(String name) {
  final f = File('/home/ubuntu/ucp/z_pages/$name');
  return f.existsSync() ? f.readAsStringSync() : null;
}

void main() {
  group('course tab routes', () {
    test('id from any course url', () {
      expect(courseIdFromUrl('/student/course/info/pBG3ykar5ZOkdJ8v4NYV'),
          'pBG3ykar5ZOkdJ8v4NYV');
      expect(
          courseIdFromUrl(
              'https://horizon.ucp.edu.pk/student/course/gradebook/abc12345'),
          'abc12345');
      expect(courseIdFromUrl('/student/dashboard'), isNull);
      expect(courseIdFromUrl(''), isNull);
    });

    test('seven tab paths mirror the portal tab bar', () {
      final tabs = courseTabsFromInfoUrl('/student/course/info/ABC12345xyz');
      expect(tabs, isNotNull);
      expect(tabs!.news, '/student/course/info/ABC12345xyz');
      expect(tabs.outline, '/student/course/outline/ABC12345xyz');
      expect(tabs.material, '/student/course/material/ABC12345xyz');
      expect(tabs.assessments, '/student/course/assessment/ABC12345xyz');
      expect(tabs.submission, '/student/course/submission/ABC12345xyz');
      expect(tabs.gradebook, '/student/course/gradebook/ABC12345xyz');
      expect(tabs.attendance, '/student/course/attendance/ABC12345xyz');
      expect(tabs.all.length, 7);
      expect(courseTabsFromInfoUrl('/student/dashboard'), isNull);
    });
  });

  group('synthetic markup', () {
    test('assessments row', () {
      const html = '<table><thead><tr><th>Sr No.</th><th>Name</th>'
          '<th>Type</th><th>Date</th><th>Due Date</th><th>Upload</th>'
          '<th>Attachments</th></tr></thead><tbody><tr><td>1</td>'
          '<td>Class Activity 1</td><td>Class Activity</td>'
          '<td>2026-10-08 11:01</td><td>2026-10-08 13:00</td>'
          '<td></td><td></td></tr></tbody></table>';
      final list = parseCourseAssessments(html);
      expect(list.length, 1);
      expect(list.first.name, 'Class Activity 1');
      expect(list.first.type, 'Class Activity');
      expect(list.first.dueDate, contains('13:00'));
    });
  });
}
