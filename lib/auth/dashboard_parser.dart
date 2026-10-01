import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// Parsed view of the Horizon student dashboard.
///
/// Selector mapping was reverse-engineered from the real
/// `/student/dashboard` page (Odoo 15 + Altair admin theme):
///
/// - name     : `h2.heading_b > span.uk-text-truncate`
/// - studentId: `h2.heading_b > span.sub-heading` [0]  (e.g. L1F25…)
/// - faculty  : `h2.heading_b > span.sub-heading` [1]
/// - CGPA     : `.user_heading_content` containing "Academic Standings",
///   number after `CGPA:` (the span's class is a raw QWeb conditional, so
///   the label text — not the class — is matched)
/// - credits  : sibling `.user_heading_content` divs, `Earned/Total/
///   Inprogress Cr : <number>` via regex on the block text
/// - today    : `.user_heading_content` containing "Today Classes",
///   following `<span>` text
/// - news     : `<h3>` "News and Announcements" + following `<span>` and
///   slider `<li>` items
///
/// Generic heuristic layers still run as fallback when the exact markup is
/// absent (other pages/portal versions). Parsing never throws.
class DashboardStat {
  final String label;
  final String value;
  const DashboardStat(this.label, this.value);
}

class DashboardData {
  final String? studentName;
  final String? studentId;
  final String? faculty;
  final List<DashboardStat> stats;
  final String? todayClasses;
  final List<String> news;
  const DashboardData({
    this.studentName,
    this.studentId,
    this.faculty,
    this.stats = const [],
    this.todayClasses,
    this.news = const [],
  });

  bool get isEmpty =>
      studentName == null &&
      studentId == null &&
      stats.isEmpty &&
      todayClasses == null &&
      news.isEmpty;
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
  final exact = _parseExact(doc);
  // Heuristic layers fill whatever the exact pass missed.
  return DashboardData(
    studentName: exact.studentName ?? _findName(doc),
    studentId: exact.studentId,
    faculty: exact.faculty,
    stats: exact.stats.isNotEmpty ? exact.stats : _findStats(doc),
    todayClasses: exact.todayClasses,
    news: exact.news,
  );
}

/// Exact pass against the real dashboard markup.
DashboardData _parseExact(Document doc) {
  String? name;
  String? sid;
  String? faculty;
  final h2 = doc.querySelector('h2.heading_b');
  if (h2 != null) {
    name = _clean(h2.querySelector('span.uk-text-truncate')?.text);
    final subs = h2
        .querySelectorAll('span.sub-heading')
        .map((e) => _clean(e.text))
        .where((t) => t.isNotEmpty)
        .toList();
    if (subs.isNotEmpty) sid = subs[0];
    if (subs.length > 1) faculty = subs[1];
  }

  final stats = <DashboardStat>[];
  String? today;
  for (final block in doc.querySelectorAll('.user_heading_content')) {
    final text = _clean(block.text);
    if (text.contains('Academic Standings')) {
      final cgpa = RegExp(r'CGPA:\s*([0-9]+\.[0-9]+)').firstMatch(text);
      if (cgpa != null) stats.add(DashboardStat('CGPA', cgpa.group(1)!));
    }
    if (text.contains('Earned Cr')) {
      for (final entry in ['Earned Cr', 'Total Cr', 'Inprogress Cr']) {
        final m =
            RegExp('${RegExp.escape(entry)}\\s*:\\s*([0-9]+\\.?[0-9]*)')
                .firstMatch(text);
        if (m != null) stats.add(DashboardStat(entry, m.group(1)!));
      }
    }
    if (text.contains('Today Classes')) {
      final span = block.querySelector('span');
      today = _clean(span?.text);
      if (today != null && today.isEmpty) today = null;
    }
  }

  final news = <String>[];
  for (final h in doc.querySelectorAll('h3')) {
    if (_clean(h.text) != 'News and Announcements') continue;
    var el = h.nextElementSibling;
    var hops = 0;
    while (el != null && hops < 4) {
      if (el.localName == 'span') {
        final t = _clean(el.text);
        if (t.isNotEmpty) news.add(t);
      }
      for (final li in el.querySelectorAll('li')) {
        final t = _clean(li.text);
        if (t.isNotEmpty && t.length < 200 && news.length < 6) news.add(t);
      }
      el = el.nextElementSibling;
      hops++;
    }
    break;
  }

  return DashboardData(
    studentName: (name != null && name.isNotEmpty) ? name : null,
    studentId: (sid != null && sid.isNotEmpty) ? sid : null,
    faculty: (faculty != null && faculty.isNotEmpty) ? faculty : null,
    stats: stats,
    todayClasses: today,
    news: news,
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
