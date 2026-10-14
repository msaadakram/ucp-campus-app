import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Status of a single portal file download.
enum DownloadStatus { queued, downloading, complete, failed, canceled }

/// One download job. Immutable snapshots are emitted through [PortalDownloader.updates].
class PortalDownload {
  final String id;
  final String url;
  final String fileName;
  final String mimeType;
  final int totalBytes;
  final int receivedBytes;
  final DownloadStatus status;
  final String? filePath;

  /// Absolute path of the public copy (phone Download folder), if saved.
  final String? publicPath;
  final String? error;

  /// True when the portal answered with its login page instead of the file
  /// (session died mid-download). The UI should trigger re-login.
  final bool sessionExpired;

  const PortalDownload({
    required this.id,
    required this.url,
    required this.fileName,
    this.mimeType = '',
    this.totalBytes = -1,
    this.receivedBytes = 0,
    this.status = DownloadStatus.queued,
    this.filePath,
    this.publicPath,
    this.error,
    this.sessionExpired = false,
  });

  double get progress =>
      totalBytes > 0 ? receivedBytes / totalBytes : -1;

  bool get isActive =>
      status == DownloadStatus.queued ||
      status == DownloadStatus.downloading;

  PortalDownload copyWith({
    String? fileName,
    String? mimeType,
    int? totalBytes,
    int? receivedBytes,
    DownloadStatus? status,
    String? filePath,
    String? publicPath,
    String? error,
    bool? sessionExpired,
  }) =>
      PortalDownload(
        id: id,
        url: url,
        fileName: fileName ?? this.fileName,
        mimeType: mimeType ?? this.mimeType,
        totalBytes: totalBytes ?? this.totalBytes,
        receivedBytes: receivedBytes ?? this.receivedBytes,
        status: status ?? this.status,
        filePath: filePath ?? this.filePath,
        publicPath: publicPath ?? this.publicPath,
        error: error ?? this.error,
        sessionExpired: sessionExpired ?? this.sessionExpired,
      );
}

typedef DownloadDirProvider = Future<Directory> Function();

Future<Directory> _defaultDownloadDir() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/downloads');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// Downloads portal files with the student's `session_id` cookie.
///
/// The portal only serves files to signed-in sessions, so every request
/// (including redirect hops) carries `Cookie: session_id=...`. Redirects
/// are followed manually to detect bounces to `/web/login` — those mean
/// the session died and surface as [PortalDownload.sessionExpired].
class PortalDownloader {
  final http.Client Function() _clientFactory;
  final DownloadDirProvider _dirProvider;
  final _updates = StreamController<PortalDownload>.broadcast();
  final Map<String, http.Client> _liveClients = {};
  final Set<String> _canceled = {};

  PortalDownloader({
    http.Client Function()? clientFactory,
    DownloadDirProvider? dirProvider,
  })  : _clientFactory = clientFactory ?? (() => http.Client()),
        _dirProvider = dirProvider ?? _defaultDownloadDir;

  Stream<PortalDownload> get updates => _updates.stream;

  void cancel(String id) {
    _canceled.add(id);
    _liveClients.remove(id)?.close();
  }

  void dispose() {
    for (final c in _liveClients.values) {
      c.close();
    }
    _liveClients.clear();
    if (!_updates.isClosed) _updates.close();
  }

  void _emit(PortalDownload d) {
    if (!_updates.isClosed) _updates.add(d);
  }

  /// Downloads [url] to the app downloads folder. Returns the final snapshot.
  ///
  /// Most portal files are plain GET links, but some download buttons POST
  /// a form (Odoo binary endpoints): pass [method] + [fields] for those.
  /// The body is `application/x-www-form-urlencoded`; file inputs are not
  /// supported (the portal's file downloads don't use them).
  Future<PortalDownload> start({
    required String url,
    required String? sessionId,
    String? fileName,
    String method = 'GET',
    Map<String, String>? fields,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    var dl = PortalDownload(
      id: id,
      url: url,
      fileName: sanitizeFileName(fileName ?? fileNameFromUrl(url)),
    );
    _emit(dl);

    final client = _clientFactory();
    _liveClients[id] = client;
    try {
      final resolved = await _followRedirects(
        client: client,
        url: url,
        method: method.toUpperCase() == 'POST' ? 'POST' : 'GET',
        fields: fields ?? const {},
        sessionId: sessionId,
        onHop: (hopUrl) {
          if (_isLoginUrl(hopUrl)) {
            throw const _SessionExpired();
          }
        },
      );
      if (_canceled.contains(id)) return _finishCanceled(dl, client, id);

      final contentType =
          resolved.headers['content-type']?.split(';').first.trim() ?? '';
      if (contentType.startsWith('text/html')) {
        // The portal served a page, not a file — usually the login page
        // (session died) or an inline preview/error page.
        final probe = await _readTextProbe(resolved);
        final expired = _looksLikeLoginPage(resolved.requestUrl, probe);
        _emit(dl = dl.copyWith(
          status: DownloadStatus.failed,
          error: expired
              ? 'Sign in again to download this file.'
              : 'Could not download this file from the portal.',
          sessionExpired: expired,
        ));
        return dl;
      }

      final name = sanitizeFileName(
        fileName ??
            fileNameFromContentDisposition(
                resolved.headers['content-disposition']) ??
            fileNameFromUrl(resolved.requestUrl),
      );
      final total = int.tryParse(resolved.headers['content-length'] ?? '') ?? -1;
      _emit(dl = dl.copyWith(
        fileName: name,
        mimeType: contentType,
        totalBytes: total,
        status: DownloadStatus.downloading,
      ));

      final dir = await _dirProvider();
      final part = File('${dir.path}/.part-$id');
      final sink = part.openWrite();
      var received = 0;
      try {
        await for (final chunk in resolved.stream) {
          if (_canceled.contains(id)) {
            await sink.close();
            if (await part.exists()) await part.delete();
            return _finishCanceled(dl, client, id);
          }
          sink.add(chunk);
          received += chunk.length;
          // Throttle UI churn: emit at most every ~64 KB.
          if (received % 65536 < chunk.length) {
            _emit(dl = dl.copyWith(receivedBytes: received));
          }
        }
        await sink.close();
      } catch (_) {
        try {
          await sink.close();
        } catch (_) {}
        if (await part.exists()) await part.delete();
        rethrow;
      }
      if (_canceled.contains(id)) {
        if (await part.exists()) await part.delete();
        return _finishCanceled(dl, client, id);
      }
      if (total > 0 && received != total) {
        if (await part.exists()) await part.delete();
        _emit(dl = dl.copyWith(
          status: DownloadStatus.failed,
          receivedBytes: received,
          error: 'Download incomplete — tap retry.',
        ));
        return dl;
      }
      final finalPath = await _uniquePath(dir, name);
      await part.rename(finalPath);
      _emit(dl = dl.copyWith(
        status: DownloadStatus.complete,
        receivedBytes: received,
        filePath: finalPath,
      ));
      return dl;
    } on _SessionExpired {
      _emit(dl = dl.copyWith(
        status: DownloadStatus.failed,
        error: 'Portal session expired — sign in again.',
        sessionExpired: true,
      ));
      return dl;
    } catch (e) {
      if (_canceled.contains(id)) return _finishCanceled(dl, client, id);
      _emit(dl = dl.copyWith(
        status: DownloadStatus.failed,
        error: 'Download failed — tap retry.',
      ));
      return dl;
    } finally {
      _liveClients.remove(id);
      client.close();
    }
  }

  /// Saves raw bytes (e.g. reassembled `blob:` payloads from the WebView JS
  /// bridge) as a completed download.
  Future<PortalDownload> saveBytes({
    required String url,
    required List<int> bytes,
    required String? sessionId,
    String? fileName,
    String mimeType = '',
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    var dl = PortalDownload(
      id: id,
      url: url,
      fileName: sanitizeFileName(fileName ?? fileNameFromUrl(url)),
      mimeType: mimeType,
      totalBytes: bytes.length,
      receivedBytes: bytes.length,
      status: DownloadStatus.downloading,
    );
    _emit(dl);
    try {
      final dir = await _dirProvider();
      final finalPath = await _uniquePath(dir, dl.fileName);
      await File(finalPath).writeAsBytes(bytes, flush: true);
      _emit(dl = dl.copyWith(
        status: DownloadStatus.complete,
        filePath: finalPath,
      ));
      return dl;
    } catch (_) {
      _emit(dl = dl.copyWith(
        status: DownloadStatus.failed,
        error: 'Could not save file — tap retry.',
      ));
      return dl;
    }
  }

  PortalDownload _finishCanceled(
      PortalDownload dl, http.Client client, String id) {
    _liveClients.remove(id);
    final done = dl.copyWith(status: DownloadStatus.canceled);
    _emit(done);
    return done;
  }

  static const _maxHops = 5;

  Future<_ResolvedResponse> _followRedirects({
    required http.Client client,
    required String url,
    required String method,
    required Map<String, String> fields,
    required String? sessionId,
    required void Function(String hopUrl) onHop,
  }) async {
    var current = url;
    var currentMethod = method;
    var currentFields = fields;
    for (var hop = 0; hop <= _maxHops; hop++) {
      final req = http.Request(currentMethod, Uri.parse(current));
      req.followRedirects = false;
      req.headers['User-Agent'] = 'UCP-Campus-App/1.0';
      if (sessionId != null && sessionId.isNotEmpty) {
        req.headers['Cookie'] = 'session_id=$sessionId';
      }
      if (currentMethod == 'POST') {
        req.headers['Content-Type'] =
            'application/x-www-form-urlencoded; charset=utf-8';
        req.bodyFields = Map<String, String>.of(currentFields);
      }
      final res = await client.send(req);
      final code = res.statusCode;
      if (code == 301 ||
          code == 302 ||
          code == 303 ||
          code == 307 ||
          code == 308) {
        final loc = res.headers['location'];
        await res.stream.drain<void>();
        if (loc == null || loc.isEmpty) throw const _SessionExpired();
        current = Uri.parse(current).resolve(loc).toString();
        if (currentMethod == 'POST' && code != 307 && code != 308) {
          // Classic redirect-after-POST: continue as GET without a body.
          currentMethod = 'GET';
          currentFields = const {};
        }
        onHop(current);
        continue;
      }
      if (code == 401 || code == 403) {
        await res.stream.drain<void>();
        throw const _SessionExpired();
      }
      if (code < 200 || code >= 300) {
        await res.stream.drain<void>();
        throw HttpException('portal answered $code');
      }
      onHop(current);
      return _ResolvedResponse(
        stream: res.stream,
        headers: res.headers,
        requestUrl: current,
      );
    }
    throw const HttpException('too many redirects');
  }

  Future<String> _readTextProbe(_ResolvedResponse res) async {
    final buf = <int>[];
    var taken = 0;
    try {
      await for (final chunk in res.stream) {
        final room = 262144 - taken;
        if (room <= 0) break;
        buf.addAll(chunk.take(room));
        taken += chunk.length < room ? chunk.length : room;
        if (taken >= 262144) break;
      }
    } catch (_) {}
    try {
      return String.fromCharCodes(buf);
    } catch (_) {
      return '';
    }
  }

  static bool _isLoginUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('/web/login') || u.contains('oe_login_form');
  }

  static bool _looksLikeLoginPage(String url, String probe) {
    if (_isLoginUrl(url)) return true;
    final p = probe.toLowerCase();
    return p.contains('oe_login_form') ||
        p.contains('/web/login') ||
        p.contains('name="login"') && p.contains('name="password"');
  }

  /// Never throws: returns a free path, appending ` (1)`, ` (2)`, … .
  static Future<String> _uniquePath(Directory dir, String name) async {
    var candidate = '${dir.path}/$name';
    if (!await File(candidate).exists()) return candidate;
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    for (var i = 1; i < 1000; i++) {
      candidate = '${dir.path}/$stem ($i)$ext';
      if (!await File(candidate).exists()) return candidate;
    }
    return '${dir.path}/$stem (${DateTime.now().millisecondsSinceEpoch})$ext';
  }

  /// Extracts a filename from `Content-Disposition`, or null.
  static String? fileNameFromContentDisposition(String? header) {
    if (header == null || header.isEmpty) return null;
    // RFC 5987: filename*=UTF-8''... takes precedence.
    final star = RegExp(r'''filename\*\s*=\s*UTF-8''([^;]+)''',
            caseSensitive: false)
        .firstMatch(header);
    if (star != null) {
      try {
        final decoded = Uri.decodeComponent(star.group(1)!.trim());
        if (decoded.isNotEmpty) return sanitizeFileName(decoded);
      } catch (_) {}
    }
    final plain =
        RegExp(r'''filename\s*=\s*("([^"]+)"|([^;]+))''', caseSensitive: false)
            .firstMatch(header);
    if (plain != null) {
      final raw = (plain.group(2) ?? plain.group(3) ?? '').trim();
      if (raw.isNotEmpty) return sanitizeFileName(raw);
    }
    return null;
  }

  /// Last path segment of [url], or a timestamped fallback.
  static String fileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final seg = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
      final clean = sanitizeFileName(Uri.decodeComponent(seg));
      if (clean.isNotEmpty) return clean;
    } catch (_) {}
    return 'download-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Strips path separators / control chars; never returns empty.
  static String sanitizeFileName(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_');
    s = s.replaceAll(RegExp(r'_+'), '_');
    if (s.isEmpty) return 'download-${DateTime.now().millisecondsSinceEpoch}';
    if (s.length > 120) {
      final dot = s.lastIndexOf('.');
      if (dot > 100) return s.substring(0, 120);
      s = s.substring(0, 120 - (s.length - dot)) + s.substring(dot);
    }
    return s;
  }
}

class _ResolvedResponse {
  final Stream<List<int>> stream;
  final Map<String, String> headers;
  final String requestUrl;
  _ResolvedResponse({
    required this.stream,
    required this.headers,
    required this.requestUrl,
  });
}

class _SessionExpired implements Exception {
  const _SessionExpired();
}

/// File extensions treated as downloads when a portal navigation ends
/// with one.
const portalDownloadExts = [
  '.pdf',
  '.doc',
  '.docx',
  '.xls',
  '.xlsx',
  '.ppt',
  '.pptx',
  '.csv',
  '.txt',
  '.zip',
  '.rar',
  '.7z',
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.webp',
  '.mp4',
  '.mp3',
];

/// True for navigations that fetch a file rather than a portal page:
/// Odoo binary/report endpoints, `?download=` links and file extensions.
/// Anything else (dashboards, login, blob:) is left to the WebView.
bool isPortalDownloadUrl(Uri uri) {
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  final path = uri.path.toLowerCase();
  if (path.contains('/web/content') || path.contains('/web/binary')) {
    return true;
  }
  if (path.contains('/report/pdf') || path.contains('/report/text')) {
    return true;
  }
  if (uri.query.toLowerCase().contains('download')) return true;
  for (final ext in portalDownloadExts) {
    if (path.endsWith(ext)) return true;
  }
  return false;
}
