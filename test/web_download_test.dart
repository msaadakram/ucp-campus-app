import 'package:flutter_test/flutter_test.dart';
import 'package:ucp/screens/materials_web.dart';
import 'package:ucp/web/portal_downloader.dart';

/// Strips single-quoted JS string literals (handling escapes) so
/// delimiter balancing below only sees real code.
String _stripJsStrings(String src) {
  final out = StringBuffer();
  var i = 0;
  while (i < src.length) {
    final ch = src[i];
    if (ch == "'") {
      out.write('__STR__');
      i++;
      while (i < src.length && src[i] != "'") {
        if (src[i] == '\\') i++;
        i++;
      }
      i++; // closing quote
    } else {
      out.write(ch);
      i++;
    }
  }
  return out.toString();
}

/// The links the app steals from the WebView and downloads with the
/// session cookie instead of navigating.
void main() {
  group('download URL detection', () {
    test('odoo binary + report endpoints', () {
      expect(
          isPortalDownloadUrl(Uri.parse(
              'https://horizon.ucp.edu.pk/web/content/123?download=true')),
          isTrue);
      expect(
          isPortalDownloadUrl(Uri.parse('https://horizon.ucp.edu.pk/'
              'web/binary/download_document')),
          isTrue);
      expect(
          isPortalDownloadUrl(Uri.parse(
              'https://horizon.ucp.edu.pk/report/pdf/sale.order/9')),
          isTrue);
    });

    test('file extensions + download query', () {
      expect(
          isPortalDownloadUrl(Uri.parse(
              'https://horizon.ucp.edu.pk/slides/lecture-6.pdf')),
          isTrue);
      expect(
          isPortalDownloadUrl(
              Uri.parse('https://horizon.ucp.edu.pk/files/data.XLSX')),
          isTrue);
      expect(
          isPortalDownloadUrl(Uri.parse(
              'https://horizon.ucp.edu.pk/portal/export?download=1')),
          isTrue);
    });

    test('normal portal pages are left alone', () {
      expect(
          isPortalDownloadUrl(
              Uri.parse('https://horizon.ucp.edu.pk/student/dashboard')),
          isFalse);
      expect(
          isPortalDownloadUrl(
              Uri.parse('https://horizon.ucp.edu.pk/my/home')),
          isFalse);
      expect(
          isPortalDownloadUrl(Uri.parse(
              'https://horizon.ucp.edu.pk/web/login?redirect=/')),
          isFalse);
      expect(
          isPortalDownloadUrl(Uri.parse('blob:https://x/abc')), isFalse);
    });
  });

  group('in-page download hook script', () {
    test('has no division-assign accident (killed the whole hook once)',
        () {
      // `var m/=re/` parses as divide-assign and is a SyntaxError that
      // disables every trigger at parse time. Only ==, !=, <=, >= may
      // precede a slash.
      expect(RegExp(r'[^=!<>]=/').hasMatch(downloadHookJs), isFalse);
    });

    test('installs every trigger', () {
      for (final marker in [
        '__ucpDlHook',
        "addEventListener('click'",
        "addEventListener('submit'",
        'window.fetch',
        'window.open',
        'sendChunked',
        'content-disposition',
        'postMessage',
      ]) {
        expect(downloadHookJs, contains(marker), reason: marker);
      }
    });

    test('delimiters balance', () {
      final code = _stripJsStrings(downloadHookJs);
      expect('('.allMatches(code).length, ')'.allMatches(code).length);
      expect('{'.allMatches(code).length, '}'.allMatches(code).length);
      expect('['.allMatches(code).length, ']'.allMatches(code).length);
    });
  });
}
