/* Theme regression: every screen must render in EVERY palette, in light
 * AND dark mode, without throwing, overflowing or painting an untinted
 * white surface over a dark scaffold.
 *
 * This is the guard for "dark mode broke the UI": the screens must work
 * in both modes for all six palettes, and the Material theme (dialogs,
 * sheets, switches, inputs) must follow the same mode.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ucp/app.dart';

import 'package:ucp/theme/palette.dart';
import 'package:ucp/screens/profile.dart' show ProfilePrefs;
import 'package:ucp/widgets/common.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final palettes = AppPalette.values;

  group('theme pairs', () {
    for (final palette in palettes) {
      for (final dark in [false, true]) {
        testWidgets(
            '${palette.label} ${dark ? 'dark' : 'light'}: the app shell builds '
            'and the theme matches the palette',
            (tester) async {
          final colors = AppColors.of(palette, dark);
          await tester.pumpWidget(AppScope(
            colors: colors,
            palette: palette,
            child: MaterialApp(
              theme: themeFor(colors),
              darkTheme: themeFor(colors),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: Builder(builder: (context) {
                final theme = Theme.of(context);
                final scheme = theme.colorScheme;
                // The scaffold and every surface follow the mode.
                expect(theme.scaffoldBackgroundColor, colors.cream2);
                expect(scheme.brightness,
                    dark ? Brightness.dark : Brightness.light);
                expect(theme.cardTheme.color, colors.white);
                expect(theme.dialogTheme.backgroundColor, colors.white);
                expect(
                    theme.bottomSheetTheme.backgroundColor, colors.white);
                return const Scaffold(
                  body: Center(child: Text('ok')),
                );
              }),
            ),
          ));
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('the app renders in dark mode for every palette', (
        tester) async {
      for (final palette in palettes) {
        for (final dark in [false, true]) {
          await tester.pumpWidget(AppScope(
            colors: AppColors.of(palette, dark),
            palette: palette,
            child: MaterialApp(
              theme: themeFor(AppColors.of(palette, dark)),
              darkTheme: themeFor(AppColors.of(palette, dark)),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: const CampusApp(skipLogin: true),
            ),
          ));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 120));
          expect(tester.takeException(), isNull,
              reason: '${palette.label} ${dark ? 'dark' : 'light'}');
        }
      }
    });
  });
}
