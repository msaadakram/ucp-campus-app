import 'package:flutter/material.dart';

import '../auth/offline.dart';
import '../theme/palette.dart';
import 'common.dart';

/// App-wide "no internet" pill. Overlays the top of every screen (login
/// included) while [OfflineMonitor] reports offline; hidden otherwise.
/// Non-interactive so it never blocks taps. `forceShow` is a test seam.
class OfflineBanner extends StatelessWidget {
  final bool? forceShow;
  const OfflineBanner({super.key, this.forceShow});

  @override
  Widget build(BuildContext context) {
    if (forceShow != null) {
      return forceShow! ? _pill(AppScope.colorsOf(context)) : const SizedBox.shrink();
    }
    return ValueListenableBuilder<bool>(
      valueListenable: OfflineMonitor.instance.offline,
      builder: (_, off, __) =>
          off ? _pill(AppScope.colorsOf(context)) : const SizedBox.shrink(),
    );
  }

  Widget _pill(AppColors c) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: c.tealInk,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_outlined, size: 16, color: Colors.white),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'You’re offline — showing saved data',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
