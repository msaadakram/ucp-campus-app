import 'package:flutter/material.dart';

/// Deterministic per-user avatars from the bundled `assets/avatars/` set.
///
/// Identity key: the visible author name/email the backend already sends
/// with posts, comments and reviews (payloads carry no emails, so no
/// schema change was needed). Same key -> same avatar forever, with zero
/// storage and zero uploads:
///
/// ```dart
/// avatarIndex = stableHash(userKey) % avatarCount
/// ```
///
/// The signed-in user's own spots (composer, "you" reviews) use their
/// account email, so everyone — including you — gets a stable default.
class UserAvatars {
  /// Must match the generated files `assets/avatars/avatar_001.png` …
  static const int count = 72;

  /// Stable DJB2 hash: identical on every device, every launch.
  /// Never `Object.hashCode` (it is randomized per run).
  static int stableHash(String key) {
    var h = 5381;
    for (var i = 0; i < key.length; i++) {
      h = ((h << 5) + h + key.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return h;
  }

  /// 0-based index for any identity string. Empty/blank keys map to the
  /// first avatar instead of throwing.
  static int indexFor(String? key) {
    final k = (key ?? '').trim().toLowerCase();
    if (k.isEmpty) return 0;
    return stableHash(k) % count;
  }

  /// Asset path, e.g. `assets/avatars/avatar_007.png`.
  static String assetFor(String? key) {
    final n = indexFor(key) + 1;
    return 'assets/avatars/avatar_${n.toString().padLeft(3, '0')}.png';
  }
}

/// Circular profile image with a graceful initial-letter fallback.
///
/// The PNGs are opaque illustrations, so they read well in light and dark
/// mode alike. If an asset is ever missing, the fallback keeps layout,
/// size and shape identical.
class UserAvatar extends StatelessWidget {
  /// Stable identity: author name, reviewer name, or account email.
  final String? userKey;

  /// Display name used only for the fallback initial.
  final String fallbackName;
  final double radius;

  const UserAvatar({
    super.key,
    required this.userKey,
    this.fallbackName = '',
    this.radius = 15,
  });

  @override
  Widget build(BuildContext context) {
    final name = fallbackName.isNotEmpty ? fallbackName : (userKey ?? '');
    final initial =
        name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Image.asset(
          UserAvatars.assetFor(userKey),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => Container(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.14),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
