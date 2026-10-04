import 'dart:async';

import 'package:flutter/material.dart';

import '../teachers/teacher_models.dart';
import '../teachers/teacher_service.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/loading.dart';

/// Teacher reviews page: photo grid/list, separate 3-dimension ratings,
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        detailLoading = false;
        detailError = 'Could not load reviews. Retry.';
      });
    }
  }

  Future<void> _openRateSheet(Teacher t) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(e is TeacherException
                      ? e.message
                      : 'Could not save rating. Try again.'),
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
      height: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(c),
          const SizedBox(height: 12),
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
                color: c.white, borderRadius: BorderRadius.circular(24)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Teachers', style: display(c, size: 28, color: Colors.white)),
        Text(
          teachers.isEmpty
              ? 'Photos, ratings & student reviews'
              : '${teachers.length} teachers · tap a photo for reviews',
          style: body(c, size: 14, color: Colors.white.withValues(alpha: 0.78)),
        ),
      ],
    );
  }

  Widget _searchBar(AppColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration:
          BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(16)),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search by name…',
          border: InputBorder.none,
          icon: const Icon(Icons.search, size: 20),
          suffixIcon: query.isEmpty && _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    query = '';
                    _reload();
                  },
                ),
        ),
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
                  setState(() => dept = code);
                  _reload();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: dept == code ? c.tealInk : c.dustSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: dept == code
                          ? c.cream
                          : c.tealInk.withValues(alpha: 0.7),
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
          color: c.dustSoft.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(30)),
      child: Row(
        children: [
          for (final s in ['Top', 'Most reviewed', 'Name'])
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => sort = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: sort == s ? c.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    s,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: sort == s
                          ? c.tealInk
                          : c.tealInk.withValues(alpha: 0.55),
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
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: c.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Text(error!, textAlign: TextAlign.center, style: body(c, size: 14)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _reload,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                  color: c.teal, borderRadius: BorderRadius.circular(20)),
              child: const Text('Retry',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(AppColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text('No teachers found.\nTry another search or faculty.',
            textAlign: TextAlign.center,
            style: body(c, size: 14, color: c.tealInk.withValues(alpha: 0.5))),
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
            color: c.white, borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 72,
                height: 72,
                child: t.imageUrl.isEmpty
                    ? Container(
                        color: c.dustSoft,
                        child: Icon(Icons.person,
                            size: 36, color: c.tealInk.withValues(alpha: 0.4)),
                      )
                    : Image.network(
                        t.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: c.dustSoft,
                          child: Icon(Icons.person,
                              size: 36,
                              color: c.tealInk.withValues(alpha: 0.4)),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: display(c, size: 16)),
                  Text(
                    t.designation.isEmpty
                        ? t.departmentName
                        : '${t.designation} · ${_shortDept(t)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(c,
                        size: 12, color: c.tealInk.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 15, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        t.reviewCount == 0
                            ? 'No reviews yet'
                            : '${t.overallRating.toStringAsFixed(1)} (${t.reviewCount})',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      if (t.reviewCount > 0)
                        Expanded(
                          child: Text(
                            'G ${t.gradingPct}% · L ${t.leniencyPct}% · S ${t.subjectPct}%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                color: c.tealInk.withValues(alpha: 0.6)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }

  String _shortDept(Teacher t) {
    if (t.departmentCode.isEmpty) return t.departmentName;
    return t.departmentCode.toUpperCase();
  }

  Widget _detailView(AppColors c, Teacher t) {
    return Padding(
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
                child: const Row(children: [
                  Icon(Icons.arrow_back, size: 18),
                  Text(' Teachers',
                      style: TextStyle(fontWeight: FontWeight.w600))
                ]),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _openRateSheet(t),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      color: c.teal,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Row(children: [
                    Icon(Icons.star_outline, size: 16, color: Colors.white),
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
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _detailHeader(c, t),
                  const SizedBox(height: 12),
                  _dialsCard(c, t),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: c.white,
                        borderRadius: BorderRadius.circular(24)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${reviews.length} STUDENT REVIEWS'
                                .toUpperCase(),
                            style: TextStyle(
                                fontSize: 12,
                                color: c.tealInk.withValues(alpha: 0.55))),
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
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailHeader(AppColors c, Teacher t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: c.white, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 88,
              height: 88,
              child: t.imageUrl.isEmpty
                  ? Container(
                      color: c.dustSoft,
                      child: Icon(Icons.person,
                          size: 44, color: c.tealInk.withValues(alpha: 0.4)),
                    )
                  : Image.network(
                      t.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: c.dustSoft,
                        child: Icon(Icons.person,
                            size: 44,
                            color: c.tealInk.withValues(alpha: 0.4)),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name, style: display(c, size: 19)),
                Text(
                  t.designation.isEmpty
                      ? t.departmentName
                      : '${t.designation}\n${t.departmentName}',
                  style: body(c,
                      size: 12, color: c.tealInk.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, size: 17, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      t.reviewCount == 0
                          ? 'No reviews yet'
                          : '${t.overallRating.toStringAsFixed(1)} · ${t.reviewCount} reviews',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialsCard(AppColors c, Teacher t) {
    if (t.reviewCount == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: c.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HOW STUDENTS RATE',
              style: TextStyle(
                  fontSize: 12, color: c.tealInk.withValues(alpha: 0.55))),
          const SizedBox(height: 12),
          Row(
            children: [
              _dial(c, 'Grading', t.gradingPct, t.avgGrading),
              _dial(c, 'Leniency', t.leniencyPct, t.avgLeniency),
              _dial(c, 'Subject', t.subjectPct, t.avgSubject),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dial(AppColors c, String label, int pct, double avg) {
    return Expanded(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: (pct / 100).clamp(0.0, 1.0),
                  strokeWidth: 7,
                  backgroundColor: c.dustSoft,
                  valueColor: AlwaysStoppedAnimation(c.teal),
                ),
              ),
              Text('$pct%',
                  style:
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: c.tealInk.withValues(alpha: 0.65))),
          Text(avg.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _reviewTile(AppColors c, TeacherReview r) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: c.cream2, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                child: Text(
                  r.studentName.isEmpty
                      ? '?'
                      : r.studentName[0].toUpperCase(),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(r.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const Icon(Icons.star, size: 14, color: Colors.amber),
              Text(' ${r.average.toStringAsFixed(1)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          if (r.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(r.comment, style: const TextStyle(fontSize: 14)),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              _miniStat('G ${r.ratingGrading}'),
              _miniStat('L ${r.ratingLeniency}'),
              _miniStat('S ${r.ratingSubject}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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

class _RateSheetState extends State<_RateSheet> {
  int grading = 5;
  int leniency = 5;
  int subject = 5;
  late final TextEditingController _commentCtrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _commentCtrl = TextEditingController();
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
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: BoxDecoration(
          color: c.cream2,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
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
              const SizedBox(height: 10),
              Text('Rate ${widget.teacher.name}',
                  style: display(c, size: 18)),
              Text('1 = poor · 5 = excellent',
                  style: body(c,
                      size: 12, color: c.tealInk.withValues(alpha: 0.6))),
              const SizedBox(height: 12),
              _starsRow(c, 'Grading fairness', grading,
                  (v) => setState(() => grading = v)),
              _starsRow(c, 'Leniency', leniency,
                  (v) => setState(() => leniency = v)),
              _starsRow(c, 'Subject knowledge', subject,
                  (v) => setState(() => subject = v)),
              const SizedBox(height: 12),
              TextField(
                controller: _commentCtrl,
                maxLines: 3,
                maxLength: 500,
                enabled: !_busy,
                decoration: InputDecoration(
                  hintText: 'Write a short anonymous review (optional)…',
                  filled: true,
                  fillColor: c.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                        color: c.teal,
                        borderRadius: BorderRadius.circular(20)),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                    Colors.white)),
                          )
                        : const Text('Submit rating',
                            style: TextStyle(
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

  Widget _starsRow(
      AppColors c, String label, int value, ValueChanged<int> onPick) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: body(c, size: 14))),
          for (int i = 1; i <= 5; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onPick(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  i <= value ? Icons.star : Icons.star_outline,
                  size: 28,
                  color: Colors.amber,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
