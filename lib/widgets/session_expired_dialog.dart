import 'package:flutter/material.dart';

import '../theme/palette.dart';
import 'common.dart';

/// Shown when the portal session dies while the app is open — most often
/// because the same account signed in somewhere else (e.g. the laptop).
///
/// Two choices: [onLoginNow] drops straight into the interactive Microsoft
/// sign-in to mint fresh cookies; [onLater] dismisses and keeps the app
/// usable offline until the next automatic retry.
class SessionExpiredDialog extends StatelessWidget {
  final String message;
  /// Raw failure code (e.g. `login_required`) shown tiny for diagnosis.
  final String? detail;
  final VoidCallback onLoginNow;
  final VoidCallback onLater;

  const SessionExpiredDialog({
    super.key,
    required this.message,
    this.detail,
    required this.onLoginNow,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Container(
      color: c.tealInk.withValues(alpha: 0.45),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: c.cream2,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: c.clay.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_outlined,
                    size: 28,
                    color: c.clay,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Session expired',
                  style: display(c, size: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: body(
                    c,
                    size: 14,
                    color: c.tealInk.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Someone may have signed in on another device, such as your laptop.',
                  style: body(
                    c,
                    size: 12,
                    color: c.tealInk.withValues(alpha: 0.55),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ClayButton(
                  label: 'Login here now',
                  colors: c,
                  height: 52,
                  fontSize: 16,
                  onPressed: onLoginNow,
                ),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'diagnostic: $detail',
                    style: body(
                      c,
                      size: 11,
                      color: c.tealInk.withValues(alpha: 0.45),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onLater,
                  child: Text(
                    'Later',
                    style: body(c, size: 14, weight: FontWeight.w600, color: c.teal),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
