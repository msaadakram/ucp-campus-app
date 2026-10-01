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
