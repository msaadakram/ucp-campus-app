import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ucp/web/portal_downloader.dart';

/// Canned portal that answers from a route table.
class FakePortalClient extends http.BaseClient {
  final FutureOr<http.StreamedResponse> Function(http.BaseRequest req) handler;
  FakePortalClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      handler(request);
}

http.StreamedResponse bytesRes(
  List<int> bytes, {
  int status = 200,
  Map<String, String> headers = const {},
}) =>
    http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      status,
      headers: Map<String, String>.of(headers),
    );

http.StreamedResponse redirectRes(String location) => http.StreamedResponse(
      const Stream<List<int>>.empty(),
      302,
      headers: {'location': location},
    );

Future<Directory> tempDir() =>
    Directory.systemTemp.createTemp('ucp-dl-test');

PortalDownloader downloaderWith(
  FutureOr<http.StreamedResponse> Function(http.BaseRequest req) handler,
  Directory dir,
) =>
    PortalDownloader(
      clientFactory: () => FakePortalClient(handler),
      dirProvider: () async => dir,
    );

void main() {
  group('filename helpers', () {
    test('content-disposition plain filename', () {
      expect(
        PortalDownloader.fileNameFromContentDisposition(
            'attachment; filename="Lecture 6.pdf"'),
        'Lecture 6.pdf',
      );
    });

    test('content-disposition RFC5987 star wins', () {
      expect(
        PortalDownloader.fileNameFromContentDisposition(
            'attachment; filename="fallback.pdf"; filename*=UTF-8\'\'%D9%85%D8%AD%D8%A7%D8%B6%D8%B1%D8%A9.pdf'),
        isNotEmpty,
      );
    });

    test('content-disposition missing → null', () {
      expect(PortalDownloader.fileNameFromContentDisposition(null), isNull);
      expect(PortalDownloader.fileNameFromContentDisposition(''), isNull);
    });

    test('url fallback uses last segment', () {
      expect(
        PortalDownloader.fileNameFromUrl(
            'https://horizon.ucp.edu.pk/web/content/123?download=true'),
        '123',
      );
    });

    test('sanitize strips separators, never empty', () {
      expect(PortalDownloader.sanitizeFileName('../../etc/passwd'),
          '.._.._etc_passwd');
      expect(PortalDownloader.sanitizeFileName('   ').isNotEmpty, isTrue);
    });
  });

  group('PortalDownloader.start', () {
    test('saves bytes with server filename + progress', () async {
      final dir = await tempDir();
      final payload = List<int>.generate(4096, (i) => i % 256);
      final seenProgress = <double>[];
      final dl = downloaderWith((req) {
        expect(req.headers['Cookie'], 'session_id=sid123');
        return bytesRes(payload, headers: {
          'content-disposition': 'attachment; filename="slides.pdf"',
          'content-type': 'application/pdf',
          'content-length': '${payload.length}',
        });
      }, dir);
      dl.updates.listen((d) {
        if (d.status == DownloadStatus.downloading) {
          seenProgress.add(d.progress);
        }
      });
      final done = await dl.start(
        url: 'https://horizon.ucp.edu.pk/web/content/9?download=true',
        sessionId: 'sid123',
      );
      expect(done.status, DownloadStatus.complete);
      expect(done.fileName, 'slides.pdf');
      expect(done.progress, 1.0);
      expect(seenProgress.isNotEmpty, isTrue);
      final f = File(done.filePath!);
      expect(await f.exists(), isTrue);
      expect(await f.length(), payload.length);
      dl.dispose();
    });

    test('redirect to login → sessionExpired', () async {
      final dir = await tempDir();
      final dl = downloaderWith(
        (_) => redirectRes('https://horizon.ucp.edu.pk/web/login'),
        dir,
      );
      final done = await dl.start(
        url: 'https://horizon.ucp.edu.pk/web/content/9?download=true',
        sessionId: 'stale',
      );
      expect(done.status, DownloadStatus.failed);
      expect(done.sessionExpired, isTrue);
      dl.dispose();
    });

    test('401 → sessionExpired', () async {
      final dir = await tempDir();
      final dl = downloaderWith(
        (_) => bytesRes('no'.codeUnits, status: 401),
        dir,
      );
      final done = await dl.start(
          url: 'https://horizon.ucp.edu.pk/web/content/9',
          sessionId: 'bad');
      expect(done.sessionExpired, isTrue);
      dl.dispose();
    });

    test('HTML login page body → sessionExpired, no file kept', () async {
      final dir = await tempDir();
      const html =
          '<html><body><form class="oe_login_form"><input name="login">'
          '<input name="password"></form></body></html>';
      final dl = downloaderWith(
        (_) => bytesRes(html.codeUnits, headers: {
          'content-type': 'text/html; charset=utf-8',
        }),
        dir,
      );
      final done = await dl.start(
          url: 'https://horizon.ucp.edu.pk/web/content/9',
          sessionId: 'stale');
      expect(done.status, DownloadStatus.failed);
      expect(done.sessionExpired, isTrue);
      expect(done.filePath, isNull);
      expect(await dir.list().toList(), isEmpty);
      dl.dispose();
    });

    test('missing content-length still completes', () async {
      final dir = await tempDir();
      final payload = List<int>.filled(1000, 7);
      final dl = downloaderWith(
        (_) => bytesRes(payload,
            headers: {'content-type': 'application/octet-stream'}),
        dir,
      );
      final done = await dl.start(
          url: 'https://horizon.ucp.edu.pk/web/content/9',
          sessionId: 'sid');
      expect(done.status, DownloadStatus.complete);
      expect(done.totalBytes, -1);
      dl.dispose();
    });

    test('duplicate names get unique suffix', () async {
      final dir = await tempDir();
      await File('${dir.path}/notes.pdf').writeAsBytes([1, 2, 3]);
      final dl = downloaderWith(
        (_) => bytesRes([4, 5],
            headers: {'content-disposition': 'attachment; filename="notes.pdf"'}),
        dir,
      );
      final done = await dl.start(
          url: 'https://horizon.ucp.edu.pk/x', sessionId: 'sid');
      expect(done.status, DownloadStatus.complete);
      expect(done.fileName, 'notes.pdf');
      expect(done.filePath, '${dir.path}/notes (1).pdf');
      dl.dispose();
    });

    test('cancel deletes the partial file', () async {
      final dir = await tempDir();
      final controller = StreamController<List<int>>();
      final dl = downloaderWith(
        (_) => http.StreamedResponse(
          controller.stream,
          200,
          headers: {
            'content-type': 'application/pdf',
            'content-length': '1000000',
          },
        ),
        dir,
      );
      var id = '';
      dl.updates.listen((d) {
        if (d.status == DownloadStatus.downloading) id = d.id;
      });
      final fut = dl.start(
          url: 'https://horizon.ucp.edu.pk/web/content/9', sessionId: 'sid');
      controller.add(List<int>.filled(1000, 1));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      dl.cancel(id);
      await controller.close();
      final done = await fut;
      expect(done.status, DownloadStatus.canceled);
      expect(await dir.list().toList(), isEmpty);
      dl.dispose();
    });
  });

  group('PortalDownloader.start POST forms', () {
    test('posts urlencoded body with session cookie', () async {
      final dir = await tempDir();
      http.BaseRequest? seen;
      String? seenBody;
      final dl = downloaderWith((req) async {
        seen = req;
        if (req is http.Request) seenBody = req.body;
        // Drain to mimic a real client before answering.
        if (req is http.Request) {
          return bytesRes([1, 2, 3], headers: {
            'content-type': 'application/pdf',
            'content-length': '3',
            'content-disposition': 'attachment; filename="doc.pdf"',
          });
        }
        return bytesRes([], status: 500);
      }, dir);
      final done = await dl.start(
        url: 'https://horizon.ucp.edu.pk/web/binary/download_document',
        sessionId: 'sid9',
        method: 'POST',
        fields: {'res_id': '42', 'res_model': 'ir.attachment'},
      );
      expect(done.status, DownloadStatus.complete);
      expect(seen!.method, 'POST');
      expect(seen!.headers['Cookie'], 'session_id=sid9');
      expect(seenBody, contains('res_id=42'));
      expect(seenBody, contains('res_model=ir.attachment'));
      dl.dispose();
    });

    test('302 after POST continues as GET without body', () async {
      final dir = await tempDir();
      final methods = <String>[];
      final dl = downloaderWith((req) {
        methods.add(req.method);
        if (methods.length == 1) {
          return redirectRes('/web/content/7?download=true');
        }
        return bytesRes([9], headers: {'content-type': 'application/pdf'});
      }, dir);
      final done = await dl.start(
        url: 'https://horizon.ucp.edu.pk/web/binary/download_document',
        sessionId: 'sid9',
        method: 'POST',
        fields: {'a': 'b'},
      );
      expect(done.status, DownloadStatus.complete);
      expect(methods, ['POST', 'GET']);
      dl.dispose();
    });

    test('non-login HTML explains itself instead of blaming session',
        () async {
      final dir = await tempDir();
      const html = '<html><body><h1>Preview not available</h1></body></html>';
      final dl = downloaderWith(
        (_) => bytesRes(html.codeUnits,
            headers: {'content-type': 'text/html'}),
        dir,
      );
      final done = await dl.start(
          url: 'https://horizon.ucp.edu.pk/web/content/9',
          sessionId: 'sid');
      expect(done.status, DownloadStatus.failed);
      expect(done.sessionExpired, isFalse);
      expect(done.error, contains('Could not download'));
      dl.dispose();
    });
  });
  group('PortalDownloader.saveBytes', () {
    test('writes blob payload as completed download', () async {
      final dir = await tempDir();
      final dl = PortalDownloader(dirProvider: () async => dir);
      final done = await dl.saveBytes(
        url: 'blob:abc',
        bytes: [10, 20, 30],
        sessionId: 'sid',
        fileName: 'paper.pdf',
        mimeType: 'application/pdf',
      );
      expect(done.status, DownloadStatus.complete);
      expect(await File(done.filePath!).length(), 3);
      dl.dispose();
    });
  });
}
