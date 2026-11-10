// Widget tests for the redesigned course pages: summary strips,
// countdown pills, window states and attendance breakdowns.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/auth/course_cache.dart';
import 'package:ucp/auth/course_detail.dart';
import 'package:ucp/auth/student_portal.dart';
import 'package:ucp/screens/course_detail.dart';
import 'package:ucp/screens/course_detail_tabs_b.dart';
import 'package:ucp/screens/course_detail_tabs_c.dart';
import 'package:ucp/screens/course_detail_tabs_d.dart';
import 'package:ucp/screens/course_detail_tabs_e.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/web/portal_downloader.dart';
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

const _outline2 = '<h5>Assessment and Evaluation:</h5>'
    '<table><thead><tr><th>Assessment Type</th><th>Weightage %</th>'
    '<th>Consider Top</th></tr></thead><tbody>'
    '<tr><td>Final Term</td><td>40.0</td><td>0</td></tr>'
    '</tbody></table>'
    '<h5>Course Objectives:</h5>'
    '<ul><li>Understand the fundamentals of object oriented thinking</li></ul>';

const _assess2 = '<table><thead><tr><th>Sr No.</th><th>Name</th><th>Type</th>'
    '<th>Date</th><th>Due Date</th><th>Upload</th></tr></thead>'
    '<tbody><tr><td>1</td><td>Lab Report 1</td><td>Assignment</td>'
    '<td>2000-01-01 09:00</td><td>2000-01-10 13:00</td><td>Yes</td></tr>'
    '<tr><td>2</td><td>Final Project</td><td>Project</td>'
    '<td>2000-01-02 09:00</td><td>2080-12-31 13:00</td><td>No upload</td></tr>'
    '</tbody></table>';

const _submission2 = '<table><thead><tr><th>Sr No.</th><th>Name</th>'
    '<th>Description</th><th>Start Date</th><th>Due Date</th>'
    '<th>Attachment</th></tr></thead>'
    '<tbody><tr><td>1</td><td>Lab Report 1</td>'
    '<td>Submit your final lab report here</td>'
    '<td>2000-01-01 09:00</td><td>2000-02-01 13:00</td>'
    '<td>Attach</td></tr></tbody></table>';

const _submissionLink2 = '<table><thead><tr><th>Sr No.</th><th>Name</th>'
    '<th>Description</th><th>Start Date</th><th>Due Date</th>'
    '<th>Attachment</th></tr></thead>'
    '<tbody><tr><td>1</td><td>Lab Report 1</td>'
    '<td>Submit your final lab report here — rubric attached. Your report is judged on code completeness, style and the write-up.</td>'
    '<td>2000-01-01 09:00</td><td>2080-12-31 13:00</td>'
    '<td><a href="/student/class/submission/download/abc123">Lab Rubric F2026.pdf</a></td></tr></tbody></table>';

class _FakeDl extends PortalDownloader {
  int startCalls = 0;
  @override
  Future<String?> findDownloaded(String fileName) async => null;
  @override
  Future<PortalDownload> start({
    required String url,
    required String? sessionId,
    String? fileName,
    String method = 'GET',
    Map<String, String>? fields,
  }) async {
    startCalls++;
    return PortalDownload(
      id: 'sub-1',
      url: url,
      fileName: fileName ?? 'file',
      mimeType: 'application/pdf',
      totalBytes: 10,
      receivedBytes: 10,
      status: DownloadStatus.complete,
      filePath: '/data/sub/rubric.pdf',
    );
  }
}

const _grade2 = '<table>'
    '<tr class="table-parent-row show_child_row">'
    '<td><a href="#" class="js-toggle-children-row toggle-childrens">'
    ' Quiz <div class="uk-badge md-bg-orange-800"> 15.0 % </div>'
    ' </a> </td> <td class=""> 80.00 </td> </tr>'
    '<tr class="table-child-row md-bg-blue-grey-800"><th>Assessment</th>'
    '<th>Max Mark</th><th>Obtained Marks</th><th>Class Average</th>'
    '<th>Percentage</th></tr>'
    '<tr class="table-child-row"><td>Quiz 1</td><td>20</td><td>16</td>'
    '<td>12</td><td>80.00</td></tr></table>';

const _attend2 = '<table><thead><tr><th>Sr. no</th><th>Date</th>'
    '<th>Status</th><th>Fine</th></tr></thead><tbody>'
    '<tr><td>1</td><td>2026-10-01</td><td>Present</td><td>-</td></tr>'
    '<tr><td>2</td><td>2026-10-02</td><td>Present</td><td>-</td></tr>'
    '<tr><td>3</td><td>2026-10-05</td><td>Present</td><td>-</td></tr>'
    '<tr><td>4</td><td>2026-10-08</td><td>Absent</td><td>100</td></tr>'
    '</tbody></table>';

void main() {
  setUp(() => CourseDetailCache.clear());

  testWidgets('outline body shows the marks distribution and objectives',
      (t) async {
    await t.pumpWidget(_wrap2(CourseDetailScreen(
      portalCourse: _pc2,
      back: () {},
      debugHtml: const {'news': '', 'outline': _outline2},
    )));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Outline'));
    await t.pumpAndSettle();
    await t.tap(find.text('Outline'));
    await t.pumpAndSettle();
    expect(find.text('Marks distribution'), findsOneWidget);
    expect(find.text('Course objectives'), findsOneWidget);
    expect(
      find.text(
          'Understand the fundamentals of object oriented thinking'),
      findsWidgets,
    );
    expect(find.text('Final Term'), findsWidgets);
    // The distribution bar and the type row both carry the total share.
    expect(find.text('40.0%', skipOffstage: false), findsWidgets);
  });

  testWidgets('assessments tab groups overdue and upcoming with counts',
      (t) async {
    await t.pumpWidget(_wrap2(CourseDetailScreen(
      portalCourse: _pc2,
      back: () {},
      debugHtml: const {'news': '', 'assessments': _assess2},
    )));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Assess'));
    await t.pumpAndSettle();
    await t.tap(find.text('Assess'));
    await t.pumpAndSettle();
    expect(find.text('Overdue'), findsWidgets);
    expect(find.text('Upcoming'), findsWidgets);
    expect(find.text('Lab Report 1'), findsOneWidget);
    expect(find.text('Final Project'), findsOneWidget);
    // The countdown pill calls out that the overdue row is late.
    expect(find.textContaining('Late by'), findsOneWidget);
    // Upload status is shown per row (one open, one closed).
    expect(find.text('Upload open'), findsWidgets);
    expect(find.text('Upload closed'), findsOneWidget);
    // Both due dates are spelled out with the time.
    expect(find.textContaining('Due Mon 10 Jan 2000'), findsOneWidget);
  });

  testWidgets('submissions tab shows the closed window and attachments',
      (t) async {
    await t.pumpWidget(_wrap2(CourseDetailScreen(
      portalCourse: _pc2,
      back: () {},
      debugHtml: const {'news': '', 'submission': _submission2},
    )));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Submit'));
    await t.pumpAndSettle();
    await t.tap(find.text('Submit'));
    await t.pumpAndSettle();
    expect(find.text('Closed'), findsWidgets);
    expect(find.text('Attachment included'), findsOneWidget);
    expect(find.textContaining('Window closed'), findsOneWidget);
    expect(find.textContaining('Submit your final lab report'), findsOneWidget);
  });

  testWidgets('submissions tab shows the full detail and attachment card',
      (t) async {
    final dl = _FakeDl();
    final opened = <String>[];
    await t.pumpWidget(_wrap2(CourseDetailScreen(
      portalCourse: _pc2,
      back: () {},
      downloader: dl,
      onOpenFile: (p) async => opened.add(p),
      debugHtml: const {'news': '', 'submission': _submissionLink2},
    )));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Submit'));
    await t.pumpAndSettle();
    await t.tap(find.text('Submit'));
    await t.pumpAndSettle();
    // The FULL description, not a preview fragment.
    expect(find.textContaining('code completeness'), findsOneWidget);
    expect(find.textContaining('rubric attached'), findsOneWidget);
    // The attachment is a real, named card with a download action.
    expect(find.text('Lab Rubric F2026.pdf'), findsOneWidget);
    expect(find.text('Save / open in the app'), findsOneWidget);
    expect(find.byIcon(Icons.download), findsOneWidget);
    // Tapping it downloads and auto-opens via the same pipeline.
    await t.tap(find.byIcon(Icons.download));
    await t.pumpAndSettle();
    expect(dl.startCalls, 1);
    expect(opened, ['/data/sub/rubric.pdf']);
  });

  testWidgets('grades tab groups marks under their type with class avg',
      (t) async {
    await t.pumpWidget(_wrap2(CourseDetailScreen(
      portalCourse: _pc2,
      back: () {},
      onOpenLeaderboard: (_) {},
      debugHtml: const {'news': '', 'gradebook': _grade2},
    )));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Grades'));
    await t.pumpAndSettle();
    await t.tap(find.text('Grades'));
    await t.pumpAndSettle();
    // Overall hero letter + the weighted points line.
    expect(find.text('Overall so far'), findsOneWidget);
    expect(find.textContaining('weighted points earned'), findsOneWidget);
    // The child row shows marks, and the class average line
    // contrasts with the student.
    expect(find.text('16/20'), findsOneWidget);
    expect(find.textContaining('Class avg 12.0'), findsOneWidget);
    // The leaderboard action is still available.
    expect(find.text('See class leaderboard'), findsOneWidget);
  });

  testWidgets('every modern tab body renders without overflow on a 320dp phone',
      (t) async {
    await t.binding.setSurfaceSize(const Size(320, 780));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final c = AppColors.of(AppPalette.skater, false);
    final outline = parseCourseOutline(_outline2);
    final bodies = <String, Widget>{
      'outline': courseOutlineBody(c, outline),
      'outline-plan': courseOutlinePlan(c, outline),
      'assessments': courseAssessBody(c, parseCourseAssessments(_assess2)),
      'submissions': courseSubmissionBody(c, parseCourseSubmissions(_submission2)),
      'grades': courseGradesBody(c, parseCourseGradebook(_grade2)),
      'attendance': courseAttendanceBody(c, parseCourseAttendance(_attend2)),
    };
    for (final entry in bodies.entries) {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: entry.value,
          ),
        ),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull,
          reason: 'body ${entry.key} overflowed at 320dp');
    }
  });

  testWidgets('attendance tab breaks the records into counts and a bar',
      (t) async {
    await t.pumpWidget(_wrap2(CourseDetailScreen(
      portalCourse: _pc2,
      back: () {},
      debugHtml: const {'news': '', 'attendance': _attend2},
    )));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Attend'));
    await t.pumpAndSettle();
    await t.tap(find.text('Attend'));
    await t.pumpAndSettle();
    expect(find.text('3 of 4 classes attended'), findsOneWidget);
    expect(find.text('Fine 100'), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
    // The segmented mix bar renders present/absent/other counts.
    expect(find.text('Leave/Other'), findsOneWidget);
    expect(find.text('Fines'), findsOneWidget);
  });
}
