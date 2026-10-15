import 'package:flutter_test/flutter_test.dart';
import 'package:ucp/gpa_vault/grading.dart';
import 'package:ucp/gpa_vault/models.dart';
import 'package:ucp/gpa_vault/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('vaultCalculateGpa matches f4/x.a vectors', () {
    final r1 = vaultCalculateGpa([
      const VaultGpaInput(grade: 'A', creditHours: 3),
      const VaultGpaInput(grade: 'B', creditHours: 3),
    ]);
    expect(r1.gpa, closeTo(3.5, 1e-9));
    expect(r1.totalCreditHours, 6);

    // Select/empty and 0 credit skipped like smali
    final r2 = vaultCalculateGpa([
      const VaultGpaInput(grade: 'Select', creditHours: 3),
      const VaultGpaInput(grade: '', creditHours: 3),
      const VaultGpaInput(grade: 'A', creditHours: 0),
      const VaultGpaInput(grade: 'F', creditHours: 3),
    ]);
    expect(r2.gpa, 0);
    expect(r2.totalCreditHours, 3);

    // Full scale spot checks
    expect(vaultPointsForGrade('A-'), 3.67);
    expect(vaultPointsForGrade('D+'), 1.33);
    expect(vaultPointsForGrade('F'), 0.0);
  });

  test('grade bands match GradingSchemeActivity', () {
    expect(vaultGradeForPercent(86), 'A');
    expect(vaultGradeForPercent(82), 'A-');
    expect(vaultGradeForPercent(78), 'B+');
    expect(vaultGradeForPercent(74), 'B');
    expect(vaultGradeForPercent(70), 'B-');
    expect(vaultGradeForPercent(66), 'C+');
    expect(vaultGradeForPercent(62), 'C');
    expect(vaultGradeForPercent(58), 'C-');
    expect(vaultGradeForPercent(54), 'D+');
    expect(vaultGradeForPercent(50), 'D');
    expect(vaultGradeForPercent(49.9), 'F');
  });

  test('blend matches f4/b0 rounding', () {
    expect(
        vaultBlendCgpa(prevCgpa: 3.0, prevCr: 30, gpa: 4.0, credits: 15),
        3.33);
    expect(vaultBlendCgpa(prevCgpa: 5, prevCr: 10, gpa: 4, credits: 10),
        isNull);
  });

  test('refreshCourse + refreshSemester chain', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = VaultStore(prefs);
    final sem = await store.addSemester('Fall 2025');
    final course = await store.addCourse(sem.id,
        name: 'CS101', creditHours: 3);
    await store.saveAttributes(course.id, [
      for (final t in vaultAssessmentTypes)
        VaultCourseAttribute(
            name: t, value: t == 'Quiz' ? 100 : 0),
    ]);
    await store.addAssessment(course.id,
        name: 'Quiz', type: 'Quiz', obtained: 86, total: 100);
    var items = store.assessments(course.id);
    var attrs = store.attributes(course.id);
    var c = store.refreshCourse(course, items, attrs);
    expect(c.obtainedPercentage, closeTo(86, 1e-9));
    expect(c.grade, 'A');
    await store.updateCourse(sem.id, c);
    await store.persistSemesterRefresh(sem, store.courses(sem.id));
    final updated =
        store.semesters().firstWhere((e) => e.id == sem.id);
    expect(updated.sGpa, closeTo(4.0, 1e-9));
    expect(updated.creditHours, 3);
  });
}
