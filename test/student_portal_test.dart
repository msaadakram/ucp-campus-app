import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/auth/student_portal.dart';

void main() {
  group('timetable (real markup)', () {
        const html = '<li class=" md-color-blue-grey-900" style="background: none; box-shadow: none; font-size: 15px;"> <b>Term :</b> <span>Fall 2026</span> </li><li class="md-color-blue-grey-900" style="background: none; box-shadow: none; font-size: 15px;"> <b>Month :</b> <span> October </span> </li><li class="cd-schedule__group"> <div class="cd-schedule__top-info"><span>Monday</span></div> <ul> <li class="cd-schedule__event" style="top: -1px; height: 92.66666666666667px"> <a id="" style="margin:0px;padding:3px;" data-event="event-1" data-start="08:00" data-end="08:55" data-content="week[\'subject\']"> <em style="font-size:10px !important;" class="cd-schedule__name uk-text-small"> Dr. A Khan </em> <span style="font-size:9px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> Object Oriented Programming - Lab </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> CP221-F26-BS-CS-F25-C6 </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> B-CL203 ( Lab ) </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> </span> </a> </li> <li class="cd-schedule__event" style="top: 99px; height: 92.66666666666667px"> <a id="" style="margin:0px;padding:3px;" data-event="event-1" data-start="09:00" data-end="09:55" data-content="week[\'subject\']"> <em style="font-size:10px !important;" class="cd-schedule__name uk-text-small"> Dr. A Khan </em> <span style="font-size:9px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> Object Oriented Programming - Lab </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> CP221-F26-BS-CS-F25-C6 </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> B-CL203 ( Lab ) </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> </span> </a> </li> <li class="cd-schedule__event" style="top: 199px; height: 92.66666666666667px"> <a id="" style="margin:0px;padding:3px;" data-event="event-1" data-start="10:00" data-end="10:55" data-content="week[\'subject\']"> <em style="font-size:10px !important;" class="cd-schedule__name uk-text-small"> Dr. A Khan </em> <span style="font-size:9px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> Object Oriented Programming - Lab </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> CP221-F26-BS-CS-F25-C6 </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> B-CL203 ( Lab ) </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> </span> </a> </li> <li class="cd-schedule__event" style="top: 299px; height: 92.66666666666667px"> <a id="" style="margin:0px;padding:3px;" data-event="event-1" data-start="11:00" data-end="11:55" data-content="week[\'subject\']"> <em style="font-size:10px !important;" class="cd-schedule__name uk-text-small"> Dr. C Raza </em> <span style="font-size:9px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> Fundamentals of Entrepreneurship </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> ENT102-F26-BS-CS-F25-C6 </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> B-108 ( Lecture ) </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> </span> </a> </li> <li class="cd-schedule__event" style="top: 399px; height: 92.66666666666667px"> <a id="" style="margin:0px;padding:3px;" data-event="event-1" data-start="12:00" data-end="12:55" data-content="week[\'subject\']"> <em style="font-size:10px !important;" class="cd-schedule__name uk-text-small"> Dr. C Raza </em> <span style="font-size:9px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> Fundamentals of Entrepreneurship </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> ENT102-F26-BS-CS-F25-C6 </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> B-108 ( Lecture ) </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> </span> </a> </li> </ul> </li><li class="cd-schedule__group"> <div class="cd-schedule__top-info"><span>Tuesday</span></div> <ul> <li class="cd-schedule__event" style="top: -1px; height: 92.66666666666667px"> <a id="" style="margin:0px;padding:3px;" data-event="event-2" data-start="08:00" data-end="08:55" data-content="week[\'subject\']"> <em style="font-size:10px !important;" class="cd-schedule__name uk-text-small"> Ms. B Iqbal </em> <span style="font-size:9px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> Probability and Statistics </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> MAT253-F26-BS-CS-F25-C15 </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> A-101 ( Lecture ) </span> </a> </li> <li class="cd-schedule__event" style="top: 99px; height: 92.66666666666667px"> <a id="" style="margin:0px;padding:3px;" data-event="event-2" data-start="09:00" data-end="09:55" data-content="week[\'subject\']"> <em style="font-size:10px !important;" class="cd-schedule__name uk-text-small"> Ms. B Iqbal </em> <span style="font-size:9px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> Probability and Statistics </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> MAT253-F26-BS-CS-F25-C15 </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> A-101 ( Lecture ) </span> </a> </li> <li class="cd-schedule__event" style="top: 399px; height: 92.66666666666667px"> <a id="" style="margin:0px;padding:3px;" data-event="event-2" data-start="12:00" data-end="12:55" data-content="week[\'subject\']"> <em style="font-size:10px !important;" class="cd-schedule__name uk-text-small"> Mr. D Tariq </em> <span style="font-size:9px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> Computer Organization and Assembly .. </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> AR223-F26-BS-CS-F25-C1 </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> A-111 ( Lecture ) </span> </a> </li> <li class="cd-schedule__event" style="top: 499px; height: 92.66666666666667px"> <a id="" style="margin:0px;padding:3px;" data-event="event-2" data-start="13:00" data-end="13:55" data-content="week[\'subject\']"> <em style="font-size:10px !important;" class="cd-schedule__name uk-text-small"> Mr. D Tariq </em> <span style="font-size:9px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> Computer Organization and Assembly .. </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> AR223-F26-BS-CS-F25-C1 </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> A-111 ( Lecture ) </span> </a> </li> <li class="cd-schedule__event" style="top: 599px; height: 92.66666666666667px"> <a id="" style="margin:0px;padding:3px;" data-event="event-2" data-start="14:00" data-end="14:55" data-content="week[\'subject\']"> <em style="font-size:10px !important;" class="cd-schedule__name uk-text-small"> Seema Mazhar </em> <span style="font-size:9px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> Multivariable Calculus </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> MAT243-F26-BS-CS-F25-C7 </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> A-108 ( Lecture ) </span> </a> </li> <li class="cd-schedule__event" style="top: 699px; height: 92.66666666666667px"> <a id="" style="margin:0px;padding:3px;" data-event="event-2" data-start="15:00" data-end="15:55" data-content="week[\'subject\']"> <em style="font-size:10px !important;" class="cd-schedule__name uk-text-small"> Seema Mazhar </em> <span style="font-size:9px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> Multivariable Calculus </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> MAT243-F26-BS-CS-F25-C7 </span> <span style="font-size:10px !important;margin:0px !important;" class="cd-schedule__name uk-text-small"> A-108 ( Lecture ) </span> </a> </li> </ul> </li>';

    test('term, days and full slot detail', () {
      final d = parseTimetable(html);
      expect(d.term, 'Fall 2026');
      expect(d.month, 'October');
      expect(d.slots.length, 11);
      final first = d.slots.first;
      expect(first.day, 'Monday');
      expect(first.start, '08:00');
      expect(first.end, '08:55');
      expect(first.teacher, 'Dr. A Khan');
      expect(first.subject, 'Object Oriented Programming - Lab');
      expect(first.section, 'CP221-F26-BS-CS-F25-C6');
      expect(first.room, 'B-CL203 ( Lab )');
      expect(first.isLab, isTrue);
      final tue = d.slots.where((s) => s.day == 'Tuesday').toList();
      expect(tue.length, 6);
      expect(tue.last.isLab, isFalse);
    });

    test('garbage never throws', () {
      expect(parseTimetable('').slots, isEmpty);
      expect(parseTimetable('<div>nope').term, '');
    });
  });

  group('attendance (real markup)', () {
    const html = '<h3 class="mt-3 uk-accordion-title" style="padding-left: 2px;" id="course_3413277"> <div class="d-flex justify-content-between"> <span>Fundamentals of Entrepreneurship</span> <div> <span>Attendance: 0.0%</span> <div class="uk-progress uk-progress-mini uk-progress-danger uk-margin-remove mb-2"> <div class="uk-progress-bar" style="width: 0.0%;"></div> </div> </div> </div> </h3><table class="uk-table uk-text-nowrap"> <thead style="background:##112B4F; color:white;"> <tr> <th style="color:white;">Sr. no</th> <th style="color:white;">Date</th> <th style="color:white;">Status</th> <th style="color:white;">Fine</th> </tr> </thead> <tbody style="color:black;"> <tr> <td> <span>1</span> </td> <td> <span>2026-09-28</span> </td> <td> <span>Leave</span> </td> <td> <span>-</span> </td> </tr> <tr> <td> <span>2</span> </td> <td> <span>2026-09-28</span> </td> <td> <span>Leave</span> </td> <td> <span>-</span> </td> </tr> </tbody> </table><h3 class="mt-3 uk-accordion-title" style="padding-left: 2px;" id="course_3413271"> <div class="d-flex justify-content-between"> <span>Object Oriented Programming</span> <div> <span>Attendance: 67.0%</span> <div class="uk-progress uk-progress-mini uk-progress-danger uk-margin-remove mb-2"> <div class="uk-progress-bar" style="width: 67.0%;"></div> </div> </div> </div> </h3><table class="uk-table uk-text-nowrap"> <thead style="background:##112B4F; color:white;"> <tr> <th style="color:white;">Sr. no</th> <th style="color:white;">Date</th> <th style="color:white;">Status</th> <th style="color:white;">Fine</th> </tr> </thead> <tbody style="color:black;"> <tr> <td> <span>1</span> </td> <td> <span>2026-10-01</span> </td> <td> <span>Present</span> </td> <td> <span>-</span> </td> </tr> <tr> <td> <span>2</span> </td> <td> <span>2026-10-01</span> </td> <td> <span>Present</span> </td> <td> <span>-</span> </td> </tr> <tr> <td> <span>3</span> </td> <td> <span>2026-10-02</span> </td> <td> <span>Absent</span> </td> <td> <span>-</span> </td> </tr> </tbody> </table>';

    test('courses with percentages and daily records', () {
      final courses = parseAttendance(html);
      expect(courses.length, 2);
      expect(courses[0].name, 'Fundamentals of Entrepreneurship');
      expect(courses[0].percent, 0.0);
      expect(courses[1].name, 'Object Oriented Programming');
      expect(courses[1].percent, 67.0);
      expect(courses[0].records.length, greaterThan(0));
      final r = courses[0].records.first;
      expect(r.date, isNotEmpty);
      expect(['Present', 'Absent', 'Leave'], contains(r.status));
    });

    test('garbage never throws', () {
      expect(parseAttendance(''), isEmpty);
    });
  });

  group('invoices (real markup)', () {
    const html = '<table id="" class="uk-table uk-table-nowrap table_check"> <thead class="md-bg-blue-grey-700 "> <tr> <th class="uk-width-1-10 md-color-grey-50 ">Invoice Date</th> <th class="uk-width-1-10 md-color-grey-50 ">Due Date</th> <th class="uk-width-1-10 md-color-grey-50 ">Term</th> <th class="uk-width-1-10 md-color-grey-50 ">Semester</th> <th class="uk-width-1-10 md-color-grey-50 ">Challan Type</th> <th class="uk-width-1-10 md-color-grey-50 ">Challan ID</th> <th class="uk-width-1-10 md-color-grey-50 ">Scholarship %</th> <th class="uk-width-1-10 md-color-grey-50 ">Payable Amount</th> <th class="uk-width-1-10 md-color-grey-50 ">Status</th> <th class="uk-width-1-10 md-color-grey-50 ">Print/Save</th> <th class="uk-width-1-10 md-color-grey-50 ">Action</th> <th class="uk-width-1-10 md-color-grey-50 ">Paid Date</th> </tr> </thead> <tbody> <tr> <td>2025-09-04</td> <td>2025-12-15</td> <td>Fall 2025</td> <td>-</td> <td> 2nd Challan </td> <td>145830111111</td> <td>50.0</td> <td>0</td> <td> <span class="uk-badge uk-badge-success"> Paid </span> </td> <td> </td> <td> </td> <td>2025-12-12</td> </tr> <tr> <td>2026-02-11</td> <td>2026-02-23</td> <td>Spring 2026</td> <td>-</td> <td> Main Challan </td> <td>145830111111</td> <td>50.0</td> <td>0</td> <td> <span class="uk-badge uk-badge-success"> Paid </span> </td> <td> </td> <td> </td> <td>2026-02-23</td> </tr> <tr> <td>2026-02-11</td> <td>2026-04-24</td> <td>Spring 2026</td> <td>-</td> <td> 2nd Challan </td> <td>145830111111</td> <td>50.0</td> <td>0</td> <td> <span class="uk-badge uk-badge-success"> Paid </span> </td> <td> </td> <td> </td> <td>2026-04-22</td> </tr> <tr> <td>2026-09-29</td> <td>2026-10-01</td> <td>Fall 2026</td> <td>-</td> <td> Main Challan </td> <td>145830111111</td> <td>50.0</td> <td>0</td> <td> <span class="uk-badge uk-badge-success"> Paid </span> </td> <td> </td> <td> </td> <td>2026-10-01</td> </tr> </tbody> </table>';

    test('challan rows with all columns', () {
      final list = parseInvoices(html);
      expect(list.length, 4);
      final first = list.first;
      expect(first.term, isNotEmpty);
      expect(first.challanId, isNotEmpty);
      expect(first.status, 'Paid');
      expect(first.isPaid, isTrue);
      expect(list.every((i) => i.amount.isNotEmpty), isTrue);
    });

    test('garbage never throws', () {
      expect(parseInvoices('no tables here'), isEmpty);
    });
  });

  group('results (real markup)', () {
    const html = '<table class="uk-table uk-table-nowrap uk-table-align-vertical table_tree"> <thead> <tr> <th class="uk-width-1-10 ">Term</th> <th class="uk-width-1-10 uk-text-center ">Grade Points</th> <th class="uk-width-1-10 uk-text-center ">Cumulative GP</th> <th class="uk-width-1-10 uk-text-center ">Attempted CH</th> <th class="uk-width-1-10 uk-text-center ">Earned CH</th> <th class="uk-width-1-10 uk-text-center ">Cumulative CH</th> <th class="uk-width-1-10 uk-text-center ">SGPA</th> <th class="uk-width-1-10 uk-text-center ">CGPA</th> </tr> </thead> <tbody> <tr class="table-parent-row show_child_row"> <td> <a href="#" class="js-toggle-children-row toggle-childrens"> Fall 2025 </a> </td> <td class="uk-text-center"> 46.64 </td> <td class="uk-text-center"> 46.64 </td> <td class="uk-text-center"> 15.0 </td> <td class="uk-text-center"> 15.0 </td> <td class="uk-text-center"> 15.0 </td> <td class="uk-text-center"> 3.11 </td> <td class="uk-text-center"> 3.11 </td> </tr> <tr class="table-child-row md-bg-blue-grey-800 md-color-grey-50" style="display: none;"> <th>Course</th> <th>Credit Hours</th> <th>Grade Pts</th> <th>Final Grade</th> </tr> <tr class="table-child-row" style="display: none;"> <td class="uk-width-1-10 "> Introduction to Computing - Lab </td> <td class="uk-width-1-10 "> 1.0 </td> <td class="uk-width-1-10 "> 4.0 </td> <td class="uk-width-1-10 "> A </td> </tr> <tr class="table-child-row" style="display: none;"> <td class="uk-width-1-10 "> Basic Electronics </td> <td class="uk-width-1-10 "> 2.0 </td> <td class="uk-width-1-10 "> 6.66 </td> <td class="uk-width-1-10 "> B+ </td> </tr> <tr class="table-child-row" style="display: none;"> <td class="uk-width-1-10 "> Ideology and Constitution of Pakistan </td> <td class="uk-width-1-10 "> 2.0 </td> <td class="uk-width-1-10 "> 4.66 </td> <td class="uk-width-1-10 "> C+ </td> </tr> <tr class="table-child-row" style="display: none;"> <td class="uk-width-1-10 "> Functional English </td> <td class="uk-width-1-10 "> 3.0 </td> <td class="uk-width-1-10 "> 9.0 </td> <td class="uk-width-1-10 "> B </td> </tr> <tr class="table-child-row" style="display: none;"> <td class="uk-width-1-10 "> Discrete Structures </td> <td class="uk-width-1-10 "> 3.0 </td> <td class="uk-width-1-10 "> 6.99 </td> <td class="uk-width-1-10 "> C+ </td> </tr> <tr class="table-child-row" style="display: none;"> <td class="uk-width-1-10 "> Introduction to Computing </td> <td class="uk-width-1-10 "> 3.0 </td> <td class="uk-width-1-10 "> 12.0 </td> <td class="uk-width-1-10 "> A </td> </tr> <tr class="table-child-row" style="display: none;"> <td class="uk-width-1-10 "> Basic Electronics - Lab </td> <td class="uk-width-1-10 "> 1.0 </td> <td class="uk-width-1-10 "> 3.33 </td> <td class="uk-width-1-10 "> B+ </td> </tr> <tr class="table-parent-row show_child_row"> <td> <a href="#" class="js-toggle-children-row toggle-childrens"> Spring 2026 </a> </td> <td class="uk-text-center"> 47.35 </td> <td class="uk-text-center"> 93.99 </td> <td class="uk-text-center"> 15.0 </td> <td class="uk-text-center"> 15.0 </td> <td class="uk-text-center"> 30.0 </td> <td class="uk-text-center"> 3.16 </td> <td class="uk-text-center"> 3.13 </td> </tr> <tr class="table-child-row md-bg-blue-grey-800 md-color-grey-50" style="display: none;"> <th>Course</th> <th>Credit Hours</th> <th>Grade Pts</th> <th>Final Grade</th> </tr> <tr class="table-child-row" style="display: none;"> <td class="uk-width-1-10 "> Programming Fundamentals - Lab </td> <td class="uk-width-1-10 "> 1.0 </td> <td class="uk-width-1-10 "> 3.67 </td> <td class="uk-width-1-10 "> A- </td> </tr> <tr class="table-child-row" style="display: none;"> <td class="uk-width-1-10 "> Programming Fundamentals </td> <td class="uk-width-1-10 "> 3.0 </td> <td class="uk-width-1-10 "> 9.99 </td> <td class="uk-width-1-10 "> B+ </td> </tr> <tr class="table-child-row" style="display: none;"> <td class="uk-width-1-10 "> Expository Writing </td> <td class="uk-width-1-10 "> 3.0 </td> <td class="uk-width-1-10 "> 9.0 </td> <td class="uk-width-1-10 "> B </td> </tr> <tr class="table-child-row" style="display: none;"> <td class="uk-width-1-10 "> Digital Logic and Design - Lab </td> <td class="uk-width-1-10 "> 1.0 </td> <td class="uk-width-1-10 "> 2.0 </td> <td class="uk-width-1-10 "> C </td> </tr> <tr class="table-child-row" style="display: none;"> <td class="uk-width-1-10 "> Civics and Community Engagement </td> <td class="uk-width-1-10 "> 2.0 </td> <td class="uk-width-1-10 "> 7.34 </td> <td class="uk-width-1-10 "> A- </td> </tr> <tr class="table-child-row" style="display: none;"> <td class="uk-width-1-10 "> Calculus and Analytical Geometry </td> <td class="uk-width-1-10 "> 3.0 </td> <td class="uk-width-1-10 "> 8.01 </td> <td class="uk-width-1-10 "> B- </td> </tr> <tr class="table-child-row" style="display: none;"> <td class="uk-width-1-10 "> Digital Logic and Design </td> <td class="uk-width-1-10 "> 2.0 </td> <td class="uk-width-1-10 "> 7.34 </td> <td class="uk-width-1-10 "> A- </td> </tr> </tbody> </table>';

    test('term summaries with course grades', () {
      final d = parseResults(html);
      expect(d.terms.length, 2);
      expect(d.terms.first.term, 'Fall 2025');
      expect(d.terms.first.sgpa, '3.11');
      expect(d.terms.first.courses.length, greaterThan(3));
      final course = d.terms.first.courses.first;
      expect(course.name, contains('Introduction to Computing'));
      expect(course.grade, 'A');
      expect(d.terms[1].cgpa, '3.13');
    });

    test('garbage never throws', () {
      expect(parseResults('').isEmpty, isTrue);
    });
  });

  group('PLO table (real markup)', () {
    const html = '<table class="uk-table table_tree"><tr> <th class="uk-width-1-10 ">Code</th> <th class="uk-width-1-10 uk-text-center ">PLO Points</th> <th class="uk-width-1-10 uk-text-center ">PLO Level</th> <th class="uk-width-1-10 uk-text-center ">Attainment</th> <th class="uk-width-1-10 uk-text-center ">Description</th> </tr><tr> <td> PLO-1 </td> <td> 510.3809523809524 </td> <td> 10.0 </td> <td> 51.03809523809524 </td> <td> Academic Education </td> </tr><tr> <td> PLO-2 </td> <td> 2425.3153769841274 </td> <td> 32.0 </td> <td> 75.79110553075398 </td> <td> Knowledge for Solving Computing Problems </td> </tr></table>';

    test('attainment entries parse', () {
      final d = parseResults(html);
      expect(d.plos.length, 2);
      expect(d.plos.first.code, 'PLO-1');
      expect(d.plos.first.attainment, contains('%'));
      expect(d.isEmpty, isFalse);
    });
  });

  group('datesheet empty state (real markup)', () {
    const html = '<h3 class="uk-row-first"> DateSheet <hr> </h3><h3>Currently No Exam DateSheet Notified!</h3><h3 class="uk-modal-title">Your session is about to expire!</h3>';

    test('empty notice, no exams, never throws', () {
      final d = parseDatesheet(html);
      expect(d.isEmpty, isTrue);
      expect(d.notice, isNotEmpty);
      expect(parseDatesheet('garbage').isEmpty, isTrue);
    });
  });
}
