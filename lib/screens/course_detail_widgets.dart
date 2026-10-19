import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../widgets/common.dart';

/// Shared design system for the Course Detail tab bodies — mirrors the
/// modern card language of Community/Teachers: white cards, hairline
/// border, soft shadow, accent-tinted icon tiles, metadata pills.

/// Standard content card: white, rounded 20, hairline border, soft shadow.
Widget courseCard(AppColors c, {Widget? child, EdgeInsetsGeometry padding = const EdgeInsets.all(14)}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: padding,
    decoration: BoxDecoration(
      color: c.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.dustSoft.withValues(alpha: 0.6)),
      boxShadow: [
        BoxShadow(
          color: c.tealInk.withValues(alpha: 0.06),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

/// Accent-tinted icon tile (40px, rounded 12): icon color = [tone].
Widget courseIconTile(AppColors c, IconData icon, Color tone) {
  return Container(
    alignment: Alignment.center,
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: tone.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, size: 20, color: tone),
  );
}

/// Small metadata pill on [bg] (defaults to the muted surface tone).
Widget courseChip(AppColors c, String text, {Color? bg, Color? fg}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg ?? c.dustSoft.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg ?? c.tealInk.withValues(alpha: 0.75)),
    ),
  );
}

/// Friendly per-tab empty state: tinted disc + icon + message.
Widget courseEmptyCard(AppColors c, IconData icon, String text) {
  return courseCard(
    c,
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
    child: Column(
      children: [
        Container(
          alignment: Alignment.center,
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: c.teal.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28, color: c.teal),
        ),
        const SizedBox(height: 12),
        Text(text,
            textAlign: TextAlign.center,
            style:
                body(c, size: 14, color: c.tealInk.withValues(alpha: 0.6))),
      ],
    ),
  );
}

/// Key-value card for books and reference lists.
Widget courseKvCard(AppColors c, String title, List<List<String>> rows) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionLabel(title),
      courseCard(
        c,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        flex: 3,
                        child: Text(r[0],
                            style: body(c,
                                size: 13,
                                weight: FontWeight.w600))),
                    Expanded(
                        flex: 5,
                        child: Text(r.length > 1 ? r[1] : '',
                            style: body(c,
                                size: 13,
                                color: c.tealInk.withValues(alpha: 0.6)))),
                  ],
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

/// Retained for callers that compose inside a standard card.
Widget courseRowCard(AppColors c, Widget child) =>
    courseCard(c, child: child);
