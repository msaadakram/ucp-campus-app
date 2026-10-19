import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/auth/student_portal.dart';
import 'package:ucp/screens/course_detail.dart';
import 'package:ucp/screens/materials_web.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

Widget _wrap(Widget child) {
  final colors = AppColors.of(AppPalette.skater, false);
  return MaterialApp(
    home: Scaffold(
      body: child,
    ),
    builder: (ctx, child) => AppScope(
      colors: colors,
      palette: AppPalette.skater,
      child: child!,
    ),
  );
}

const _courses = [
  PortalCourse(
      name: 'Object Oriented Programming',
      teacher: 'Aasma Abdul Waheed',
      code: 'CP223',
      credits: 3.0,
      attendance: 75.0,
      infoUrl: '/student/course/info/TEST1234abcd'),
  PortalCourse(
      name: 'Data Structures',
      teacher: 'Ali Haider',
      code: 'CP233',
      credits: 3.0,
      attendance: 60.0,
      infoUrl: '/student/course/info/TEST5678wxyz'),
];

const _materialHtml = '<table><thead><tr><th>Sr No.</th>'
    '<th>Course Material File</th><th>Description</th><th>Download</th>'
    '</tr></thead><tbody><tr><td>1</td><td>OOP-WEEK1.cpp</td>'
    '<td>Week 1 code</td>'
    '<td><a href="/student/class/material/download/abc123">dl</a></td>'
    '</tr></tbody></table>';

void main() {
  group('MaterialsScreen (bottom-bar Material tab)', () {
    testWidgets('live mode lists every course material page link',
        (t) async {
      final opened = <String>[];
      await t.pumpWidget(_wrap(MaterialsScreen(
        portalCourses: _courses,
        onOpenCourse: (pc) => opened.add(pc.name),
      )));
      await t.pumpAndSettle();
      expect(find.text('Material pages'), findsOneWidget);
      expect(find.text('Object Oriented Programming'), findsOneWidget);
      expect(find.text('Data Structures'), findsOneWidget);
      // Past papers: coming soon in live mode too.
      expect(find.text('Past paper session is coming soon'), findsOneWidget);
      await t.tap(find.text('Data Structures'));
      await t.pumpAndSettle();
      expect(opened, ['Data Structures']);
    });

    testWidgets('sample mode keeps mock files + coming-soon papers',
        (t) async {
      await t.pumpWidget(_wrap(const MaterialsScreen()));
      await t.pumpAndSettle();
      // Bundled course pills + sample files.
      expect(find.text('Lecture 6 — slides'), findsOneWidget);
      await t.tap(find.text('Past papers'));
      await t.pumpAndSettle();
      expect(find.text('Past paper session is coming soon'), findsOneWidget);
      expect(find.text('Practiced'), findsNothing); // mock list gone
    });
  });

  group('CourseDetailScreen initialTab', () {
    testWidgets('opens straight on the Material tab', (t) async {
      await t.pumpWidget(_wrap(CourseDetailScreen(
        portalCourse: _courses.first,
        back: () {},
        initialTab: 'material',
        debugHtml: const {'material': _materialHtml},
      )));
      await t.pumpAndSettle();
      expect(find.text('OOP-WEEK1.cpp'), findsOneWidget);
      // Garbage tabs fall back to news safely (different course so the
      // controller rebuilds — same-course pumpWidget reuses the State).
      await t.pumpWidget(_wrap(CourseDetailScreen(
        portalCourse: _courses.last,
        back: () {},
        initialTab: 'nonsense',
        debugHtml: const {'material': _materialHtml},
      )));
      await t.pumpAndSettle();
      expect(find.text('OOP-WEEK1.cpp'), findsNothing);
      // News tab (fallback) with no canned HTML and no session → the
      // screen's honest expired-session error, never the material list.
      expect(find.textContaining('sign in again'), findsOneWidget);
    });
  });
}
