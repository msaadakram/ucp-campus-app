import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../widgets/common.dart';
import 'loading.dart';

/// Loading / error states shared by the portal-backed screens (timetable,
/// attendance, fees, results). Each screen fetches its own page; these keep
/// the states visually consistent.
class PortalLoading extends StatelessWidget {
  final String title;
  final String subtitle;
  const PortalLoading({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return PortalListSkeleton(
      title: title,
      subtitle: subtitle,
      heroCard: true,
    );
  }
}

class PortalError extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onRelogin;
  const PortalError({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.onRelogin,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return UHead(
      height: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: display(c, size: 28, color: Colors.white)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: c.white, borderRadius: BorderRadius.circular(24)),
            child: Column(
              children: [
                Icon(Icons.cloud_off_outlined, size: 36, color: c.clay),
                const SizedBox(height: 12),
                Text(message,
                    textAlign: TextAlign.center,
                    style: body(c, size: 14)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onRetry,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                              color: c.teal,
                              borderRadius: BorderRadius.circular(16)),
                          child: const Text('Retry',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    if (onRelogin != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onRelogin,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                                color: c.tealInk,
                                borderRadius: BorderRadius.circular(16)),
                            child: const Text('Re-login',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
