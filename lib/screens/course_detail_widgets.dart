import 'package:flutter/material.dart';

import '../theme/palette.dart';

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

/// Retained for callers that compose inside a standard card.
Widget courseRowCard(AppColors c, Widget child) =>
    courseCard(c, child: child);

/// Section header with an optional trailing badge (count / chip).
Widget courseSectionHeader(AppColors c, String title, {String? trailing}) {
  return Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(title,
              style: display(c, size: 16.5, color: c.tealInk)),
        ),
        if (trailing != null && trailing.isNotEmpty)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: c.tealInk.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(trailing,
                style: body(c,
                    size: 11,
                    weight: FontWeight.w800,
                    color: c.tealInk.withValues(alpha: 0.7))),
          ),
      ],
    ),
  );
}

/// Status pill: tinted background, tone foreground, leading icon.
Widget courseStatusPill(
  AppColors c, {
  required String text,
  required Color tone,
  IconData? icon,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: tone.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: tone.withValues(alpha: 0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: tone),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: tone)),
        ),
      ],
    ),
  );
}

/// One labelled number in a summary strip (big value over caption).
Widget courseStat(AppColors c, String value, String label, {Color? tone}) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: display(c, size: 17, color: tone ?? c.teal)),
      const SizedBox(height: 2),
      Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: body(c,
              size: 9.5,
              weight: FontWeight.w800,
              color: c.tealInk.withValues(alpha: 0.5))),
    ],
  );
}

/// A labelled chip row for book/reference entries: title + meta lines.
Widget courseBookTile(
  AppColors c, {
  required int index,
  required String title,
  required String authors,
  required String edition,
  required String publisher,
  required String year,
  required String description,
  required Color tone,
}) {
  final meta = StringBuffer();
  if (authors.isNotEmpty) meta.write(authors);
  final editionYear = [
    if (edition.isNotEmpty) edition,
    if (year.isNotEmpty) year,
  ].join(' · ');
  if (editionYear.isNotEmpty) {
    if (meta.isNotEmpty) meta.write(' · ');
    meta.write(editionYear);
  }
  final pub = [
    if (publisher.isNotEmpty) publisher,
  ].join(' · ');
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: c.cream2,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.dustSoft.withValues(alpha: 0.55)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            (index + 1).toString().padLeft(2, '0'),
            style: display(c, size: 13, color: tone),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: body(c, size: 13.5, weight: FontWeight.w800)),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(meta.toString(),
                    style: body(c,
                        size: 11.5,
                        color: c.tealInk.withValues(alpha: 0.6))),
              ],
              if (pub.isNotEmpty)
                Text(pub,
                    style: body(c,
                        size: 10.5,
                        color: c.tealInk.withValues(alpha: 0.45))),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: body(c,
                        size: 11,
                        color: c.tealInk.withValues(alpha: 0.65))),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

