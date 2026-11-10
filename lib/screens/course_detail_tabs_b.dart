import 'package:flutter/material.dart';

import '../auth/course_detail.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import 'course_detail_widgets.dart';

const _weightTones = [
  Color(0xFF1789B8),
  Color(0xFFF4A82A),
  Color(0xFF8FAE6E),
  Color(0xFFEE6A24),
  Color(0xFF6C63B7),
];

/// Outline tab body: course plan hero + weightage distribution +
/// objectives + learning outcomes.
Widget courseOutlineBody(AppColors c, CourseOutlineData? o) {
  if (o == null || o.isEmpty) {
    return courseEmptyCard(
        c, Icons.menu_book_outlined, 'No outline published yet.');
  }
  final totalWeight =
      o.weightages.fold<double>(0, (sum, w) => sum + w.weight);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (o.weightages.isNotEmpty) ...[
        courseSectionHeader(c, 'Marks distribution',
            trailing: '${o.weightages.length} types · '
                '${_trimNum(totalWeight)}% in total'),
        courseCard(
          c,
          child: Column(
            children: [
              _WeightStack(weightages: o.weightages),
              const SizedBox(height: 14),
              for (var i = 0; i < o.weightages.length; i++)
                _weightRow(
                    c, o.weightages[i], _weightTones[i % _weightTones.length]),
            ],
          ),
        ),
      ],
      if (o.objectives.isNotEmpty) ...[
        courseSectionHeader(c, 'Course objectives',
            trailing: '${o.objectives.length}'),
        courseCard(
          c,
          child: Column(
            children: [
              for (var i = 0; i < o.objectives.length; i++)
                _objectiveRow(c, i + 1, o.objectives[i]),
            ],
          ),
        ),
      ],
      if (o.clos.isNotEmpty) ...[
        courseSectionHeader(c, 'Learning outcomes',
            trailing:
                '${o.clos.length} CLO${o.clos.length == 1 ? '' : 's'}'),
        for (var i = 0; i < o.clos.length; i++)
          _cloCard(c, o.clos[i], _weightTones[i % _weightTones.length]),
      ],
    ],
  );
}

/// The horizontal share-of-marks bar: each type sized by its weight.
class _WeightStack extends StatelessWidget {
  final List<CourseWeightage> weightages;
  const _WeightStack({required this.weightages});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    var total = 0.0;
    for (final w in weightages) {
      total += w.weight;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Who earns the marks',
                style: body(c,
                    size: 11,
                    weight: FontWeight.w800,
                    color: c.tealInk.withValues(alpha: 0.5))),
            const Spacer(),
            Text('${_trimNum(total)}%',
                style: body(c,
                    size: 11,
                    weight: FontWeight.w800,
                    color: c.tealInk.withValues(alpha: 0.5))),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 18,
            child: Row(
              children: [
                for (var i = 0; i < weightages.length; i++)
                  Expanded(
                    flex: weightages[i].weight.round().clamp(1, 100),
                    child: Container(color: _weightTones[i % _weightTones.length]),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// One weightage line: tone dot, type, top-N hint, weight + bar.
Widget _weightRow(AppColors c, CourseWeightage w, Color tone) {
  // Pill text must stay exactly '<weight>%' — tab tests match it.
  final fill = w.weight.clamp(0.0, 100.0) / 100;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: tone, borderRadius: BorderRadius.circular(3)),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(w.type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(c,
                              size: 13, weight: FontWeight.w800))),
                  if (w.considerTop > 0) ...[
                    const SizedBox(width: 6),
                    courseChip(c, 'top ${w.considerTop} counted',
                        bg: c.board.withValues(alpha: 0.16), fg: c.board),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: fill.toDouble(),
                  minHeight: 6,
                  backgroundColor: c.dustSoft.withValues(alpha: 0.65),
                  valueColor: AlwaysStoppedAnimation(tone),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 64,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text('${w.weight}%',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.2)),
          ),
        ),
      ],
    ),
  );
}

/// One numbered objective line.
Widget _objectiveRow(AppColors c, int index, String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.teal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$index',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: c.tealDeep)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: body(c, size: 12.5, color: c.tealInk.withValues(alpha: 0.85)),
          ),
        ),
      ],
    ),
  );
}

/// One learning-outcome card with CLO chip + Bloom/PLO chips.
Widget _cloCard(AppColors c, CourseOutlineClo clo, Color tone) {
  return courseCard(
    c,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          alignment: Alignment.center,
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(clo.clo,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                  color: tone)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(clo.statement,
                  style: body(c, size: 13, weight: FontWeight.w600,
                      color: c.tealInk)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (clo.bloom.isNotEmpty)
                    courseChip(c, clo.bloom,
                        bg: c.teal.withValues(alpha: 0.10), fg: c.tealDeep),
                  if (clo.plo.isNotEmpty)
                    courseChip(c, 'PLO ${clo.plo}'),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _trimNum(double v) {
  final whole = v.truncateToDouble() == v;
  return whole ? v.toInt().toString() : v.toStringAsFixed(1);
}
