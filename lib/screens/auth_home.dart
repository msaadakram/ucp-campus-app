import 'package:flutter/material.dart';
import '../auth/dashboard_parser.dart';
import '../auth/student_portal.dart';
import '../data/seed.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/loading.dart';

/// Time-of-day greeting: night <5, morning <12, afternoon <17,
/// evening <21, else night.
String greetingForHour(int hour) {
  if (hour < 5 || hour >= 21) return 'Good night,';
  if (hour < 12) return 'Good morning,';
  if (hour < 17) return 'Good afternoon,';
  return 'Good evening,';
}

class LoginScreen extends StatefulWidget {
  /// Called with the typed university email. The app opens Microsoft
  /// sign-in with it as `login_hint`; the password is typed by the user on
  /// Microsoft's own page and never enters the app.
  final ValueChanged<String> onMicrosoftSignIn;
  final String? authError;
  /// True while the cold-start auto-login attempt runs: shows a short
  /// "Signing you in…" animation instead of the form.
  final bool restoring;
  const LoginScreen(
      {super.key,
      required this.onMicrosoftSignIn,
      this.authError,
      this.restoring = false});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  String email = '';
  bool get ok =>
      email.trim().toLowerCase().endsWith('@ucp.edu.pk');

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.restoring) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(LoginScreen old) {
    super.didUpdateWidget(old);
    if (widget.restoring && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.restoring && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final hero = AppScope.paletteOf(context).heroAsset;
    if (widget.restoring) return _restoringView(c, hero);
    return SingleChildScrollView(
      primary: false,
      child: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.46,
            child: Stack(
              children: [
                Positioned.fill(child: Image.asset(hero, fit: BoxFit.cover, alignment: const Alignment(0.5, -0.4))),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [c.teal.withValues(alpha: 0.1), Colors.transparent, c.teal],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 24, top: 48,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: c.cream, borderRadius: BorderRadius.circular(20)),
                    child: Text('UCP', style: display(c, size: 14)),
                  ),
                ),
              ],
            ),
          ),
          Container(
            transform: Matrix4.translationValues(0, -24, 0),
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            decoration: BoxDecoration(color: c.cream2, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UCP · The University of Central Punjab',
                    style: body(c, size: 12, weight: FontWeight.w700, color: c.teal)),
                const SizedBox(height: 6),
                Text('Hey, welcome back.', style: display(c, size: 36)),
                const SizedBox(height: 8),
                Text('Sign in with your @ucp.edu.pk email to see your semester.',
                    style: body(c, size: 14, color: c.tealInk.withValues(alpha: 0.6))),
                const SizedBox(height: 16),
                Text('UNIVERSITY EMAIL', style: body(c, size: 12, weight: FontWeight.w600, color: c.tealInk.withValues(alpha: 0.6))),
                const SizedBox(height: 6),
                TextField(
                  onChanged: (v) => setState(() => email = v),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    hintText: 'you@ucp.edu.pk',
                    helperText: 'Use your email ending with @ucp.edu.pk',
                    filled: true, fillColor: c.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.dustSoft, width: 2)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.dustSoft, width: 2)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.teal, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.authError != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.clay.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      widget.authError!,
                      style: body(
                        c,
                        size: 13,
                        weight: FontWeight.w600,
                        color: c.clay,
                      ),
                    ),
                  ),
                if (widget.authError != null) const SizedBox(height: 12),
                ClayButton(
                  label: 'Continue with Microsoft',
                  colors: c,
                  onPressed: ok
                      ? () => widget.onMicrosoftSignIn(email.trim())
                      : null,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'You sign in on Microsoft — your password never enters this app.',
                    textAlign: TextAlign.center,
                    style: body(
                      c,
                      size: 12,
                      color: c.tealInk.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Short branded wait shown while the app tries the saved session
  /// (validate → silent renew): pulsing UCP badge, spinner, status text.
  Widget _restoringView(AppColors c, String hero) {
    return SingleChildScrollView(
      primary: false,
      child: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.30,
            child: Stack(
              children: [
                Positioned.fill(
                    child: Image.asset(hero,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0.5, -0.4))),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          c.teal.withValues(alpha: 0.1),
                          Colors.transparent,
                          c.teal
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            transform: Matrix4.translationValues(0, -24, 0),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 64),
            decoration: BoxDecoration(
                color: c.cream2,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32))),
            child: Column(
              children: [
                ScaleTransition(
                  scale: Tween(begin: 0.92, end: 1.06).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                  ),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: c.teal,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: c.clay,
                            offset: const Offset(0, 6),
                            blurRadius: 0),
                      ],
                    ),
                    child: Center(
                      child: Text('UCP',
                          style: display(c, size: 20, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Signing you in…', style: display(c, size: 24)),
                const SizedBox(height: 8),
                Text('Checking your saved session securely.',
                    style: body(c,
                        size: 14,
                        color: c.tealInk.withValues(alpha: 0.6))),
                const SizedBox(height: 24),
                const ModernLoader(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {  final ValueChanged<Course> onOpen;
  final VoidCallback toProfile;
  final VoidCallback onMenu;
  final VoidCallback onGpa;
  final ValueChanged<Course> onBoard;
  final VoidCallback? onAttend;
  /// Live portal data. Null while loading/failed → bundled sample content.
  final DashboardData? dashboard;
  /// Real weekly slots, used to enrich portal courses with rooms/times.
  final List<TimetableSlot> timetableSlots;
  const HomeScreen({super.key, required this.onOpen, required this.toProfile, required this.onMenu, required this.onGpa, required this.onBoard, this.dashboard, this.onAttend, this.timetableSlots = const []});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String filter = 'All';
  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final hero = AppScope.paletteOf(context).heroAsset;
    final live = widget.dashboard;
    // Real enrolled courses when the portal provided them; mock sample
    // content otherwise (offline, tests).
    final liveCourses =
        (live != null && live.courses.isNotEmpty) ? live.courses : null;
    Course mapCourse(PortalCourse pc, int i) =>
        portalCourseToCourse(pc, widget.timetableSlots, i);
    final baseCourses = liveCourses == null
        ? courses
        : [for (int i = 0; i < liveCourses.length; i++) mapCourse(liveCourses[i], i)];
    // Ongoing = courses with a class TODAY; Almost done = the complete
    // weekly subject list. Both come from the real timetable when loaded;
    // offline they fall back to the old progress split.
    List<Course> applyFilter() {
      if (filter == 'All') return baseCourses;
      final useSchedule =
          liveCourses != null && widget.timetableSlots.isNotEmpty;
      if (filter == 'Ongoing') {
        if (!useSchedule) {
          return baseCourses.where((x) => x.progress < 80).toList();
        }
        final today = coursesToday(
            liveCourses, widget.timetableSlots, DateTime.now());
        return [
          for (final pc in today) mapCourse(pc, liveCourses.indexOf(pc))
        ];
      }
      if (!useSchedule) {
        return baseCourses.where((x) => x.progress >= 80).toList();
      }
      final week = coursesThisWeek(liveCourses, widget.timetableSlots);
      return [for (final pc in week) mapCourse(pc, liveCourses.indexOf(pc))];
    }

    final list = applyFilter();
    final greeting = greetingForHour(DateTime.now().hour);
    // First two tiles mirror the portal stats (CGPA, Earned Cr). The third
    // tile is the credit-weighted overall attendance parsed from the real
    // enrolled course cards — the portal's own "Total Cr" stat sits at 0.0
    // and is useless, so it is never shown. Offline/tests fall back to the
    // matching sample tile.
    final hasCourses = live != null && live.courses.isNotEmpty;
    List<String>? attendStatTile() {
      if (live == null) return null;
      for (final s in live.stats) {
        if (s.label.toLowerCase().contains('attend')) {
          return [s.value, s.label];
        }
      }
      return null;
    }

    final attendTile = hasCourses
        ? [formatPercent(overallAttendance(live!.courses)), 'Attend.']
        : attendStatTile();
    final liveTiles = live == null
        ? <List<String>>[]
        : [
            for (final s in live.stats.take(2)) [s.value, s.label],
            if (attendTile != null) attendTile,
          ];
    const mockTiles = [
      ['3.62', 'GPA'],
      ['11', 'Credits'],
      ['94%', 'Attend.'],
    ];
    final statTiles = [
      ...liveTiles,
      ...mockTiles.sublist(0, 3 - liveTiles.length),
    ];
    final liveBadge = liveTiles.isNotEmpty;
    final nameParts =
        (live?.studentName ?? '').split(' ').where((w) => w.isNotEmpty).toList();
    final displayName = nameParts.isEmpty ? 'Ayaan' : nameParts.first;
    return UHead(
      height: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onMenu,
                child: Container(alignment: Alignment.center, width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.menu, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greeting, style: body(c, size: 14, color: Colors.white.withValues(alpha: 0.8))),
                    Row(children: [Flexible(child: Text('$displayName ', style: display(c, size: 28, color: Colors.white), overflow: TextOverflow.ellipsis)), const Text('👋', style: TextStyle(fontSize: 24))]),
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.toProfile,
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), image: DecorationImage(image: AssetImage(hero), fit: BoxFit.cover, alignment: Alignment.topCenter)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (int i = 0; i < 3; i++)
                Builder(builder: (_) {
                  final s = statTiles[i];
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
                      child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: s[1] == 'GPA'
                          ? widget.onGpa
                          : (s[1].toLowerCase().startsWith('attend')
                              ? widget.onAttend
                              : null),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s[0], style: display(c, size: 22)),
                            Row(children: [Text(s[1], style: body(c, size: 12, color: c.tealInk.withValues(alpha: 0.55))), if (s[1] == 'GPA') Icon(Icons.calculate_outlined, size: 12, color: c.teal)]),
                          ],
                        ),
                      ),
                    ),
                  ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 20),
          Builder(builder: (_) {
            final now = DateTime.now();
            final upcoming = widget.timetableSlots.isEmpty
                ? const <TimetableSlot>[]
                : upcomingClasses(widget.timetableSlots, now, 3);
            final next = upcoming.isEmpty ? null : upcoming.first;
            final liveNow =
                next != null && isSlotLive(next, now);
            final then = upcoming.length > 1
                ? upcoming.sublist(1)
                : const <TimetableSlot>[];
            final upTitle = next?.subject ?? 'Data Structures';
            final upTime = next != null ? '${next.day} · ${next.start}' : '09:00';
            final upBits = [
              if ((next?.room ?? '').isNotEmpty) next!.room,
              if ((next?.teacher ?? '').isNotEmpty) next!.teacher,
            ];
            final upSub = upBits.isEmpty
                ? 'Block C · 204 — Dr. Amina Qureshi'
                : upBits.join(' — ');
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: c.teal, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${liveNow ? 'NOW' : 'UP NEXT'} · $upTime',
                      style: body(c,
                          size: 12,
                          weight: FontWeight.w600,
                          color: c.cream.withValues(alpha: 0.8))),
                  const SizedBox(height: 4),
                  Text(upTitle,
                      style: display(c, size: 24, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2),
                  Text(upSub,
                      style: body(c,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.8))),
                  for (final s in then) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text('${s.day.substring(0, 3)} · ${s.start}',
                              style: body(c,
                                  size: 12,
                                  weight: FontWeight.w700,
                                  color: Colors.white)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(s.subject,
                                style: body(c,
                                    size: 12,
                                    color:
                                        Colors.white.withValues(alpha: 0.85)),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          if (live?.todayClasses != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(24)),
              child: Row(
                children: [
                  Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: c.board.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.today_outlined, size: 22, color: c.tealInk)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Today', style: body(c, size: 12, weight: FontWeight.w600, color: c.tealInk.withValues(alpha: 0.55))),
                        Text(live!.todayClasses!,
                            style: body(c, size: 15, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My courses', style: display(c, size: 20)),
              Row(
                children: [
                  if (liveBadge)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: c.teal, borderRadius: BorderRadius.circular(10)),
                      child: const Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  Text('Fall 2026', style: body(c, size: 14, color: c.tealInk.withValues(alpha: 0.5))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in ['All', 'Ongoing', 'Almost done'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => filter = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: filter == f ? c.tealInk : c.dustSoft, borderRadius: BorderRadius.circular(20)),
                        child: Text(f, style: body(c, size: 14, weight: FontWeight.w600, color: filter == f ? c.cream : c.tealInk.withValues(alpha: 0.7))),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final course in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onOpen(course),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: toneBg(course.tone, c), borderRadius: BorderRadius.circular(24)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${course.code} · ${course.credits} cr'.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.75))),
                                Text(course.title, style: display(c, size: 18, color: course.tone == CourseTone.board ? c.tealInk : Colors.white)),
                                Text(course.time, style: TextStyle(fontSize: 14, color: (course.tone == CourseTone.board ? c.tealInk : Colors.white).withValues(alpha: 0.8))),
                              ],
                            ),
                          ),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              ProgressRing(value: course.progress, color: course.tone == CourseTone.board ? c.tealInk : Colors.white),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onBoard(course),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.fromLTRB(16, 28, 16, 10),
                      transform: Matrix4.translationValues(0, -20, 0),
                      decoration: BoxDecoration(color: c.white, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
                      child: Builder(builder: (ctx) {
                        final top = board(course.code, 'Overall').first;
                        return Row(
                          children: [
                            Icon(Icons.emoji_events_outlined, size: 15, color: c.clay),
                            const SizedBox(width: 8),
                            Expanded(child: Text.rich(TextSpan(children: [const TextSpan(text: 'Leader: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: '${top.me ? 'You' : top.name} · ${top.score} pts')]), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                            Text('Leaderboard ›', style: body(c, size: 12, weight: FontWeight.bold, color: c.teal)),
                          ],
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          if (list.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: c.white, borderRadius: BorderRadius.circular(20)),
              child: Text(
                filter == 'Ongoing'
                    ? 'No classes today — enjoy the day off 🎉'
                    : 'No subjects scheduled this week.',
                textAlign: TextAlign.center,
                style:
                    body(c, size: 14, color: c.tealInk.withValues(alpha: 0.55)),
              ),
            ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  final Course course;
  final VoidCallback back;
  /// Real weekly slots + whether this is a portal course (vs sample data).
  final List<TimetableSlot> slots;
  final bool isLive;
  const DetailScreen(
      {super.key,
      required this.course,
      required this.back,
      this.slots = const [],
      this.isLive = false});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final bg = toneBg(course.tone, c);
    final weekClasses =
        isLive ? slotsForCourse(course.title, slots) : <TimetableSlot>[];
    final infoTiles = isLive
        ? [
            ['Attendance', '${course.progress}%'],
            ['Credits', '${course.credits} cr'],
            ['Schedule', course.time],
            ['Room', course.room],
          ]
        : [
            ['Current grade', course.grade],
            ['Progress', '${course.progress}%'],
            ['Schedule', course.time],
            ['Room', course.room],
          ];
    return SingleChildScrollView(
      primary: false,
      child: Column(
        children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(onTap: back, child: Container(alignment: Alignment.center, width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle), child: const Icon(Icons.arrow_back, color: Colors.white))),
              const SizedBox(height: 24),
              Text(course.code.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.75))),
              Text(course.title, style: display(c, size: 36, color: course.tone == CourseTone.board ? c.tealInk : Colors.white)),
              const SizedBox(height: 8),
              Text(course.prof, style: TextStyle(color: (course.tone == CourseTone.board ? c.tealInk : Colors.white).withValues(alpha: 0.85))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
                children: [
                  for (final kv in infoTiles)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text(kv[0], style: body(c, size: 12, color: c.tealInk.withValues(alpha: 0.55))), const SizedBox(height: 4), Text(kv[1], style: display(c, size: 16), overflow: TextOverflow.ellipsis, maxLines: 2)],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(isLive ? 'This week' : 'Upcoming', style: display(c, size: 20)),
              const SizedBox(height: 12),
              if (isLive && weekClasses.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(16)),
                  child: Text('No classes scheduled this week.',
                      textAlign: TextAlign.center,
                      style: body(c, size: 14, color: c.tealInk.withValues(alpha: 0.55))),
                ),
              if (isLive)
                for (final s in weekClasses)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: s.isLab ? c.clay : c.teal)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text('${s.day} · ${s.start} – ${s.end}',
                                style: body(c,
                                    size: 15, weight: FontWeight.w600))),
                        Text(s.room,
                            style: body(c,
                                size: 13,
                                color: c.tealInk.withValues(alpha: 0.55))),
                      ],
                    ),
                  ),
              if (!isLive)
              for (final u in const [['Assignment 3', 'Due Oct 4', 0], ['Quiz · Week 6', 'Oct 8', 1], ['Midterm exam', 'Oct 21', 2]])
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: (u[2] as int) == 0 ? c.clay : (u[2] as int) == 1 ? c.teal : c.board)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(u[0] as String, style: body(c, size: 15, weight: FontWeight.w600))),
                      Text(u[1] as String, style: body(c, size: 14, color: c.tealInk.withValues(alpha: 0.55))),
                    ],
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
