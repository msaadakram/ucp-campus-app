import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/auth/course_cache.dart';
import 'package:ucp/auth/student_portal.dart';
import 'package:ucp/screens/course_detail.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

Widget _wrap2(Widget child) {
  final colors = AppColors.of(AppPalette.skater, false);
  return MaterialApp(
    home: AppScope(colors: colors, palette: AppPalette.skater, child: child),
  );
}

const _pc2 = PortalCourse(
  name: 'Object Oriented Programming',
  teacher: 'Aasma Abdul Waheed',
  code: 'CP223',
  credits: 3.0,
  attendance: 75.0,
  infoUrl: '/student/course/info/TEST1234abcd',
);

const _news2 = '<table><thead><tr><th>Sr No.</th><th>Subject</th>'
    '<th>Date</th><th>Description</th><th>Attachment</th></tr></thead>'
    '<tbody><tr><td>1</td><td>Midterm venue</td><td>2026-10-10</td>'
    '<td>Room C-301</td><td></td></tr></tbody></table>';

const _outline2 = '<h5>Assessment and Evaluation:</h5>'
    '<table><thead><tr><th>Assessment Type</th><th>Weightage %</th>'
    '<th>Consider Top</th></tr></thead><tbody>'
    '<tr><td>Final Term</td><td>40.0</td><td>0</td></tr>'
    '</tbody></table>';

const _material2 = '<table><thead><tr><th>Sr No.</th>'
    '<th>Course Material File</th><th>Description</th><th>Download</th>'
    '</tr></thead><tbody><tr><td>1</td><td>OOP-WEEK1.cpp</td>'
    '<td>Week 1 code</td>'
    '<td><a href="/student/class/material/download/abc123">dl</a></td>'
    '</tr><tr><td>2</td><td>CP223 Outline.docx</td>'
    '<td>Course Outline</td>'
    '<td><a href="/student/class/material/download/def456">dl</a></td>'
    '</tr></tbody></table>';

const _grade2 = '<table><thead><tr><th>Assessment Type</th>'
    '<th>Obtained Percentage</th></tr></thead><tbody><tr>'
    '<td>Quiz 15.0 %</td><td>80.00</td></tr></tbody></table>';

void main() {
  setUp(() => CourseDetailCache.clear());

  testWidgets('tab switching loads outline then material', (t) async {
    await t.pumpWidget(_wrap2(CourseDetailScreen(
      portalCourse: _pc2,
      back: () {},
      debugHtml: const {
        'news': _news2,
        'outline': _outline2,
        'material': _material2,
      },
    )));
    await t.pumpAndSettle();
    expect(find.text('Midterm venue'), findsOneWidget);

    await t.tap(find.text('Outline'));
    await t.pumpAndSettle();
    expect(find.text('Final Term'), findsOneWidget);
    expect(find.text('40.0%', skipOffstage: false), findsWidgets);

    await t.tap(find.text('Material'));
    await t.pumpAndSettle();
    expect(find.text('OOP-WEEK1.cpp'), findsOneWidget);
    // Subject-wise sections render with their headers + file counts.
    // (Section header AND the fixture's file description say
    // "Course Outline", so findsWidgets.)
    expect(find.text('Week 1'), findsOneWidget);
    expect(find.text('Course Outline'), findsWidgets);
    expect(find.text('1 file'), findsWidgets);
  });

  testWidgets('grades tab shows summary bar', (t) async {
    await t.pumpWidget(_wrap2(CourseDetailScreen(
      portalCourse: _pc2,
      back: () {},
      debugHtml: const {'news': _news2, 'gradebook': _grade2},
    )));
    await t.pumpAndSettle();
    await t.tap(find.text('Grades'));
    await t.pumpAndSettle();
    expect(find.text('Quiz'), findsOneWidget);
    expect(find.text('80.0%', skipOffstage: false), findsWidgets);
  });

  testWidgets('missing portal link shows setup error', (t) async {
    const noLink = PortalCourse(
      name: 'Sample',
      teacher: 'T',
      code: 'CS 101',
      credits: 3,
      attendance: 50,
      infoUrl: '',
    );
    await t.pumpWidget(_wrap2(CourseDetailScreen(
      portalCourse: noLink,
      back: () {},
      debugHtml: const {},
    )));
    await t.pumpAndSettle();
    expect(find.textContaining('no portal link'), findsOneWidget);
  });
}
