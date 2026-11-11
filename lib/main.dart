import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'auth/page_cache.dart';
import 'auth/prefs_store.dart';
import 'screens/profile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Production resilience: a widget that throws during build must NEVER
  // leave the student staring at a flat gray release screen. Render a
  // branded retry card instead (keeps the red debug overlay in debug).
  if (kReleaseMode) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      debugPrint('release-build widget error: ${details.exceptionAsString()}');
      return const _ReleaseErrorCard();
    };
  }
  // Fonts are fetched at runtime by default — never let that happen
  // (offline cold starts must render fast, and no silent third-party
  // calls to Google on first open).
  GoogleFonts.config.allowRuntimeFetching = false;
  // On-disk portal snapshots make offline restarts show real content.
  PageCache.diskEnabled = true;
  // Saved theme BEFORE the first frame: splash, restoring view and login
  // already paint dark/light correctly — never a light-mode flash.
  // Bounded so a slow keystore can never stall launch.
  ProfilePrefs initialPrefs;
  try {
    initialPrefs = await PrefsStore()
        .loadPrefs()
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    initialPrefs = ProfilePrefs();
  }
  runApp(CampusApp(initialPrefs: initialPrefs));
}

/// Shown in release builds when a widget throws during build. Deliberately
/// dependency-free (no AppScope, no theme) — it must render even if the
/// surrounding tree is what failed.
class _ReleaseErrorCard extends StatelessWidget {
  const _ReleaseErrorCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF101820),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh_outlined,
                  size: 44, color: Color(0xFF66E7FF)),
              const SizedBox(height: 14),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  color: Color(0xFFF3F6F8),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Press back and try again — your data is safe.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF8C98A4),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
