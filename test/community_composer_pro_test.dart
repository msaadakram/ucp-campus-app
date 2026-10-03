import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucp/community/fake_community_service.dart';
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

Future<void> openComposer(WidgetTester tester) async {
  await tester.tap(find.text(' Post'));
  await tester.pumpAndSettle();
  expect(find.text('Create post'), findsOneWidget);
}

void main() {
  testWidgets('counters update live as user types', (tester) async {
    final svc = FakeCommunityService();
    await tester.pumpWidget(
        wrap(CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk')));
    await tester.pumpAndSettle();
    await openComposer(tester);
    expect(find.text('0/120'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('composer-title')), 'Hello');
    await tester.pump();
    expect(find.text('5/120'), findsOneWidget);
    svc.dispose();
  });

  testWidgets('preview toggle shows live post preview', (tester) async {
    final svc = FakeCommunityService();
    await tester.pumpWidget(
        wrap(CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk')));
    await tester.pumpAndSettle();
    await openComposer(tester);
    await tester.enterText(
        find.byKey(const ValueKey('composer-title')), 'Preview title');
    await tester.pump();
    await tester.ensureVisible(
        find.byKey(const ValueKey('composer-preview-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('composer-preview-toggle')),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer-preview-card')),
        findsOneWidget);
    expect(find.text('Preview title'), findsWidgets);
    svc.dispose();
  });

  testWidgets('over-long title blocked with clear error', (tester) async {
    final svc = FakeCommunityService();
    await tester.pumpWidget(
        wrap(CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk')));
    await tester.pumpAndSettle();
    await openComposer(tester);
    final long = List.filled(130, 'A').join();
    await tester.enterText(find.byKey(const ValueKey('composer-title')), long);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('composer-post-button')));
    await tester.pumpAndSettle();
    expect(find.text('Title must be 120 characters or less.'),
        findsOneWidget);
    final posts = await svc.fetchPosts(myEmail: 't@ucp.edu.pk');
    expect(posts.any((p) => p.title == long), isFalse);
    svc.dispose();
  });

  testWidgets('flair select + bottom Post publishes', (tester) async {
    final svc = FakeCommunityService();
    await tester.pumpWidget(
        wrap(CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk')));
    await tester.pumpAndSettle();
    await openComposer(tester);
    await tester.enterText(
        find.byKey(const ValueKey('composer-title')), 'Flair bottom test');
    await tester.pump();
    // Switch flair to Events (keyed, inside the sheet — not the feed filter).
    await tester.ensureVisible(
        find.byKey(const ValueKey('composer-flair-Events')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('composer-flair-Events')),
        warnIfMissed: false);
    await tester.pump();
    await tester.ensureVisible(
        find.byKey(const ValueKey('composer-post-button-bottom')));
    await tester.pumpAndSettle();
    await tester.tap(
        find.byKey(const ValueKey('composer-post-button-bottom')),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Create post'), findsNothing);
    expect(find.text('Flair bottom test'), findsOneWidget);
    expect(find.text('Posted to r/campus'), findsOneWidget);
    svc.dispose();
  });

  testWidgets('close with draft asks, discard closes', (tester) async {
    final svc = FakeCommunityService();
    await tester.pumpWidget(
        wrap(CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk')));
    await tester.pumpAndSettle();
    await openComposer(tester);
    await tester.enterText(
        find.byKey(const ValueKey('composer-title')), 'draft here');
    await tester.pump();
    // Tap top-left close (first close icon in sheet header).
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.text('Discard post?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('composer-discard-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Create post'), findsNothing);
    svc.dispose();
  });

  testWidgets('draft survives realtime refresh in new composer too',
      (tester) async {
    final svc = FakeCommunityService();
    await tester.pumpWidget(
        wrap(CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk')));
    await tester.pumpAndSettle();
    await openComposer(tester);
    await tester.enterText(
        find.byKey(const ValueKey('composer-title')), 'Survive me');
    await tester.pump();
    final posts = await svc.fetchPosts(myEmail: 't@ucp.edu.pk');
    await svc.setVote(
        postId: posts.first.id, myEmail: 'o@ucp.edu.pk', value: 1);
    await tester.pumpAndSettle();
    expect(find.text('Survive me'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('composer-post-button')));
    await tester.pumpAndSettle();
    expect(find.text('Survive me'), findsOneWidget);
    expect(find.text('Create post'), findsNothing);
    svc.dispose();
  });
}
