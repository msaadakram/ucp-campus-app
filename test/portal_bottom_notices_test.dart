import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';
import 'package:ucp/widgets/portal_state.dart';

Widget _wrap(Widget child) {
  final colors = AppColors.of(AppPalette.skater, false);
  return AppScope(
    colors: colors,
    palette: AppPalette.skater,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('passes content through with no notices', (tester) async {
    await tester.pumpWidget(_wrap(const PortalBottomNotices(
      refreshFailed: false,
      onRetry: _noop,
      child: Text('page content'),
    )));
    await tester.pumpAndSettle();
    expect(find.text('page content'), findsOneWidget);
    expect(find.textContaining('Saved'), findsNothing);
    expect(find.textContaining("Couldn't refresh"), findsNothing);
  });

  testWidgets('docks saved-data pill above the tab bar', (tester) async {
    final at = DateTime.now().millisecondsSinceEpoch -
        const Duration(minutes: 5).inMilliseconds;
    await tester.pumpWidget(_wrap(PortalBottomNotices(
      refreshFailed: false,
      onRetry: _noop,
      cachedAtMs: at,
      child: const Text('page content'),
    )));
    await tester.pumpAndSettle();
    expect(find.text('page content'), findsOneWidget);
    expect(
        find.text('Saved 5m ago · connect to refresh'), findsOneWidget);
  });

  testWidgets('retry pill calls back on tap', (tester) async {
    var retried = false;
    // Bounded height like the real viewport (screens fill Positioned.fill).
    await tester.pumpWidget(_wrap(SizedBox(
      height: 600,
      child: PortalBottomNotices(
        refreshFailed: true,
        onRetry: () => retried = true,
        child: const Text('page content'),
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't refresh"), findsOneWidget);
    await tester.tap(find.textContaining("Couldn't refresh"));
    await tester.pump();
    expect(retried, isTrue);
  });
}

void _noop() {}
