import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// On-disk snapshots of raw portal pages (`portal_<page>.html` in the app
/// documents directory). Raw pages are ~1.4 MB each — far too big for
/// encrypted prefs — but trivial on disk. Screens parse them exactly like
/// live responses, so offline restarts still show real content.
///
/// Disk access is enabled by `main()` (`diskEnabled = true`). Everywhere
/// else — notably widget tests, where real async IO never completes —
/// calls are safe no-ops returning null. `debugPages` is an in-memory
/// stand-in for tests.
///
/// Never throws; every failure maps to null / no-op.
class PageSnapshot {
  final String html;
  final int savedAtMs;
  const PageSnapshot(this.html, this.savedAtMs);
}

class PageCache {
  static const pages = [
    'timetable',
    'datesheet',
    'attendance',
    'invoices',
    'results',
  ];

  /// Set by `main()` in production. Stays false in tests.
  static bool diskEnabled = false;

  /// In-memory pages used instead of disk when non-null (test seam).
  static Map<String, String>? debugPages;

  static Directory? debugDir;

  static Future<Directory?> _dir() async {
    try {
      return debugDir ?? await getApplicationDocumentsDirectory();
    } catch (_) {
      return null;
    }
  }

  /// Saves a page. Portal pages are ~1.5 MB each, so they are gzipped on
  /// disk (~8x smaller). Course snapshots (`course_<id>_<tab>`) are kept
  /// for ONE course at a time — the previous course's files are removed —
  /// otherwise browsing the hub would fill the phone with HTML.
  static Future<void> savePage(String page, String html) async {
    try {
      final dbg = debugPages;
      if (dbg != null) {
        if (html.isNotEmpty) dbg[page] = html;
        return;
      }
      if (!diskEnabled || html.isEmpty) return;
      final d = await _dir();
      if (d == null) return;
      final file = File('${d.path}/portal_$page.html.gz');
      await file.writeAsBytes(gzip.encode(utf8.encode(html)), flush: true);
      final course = _courseIdOf(page);
      if (course != null) await _dropOtherCourses(d, course);
    } catch (_) {}
  }

  /// "course_42_gradebook" -> "42" (null for the fixed pages).
  static String? _courseIdOf(String page) {
    final m = RegExp(r'^course_(.+)_[^_]+$').firstMatch(page);
    return m?.group(1);
  }

  /// Removes snapshots belonging to OTHER courses.
  static Future<void> _dropOtherCourses(Directory d, String keep) async {
    try {
      await for (final f in d.list()) {
        if (f is! File) continue;
        final name = f.uri.pathSegments.isNotEmpty
            ? f.uri.pathSegments.last
            : '';
        if (!name.startsWith('portal_course_')) continue;
        final body =
            name.substring('portal_'.length, name.length - '.html.gz'.length);
        final id = _courseIdOf(body) ?? _courseIdOf(
            body.replaceAll('.html', ''));
        if (id != null && id != keep) {
          await f.delete();
        }
      }
    } catch (_) {}
  }

  /// Drops snapshots older than [maxAge] (and every course snapshot on
  /// demand). Never throws.
  static Future<void> prune({
    Duration maxAge = const Duration(days: 14),
    bool courseSnapshotsOnly = false,
  }) async {
    final d = await _dir();
    if (d == null) return;
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - maxAge.inMilliseconds;
    try {
      await for (final f in d.list()) {
        if (f is! File) continue;
        final name = f.uri.pathSegments.isNotEmpty
            ? f.uri.pathSegments.last
            : '';
        if (!name.startsWith('portal_') || !name.endsWith('.html.gz')) continue;
        if (courseSnapshotsOnly && !name.startsWith('portal_course_')) continue;
        try {
          final stat = await f.lastModified();
          if (stat.millisecondsSinceEpoch < cutoff) await f.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  static Future<PageSnapshot?> loadPage(String page) async {
    try {
      final dbg = debugPages;
      if (dbg != null) {
        final html = dbg[page];
        if (html == null || html.isEmpty) return null;
        return PageSnapshot(
            html, DateTime.now().millisecondsSinceEpoch);
      }
      if (!diskEnabled) return null;
      final d = await _dir();
      if (d == null) return null;
      final f = File('${d.path}/portal_$page.html.gz');
      if (!await f.exists()) {
        // Legacy plaintext snapshots still load, then are re-gzipped on
        // the next save.
        final legacy = File('${d.path}/portal_$page.html');
        if (!await legacy.exists()) return null;
        final plain = await legacy.readAsString();
        if (plain.isEmpty) return null;
        final stat = await legacy.lastModified();
        return PageSnapshot(plain, stat.millisecondsSinceEpoch);
      }
      final html = utf8.decode(
        gzip.decode(await f.readAsBytes()),
      );
      if (html.isEmpty) return null;
      final stat = await f.lastModified();
      return PageSnapshot(
          html, stat.millisecondsSinceEpoch);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      debugPages?.clear();
      if (!diskEnabled) return;
      final d = await _dir();
      if (d == null) return;
      // Gzipped snapshots (and any legacy plaintext ones) are removed by
      // prefix, since the per-course names are dynamic.
      try {
        await for (final e in d.list()) {
          if (e is! File) continue;
          final name = e.path.split('/').last;
          if (name.startsWith('portal_') &&
              (name.endsWith('.html.gz') || name.endsWith('.html'))) {
            try {
              await e.delete();
            } catch (_) {}
          }
        }
      } catch (_) {}
    } catch (_) {}
  }
}
