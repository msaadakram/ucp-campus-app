// Local persistence mirroring CourseVault Firebase layout:
// Users/{uid}/Semesters, Courses, Assessments + CourseAttributes.
// Phase 1 is on-device via SharedPreferences; Phase 4 can swap this
// class for a Firebase Database adapter with identical method names.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'grading.dart';
import 'models.dart';

const _kSemesters = 'vault_semesters';
String _coursesKey(String semId) => 'vault_courses_$semId';
String _assessKey(String courseId) => 'vault_assess_$courseId';
String _attrsKey(String courseId) => 'vault_attrs_$courseId';

class VaultStore {
  final SharedPreferences prefs;
  final Uuid _uuid = const Uuid();
  VaultStore(this.prefs);

  static Future<VaultStore> load() async =>
      VaultStore(await SharedPreferences.getInstance());

  String newId() => _uuid.v4();

  List<VaultSemester> semesters() {
    final raw = prefs.getString(_kSemesters);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => VaultSemester.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveSemesters(List<VaultSemester> items) =>
      prefs.setString(_kSemesters,
          jsonEncode(items.map((e) => e.toJson()).toList()));

  Future<VaultSemester> addSemester(String name) async {
    final items = semesters();
    final s = VaultSemester(id: newId(), name: name.trim());
    items.add(s);
    await _saveSemesters(items);
    return s;
  }

  Future<void> deleteSemester(String id) async {
    final items = semesters()..removeWhere((e) => e.id == id);
    await _saveSemesters(items);
    await prefs.remove(_coursesKey(id));
  }

  List<VaultCourse> courses(String semesterId) {
    final raw = prefs.getString(_coursesKey(semesterId));
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => VaultCourse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveCourses(String semesterId, List<VaultCourse> items) =>
      prefs.setString(_coursesKey(semesterId),
          jsonEncode(items.map((e) => e.toJson()).toList()));

  Future<VaultCourse> addCourse(
    String semesterId, {
    required String name,
    String category = 'General',
    int creditHours = 3,
  }) async {
    final items = courses(semesterId);
    final c = VaultCourse(
      id: newId(),
      name: name.trim(),
      category: category,
      creditHours: creditHours,
    );
    items.add(c);
    await _saveCourses(semesterId, items);
    return c;
  }

  Future<void> updateCourse(String semesterId, VaultCourse updated) async {
    final items = courses(semesterId);
    final i = items.indexWhere((e) => e.id == updated.id);
    if (i >= 0) {
      items[i] = updated;
      await _saveCourses(semesterId, items);
    }
  }

  Future<void> deleteCourse(String semesterId, String courseId) async {
    final items = courses(semesterId)..removeWhere((e) => e.id == courseId);
    await _saveCourses(semesterId, items);
    await prefs.remove(_assessKey(courseId));
    await prefs.remove(_attrsKey(courseId));
  }

  List<VaultAssessment> assessments(String courseId) {
    final raw = prefs.getString(_assessKey(courseId));
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => VaultAssessment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveAssessments(
          String courseId, List<VaultAssessment> items) =>
      prefs.setString(_assessKey(courseId),
          jsonEncode(items.map((e) => e.toJson()).toList()));

  Future<VaultAssessment> addAssessment(
    String courseId, {
    required String name,
    required String type,
    required double obtained,
    required double total,
  }) async {
    final items = assessments(courseId);
    final a = VaultAssessment(
      id: newId(),
      name: name.trim().isEmpty ? type : name.trim(),
      type: type,
      obtainedMarks: obtained,
      totalMarks: total,
    );
    items.add(a);
    await _saveAssessments(courseId, items);
    return a;
  }

  Future<void> deleteAssessment(String courseId, String assessmentId) async {
    final items = assessments(courseId)
      ..removeWhere((e) => e.id == assessmentId);
    await _saveAssessments(courseId, items);
  }

  List<VaultCourseAttribute> attributes(String courseId) {
    final raw = prefs.getString(_attrsKey(courseId));
    if (raw == null || raw.isEmpty) {
      return [
        for (final t in vaultAssessmentTypes)
          VaultCourseAttribute(name: t, value: 0),
      ];
    }
    final list = jsonDecode(raw) as List;
    final existing = <String, VaultCourseAttribute>{};
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      existing[m['name'] as String] = VaultCourseAttribute.fromJson(m);
    }
    // Same as f4/s1: backfill missing types with 0.
    return [
      for (final t in vaultAssessmentTypes)
        existing[t] ?? VaultCourseAttribute(name: t, value: 0),
    ];
  }

  Future<void> saveAttributes(
          String courseId, List<VaultCourseAttribute> attrs) =>
      prefs.setString(_attrsKey(courseId),
          jsonEncode(attrs.map((e) => e.toJson()).toList()));

  /// Recompute Course.obtained/total/grade from assessments + weights.
  /// weight of a type is split equally across its assessments.
  /// Falls back to plain average when all weights are 0.
  VaultCourse refreshCourse(
    VaultCourse course,
    List<VaultAssessment> items,
    List<VaultCourseAttribute> attrs,
  ) {
    final weights = {for (final a in attrs) a.name: a.value};
    final totalWeight = weights.values.fold(0.0, (s, v) => s + v);
    double obtained = 0;
    if (totalWeight <= 0) {
      double oSum = 0, tSum = 0;
      for (final a in items) {
        oSum += a.obtainedMarks;
        tSum += a.totalMarks;
      }
      obtained = tSum <= 0 ? 0 : oSum / tSum * 100;
      course
        ..obtainedPercentage = vaultRound2(obtained)
        ..totalPercentage = 100
        ..grade = vaultGradeForPercent(obtained);
      return course;
    }
    final byType = <String, List<VaultAssessment>>{};
    for (final a in items) {
      byType.putIfAbsent(a.type, () => []).add(a);
    }
    for (final entry in byType.entries) {
      final w = weights[entry.key] ?? 0;
      if (w <= 0) continue;
      final perItem = w / entry.value.length;
      for (final a in entry.value) {
        if (a.totalMarks <= 0) continue;
        obtained += a.obtainedMarks / a.totalMarks * perItem;
      }
    }
    course
      ..obtainedPercentage = vaultRound2(obtained)
      ..totalPercentage = vaultRound2(totalWeight)
      ..grade = vaultGradeForPercent(obtained);
    return course;
  }

  /// Recompute Semester sGPA/credits via vaultCalculateGpa over its courses.
  VaultSemester refreshSemester(
    VaultSemester semester,
    List<VaultCourse> items,
  ) {
    final res = vaultCalculateGpa([
      for (final c in items)
        VaultGpaInput(grade: c.grade, creditHours: c.creditHours),
    ]);
    // vaultCalculateGpa skips "--"/empty like f4/x.a skips empty grades.
    if (res.totalCreditHours <= 0) {
      semester
        ..sGpa = null
        ..creditHours = 0;
    } else {
      semester
        ..sGpa = vaultRound2(res.gpa)
        ..creditHours = res.totalCreditHours;
    }
    return semester;
  }

  Future<VaultSemester> persistSemesterRefresh(
    VaultSemester semester,
    List<VaultCourse> items,
  ) async {
    final all = semesters();
    final i = all.indexWhere((e) => e.id == semester.id);
    refreshSemester(semester, items);
    if (i >= 0) {
      all[i] = semester;
      await _saveSemesters(all);
    }
    return semester;
  }
}
