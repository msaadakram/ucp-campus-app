import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import 'common.dart';

/// Modern loading system: bouncing campus dots + shimmer skeletons.
///
/// Dependency-free (no new packages). Used by:
/// - Community feed initial load ([CommunityFeedSkeleton])
/// - Portal screens via [PortalLoading] ([PortalListSkeleton])
/// - Any inline wait via [ModernLoader].
class ModernLoader extends StatefulWidget {
  final String? message;
  final double dotSize;
  const ModernLoader({super.key, this.message, this.dotSize = 12});

  @override
  State<ModernLoader> createState() => _ModernLoaderState();
}

class _ModernLoaderState extends State<ModernLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final dots = [c.teal, c.clay, c.board];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  _Dot(
                    color: dots[i],
                    size: widget.dotSize,
                    // Staggered bounce: each dot offset by 1/3 phase.
                    t: ((_ctrl.value + i / 3) % 1.0),
                  ),
              ],
            );
          },
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.message!,
            style: body(c,
                size: 13,
                weight: FontWeight.w600,
                color: c.tealInk.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 12),
        _ShimmerBar(controller: _ctrl, color: c.teal),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final double size;
  final double t;
  const _Dot({required this.color, required this.size, required this.t});

  @override
  Widget build(BuildContext context) {
    // 0..1..0 bounce + fade, staggered by caller.
    final bounce = math.sin(t * math.pi * 2) * 0.5 + 0.5;
    final dy = -8 * math.sin(t * math.pi);
    final scale = 0.7 + 0.45 * bounce;
    return Transform.translate(
      offset: Offset(0, dy),
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: size,
          height: size,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.55 + 0.45 * bounce),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin gradient sweep driven by the parent loader controller.
class _ShimmerBar extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  const _ShimmerBar({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, _) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    color.withValues(alpha: 0.15),
                    color.withValues(alpha: 0.7),
                    color.withValues(alpha: 0.15),
                  ],
                  stops: [
                    (controller.value - 0.35).clamp(0.0, 1.0),
                    controller.value.clamp(0.0, 1.0),
                    (controller.value + 0.35).clamp(0.0, 1.0),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Pulsing placeholder block for skeleton cards.
class ShimmerBlock extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  final Color? color;
  const ShimmerBlock(
      {super.key, this.width, required this.height, this.radius = 10, this.color});

  @override
  State<ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        return Opacity(
          opacity: 0.45 + 0.4 * _ctrl.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.color ?? c.dustSoft.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton post cards shown while the community feed loads.
/// Keeps the header + Post entry points visible (never a bare spinner).
class CommunityFeedSkeleton extends StatelessWidget {
  final int count;
  const CommunityFeedSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Column(
      children: [
        const SizedBox(height: 12),
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: ModernLoader(message: 'Loading campus feed…'),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: c.white, borderRadius: BorderRadius.circular(24)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShimmerBlock(width: 32, height: 32, radius: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBlock(width: 120, height: 12),
                          SizedBox(height: 6),
                          ShimmerBlock(width: 70, height: 10),
                        ],
                      ),
                    ),
                    ShimmerBlock(width: 52, height: 22, radius: 12),
                  ],
                ),
                SizedBox(height: 12),
                ShimmerBlock(width: double.infinity, height: 16),
                SizedBox(height: 8),
                ShimmerBlock(width: double.infinity, height: 12),
                SizedBox(height: 8),
                ShimmerBlock(width: 180, height: 12),
                SizedBox(height: 12),
                ShimmerBlock(width: double.infinity, height: 120, radius: 16),
              ],
            ),
          ),
      ],
    );
  }
}

/// Generic skeleton list for portal screens (timetable/attendance/fees).
class PortalListSkeleton extends StatelessWidget {
  final String title;
  final String subtitle;
  final int cards;
  final bool heroCard;
  const PortalListSkeleton({
    super.key,
    required this.title,
    required this.subtitle,
    this.cards = 3,
    this.heroCard = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return UHead(
      height: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: display(c, size: 28, color: Colors.white),
              overflow: TextOverflow.ellipsis),
          Text(subtitle,
              style: body(c,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.78)),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: ModernLoader(),
            ),
          ),
          const SizedBox(height: 8),
          if (heroCard)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: c.tealInk,
                  borderRadius: BorderRadius.circular(24)),
              child: const Row(
                children: [
                  ShimmerBlock(width: 64, height: 64, radius: 32),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBlock(width: 150, height: 16),
                        SizedBox(height: 8),
                        ShimmerBlock(width: double.infinity, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (heroCard) const SizedBox(height: 12),
          for (var i = 0; i < cards; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: c.white,
                  borderRadius: BorderRadius.circular(24)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBlock(width: 160, height: 14),
                  SizedBox(height: 8),
                  ShimmerBlock(width: double.infinity, height: 12),
                  SizedBox(height: 6),
                  ShimmerBlock(width: 120, height: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
