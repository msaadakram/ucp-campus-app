import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Message shown whenever the device has no usable internet.
const offlineMessage =
    "You're offline. Showing your saved data — connect and tap Retry for the latest.";

const offlineLoginMessage =
    'No internet connection. Connect and try signing in again.';

/// Short "how long ago" label for cached data, e.g. `Saved 5m ago`.
/// Pure and unit-tested.
String timeAgo(int savedAtMs, [DateTime? now]) {
  final at = DateTime.fromMillisecondsSinceEpoch(savedAtMs);
  final diff = (now ?? DateTime.now()).difference(at);
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// Device internet liveness: interface state from connectivity_plus plus a
/// cheap DNS probe of the portal host (catches wifi-without-internet and
/// captive portals). Single app-wide instance; screens and the watchdog
/// read [isOffline] instead of each doing their own detection.
///
/// Never throws: every failure mode maps to "offline". Stays `false`
/// (online) until [start] runs, so widget tests without platform channels
/// behave as online.
class OfflineMonitor {
  static OfflineMonitor? _instance;
  static OfflineMonitor get instance => _instance ??= OfflineMonitor._();

  @visibleForTesting
  static void debugOverride(OfflineMonitor monitor) => _instance = monitor;

  @visibleForTesting
  static void resetDebug() => _instance = null;

  final Future<List<ConnectivityResult>> Function() _check;
  final Stream<List<ConnectivityResult>> _changes;
  final Future<bool> Function() _probe;

  /// Last known state. Notifier so banners and screens repaint on change.
  final ValueNotifier<bool> offline = ValueNotifier(false);
  bool get isOffline => offline.value;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  int _epoch = 0;
  bool _started = false;

  OfflineMonitor._()
      : _check = Connectivity().checkConnectivity,
        _changes = Connectivity().onConnectivityChanged,
        _probe = _defaultProbe;

  @visibleForTesting
  OfflineMonitor.debug({
    Future<List<ConnectivityResult>> Function()? check,
    Stream<List<ConnectivityResult>>? changes,
    Future<bool> Function()? probe,
  })  : _check = check ?? (() async => [ConnectivityResult.wifi]),
        _changes = changes ?? const Stream.empty(),
        _probe = probe ?? (() async => true);

  static Future<bool> _defaultProbe() async {
    try {
      final found = await InternetAddress.lookup('horizon.ucp.edu.pk')
          .timeout(const Duration(seconds: 5));
      return found.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Begins listening. Idempotent; safe to call from app init and resume.
  void start() {
    if (_started) {
      unawaited(refresh());
      return;
    }
    _started = true;
    _sub = _changes.listen((_) => unawaited(refresh()));
    unawaited(refresh());
  }

  /// One liveness pass. Stale overlapping passes are discarded.
  Future<void> refresh() async {
    final my = ++_epoch;
    bool off;
    try {
      final status = await _check().timeout(const Duration(seconds: 5));
      if (status.contains(ConnectivityResult.none) || status.isEmpty) {
        off = true;
      } else {
        off = !(await _probe().timeout(const Duration(seconds: 6)));
      }
    } catch (_) {
      // Platform channel missing (tests) or any probe failure: offline.
      // In real widget-test environments start() is never called, so this
      // path only triggers when refresh is forced explicitly.
      off = true;
    }
    if (my != _epoch || !_started) return;
    offline.value = off;
  }

  void stop() {
    _started = false;
    _epoch++;
    unawaited(_sub?.cancel());
    _sub = null;
  }
}
