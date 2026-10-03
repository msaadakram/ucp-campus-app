import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ucp/community/community_service.dart';
import 'package:ucp/community/fake_community_service.dart';
import 'package:ucp/community/node_community_service.dart';
import 'package:ucp/screens/community.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

Widget wrap(Widget child) {
  final colors = AppColors.of(AppPalette.skater, false);
  return AppScope(
    colors: colors,
    palette: AppPalette.skater,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('formatCommunityStats', () {
    test('null means connecting', () {
      expect(formatCommunityStats(null), 'Connecting…');
    });
    test('plural + online passthrough', () {
      expect(formatCommunityStats(const CommunityStats(members: 12, online: 3)),
          '12 students · 3 online');
    });
    test('singular forms', () {
      expect(formatCommunityStats(const CommunityStats(members: 1, online: 1)),
          '1 student · 1 online');
    });
    test('counts self when backend reports 0 online', () {
      expect(formatCommunityStats(const CommunityStats(members: 5, online: 0)),
          '5 students · 1 online');
    });
    test('fromJson tolerates strings', () {
      final s = CommunityStats.fromJson({'members': '7', 'online': '2'});
      expect(s.members, 7);
      expect(s.online, 2);
    });
  });

  group('FakeCommunityService.fetchStats', () {
    test('members are distinct contributors, online is 1', () async {
      final svc = FakeCommunityService();
      final stats = await svc.fetchStats();
      // Seed has 4 post authors + several commenters; must be > post count
      // and 100% derived (no hardcode).
      expect(stats.members, greaterThanOrEqualTo(4));
      expect(stats.online, 1);
      expect(formatCommunityStats(stats), contains('students'));
      expect(formatCommunityStats(stats), contains('online'));
      svc.dispose();
    });

    test('new contributor grows the count', () async {
      final svc = FakeCommunityService();
      final before = (await svc.fetchStats()).members;
      await svc.createPost(
        myEmail: 'brand.new@ucp.edu.pk',
        authorName: 'brand.new',
        title: 'hello',
        body: '',
        flair: 'Study',
      );
      final after = (await svc.fetchStats()).members;
      expect(after, before + 1);
      svc.dispose();
    });
  });

  group('NodeCommunityService.fetchStats', () {
    NodeCommunityService service(MockClient client) =>
        NodeCommunityService(
          baseUrl: 'https://api.test',
          sessionOf: () => 'sid-1',
          client: client,
        );

    test('parses members + online', () async {
      final svc = service(MockClient((req) async {
        expect(req.url.path, '/api/stats');
        return http.Response('{"members":42,"online":7}', 200,
            headers: {'content-type': 'application/json'});
      }));
      final stats = await svc.fetchStats();
      expect(stats.members, 42);
      expect(stats.online, 7);
      expect(formatCommunityStats(stats), '42 students · 7 online');
      svc.dispose();
    });

    test('server error throws so UI keeps last good value', () async {
      final svc = service(MockClient(
          (_) async => http.Response('{"error":"down"}', 502)));
      expect(() => svc.fetchStats(), throwsA(isA<CommunityException>()));
      svc.dispose();
    });
  });

  group('Community header shows REAL numbers', () {
    testWidgets('header starts connecting then shows live stats',
        (tester) async {
      final svc = FakeCommunityService();
      await tester.pumpWidget(
          wrap(CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk')));
      // First frame: stats not loaded yet.
      await tester.pump();
      expect(find.byKey(const ValueKey('community-stats')), findsOneWidget);
      await tester.pumpAndSettle();
      final text = tester
          .widget<Text>(find.byKey(const ValueKey('community-stats')))
          .data!;
      // Never the old hardcoded fake.
      expect(text, isNot(contains('4.2k')));
      expect(text, isNot(contains('138')));
      expect(text, contains('students'));
      expect(text, contains('online'));
      svc.dispose();
    });

    testWidgets('header updates when a new student posts', (tester) async {
      final svc = FakeCommunityService();
      await tester.pumpWidget(
          wrap(CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk')));
      await tester.pumpAndSettle();
      final before = tester
          .widget<Text>(find.byKey(const ValueKey('community-stats')))
          .data!;
      await tester.tap(find.text(' Post'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('composer-title')), 'Brand new voice');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('composer-post-button')));
      await tester.pumpAndSettle();
      final after = tester
          .widget<Text>(find.byKey(const ValueKey('community-stats')))
          .data!;
      expect(after, isNot(equals(before)));
      expect(find.text('Brand new voice'), findsOneWidget);
      svc.dispose();
    });
  });
}
