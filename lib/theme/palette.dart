import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppPalette { skater, autumn, mono, ember, mint, leap }

extension AppPaletteX on AppPalette {
  String get label {
    switch (this) {
      case AppPalette.skater:
        return 'Skater Teal';
      case AppPalette.autumn:
        return 'Autumn Rust';
      case AppPalette.mono:
        return 'Snow Mono';
      case AppPalette.ember:
        return 'Ember Glow';
      case AppPalette.mint:
        return 'Mint Neon';
      case AppPalette.leap:
        return 'Sky Leap';
    }
  }

  String get heroAsset {
    switch (this) {
      case AppPalette.skater:
        return 'assets/heroes/hero-skater.jpg';
      case AppPalette.autumn:
        return 'assets/heroes/hero-autumn.jpg';
      case AppPalette.mono:
        return 'assets/heroes/hero-mono.jpg';
      case AppPalette.ember:
        return 'assets/heroes/hero-ember.jpg';
      case AppPalette.mint:
        return 'assets/heroes/hero-mint.jpg';
      case AppPalette.leap:
        return 'assets/heroes/hero-leap.jpg';
    }
  }

  List<Color> get swatches {
    switch (this) {
      case AppPalette.skater:
        return const [Color(0xFF1596A8), Color(0xFF7F9BAA), Color(0xFFF4EAD9), Color(0xFFE89A5B)];
      case AppPalette.autumn:
        return const [Color(0xFFC2461C), Color(0xFFD9772B), Color(0xFFF6E3D0), Color(0xFF7D93AA)];
      case AppPalette.mono:
        return const [Color(0xFF26282C), Color(0xFF7CC242), Color(0xFFE4E6E9), Color(0xFF8A8F96)];
      case AppPalette.ember:
        return const [Color(0xFFFF6A13), Color(0xFFFFB347), Color(0xFF2A2630), Color(0xFFFFF4EA)];
      case AppPalette.mint:
        return const [Color(0xFF2FA37F), Color(0xFF9BE22D), Color(0xFFEAF7F1), Color(0xFF2C3134)];
      case AppPalette.leap:
        return const [Color(0xFF1789B8), Color(0xFFF4A82A), Color(0xFF8FAE6E), Color(0xFFEE6A24)];
    }
  }
}

class AppColors {
  final Color teal;
  final Color tealDeep;
  final Color tealInk;
  final Color dust;
  final Color dustSoft;
  final Color cream;
  final Color cream2;
  final Color clay;
  final Color board;
  final Color white;
  final bool dark;

  const AppColors({
    required this.teal,
    required this.tealDeep,
    required this.tealInk,
    required this.dust,
    required this.dustSoft,
    required this.cream,
    required this.cream2,
    required this.clay,
    required this.board,
    required this.white,
    this.dark = false,
  });

  factory AppColors.of(AppPalette p, bool dark) {
    if (!dark) {
      switch (p) {
        case AppPalette.skater:
          return const AppColors(
            teal: Color(0xFF1596A8), tealDeep: Color(0xFF0C6F7D), tealInk: Color(0xFF0A3F47),
            dust: Color(0xFF7F9BAA), dustSoft: Color(0xFFDCE6EA), cream: Color(0xFFF4EAD9),
            cream2: Color(0xFFFBF6EE), clay: Color(0xFFC47A52), board: Color(0xFFE89A5B),
            white: Color(0xFFFFFFFF),
          );
        case AppPalette.autumn:
          return const AppColors(
            teal: Color(0xFFC2461C), tealDeep: Color(0xFF8F2F12), tealInk: Color(0xFF3A1C10),
            dust: Color(0xFF7D93AA), dustSoft: Color(0xFFF0D9C4), cream: Color(0xFFF6E3D0),
            cream2: Color(0xFFFDF5EC), clay: Color(0xFFB8864E), board: Color(0xFFE59A3C),
            white: Color(0xFFFFFFFF),
          );
        case AppPalette.mono:
          return const AppColors(
            teal: Color(0xFF26282C), tealDeep: Color(0xFF111214), tealInk: Color(0xFF17181B),
            dust: Color(0xFF8A8F96), dustSoft: Color(0xFFE4E6E9), cream: Color(0xFFEEF0F2),
            cream2: Color(0xFFF7F8F9), clay: Color(0xFF6FAE2E), board: Color(0xFFA8DC5C),
            white: Color(0xFFFFFFFF),
          );
        case AppPalette.ember:
          return const AppColors(
            teal: Color(0xFFFF6A13), tealDeep: Color(0xFFD9430F), tealInk: Color(0xFF2A2630),
            dust: Color(0xFF6B6272), dustSoft: Color(0xFFF6E2D3), cream: Color(0xFFFFE9D6),
            cream2: Color(0xFFFFF7F0), clay: Color(0xFFE8431C), board: Color(0xFFFFB347),
            white: Color(0xFFFFFFFF),
          );
        case AppPalette.mint:
          return const AppColors(
            teal: Color(0xFF2FA37F), tealDeep: Color(0xFF1D7A5D), tealInk: Color(0xFF1F2A27),
            dust: Color(0xFF2C3134), dustSoft: Color(0xFFD6EFE5), cream: Color(0xFFE3F6EC),
            cream2: Color(0xFFF3FBF7), clay: Color(0xFF5FB31C), board: Color(0xFF9BE22D),
            white: Color(0xFFFFFFFF),
          );
        case AppPalette.leap:
          return const AppColors(
            teal: Color(0xFF1789B8), tealDeep: Color(0xFF0F6A91), tealInk: Color(0xFF1C2C44),
            dust: Color(0xFF8FAE6E), dustSoft: Color(0xFFDBE8CF), cream: Color(0xFFE4F2F8),
            cream2: Color(0xFFF5FAFC), clay: Color(0xFFEE6A24), board: Color(0xFFF4A82A),
            white: Color(0xFFFFFFFF),
          );
      }
    }
    switch (p) {
      case AppPalette.skater:
        return const AppColors(
          teal: Color(0xFF1596A8), tealDeep: Color(0xFF0C6F7D), tealInk: Color(0xFFE9F2F3),
          dust: Color(0xFF7F9BAA), dustSoft: Color(0xFF22505A), cream: Color(0xFF1B3D44),
          cream2: Color(0xFF0B2227), clay: Color(0xFFC47A52), board: Color(0xFFE89A5B),
          white: Color(0xFF12343B), dark: true,
        );
      case AppPalette.autumn:
        return const AppColors(
          teal: Color(0xFFC2461C), tealDeep: Color(0xFF8F2F12), tealInk: Color(0xFFF8E9DC),
          dust: Color(0xFF7D93AA), dustSoft: Color(0xFF4A2A1D), cream: Color(0xFF3A2016),
          cream2: Color(0xFF1F0F09), clay: Color(0xFFB8864E), board: Color(0xFFE59A3C),
          white: Color(0xFF2E1810), dark: true,
        );
      case AppPalette.mono:
        return const AppColors(
          teal: Color(0xFF3A3D43), tealDeep: Color(0xFF111214), tealInk: Color(0xFFF1F2F4),
          dust: Color(0xFF8A8F96), dustSoft: Color(0xFF2E3136), cream: Color(0xFF25272C),
          cream2: Color(0xFF0E0F11), clay: Color(0xFF6FAE2E), board: Color(0xFFA8DC5C),
          white: Color(0xFF1B1C20), dark: true,
        );
      case AppPalette.ember:
        return const AppColors(
          teal: Color(0xFFFF6A13), tealDeep: Color(0xFFD9430F), tealInk: Color(0xFFFFF4EA),
          dust: Color(0xFF6B6272), dustSoft: Color(0xFF3D3644), cream: Color(0xFF352F3B),
          cream2: Color(0xFF1C1A21), clay: Color(0xFFE8431C), board: Color(0xFFFFB347),
          white: Color(0xFF2A2630), dark: true,
        );
      case AppPalette.mint:
        return const AppColors(
          teal: Color(0xFF2FA37F), tealDeep: Color(0xFF1D7A5D), tealInk: Color(0xFFEAF7F1),
          dust: Color(0xFF2C3134), dustSoft: Color(0xFF24403A), cream: Color(0xFF1F3530),
          cream2: Color(0xFF0F1A17), clay: Color(0xFF5FB31C), board: Color(0xFF9BE22D),
          white: Color(0xFF182824), dark: true,
        );
      case AppPalette.leap:
        return const AppColors(
          teal: Color(0xFF1789B8), tealDeep: Color(0xFF0F6A91), tealInk: Color(0xFFE8F3F8),
          dust: Color(0xFF8FAE6E), dustSoft: Color(0xFF243D50), cream: Color(0xFF1B3142),
          cream2: Color(0xFF0D1A24), clay: Color(0xFFEE6A24), board: Color(0xFFF4A82A),
          white: Color(0xFF152634), dark: true,
        );
    }
  }
}

class AppPrefs {
  AppPalette palette;
  bool dark;
  bool bigText;
  AppPrefs({this.palette = AppPalette.skater, this.dark = false, this.bigText = false});
}

TextStyle display(AppColors c, {double size = 20, FontWeight weight = FontWeight.w800, Color? color}) {
  return GoogleFonts.bricolageGrotesque(
    fontSize: size, fontWeight: weight, color: color ?? c.tealInk, letterSpacing: -0.5,
  );
}

TextStyle body(AppColors c, {double size = 14, FontWeight weight = FontWeight.w400, Color? color}) {
  return GoogleFonts.figtree(fontSize: size, fontWeight: weight, color: color ?? c.tealInk);
}
