import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../widgets/common.dart';

/// Shared bits for the Course Detail tab bodies.
Widget courseEmptyCard(AppColors c, IconData icon, String text) {
  return WhiteCard(
    child: Column(
      children: [
        Icon(icon, size: 36, color: c.teal),
        const SizedBox(height: 12),
        Text(text,
            textAlign: TextAlign.center,
            style:
                body(c, size: 14, color: c.tealInk.withValues(alpha: 0.6))),
      ],
    ),
  );
}

Widget courseKvCard(AppColors c, String title, List<List<String>> rows) {
  return WhiteCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: display(c, size: 16)),
        const SizedBox(height: 10),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    flex: 3,
                    child: Text(r[0],
                        style: body(c,
                            size: 13,
                            color: c.tealInk.withValues(alpha: 0.6)))),
                Expanded(
                    flex: 5,
                    child: Text(r.length > 1 ? r[1] : '',
                        style:
                            body(c, size: 13, weight: FontWeight.w600))),
              ],
            ),
          ),
      ],
    ),
  );
}

Widget courseRowCard(AppColors c, Widget child) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
        color: c.white, borderRadius: BorderRadius.circular(16)),
    child: child,
  );
}
