// ============================================================
// Portal date/time parsing + formatting shared by the course
// pages (assessments, submissions, grades, attendance).
//
// The Horizon portal renders timestamps in several shapes:
//   2026-10-15 13:00        (most tables)
//   2026-10-15              (date-only cells)
//   15 Oct 2026 13:00       (some exports)
//   2026/10/15, 1:00 PM     (partial locale pages)
// Exactly one of each form is matched; anything unrecognised
// returns null and the caller falls back to the raw string.
// ============================================================
library;

const _months = <String, int>{
  'jan': 1,
  'january': 1,
  'feb': 2,
  'february': 2,
  'mar': 3,
  'march': 3,
  'apr': 4,
  'april': 4,
  'may': 5,
  'jun': 6,
  'june': 6,
  'jul': 7,
  'july': 7,
  'aug': 8,
  'august': 8,
  'sep': 9,
  'sept': 9,
  'september': 9,
  'oct': 10,
  'october': 10,
  'nov': 11,
  'november': 11,
  'dec': 12,
  'december': 12,
};

/// Parses an hour+minute tail with an optional AM/PM marker.
({int hour, int minute})? _hourMinute(String? h, String? m, String? ampm) {
  final hour = int.tryParse(h ?? '');
  final minute = int.tryParse(m ?? '');
  if (hour == null || minute == null || minute < 0 || minute > 59) {
    return null;
  }
  var h24 = hour % 24;
  if (ampm != null && ampm.isNotEmpty) {
    var hh = hour % 12;
    if (ampm.toLowerCase().startsWith('p')) hh += 12;
    h24 = hh;
    if (hh > 23) return null;
  }
  return (hour: h24, minute: minute);
}

/// Parses a portal timestamp. Returns null when the text does not
/// describe a date the app can use.
DateTime? parsePortalDateTime(String raw) {
  final s = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.isEmpty) return null;

  // ---- 2026-10-15[ 13:00(:30)? (AM|PM)?] or with / or . separators ----
  final iso = RegExp(
    r'(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?:[ T]*(\d{1,2}):(\d{2})(?::\d{1,2})?(?:\s*([AaPp])[Mm])?)?' ,
  ).firstMatch(s);
  if (iso != null) {
    final ampm = iso.group(6);
    final hm = _hourMinute(iso.group(4), iso.group(5), ampm);
    if (hm == null && iso.group(4) != null) return null;
    final result = DateTime(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
      hm?.hour ?? 0,
      hm?.minute ?? 0,
    );
    return result;
  }

  // ---- 15 Oct 2026 [13:00 (AM|PM)?] ----
  final dmy = RegExp(
    r'(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{4})(?:[ ,]*(\d{1,2}):(\d{2})(?:\s*([AaPp])[Mm])?)?',
  ).firstMatch(s);
  if (dmy != null) {
    final month = _months[dmy.group(2)!.toLowerCase()];
    if (month != null) {
      final hm = _hourMinute(dmy.group(4), dmy.group(5), dmy.group(6));
      if (hm == null && dmy.group(4) != null) return null;
      return DateTime(
        int.parse(dmy.group(3)!),
        month,
        int.parse(dmy.group(1)!),
        hm?.hour ?? 0,
        hm?.minute ?? 0,
      );
    }
  }

  // ---- Oct 15, 2026 [1:00 PM] ----
  final mdy = RegExp(
    r'([A-Za-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?\s*,?\s+(\d{4})(?:[ ,]*(\d{1,2}):(\d{2})(?:\s*([AaPp])[Mm])?)?',
  ).firstMatch(s);
  if (mdy != null) {
    final month = _months[mdy.group(1)!.toLowerCase()];
    if (month != null) {
      final hm = _hourMinute(mdy.group(4), mdy.group(5), mdy.group(6));
      if (hm == null && mdy.group(4) != null) return null;
      return DateTime(
        int.parse(mdy.group(3)!),
        month,
        int.parse(mdy.group(2)!),
        hm?.hour ?? 0,
        hm?.minute ?? 0,
      );
    }
  }

  // ---- 15/10/2026[ 13:00] (day first) ----
  final dmyNum = RegExp(
    r'(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})(?:[ T]*(\d{1,2}):(\d{2})(?:\s*([AaPp])[Mm])?)?',
  ).firstMatch(s);
  if (dmyNum != null) {
    final d = int.parse(dmyNum.group(1)!);
    final m = int.parse(dmyNum.group(2)!);
    if (d > 31 || m > 12 || m < 1) return null;
    final year = int.parse(dmyNum.group(3)!) + (dmyNum.group(3)!.length == 2 ? 2000 : 0);
    final hm = _hourMinute(dmyNum.group(4), dmyNum.group(5), dmyNum.group(6));
    if (hm == null && dmyNum.group(4) != null) return null;
    return DateTime(year, m, d, hm?.hour ?? 0, hm?.minute ?? 0);
  }

  return null;
}

const _weekdayShort = {
  1: 'Mon',
  2: 'Tue',
  3: 'Wed',
  4: 'Thu',
  5: 'Fri',
  6: 'Sat',
  7: 'Sun',
};

const _monthShort = {
  1: 'Jan',
  2: 'Feb',
  3: 'Mar',
  4: 'Apr',
  5: 'May',
  6: 'Jun',
  7: 'Jul',
  8: 'Aug',
  9: 'Sep',
  10: 'Oct',
  11: 'Nov',
  12: 'Dec',
};

/// "Mon 13 Oct 2026" (every portal date the app shows).
String formatPortalDay(DateTime d) =>
    '${_weekdayShort[d.weekday]} ${d.day.toString().padLeft(2, '0')} '
    '${_monthShort[d.month]} ${d.year}';

/// "1:00 PM".
String formatPortalTime(DateTime d) {
  final minutes = d.minute.toString().padLeft(2, '0');
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour >= 12 ? 'PM' : 'AM';
  return '$h12:$minutes $ampm';
}

/// "Mon 13 Oct · 1:00 PM".
String formatPortalStamp(DateTime d) =>
    '${formatPortalDay(d)} · ${formatPortalTime(d)}';

/// Due-in relation: signed count of calendar days between [due] and
/// [now] at day resolution. Negative = already past.
int dueDayDelta(DateTime now, DateTime due) {
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(due.year, due.month, due.day);
  return b.difference(a).inDays;
}
