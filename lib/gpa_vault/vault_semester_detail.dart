// Semester detail: header Semester GPA/Credits + refresh,
// course list, add-course dialog. Mirrors SemesterDetailsActivity.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/palette.dart';
import '../widgets/common.dart';
import 'models.dart';
import 'store.dart';
import 'vault_course_detail.dart';

class VaultSemesterDetail extends StatefulWidget {
  final String semesterId;
  const VaultSemesterDetail({super.key, required this.semesterId});
  @override
  State<VaultSemesterDetail> createState() => _VaultSemesterDetailState();
}

class _VaultSemesterDetailState extends State<VaultSemesterDetail> {
  VaultStore? store;
  VaultSemester? semester;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final s = VaultStore(prefs);
    final found = s.semesters().where((e) => e.id == widget.semesterId);
    setState(() {
      store = s;
      semester = found.isEmpty ? null : found.first;
    });
  }

  Future<void> _refresh() async {
    if (store == null || semester == null) return;
    final list = store!.courses(semester!.id);
    await store!.persistSemesterRefresh(semester!, list);
    setState(() {});
  }

  Future<void> _addCourse() async {
    if (store == null || semester == null) return;
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'General');
    int credits = 3;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = AppScope.colorsOf(ctx);
        return StatefulBuilder(builder: (ctx, setD) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            title: Text('Add Course to Semester',
                style: display(c, size: 18), textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Course name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: catCtrl,
                  decoration: InputDecoration(
                    hintText: 'Category',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: credits,
                  decoration: InputDecoration(
                    labelText: 'Credit Hours',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    for (final h in [1, 2, 3, 4])
                      DropdownMenuItem(value: h, child: Text('$h')),
                  ],
                  onChanged: (v) => setD(() => credits = v ?? 3),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Add Course')),
            ],
          );
        });
      },
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    await store!.addCourse(
      semester!.id,
      name: nameCtrl.text,
      category: catCtrl.text.trim().isEmpty ? 'General' : catCtrl.text.trim(),
      creditHours: credits,
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Scaffold(
      backgroundColor: c.cream2,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text(semester?.name ?? 'Semester',
            style: display(c, size: 18)),
      ),
      body: store == null || semester == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: c.teal,
              backgroundColor: c.white,
              onRefresh: _refresh,
              child: UHead(
                height: 112,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WhiteCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Semester GPA:',
                                    style: body(c, weight: FontWeight.w700)),
                                Text(
                                  semester!.sGpa?.toStringAsFixed(2) ?? '--',
                                  style: display(c, size: 28),
                                ),
                                Text(
                                  'Semester Credit Hours: ${semester!.creditHours}',
                                  style: body(c, size: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Refresh',
                            icon: const Icon(Icons.refresh),
                            onPressed: _refresh,
                          ),
                          IconButton(
                            tooltip: 'Add Course',
                            icon: const Icon(Icons.add),
                            onPressed: _addCourse,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Builder(builder: (_) {
                      final list = store!.courses(semester!.id);
                      if (list.isEmpty) {
                        return WhiteCard(
                          child: Text(
                            'No Courses added\n1) Add Courses to start calculating GPA\n2) Then click on the course to add assessments in the courses\n3) Calculate the grade in the course using the Refresh Button',
                            style: body(c, size: 13),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final course in list)
                            _courseCard(c, course),
                        ],
                      );
                    }),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _courseCard(AppColors c, VaultCourse course) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VaultCourseDetail(
              semesterId: semester!.id,
              courseId: course.id,
            ),
          ),
        );
        setState(() {});
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: c.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.name,
                      style: body(c, weight: FontWeight.w800)),
                  Text(course.category,
                      style: body(c,
                          size: 12,
                          color: c.tealInk.withValues(alpha: 0.6))),
                  Text('Credit Hours :  ${course.creditHours}',
                      style: body(c, size: 12)),
                  Text(
                    'Percentage : ${course.obtainedPercentage.toStringAsFixed(2)} / ${course.totalPercentage.toStringAsFixed(2)}%',
                    style: body(c, size: 12),
                  ),
                  Text('Grade :  ${course.grade}',
                      style: body(c,
                          size: 13, weight: FontWeight.w700)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Delete Course',
              icon: Icon(Icons.delete_outline, color: c.clay),
              onPressed: () async {
                await store!.deleteCourse(semester!.id, course.id);
                await _refresh();
              },
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
