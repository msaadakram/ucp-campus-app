import 'package:flutter/material.dart';
import 'app.dart';
import 'auth/page_cache.dart';
import 'auth/prefs_store.dart';
import 'screens/profile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
