// Semester list: mirrors HomePage semesters + dialog_add_semester.
// Empty state text kept verbatim from strings.xml.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/palette.dart';
import '../widgets/common.dart';
import 'store.dart';
import 'vault_semester_detail.dart';

class VaultSemestersScreen extends StatefulWidget {
  final VoidCallback? onChanged;
  const VaultSemestersScreen({super.key, this.onChanged});
  @override
  State<VaultSemestersScreen> createState() => _VaultSemestersScreenState();
}

class _VaultSemestersScreenState extends State<VaultSemestersScreen> {
  VaultStore? store;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      store = VaultStore(prefs);
      loading = false;
    });
  }

  Future<void> _addSemester() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = AppScope.colorsOf(ctx);
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Add Semester',
              style: display(c, size: 18), textAlign: TextAlign.center),
          content: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: 'Semester, Type, Year…',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Add Semester')),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || store == null) return;
    await store!.addSemester(name);
    setState(() {});
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    if (loading || store == null) {
      return UHead(
        height: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Courses',
                style: display(c, size: 26, color: Colors.white)),
            const SizedBox(height: 16),
            const WhiteCard(child: Text('Loading Semesters')),
          ],
        ),
      );
    }
    final items = store!.semesters();
    return RefreshIndicator(
      color: c.teal,
      backgroundColor: c.white,
      onRefresh: () async => setState(() {}),
      child: UHead(
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
                      Text('My Courses',
                          style: display(c, size: 26, color: Colors.white)),
                      Text('Choose Your Semester',
                          style: body(c,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.78))),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _addSemester,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                        color: c.white,
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      Icon(Icons.add, size: 16, color: c.tealInk),
                      Text(' Add',
                          style: TextStyle(
                              color: c.tealInk,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              WhiteCard(
                child: Text(
                  'No Semester added\n1) Add Semesters to start calculating CGPA/GPA\n2) Then add courses in the semester from the Home Page Courses',
                  style: body(c, size: 13),
                ),
              )
            else
              for (final s in items)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            VaultSemesterDetail(semesterId: s.id),
                      ),
                    );
                    setState(() {});
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: c.white,
                        borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name,
                                  style:
                                      body(c, weight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(
                                'GPA : ${s.sGpa?.toStringAsFixed(2) ?? '--'}',
                                style: body(c, size: 13),
                              ),
                              Text(
                                'Credit Hours :  ${s.creditHours}',
                                style: body(c,
                                    size: 13,
                                    color: c.tealInk.withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete Semester',
                          icon: Icon(Icons.delete_outline, color: c.clay),
                          onPressed: () async {
                            await store!.deleteSemester(s.id);
                            setState(() {});
                          },
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
