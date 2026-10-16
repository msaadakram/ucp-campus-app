// Vault entry point: mirrors CourseVault bottom sections
// My Courses (semesters) + GPA Calculator + Grading Scheme.
import 'package:flutter/material.dart';

import '../widgets/common.dart';
import 'vault_calculator_screen.dart';
import 'vault_grading_screen.dart';
import 'vault_semesters_screen.dart';

class VaultHomeScreen extends StatefulWidget {
  /// Which of [Semesters=0, Calculator=1, Grading=2] shows first.
  /// Defaults to 1 so the GPA menu opens straight on the calculator
  /// (the middle option), matching CourseVault's GpaCalculatorActivity.
  final int initialTab;
  const VaultHomeScreen({super.key, this.initialTab = 1});
  @override
  State<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

class _VaultHomeScreenState extends State<VaultHomeScreen> {
  late int tab;

  @override
  void initState() {
    super.initState();
    tab = widget.initialTab.clamp(0, 2);
  }

  @override
  void didUpdateWidget(VaultHomeScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialTab != old.initialTab) {
      tab = widget.initialTab.clamp(0, 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: c.tealInk.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                for (int i = 0; i < 3; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => tab = i),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: tab == i ? c.tealInk : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          ['Semesters', 'Calculator', 'Grading'][i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: tab == i
                                ? c.cream
                                : c.tealInk.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: switch (tab) {
            0 => const VaultSemestersScreen(),
            1 => const VaultCalculatorScreen(),
            _ => const VaultGradingScreen(),
          },
        ),
      ],
    );
  }
}
