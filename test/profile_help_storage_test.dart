import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucp/screens/profile.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

Widget wrap(Widget child) {
  final c = AppColors.of(AppPalette.skater, false);
  return AppScope(
      colors: c,
      palette: AppPalette.skater,
      child: MaterialApp(home: Scaffold(body: child)));
}

ProfilePrefs testPrefs() => ProfilePrefs();

void main() {
  testWidgets('Help & support shows support email and opens dialog',
      (t) async {
    await t.pumpWidget(wrap(ProfileScreen(
      logout: () {},
      prefs: testPrefs(),
      onPrefs: (_) {},
    )));
    await t.pumpAndSettle();

    expect(find.text('msaadakram786@gmail.com'), findsOneWidget);
    expect(find.text('Help & support'), findsOneWidget);

    final help = find.text('Help & support');
    await t.ensureVisible(help);
    await t.pumpAndSettle();
    await t.tap(help);
    await t.pumpAndSettle();
    expect(find.text('Copy email'), findsOneWidget);
    await t.tap(find.text('Close'));
    await t.pumpAndSettle();
  });

  testWidgets('Language is static English only', (t) async {
    await t.pumpWidget(wrap(ProfileScreen(
      logout: () {},
      prefs: testPrefs(),
      onPrefs: (_) {},
    )));
    await t.pumpAndSettle();

    // English shown as a plain value, no other languages offered.
    expect(find.text('English'), findsOneWidget);
    expect(find.text('اردو'), findsNothing);
    expect(find.text('العربية'), findsNothing);
    expect(find.text('Español'), findsNothing);
    expect(find.byType(DropdownButton<String>), findsNothing);
  });

  testWidgets('Profile visibility row is removed', (t) async {
    await t.pumpWidget(wrap(ProfileScreen(
      logout: () {},
      prefs: testPrefs(),
      onPrefs: (_) {},
    )));
    await t.pumpAndSettle();

    expect(find.text('Profile visibility'), findsNothing);
    // Rest of the privacy section remains.
    expect(find.text('App lock'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
  });

  testWidgets('Downloads & storage shows measured size not the old 182 MB',
      (t) async {
    await t.pumpWidget(wrap(ProfileScreen(
      logout: () {},
      prefs: testPrefs(),
      onPrefs: (_) {},
    )));
    await t.pumpAndSettle();

    expect(find.text('182 MB used'), findsNothing);
    final row = find.text('Downloads & storage');
    expect(row, findsOneWidget);
    // Test env lacks real dirs; row resolves to a measurement or the
    // graceful fallback — never the stale hardcoded value.
    final sub = t.widget<SettingRow>(find
        .widgetWithText(SettingRow, 'Downloads & storage'));
    expect(sub.sub, isNotNull);
  });
}
