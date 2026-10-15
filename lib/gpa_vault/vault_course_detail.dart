// Course detail: 8 assessment sections + weightages + refresh.
// Mirrors UserCourseDetailsActivity + dialog_add_assessment +
// dialog_edit_course_attributes.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/palette.dart';
import '../widgets/common.dart';
import 'grading.dart';
import 'models.dart';
import 'store.dart';

class VaultCourseDetail extends StatefulWidget {
  final String semesterId;
  final String courseId;
  const VaultCourseDetail(
      {super.key, required this.semesterId, required this.courseId});
  @override
  State<VaultCourseDetail> createState() => _VaultCourseDetailState();
}

class _VaultCourseDetailState extends State<VaultCourseDetail> {
  VaultStore? store;
  VaultCourse? course;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final s = VaultStore(prefs);
    final found =
        s.courses(widget.semesterId).where((e) => e.id == widget.courseId);
    setState(() {
      store = s;
      course = found.isEmpty ? null : found.first;
    });
  }

  Future<void> _refresh() async {
    if (store == null || course == null) return;
    final items = store!.assessments(course!.id);
    final attrs = store!.attributes(course!.id);
    store!.refreshCourse(course!, items, attrs);
    await store!.updateCourse(widget.semesterId, course!);
    // Keep semester SGPA in sync like SemesterDetails refresh.
    final sems = store!.semesters().where((e) => e.id == widget.semesterId);
    if (sems.isNotEmpty) {
      await store!.persistSemesterRefresh(
          sems.first, store!.courses(widget.semesterId));
    }
    setState(() {});
  }

  Future<void> _addAssessment(String type) async {
    if (store == null || course == null) return;
    final totalCtrl = TextEditingController();
    final obtCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = AppScope.colorsOf(ctx);
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Add Assessment',
              style: display(c, size: 18), textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: totalCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: InputDecoration(
                  labelText: 'Total Marks',
                  hintText: 'Enter Total Marks',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: obtCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: InputDecoration(
                  labelText: 'Obtained Marks',
                  hintText: 'Enter Obtained Marks',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add Assessment')),
          ],
        );
      },
    );
    if (ok != true) return;
    final total = double.tryParse(totalCtrl.text.trim());
    final obt = double.tryParse(obtCtrl.text.trim());
    if (total == null || total <= 0 || obt == null || obt < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid marks')));
      return;
    }
    await store!.addAssessment(
      course!.id,
      name: type,
      type: type,
      obtained: obt,
      total: total,
    );
    await _refresh();
  }

  Future<void> _editWeights() async {
    if (store == null || course == null) return;
    final attrs = store!.attributes(course!.id);
    final ctrls = {
      for (final a in attrs) a.name: TextEditingController(text: '${a.value}')
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = AppScope.colorsOf(ctx);
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Course Attributes',
              style: display(c, size: 18), textAlign: TextAlign.center),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final a in attrs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: ctrls[a.name],
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration: InputDecoration(
                          labelText: '${a.name} weightage %',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        );
      },
    );
    if (ok != true) return;
    for (final a in attrs) {
      a.value = double.tryParse(ctrls[a.name]!.text.trim()) ?? 0;
      if (a.value < 0) a.value = 0;
    }
    await store!.saveAttributes(course!.id, attrs);
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
        title:
            Text(course?.name ?? 'Course', style: display(c, size: 18)),
        actions: [
          IconButton(
              tooltip: 'Edit weightages',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editWeights),
          IconButton(
              tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: store == null || course == null
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text('Grade :  ',
                                style: body(c, weight: FontWeight.w700)),
                            Text(course!.grade,
                                style: display(c, size: 20)),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                            'Percentage : ${course!.obtainedPercentage.toStringAsFixed(2)} / ${course!.totalPercentage.toStringAsFixed(2)}%',
                            style: body(c),
                          ),
                          Text(
                            'Credit Hours :  ${course!.creditHours}',
                            style: body(c),
                          ),
                          Text(
                            'Click on course to add assessment',
                            style: body(c,
                                size: 12,
                                color: c.tealInk.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Builder(builder: (_) {
                      final items = store!.assessments(course!.id);
                      final attrs = {
                        for (final a in store!.attributes(course!.id))
                          a.name: a.value
                      };
                      return Column(
                        children: [
                          for (final t in vaultAssessmentTypes)
                            _typeSection(c, t, items, attrs[t] ?? 0),
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

  Widget _typeSection(AppColors c, String type,
      List<VaultAssessment> all, double weight) {
    final items = all.where((e) => e.type == type).toList();
    double typeObt = 0;
    for (final a in items) {
      typeObt += a.scorePercent;
    }
    final avg = items.isEmpty ? 0 : typeObt / items.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: c.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(type,
                      style: body(c, weight: FontWeight.w700))),
              Text(avg.toStringAsFixed(0),
                  style: body(c, weight: FontWeight.w700)),
              const SizedBox(width: 12),
              Text(weight.toStringAsFixed(0),
                  style: body(c,
                      color: c.tealInk.withValues(alpha: 0.6))),
              IconButton(
                tooltip: 'Add $type',
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => _addAssessment(type),
              ),
            ],
          ),
          for (final a in items)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.cream2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name,
                            style: body(c, weight: FontWeight.w700)),
                        Text(
                          'Total Marks :  ${a.totalMarks}\nObtained Marks :  ${a.obtainedMarks}\nPercentage : ${a.scorePercent.toStringAsFixed(2)}%',
                          style: body(c, size: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete Assessment',
                    icon: Icon(Icons.delete_outline, color: c.clay),
                    onPressed: () async {
                      await store!
                          .deleteAssessment(course!.id, a.id);
                      await _refresh();
                    },
                  ),
                ],
              ),
            ),
          if (items.isEmpty)
            Text('No $type yet — tap + to add',
                style: body(c,
                    size: 12,
                    color: c.tealInk.withValues(alpha: 0.55))),
        ],
      ),
    );
  }
}
