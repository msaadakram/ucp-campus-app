// Data models mirroring com.app.foit.models.* (smali).

class VaultSemester {
  final String id;
  String name;
  double? sGpa;
  int creditHours;
  int timestamp;
  VaultSemester({
    required this.id,
    required this.name,
    this.sGpa,
    this.creditHours = 0,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'semesterName': name,
        'sGPA': sGpa,
        'semesterCreditHours': creditHours,
        'timestamp': timestamp,
      };

  factory VaultSemester.fromJson(Map<String, dynamic> j) => VaultSemester(
        id: j['id'] as String,
        name: (j['semesterName'] ?? '') as String,
        sGpa: (j['sGPA'] as num?)?.toDouble(),
        creditHours: (j['semesterCreditHours'] as num? ?? 0).toInt(),
        timestamp: (j['timestamp'] as num? ?? 0).toInt(),
      );
}

class VaultCourse {
  final String id;
  String name;
  String category;
  int creditHours;
  String grade;
  double obtainedPercentage;
  double totalPercentage;
  int timestamp;
  VaultCourse({
    required this.id,
    required this.name,
    this.category = 'General',
    this.creditHours = 3,
    this.grade = '--',
    this.obtainedPercentage = 0,
    this.totalPercentage = 0,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseName': name,
        'courseCategory': category,
        'creditHours': creditHours,
        'grade': grade,
        'obtainedPercentage': obtainedPercentage,
        'totalPercentage': totalPercentage,
        'timestamp': timestamp,
      };

  factory VaultCourse.fromJson(Map<String, dynamic> j) => VaultCourse(
        id: j['id'] as String,
        name: (j['courseName'] ?? '') as String,
        category: (j['courseCategory'] ?? 'General') as String,
        creditHours: (j['creditHours'] as num? ?? 3).toInt(),
        grade: (j['grade'] ?? '--') as String,
        obtainedPercentage: (j['obtainedPercentage'] as num? ?? 0).toDouble(),
        totalPercentage: (j['totalPercentage'] as num? ?? 0).toDouble(),
        timestamp: (j['timestamp'] as num? ?? 0).toInt(),
      );
}

class VaultAssessment {
  final String id;
  String name;
  String type;
  double obtainedMarks;
  double totalMarks;
  double percentage;
  int timestamp;
  VaultAssessment({
    required this.id,
    required this.name,
    required this.type,
    this.obtainedMarks = 0,
    this.totalMarks = 100,
    double? percentage,
    int? timestamp,
  })  : percentage = percentage ??
            (totalMarks <= 0 ? 0 : obtainedMarks / totalMarks * 100),
        timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  /// Display % for item_assessment.xml percentage row.
  double get scorePercent =>
      totalMarks <= 0 ? 0 : obtainedMarks / totalMarks * 100;

  Map<String, dynamic> toJson() => {
        'id': id,
        'assessmentName': name,
        'type': type,
        'obtainedMarks': obtainedMarks,
        'totalMarks': totalMarks,
        'percentage': percentage,
        'timestamp': timestamp,
      };

  factory VaultAssessment.fromJson(Map<String, dynamic> j) =>
      VaultAssessment(
        id: j['id'] as String,
        name: (j['assessmentName'] ?? '') as String,
        type: (j['type'] ?? 'Quiz') as String,
        obtainedMarks: (j['obtainedMarks'] as num? ?? 0).toDouble(),
        totalMarks: (j['totalMarks'] as num? ?? 100).toDouble(),
        percentage: (j['percentage'] as num?)?.toDouble(),
        timestamp: (j['timestamp'] as num? ?? 0).toInt(),
      );
}

/// Per-type weight, e.g. Quiz -> 10.0 meaning 10%.
/// Missing types default to 0.0 like f4/s1 goto_1.
class VaultCourseAttribute {
  final String name;
  double value;
  VaultCourseAttribute({required this.name, this.value = 0});

  Map<String, dynamic> toJson() => {'name': name, 'value': value};

  factory VaultCourseAttribute.fromJson(Map<String, dynamic> j) =>
      VaultCourseAttribute(
        name: j['name'] as String,
        value: (j['value'] as num? ?? 0).toDouble(),
      );
}

/// Static grading-scheme table from GradingSchemeActivity.
class VaultGradeRow {
  final String letter;
  final String points;
  final String marks;
  const VaultGradeRow(this.letter, this.points, this.marks);
}

const List<VaultGradeRow> vaultGradingScheme = [
  VaultGradeRow('A', '4.0', '86-100%'),
  VaultGradeRow('A-', '3.67', '82-85%'),
  VaultGradeRow('B+', '3.33', '78-81%'),
  VaultGradeRow('B', '3.00', '74-77%'),
  VaultGradeRow('B-', '2.67', '70-73%'),
  VaultGradeRow('C+', '2.33', '66-69%'),
  VaultGradeRow('C', '2.00', '62-65%'),
  VaultGradeRow('C-', '1.67', '58-61%'),
  VaultGradeRow('D+', '1.33', '54-57%'),
  VaultGradeRow('D', '1.00', '50-53%'),
  VaultGradeRow('F', '0.00', 'Below 50%'),
  VaultGradeRow('W', '---', 'Withdrawal'),
  VaultGradeRow('I', '', 'Incomplete'),
  VaultGradeRow('N', '', 'Continued'),
  VaultGradeRow('S', '', 'Satisfactory'),
  VaultGradeRow('US', '', 'Unsatisfactory'),
];
