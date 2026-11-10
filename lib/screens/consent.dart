import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../widgets/common.dart';

/// First-run consent gate shown before ANY student data is ever sent to
/// the ucp.animezone.me server. Until the student picks one of the two
/// options, the app publishes nothing (no timetable, no grades, no
/// session jar).
///
/// The two choices are NOT symmetric and the copy must not pretend
/// otherwise:
///   * publish — appears on the class board with marks + timetable +
///               (one latest encrypted session jar for app↔extension
///               continuity). This is what makes the leaderboard worth
///               having for the class.
///   * private — the app works read-only: the class board shows
///               classmates but never your marks. Your own session and
///               marks stay on the device only.
class ConsentScreen extends StatelessWidget {
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;
  const ConsentScreen({super.key, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return UHead(
      height: 116,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.article_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Your privacy', style: display(c, size: 22, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Before anything leaves this phone…',
            style: body(c, size: 13, color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 18),
          _section(
            c,
            'What is shared when you publish',
            [
              _bullet(c, Icons.assignment_outlined,
                  'Your course marks, so classmates in your section can see where you stand.'),
              _bullet(c, Icons.calendar_month_outlined,
                  'Your timetable (day, time, teacher, room, section) so the board matches your actual class.'),
              _bullet(c, Icons.lock_outline,
                  'Your session keeps you signed in across the app and the extension — one latest encrypted jar per student, auto-expires after 90 days.'),
            ],
          ),
          const SizedBox(height: 14),
          _section(
            c,
            'What you always control',
            [
              _bullet(c, Icons.visibility_off_outlined,
                  'Hide your name or photo on every board at once — in Profile → Privacy & security.'),
              _bullet(c, Icons.delete_outline,
                  'Ask for your stored data to be deleted — contact the developer; it happens within 7 days.'),
              _bullet(c, Icons.bolt_outlined,
                  'The leaderboard works on free views — your data is never sold.'),
            ],
          ),
          const SizedBox(height: 14),
          _note(c),
          const SizedBox(height: 18),
          ClayButton(
            label: 'Publish to my class',
            colors: c,
            height: 54,
            fontSize: 16,
            onPressed: onAccept,
          ),
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDecline,
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.dustSoft.withValues(alpha: 0.6)),
              ),
              child: Text(
                'Continue without sharing',
                style: body(c, size: 15, weight: FontWeight.w800,
                    color: c.tealInk),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'You can change this later in Profile → Privacy & security. '
            'Details: the privacy policy on the app backend, and Profile → Help.',
            style: body(c, size: 11,
                color: c.tealInk.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  static Widget _section(AppColors c, String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.dustSoft.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: display(c, size: 14.5, color: c.tealInk)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  static Widget _bullet(AppColors c, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: c.teal),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text,
                style: body(c,
                    size: 12.5,
                    color: c.tealInk.withValues(alpha: 0.85))),
          ),
        ],
      ),
    );
  }

  static Widget _note(AppColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.board.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.board.withValues(alpha: 0.3)),
      ),
      child: Text(
        'Private keeps the boards fully usable — you just will not appear '
        'on them, and nothing of your marks ever leaves this device.',
        style: body(c, size: 12, color: c.tealInk.withValues(alpha: 0.8)),
      ),
    );
  }
}
