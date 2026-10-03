import 'package:flutter/material.dart';
import '../auth/odoo_api.dart';
import '../auth/portal_api.dart';
import '../auth/student_portal.dart';
import '../data/seed.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/portal_state.dart';

class GpaRow {
  final int id;
  String name;
  int cr;
  int marks;
  int mean;
  int sd;
  GpaRow({required this.id, required this.name, required this.cr, required this.marks, required this.mean, required this.sd});
}

const _scale = [
  ['A+', 2.0, 4.0], ['A', 1.5, 4.0], ['A-', 1.0, 3.67], ['B+', 0.5, 3.33], ['B', 0.0, 3.0],
  ['B-', -0.5, 2.67], ['C+', -1.0, 2.33], ['C', -1.5, 2.0], ['D', -2.0, 1.0], ['F', -999.0, 0.0],
];

/// Grading mode: relative (curved on class mean, UCP default) vs
/// absolute (fixed marks thresholds, for what-if planning).
enum GpaMode { relative, absolute }

List<dynamic> _gradeOf(double z) => _scale.firstWhere((e) => z >= (e[1] as double));

/// Absolute marks -> grade. Common Pakistan scale used for planning:
/// 85+ A+, 80+ A, 75+ A-, 70+ B+, 65+ B, 60+ B-, 55+ C+, 50+ C, 40+ D, else F.
List<dynamic> _gradeOfAbsolute(int marks) {
  if (marks >= 85) return ['A+', 2.0, 4.0];
  if (marks >= 80) return ['A', 1.5, 4.0];
  if (marks >= 75) return ['A-', 1.0, 3.67];
  if (marks >= 70) return ['B+', 0.5, 3.33];
  if (marks >= 65) return ['B', 0.0, 3.0];
  if (marks >= 60) return ['B-', -0.5, 2.67];
  if (marks >= 55) return ['C+', -1.0, 2.33];
  if (marks >= 50) return ['C', -1.5, 2.0];
  if (marks >= 40) return ['D', -2.0, 1.0];
  return ['F', -999.0, 0.0];
}

double _zOf(GpaRow r) => (r.marks - r.mean) / (r.sd == 0 ? 0.1 : r.sd.toDouble());

Color _tone(String g, AppColors c) {
  if (g.startsWith('A')) return c.teal;
  if (g.startsWith('B')) return c.board;
  if (g.startsWith('C')) return c.clay;
  return c.tealInk;
}

class GpaCalcScreen extends StatefulWidget {
  const GpaCalcScreen({super.key});
  @override
  State<GpaCalcScreen> createState() => _GpaCalcScreenState();
}

class _GpaCalcScreenState extends State<GpaCalcScreen> {
  List<GpaRow> rows = [
    GpaRow(id: 1, name: 'CS 214 · Data Structures', cr: 4, marks: 78, mean: 64, sd: 11),
    GpaRow(id: 2, name: 'MA 201 · Linear Algebra', cr: 3, marks: 61, mean: 58, sd: 12),
    GpaRow(id: 3, name: 'DS 150 · Design Thinking', cr: 2, marks: 88, mean: 74, sd: 8),
    GpaRow(id: 4, name: 'EN 110 · Academic Writing', cr: 2, marks: 69, mean: 71, sd: 9),
  ];
  double prevCgpa = 3.45;
  int prevCr = 36;
  int? open = 1;
  bool help = false;
  int uid = 10;
  GpaMode mode = GpaMode.relative;
  double targetCgpa = 3.50;

  List<dynamic> _gradeFor(GpaRow r) =>
      mode == GpaMode.relative ? _gradeOf(_zOf(r)) : _gradeOfAbsolute(r.marks);

  void _reset() => setState(() {
        rows = [
          GpaRow(id: 1, name: 'CS 214 · Data Structures', cr: 4, marks: 78, mean: 64, sd: 11),
          GpaRow(id: 2, name: 'MA 201 · Linear Algebra', cr: 3, marks: 61, mean: 58, sd: 12),
          GpaRow(id: 3, name: 'DS 150 · Design Thinking', cr: 2, marks: 88, mean: 74, sd: 8),
          GpaRow(id: 4, name: 'EN 110 · Academic Writing', cr: 2, marks: 69, mean: 71, sd: 9),
        ];
        prevCgpa = 3.45;
        prevCr = 36;
        targetCgpa = 3.50;
        open = 1;
        uid = 10;
      });

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final credits = rows.fold(0, (s, r) => s + r.cr);
    final pts = rows.fold(0.0, (s, r) => s + (_gradeFor(r)[2] as double) * r.cr);
    final sgpa = credits == 0 ? 0 : pts / credits;
    final cgpa = (prevCr + credits) == 0 ? 0.0 : (prevCgpa * prevCr + pts) / (prevCr + credits);
    final requiredSgpa = credits == 0
        ? 0.0
        : (targetCgpa * (prevCr + credits) - prevCgpa * prevCr) / credits;
    return UHead(
      height: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GPA calculator', style: display(c, size: 26, color: Colors.white), overflow: TextOverflow.ellipsis),
                    Text(mode == GpaMode.relative ? 'Relative grading · curved on class mean' : 'Absolute grading · fixed thresholds', style: body(c, size: 13, color: Colors.white.withValues(alpha: 0.78)), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(onTap: () => setState(() => help = !help), child: Container(alignment: Alignment.center, width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.info_outline, color: Colors.white))),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(30)),
            child: Row(
              children: [
                for (final m in GpaMode.values)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => mode = m),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(color: mode == m ? c.white : Colors.transparent, borderRadius: BorderRadius.circular(24)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(m == GpaMode.relative ? Icons.show_chart_outlined : Icons.rule_outlined, size: 16, color: mode == m ? c.tealInk : Colors.white70),
                            const SizedBox(width: 6),
                            Text(m == GpaMode.relative ? 'Relative' : 'Absolute', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: mode == m ? c.tealInk : Colors.white70)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: c.tealInk, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: c.clay, offset: const Offset(0, 6))]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('THIS SEMESTER', style: TextStyle(fontSize: 11, color: c.cream.withValues(alpha: 0.7))), Text(sgpa.toStringAsFixed(2), style: display(c, size: 36, color: c.cream)), Text('SGPA · $credits credits', style: TextStyle(fontSize: 12, color: c.cream.withValues(alpha: 0.7)))]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(24)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('CUMULATIVE', style: TextStyle(fontSize: 11, color: c.tealInk.withValues(alpha: 0.55))), Text(cgpa.toStringAsFixed(2), style: display(c, size: 36, color: c.teal)), Text('${cgpa >= prevCgpa ? '+' : ''}${(cgpa - prevCgpa).toStringAsFixed(2)} CGPA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cgpa >= prevCgpa ? c.teal : c.clay))]),
                ),
              ),
            ],
          ),
          if (help)
            Container(
              margin: const EdgeInsets.only(top: 16), padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mode == GpaMode.relative ? 'How relative grading works' : 'How absolute grading works', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                      mode == GpaMode.relative
                          ? 'Your grade depends on where your marks sit against the class: z = (your marks − class mean) ÷ std. deviation.'
                          : 'Your grade depends only on your marks: 85+ A+, 80+ A, 75+ A-, 70+ B+, 65+ B, 60+ B-, 55+ C+, 50+ C, 40+ D, else F.',
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 5, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 0.75,
                    children: [
                      for (final s in _scale)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(color: _tone(s[0] as String, c), borderRadius: BorderRadius.circular(12)),
                          child: Column(children: [Text(s[0] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)), Text((s[1] as double) <= -900 ? '< −2σ' : '≥ ${s[1]}σ', style: const TextStyle(fontSize: 9, color: Colors.white70)), Text((s[2] as double).toStringAsFixed(2), style: const TextStyle(fontSize: 10, color: Colors.white))]),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 16), padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Previous record', style: TextStyle(fontWeight: FontWeight.bold)),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _reset,
                      child: const Row(children: [Icon(Icons.refresh, size: 14), Text(' Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _numBox(c, 'CURRENT CGPA', prevCgpa, 4, (v) => setState(() => prevCgpa = v))),
                    const SizedBox(width: 8),
                    Expanded(child: _numBoxInt(c, 'CREDITS DONE', prevCr, 200, (v) => setState(() => prevCr = v))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _numBox(c, 'TARGET CGPA', targetCgpa, 4, (v) => setState(() => targetCgpa = v))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: c.tealInk, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('NEED SGPA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
                            Text(
                              credits == 0 ? '—' : requiredSgpa.toStringAsFixed(2),
                              style: display(c, size: 18, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  credits == 0
                      ? 'Add a course below to plan your target.'
                      : requiredSgpa > 4.0
                          ? 'Target ${targetCgpa.toStringAsFixed(2)} needs SGPA ${requiredSgpa.toStringAsFixed(2)} — not possible this term.'
                          : requiredSgpa <= 0
                              ? 'Target ${targetCgpa.toStringAsFixed(2)} already secured even with 0.00 this term.'
                              : 'You need SGPA ${requiredSgpa.toStringAsFixed(2)} across $credits credits to reach ${targetCgpa.toStringAsFixed(2)}. Quality points so far: ${pts.toStringAsFixed(2)}.',
                  style: TextStyle(fontSize: 12, color: c.tealInk.withValues(alpha: 0.65)),
                ),
                if (sgpa >= 3.5 && credits > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: c.teal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: const Row(children: [Icon(Icons.emoji_events_outlined, size: 14), SizedBox(width: 6), Text("Dean's List pace · SGPA ≥ 3.50", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Courses', style: display(c, size: 20)),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() { uid++; rows.add(GpaRow(id: uid, name: 'New course', cr: 3, marks: 60, mean: 60, sd: 10)); open = uid; }),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: c.tealInk, borderRadius: BorderRadius.circular(20)), child: const Row(children: [Icon(Icons.add, size: 16, color: Colors.white), Text(' Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final r in rows)
            Builder(builder: (_) {
              final z = _zOf(r);
              final g = _gradeFor(r);
              final on = open == r.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => open = on ? null : r.id),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(width: 48, height: 48, decoration: BoxDecoration(color: _tone(g[0] as String, c), borderRadius: BorderRadius.circular(16)), child: Center(child: Text(g[0] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)))),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis), Text(mode == GpaMode.relative ? '${r.cr} cr · ${r.marks} marks · z ${z >= 0 ? '+' : ''}${z.toStringAsFixed(2)} · ${(g[2] as double).toStringAsFixed(2)} pts' : '${r.cr} cr · ${r.marks} marks · ${(g[2] as double).toStringAsFixed(2)} pts', style: TextStyle(fontSize: 12, color: c.tealInk.withValues(alpha: 0.55)))])),
                          ],
                        ),
                      ),
                    ),
                    if (on)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.dustSoft))),
                        child: Column(
                          children: [
                            TextFormField(
                              key: ValueKey('name-${r.id}'),
                              initialValue: r.name,
                              onChanged: (v) => r.name = v, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.dustSoft, width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
                            const SizedBox(height: 12),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Your marks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), Text('${r.marks} / 100', style: TextStyle(color: c.teal, fontWeight: FontWeight.bold, fontSize: 12))]),
                            Slider(value: r.marks.clamp(0, 100).toDouble(), min: 0, max: 100, activeColor: c.teal, onChanged: (v) => setState(() => r.marks = v.round())),
                            if (mode == GpaMode.relative)
                              Row(
                                children: [
                                  Expanded(child: _numBoxInt(c, 'CLASS MEAN', r.mean, 100, (v) => setState(() => r.mean = v), keyVal: 'mean-${r.id}')),
                                  const SizedBox(width: 8),
                                  Expanded(child: _numBoxInt(c, 'STD. DEV', r.sd, 50, (v) => setState(() => r.sd = v), keyVal: 'sd-${r.id}')),
                                  const SizedBox(width: 8),
                                  Expanded(child: _numBoxInt(c, 'CREDITS', r.cr, 6, (v) => setState(() => r.cr = v), keyVal: 'cr-${r.id}')),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  Expanded(child: _numBoxInt(c, 'CREDITS', r.cr, 6, (v) => setState(() => r.cr = v), keyVal: 'cr-${r.id}')),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: c.dustSoft.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
                                      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('FIXED SCALE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), Text('85/80/75…', style: TextStyle(fontSize: 14))]),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 12),
                            if (mode == GpaMode.relative)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: c.cream, borderRadius: BorderRadius.circular(16)),
                                child: Column(
                                  children: [
                                    SizedBox(height: 64, child: CustomPaint(painter: _CurvePainter(z: z, teal: c.teal, clay: c.clay), size: const Size(double.infinity, 64))),
                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('−3σ', style: TextStyle(fontSize: 10)), Text('+3σ', style: TextStyle(fontSize: 10))]),
                                  ],
                                ),
                              ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(onPressed: () => setState(() => rows.remove(r)), icon: Icon(Icons.delete_outline, size: 14, color: c.clay), label: Text('Remove course', style: TextStyle(fontSize: 12, color: c.clay, fontWeight: FontWeight.bold))),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _numBox(AppColors c, String label, double v, double max, ValueChanged<double> set, {Object? keyVal}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.dustSoft.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          TextFormField(
            key: ValueKey(keyVal ?? label),
            initialValue: v.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (s) {
              final p = double.tryParse(s);
              if (p != null) set(p.clamp(0, max).toDouble());
            },
            onFieldSubmitted: (s) => set(double.tryParse(s)?.clamp(0, max) ?? v),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            style: display(c, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _numBoxInt(AppColors c, String label, int v, int max, ValueChanged<int> set, {Object? keyVal}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.dustSoft.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          TextFormField(
            key: ValueKey(keyVal ?? label),
            initialValue: '$v',
            keyboardType: TextInputType.number,
            onChanged: (s) {
              final p = int.tryParse(s);
              if (p != null) set(p.clamp(0, max));
            },
            onFieldSubmitted: (s) => set(int.tryParse(s)?.clamp(0, max) ?? v),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            style: display(c, size: 18),
          ),
        ],
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  final double z;
  final Color teal;
  final Color clay;
  _CurvePainter({required this.z, required this.teal, required this.clay});
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = teal.withValues(alpha: 0.15)..style = PaintingStyle.fill;
    final line = Paint()..color = teal..strokeWidth = 2..style = PaintingStyle.stroke;
    final path = Path()..moveTo(0, size.height);
    for (int i = 0; i <= 60; i++) {
      final x = -3 + (i / 60) * 6;
      final y = size.height - (exponential(-(x * x) / 2) * (size.height - 8));
      path.lineTo((i / 60) * size.width, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, fill);
    final stroke = Path();
    for (int i = 0; i <= 60; i++) {
      final x = -3 + (i / 60) * 6;
      final y = size.height - (exponential(-(x * x) / 2) * (size.height - 8));
      if (i == 0) stroke.moveTo(0, y);
      else stroke.lineTo((i / 60) * size.width, y);
    }
    canvas.drawPath(stroke, line);
    final cx = ((z.clamp(-3, 3) + 3) / 6) * size.width;
    canvas.drawLine(Offset(cx, 4), Offset(cx, size.height), Paint()..color = clay..strokeWidth = 2.5);
    canvas.drawCircle(Offset(cx, 4), 4, Paint()..color = clay);
  }

  double exponential(double x) => _exp(x);
  double _exp(double x) {
    double r = 1, t = 1;
    for (int n = 1; n < 20; n++) { t *= x / n; r += t; }
    return r;
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) => old.z != z;
}


const _weekOrder = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];

class TimetableScreen extends StatefulWidget {
  final String? sessionId;
  final VoidCallback? onSessionExpired;
  /// Test seam: canned page HTML per path (skips all network).
  final Future<String> Function(String path)? fetchHtml;
  const TimetableScreen(
      {super.key, this.sessionId, this.onSessionExpired, this.fetchHtml});
  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  TimetableData? data;
  DatesheetData? datesheet;
  bool loading = true;
  bool expired = false;
  String? error;
  late String day;
  bool grid = false;
  final Set<String> remind = {};

  @override
  void initState() {
    super.initState();
    day = _todayName();
    _load();
  }

  static String _todayName() {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return names[(DateTime.now().weekday - 1).clamp(0, 6)];
  }

  Future<String> _fetch(String path) {
    if (widget.fetchHtml != null) return widget.fetchHtml!(path);
    final sid = widget.sessionId;
    if (sid == null || sid.isEmpty) {
      return Future.error(OdooApiException('no portal session'));
    }
    return PortalApi().fetchPage(path, sid);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
      expired = false;
    });
    try {
      final results = await Future.wait([
        _fetch(PortalRoutes.timetable),
        _fetch(PortalRoutes.datesheet),
      ]);
      if (!mounted) return;
      final tt = parseTimetable(results[0] as String);
      final ds = parseDatesheet(results[1] as String);
      final days = [
        for (final d in _weekOrder)
          if (tt.slots.any((s) => s.day == d)) d
      ];
      setState(() {
        data = tt;
        datesheet = ds;
        loading = false;
        if (!days.contains(day) && days.isNotEmpty) day = days.first;
      });
    } on OdooApiException catch (e) {
      if (!mounted) return;
      final dead = e.message.contains('expired') ||
          e.message.contains('login') ||
          e.message.contains('no portal session');
      setState(() {
        loading = false;
        expired = dead;
        error = dead ? null : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Could not load the class schedule. Check connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    if (loading) {
      return const PortalLoading(
          title: 'Timetable', subtitle: 'Loading your class schedule…');
    }
    if (error != null || expired) {
      return PortalError(
        title: 'Timetable',
        message: expired
            ? 'Your portal session expired — sign in again to reload the schedule.'
            : error!,
        onRetry: _load,
        onRelogin: expired ? widget.onSessionExpired : null,
      );
    }
    final tt = data!;
    final days = [
      for (final d in _weekOrder)
        if (tt.slots.any((s) => s.day == d)) d
    ];
    final list = tt.slots.where((s) => s.day == day).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final hours = list.fold<double>(
        0, (n, s) => n + (_toH(s.end) - _toH(s.start)));
    final todayName = _todayName();
    final nowH =
        TimeOfDay.now().hour + TimeOfDay.now().minute / 60;
    final termLine = [
      if (tt.term.isNotEmpty) tt.term,
      if (tt.month.isNotEmpty) tt.month,
    ].join(' · ');
    return UHead(
      height: 184,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Timetable',
                        style: display(c, size: 28, color: Colors.white)),
                    Text(
                        termLine.isEmpty ? 'Class Schedule' : termLine,
                        style: body(c,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.78))),
                  ]),
              GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => grid = !grid),
                  child: Container(
                      alignment: Alignment.center,
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16)),
                      child: Icon(
                          grid ? Icons.list : Icons.grid_view_outlined,
                          color: Colors.white))),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (int i = 0; i < days.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == days.length - 1 ? 0 : 8),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          setState(() => day = days[i]),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                            color: day == days[i]
                                ? c.white
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: day == days[i]
                                ? [
                                    BoxShadow(
                                        color: c.clay,
                                        offset: const Offset(0, 4))
                                  ]
                                : null),
                        child: Column(children: [
                          Text(days[i].substring(0, 3),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: day == days[i]
                                      ? c.tealInk.withValues(alpha: 0.75)
                                      : Colors.white70)),
                          const SizedBox(height: 2),
                          Text(
                              '${tt.slots.where((s) => s.day == days[i]).length}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: day == days[i]
                                      ? c.tealInk
                                      : Colors.white)),
                          Text('classes',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: day == days[i]
                                      ? c.tealInk.withValues(alpha: 0.55)
                                      : Colors.white70)),
                          const SizedBox(height: 4),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: days[i] == todayName
                                  ? c.clay
                                  : Colors.transparent,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (grid)
            _gridView(c, days)
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(day,
                      style: display(c, size: 20),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Text('${list.length} classes · ${hours.toStringAsFixed(1)}h',
                    style: body(c,
                        size: 13,
                        color: c.tealInk.withValues(alpha: 0.55))),
              ],
            ),
            const SizedBox(height: 16),
            if (list.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: c.white,
                    borderRadius: BorderRadius.circular(24)),
                child: Text('No classes scheduled.',
                    textAlign: TextAlign.center,
                    style: body(c,
                        size: 14,
                        color: c.tealInk.withValues(alpha: 0.55))),
              ),
            for (final s in list)
              Builder(builder: (_) {
                final id = '${s.day}-${s.start}';
                final on = remind.contains(id);
                final tone = s.isLab ? c.clay : c.teal;
                final live = day == todayName &&
                    nowH >= _toH(s.start) &&
                    nowH < _toH(s.end);
                final past = day != todayName
                    ? _weekOrder.indexOf(day) <
                        _weekOrder.indexOf(todayName)
                    : nowH >= _toH(s.end);
                return Opacity(
                  opacity: past && !live ? 0.55 : 1,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(children: [
                        const SizedBox(height: 4),
                        Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                                color: live ? c.clay : tone,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: live
                                        ? c.clay.withValues(alpha: 0.3)
                                        : c.cream2,
                                    width: live ? 4 : 3))),
                      ]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.schedule_outlined, size: 13),
                              Flexible(
                                child: Text(
                                    ' ${s.start} – ${s.end}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (live)
                                Container(
                                  margin:
                                      const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: c.clay,
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  child: const Text('NOW',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: tone.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                    s.isLab ? 'Lab' : 'Lecture',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: tone)),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: tone,
                                  borderRadius: BorderRadius.circular(24)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(s.subject,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 17)),
                                      ),
                                      GestureDetector(
                                          behavior:
                                              HitTestBehavior.opaque,
                                          onTap: () => setState(() => on
                                              ? remind.remove(id)
                                              : remind.add(id)),
                                          child: Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                  color: on
                                                      ? Colors.white
                                                      : Colors.white
                                                          .withValues(
                                                              alpha: 0.2),
                                                  shape: BoxShape.circle),
                                              child: Icon(
                                                  Icons.notifications_outlined,
                                                  size: 16,
                                                  color: on
                                                      ? c.tealInk
                                                      : Colors.white))),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(s.teacher,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70)),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      _chip(s.room),
                                      if (s.section.isNotEmpty)
                                        _chip(s.section),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
              }),
          ],
          const SizedBox(height: 24),
          _datesheetCard(c),
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12)),
      child: Text(text,
          style: const TextStyle(fontSize: 11, color: Colors.white)),
    );
  }

  Widget _gridView(AppColors c, List<String> days) {
    const startH = 8;
    const endH = 22;
    const cellH = 44.0;
    final tones = [c.teal, c.clay, c.board, c.dust, c.tealDeep];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: c.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(children: [
            const SizedBox(width: 40),
            for (final d in days)
              Expanded(
                  child: Center(
                      child: Text(d.substring(0, 3),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)))),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: (endH - startH) * cellH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                    width: 40,
                    child: Stack(children: [
                      for (int i = 0; i <= endH - startH; i++)
                        Positioned(
                            top: i * cellH - 6,
                            child: Text(
                                '${(startH + i).toString().padLeft(2, '0')}:00',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: c.tealInk
                                        .withValues(alpha: 0.45)))),
                    ])),
                for (int d = 0; d < days.length; d++)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                          color: c.dustSoft.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12)),
                      child: Stack(
                        children: [
                          for (final s in data!.slots
                              .where((x) => x.day == days[d]))
                            Builder(builder: (_) {
                              final top =
                                  (_toH(s.start) - startH) * cellH;
                              final h = ((_toH(s.end) - _toH(s.start)) *
                                      cellH) -
                                  2;
                              final tone = tones[d % tones.length];
                              return Positioned(
                                top: top < 0 ? 0 : top,
                                height: h <= 10 ? 42 : h,
                                left: 2,
                                right: 2,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => setState(() {
                                    day = days[d];
                                    grid = false;
                                  }),
                                  child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                          color: tone,
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Text(
                                          '${s.subject}\n${s.start}',
                                          style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 4)),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _datesheetCard(AppColors c) {
    final ds = datesheet;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Exam datesheet', style: display(c, size: 20)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: c.white, borderRadius: BorderRadius.circular(24)),
          child: ds == null || ds.isEmpty
              ? Text(
                  ds?.notice.isNotEmpty == true
                      ? ds!.notice
                      : 'No exam datesheet notified yet.',
                  style: body(c,
                      size: 14,
                      color: c.tealInk.withValues(alpha: 0.6)),
                )
              : Column(
                  children: [
                    if (ds.headers.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            for (final h in ds.headers)
                              Expanded(
                                  child: Text(h,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                    for (final e in ds.exams)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            for (final cell in e.cells)
                              Expanded(
                                  child: Text(cell,
                                      style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  static double _toH(String hm) {
    final parts = hm.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) +
        (int.tryParse(parts[1]) ?? 0) / 60.0;
  }
}
