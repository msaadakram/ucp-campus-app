import 'package:flutter_test/flutter_test.dart';
import 'package:ucp/screens/profile.dart';
import 'package:ucp/theme/palette.dart';

void main() {
  group('ProfilePrefs persistence snapshot', () {
    test('round-trips a customized theme', () {
      final prefs = ProfilePrefs();
      prefs.theme = ThemeModePref.dark;
      final restored = ProfilePrefs.fromJson(prefs.toJson());
      expect(restored.theme, ThemeModePref.dark);
      expect(restored.palette, AppPalette.skater);
      expect(restored.big, isFalse);
      expect(restored.motion, isTrue);
    });

    test('round-trips every field', () {
      final prefs = ProfilePrefs(
        theme: ThemeModePref.system,
        palette: AppPalette.ember,
        big: true,
        motion: false,
      );
      final restored = ProfilePrefs.fromJson(prefs.toJson());
      expect(restored.theme, ThemeModePref.system);
      expect(restored.palette, AppPalette.ember);
      expect(restored.big, isTrue);
      expect(restored.motion, isFalse);
    });

    test('corrupt or unknown values fall back to defaults', () {
      final restored = ProfilePrefs.fromJson({
        'theme': 'midnight',
        'palette': 'neon',
        'big': 'yes',
      });
      expect(restored.theme, ThemeModePref.light);
      expect(restored.palette, AppPalette.skater);
      expect(restored.big, isFalse);
      expect(restored.motion, isTrue); // absent → default on
    });

    test('partial snapshot keeps saved fields', () {
      final restored = ProfilePrefs.fromJson({'theme': 'dark'});
      expect(restored.theme, ThemeModePref.dark);
      expect(restored.palette, AppPalette.skater);
    });
  });
}
