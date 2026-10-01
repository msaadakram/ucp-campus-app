import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ucp/auth/dashboard_parser.dart';
import 'package:ucp/auth/odoo_api.dart';
import 'package:ucp/auth/portal_api.dart';

const _cardHtml = '''
<html><head><title>Student Dashboard</title></head><body>
<h1 class="student-name">Ayaan Warraich</h1>
<div class="stat-card"><span class="value">3.62</span><small class="label">CGPA</small></div>
<div class="stat-card"><span class="value">52</span><small class="label">Credits</small></div>
<div class="stat-card"><span class="value">94%</span><small class="label">Attendance</small></div>
</body></html>
''';

const _tableHtml = '''
<html><body>
<h2>Muhammad Ali Raza</h2>
<table><tr><th>Program</th><td>BS Computer Science</td></tr>
<tr><th>Semester</th><td>Fall 2026</td></tr></table>
</body></html>
''';

void main() {
  group('parseDashboard', () {
    test('card grid: name + stats', () {
      final d = parseDashboard(_cardHtml);
      expect(d.studentName, 'Ayaan Warraich');
      expect(d.stats.length, 3);
      expect(d.stats[0].label, 'CGPA');
      expect(d.stats[0].value, '3.62');
      expect(d.stats[2].label, 'Attendance');
      expect(d.isEmpty, isFalse);
    });

    test('table fallback: heading name + row stats', () {
      final d = parseDashboard(_tableHtml);
      expect(d.studentName, 'Muhammad Ali Raza');
      expect(d.stats.length, 2);
      expect(d.stats[0].label, 'Program');
      expect(d.stats[0].value, 'BS Computer Science');
    });

    test('garbage never throws, yields empty', () {
      expect(parseDashboard('').isEmpty, isTrue);
      expect(parseDashboard('<html><body>hi').isEmpty, isTrue);
      expect(parseDashboard('<div><span>').isEmpty, isTrue);
    });

    test('duplicates are collapsed', () {
      final d = parseDashboard('$_cardHtml$_cardHtml');
      expect(d.stats.length, 3);
    });
  });



  group('real /student/dashboard markup (anonymized excerpt)', () {
    const realHtml = '<div class="user_heading_dash"><div class="user_heading_avatar"><div class="thumbnail"><img alt="user" src="avatar.jpg" data-savepage-loading="lazy"></div></div><div class="user_heading_content" style="padding: 2px 0;"><h2 class="heading_b" style="color:black;"><span class="uk-text-truncate">Test Student</span><span class="sub-heading" style="color:grey;">L1F25XXXX0000</span><span class="sub-heading" style="color:grey;">Faculty of Information Technology and Computer Science</span></h2></div><div></div></div></div><div class="uk-width-large-2-10" style=""><div class="user_heading_content"> Academic Standings: <br> CGPA: <span class="\'md-color-green-700\' if student.cgpa > 3.0 else \'md-color-orange-800\'"> 3.13 </span></div></div><div class="uk-width-large-2-10" style=""><div class="user_heading_content"><div>Earned Cr : 30.0 </div><div>Total Cr : 0.0 </div><div>Inprogress Cr : 0 </div></div></div><div class="uk-width-large-3-10" style=""><div class="user_heading_content d-flex flex-column"><strong> Today Classes: </strong><span class="md-color-green-700">No class is scheduled</span></div></div></div><h3 class="heading_a uk-tab">Classes, Grades and Attendance</h3><div class="uk-grid uk-grid-width-small-1-12 uk-grid-width-medium-1-12 uk-grid-width-medium-1-12 uk-grid-width-large-1-4 uk-margin-medium-bottom" data-uk-grid-margin="" id="hierarchical_show2" data-show-delay="100"><div style="margin-left: 3%;" class="uk-row-first">Courses not available.</div></div><h3 class="heading_a uk-tab">News and Announcements</h3><span>Stay tuned.</span>';

    test('exact selectors: name, id, faculty, cgpa, credits, today, news', () {
      final d = parseDashboard(realHtml);
      expect(d.studentName, 'Test Student');
      expect(d.studentId, 'L1F25XXXX0000');
      expect(d.faculty,
          'Faculty of Information Technology and Computer Science');
      expect(
        d.stats.map((s) => '${s.label}=${s.value}').toList(),
        ['CGPA=3.13', 'Earned Cr=30.0', 'Total Cr=0.0', 'Inprogress Cr=0'],
      );
      expect(d.todayClasses, 'No class is scheduled');
      expect(d.news, contains('Stay tuned.'));
      expect(d.isEmpty, isFalse);
    });
  });

  group('portal helpers', () {
    test('enrollment term from student ID batch code', () {
      expect(enrollmentFromStudentId('L1F25BSCS0577'), 'Fall 2025');
      expect(enrollmentFromStudentId('l1s26bscs0001'), 'Spring 2026');
      expect(enrollmentFromStudentId('nope'), isNull);
      expect(enrollmentFromStudentId(null), isNull);
    });

    test('semester number from batch code', () {
      // Fall 2025 starters: F25=1, S26=2, F26=3.
      expect(semesterFromStudentId('L1F25BSCS0577', DateTime(2026, 10, 1)), 3);
      expect(semesterFromStudentId('L1F25BSCS0577', DateTime(2025, 9, 1)), 1);
      expect(semesterFromStudentId('L1F25BSCS0577', DateTime(2026, 3, 1)), 2);
      expect(semesterFromStudentId('nope', DateTime(2026, 10, 1)), isNull);
    });

    test('statValue lookup', () {
      const stats = [DashboardStat('CGPA', '3.13'), DashboardStat('Earned Cr', '30.0')];
      expect(statValue(stats, 'Earned Cr'), 30.0);
      expect(statValue(stats, 'earned cr'), 30.0);
      expect(statValue(stats, 'Missing'), isNull);
      expect(degreeTotalCredits, 132.0);
    });
  });

  group('PortalApi.fetchPage', () {
    test('sends session cookie and returns body', () async {
      String? seenCookie;
      final api = PortalApi(MockClient((req) async {
        seenCookie = req.headers['Cookie'];
        expect(req.url.host, 'horizon.ucp.edu.pk');
        expect(req.url.path, '/student/dashboard');
        return http.Response('<html>ok</html>', 200);
      }));
      expect(await api.fetchDashboard('abc123'), '<html>ok</html>');
      expect(seenCookie, 'session_id=abc123');
      api.close();
    });

    test('login redirect means expired session', () async {
      final api = PortalApi(MockClient((_) async => http.Response(
            '',
            303,
            headers: {'location': 'https://horizon.ucp.edu.pk/web/login?redirect=x'},
          )));
      await expectLater(
        api.fetchDashboard('dead'),
        throwsA(isA<OdooApiException>()),
      );
      api.close();
    });

    test('200 login form means expired session', () async {
      final api = PortalApi(MockClient((_) async => http.Response(
            '<form class="oe_login_form" action="/web/login">x</form>',
            200,
          )));
      await expectLater(
        api.fetchDashboard('dead'),
        throwsA(isA<OdooApiException>()),
      );
      api.close();
    });

    test('server error surfaces', () async {
      final api = PortalApi(
          MockClient((_) async => http.Response('boom', 500)));
      await expectLater(
        api.fetchDashboard('x'),
        throwsA(isA<OdooApiException>()),
      );
      api.close();
    });
  });
}
