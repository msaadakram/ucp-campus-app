import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/auth/course_cache.dart';
import 'package:ucp/auth/student_portal.dart';
import 'package:ucp/screens/course_detail.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

Widget _wrap(Widget child) {
  final colors = AppColors.of(AppPalette.skater, false);
  return MaterialApp(
    home: AppScope(colors: colors, palette: AppPalette.skater, child: child),
  );
}

const _pc = PortalCourse(
  name: 'Object Oriented Programming',
  teacher: 'Aasma Abdul Waheed',
  code: 'CP223',
  credits: 3.0,
  attendance: 75.0,
  infoUrl: '/student/course/info/pBG3ykar5ZOkdJ8v4NYV',
);

const _newsHtml = '<table><thead><tr><th>Sr No.</th><th>Subject</th>'
    '<th>Date</th><th>Description</th><th>Attachment</th></tr></thead>'
    '<tbody><tr><td>1</td><td>Midterm venue</td><td>2026-10-10</td>'
    '<td>Room C-301</td><td></td></tr></tbody></table>';

const _outlineHtml = '<h5>Assessment and Evaluation:</h5>'
    '<table><thead><tr><th>Assessment Type</th><th>Weightage %</th>'
    '<th>Consider Top</th></tr></thead><tbody>'
    '<tr><td>Final Term</td><td>40.0</td><td>0</td></tr>'
    '</tbody></table>';

void main() {
  setUp(() => CourseDetailCache.clear());

  testWidgets('header plus news list renders', (t) async {
    await t.pumpWidget(_wrap(CourseDetailScreen(
      portalCourse: _pc,
      back: () {},
      debugHtml: const {'news': _newsHtml},
    )));
    await t.pumpAndSettle();
    expect(find.text('Object Oriented Programming'), findsWidgets);
    expect(find.text('Midterm venue'), findsOneWidget);
    expect(find.text('News'), findsWidgets);
    expect(find.text('Outline'), findsOneWidget);
  });

  testWidgets('renders in dark mode without layout errors', (t) async {
    final dark = AppColors.of(AppPalette.skater, true);
    await t.pumpWidget(MaterialApp(
      home: AppScope(
        colors: dark,
        palette: AppPalette.skater,
        child: CourseDetailScreen(
          portalCourse: _pc,
          back: () {},
          debugHtml: const {'news': _newsHtml, 'outline': _outlineHtml},
        ),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text('Midterm venue'), findsOneWidget);
    await t.tap(find.text('Outline'));
    await t.pumpAndSettle();
    expect(find.text('Final Term'), findsOneWidget);
  });
}
