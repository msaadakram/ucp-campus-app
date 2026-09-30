import 'package:flutter/material.dart';
import '../theme/palette.dart';

/// U-shaped teal header band behind page titles — mirrors `.u-head::before`.
class UHead extends StatelessWidget {
  final double height;
  final Widget child;
  final EdgeInsetsGeometry padding;
  const UHead({super.key, required this.height, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 24)});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      primary: false,
      child: Stack(
        children: [
          _BandInner(height: height, fallback: null),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _BandInner extends StatelessWidget {
  final double height;
  final AppColors? fallback;
  const _BandInner({required this.height, this.fallback});
  @override
  Widget build(BuildContext context) {
    final app = _AppScope.of(context);
    final c = app?.colors ?? fallback ?? AppColors.of(AppPalette.skater, false);
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [c.tealDeep, c.teal],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.elliptical(220, 44),
          bottomRight: Radius.elliptical(220, 44),
        ),
      ),
    );
  }
}

class _AppScope extends InheritedWidget {
  final AppColors colors;
  final AppPalette palette;
  const _AppScope({required super.child, required this.colors, required this.palette});
  static _AppScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_AppScope>();
  @override
  bool updateShouldNotify(_AppScope old) => old.colors != colors || old.palette != palette;
}

class AppScope extends StatelessWidget {
  final AppColors colors;
  final AppPalette palette;
  final Widget child;
  const AppScope({super.key, required this.colors, required this.palette, required this.child});
  static AppColors colorsOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AppScope>()?.colors ?? AppColors.of(AppPalette.skater, false);
  static AppPalette paletteOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AppScope>()?.palette ?? AppPalette.skater;
  @override
  Widget build(BuildContext context) => _AppScope(colors: colors, palette: palette, child: child);
}

class ProgressRing extends StatelessWidget {
  final int value;
  final Color color;
  const ProgressRing({super.key, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44, height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 44, height: 44,
            child: CircularProgressIndicator(
              value: value / 100, strokeWidth: 5,
              backgroundColor: color.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text('$value', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}

class AppToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppColors colors;
  const AppToggle({super.key, required this.value, required this.onChanged, required this.colors});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 48, height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: value ? colors.teal : colors.dustSoft,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(4),
            width: 20, height: 20,
            decoration: BoxDecoration(color: colors.cream2, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)]),
          ),
        ),
      ),
    );
  }
}

class ClayButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppColors colors;
  final double height;
  final double fontSize;
  const ClayButton({super.key, required this.label, required this.onPressed, required this.colors, this.height = 56, this.fontSize = 18});
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: colors.tealInk,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: colors.clay, offset: const Offset(0, 6), blurRadius: 0)],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Center(
              child: Text(label, style: display(colors, size: fontSize, color: colors.cream)),
            ),
          ),
        ),
      ),
    );
  }
}

class WhiteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const WhiteCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 24});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(radius)),
      child: child,
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 24),
      child: Text(text.toUpperCase(), style: body(c, size: 12, weight: FontWeight.w600, color: c.tealInk.withValues(alpha: 0.55))),
    );
  }
}

class SettingRow extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String label;
  final String? sub;
  final Widget? trailing;
  const SettingRow({super.key, required this.icon, required this.tone, required this.label, this.sub, this.trailing});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.dustSoft))),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: body(c, size: 14, weight: FontWeight.w600)),
                if (sub != null) Text(sub!, style: body(c, size: 12, color: c.tealInk.withValues(alpha: 0.55))),
              ],
            ),
          ),
          trailing ?? Icon(Icons.chevron_right, color: c.tealInk.withValues(alpha: 0.4)),
        ],
      ),
    );
  }
}
