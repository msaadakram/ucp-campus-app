import 'package:flutter/material.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';

enum ThemeModePref { light, dark, system }

class ProfilePrefs {
  ThemeModePref theme;
  AppPalette palette;
  bool big;
  bool motion;
  ProfilePrefs({this.theme = ThemeModePref.light, this.palette = AppPalette.skater, this.big = false, this.motion = true});
}

class ProfileScreen extends StatefulWidget {
  final VoidCallback logout;
  final ProfilePrefs prefs;
  final ValueChanged<ProfilePrefs> onPrefs;
  const ProfileScreen({super.key, required this.logout, required this.prefs, required this.onPrefs});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool push = true, assign = true, grades = true, community = false, email = true;
  bool lock = false;
  String lang = 'English';

  void _set(ProfilePrefs p) => widget.onPrefs(p);

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final hero = AppScope.paletteOf(context).heroAsset;
    return Column(
      children: [
        SizedBox(
          height: 256,
          child: Stack(
            children: [
              Positioned.fill(child: Image.asset(hero, fit: BoxFit.cover, alignment: const Alignment(0.5, -0.3))),
              Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, c.tealInk.withValues(alpha: 0.8)])))),
              Positioned(
                left: 20, bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ayaan Warraich', style: display(c, size: 28, color: Colors.white)),
                    Text('BS Computer Science · Year 2', style: body(c, size: 14, color: c.cream.withValues(alpha: 0.85))),
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
                    for (final kv in [['Student ID', '2024-CS-0719'], ['Email', 'ayaan.w@uni.edu'], ['Faculty', 'Engineering & Computing'], ['Advisor', 'Dr. Amina Qureshi'], ['Enrolled', 'Sep 2024']])
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(border: kv[0] == 'Enrolled' ? null : Border(bottom: BorderSide(color: c.dustSoft))),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(kv[0], style: body(c, size: 14, color: c.tealInk.withValues(alpha: 0.55))), Text(kv[1], style: body(c, size: 14, weight: FontWeight.w600))]),
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
                    Text('52 / 132 credits', style: display(c, size: 22)),
                    const SizedBox(height: 12),
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: 0.39, backgroundColor: c.white, valueColor: AlwaysStoppedAnimation(c.clay), minHeight: 12)),
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
                    SettingRow(icon: Icons.shield_outlined, tone: c.dust, label: 'Profile visibility', sub: 'Classmates only'),
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
                      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: c.dustSoft, borderRadius: BorderRadius.circular(12)), child: DropdownButton<String>(value: lang, underline: const SizedBox(), isDense: true, items: const [DropdownMenuItem(value: 'English', child: Text('English')), DropdownMenuItem(value: 'اردو', child: Text('اردو')), DropdownMenuItem(value: 'العربية', child: Text('العربية')), DropdownMenuItem(value: 'Español', child: Text('Español'))], onChanged: (v) => setState(() => lang = v ?? 'English'))),
                    ),
                    SettingRow(icon: Icons.storage_outlined, tone: c.dust, label: 'Downloads & storage', sub: '182 MB used'),
                    SettingRow(icon: Icons.help_outline, tone: c.teal, label: 'Help & support'),
                    SettingRow(icon: Icons.info_outline, tone: c.tealInk, label: 'About', sub: 'Version 1.0.0'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: widget.logout,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(border: Border.all(color: c.clay, width: 2), borderRadius: BorderRadius.circular(16)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.logout, color: c.clay), Text(' Log out', style: display(c, size: 16, color: c.clay))]),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }
}
