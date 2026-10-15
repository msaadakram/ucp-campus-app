// Exact port of CourseVault grading math.
// Sources: f4/x.smali `a(ArrayList)->GpaResult`, GradingSchemeActivity
// hardcoded rows, arrays.xml `grades` + `creditHours`.

/// Grade -> quality points. Matches f4/x.smali packed-switch.
/// F and unknown fall through to 0.0 (v1=0 default).
const Map<String, double> vaultGradePoints = {
  'A': 4.0,
  'A-': 3.67,
  'B+': 3.33,
  'B': 3.0,
  'B-': 2.67,
  'C+': 2.33,
  'C': 2.0,
  'C-': 1.67,
  'D+': 1.33,
  'D': 1.0,
  'F': 0.0,
};

/// Dropdown order from arrays.xml `grades`.
const List<String> vaultGrades = [
  'A',
  'A-',
  'B+',
  'B',
  'B-',
  'C+',
  'C',
  'C-',
  'D+',
  'D',
  'F',
];

/// Dropdown values from arrays.xml `creditHours`.
const List<int> vaultCreditOptions = [1, 2, 3, 4];

/// Absolute % -> letter. Matches GradingSchemeActivity rows:
/// 86-100 A, 82-85 A-, 78-81 B+, 74-77 B, 70-73 B-,
/// 66-69 C+, 62-65 C, 58-61 C-, 54-57 D+, 50-53 D, else F.
String vaultGradeForPercent(double percent) {
  if (percent >= 86) return 'A';
  if (percent >= 82) return 'A-';
  if (percent >= 78) return 'B+';
  if (percent >= 74) return 'B';
  if (percent >= 70) return 'B-';
  if (percent >= 66) return 'C+';
  if (percent >= 62) return 'C';
  if (percent >= 58) return 'C-';
  if (percent >= 54) return 'D+';
  if (percent >= 50) return 'D';
  return 'F';
}

double vaultPointsForGrade(String grade) => vaultGradePoints[grade] ?? 0.0;

/// Minimal input for GPA math — mirrors Course + CourseForGPA handling
/// in f4/x.a (both expose getGrade()/getCreditHours()).
class VaultGpaInput {
  final String grade;
  final int creditHours;
  const VaultGpaInput({required this.grade, required this.creditHours});
}

class VaultGpaResult {
  final double gpa;
  final int totalCreditHours;
  const VaultGpaResult({required this.gpa, required this.totalCreditHours});
}

/// Direct port of f4/x.a:
/// skip empty/"Select" grade or credit<=0, sum points*credit / sum credit.
VaultGpaResult vaultCalculateGpa(List<VaultGpaInput> rows) {
  double totalPoints = 0;
  int totalCredits = 0;
  for (final r in rows) {
    final g = r.grade.trim();
    if (g.isEmpty || g == 'Select') continue;
    if (r.creditHours <= 0) continue;
    totalPoints += vaultPointsForGrade(g) * r.creditHours;
    totalCredits += r.creditHours;
  }
  if (totalCredits <= 0) return const VaultGpaResult(gpa: 0, totalCreditHours: 0);
  return VaultGpaResult(
    gpa: totalPoints / totalCredits,
    totalCreditHours: totalCredits,
  );
}

/// Blended CGPA from f4/b0 pswitch_1:
/// (prevCgpa*prevCr + gpa*credits)/(prevCr+credits), rounded to 2dp.
/// Returns null when inputs out of 0..4 range (caller shows
/// "New GPA must be between 0 and 4.0" /
/// "Previous CGPA must be between 0 and 4.0").
double? vaultBlendCgpa({
  required double prevCgpa,
  required int prevCr,
  required double gpa,
  required int credits,
}) {
  if (prevCgpa < 0 || prevCgpa > 4) return null;
  if (gpa < 0 || gpa > 4) return null;
  if (prevCr < 0 || credits < 0) return null;
  final total = prevCr + credits;
  if (total <= 0) return 0;
  final blended = (prevCgpa * prevCr + gpa * credits) / total;
  return (blended * 100).round() / 100;
}

double vaultRound2(double v) => (v * 100).round() / 100;

String vaultFormat2(double v) => v.toStringAsFixed(2);

/// Assessment types from arrays.xml `assessment_types`.
/// Order kept identical for section headers.
const List<String> vaultAssessmentTypes = [
  'Quiz',
  'Assignment',
  'Mid Term',
  'Final Term',
  'Cp',
  'Lab',
  'Project',
  'Presentation',
];
