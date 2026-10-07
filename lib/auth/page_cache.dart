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
      await File('${d.path}/portal_$page.html').writeAsString(html);
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
      final f = File('${d.path}/portal_$page.html');
      if (!await f.exists()) return null;
      final html = await f.readAsString();
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
      for (final page in pages) {
        try {
          final f = File('${d.path}/portal_$page.html');
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }
}
