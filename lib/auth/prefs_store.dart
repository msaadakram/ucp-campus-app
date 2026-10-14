import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../screens/profile.dart';

/// On-device persistence for [ProfilePrefs] (theme, palette, text size,
/// animations). Written on every change in Profile, read once before the
/// first frame in `main()` so startup (splash, restoring view, login)
/// already paints in the saved theme — no light-mode flash. Survives
/// logout and restarts; only a new user choice overwrites it.
class PrefsStore {
  static const _kPrefs = 'ucp_profile_prefs_json';

  final FlutterSecureStorage _storage;
  PrefsStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<ProfilePrefs> loadPrefs() async {
    try {
      final raw = await _storage.read(key: _kPrefs);
      if (raw == null || raw.isEmpty) return ProfilePrefs();
      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) return ProfilePrefs();
      return ProfilePrefs.fromJson(parsed);
    } catch (_) {
      return ProfilePrefs();
    }
  }

  Future<void> savePrefs(ProfilePrefs prefs) async {
    try {
      await _storage.write(key: _kPrefs, value: jsonEncode(prefs.toJson()));
    } catch (_) {
      // Best-effort like the dashboard snapshot: the in-memory theme
      // still applies immediately; persistence retries on next change.
    }
  }
}
