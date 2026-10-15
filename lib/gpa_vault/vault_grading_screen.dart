// Grading-scheme reference: static 16-row table from GradingSchemeActivity.
import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../widgets/common.dart';
import 'models.dart';

class VaultGradingScreen extends StatelessWidget {
  const VaultGradingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return UHead(
      height: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Grading Scheme',
              style: display(c, size: 26, color: Colors.white)),
          Text('This grading scheme is for absolute marking',
              style: body(c,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.78))),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
                color: c.white, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Expanded(
                    child: Text('Letter Grade',
                        style: body(c, weight: FontWeight.w800))),
                Expanded(
                    child: Text('Grade Points',
                        textAlign: TextAlign.center,
                        style: body(c, weight: FontWeight.w800))),
                Expanded(
                    child: Text('Marks (%)',
                        textAlign: TextAlign.center,
                        style: body(c, weight: FontWeight.w800))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final r in vaultGradingScheme)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                  color: c.white,
                  borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Expanded(
                      child: Text(r.letter,
                          style: body(c, weight: FontWeight.w700))),
                  Expanded(
                      child: Text(r.points,
                          textAlign: TextAlign.center,
                          style: body(c,
                              color: c.tealInk.withValues(alpha: 0.7)))),
                  Expanded(
                      child: Text(r.marks,
                          textAlign: TextAlign.center,
                          style: body(c,
                              color: c.tealInk.withValues(alpha: 0.7)))),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
