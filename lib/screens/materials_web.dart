import 'package:flutter/material.dart';
import '../data/seed.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});
  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  String sel = courses[0].code;
  String view = 'files';
  String kind = 'All';
  final Set<String> done = {};
  Course get c => courses.firstWhere((x) => x.code == sel);

  final papers = const [
    ['Final', 'Fall 2025', '3 hrs · 100 marks', true],
    ['Midterm', 'Fall 2025', '90 min · 40 marks', true],
    ['Quiz', 'Fall 2025', 'Quiz 2 · 15 marks', false],
    ['Final', 'Spring 2025', '3 hrs · 100 marks', true],
    ['Midterm', 'Spring 2025', '90 min · 40 marks', false],
    ['Final', 'Fall 2024', '3 hrs · 100 marks', false],
  ];
  final items = const [
    ['PDF', 'Lecture 6 — slides', '2.4 MB', 0],
    ['VID', 'Recorded lecture · Week 5', '48 min', 1],
    ['DOC', 'Assignment 3 brief', '310 KB', 2],
    ['PDF', 'Reading list', '120 KB', 3],
    ['ZIP', 'Lab starter files', '5.1 MB', 4],
  ];

  @override
  Widget build(BuildContext context) {
    final ac = AppScope.colorsOf(context);
    final shown = papers.where((p) => kind == 'All' || p[0] == kind).toList();
    final bgTones = [ac.clay, ac.teal, ac.board, ac.dust, ac.tealInk];
    return UHead(
      height: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Course material', style: display(ac, size: 28, color: Colors.white)),
          Text('Slides, recordings and files for every class', style: body(ac, size: 14, color: Colors.white.withValues(alpha: 0.78))),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final x in courses)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => sel = x.code),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: sel == x.code ? ac.tealInk : ac.dustSoft, borderRadius: BorderRadius.circular(20)),
                        child: Text(x.code, style: body(ac, size: 14, weight: FontWeight.w600, color: sel == x.code ? ac.cream : ac.tealInk.withValues(alpha: 0.7))),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: toneBg(c.tone, ac), borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c.code} · ${c.prof}'.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
                Text(c.title, style: display(ac, size: 22, color: c.tone == CourseTone.board ? ac.tealInk : Colors.white)),
                Text(view == 'files' ? '${items.length} files · updated 2 days ago' : '${papers.length} past papers · ${done.where((d) => d.startsWith(sel)).length} practiced',
                    style: TextStyle(fontSize: 14, color: (c.tone == CourseTone.board ? ac.tealInk : Colors.white).withValues(alpha: 0.8))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: ac.dustSoft, borderRadius: BorderRadius.circular(30)),
            child: Row(
              children: [
                for (final v in ['files', 'papers'])
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => view = v),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(color: view == v ? ac.tealInk : Colors.transparent, borderRadius: BorderRadius.circular(24)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(v == 'files' ? Icons.book_outlined : Icons.assignment_outlined, size: 16, color: view == v ? ac.cream : ac.tealInk.withValues(alpha: 0.65)),
                            const SizedBox(width: 6),
                            Text(v == 'files' ? 'Materials' : 'Past papers', style: body(ac, size: 14, weight: FontWeight.bold, color: view == v ? ac.cream : ac.tealInk.withValues(alpha: 0.65))),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (view == 'papers') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (final k in ['All', 'Final', 'Midterm', 'Quiz'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => kind = k),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: kind == k ? ac.teal : Colors.transparent,
                          border: Border.all(color: kind == k ? ac.teal : ac.dustSoft, width: 2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(k, style: body(ac, size: 12, weight: FontWeight.bold, color: kind == k ? Colors.white : ac.tealInk.withValues(alpha: 0.65))),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (final p in shown)
              Builder(builder: (_) {
                final id = '$sel-${p[0]}-${p[1]}';
                final ok = done.contains(id);
                final sol = p[3] == true;
                Color badge = p[0] == 'Final' ? ac.clay : p[0] == 'Midterm' ? ac.teal : ac.dust;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: ac.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(alignment: Alignment.center, width: 48, height: 48, decoration: BoxDecoration(color: badge, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.description_outlined, color: Colors.white)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${c.code} ${p[0]} · ${p[1]}', style: body(ac, size: 14, weight: FontWeight.w600)), Text(p[2] as String, style: body(ac, size: 12, color: ac.tealInk.withValues(alpha: 0.55)))])),
                          Container(alignment: Alignment.center, width: 40, height: 40, decoration: BoxDecoration(color: ac.dustSoft, shape: BoxShape.circle), child: Icon(Icons.download_outlined, size: 18, color: ac.tealInk)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: ac.dustSoft))),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: sol ? ac.board.withValues(alpha: 0.4) : ac.dustSoft, borderRadius: BorderRadius.circular(12)),
                              child: Text(sol ? 'Solution included' : 'Questions only', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            const Spacer(),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => ok ? done.remove(id) : done.add(id)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(color: ok ? ac.teal : Colors.transparent, border: Border.all(color: ok ? ac.teal : ac.dustSoft, width: 2), borderRadius: BorderRadius.circular(20)),
                                child: Row(children: [const Icon(Icons.check, size: 13), Text(ok ? 'Practiced' : 'Mark practiced', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ok ? Colors.white : ac.tealInk.withValues(alpha: 0.65)))]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ] else ...[
            const SizedBox(height: 16),
            for (final it in items)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: ac.white, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Container(width: 48, height: 48, decoration: BoxDecoration(color: bgTones[it[3] as int], borderRadius: BorderRadius.circular(12)), child: Center(child: Text(it[0] as String, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(it[1] as String, style: body(ac, size: 14, weight: FontWeight.w600)), Text(it[2] as String, style: body(ac, size: 12, color: ac.tealInk.withValues(alpha: 0.55)))])),
                    Container(alignment: Alignment.center, width: 40, height: 40, decoration: BoxDecoration(color: ac.dustSoft, shape: BoxShape.circle), child: Icon(Icons.download_outlined, size: 18, color: ac.tealInk)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});
  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  final sites = const [['Student portal', 'portal.uni.edu'], ['Library', 'library.uni.edu'], ['LMS', 'learn.uni.edu']];
  String url = 'portal.uni.edu';
  bool loading = false;
  late TextEditingController ctrl;
  @override
  void initState() {
    super.initState();
    ctrl = TextEditingController(text: url);
  }

  void go(String u) {
    setState(() { url = u; ctrl.text = u; loading = true; });
    Future.delayed(const Duration(milliseconds: 600), () => mounted ? setState(() => loading = false) : null);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final title = sites.firstWhere((s) => s[1] == url, orElse: () => ['Web page', url])[0];
    return UHead(
      height: 108,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Web view', style: display(c, size: 28, color: Colors.white)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: c.teal),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: ctrl, onSubmitted: go, style: const TextStyle(fontSize: 14), decoration: const InputDecoration(border: InputBorder.none, isDense: true))),
                GestureDetector(onTap: () => go(ctrl.text), child: Container(alignment: Alignment.center, width: 36, height: 36, decoration: BoxDecoration(color: c.tealInk, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.refresh, size: 16, color: Colors.white))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final s in sites)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => go(s[1]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: url == s[1] ? c.teal : c.dustSoft, borderRadius: BorderRadius.circular(20)),
                      child: Text(s[0], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: url == s[1] ? Colors.white : c.tealInk)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: c.dustSoft, width: 2)),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  child: LinearProgressIndicator(value: loading ? 0.66 : 1, backgroundColor: c.dustSoft, valueColor: AlwaysStoppedAnimation(c.clay), minHeight: 4),
                ),
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(20), color: c.teal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(url.toUpperCase(), style: TextStyle(fontSize: 12, color: c.cream.withValues(alpha: 0.8))),
                      Text(title, style: display(c, size: 22, color: Colors.white)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: loading
                      ? Column(children: [for (int i = 0; i < 4; i++) Container(margin: const EdgeInsets.only(bottom: 8), height: 16, decoration: BoxDecoration(color: c.dustSoft, borderRadius: BorderRadius.circular(8)))])
                      : Column(
                          children: [
                            for (final l in ['Fee voucher — Fall 2026', 'Exam timetable', 'Course registration', 'Transcript request'])
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(children: [Expanded(child: Text(l, style: body(c, size: 14, weight: FontWeight.w600))), Icon(Icons.chevron_right, color: c.teal)]),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}
