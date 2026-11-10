import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucp/screens/materials_web.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

void main() {
  Future<void> pump(WidgetTester tester, Size size, {bool big = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = size.width / 400;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: AppScope(
              colors: AppColors.of(AppPalette.leap, false),
              palette: AppPalette.leap,
              child: const MaterialApp(
                debugShowCheckedModeBanner: false,
                home: WebViewScreen(sessionId: 'sid', renderWebView: false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('page fills the full width and remaining height',
      (WidgetTester tester) async {
    const size = Size(400, 800);
    await pump(tester, size);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The page surface reaches the bottom of the viewport.
    final total = find.byType(Stack).last;
    final box = tester.getRect(total);
    expect(box.width, size.width,
        reason: 'page must use the full mobile width');
    expect(box.bottom, size.height,
        reason: 'page must reach the bottom (no dead space)');
    // And it starts below the header band.
    expect(box.top, greaterThan(0));
  });

  testWidgets('no download icon button in the address bar',
      (WidgetTester tester) async {
    await pump(tester, const Size(400, 800));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // The always-on download button is gone; the menu holds it.
    expect(find.byIcon(Icons.download_outlined), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('menu exposes the downloads list', (WidgetTester tester) async {
    await pump(tester, const Size(400, 800));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Reload'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Portal home'), findsOneWidget);
  });
}
