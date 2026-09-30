import 'package:flutter/material.dart';
import 'data/seed.dart';
import 'screens/auth_home.dart';
import 'screens/community.dart';
import 'screens/fee_board.dart';
import 'screens/gpa_timetable.dart';
import 'screens/groups_chat.dart';
import 'screens/materials_web.dart';
import 'screens/profile.dart';
import 'theme/palette.dart';
import 'widgets/common.dart';

class CampusApp extends StatefulWidget {
  const CampusApp({super.key});
  @override
  State<CampusApp> createState() => _CampusAppState();
}

class _CampusAppState extends State<CampusApp> {
  bool authed = false;
  String tab = 'home';
  Course? course;
  Course boardOf = courses[0];
  ProfilePrefs prefs = ProfilePrefs();
  bool picker = false;
  bool menu = false;
  GroupInfo? chat;

  void go(String t) => setState(() { tab = t; course = null; picker = false; menu = false; chat = null; });

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final dark = prefs.theme == ThemeModePref.dark || (prefs.theme == ThemeModePref.system && brightness == Brightness.dark);
    final colors = AppColors.of(prefs.palette, dark);

    Widget screen;
    if (chat != null) {
      screen = GroupChatScreen(group: chat!, back: () => setState(() => chat = null));
    } else if (course != null) {
      screen = DetailScreen(course: course!, back: () => setState(() => course = null));
    } else {
      switch (tab) {
        case 'home':
          screen = HomeScreen(onOpen: (c) => setState(() { course = c; }), toProfile: () => go('profile'), onMenu: () => setState(() => menu = true), onGpa: () => go('gpa'), onBoard: (c) { setState(() { boardOf = c; tab = 'board'; }); });
          break;
        case 'material':
          screen = const MaterialsScreen();
          break;
        case 'community':
          screen = const CommunityScreen();
          break;
        case 'groups':
          screen = GroupsScreen(onChat: (g) => setState(() => chat = g));
          break;
        case 'gpa':
          screen = const GpaCalcScreen();
          break;
        case 'timetable':
          screen = const TimetableScreen();
          break;
        case 'fee':
          screen = const FeeChallanScreen();
          break;
        case 'board':
          screen = LeaderboardScreen(start: boardOf.code, back: () => go('home'));
          break;
        case 'web':
          screen = const WebViewScreen();
          break;
        default:
          screen = ProfileScreen(logout: () => setState(() { authed = false; tab = 'home'; }), prefs: prefs, onPrefs: (p) => setState(() => prefs = p));
      }
    }

    return AppScope(
      colors: colors,
      palette: prefs.palette,
      child: MaterialApp(
        title: 'campus.',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: colors.cream2,
          colorScheme: ColorScheme.fromSeed(seedColor: colors.teal),
          useMaterial3: true,
        ),
        home: Builder(builder: (ctx) {
          final mq = MediaQuery.of(ctx);
          final scaled = prefs.big ? mq.copyWith(textScaler: const TextScaler.linear(1.08)) : mq;
          return MediaQuery(
            data: scaled,
            child: Scaffold(
              backgroundColor: colors.cream2,
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Stack(
                    children: [
                      Container(
                        color: colors.cream2,
                        child: !authed
                            ? SingleChildScrollView(child: LoginScreen(onLogin: () => setState(() => authed = true)))
                            : Stack(
                                children: [
                                  SingleChildScrollView(child: screen),
                                  if (picker) ...[
                                    GestureDetector(onTap: () => setState(() => picker = false), child: Container(color: colors.tealInk.withValues(alpha: 0.4))),
                                    Positioned(
                                      left: 16, right: 16, bottom: 110,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () => go('community'),
                                              child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: colors.teal, borderRadius: BorderRadius.circular(24)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.forum_outlined, color: Colors.white), SizedBox(height: 24), Text('Community', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)), Text('Campus feed & posts', style: TextStyle(color: Colors.white70, fontSize: 12))])),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () => go('groups'),
                                              child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: colors.clay, borderRadius: BorderRadius.circular(24)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.group_outlined, color: Colors.white), SizedBox(height: 24), Text('Groups', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)), Text('Study circles & clubs', style: TextStyle(color: Colors.white70, fontSize: 12))])),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (menu) ...[
                                    GestureDetector(onTap: () => setState(() => menu = false), child: Container(color: colors.tealInk.withValues(alpha: 0.4))),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        width: MediaQuery.of(ctx).size.width * 0.82 > 353 ? 353 : MediaQuery.of(ctx).size.width * 0.82,
                                        decoration: BoxDecoration(color: colors.cream2, borderRadius: const BorderRadius.horizontal(right: Radius.circular(32))),
                                        child: Column(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(colors: [colors.tealDeep, colors.teal]),
                                                borderRadius: const BorderRadius.only(topRight: Radius.circular(32)),
                                              ),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(radius: 28, backgroundImage: AssetImage(prefs.palette.heroAsset)),
                                                  const SizedBox(width: 12),
                                                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Ayaan Warraich', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)), Text('BS Computer Science · Year 2', style: TextStyle(color: Colors.white70, fontSize: 12))])),
                                                  GestureDetector(onTap: () => setState(() => menu = false), child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white))),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: ListView(
                                                padding: const EdgeInsets.all(12),
                                                children: [
                                                  for (final it in [['home', 'Home', Icons.home_outlined], ['timetable', 'Timetable', Icons.calendar_month_outlined], ['material', 'Course material', Icons.book_outlined], ['gpa', 'GPA calculator', Icons.calculate_outlined], ['fee', 'Fee challan', Icons.receipt_outlined], ['community', 'Community', Icons.forum_outlined], ['groups', 'Groups & chats', Icons.group_outlined], ['web', 'Web view', Icons.language_outlined], ['profile', 'Profile & settings', Icons.person_outline]])
                                                    GestureDetector(
                                                      onTap: () => go(it[0] as String),
                                                      child: Container(
                                                        margin: const EdgeInsets.only(bottom: 4),
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                        decoration: BoxDecoration(color: tab == it[0] && course == null ? colors.teal : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                                                        child: Row(
                                                          children: [
                                                            Container(width: 36, height: 36, decoration: BoxDecoration(color: tab == it[0] && course == null ? Colors.white.withValues(alpha: 0.2) : colors.dustSoft, borderRadius: BorderRadius.circular(12)), child: Icon(it[2] as IconData, size: 18, color: tab == it[0] && course == null ? Colors.white : colors.tealInk)),
                                                            const SizedBox(width: 12),
                                                            Expanded(child: Text(it[1] as String, style: TextStyle(fontWeight: FontWeight.w600, color: tab == it[0] && course == null ? Colors.white : colors.tealInk))),
                                                            Icon(Icons.chevron_right, size: 17, color: (tab == it[0] && course == null ? Colors.white : colors.tealInk).withValues(alpha: 0.5)),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: GestureDetector(
                                                onTap: () => setState(() { menu = false; authed = false; tab = 'home'; }),
                                                child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: colors.dustSoft, borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(Icons.logout, color: colors.clay), Text(' Log out', style: TextStyle(fontWeight: FontWeight.w600, color: colors.clay))])),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  Positioned(
                                    left: 0, right: 0, bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                                      decoration: BoxDecoration(color: colors.white, border: Border(top: BorderSide(color: colors.dustSoft))),
                                      child: Row(
                                        children: [
                                          _navItem(ctx, colors, 'material', 'Material', Icons.book_outlined, 0),
                                          _navItem(ctx, colors, 'community', tab == 'groups' ? 'Groups' : 'Community', Icons.group_outlined, 1, isCommunity: true),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () => go('home'),
                                              child: Column(
                                                children: [
                                                  Container(
                                                    transform: Matrix4.translationValues(0, -24, 0),
                                                    width: 64, height: 64,
                                                    decoration: BoxDecoration(color: (tab == 'home' && course == null) ? colors.teal : colors.tealInk, shape: BoxShape.circle, border: Border.all(color: colors.cream2, width: 4), boxShadow: [BoxShadow(color: colors.clay, offset: const Offset(0, 6))]),
                                                    child: const Icon(Icons.home_outlined, color: Colors.white, size: 26),
                                                  ),
                                                  Text('Home', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: (tab == 'home' && course == null) ? colors.tealInk : colors.tealInk.withValues(alpha: 0.55))),
                                                ],
                                              ),
                                            ),
                                          ),
                                          _navItem(ctx, colors, 'web', 'Web', Icons.language_outlined, 3),
                                          _navItem(ctx, colors, 'profile', 'Profile', Icons.person_outline, 4),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _navItem(BuildContext ctx, AppColors c, String key, String label, IconData icon, int idx, {bool isCommunity = false}) {
    final on = (tab == key || (isCommunity && tab == 'groups')) && course == null && chat == null;
    return Expanded(
      child: GestureDetector(
        onTap: () => isCommunity ? setState(() => picker = !picker) : go(key),
        child: Column(
          children: [
            Container(
              width: 56, height: 32,
              decoration: BoxDecoration(color: on ? c.teal : Colors.transparent, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: on ? Colors.white : c.tealInk.withValues(alpha: 0.55)),
            ),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: on ? c.tealInk : c.tealInk.withValues(alpha: 0.55))),
          ],
        ),
      ),
    );
  }
}
