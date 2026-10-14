import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucp/web/download_tray.dart';
import 'package:ucp/web/portal_downloader.dart';

PortalDownload dl({
  required String id,
  DownloadStatus status = DownloadStatus.downloading,
  int total = 1000,
  int received = 250,
  String name = 'Lecture 6.pdf',
}) =>
    PortalDownload(
      id: id,
      url: 'https://horizon.ucp.edu.pk/web/content/$id',
      fileName: name,
      mimeType: 'application/pdf',
      totalBytes: total,
      receivedBytes: received,
      status: status,
      filePath: status == DownloadStatus.complete ? '/tmp/$name' : null,
      error: status == DownloadStatus.failed ? 'Download failed.' : null,
    );

void main() {
  testWidgets('DownloadBar shows live progress + cancel', (tester) async {
    var canceled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DownloadBar(
            item: dl(id: '1'),
            onCancel: () => canceled = true,
          ),
        ),
      ),
    );
    expect(find.text('Lecture 6.pdf'), findsOneWidget);
    expect(find.textContaining('25%'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel download'));
    expect(canceled, isTrue);
  });

  testWidgets('DownloadBar complete shows OPEN', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DownloadBar(
            item: dl(id: '2', status: DownloadStatus.complete),
            onOpen: () => opened = true,
          ),
        ),
      ),
    );
    expect(find.textContaining('Download complete'), findsOneWidget);
    await tester.tap(find.text('OPEN'));
    expect(opened, isTrue);
  });

  testWidgets('DownloadIconButton shows active badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DownloadIconButton(
            activeCount: 2,
            pendingCount: 0,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.text('2'), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
  });

  testWidgets('DownloadsSheet lists jobs with per-status actions',
      (tester) async {
    final controller = StreamController<PortalDownload>.broadcast();
    addTearDown(controller.close);
    var retried = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DownloadsSheet(
            initial: [
              dl(id: 'a', status: DownloadStatus.complete, name: 'done.pdf'),
              dl(id: 'b', status: DownloadStatus.failed, name: 'bad.pdf'),
            ],
            updates: controller.stream,
            onOpen: (_) async {},
            onCancel: (_) {},
            onRetry: (d) => retried = d.id,
            onDelete: (_) async {},
            saveLocationLabel: 'Downloads/UCP folder',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('done.pdf'), findsOneWidget);
    expect(find.text('bad.pdf'), findsOneWidget);
    expect(find.byTooltip('Open'), findsOneWidget);
    expect(find.byTooltip('Retry'), findsOneWidget);
    await tester.tap(find.byTooltip('Retry'));
    expect(retried, 'b');

    // Live progress streams into the sheet.
    controller.add(
        dl(id: 'c', name: 'live.pdf', received: 500, total: 1000));
    await tester.pumpAndSettle();
    expect(find.text('live.pdf'), findsOneWidget);
  });

  test('formatBytes + icon mapping', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
    expect(iconForFileName('x.pdf'), Icons.picture_as_pdf_outlined);
    expect(iconForFileName('x.zip'), Icons.folder_zip_outlined);
    expect(iconForFileName('x.unknown'), Icons.insert_drive_file_outlined);
  });
}
