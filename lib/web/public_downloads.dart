import 'dart:io';

import 'package:flutter/services.dart';

/// Copies an already-downloaded file into the phone's public Download folder
/// (`Download/UCP/` on Android) so it appears in Files / Downloads apps.
///
/// Best-effort by design: returns the public path on success, null when the
/// platform cannot do it (e.g. desktop test runs). Never throws.
class PublicDownloads {
  static const _channel = MethodChannel('ucp/downloads');

  static Future<String?> save({
    required String appFilePath,
    required String fileName,
    required String mimeType,
  }) async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await _channel.invokeMethod<String>(
        'saveToDownloads',
        {
          'path': appFilePath,
          'name': fileName,
          'mimeType': mimeType.isEmpty ? 'application/octet-stream' : mimeType,
        },
      );
      if (result == null || result.isEmpty) return null;
      return result;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
