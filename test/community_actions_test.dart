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

void main() {
  testWidgets('action row fits narrow screens with even buttons',
      (tester) async {
    final svc = FakeCommunityService();
    await tester.pumpWidget(wrap(
        CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk')));
    await tester.pumpAndSettle();
    // Narrow phone width: any RenderFlex overflow fails the test.
    tester.view.physicalSize = const Size(320 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3.0;
    await tester.pumpAndSettle();
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    expect(find.byKey(const ValueKey('post-comment-p1')), findsOneWidget);
    expect(find.byKey(const ValueKey('post-share-p1')), findsOneWidget);
    // Comment, share and vote pills share one uniform action-row height.
    final commentSize =
        tester.getSize(find.byKey(const ValueKey('post-comment-p1')));
    final shareSize =
        tester.getSize(find.byKey(const ValueKey('post-share-p1')));
    expect(commentSize.height, moreOrLessEquals(36, epsilon: 2));
    expect(shareSize.height, moreOrLessEquals(36, epsilon: 2));
    expect(find.text('Share'), findsWidgets);
    svc.dispose();
  });

  testWidgets('comment button in feed opens the thread', (tester) async {
    final svc = FakeCommunityService();
    await tester.pumpWidget(
        wrap(CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk')));
    await tester.pumpAndSettle();
    // Feed shows comment buttons; tapping the first opens its thread.
    final commentBtn = find.byKey(const ValueKey('post-comment-p1'));
    expect(commentBtn, findsOneWidget);
    await tester.ensureVisible(commentBtn);
    await tester.pumpAndSettle();
    await tester.tap(commentBtn);
    await tester.pumpAndSettle();
    expect(find.textContaining('COMMENTS'), findsWidgets);
    svc.dispose();
  });

  testWidgets('comment button in thread focuses the input', (tester) async {
    final svc = FakeCommunityService();
    await tester.pumpWidget(
        wrap(CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('post-comment-p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('post-comment-p1')));
    await tester.pumpAndSettle();
    // In thread, the card comment button focuses the field (no navigation).
    await tester.tap(find.byKey(const ValueKey('post-comment-p1')));
    await tester.pump();
    final field =
        tester.widget<TextField>(find.byKey(const ValueKey('comment-field')));
    expect(field.focusNode!.hasFocus, isTrue);
    svc.dispose();
  });

  testWidgets('share button confirms via snackbar', (tester) async {
    final svc = FakeCommunityService();
    await tester.pumpWidget(
        wrap(CommunityScreen(service: svc, myEmail: 't@ucp.edu.pk')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('post-share-p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('post-share-p1')));
    await tester.pumpAndSettle();
    expect(find.text('Copied to clipboard'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    svc.dispose();
  });
}

