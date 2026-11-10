import 'package:flutter_test/flutter_test.dart';
import 'package:ucp/auth/portal_dates.dart';

void main() {
  group('parsePortalDateTime', () {
    test('portal tables render yyyy-mm-dd hh:mm', () {
      final d = parsePortalDateTime('2026-10-15 13:00')!;
      expect(d.year, 2026);
      expect(d.month, 10);
      expect(d.day, 15);
      expect(d.hour, 13);
      expect(d.minute, 0);
    });

    test('date-only cells parse to midnight', () {
      final d = parsePortalDateTime('2026-10-08')!;
      expect(d.year, 2026);
      expect(d.hour, 0);
      expect(d.minute, 0);
    });

    test('PM markers add 12h', () {
      final d = parsePortalDateTime('Oct 15, 2026, 1:30 PM')!;
      expect(d.hour, 13);
      expect(d.minute, 30);
    });

    test('day-month-year with month name', () {
      final d = parsePortalDateTime('15 Oct 2026 13:00')!;
      expect(d.month, 10);
      expect(d.day, 15);
      expect(d.hour, 13);
    });

    test('day-first numeric falls back safely', () {
      expect(parsePortalDateTime('15/10/2026 13:00')!.month, 10);
      expect(parsePortalDateTime('40/13/2026'), isNull);
    });

    test('unrecognised text yields null, never throws', () {
      expect(parsePortalDateTime('someday next week'), isNull);
      expect(parsePortalDateTime(''), isNull);
    });
  });

  group('formatting', () {
    test('day and stamp formats', () {
      final d = DateTime(2026, 10, 15, 13, 30);
      expect(formatPortalDay(d), 'Thu 15 Oct 2026');
      expect(formatPortalTime(d), '1:30 PM');
      expect(formatPortalStamp(d), 'Thu 15 Oct 2026 · 1:30 PM');
    });

    test('midnight reads as AM', () {
      expect(formatPortalTime(DateTime(2026, 10, 15)), '12:00 AM');
    });
  });

  group('dueDayDelta', () {
    test('same day is 0, tomorrow is 1, yesterday is -1', () {
      final now = DateTime(2026, 10, 15, 20, 0); // evening
      expect(dueDayDelta(now, DateTime(2026, 10, 15, 1, 0)), 0);
      expect(dueDayDelta(now, DateTime(2026, 10, 16, 1, 0)), 1);
      expect(dueDayDelta(now, DateTime(2026, 10, 14, 23, 0)), -1);
    });
  });
}
