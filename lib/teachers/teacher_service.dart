import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'teacher_models.dart';

/// Backend contract for teacher reviews. UI only speaks this interface,
/// so Node/Supabase, fake seed, and unconfigured modes share every pixel.
abstract class TeacherService {
  Future<List<Teacher>> fetchTeachers({String dept = 'all', String query = ''});
  Future<(Teacher, List<TeacherReview>)> fetchDetail(String slug);
  Future<TeacherReview> submitRating({
    required String slug,
    required int grading,
    required int leniency,
    required int subject,
    required String comment,
  });
  Stream<void> get updates;
  bool get supportsRealtime;
  Future<void> ensureRealtime(Future<void> Function() onEvent);
  void dispose();
}

class TeacherException implements Exception {
  final String message;
  TeacherException(this.message);
  @override
  String toString() => 'TeacherException: $message';
}

/// Live backend via Node API (`backend/src/routes/teachers.js`), which
/// verifies `x-ucp-session` against Odoo and stores in Supabase tables
/// `teachers` + `teacher_reviews` (see `supabase/teachers_schema.sql`).
class NodeTeacherService extends TeacherService {
  final String baseUrl;
  final String? Function() sessionOf;
  final http.Client _client;
  static const requestTimeout = Duration(seconds: 20);

  final _updates = StreamController<void>.broadcast();

  NodeTeacherService({
    required this.baseUrl,
    required this.sessionOf,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    final sid = sessionOf();
    if (sid != null && sid.isNotEmpty) headers['x-ucp-session'] = sid;
    return headers;
  }

  Never _throwFor(http.Response res) {
    String message = 'request failed (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] is String) {
        message = body['error'] as String;
      }
    } catch (_) {}
    throw TeacherException(message);
  }

  @override
  Stream<void> get updates => _updates.stream;

  @override
  bool get supportsRealtime => false;

  @override
  Future<void> ensureRealtime(Future<void> Function() onEvent) async {}

  @override
  Future<List<Teacher>> fetchTeachers(
      {String dept = 'all', String query = ''}) async {
    final params = <String, String>{'limit': '200'};
    if (dept != 'all' && dept.isNotEmpty) params['dept'] = dept;
    if (query.trim().isNotEmpty) params['q'] = query.trim();
    final uri =
        Uri.parse('$baseUrl/api/teachers').replace(queryParameters: params);
    final res =
        await _client.get(uri, headers: _headers()).timeout(requestTimeout);
    if (res.statusCode != 200) _throwFor(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['teachers'] as List?) ?? [];
    return [
      for (final t in items.whereType<Map>())
        Teacher.fromJson(Map<String, dynamic>.from(t))
    ];
  }

  @override
  Future<(Teacher, List<TeacherReview>)> fetchDetail(String slug) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/api/teachers/$slug'), headers: _headers())
        .timeout(requestTimeout);
    if (res.statusCode != 200) _throwFor(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final teacher =
        Teacher.fromJson(Map<String, dynamic>.from(body['teacher'] as Map));
    final items = (body['reviews'] as List?) ?? [];
    final reviews = [
      for (final r in items.whereType<Map>())
        TeacherReview.fromJson(Map<String, dynamic>.from(r))
    ];
    return (teacher, reviews);
  }

  @override
  Future<TeacherReview> submitRating({
    required String slug,
    required int grading,
    required int leniency,
    required int subject,
    required String comment,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$baseUrl/api/teachers/$slug/rate'),
          headers: _headers(json: true),
          body: jsonEncode({
            'grading': grading,
            'leniency': leniency,
            'subject': subject,
            'comment': comment,
          }),
        )
        .timeout(requestTimeout);
    if (res.statusCode != 200 && res.statusCode != 201) _throwFor(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return TeacherReview.fromJson(
        Map<String, dynamic>.from(body['review'] as Map));
  }

  @override
  void dispose() {
    if (!_updates.isClosed) _updates.close();
    _client.close();
  }
}

/// Offline/test fallback: bundled top teachers from the parsed
/// `teachers.json` (full 706 live in Supabase after import).
class FakeTeacherService extends TeacherService {
  final List<Teacher> _teachers;
  final Map<String, List<TeacherReview>> _reviews;
  final _updates = StreamController<void>.broadcast();

  FakeTeacherService()
      : _teachers = _seedTeachers(),
        _reviews = _seedReviews();

  static List<Teacher> _seedTeachers() => const [
        Teacher(
          slug: 'muhammad-zulkifl-hasan',
          name: 'Muhammad Zulkifl Hasan',
          designation: 'Principal Lecturer',
          departmentCode: 'foit',
          departmentName: 'Faculty of Information and Technology',
          departmentId: 3,
          imageUrl:
              'https://ucp.edu.pk/wp-content/uploads/2022/10/Muhammad-Zulkifl-Hasan.jpg',
          overallRating: 4.9,
          reviewCount: 174,
          gradingPct: 98,
          leniencyPct: 99,
          subjectPct: 99,
          avgGrading: 4.92,
          avgLeniency: 4.94,
          avgSubject: 4.95,
        ),
        Teacher(
          slug: 'misbah-naz',
          name: 'Misbah Naz',
          designation: 'Senior Lecturer',
          departmentCode: 'foit',
          departmentName: 'Faculty of Information and Technology',
          departmentId: 3,
          imageUrl:
              'https://ucp.edu.pk/wp-content/uploads/2022/11/Ms.-Misbah-Naz.jpg',
          overallRating: 4.8,
          reviewCount: 60,
          gradingPct: 96,
          leniencyPct: 97,
          subjectPct: 97,
        ),
        Teacher(
          slug: 'usman-aamer',
          name: 'Usman Aamer',
          designation: 'Lecturer',
          departmentCode: 'foit',
          departmentName: 'Faculty of Information and Technology',
          departmentId: 3,
          imageUrl:
              'https://ucp.edu.pk/wp-content/uploads/2022/04/USMAN-AAMER.jpg',
          overallRating: 4.7,
          reviewCount: 50,
          gradingPct: 94,
          leniencyPct: 94,
          subjectPct: 94,
        ),
      ];

  static Map<String, List<TeacherReview>> _seedReviews() => {
        'usman-aamer': [
          TeacherReview(
            id: 1,
            teacherSlug: 'usman-aamer',
            studentName: 'Coco Luna',
            comment: 'Great Sir, one of the best',
            ratingGrading: 5,
            ratingLeniency: 5,
            ratingSubject: 5,
          ),
          TeacherReview(
            id: 2,
            teacherSlug: 'usman-aamer',
            studentName: 'Momo Tori',
            comment: 'GOAT',
            ratingGrading: 3,
            ratingLeniency: 3,
            ratingSubject: 5,
          ),
        ],
      };

  @override
  Future<List<Teacher>> fetchTeachers(
      {String dept = 'all', String query = ''}) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _teachers
        .where((t) => dept == 'all' || t.departmentCode == dept)
        .where((t) =>
            query.trim().isEmpty ||
            t.name.toLowerCase().contains(query.trim().toLowerCase()))
        .toList();
  }

  @override
  Future<(Teacher, List<TeacherReview>)> fetchDetail(String slug) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final t = _teachers.firstWhere((e) => e.slug == slug,
        orElse: () => _teachers.first);
    return (t, List<TeacherReview>.of(_reviews[slug] ?? const []));
  }

  @override
  Future<TeacherReview> submitRating({
    required String slug,
    required int grading,
    required int leniency,
    required int subject,
    required String comment,
  }) async {
    final review = TeacherReview(
      id: DateTime.now().millisecondsSinceEpoch,
      teacherSlug: slug,
      studentName: 'you',
      comment: comment,
      ratingGrading: grading,
      ratingLeniency: leniency,
      ratingSubject: subject,
    );
    (_reviews[slug] ??= []).insert(0, review);
    if (!_updates.isClosed) _updates.add(null);
    return review;
  }

  @override
  Stream<void> get updates => _updates.stream;

  @override
  bool get supportsRealtime => false;

  @override
  Future<void> ensureRealtime(Future<void> Function() onEvent) async {}

  @override
  void dispose() {
    if (!_updates.isClosed) _updates.close();
  }
}
