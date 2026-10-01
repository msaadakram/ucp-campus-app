import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// Parsed view of the Horizon student dashboard.
///
/// The parser is deliberately heuristic: the dashboard is server-rendered
/// Odoo HTML whose exact markup can only be confirmed with a live student
/// session. Layers run from most-specific to most-generic and everything
/// degrades to empty (never throws on unexpected markup).
class DashboardStat {
  final String label;
  final String value;
  const DashboardStat(this.label, this.value);
}

class DashboardData {
  final String? studentName;
  final List<DashboardStat> stats;
  const DashboardData({this.studentName, this.stats = const []});

  bool get isEmpty => studentName == null && stats.isEmpty;
}

String _clean(String? s) => (s ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Parse `/student/dashboard` HTML into displayable data.
DashboardData parseDashboard(String html) {
  final Document doc;
  try {
    doc = html_parser.parse(html);
  } catch (_) {
    return const DashboardData();
  }
  return DashboardData(
    studentName: _findName(doc),
    stats: _findStats(doc),
  );
}

const _nameSelectors = [
  '.student-name',
  '#student_name',
  '[data-student-name]',
  '.portal-name',
  '.o_portal_name',
  '.student-info h2',
  '.dashboard-username',
  '.user-name',
];

String? _findName(Document doc) {
  for (final sel in _nameSelectors) {
    final text = _clean(doc.querySelector(sel)?.text);
    if (text.length >= 3) return text;
  }
  // Fallback: first heading that looks like a person (2-4 words, no digits).
  for (final tag in ['h1', 'h2', 'h3']) {
    for (final el in doc.querySelectorAll(tag)) {
      final text = _clean(el.text);
      final words = text.split(' ');
      if (words.length >= 2 &&
          words.length <= 4 &&
          !RegExp(r'\d').hasMatch(text) &&
          text.length < 60) {
        return text;
      }
    }
  }
  return null;
}

List<DashboardStat> _findStats(Document doc) {
  final stats = <DashboardStat>[];
  final seen = <String>{};

  void add(String label, String value) {
    label = _clean(label);
    value = _clean(value);
    if (label.isEmpty || value.isEmpty) return;
    if (label.length > 40 || value.length > 40) return;
    final key = '$label::$value'.toLowerCase();
    if (seen.add(key)) stats.add(DashboardStat(label, value));
  }

  // Layer 1: explicit stat cards.
  for (final card in doc.querySelectorAll(
      '.stat-card, .stat_card, .dashboard-stat, .stat-box, .info-card, .portal-stat, .card-stat, [data-stat]')) {
    final label = _clean(card.querySelector(
            '.label, .stat-label, small, .card-label, [data-label]')
        ?.text);
    final value = _clean(card.querySelector(
            '.value, .stat-value, strong, h3, h4, b, .card-value, [data-value]')
        ?.text);
    if (label.isNotEmpty && value.isNotEmpty) {
      add(label, value);
    } else {
      final texts = card
          .querySelectorAll('div, span, p, strong, h3, h4, b, small')
          .map((e) => _clean(e.text))
          .where((t) => t.isNotEmpty && t.length <= 40)
          .toList();
      if (texts.length >= 2) add(texts[1], texts[0]);
    }
    if (stats.length >= 8) return stats;
  }
  if (stats.isNotEmpty) return stats;

  // Layer 2: two-column tables (label | value).
  for (final row in doc.querySelectorAll('tr')) {
    final cells = row
        .querySelectorAll('th, td')
        .map((e) => _clean(e.text))
        .where((t) => t.isNotEmpty)
        .toList();
    if (cells.length >= 2) add(cells[0], cells[1]);
    if (stats.length >= 8) return stats;
  }
  if (stats.isNotEmpty) return stats;

  // Layer 3: definition lists.
  final terms = doc.querySelectorAll('dt');
  for (final dt in terms) {
    var next = dt.nextElementSibling;
    while (next != null && next.localName != 'dd') {
      next = next.nextElementSibling;
    }
    if (next != null) add(dt.text, next.text);
    if (stats.length >= 8) return stats;
  }
  return stats;
}
