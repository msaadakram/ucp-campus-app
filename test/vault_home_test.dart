import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucp/gpa_vault/vault_home_screen.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

Widget wrap(Widget child) {
  final c = AppColors.of(AppPalette.skater, false);
  return AppScope(colors: c, palette: AppPalette.skater, child: MaterialApp(home: Scaffold(body: child)));
}

void main() {
  testWidgets('default opens Calculator (middle option)', (t) async {
    await t.pumpWidget(wrap(const VaultHomeScreen()));
    await t.pumpAndSettle();
    expect(find.text('GPA Calculator'), findsOneWidget);
  });
  testWidgets('initialTab 0 opens Semesters', (t) async {
    await t.pumpWidget(wrap(const VaultHomeScreen(initialTab: 0)));
    await t.pumpAndSettle();
    expect(find.text('My Courses'), findsOneWidget);
  });
  testWidgets('tapping Semesters switches away from calculator', (t) async {
    await t.pumpWidget(wrap(const VaultHomeScreen()));
    await t.pumpAndSettle();
    await t.tap(find.text('Semesters'));
    await t.pumpAndSettle();
    expect(find.text('My Courses'), findsOneWidget);
  });
}
