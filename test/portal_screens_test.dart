import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/screens/attendance.dart';
import 'package:ucp/screens/fee_board.dart';
import 'package:ucp/screens/gpa_timetable.dart';
import 'package:ucp/screens/results.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

Widget _wrap(Widget child) {
  final colors = AppColors.of(AppPalette.skater, false);
  return AppScope(
    colors: colors,
    palette: AppPalette.skater,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

const _ttHtml = '<div><b>Term :</b><span>Fall 2026</span>'
    '<b>Month :</b><span>October</span></div>'
    '<li class="cd-schedule__group">'
    '<div class="cd-schedule__top-info"><span>Monday</span></div><ul>'
    '<li class="cd-schedule__event"><a data-start="08:00" data-end="08:55">'
    '<em>Dr. A Khan</em>'
    '<span>Object Oriented Programming - Lab</span>'
    '<span>CP221-F26</span><span>B-CL203 ( Lab )</span>'
    '</a></li></ul></li>'
    '<li class="cd-schedule__group">'
    '<div class="cd-schedule__top-info"><span>Tuesday</span></div><ul>'
    '<li class="cd-schedule__event"><a data-start="09:00" data-end="09:55">'
    '<em>Ms. B Iqbal</em><span>Linear Algebra</span>'
    '<span>MA201-F26</span><span>Science Hall 11</span>'
    '</a></li></ul></li>';

const _dsEmpty =
    '<h3>DateSheet</h3><div><h3>Currently No Exam DateSheet Notified!</h3></div>';

const _attHtml = '<h3><div><span>Multivariable Calculus</span>'
    '<div><span>Attendance: 33.0%</span></div></div></h3>'
    '<table class="uk-table"><tr><th>Sr. no</th><th>Date</th><th>Status</th><th>Fine</th></tr>'
    '<tr><td>1</td><td>2026-09-28</td><td>Absent</td><td>-</td></tr>'
    '<tr><td>2</td><td>2026-09-29</td><td>Present</td><td>-</td></tr></table>';

const _feeHtml = '<table class="uk-table uk-table-nowrap table_check">'
    '<tr><th>Invoice Date</th><th>Due Date</th><th>Term</th><th>Semester</th>'
    '<th>Challan Type</th><th>Challan ID</th><th>Scholarship %</th>'
    '<th>Payable Amount</th><th>Status</th><th>Print/Save</th><th>Action</th>'
    '<th>Paid Date</th></tr>'
    '<tr><td>2026-09-29</td><td>2026-10-15</td><td>Fall 2026</td><td>-</td>'
    '<td>Main Challan</td><td>145830580658</td><td>50.0</td><td>86800</td>'
    '<td>Unpaid</td><td></td><td></td><td>-</td></tr></table>';

const _resHtml = '<table class="uk-table table_tree">'
    '<tr><th>Term</th><th>Grade Points</th><th>Cumulative GP</th>'
    '<th>Attempted CH</th><th>Earned CH</th><th>Cumulative CH</th>'
    '<th>SGPA</th><th>CGPA</th></tr>'
    '<tr><td>Fall 2025</td><td>46.64</td><td>46.64</td><td>15.0</td>'
    '<td>15.0</td><td>15.0</td><td>3.11</td><td>3.11</td></tr>'
    '<tr><td>Course</td><td>Credit Hours</td><td>Grade Pts</td>'
    '<td>Final Grade</td></tr>'
    '<tr><td>Functional English</td><td>3.0</td><td>9.0</td><td>B</td></tr>'
    '</table>';

void main() {
  group('portal screens with canned HTML', () {
    testWidgets('timetable shows real slots + datesheet empty state',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(TimetableScreen(
        fetchHtml: (path) async =>
            path.contains('datesheet') ? _dsEmpty : _ttHtml,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Object Oriented Programming - Lab'), findsOneWidget);
      expect(find.text('B-CL203 ( Lab )'), findsOneWidget);
      expect(find.textContaining('No Exam DateSheet Notified!'),
          findsOneWidget);
      // Switch day: Tuesday slot appears.
      await tester.tap(find.text('Tue'));
      await tester.pumpAndSettle();
      expect(find.text('Linear Algebra'), findsOneWidget);
    });

    testWidgets('attendance shows courses, expands records',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const AttendanceScreen(
        debugHtml: _attHtml,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Multivariable Calculus'), findsOneWidget);
      expect(find.text('33%', skipOffstage: false), findsNWidgets(2));
      await tester.tap(find.text('Multivariable Calculus'));
      await tester.pumpAndSettle();
      expect(find.text('2026-09-28'), findsOneWidget);
      expect(find.text('Absent'), findsWidgets);
    });

    testWidgets('fee shows real challan with unpaid summary',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const FeeChallanScreen(
        debugHtml: _feeHtml,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Challan 145830580658'), findsOneWidget);
      expect(find.text('Unpaid'), findsWidgets);
      expect(find.textContaining('86,800'), findsNWidgets(3));
    });

    testWidgets('results show terms, courses and PLO toggle',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const ResultsScreen(
        debugHtml: _resHtml,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Fall 2025'), findsOneWidget);
      expect(find.text('3.11'), findsWidgets);
      expect(find.text('Functional English'), findsOneWidget);
      expect(find.text('PLO attainment'), findsOneWidget);
    });
  });
}
