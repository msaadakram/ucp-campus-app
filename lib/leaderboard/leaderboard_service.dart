import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../community/backend_config.dart';

/// Live class leaderboard over the extension backend
/// (`GET /api/ext/leaderboard`, `GET /api/ext/timetable`), mirroring the
/// server contract exactly:
///
/// * Ranking formula: entries arrive sorted by `overallPercentage`
///   descending — rank is list position (1-based).
/// * Privacy: students who opted out are served as `Anonymous` with
///   `studentId: 'hidden'` and no photo (server-enforced; we just render).
/// * Credits: passing [studentId] scopes the board to that student's
///   class group AND costs 1 credit per view — the remaining balance
///   comes back as `remainingCredits`. Out of credits → [NoCredits].
class LeaderboardEntry {
  final int rank;
  final String studentName;
  final String studentId;
  final String imageUrl;
  final double percentage;
  final String grade;
  final bool isMe;

  const LeaderboardEntry({
    required this.rank,
    required this.studentName,
    required this.studentId,
    required this.imageUrl,
    required this.percentage,
    required this.grade,
    this.isMe = false,
  });

  bool get isAnonymous => studentName.isEmpty || studentName == 'Anonymous';
}

class LeaderboardResult {
  final List<LeaderboardEntry> entries;
  final int? remainingCredits;
  /// True when the view was free (app client, or nobody else published
  /// marks yet). The app never spends the extension's credits.
  final bool free;
  const LeaderboardResult({
    required this.entries,
    this.remainingCredits,
    this.free = false,
  });
}

/// Privacy state of a student on the leaderboards.
class LeaderboardPrivacy {
  final bool hideName;
  final bool hidePhoto;
  const LeaderboardPrivacy({
    this.hideName = false,
    this.hidePhoto = false,
  });
}

/// Thrown when the student has no credits left (server 402 NO_CREDITS).
class NoCredits implements Exception {
  const NoCredits();
  @override
  String toString() => 'NoCredits';
}

class LeaderboardException implements Exception {
  final String message;
  LeaderboardException(this.message);
  @override
  String toString() => 'LeaderboardException: $message';
}

/// Roster verification for a course section.
class LeaderboardRoster {
  final int rosterSize;
  final int classmates;
  final bool youAreIn;
  final List<String> sections;
  const LeaderboardRoster({
    required this.rosterSize,
    required this.classmates,
    required this.youAreIn,
    this.sections = const [],
  });
}

/// UI speaks only to this interface; [NodeLeaderboardService] is the
/// live backend, tests inject fakes (the house service pattern).
abstract class LeaderboardService {
  /// Canonical ext course names for [studentId]'s own timetable rows
  /// (all courses when the id is unknown/empty).
  Future<List<String>> fetchCourses({String? studentId});

  /// Class roster for a course (verification: who shares the section).
  Future<LeaderboardRoster> fetchRoster({
    required String courseName,
    String? studentId,
    String? courseCode,
  });

  /// Publishes the student's own timetable so the server can build the
  /// class roster (app-only users join the same groups as extension
  /// users). Rows: {day, time, courseName, teacher, room}.
  Future<void> syncTimetable({
    required String studentId,
    required List<Map<String, String>> rows,
  });

  /// Publishes the student's own gradebook so their row exists on the
  /// board even without the extension.
  Future<void> syncGrades({
    required String studentId,
    required String studentName,
    required String courseName,
    required String courseCode,
    required double overallPercentage,
    required String grade,
    required List<Map<String, dynamic>> assessments,
  });
  Future<LeaderboardResult> fetchLeaderboard({
    required String courseName,
    String? studentId,
    String? courseCode,
  });

  /// Privacy settings — shared with the extension: hiding your name here
  /// hides it everywhere (the server masks rows for every client).
  Future<LeaderboardPrivacy> fetchPrivacy(String studentId);

  /// Stores the privacy settings on the server (so the extension and the
  /// app always agree).
  Future<LeaderboardPrivacy> savePrivacy(
    String studentId, {
    required bool hideName,
    required bool hidePhoto,
  });

  void dispose();
}

class NodeLeaderboardService extends LeaderboardService {
  final http.Client _client;
  final String _apiKey;
  static const _timeout = Duration(seconds: 20);

  /// Live instances in this process. The app must keep this at ONE: each
  /// instance owns a socket pool, and building one per rebuild used to
  /// leak a connection pool every time the screen repainted.
  static int instances = 0;

  NodeLeaderboardService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = (apiKey ?? extApiKey).trim() {
    instances++;
  }

  Map<String, String> get _headers => {'x-api-key': _apiKey};

  Never _throwFor(http.Response res) {
    if (res.statusCode == 402) throw const NoCredits();
    String? serverError;
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] is String) {
        serverError = body['error'] as String;
      }
    } catch (_) {}
    if (res.statusCode == 404) {
      throw LeaderboardException(
          'Leaderboard is not deployed on this backend.');
    }
    throw LeaderboardException(
        serverError ?? 'Leaderboard unavailable (${res.statusCode})');
  }

  @override
  Future<List<String>> fetchCourses({String? studentId}) async {
    // Ask for THIS student's rows only — the unscoped endpoint returns
    // the whole school's catalogue.
    final sid = (studentId ?? '').trim();
    final res = await _client
        .get(
          Uri.parse('$nodeApiUrl/api/ext/timetable').replace(
            queryParameters: sid.isEmpty ? null : {'studentId': sid},
          ),
          headers: _headers,
        )
        .timeout(_timeout);
    if (res.statusCode != 200) _throwFor(res);
    final rows = jsonDecode(res.body);
    if (rows is! List) return const [];
    final mine = <Map>[];
    for (final r in rows) {
      if (r is Map) mine.add(r);
    }
    // Scope to the student's own classes when their rows exist;
    // otherwise the whole catalogue (first-seen order).
    final scoped = sid.isEmpty
        ? mine
        : mine
            .where((r) => '${r['studentID'] ?? ''}'.trim() == sid)
            .toList();
    final source = scoped.isNotEmpty ? scoped : mine;
    final seen = <String>{};
    final out = <String>[];
    for (final r in source) {
      final name = '${r['courseName'] ?? ''}'.trim();
      // Skip "Room: A-102 (Makeup Class…)" pseudo-entries.
      if (name.isEmpty ||
          name.toLowerCase().startsWith('room:') ||
          !seen.add(name)) {
        continue;
      }
      out.add(name);
    }
    return out;
  }

  @override
  Future<LeaderboardRoster> fetchRoster({
    required String courseName,
    String? studentId,
    String? courseCode,
  }) async {
    final params = <String, String>{
      'courseName': courseName,
      // The app is a first-party, free client: the server never spends
      // the extension's credits for it.
      'source': 'app',
    };
    final sid = (studentId ?? '').trim();
    if (sid.isNotEmpty) params['studentId'] = sid;
    final code = (courseCode ?? '').trim();
    if (code.isNotEmpty) params['courseCode'] = code;
    final res = await _client
        .get(
          Uri.parse('$nodeApiUrl/api/ext/roster').replace(
            queryParameters: params,
          ),
          headers: _headers,
        )
        .timeout(_timeout);
    if (res.statusCode != 200) _throwFor(res);
    final body = jsonDecode(res.body);
    if (body is! Map) {
      throw LeaderboardException('Malformed roster data.');
    }
    return LeaderboardRoster(
      rosterSize: _asInt(body['rosterSize']),
      classmates: _asInt(body['classmates']),
      youAreIn: body['youAreIn'] == true,
      sections: [
        for (final s in (body['sections'] as List? ?? const [])) '$s',
      ],
    );
  }

  @override
  Future<void> syncTimetable({
    required String studentId,
    required List<Map<String, String>> rows,
  }) async {
    if (studentId.trim().isEmpty || rows.isEmpty) return;
    final res = await _client
        .post(
          Uri.parse('$nodeApiUrl/api/ext/timetable/save'),
          headers: {
            ..._headers,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'studentID': studentId, 'timetable': rows}),
        )
        .timeout(_timeout);
    // A rejected sync must never break the leaderboard UI.
    if (res.statusCode >= 400) {
      throw LeaderboardException('Timetable sync failed (${res.statusCode}).');
    }
  }

  @override
  Future<void> syncGrades({
    required String studentId,
    required String studentName,
    required String courseName,
    required String courseCode,
    required double overallPercentage,
    required String grade,
    required List<Map<String, dynamic>> assessments,
  }) async {
    if (studentId.trim().isEmpty) return;
    final res = await _client
        .post(
          Uri.parse('$nodeApiUrl/api/ext/grades/save'),
          headers: {
            ..._headers,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'studentID': studentId,
            'studentName': studentName,
            'courseName': courseName,
            'courseCode': courseCode,
            'overallPercentage': overallPercentage,
            'grade': grade,
            'assessments': assessments,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode >= 400) {
      throw LeaderboardException('Grade sync failed (${res.statusCode}).');
    }
  }

  @override
  Future<LeaderboardResult> fetchLeaderboard({
    required String courseName,
    String? studentId,
    String? courseCode,
  }) async {
    final params = <String, String>{
      'courseName': courseName,
      // Free for the app (see the server's credit policy).
      'source': 'app',
    };
    final sid = (studentId ?? '').trim();
    if (sid.isNotEmpty) params['studentId'] = sid;
    final code = (courseCode ?? '').trim();
    if (code.isNotEmpty) params['courseCode'] = code;
    final res = await _client
        .get(
          Uri.parse('$nodeApiUrl/api/ext/leaderboard').replace(
            queryParameters: params,
          ),
          // The ext gate requires this on EVERY call — without it the
          // server answers 401 EXT_KEY_REQUIRED.
          headers: _headers,
        )
        .timeout(_timeout);
    if (res.statusCode != 200) _throwFor(res);
    final body = jsonDecode(res.body);
    if (body is! Map) throw LeaderboardException('Malformed leaderboard data.');
    final rows = (body['grades'] as List?) ?? [];
    var rank = 0;
    final entries = <LeaderboardEntry>[];
    for (final r in rows) {
      if (r is! Map) continue;
      rank++;
      final id = '${r['studentId'] ?? ''}';
      entries.add(LeaderboardEntry(
        rank: rank,
        studentName: '${r['studentName'] ?? ''}',
        studentId: id,
        imageUrl: '${r['studentImage'] ?? ''}',
        percentage: _asDouble(r['overallPercentage']),
        grade: '${r['grade'] ?? ''}',
        // Hidden students (privacy on) serve 'hidden' and never match.
        isMe: sid.isNotEmpty && id == sid,
      ));
    }
    final credits = body['remainingCredits'];
    return LeaderboardResult(
      entries: entries,
      remainingCredits:
          credits == null ? null : _asInt(credits),
      free: body['free'] == true,
    );
  }

  @override
  Future<LeaderboardPrivacy> fetchPrivacy(String studentId) async {
    final res = await _client
        .get(
          Uri.parse(
            '$nodeApiUrl/api/ext/privacy/${Uri.encodeComponent(studentId)}',
          ),
          headers: _headers,
        )
        .timeout(_timeout);
    if (res.statusCode != 200) _throwFor(res);
    final body = jsonDecode(res.body);
    if (body is! Map) {
      throw LeaderboardException('Malformed privacy data.');
    }
    return LeaderboardPrivacy(
      hideName: body['hideName'] == true,
      hidePhoto: body['hidePhoto'] == true,
    );
  }

  @override
  Future<LeaderboardPrivacy> savePrivacy(
    String studentId, {
    required bool hideName,
    required bool hidePhoto,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$nodeApiUrl/api/ext/privacy'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'studentId': studentId,
            'hideName': hideName,
            'hidePhoto': hidePhoto,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) _throwFor(res);
    final body = jsonDecode(res.body);
    if (body is! Map) {
      throw LeaderboardException('Malformed privacy data.');
    }
    return LeaderboardPrivacy(
      hideName: body['hideName'] == true,
      hidePhoto: body['hidePhoto'] == true,
    );
  }

  @override
  void dispose() => _client.close();
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) {
    return double.tryParse(v.replaceAll('%', '').trim()) ?? 0;
  }
  return 0;
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? 0;
  return 0;
}
