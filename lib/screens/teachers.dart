import 'dart:async';

import 'package:flutter/material.dart';

import '../teachers/teacher_models.dart';
import '../teachers/teacher_service.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/loading.dart';

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

class _TeachersScreenState extends State<TeachersScreen> {
  List<Teacher> teachers = [];
  bool loading = true;
  String? error;
  String dept = 'all';
  String query = '';
  String sort = 'Top';
  int visibleCount = 60;
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Could not load teachers. Check connection and retry.';
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

  Future<void> _openDetail(Teacher t) async {
    final svc = widget.service;
    if (svc == null) return;
    setState(() {
      open = t;
      reviews = [];
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
          ? 'Backend has no teachers routes — redeploy the API, or run with SUPABASE_URL + SUPABASE_ANON_KEY for direct read.'
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
              final text = msg.contains('404') || msg.contains('redeploy')
                  ? 'Rating needs the updated API — redeploy the backend with teachers routes, then retry.'
                  : (msg.isEmpty
                      ? 'Could not save rating. Try again.'
                      : msg);
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
    return UHead(
      height: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(c),
          const SizedBox(height: 14),
          _statsStrip(c),
          const SizedBox(height: 14),
          _searchBar(c),
          const SizedBox(height: 10),
          _deptChips(c),
          const SizedBox(height: 10),
          _sortRow(c),
          const SizedBox(height: 12),
          if (loading)
            const CommunityFeedSkeleton()
          else if (error != null && teachers.isEmpty)
            _errorCard(c)
          else if (shown.isEmpty)
            _emptyCard(c)
          else
            for (final t in shown) _teacherCard(context, c, t),
          if (!loading && error == null && teachers.length > shown.length)
            _showMoreCard(c),
          const SizedBox(height: 96),
        ],
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

  Widget _header(AppColors c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Teachers',
                  style: display(c, size: 30, color: Colors.white)),
              const SizedBox(height: 2),
              Text(
                'Photos · ratings · student reviews',
                style: body(c,
                    size: 13.5, color: Colors.white.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_outlined,
                  size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                teachers.isEmpty ? 'UCP' : '${teachers.length} listed',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statsStrip(AppColors c) {
    if (teachers.isEmpty) return const SizedBox.shrink();
    final rated =
        teachers.where((t) => t.reviewCount > 0).toList();
    final avg = rated.isEmpty
        ? 0.0
        : rated.map((t) => t.overallRating).reduce((a, b) => a + b) /
            rated.length;
    final totalReviews =
        teachers.fold<int>(0, (a, t) => a + t.reviewCount);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          _statItem(c, '${teachers.length}', 'teachers'),
          _statDivider(),
          _statItem(c, avg.toStringAsFixed(1), 'avg rating'),
          _statDivider(),
          _statItem(c, '$totalReviews', 'reviews'),
          const Spacer(),
          const Icon(Icons.auto_awesome_outlined,
              size: 18, color: Colors.white70),
        ],
      ),
    );
  }

  Widget _statItem(AppColors c, String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
      ],
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: Colors.white.withValues(alpha: 0.25),
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

  Widget _teacherCard(BuildContext context, AppColors c, Teacher t) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDetail(t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: t.imageUrl.isEmpty
                        ? _avatarFallback(c, t.name, 88)
                        : Image.network(
                            t.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _avatarFallback(c, t.name, 88),
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
                children: [
                  Text(t.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: display(c, size: 16.5)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            t.designation.isEmpty ? 'Faculty' : t.designation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: c.tealDeep),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.dustSoft.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _shortDept(t),
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: c.tealInk.withValues(alpha: 0.7)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _starRow(t.overallRating, size: 14),
                  const SizedBox(height: 5),
                  Text(
                    t.reviewCount == 0
                        ? 'No reviews yet — tap to be first'
                        : '${t.reviewCount} reviews · G ${t.gradingPct}% · L ${t.leniencyPct}% · S ${t.subjectPct}%',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: c.tealInk.withValues(alpha: 0.62)),
                  ),
                  if (t.reviewCount > 0) ...[
                    const SizedBox(height: 6),
                    _meter(c, t.gradingPct / 100, c.teal),
                    const SizedBox(height: 4),
                    _meter(c, t.leniencyPct / 100, c.board),
                    const SizedBox(height: 4),
                    _meter(c, t.subjectPct / 100, c.clay),
                  ],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  open = null;
                  reviews = [];
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: c.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4)),
                      ]),
                  child: const Row(children: [
                    Icon(Icons.arrow_back, size: 17),
                    Text(' All',
                        style: TextStyle(fontWeight: FontWeight.w700))
                  ]),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _openRateSheet(t),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient:
                        LinearGradient(colors: [c.tealDeep, c.teal]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: c.teal.withValues(alpha: 0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const Row(children: [
                    Icon(Icons.star_outline,
                        size: 16, color: Colors.white),
                    Text(' Rate',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold))
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _detailHero(c, t),
          const SizedBox(height: 12),
          _dialsCard(c, t),
          const SizedBox(height: 12),
          Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          '${reviews.length} STUDENT REVIEWS'.toUpperCase(),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: c.tealInk.withValues(alpha: 0.55))),
                    ),
                    GestureDetector(
                      onTap: () => _openRateSheet(t),
                      child: Text('Write one',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: c.teal)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (detailLoading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (detailError != null)
                  Column(
                    children: [
                      Text(detailError!),
                      TextButton(
                        onPressed: () => _openDetail(t),
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                else if (reviews.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                        color: c.cream2,
                        borderRadius: BorderRadius.circular(18)),
                    child: const Center(
                        child: Text(
                            'No reviews yet — be the first to rate.')),
                  )
                else
                  for (final r in reviews) _reviewTile(c, r),
              ],
            ),
          ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  Widget _detailHero(AppColors c, Teacher t) {
    return Container(
      decoration: BoxDecoration(
          color: c.white, borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(0, 10)),
          ]),
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28)),
                child: SizedBox(
                  height: 130,
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
                height: 130,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                bottom: 12,
                right: 14,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.departmentName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                          Text(t.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: display(c,
                                  size: 20, color: Colors.white)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star,
                              size: 17, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            t.reviewCount == 0
                                ? 'New'
                                : t.overallRating.toStringAsFixed(1),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: t.imageUrl.isEmpty
                        ? _avatarFallback(c, t.name, 58)
                        : Image.network(
                            t.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _avatarFallback(c, t.name, 58),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.designation.isEmpty
                            ? _shortDept(t)
                            : '${t.designation} · ${_shortDept(t)}',
                        style: body(c,
                            size: 12,
                            color: c.tealInk.withValues(alpha: 0.65)),
                      ),
                      const SizedBox(height: 4),
                      _starRow(t.overallRating, size: 16),
                      const SizedBox(height: 2),
                      Text(
                        t.reviewCount == 0
                            ? 'No reviews yet'
                            : '${t.reviewCount} student reviews',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: c.tealInk.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialsCard(AppColors c, Teacher t) {
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
          color: c.white, borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 18,
                offset: Offset(0, 8)),
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
          const SizedBox(height: 14),
          Row(
            children: [
              _dial(c, 'Grading', t.gradingPct, t.avgGrading, c.teal),
              _dial(c, 'Leniency', t.leniencyPct, t.avgLeniency, c.board),
              _dial(c, 'Subject', t.subjectPct, t.avgSubject, c.clay),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dial(
      AppColors c, String label, int pct, double avg, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
            color: c.cream2, borderRadius: BorderRadius.circular(18)),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 66,
                  height: 66,
                  child: CircularProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: c.dustSoft.withValues(alpha: 0.8),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Text('$pct%',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.tealInk.withValues(alpha: 0.65))),
            Text('${avg.toStringAsFixed(1)} / 5',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _reviewTile(AppColors c, TeacherReview r) {
    final avatarColors = [c.teal, c.clay, c.board, c.tealDeep];
    final avatarBg = avatarColors[r.studentName.length % avatarColors.length];
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: c.cream2, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: avatarBg,
                child: Text(
                  r.studentName.isEmpty
                      ? '?'
                      : r.studentName[0].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w800),
                ),
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
                    _starRow(r.average, size: 11),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.white,
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
            const SizedBox(height: 8),
            Text(r.comment, style: const TextStyle(fontSize: 14, height: 1.35)),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              _miniStat(c, 'Grading ${r.ratingGrading}'),
              _miniStat(c, 'Leniency ${r.ratingLeniency}'),
              _miniStat(c, 'Subject ${r.ratingSubject}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(AppColors c, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.dustSoft)),
      child: Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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
                          ? Container(
                              color: c.dustSoft,
                              child: const Icon(Icons.person))
                          : Image.network(
                              widget.teacher.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                  color: c.dustSoft,
                                  child: const Icon(Icons.person)),
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
