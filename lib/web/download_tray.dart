import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/common.dart';

import 'portal_downloader.dart';

/// Human-readable byte size, e.g. `1.2 MB`.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var v = bytes.toDouble();
  var u = 0;
  while (v >= 1024 && u < units.length - 1) {
    v /= 1024;
    u++;
  }
  return v >= 100 || u == 0
      ? '${v.toStringAsFixed(0)} ${units[u]}'
      : '${v.toStringAsFixed(1)} ${units[u]}';
}

IconData iconForFileName(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
  if (n.endsWith('.doc') || n.endsWith('.docx')) {
    return Icons.description_outlined;
  }
  if (n.endsWith('.xls') || n.endsWith('.xlsx') || n.endsWith('.csv')) {
    return Icons.table_chart_outlined;
  }
  if (n.endsWith('.ppt') || n.endsWith('.pptx')) {
    return Icons.slideshow_outlined;
  }
  if (n.endsWith('.zip') || n.endsWith('.rar') || n.endsWith('.7z')) {
    return Icons.folder_zip_outlined;
  }
  if (n.endsWith('.jpg') ||
      n.endsWith('.jpeg') ||
      n.endsWith('.png') ||
      n.endsWith('.gif') ||
      n.endsWith('.webp')) {
    return Icons.image_outlined;
  }
  if (n.endsWith('.mp4')) return Icons.movie_outlined;
  if (n.endsWith('.mp3')) return Icons.audio_file_outlined;
  if (n.endsWith('.txt')) return Icons.text_snippet_outlined;
  return Icons.insert_drive_file_outlined;
}

/// Chrome-like bottom download bar: live progress while downloading,
/// Open action when complete, retry hint on failure.
class DownloadBar extends StatelessWidget {
  final PortalDownload item;
  final VoidCallback? onOpen;
  final VoidCallback? onCancel;
  final VoidCallback? onDismiss;
  final VoidCallback? onShowAll;

  const DownloadBar({
    super.key,
    required this.item,
    this.onOpen,
    this.onCancel,
    this.onDismiss,
    this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final d = item;
    final pct = d.progress;
    final subtitle = switch (d.status) {
      DownloadStatus.downloading =>
        pct >= 0
            ? '${(pct * 100).toStringAsFixed(0)}% · ${formatBytes(d.receivedBytes)} of ${formatBytes(d.totalBytes)}'
            : '${formatBytes(d.receivedBytes)} downloaded…',
      DownloadStatus.queued => 'Waiting to download…',
      DownloadStatus.complete =>
        'Download complete · ${formatBytes(d.receivedBytes)}',
      DownloadStatus.failed => d.error ?? 'Download failed.',
      DownloadStatus.canceled => 'Download canceled.',
    };
    final c = AppScope.colorsOf(context);
    return Material(
      // The card surface, so the tray follows light/dark like every other
      // surface in the app (it used to be a fixed dark grey).
      color: c.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 6,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: d.status == DownloadStatus.complete ? onOpen : onShowAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _Leading(item: d),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          d.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.tealInk,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.tealInk.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (d.isActive)
                    IconButton(
                      tooltip: 'Cancel download',
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: c.tealInk.withValues(alpha: 0.7),
                      ),
                      onPressed: onCancel,
                    )
                  else if (d.status == DownloadStatus.complete)
                    TextButton(
                      onPressed: onOpen,
                      child: Text(
                        'OPEN',
                        style: TextStyle(
                          color: c.tealInk,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      tooltip: 'Dismiss',
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: c.tealInk.withValues(alpha: 0.7),
                      ),
                      onPressed: onDismiss,
                    ),
                ],
              ),
              if (d.status == DownloadStatus.downloading)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: pct >= 0 ? pct : null,
                      backgroundColor: c.dustSoft,
                      valueColor: AlwaysStoppedAnimation<Color>(c.teal),
                      minHeight: 3,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  final PortalDownload item;
  const _Leading({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final d = item;
    if (d.status == DownloadStatus.downloading ||
        d.status == DownloadStatus.queued) {
      final pct = d.progress;
      return SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: pct >= 0 ? pct : null,
              strokeWidth: 3,
              color: c.teal,
              backgroundColor: c.dustSoft,
            ),
            Icon(Icons.arrow_downward, size: 16, color: c.tealInk),
          ],
        ),
      );
    }
    if (d.status == DownloadStatus.complete) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: c.clay,
        child: Icon(Icons.check, size: 20, color: c.white),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: c.clay.withValues(alpha: 0.25),
      child: Icon(Icons.error_outline, size: 20, color: c.clay),
    );
  }
}

/// Toolbar download button with an activity badge, Chrome-style.
class DownloadIconButton extends StatelessWidget {
  final int activeCount;
  final int pendingCount;
  final VoidCallback onTap;

  const DownloadIconButton({
    super.key,
    required this.activeCount,
    required this.pendingCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final badge = activeCount > 0 ? '$activeCount' : null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Downloads',
          padding: EdgeInsets.zero,
          iconSize: 20,
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const Size(32, 32),
          ),
          color: c.tealInk,
          icon: const Icon(Icons.download_outlined),
          onPressed: onTap,
        ),
        if (badge != null)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: c.teal,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: c.tealInk,
                ),
              ),
            ),
          )
        else if (pendingCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF81C995),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

/// Full download manager bottom sheet.
class DownloadsSheet extends StatefulWidget {
  final List<PortalDownload> initial;
  final Stream<PortalDownload> updates;
  final Future<void> Function(PortalDownload item) onOpen;
  final void Function(PortalDownload item) onCancel;
  final void Function(PortalDownload item) onRetry;
  final Future<void> Function(PortalDownload item) onDelete;
  final Future<void> Function(PortalDownload item) onSaveToPublic;
  final String saveLocationLabel;

  const DownloadsSheet({
    super.key,
    required this.initial,
    required this.updates,
    required this.onOpen,
    required this.onCancel,
    required this.onRetry,
    required this.onDelete,
    required this.onSaveToPublic,
    required this.saveLocationLabel,
  });

  @override
  State<DownloadsSheet> createState() => _DownloadsSheetState();
}

class _DownloadsSheetState extends State<DownloadsSheet> {
  late final Map<String, PortalDownload> _items;
  StreamSubscription<PortalDownload>? _sub;

  @override
  void initState() {
    super.initState();
    _items = {for (final d in widget.initial) d.id: d};
    _sub = widget.updates.listen((d) {
      if (!mounted) return;
      setState(() => _items[d.id] = d);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordered = _items.values.toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Downloads',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Text(
              'Saved to ${widget.saveLocationLabel}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            if (ordered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No downloads yet.')),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: ordered.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (_, i) => _RowTile(
                    item: ordered[i],
                    onOpen: () => widget.onOpen(ordered[i]),
                    onCancel: () => widget.onCancel(ordered[i]),
                    onRetry: () => widget.onRetry(ordered[i]),
                    onSaveToPublic: () => widget.onSaveToPublic(ordered[i]),
                    onDelete: () async {
                      await widget.onDelete(ordered[i]);
                      if (mounted) {
                        setState(() => _items.remove(ordered[i].id));
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  final PortalDownload item;
  final VoidCallback onOpen;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final VoidCallback onSaveToPublic;
  final VoidCallback onDelete;

  const _RowTile({
    required this.item,
    required this.onOpen,
    required this.onCancel,
    required this.onRetry,
    required this.onSaveToPublic,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final d = item;
    final pct = d.progress;
    // Exact save location so "where is my file?" is never a mystery.
    final location = d.status == DownloadStatus.complete
        ? (d.publicPath != null
              ? 'Download/UCP · ${formatBytes(d.receivedBytes)}'
              : 'App files · ${formatBytes(d.receivedBytes)}')
        : null;
    final detail = switch (d.status) {
      DownloadStatus.downloading =>
        pct >= 0
            ? '${(pct * 100).toStringAsFixed(0)}% · ${formatBytes(d.receivedBytes)} of ${formatBytes(d.totalBytes)}'
            : '${formatBytes(d.receivedBytes)} downloaded…',
      DownloadStatus.queued => 'Waiting…',
      DownloadStatus.complete => 'Completed · $location',
      DownloadStatus.failed => d.error ?? 'Failed.',
      DownloadStatus.canceled => 'Canceled.',
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        iconForFileName(d.fileName),
        size: 32,
        color: Colors.teal.shade700,
      ),
      title: Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (d.status == DownloadStatus.downloading)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(
                value: pct >= 0 ? pct : null,
                minHeight: 3,
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (d.isActive)
            IconButton(
              tooltip: 'Cancel',
              icon: const Icon(Icons.close),
              onPressed: onCancel,
            )
          else ...[
            if (d.status == DownloadStatus.complete) ...[
              IconButton(
                tooltip: 'Open',
                icon: const Icon(Icons.open_in_new_outlined),
                onPressed: onOpen,
              ),
              // Still in app files only: one tap moves it to Downloads.
              if (d.publicPath == null && d.filePath != null)
                IconButton(
                  tooltip: 'Save to Downloads',
                  icon: const Icon(Icons.drive_folder_upload_outlined),
                  onPressed: onSaveToPublic,
                ),
            ],
            if (d.status == DownloadStatus.failed ||
                d.status == DownloadStatus.canceled)
              IconButton(
                tooltip: 'Retry',
                icon: const Icon(Icons.refresh),
                onPressed: onRetry,
              ),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}
