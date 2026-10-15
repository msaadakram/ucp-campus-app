import 'package:flutter/material.dart';

import '../theme/palette.dart';
import 'common.dart';

/// Shown when the portal session dies while the app is open — most often
/// because the same account signed in somewhere else (e.g. the laptop).
///
/// Two choices: [onLoginNow] drops straight into the interactive Microsoft
/// sign-in (same flow as app-open login) to mint fresh cookies;
/// [onLater] ("Stay logged out") dismisses and keeps the app usable on
/// saved data with no cookie refresh until the user asks. The stored
/// session is never wiped here, so the next app launch retries auto
/// sign-in on its own.
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
    // Compact by design: icon, title, message and BOTH actions fit
    // above the fold on small phones — no scrolling to reach a button.
    // The scroll view is only a safety net for huge text scales.
    return Container(
      color: c.tealInk.withValues(alpha: 0.45),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.cream2,
              borderRadius: BorderRadius.circular(28),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: c.clay.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_outlined,
                    size: 24,
                    color: c.clay,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Session expired',
                  style: display(c, size: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: body(
                    c,
                    size: 13,
                    color: c.tealInk.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ClayButton(
                  label: 'Relogin now',
                  colors: c,
                  height: 48,
                  fontSize: 15,
                  onPressed: onLoginNow,
                ),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: 6),
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
                TextButton(
                  onPressed: onLater,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Stay logged out',
                    style: body(c, size: 14, weight: FontWeight.w600, color: c.teal),
                  ),
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
