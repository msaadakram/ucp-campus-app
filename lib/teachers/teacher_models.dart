// Teacher review models (StudentSpace parsed data + live Supabase ratings).
// Overall is 0..5. Separate dials are percentages (avg/5*100):
// gradingPct / leniencyPct / subjectPct, plus avg/5 values.

class Teacher {
  final String slug;
  final String name;
  final String designation;
  final String departmentCode;
  final String departmentName;
  final int departmentId;
  final String imageUrl;
  final String bio;
  final double overallRating;
  final int reviewCount;
  final int gradingPct;
  final int leniencyPct;
  final int subjectPct;
  final double avgGrading;
  final double avgLeniency;
  final double avgSubject;
  final String profileUrl;

  const Teacher({
    required this.slug,
    required this.name,
    this.designation = '',
    this.departmentCode = '',
    this.departmentName = '',
    this.departmentId = 0,
    this.imageUrl = '',
    this.bio = '',
    this.overallRating = 0,
    this.reviewCount = 0,
    this.gradingPct = 0,
    this.leniencyPct = 0,
    this.subjectPct = 0,
    this.avgGrading = 0,
    this.avgLeniency = 0,
    this.avgSubject = 0,
    this.profileUrl = '',
  });

  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  factory Teacher.fromJson(Map<String, dynamic> json) => Teacher(
        slug: '${json['slug'] ?? ''}',
        name: '${json['name'] ?? ''}',
        designation: '${json['designation'] ?? ''}',
        departmentCode: '${json['department_code'] ?? ''}',
        departmentName: '${json['department_name'] ?? ''}',
        departmentId: _asInt(json['department_id']),
        imageUrl: '${json['image_url'] ?? ''}',
        bio: '${json['bio'] ?? ''}',
        overallRating: _asDouble(json['overall_rating']),
        reviewCount: _asInt(json['review_count']),
        gradingPct: _asInt(json['grading_pct']),
        leniencyPct: _asInt(json['leniency_pct']),
        subjectPct: _asInt(json['subject_pct']),
        avgGrading: _asDouble(json['avg_grading']),
        avgLeniency: _asDouble(json['avg_leniency']),
        avgSubject: _asDouble(json['avg_subject']),
        profileUrl: '${json['profile_url'] ?? ''}',
      );
}

class TeacherReview {
  final int id;
  final String teacherSlug;
  final String studentName;
  final String comment;
  final int ratingGrading;
  final int ratingLeniency;
  final int ratingSubject;
  final bool isBlocked;
  final String createdAt;

  const TeacherReview({
    required this.id,
    required this.teacherSlug,
    this.studentName = 'student',
    this.comment = '',
    this.ratingGrading = 0,
    this.ratingLeniency = 0,
    this.ratingSubject = 0,
    this.isBlocked = false,
    this.createdAt = '',
  });

  double get average =>
      (ratingGrading + ratingLeniency + ratingSubject) / 3.0;

  factory TeacherReview.fromJson(Map<String, dynamic> json) => TeacherReview(
        id: Teacher._asInt(json['id']),
        teacherSlug: '${json['teacher_slug'] ?? ''}',
        studentName: '${json['student_name'] ?? 'student'}',
        comment: '${json['comment'] ?? ''}',
        ratingGrading: Teacher._asInt(json['rating_grading']),
        ratingLeniency: Teacher._asInt(json['rating_leniency']),
        ratingSubject: Teacher._asInt(json['rating_subject']),
        isBlocked: json['is_blocked'] == true,
        createdAt: '${json['created_at'] ?? ''}',
      );
}

/// Faculty filter list mirrors studentspace.site (9 faculties).
const teacherDepartments = [
  ('all', 'All faculties'),
  ('foit', 'Information Technology'),
  ('foe', 'Engineering'),
  ('fohs', 'Humanities & Social Sciences'),
  ('foll', 'Languages & Literature'),
  ('fol', 'Law'),
  ('foms', 'Management Sciences'),
  ('fomm', 'Media & Mass Comm'),
  ('fop', 'Pharmacy'),
  ('fost', 'Science & Technology'),
];
