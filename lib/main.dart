import 'package:flutter/material.dart';
import 'app.dart';
import 'auth/page_cache.dart';

void main() {
  // On-disk portal snapshots make offline restarts show real content.
  PageCache.diskEnabled = true;
  runApp(const CampusApp());
}
