import 'dart:async';

import 'package:flutter/material.dart';

import '../teachers/teacher_models.dart';
import '../teachers/teacher_service.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/loading.dart';
import '../widgets/user_avatar.dart';

/// Teacher reviews page: photo cards, separate 3-dimension ratings,
/// student comments, and a 1..5 rate flow stored in Supabase via Node API.
///
/// Null [service] = backend not configured (setup notice, same pattern as
/// CommunityScreen).
class TeachersScreen extends StatefulWidget {
  final TeacherService? service;
  final String myEmail;
  const TeachersScreen({super.key, this.service, this.myEmail = ''});

  @override
  State<TeachersScreen> createState() => _TeachersScreenState();
}

/// 'Mar 2026' from an ISO review timestamp; '' when unparseable.
String teacherReviewDate(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  } catch (_) {
    return '';
  }
}

class _TeachersScreenState extends State<TeachersScreen> {
  List<Teacher> teachers = [];
  bool loading = true;
  String? error;
  String dept = 'all';
  String query = '';
  String sort = 'Top';
  int visibleCount = 60;
  String reviewSort = 'Newest';
  Teacher? open;
  List<TeacherReview> reviews = [];
  bool detailLoading = false;
  String? detailError;
  Timer? _debounce;
  late final TextEditingController _searchCtrl;
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    if (widget.service == null) {
      loading = false;
      return;
    }
    _reload();
    _sub = widget.service!.updates.listen((_) {
      if (open != null) {
        _openDetail(open!);
      } else {
        _reload();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final svc = widget.service;
    if (svc == null || !mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final fresh =
          await svc.fetchTeachers(dept: dept, query: query).timeout(
                const Duration(seconds: 22),
              );
      if (!mounted) return;
      setState(() {
        teachers = fresh;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final detail = e is TeacherException && e.message.isNotEmpty
          ? ' (${e.message})'
          : '';
      setState(() {
        loading = false;
        error =
            'Could not load teachers. Check connection and retry.$detail';
      });
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      query = v;
      visibleCount = 60;
      _reload();
    });
  }

  List<Teacher> get shown {
    final list = List<Teacher>.of(teachers);
    if (sort == 'Most reviewed') {
      list.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
    } else if (sort == 'Name') {
      list.sort((a, b) => a.name.compareTo(b.name));
    } else {
      list.sort((a, b) {
        final r = b.overallRating.compareTo(a.overallRating);
        if (r != 0) return r;
        return b.reviewCount.compareTo(a.reviewCount);
      });
    }
    // Progressive render: stats always use the full list, cards render
    // in pages of 60 so 706 teachers stay smooth.
    if (list.length > visibleCount) return list.sublist(0, visibleCount);
    return list;
  }

  /// Reviews in the selected order. Backend returns newest first;
  /// 'Highest' re-sorts client-side by average rating.
  List<TeacherReview> get sortedReviews {
    final list = List<TeacherReview>.of(reviews);
    if (reviewSort == 'Highest') {
      list.sort((a, b) => b.average.compareTo(a.average));
    }
    return list;
  }

  Future<void> _openDetail(Teacher t) async {
    final svc = widget.service;
    if (svc == null) return;
    setState(() {
      open = t;
      reviews = [];
      reviewSort = 'Newest';
      detailLoading = true;
      detailError = null;
    });
    try {
      final (fresh, revs) = await svc.fetchDetail(t.slug).timeout(
            const Duration(seconds: 22),
          );
      if (!mounted) return;
      setState(() {
        open = fresh;
        reviews = revs.where((r) => !r.isBlocked).toList();
        detailLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final hint = e is TeacherException && e.message.contains('404')
          ? 'Teacher not found on the server.'
          : 'Check connection and retry.';
      setState(() {
        detailLoading = false;
        detailError = 'Could not load reviews. $hint';
      });
    }
  }

  Future<void> _openRateSheet(Teacher t) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RateSheet(
        teacher: t,
        onSubmit: (g, l, s, comment) async {
          try {
            await widget.service!.submitRating(
              slug: t.slug,
              grading: g,
              leniency: l,
              subject: s,
              comment: comment,
            );
            if (ctx.mounted) Navigator.of(ctx).pop(true);
          } catch (e) {
            if (ctx.mounted) {
              final msg = e is TeacherException ? e.message : '';
              final text = msg.isEmpty
                  ? 'Could not save rating. Try again.'
                  : msg;
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(text),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rating posted — thank you.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      _openDetail(t);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    if (widget.service == null) return _setupNotice(c);
    if (open != null) return _detailView(c, open!);
    // Lazy sliver list: only visible cards are built, with bouncing
    // physics for a smooth feel on 706 rows. The gradient band lives
    // inside the first sliver (same look as UHead, scrolls together).
    // Pull-to-refresh re-fetches the current dept/search.
    return RefreshIndicator(
      color: c.teal,
      backgroundColor: c.white,
      onRefresh: _reload,
      child: CustomScrollView(
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [c.tealDeep, c.teal],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.elliptical(220, 44),
                bottomRight: Radius.elliptical(220, 44),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
            child: Stack(
              children: [
                Positioned(
                  right: -46,
                  top: -54,
                  child: _decoCircle(150, 0.07),
                ),
                Positioned(
                  left: 50,
                  bottom: -84,
                  child: _decoCircle(170, 0.05),
                ),
                Positioned(
                  right: 72,
                  bottom: -46,
                  child: _decoRing(96, 0.10),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(c),
                    const SizedBox(height: 14),
                    _statsStrip(c),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Pinned search: stays under the thumb across 706 rows.
        SliverAppBar(
          pinned: true,
          floating: false,
          toolbarHeight: 68,
          automaticallyImplyLeading: false,
          backgroundColor: c.cream2,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: _searchBar(c),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _deptChips(c),
                const SizedBox(height: 10),
                _sortRow(c),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        if (loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: CommunityFeedSkeleton(),
            ),
          )
        else if (error != null && teachers.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: _errorCard(c),
            ),
          )
        else if (shown.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: _emptyCard(c),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            sliver: SliverList.builder(
              itemCount: shown.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
              itemBuilder: (ctx, i) => _teacherCard(context, c, shown[i]),
            ),
          ),
        if (!loading && error == null && teachers.length > shown.length)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
              child: _showMoreCard(c),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
      ),
    );
  }

  /// Soft translucent disc for header decoration.
  Widget _decoCircle(double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: alpha),
        shape: BoxShape.circle,
      ),
    );
  }

  /// Outlined ring for header decoration (pairs with [_decoCircle]).
  Widget _decoRing(double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: alpha),
          width: 10,
        ),
      ),
    );
  }

  Widget _setupNotice(AppColors c) {
    return UHead(
      height: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Teachers', style: display(c, size: 28, color: Colors.white)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Teacher backend not connected',
                    style: display(c, size: 18)),
                const SizedBox(height: 8),
                Text(
                  'Run supabase/teachers_schema.sql, import teachers.json + reviews.json, and deploy the Node API (see supabase/README-teachers.md).',
                  style: body(c,
                      size: 14, color: c.tealInk.withValues(alpha: 0.65)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Editorial hero: eyebrow + count badge, oversized title, tagline.
  Widget _header(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('RATE · REVIEW',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 1.1)),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_outlined,
                      size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    teachers.isEmpty ? 'UCP' : '${teachers.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text('Teachers',
            style: display(c, size: 34, color: Colors.white)),
        const SizedBox(height: 2),
        Text(
          'Find the mentors worth learning from.',
          style: body(c,
              size: 13.5,
              color: Colors.white.withValues(alpha: 0.82)),
        ),
      ],
    );
  }

  /// Three glass stat cards with icons — faculty size, average score,
  /// review volume — instead of one divider strip.
  Widget _statsStrip(AppColors c) {
    if (teachers.isEmpty) return const SizedBox.shrink();
    final rated = teachers.where((t) => t.reviewCount > 0).toList();
    final avg = rated.isEmpty
        ? 0.0
        : rated.map((t) => t.overallRating).reduce((a, b) => a + b) /
            rated.length;
    final totalReviews =
        teachers.fold<int>(0, (a, t) => a + t.reviewCount);
    return Row(
      children: [
        Expanded(
            child: _statCard(
                c, Icons.people_outline, '${teachers.length}', 'faculty')),
        const SizedBox(width: 8),
        Expanded(
            child: _statCard(
                c, Icons.star_outline, avg.toStringAsFixed(1), 'avg score')),
        const SizedBox(width: 8),
        Expanded(
            child: _statCard(
                c, Icons.forum_outlined, '$totalReviews', 'reviews')),
      ],
    );
  }

  Widget _statCard(
      AppColors c, IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(height: 6),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _searchBar(AppColors c) {
    return Container(
      padding: const EdgeInsets.only(left: 6, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: c.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            alignment: Alignment.center,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: c.teal.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.search, size: 20, color: c.tealInk),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search by name…',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchCtrl.text.isNotEmpty || query.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _searchCtrl.clear();
                query = '';
                _reload();
              },
              child: Container(
                alignment: Alignment.center,
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: c.dustSoft, shape: BoxShape.circle),
                child: const Icon(Icons.clear, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _deptChips(AppColors c) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (code, label) in teacherDepartments)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    dept = code;
                    visibleCount = 60;
                  });
                  _reload();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 15, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: dept == code
                        ? LinearGradient(
                            colors: [c.tealDeep, c.teal],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: dept == code ? null : c.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: dept == code
                            ? c.teal.withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: dept == code
                          ? Colors.white
                          : c.tealInk.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sortRow(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: c.white, borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 12, offset: Offset(0, 5)),
          ]),
      child: Row(
        children: [
          for (final s in ['Top', 'Most reviewed', 'Name'])
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() { sort = s; visibleCount = 60; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    gradient: sort == s
                        ? LinearGradient(
                            colors: [c.tealDeep, c.teal])
                        : null,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    s,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: sort == s
                          ? Colors.white
                          : c.tealInk.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _errorCard(AppColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          color: c.white, borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 18, offset: Offset(0, 8)),
          ]),
      child: Column(
        children: [
          Container(
            alignment: Alignment.center,
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                color: c.clay.withValues(alpha: 0.14),
                shape: BoxShape.circle),
            child: Icon(Icons.wifi_off_outlined, color: c.clay),
          ),
          const SizedBox(height: 12),
          Text(error!, textAlign: TextAlign.center, style: body(c, size: 14)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _reload,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c.tealDeep, c.teal]),
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('Retry',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _showMoreCard(AppColors c) {
    final remaining = teachers.length - shown.length;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        visibleCount += 60;
        if (visibleCount > teachers.length) {
          visibleCount = teachers.length;
        }
      }),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: c.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 14, offset: Offset(0, 6)),
          ],
        ),
        child: Text(
          'Show more · $remaining remaining of ${teachers.length}',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700, color: c.tealDeep),
        ),
      ),
    );
  }

  Widget _emptyCard(AppColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              alignment: Alignment.center,
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: c.white, shape: BoxShape.circle),
              child: Icon(Icons.person_search_outlined,
                  size: 30, color: c.tealInk.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 12),
            Text('No teachers found.\nTry another search or faculty.',
                textAlign: TextAlign.center,
                style:
                    body(c, size: 14, color: c.tealInk.withValues(alpha: 0.55))),
          ],
        ),
      ),
    );
  }

  /// RateMyProfessors-style list card: photo with rating badge, name,
  /// designation · dept, stars + `4.8 (174)`. Breakdown meters live on
  /// the detail profile — the card stays scannable at 60fps.
  Widget _teacherCard(BuildContext context, AppColors c, Teacher t) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDetail(t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: c.dustSoft.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: c.tealInk.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: t.imageUrl.isEmpty
                        ? _avatarFallback(c, t.name, 84)
                        : Image.network(
                            t.imageUrl,
                            fit: BoxFit.cover,
                            cacheWidth: 168,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) =>
                                _avatarFallback(c, t.name, 84),
                          ),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star,
                            size: 12, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(
                          t.reviewCount == 0
                              ? 'New'
                              : t.overallRating.toStringAsFixed(1),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: display(c, size: 16)),
                  const SizedBox(height: 2),
                  Text(
                    t.designation.isEmpty
                        ? _shortDept(t)
                        : '${t.designation} · ${_shortDept(t)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: c.tealInk.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _starRow(t.overallRating, size: 14),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          t.reviewCount == 0
                              ? 'No reviews yet'
                              : '${t.overallRating.toStringAsFixed(1)} (${t.reviewCount})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: c.tealInk
                                  .withValues(alpha: 0.7)),
                        ),
                      ),
                    ],
                  ),
                  if (t.reviewCount == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Tap to be the first to rate',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: c.teal),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              alignment: Alignment.center,
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: c.dustSoft.withValues(alpha: 0.6),
                  shape: BoxShape.circle),
              child: const Icon(Icons.chevron_right, size: 17),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(AppColors c, String name, double size) {
    final colors = [c.teal, c.clay, c.board, c.tealDeep];
    final bg = colors[name.length % colors.length];
    return Container(
      width: size,
      height: size,
      color: bg.withValues(alpha: 0.2),
      child: Icon(Icons.person,
          size: size * 0.45, color: c.tealInk.withValues(alpha: 0.45)),
    );
  }

  Widget _starRow(double rating, {double size = 14}) {
    final full = rating.floor().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          Icon(
            i <= full ? Icons.star : Icons.star_outline,
            size: size,
            color: Colors.amber,
          ),
      ],
    );
  }

  Widget _meter(AppColors c, double value, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 5,
        backgroundColor: c.dustSoft.withValues(alpha: 0.7),
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }

  String _shortDept(Teacher t) {
    if (t.departmentCode.isEmpty) {
      final words = t.departmentName.replaceAll('Faculty of ', '').split(' ');
      return words.take(2).join(' ');
    }
    return t.departmentCode.toUpperCase();
  }

  Widget _detailView(AppColors c, Teacher t) {
    // Lazy reviews: hero + breakdown stay on top, review tiles build
    // on demand so 174-review profiles scroll at 60fps. Pull down to
    // refresh the profile.
    return RefreshIndicator(
      color: c.teal,
      backgroundColor: c.white,
      onRefresh: () => _openDetail(t),
      child: CustomScrollView(
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _detailHero(c, t),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _breakdownCard(c, t),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: c.white, borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 18,
                        offset: Offset(0, 8)),
                  ]),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                        '${reviews.length} review${reviews.length == 1 ? '' : 's'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.tealInk.withValues(alpha: 0.55))),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Sort reviews',
                    initialValue: reviewSort,
                    onSelected: (v) =>
                        setState(() => reviewSort = v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'Newest', child: Text('Newest first')),
                      PopupMenuItem(
                          value: 'Highest', child: Text('Highest rated')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.dustSoft.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sort_outlined, size: 13),
                          Text(' $reviewSort',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _openRateSheet(t),
                    child: Text('Write one',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.teal)),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (detailLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (detailError != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: c.white,
                    borderRadius: BorderRadius.circular(22)),
                child: Column(
                  children: [
                    Text(detailError!),
                    TextButton(
                      onPressed: () => _openDetail(t),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (reviews.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                    color: c.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: c.dustSoft.withValues(alpha: 0.6))),
                child: Column(
                  children: [
                    Icon(Icons.rate_review_outlined,
                        size: 32, color: c.teal),
                    const SizedBox(height: 8),
                    const Text('No reviews yet — be the first to rate.'),
                    const SizedBox(height: 12),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openRateSheet(t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [c.tealDeep, c.teal]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text('Rate first',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList.builder(
              itemCount: sortedReviews.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
              itemBuilder: (ctx, i) =>
                  _reviewTile(c, sortedReviews[i]),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
      ),
    );
  }

  /// Single identity header, LinkedIn-style: cover banner with a floating
  /// back button, overlapping avatar, name + designation, one big score
  /// with stars + count, and a full-width Rate CTA.
  Widget _detailHero(AppColors c, Teacher t) {
    return Container(
      decoration: BoxDecoration(
          color: c.white, borderRadius: BorderRadius.circular(28),
          border: Border.all(color: c.dustSoft.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
                color: c.tealInk.withValues(alpha: 0.07),
                blurRadius: 20,
                offset: const Offset(0, 10)),
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28)),
                child: SizedBox(
                  height: 118,
                  width: double.infinity,
                  child: t.imageUrl.isEmpty
                      ? Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              c.tealDeep,
                              c.teal.withValues(alpha: 0.7)
                            ]),
                          ),
                        )
                      : Image.network(
                          t.imageUrl,
                          fit: BoxFit.cover,
                          cacheWidth: 800,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                c.tealDeep,
                                c.teal.withValues(alpha: 0.7)
                              ]),
                            ),
                          ),
                        ),
                ),
              ),
              Container(
                height: 118,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() {
                    open = null;
                    reviews = [];
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back,
                            size: 16, color: Colors.white),
                        Text(' All',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                bottom: -30,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: SizedBox(
                      width: 62,
                      height: 62,
                      child: t.imageUrl.isEmpty
                          ? _avatarFallback(c, t.name, 62)
                          : Image.network(
                              t.imageUrl,
                              fit: BoxFit.cover,
                              cacheWidth: 128,
                              gaplessPlayback: true,
                              errorBuilder: (_, _, _) =>
                                  _avatarFallback(c, t.name, 62),
                            ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 14,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 17, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        t.reviewCount == 0
                            ? 'New'
                            : t.overallRating.toStringAsFixed(1),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: c.tealDeep),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: display(c, size: 21)),
                const SizedBox(height: 2),
                Text(
                  t.designation.isEmpty
                      ? t.departmentName
                      : '${t.designation} · ${t.departmentName.isEmpty ? _shortDept(t) : t.departmentName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: body(c,
                      size: 12.5,
                      color: c.tealInk.withValues(alpha: 0.65)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _starRow(t.overallRating, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        t.reviewCount == 0
                            ? 'No reviews yet'
                            : '${t.reviewCount} student review${t.reviewCount == 1 ? '' : 's'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.tealInk.withValues(alpha: 0.6)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openRateSheet(t),
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [c.tealDeep, c.teal]),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: c.teal.withValues(alpha: 0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: const Text('Rate this teacher',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Rating breakdown, one labeled row per dimension: icon + bar +
  /// `4.6/5`. Reads at a glance — no decoding cryptic dials.
  Widget _breakdownCard(AppColors c, Teacher t) {
    if (t.reviewCount == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [c.tealDeep, c.teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: c.teal.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8)),
            ]),
        child: const Row(
          children: [
            Icon(Icons.auto_awesome_outlined, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text('Fresh profile — your rating will set the tone.',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: c.white, borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.dustSoft.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
                color: c.tealInk.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 8)),
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('HOW STUDENTS RATE',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: c.tealInk.withValues(alpha: 0.55))),
              const Spacer(),
              const Icon(Icons.insights_outlined, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          _breakdownRow(c, Icons.task_alt_outlined, 'Grading fairness',
              t.avgGrading, c.teal),
          const SizedBox(height: 10),
          _breakdownRow(c, Icons.spa_outlined, 'Leniency & support',
              t.avgLeniency, c.board),
          const SizedBox(height: 10),
          _breakdownRow(c, Icons.menu_book_outlined, 'Subject knowledge',
              t.avgSubject, c.clay),
        ],
      ),
    );
  }

  Widget _breakdownRow(
      AppColors c, IconData icon, String label, double avg, Color color) {
    final pct = (avg / 5).clamp(0.0, 1.0);
    return Row(
      children: [
        Container(
          alignment: Alignment.center,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  Text('${avg.toStringAsFixed(1)}/5',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: c.dustSoft.withValues(alpha: 0.7),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewTile(AppColors c, TeacherReview r) {
    final date = teacherReviewDate(r.createdAt);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: c.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.dustSoft.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
                color: c.tealInk.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 5)),
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                userKey: r.studentName,
                fallbackName: r.studentName,
                radius: 15,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    if (date.isNotEmpty)
                      Text(date,
                          style: TextStyle(
                              fontSize: 11,
                              color:
                                  c.tealInk.withValues(alpha: 0.5))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: c.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 13, color: Colors.amber),
                    Text(' ${r.average.toStringAsFixed(1)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (r.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.dustSoft.withValues(alpha: 0.45),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child:
                  Text(r.comment, style: const TextStyle(fontSize: 14, height: 1.35)),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _miniStat(c, Icons.task_alt_outlined,
                  'Grading ${r.ratingGrading}'),
              _miniStat(c, Icons.spa_outlined,
                  'Leniency ${r.ratingLeniency}'),
              _miniStat(c, Icons.menu_book_outlined,
                  'Subject ${r.ratingSubject}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(AppColors c, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: c.cream2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.dustSoft)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c.tealInk.withValues(alpha: 0.6)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RateSheet extends StatefulWidget {
  final Teacher teacher;
  final Future<void> Function(int g, int l, int s, String comment) onSubmit;
  const _RateSheet({required this.teacher, required this.onSubmit});

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

String _rateWord(int v) {
  switch (v) {
    case 5:
      return 'Excellent';
    case 4:
      return 'Good';
    case 3:
      return 'Average';
    case 2:
      return 'Poor';
    default:
      return 'Very poor';
  }
}

class _RateSheetState extends State<_RateSheet> {
  int grading = 5;
  int leniency = 5;
  int subject = 5;
  late final TextEditingController _commentCtrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _commentCtrl = TextEditingController()..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final initial = widget.teacher.name.isEmpty
        ? '?'
        : widget.teacher.name[0].toUpperCase();
    Widget fallback() => Container(
          color: c.teal.withValues(alpha: 0.14),
          alignment: Alignment.center,
          child: Text(initial,
              style: TextStyle(
                  color: c.tealDeep,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
        );
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: BoxDecoration(
          color: c.cream2,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                        color: c.dustSoft,
                        borderRadius: BorderRadius.circular(4))),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: widget.teacher.imageUrl.isEmpty
                          ? fallback()
                          : Image.network(
                              widget.teacher.imageUrl,
                              fit: BoxFit.cover,
                              cacheWidth: 96,
                              gaplessPlayback: true,
                              errorBuilder: (_, _, _) => fallback(),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rate ${widget.teacher.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: display(c, size: 17)),
                        Text('Anonymous · 1 poor · 5 excellent',
                            style: body(c,
                                size: 12,
                                color:
                                    c.tealInk.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _starsCard(
                  c, 'Grading fairness', 'Fair marking & feedback', grading,
                  (v) => setState(() => grading = v)),
              _starsCard(c, 'Leniency', 'Flexibility & support', leniency,
                  (v) => setState(() => leniency = v)),
              _starsCard(c, 'Subject knowledge', 'Concepts & clarity',
                  subject, (v) => setState(() => subject = v)),
              const SizedBox(height: 6),
              TextField(
                controller: _commentCtrl,
                maxLines: 3,
                maxLength: 500,
                enabled: !_busy,
                decoration: InputDecoration(
                  hintText:
                      'Write a short anonymous review (optional)…',
                  filled: true,
                  fillColor: c.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await widget.onSubmit(
                            grading,
                            leniency,
                            subject,
                            _commentCtrl.text.trim(),
                          );
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: Opacity(
                  opacity: _busy ? 0.6 : 1,
                  child: Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [c.tealDeep, c.teal]),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                            color: c.teal.withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                    Colors.white)),
                          )
                        : Text(
                            'Submit · ${((grading + leniency + subject) / 3).toStringAsFixed(1)} average',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _starsCard(AppColors c, String label, String hint, int value,
      ValueChanged<int> onPick) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: c.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(hint,
                        style: TextStyle(
                            fontSize: 11,
                            color: c.tealInk.withValues(alpha: 0.55))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: c.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(_rateWord(value),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: c.tealDeep)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 1; i <= 5; i++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onPick(i),
                  child: AnimatedScale(
                    scale: i == value ? 1.18 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      i <= value ? Icons.star : Icons.star_outline,
                      size: 34,
                      color: Colors.amber,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
