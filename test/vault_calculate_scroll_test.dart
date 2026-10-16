import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucp/gpa_vault/vault_calculator_screen.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

Widget wrap(Widget child) {
  final c = AppColors.of(AppPalette.skater, false);
  return AppScope(
      colors: c,
      palette: AppPalette.skater,
      child: MaterialApp(home: Scaffold(body: child)));
}

Future<void> pickGrade(WidgetTester t, int row, String grade) async {
  final fields = find.byType(DropdownButtonFormField<String>);
  await t.ensureVisible(fields.at(row));
  await t.pumpAndSettle();
  await t.tap(fields.at(row));
  await t.pumpAndSettle();
  final item = find.widgetWithText(DropdownMenuItem<String>, grade);
  await t.tap(item.first);
  await t.pumpAndSettle();
}

Future<void> pickCredit(WidgetTester t, int row, String credit) async {
  final fields = find.byType(DropdownButtonFormField<int>);
  await t.ensureVisible(fields.at(row));
  await t.pumpAndSettle();
  await t.tap(fields.at(row));
  await t.pumpAndSettle();
  final item = find.widgetWithText(DropdownMenuItem<int>, credit);
  await t.tap(item.first);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Calculate GPA updates result and scroll animates',
      (t) async {
    await t.pumpWidget(wrap(const VaultCalculatorScreen()));
    await t.pumpAndSettle();
    expect(find.text('CGPA: 0'), findsOneWidget);

    await pickGrade(t, 0, 'A');
    await pickCredit(t, 0, '3');

    final calc = find.text('Calculate GPA');
    await t.ensureVisible(calc);
    await t.pumpAndSettle();
    await t.tap(calc);
    await t.pumpAndSettle();

    expect(find.text('CGPA: 4.00'), findsOneWidget);
    expect(find.text('Credit Hours: 3'), findsOneWidget);
    expect(find.text('CGPA: 4.00').hitTestable(), findsOneWidget);
  });
}
