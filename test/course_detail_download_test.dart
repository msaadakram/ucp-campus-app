import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucp/auth/course_cache.dart';
import 'package:ucp/auth/student_portal.dart';
import 'package:ucp/screens/course_detail.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/web/portal_downloader.dart';
import 'package:ucp/widgets/common.dart';

Widget _wrap(Widget child) {
  final colors = AppColors.of(AppPalette.skater, false);
  return MaterialApp(
    home: AppScope(
      colors: colors,
      palette: AppPalette.skater,
      // Scaffold so the screen's snackbars have somewhere to present.
      child: Scaffold(body: child),
    ),
  );
}

const _pc = PortalCourse(
  name: 'Object Oriented Programming',
  teacher: 'Aasma Abdul Waheed',
  code: 'CP223',
  credits: 3.0,
  attendance: 75.0,
  infoUrl: '/student/course/info/TEST1234abcd',
);

const _materialHtml = '<table><thead><tr><th>Sr No.</th>'
    '<th>Course Material File</th><th>Description</th><th>Download</th>'
    '</tr></thead><tbody><tr><td>1</td><td>OOP-WEEK1.cpp</td>'
    '<td>Week 1 code</td>'
    '<td><a href="/student/class/material/download/abc123">dl</a></td>'
    '</tr></tbody></table>';

class _FakeDownloader extends PortalDownloader {
  int startCalls = 0;
  String? existingPath;
  String? downloadedPath;
  PortalDownload? result;

  _FakeDownloader({this.existingPath, this.downloadedPath});

  @override
  Future<String?> findDownloaded(String fileName) async => existingPath;

  @override
  Future<PortalDownload> start({
    required String url,
    required String? sessionId,
    String? fileName,
    String method = 'GET',
    Map<String, String>? fields,
  }) async {
    startCalls++;
    if (result != null) return result!;
    assert(downloadedPath != null);
    return PortalDownload(
      id: 'd1',
      url: url,
      fileName: fileName ?? 'file',
      mimeType: 'text/plain',
      totalBytes: 4,
      receivedBytes: 4,
      status: DownloadStatus.complete,
      filePath: downloadedPath,
    );
  }
}

void main() {
  setUp(() => CourseDetailCache.clear());

  group('PortalDownloader.findDownloaded', () {
    test('finds the exact saved name, null otherwise', () async {
      final dir = await Directory.systemTemp.createTemp('dl-find');
      addTearDown(() => dir.delete(recursive: true));
      final dl = PortalDownloader(dirProvider: () async => dir);
      expect(await dl.findDownloaded('notes.pdf'), isNull);
      await File('${dir.path}/notes.pdf').writeAsString('x');
      expect(await dl.findDownloaded('notes.pdf'), '${dir.path}/notes.pdf');
      expect(await dl.findDownloaded('other.pdf'), isNull);
      // Path traversal is defused by the sanitizer: '../notes.pdf'
      // becomes '.._notes.pdf' — NOT a match for the saved 'notes.pdf'.
      expect(await dl.findDownloaded('../notes.pdf'), isNull);
      expect(await dl.findDownloaded('..\\notes.pdf'), isNull);
      dl.dispose();
    });
  });

  group('CourseDetailScreen material download UX', () {
    testWidgets(
        'already in storage: opens the saved file, never re-downloads',
        (t) async {
      final fake = _FakeDownloader(existingPath: '/data/OOP-WEEK1.cpp');
      final opened = <String>[];
      await t.pumpWidget(_wrap(CourseDetailScreen(
        portalCourse: _pc,
        back: () {},
        debugHtml: const {'news': _materialHtml, 'material': _materialHtml},
        downloader: fake,
        onOpenFile: (p) async => opened.add(p),
      )));
      await t.pumpAndSettle();
      await t.tap(find.text('Material'));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.download).first);
      await t.pumpAndSettle();
      expect(opened, ['/data/OOP-WEEK1.cpp']);
      expect(fake.startCalls, 0); // no network fetch
      expect(find.textContaining('Opening saved OOP-WEEK1.cpp'),
          findsOneWidget);
      expect(find.text('Download again'), findsOneWidget);
    });

    testWidgets('fresh download: auto-opens once and confirms saved',
        (t) async {
      final fake = _FakeDownloader(downloadedPath: '/data/new/OOP-WEEK1.cpp');
      final opened = <String>[];
      await t.pumpWidget(_wrap(CourseDetailScreen(
        portalCourse: _pc,
        back: () {},
        debugHtml: const {'news': _materialHtml, 'material': _materialHtml},
        downloader: fake,
        onOpenFile: (p) async => opened.add(p),
      )));
      await t.pumpAndSettle();
      await t.tap(find.text('Material'));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.download).first);
      await t.pumpAndSettle();
      expect(fake.startCalls, 1);
      expect(opened, ['/data/new/OOP-WEEK1.cpp']); // auto-opened once
      expect(find.textContaining('Saved OOP-WEEK1.cpp'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget); // manual backup action
    });

    testWidgets('"Download again" forces a fresh fetch and opens it',
        (t) async {
      final fake = _FakeDownloader(
        existingPath: '/data/old.cpp',
        downloadedPath: '/data/fresh/OOP-WEEK1.cpp',
      );
      final opened = <String>[];
      await t.pumpWidget(_wrap(CourseDetailScreen(
        portalCourse: _pc,
        back: () {},
        debugHtml: const {'news': _materialHtml, 'material': _materialHtml},
        downloader: fake,
        onOpenFile: (p) async => opened.add(p),
      )));
      await t.pumpAndSettle();
      await t.tap(find.text('Material'));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.download).first);
      await t.pumpAndSettle();
      expect(opened, ['/data/old.cpp']);
      await t.tap(find.text('Download again'));
      await t.pumpAndSettle();
      expect(fake.startCalls, 1);
      expect(opened, ['/data/old.cpp', '/data/fresh/OOP-WEEK1.cpp']);
    });
  });
}
