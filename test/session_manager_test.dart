import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ucp/auth/odoo_api.dart';
import 'package:ucp/auth/session_manager.dart';

class _MemoryBackend implements SessionBackend {
  String? sid;
  String? email;
  int? savedAt;
  _MemoryBackend({this.sid, this.email, this.savedAt});

  @override
  Future<void> clear() async {
    sid = null;
    email = null;
    savedAt = null;
  }

  @override
  Future<({String email, String sessionId})?> load() async =>
      (sid == null || email == null) ? null : (sessionId: sid!, email: email!);

  @override
  Future<String?> readEmail() async => email;

  @override
  Future<void> save({required String sessionId, required String email}) async {
    sid = sessionId;
    this.email = email;
    savedAt = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  Future<int?> savedAtMs() async => savedAt;

  String? dashboardJson;

  @override
  Future<void> saveDashboard(String json) async {
    dashboardJson = json;
  }

  @override
  Future<String?> loadDashboard() async => dashboardJson;
}

/// Odoo stub: only `good-live-session` belongs to a logged-in user (uid 7).
MockClient _client() => MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['jsonrpc'], '2.0');
      final cookie = req.headers['Cookie'] ?? '';
      if (cookie.contains('good-live-session')) {
        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': null,
            'result': {'uid': 7, 'username': 'tester@ucp.edu.pk'}
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': null,
          'error': {'code': 100, 'message': 'Odoo Session Expired'}
        }),
        200,
      );
    });

SessionManager _manager(_MemoryBackend backend) =>
    SessionManager(store: backend, api: OdooApi(_client()));

int _msAgo(Duration d) =>
    DateTime.now().millisecondsSinceEpoch - d.inMilliseconds;

void main() {
  group('staleness (15-minute session, refresh at 10)', () {
    test('fresh session is not stale', () {
      final m = _manager(_MemoryBackend());
      expect(m.isStale(_msAgo(const Duration(minutes: 2)), DateTime.now()),
          isFalse);
    });

    test('old session is stale', () {
      final m = _manager(_MemoryBackend());
      expect(m.isStale(_msAgo(const Duration(minutes: 11)), DateTime.now()),
          isTrue);
    });

    test('unknown age is stale', () {
      final m = _manager(_MemoryBackend());
      expect(m.isStale(null, DateTime.now()), isTrue);
    });
  });

  group('ensureValidSession', () {
    test('no stored session -> AuthRequired, renew never called', () async {
      var renewed = false;
      final m = _manager(_MemoryBackend());
      await expectLater(
        m.ensureValidSession(renew: (_) async {
          renewed = true;
          return 'x';
        }),
        throwsA(isA<AuthRequired>()),
      );
      expect(renewed, isFalse);
    });

    test('fresh + live session passes without renew', () async {
      var renewed = false;
      final backend = _MemoryBackend(
        sid: 'good-live-session',
        email: 'a@ucp.edu.pk',
        savedAt: _msAgo(const Duration(minutes: 1)),
      );
      final s = await _manager(backend).ensureValidSession(renew: (_) async {
        renewed = true;
        return 'x';
      });
      expect(s.sessionId, 'good-live-session');
      expect(s.renewed, isFalse);
      expect(renewed, isFalse);
    });

    test('stale session is renewed and saved', () async {
      final backend = _MemoryBackend(
        sid: 'old-dead-session',
        email: 'a@ucp.edu.pk',
        savedAt: _msAgo(const Duration(minutes: 14)),
      );
      final s = await _manager(backend).ensureValidSession(
        renew: (email) async {
          expect(email, 'a@ucp.edu.pk');
          return 'good-live-session';
        },
      );
      expect(s.sessionId, 'good-live-session');
      expect(s.renewed, isTrue);
      expect(backend.sid, 'good-live-session');
      expect(backend.savedAt, isNotNull);
    });

    test('fresh-looking but dead session renews once', () async {
      final backend = _MemoryBackend(
        sid: 'dead-session',
        email: 'a@ucp.edu.pk',
        savedAt: _msAgo(const Duration(minutes: 1)),
      );
      var calls = 0;
      final s = await _manager(backend).ensureValidSession(renew: (_) async {
        calls++;
        return 'good-live-session';
      });
      expect(calls, 1);
      expect(s.sessionId, 'good-live-session');
    });

    test('renew returning null -> AuthRequired', () async {
      final backend = _MemoryBackend(
        sid: 'old',
        email: 'a@ucp.edu.pk',
        savedAt: _msAgo(const Duration(hours: 1)),
      );
      await expectLater(
        _manager(backend).ensureValidSession(renew: (_) async => null),
        throwsA(isA<AuthRequired>()),
      );
    });

    test('renew throwing propagates as-is (caller maps to UI)', () async {
      final backend = _MemoryBackend(
        sid: 'old',
        email: 'a@ucp.edu.pk',
        savedAt: _msAgo(const Duration(hours: 1)),
      );
      await expectLater(
        _manager(backend).ensureValidSession(
          renew: (_) async => throw InteractionNeededForTest(),
        ),
        throwsA(isA<InteractionNeededForTest>()),
      );
    });
  });
}

class InteractionNeededForTest implements Exception {}
