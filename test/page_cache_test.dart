import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ucp/auth/page_cache.dart';

void main() {
  test('pages round-trip gzipped and only one course is kept', () async {
    final dir = await Directory.systemTemp.createTemp('ucpcache');
    PageCache.debugDir = dir;
    PageCache.diskEnabled = true;
    PageCache.debugPages = null;

    // A portal page is ~1.5 MB; compress that shape, not a toy string.
    final pageA = '<html>${'x' * 200000}</html>';
    final pageB = '<html>${'y' * 200000}</html>';
    await PageCache.savePage('course_AAA_news', pageA);
    await PageCache.savePage('course_BBB_news', pageB);

    final files = dir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toList();
    // Only course B survives — course A's snapshot was dropped.
    expect(files.where((f) => f.contains('AAA')), isEmpty);
    expect(files.where((f) => f.contains('BBB')), hasLength(1));

    // The round-trip returns the original HTML.
    final snap = await PageCache.loadPage('course_BBB_news');
    expect(snap!.html, pageB);

    // It really is gzipped on disk (a ~1.5 MB page shrinks ~20x).
    final raw = File('${dir.path}/portal_course_BBB_news.html.gz');
    final bytes = await raw.readAsBytes();
    expect(utf8.decode(gzip.decode(bytes)), pageB);
    expect(bytes.length, lessThan(pageB.length ~/ 10));

    await dir.delete(recursive: true);
  });
}
