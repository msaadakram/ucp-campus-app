// Standalone planner: exact port of GpaCalculatorActivity.
// 6 default rows, grades/credit dropdowns, Calculate -> GpaResult,
// edit icon -> Add Previous Data dialog (current CGPA + completed credits).
import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../widgets/common.dart';
import 'grading.dart';

class VaultPlannerRow {
  String grade;
  int creditHours;
  VaultPlannerRow({this.grade = 'Select', this.creditHours = 0});
}

class VaultCalculatorScreen extends StatefulWidget {
  const VaultCalculatorScreen({super.key});
  @override
  State<VaultCalculatorScreen> createState() => _VaultCalculatorScreenState();
}

class _VaultCalculatorScreenState extends State<VaultCalculatorScreen> {
  List<VaultPlannerRow> rows =
      List.generate(6, (_) => VaultPlannerRow());
  double prevCgpa = 0;
  int prevCr = 0;
  double? resultGpa;
  int resultCr = 0;
  double? blendedCgpa;

  /// Scrolls the result card into view after Calculate, with glow pulse.
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _resultKey = GlobalKey();
  int _flash = 0;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToResult() {
    final ctx = _resultKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        alignment: 0.0,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    } else if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  void _calculate() {
    final res = vaultCalculateGpa([
      for (final r in rows)
        VaultGpaInput(grade: r.grade, creditHours: r.creditHours),
    ]);
    double? blended;
    if (prevCgpa > 0 && prevCr > 0) {
      blended = vaultBlendCgpa(
        prevCgpa: prevCgpa,
        prevCr: prevCr,
        gpa: res.gpa,
        credits: res.totalCreditHours,
      );
      if (blended == null) {
        final c = AppScope.colorsOf(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            res.gpa < 0 || res.gpa > 4 || prevCgpa < 0 || prevCgpa > 4
                ? (prevCgpa < 0 || prevCgpa > 4
                    ? 'Previous CGPA must be between 0 and 4.0'
                    : 'New GPA must be between 0 and 4.0')
                : 'Invalid previous data',
            style: body(c, color: Colors.white),
          ),
          backgroundColor: c.clay,
        ));
        return;
      }
    }
    setState(() {
      resultGpa = vaultRound2(res.gpa);
      resultCr = res.totalCreditHours;
      blendedCgpa = blended;
      _flash++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToResult());
  }

  Future<void> _editPreviousData() async {
    final cgpaCtrl = TextEditingController(
        text: prevCgpa > 0 ? prevCgpa.toString() : '');
    final crCtrl =
        TextEditingController(text: prevCr > 0 ? prevCr.toString() : '');
    String? cgpaErr;
    String? crErr;
    await showDialog(
      context: context,
      builder: (ctx) {
        final c = AppScope.colorsOf(ctx);
        return StatefulBuilder(builder: (ctx, setD) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            title: Text('Add Previous Data',
                style: display(c, size: 18), textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current CGPA', style: body(c, weight: FontWeight.w600)),
                TextField(
                  controller: cgpaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Enter CGPA',
                    errorText: cgpaErr,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Completed Credit Hours',
                    style: body(c, weight: FontWeight.w600)),
                TextField(
                  controller: crCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter Credit Hours',
                    errorText: crErr,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final cgRaw = cgpaCtrl.text.trim();
                  final crRaw = crCtrl.text.trim();
                  var ok = true;
                  setD(() {
                    cgpaErr = null;
                    crErr = null;
                    if (cgRaw.isEmpty) {
                      cgpaErr = 'Enter CGPA';
                      ok = false;
                    }
                    if (crRaw.isEmpty) {
                      crErr = 'Enter Credit Hours';
                      ok = false;
                    }
                  });
                  if (!ok) return;
                  final cg = double.tryParse(cgRaw);
                  final cr = int.tryParse(crRaw);
                  if (cg == null || cg < 0 || cg > 4) {
                    setD(() => cgpaErr =
                        'Previous CGPA must be between 0 and 4.0');
                    return;
                  }
                  if (cr == null || cr < 0) {
                    setD(() => crErr = 'Enter Credit Hours');
                    return;
                  }
                  setState(() {
                    prevCgpa = cg;
                    prevCr = cr;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Save Data'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return RefreshIndicator(
      color: c.teal,
      backgroundColor: c.white,
      onRefresh: () async => setState(() {}),
      child: UHead(
        height: 112,
        controller: _scrollCtrl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GPA Calculator',
                          style: display(c, size: 26, color: Colors.white)),
                      Text('CourseVault planner · same grades & math',
                          style: body(c,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.78))),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _editPreviousData,
                  child: Container(
                    alignment: Alignment.center,
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.edit_outlined,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              key: _resultKey,
              child: TweenAnimationBuilder<double>(
              key: ValueKey(_flash),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              builder: (ctx, t, child) {
                // Glow pulse: strong right after Calculate, fades to 0.
                final pulse = _flash == 0 ? 0.0 : (1 - t);
                return Transform.scale(
                  scale: 1 + 0.03 * pulse,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: pulse > 0.01
                          ? Border.all(
                              color: c.teal
                                  .withValues(alpha: 0.8 * pulse),
                              width: 2)
                          : null,
                      boxShadow: pulse > 0.01
                          ? [
                              BoxShadow(
                                color: c.teal
                                    .withValues(alpha: 0.55 * pulse),
                                blurRadius: 18 * pulse,
                                offset: const Offset(0, 6),
                              )
                            ]
                          : const [],
                    ),
                    child: child,
                  ),
                );
              },
              child: WhiteCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text('CGPA: ${resultGpa?.toStringAsFixed(2) ?? '0'}',
                                style: body(c, weight: FontWeight.w800))),
                        Expanded(
                            child: Text('Credit Hours: $resultCr',
                                style: body(c, weight: FontWeight.w800))),
                      ],
                    ),
                    if (prevCgpa > 0 && prevCr > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Previous: ${prevCgpa.toStringAsFixed(2)} · $prevCr cr'
                          '${blendedCgpa != null ? ' → Blended ${blendedCgpa!.toStringAsFixed(2)}' : ''}',
                          style: body(c,
                              size: 12,
                              color: c.tealInk.withValues(alpha: 0.65)),
                        ),
                      ),
                  ],
                ),
              ),
              ),
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < rows.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: vaultGrades.contains(rows[i].grade)
                            ? rows[i].grade
                            : null,
                        hint: const Text('Grade'),
                        items: [
                          for (final g in vaultGrades)
                            DropdownMenuItem(value: g, child: Text(g)),
                        ],
                        onChanged: (v) =>
                            setState(() => rows[i].grade = v ?? 'Select'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue:
                            rows[i].creditHours > 0 ? rows[i].creditHours : null,
                        hint: const Text('Credit Hours'),
                        items: [
                          for (final h in vaultCreditOptions)
                            DropdownMenuItem(value: h, child: Text('$h')),
                        ],
                        onChanged: (v) =>
                            setState(() => rows[i].creditHours = v ?? 0),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete GPA course',
                      icon: Icon(Icons.delete_outline, color: c.clay),
                      onPressed: () => setState(() => rows.removeAt(i)),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: ClayButton(
                    label: 'Calculate GPA',
                    colors: c,
                    onPressed: _calculate,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () =>
                      setState(() => rows.add(VaultPlannerRow())),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: c.tealInk,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: c.clay, offset: const Offset(0, 6))
                      ],
                    ),
                    child: Icon(Icons.add, color: c.cream),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
