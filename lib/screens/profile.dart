import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../auth/dashboard_parser.dart';
import '../leaderboard/leaderboard_service.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';

enum ThemeModePref { light, dark, system }

class ProfilePrefs {
  ThemeModePref theme;
  AppPalette palette;
  bool big;
  bool motion;
  ProfilePrefs({this.theme = ThemeModePref.light, this.palette = AppPalette.skater, this.big = false, this.motion = true});

  /// Device snapshot so the theme survives restarts until the user
  /// changes it again (see PrefsStore). Tolerant: unknown/corrupt
  /// values fall back to defaults instead of crashing startup.
  Map<String, dynamic> toJson() => {
        'theme': theme.name,
        'palette': palette.name,
        'big': big,
        'motion': motion,
      };

  factory ProfilePrefs.fromJson(Map<String, dynamic> json) {
    var theme = ThemeModePref.light;
    try {
      theme = ThemeModePref.values.byName('${json['theme']}');
    } catch (_) {}
    var palette = AppPalette.skater;
    try {
      palette = AppPalette.values.byName('${json['palette']}');
    } catch (_) {}
    return ProfilePrefs(
      theme: theme,
      palette: palette,
      big: json['big'] == true,
      motion: json['motion'] != false,
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final VoidCallback logout;
  final ProfilePrefs prefs;
  final ValueChanged<ProfilePrefs> onPrefs;
  /// Live identity from the portal (null = bundled sample content).
  final String? studentName;
  final String? studentId;
  final String? faculty;
  final String? email;
  /// Parsed "Earned Cr" from the dashboard; drives the degree progress bar.
  final double? earnedCredits;
  const ProfileScreen(
      {super.key,
      required this.logout,
      required this.prefs,
      required this.onPrefs,
      this.studentName,
      this.studentId,
      this.faculty,
      this.email,
      this.earnedCredits});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Leaderboard privacy — lives on the SERVER so the app and the
  /// extension always agree (hiding your name here hides it everywhere).
  bool _hideName = false;
  bool _privacyLoaded = false;

  /// Reads the privacy setting (shared with the extension).
  Future<void> _loadPrivacy() async {
    final sid = (widget.studentId ?? '').trim();
    if (sid.isEmpty) return;
    try {
      final p = await NodeLeaderboardService().fetchPrivacy(sid);
      if (!mounted) return;
      setState(() {
        _hideName = p.hideName;
        _privacyLoaded = true;
      });
    } catch (_) {
      // Offline / not configured: keep the local value.
    }
  }

  /// Stores the privacy setting on the server.
  Future<void> _setHideName(bool value) async {
    final sid = (widget.studentId ?? '').trim();
    setState(() => _hideName = value);
    if (sid.isEmpty) return;
    try {
      final p = await NodeLeaderboardService()
          .savePrivacy(sid, hideName: value, hidePhoto: false);
      if (!mounted) return;
      setState(() => _hideName = p.hideName);
    } catch (_) {
      // Roll back on failure so the switch never lies.
      if (mounted) setState(() => _hideName = !value);
    }
  }
  bool push = true, assign = true, grades = true, community = false, email = true;
  bool lock = false;
  String _appVersion = '';
  /// Real on-device storage used by this app (documents + support +
  /// cache), formatted for the Downloads & storage row. Empty until the
  /// first measurement completes.
  String _storageUsed = '';

  /// Support inbox shown in Help & support.
  static const _supportEmail = 'msaadakram786@gmail.com';

  @override
  void initState() {
    super.initState();
    _loadPrivacy();
    _loadVersion();
    _loadStorage();
  }

  /// Real build version (e.g. 1.0.20) so installed APKs are identifiable.
  /// Falls back silently where package info is unavailable (tests).
  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = 'Version ${info.version}');
    } catch (_) {}
  }

  /// Total bytes under [dir], recursive; unreadable entries are skipped.
  Future<int> _dirSize(Directory dir) async {
    var total = 0;
    try {
      await for (final entry
          in dir.list(recursive: true, followLinks: false)) {
        if (entry is File) {
          try {
            total += await entry.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  /// Measures the app's real disk footprint (docs + support + temp)
  /// and updates the Downloads & storage row. Never throws: failures
  /// leave the row showing the app-size-only fallback.
  Future<void> _loadStorage() async {
    try {
      var total = 0;
      final dirs = <Directory>[
        await getApplicationDocumentsDirectory(),
        await getApplicationSupportDirectory(),
        await getTemporaryDirectory(),
      ];
      for (final d in dirs) {
        total += await _dirSize(d);
      }
      if (!mounted) return;
      setState(() => _storageUsed = _formatBytes(total));
    } catch (_) {
      if (!mounted) return;
      setState(() => _storageUsed = 'Not available');
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB used';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB used';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB used';
    }
    return '$bytes B used';
  }

  /// Help & support dialog: contact address + copy-to-clipboard.
  Future<void> _showSupport() async {
    final c = AppScope.colorsOf(context);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Help & support',
            style: display(c, size: 18), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Having a problem or a suggestion? Email us at:',
                style: body(c, size: 13)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.dustSoft.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_supportEmail,
                  textAlign: TextAlign.center,
                  style: body(c, size: 14, weight: FontWeight.w700)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: _supportEmail));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Support email copied'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Copy email'),
          ),
        ],
      ),
    );
  }

  void _set(ProfilePrefs p) => widget.onPrefs(p);

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final hero = AppScope.paletteOf(context).heroAsset;
    final name = widget.studentName ?? 'Ayaan Warraich';
    final program = programFromStudentId(widget.studentId);
    final year =
        yearFromSemester(semesterFromStudentId(widget.studentId, DateTime.now()));
    final subtitle = (program != null && year != null)
        ? '$program · Year $year'
        : 'BS Computer Science · Year 2';
    final enrolled = enrollmentFromStudentId(widget.studentId) ?? '—';
    final semester = semesterFromStudentId(widget.studentId, DateTime.now());
    final rows = [
      ['Student ID', widget.studentId ?? '2024-CS-0719'],
      ['Email', widget.email ?? 'ayaan.w@ucp.edu.pk'],
      ['Faculty', widget.faculty ?? 'Engineering & Computing'],
      ['Semester', semester == null ? '—' : 'Semester $semester'],
      ['Enrolled', enrolled],
    ];
    final earned = widget.earnedCredits ?? 0;
    final earnedLabel =
        earned == earned.roundToDouble() ? '${earned.toInt()}' : '$earned';
    final progress =
        (earned / degreeTotalCredits).clamp(0.0, 1.0);
    return SingleChildScrollView(
      primary: false,
      child: Column(
        children: [
        SizedBox(
          height: 256,
          child: Stack(
            children: [
              Positioned.fill(child: Image.asset(hero, fit: BoxFit.cover, alignment: const Alignment(0.5, -0.3))),
              Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)])))),
              Positioned(
                left: 20, bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: display(c, size: 28, color: Colors.white)),
                    Text(subtitle, style: body(c, size: 14, color: c.cream.withValues(alpha: 0.85))),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    for (final kv in rows)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(border: kv[0] == 'Enrolled' ? null : Border(bottom: BorderSide(color: c.dustSoft))),
                        child: Row(
                          children: [
                            Text(kv[0], style: body(c, size: 14, color: c.tealInk.withValues(alpha: 0.55))),
                            const SizedBox(width: 12),
                            Expanded(child: Text(kv[1], textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: body(c, size: 14, weight: FontWeight.w600))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: c.cream, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DEGREE PROGRESS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.clay)),
                    Text('$earnedLabel / ${degreeTotalCredits.toInt()} credits', style: display(c, size: 22)),
                    const SizedBox(height: 12),
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: progress, backgroundColor: c.white, valueColor: AlwaysStoppedAnimation(c.clay), minHeight: 12)),
                  ],
                ),
              ),
              const SectionLabel('Appearance'),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (final t in [(ThemeModePref.light, Icons.wb_sunny_outlined, 'Light'), (ThemeModePref.dark, Icons.dark_mode_outlined, 'Dark'), (ThemeModePref.system, Icons.smartphone_outlined, 'System')])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _set(ProfilePrefs(theme: t.$1, palette: widget.prefs.palette, big: widget.prefs.big, motion: widget.prefs.motion)),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(color: widget.prefs.theme == t.$1 ? c.teal : c.dustSoft.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(16)),
                                  child: Column(children: [Icon(t.$2, color: widget.prefs.theme == t.$1 ? Colors.white : c.tealInk), Text(t.$3, style: TextStyle(fontWeight: FontWeight.w600, color: widget.prefs.theme == t.$1 ? Colors.white : c.tealInk))]),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.fromLTRB(8, 12, 8, 8), child: Text('Color theme', style: TextStyle(fontSize: 12, color: c.tealInk.withValues(alpha: 0.55))))),
                    GridView.count(
                      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.1,
                      children: [
                        for (final p in AppPalette.values)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _set(ProfilePrefs(theme: widget.prefs.theme, palette: p, big: widget.prefs.big, motion: widget.prefs.motion)),
                            child: Container(
                              decoration: BoxDecoration(border: Border.all(color: widget.prefs.palette == p ? c.teal : Colors.transparent, width: 2), borderRadius: BorderRadius.circular(16)),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Column(
                                  children: [
                                    Expanded(child: Image.asset(p.heroAsset, fit: BoxFit.cover, width: double.infinity)),
                                    Container(
                                      width: double.infinity, padding: const EdgeInsets.all(8), color: c.dustSoft,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Row(children: [for (final s in p.swatches) Container(margin: const EdgeInsets.only(right: 2), width: 16, height: 16, decoration: BoxDecoration(color: s, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))]),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SettingRow(icon: Icons.text_fields_outlined, tone: c.board, label: 'Larger text', sub: 'Easier reading', trailing: AppToggle(value: widget.prefs.big, onChanged: (v) => _set(ProfilePrefs(theme: widget.prefs.theme, palette: widget.prefs.palette, big: v, motion: widget.prefs.motion)), colors: c)),
                    SettingRow(icon: Icons.auto_awesome_outlined, tone: c.dust, label: 'Animations', sub: 'Smooth screen transitions', trailing: AppToggle(value: widget.prefs.motion, onChanged: (v) => _set(ProfilePrefs(theme: widget.prefs.theme, palette: widget.prefs.palette, big: widget.prefs.big, motion: v)), colors: c)),
                    if ((widget.studentId ?? '').trim().isNotEmpty)
                      SettingRow(
                        icon: Icons.visibility_off_outlined,
                        tone: c.teal,
                        label: 'Hide my name on leaderboards',
                        sub: _privacyLoaded
                            ? ('Shared with the extension · ${_hideName ? 'hidden' : 'visible'}')
                            : 'Shared with the extension',
                        trailing: AppToggle(
                          value: _hideName,
                          onChanged: _setHideName,
                          colors: c,
                        ),
                      ),
                  ],
                ),
              ),
              const SectionLabel('Notifications'),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    SettingRow(icon: Icons.notifications_outlined, tone: c.teal, label: 'Push notifications', trailing: AppToggle(value: push, onChanged: (v) => setState(() => push = v), colors: c)),
                    Opacity(
                      opacity: push ? 1 : 0.4,
                      child: Column(
                        children: [
                          SettingRow(icon: Icons.assignment_outlined, tone: c.clay, label: 'Assignment reminders', sub: '24h before due', trailing: AppToggle(value: assign, onChanged: push ? (v) => setState(() => assign = v) : (_) {}, colors: c)),
                          SettingRow(icon: Icons.school_outlined, tone: c.board, label: 'New grades', trailing: AppToggle(value: grades, onChanged: push ? (v) => setState(() => grades = v) : (_) {}, colors: c)),
                          SettingRow(icon: Icons.group_outlined, tone: c.dust, label: 'Community & groups', trailing: AppToggle(value: community, onChanged: push ? (v) => setState(() => community = v) : (_) {}, colors: c)),
                        ],
                      ),
                    ),
                    SettingRow(icon: Icons.mail_outline, tone: c.tealDeep, label: 'Email digest', sub: 'Weekly summary', trailing: AppToggle(value: email, onChanged: (v) => setState(() => email = v), colors: c)),
                  ],
                ),
              ),
              const SectionLabel('Privacy & security'),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    SettingRow(icon: Icons.fingerprint, tone: c.teal, label: 'App lock', sub: 'Fingerprint or PIN', trailing: AppToggle(value: lock, onChanged: (v) => setState(() => lock = v), colors: c)),
                    SettingRow(icon: Icons.key_outlined, tone: c.clay, label: 'Change password'),
                  ],
                ),
              ),
              const SectionLabel('General'),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    SettingRow(
                      icon: Icons.language_outlined, tone: c.board, label: 'Language',
                      trailing: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Text('English', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    SettingRow(icon: Icons.storage_outlined, tone: c.dust, label: 'Downloads & storage', sub: _storageUsed.isEmpty ? 'Calculating…' : _storageUsed),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _showSupport,
                      child: SettingRow(icon: Icons.help_outline, tone: c.teal, label: 'Help & support', sub: _supportEmail),
                    ),
                    SettingRow(icon: Icons.info_outline, tone: c.tealInk, label: 'About', sub: _appVersion.isEmpty ? 'Campus app' : _appVersion),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.logout,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(border: Border.all(color: c.clay, width: 2), borderRadius: BorderRadius.circular(16)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.logout, color: c.clay), Text(' Log out', style: display(c, size: 16, color: c.clay))]),
                ),
              ),
              const SizedBox(height: 96),
            ],
          ),
        ),
      ],
      ),
    );
  }
}
