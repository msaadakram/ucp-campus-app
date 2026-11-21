import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucp/ads/ad_widgets.dart';

void main() {
  testWidgets(
    'showRewardedOffer returns false when the SDK is not ready',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      final result = await showRewardedOffer(
        tester.element(find.byType(Scaffold)),
        title: 'Boost this board',
        rewardText: 'Watch a short ad',
        onReward: () async {},
      );
      expect(result, isFalse);
    },
  );

  testWidgets(
    'the offer sheet is mandatory: it cannot be dismissed and requires an '
    'explicit choice',
    (tester) async {
      AdMobService.instance.ready = true;
      addTearDown(() => AdMobService.instance.ready = false);

      Future<bool?>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () {
                result = showRewardedOffer(
                  tester.element(find.byType(Scaffold)),
                  title: 'Boost this board',
                  rewardText:
                      'Watch a short ad to re-sync your class marks instantly',
                  onReward: () async {},
                );
              },
              child: const Text('Open offer'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open offer'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Boost this board'), findsOneWidget);
      expect(
        find.text(
          'Watch a short ad to re-sync your class marks instantly',
        ),
        findsOneWidget,
      );
      expect(find.text('Watch ad'), findsOneWidget);
      expect(find.text('No thanks, continue'), findsOneWidget);

      // Tapping the (opaque) modal barrier must not close the sheet.
      await tester.tapAt(const Offset(2, 2));
      await tester.pump();
      await tester.pump();
      expect(find.text('Watch ad'), findsOneWidget);
      expect(find.text('No thanks, continue'), findsOneWidget);

      // The explicit "continue" choice dismisses the sheet as a skip.
      await tester.tap(find.text('No thanks, continue'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(await result, isFalse);
      expect(find.text('Boost this board'), findsNothing);
    },
  );
}
