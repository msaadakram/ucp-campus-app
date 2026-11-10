import 'dart:convert';
import 'dart:typed_data';

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


/// Builds an [ImageProvider] for a portal avatar string, or null when the
/// value is unusable. Accepts:
///   - `data:image/...;base64,...` (Odoo emits these inline; classmates
///     render them with zero auth),
///   - absolute `http(s)://…` URLs (own session can usually read these),
///   - everything else returns null — callers fall back to their asset.
ImageProvider? portalAvatarProvider(String? src) {
  final s = (src ?? '').trim();
  if (s.isEmpty) return null;
  final lower = s.toLowerCase();
  if (lower.startsWith('data:image/')) {
    final comma = s.indexOf(',');
    if (comma <= 0 || comma == s.length - 1) return null;
    try {
      final bytes = base64Decode(s.substring(comma + 1));
      if (bytes.isEmpty) return null;
      return MemoryImage(Uint8List.fromList(bytes));
    } catch (_) {
      return null;
    }
  }
  if (s.startsWith('https://') || s.startsWith('http://')) {
    return NetworkImage(s);
  }
  return null;
}

/// Circular avatar that prefers a portal image (data URI or URL) and
/// falls back to [fallbackAsset] — the palette's hero art — when the
/// portal has none or it fails to load. Used for the home header and the
/// navigation drawer.
class PortalAvatar extends StatefulWidget {
  final String? src;
  final double radius;
  final String fallbackAsset;
  final BoxFit fit;

  const PortalAvatar({
    super.key,
    required this.src,
    required this.radius,
    required this.fallbackAsset,
    this.fit = BoxFit.cover,
  });

  @override
  State<PortalAvatar> createState() => _PortalAvatarState();
}

class _PortalAvatarState extends State<PortalAvatar> {
  bool _failed = false;

  @override
  void didUpdateWidget(covariant PortalAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src && _failed) {
      setState(() => _failed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = portalAvatarProvider(widget.src);
    if (provider == null || _failed) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundImage: AssetImage(widget.fallbackAsset),
      );
    }
    return CircleAvatar(
      radius: widget.radius,
      backgroundImage: provider,
      onBackgroundImageError: (_, _) => setState(() => _failed = true),
    );
  }
}

/// Circular avatar for leaderboard rows/podiums: prefers the portal
/// image, falls back to [fallbackInitial] text when missing or broken
/// (mirror of the previous inline behavior, now data-URI aware).
class LeaderboardAvatar extends StatefulWidget {
  final String? src;
  final double radius;
  final String initial;
  final Color ring;
  final Color tone;

  const LeaderboardAvatar({
    super.key,
    required this.src,
    required this.radius,
    required this.initial,
    required this.ring,
    required this.tone,
  });

  @override
  State<LeaderboardAvatar> createState() => _LeaderboardAvatarState();
}

class _LeaderboardAvatarState extends State<LeaderboardAvatar> {
  bool _failed = false;

  @override
  void didUpdateWidget(covariant LeaderboardAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src && _failed) {
      setState(() => _failed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = portalAvatarProvider(widget.src);
    if (provider == null || _failed) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.ring,
        child: Text(
          widget.initial,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: widget.tone,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.ring,
      foregroundImage: provider,
      onForegroundImageError: (_, _) => setState(() => _failed = true),
    );
  }
}
