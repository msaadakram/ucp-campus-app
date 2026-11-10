/// The class-sync pipeline shared by the app shell and the leaderboard.
///
/// When a student opens a leaderboard the app proves three things, in
/// this order, and the student SEES each step:
///
///   1. the student is signed in to the portal (Microsoft account ->
///      Horizon session cookie) — without a session nothing can be read;
///   2. the TIMETABLE is published (the parsed schedule is already in
///      memory; it says which sections the student is in, so the server
///      can build the class roster);
///   3. the SELECTED subject's grade page — one page, fetched and parsed,
///      never the whole timetable's worth of grade pages;
///   4. the BOARD of the selected subject is requested with the subject
///      AND the student's id — the server answers with the classmates'
///      grades and the student's own grade.
///
/// This whole path works WITHOUT the Chrome extension: the app reads the
/// portal with the student's own session and publishes what it finds.
library;

/// The ONE subject a leaderboard open needs to read from the portal.
///
/// The old pipeline fetched every subject's grade page on every board
/// view — six to eight full portal pages (about 1.4 MB of HTML each) to
/// show a single class. Production reads what the screen is about: the
/// selected subject only. The timetable is still published (it is already
/// parsed locally), because it is what groups the student with their
/// section.
class LeaderboardSyncTarget {
  /// The portal course name (keeps the "- Lab" suffix, so theory and lab
  /// stay separate). This is the name the marks are published under.
  final String courseName;

  /// Course code or FULL section code (e.g. "CP233-R26-BS-SE-F24-SED1").
  /// Used only to disambiguate two subjects with the same title.
  final String courseCode;

  const LeaderboardSyncTarget({
    required this.courseName,
    this.courseCode = '',
  });

  /// Stable key for de-duplicating syncs in one screen session.
  String get key =>
      (courseCode.trim().isNotEmpty ? courseCode : courseName).trim().toUpperCase();

  bool get isEmpty => courseName.trim().isEmpty && courseCode.trim().isEmpty;
}

/// Kind of a pipeline step.
enum SyncStepKind {
  /// Checking the Microsoft sign-in / session cookie.
  session,

  /// Reading the timetable and sending it to the server.
  timetable,

  /// Reading + parsing + publishing one subject's grade page.
  grade,

  /// Requesting the leaderboard of a subject.
  board,
}

/// State of a pipeline step.
enum SyncStepState {
  pending,
  active,
  done,
  failed,
}

/// One update of the pipeline (emitted by the app shell while it runs).
class SyncStepUpdate {
  /// Stable id of the step ("session", "timetable", "grade:CP233",
  /// "board:CP233"). The screen merges updates by this key.
  final String key;
  final SyncStepKind kind;

  /// What the step is doing, in the student's words.
  final String label;

  /// Extra context (the subject name, the row count, …).
  final String? detail;

  final SyncStepState state;
  final String? error;

  const SyncStepUpdate({
    required this.key,
    required this.kind,
    required this.label,
    this.detail,
    this.state = SyncStepState.pending,
    this.error,
  });

  SyncStepUpdate copyWith({
    String? label,
    String? detail,
    SyncStepState? state,
    String? error,
  }) {
    return SyncStepUpdate(
      key: key,
      kind: kind,
      label: label ?? this.label,
      detail: detail ?? this.detail,
      state: state ?? this.state,
      error: error ?? this.error,
    );
  }
}

/// State of the portal session (the Microsoft sign-in -> Horizon cookie).
///
/// These are three DIFFERENT situations and they must not be collapsed
/// into one boolean: telling a student to sign in again because the
/// network hiccuped is wrong, and it used to happen.
enum PortalSessionState {
  /// The session works.
  alive,

  /// The portal explicitly reported that the session is gone (login
  /// page / redirect) — the student must sign in again.
  expired,

  /// The portal could not be reached (offline, timeout, 5xx). The
  /// session may be perfectly fine — we simply could not check it.
  unreachable,
}

/// Result of one full class sync.
class LeaderboardSyncReport {
  /// Rows published to the server (the student's weekly slots).
  final int timetableRows;

  /// Subjects whose marks were published.
  final int subjectsSynced;

  /// Subjects that could not be read (the portal has no gradebook, the
  /// page failed, …). The sync continues past them.
  final int subjectsFailed;

  /// The subjects that failed, for display.
  final List<String> failures;

  /// True when the student had to sign in before the sync could run.
  final bool signedInDuringSync;

  /// What the session check found (null when the sync never got that
  /// far, e.g. the backend is not configured).
  final PortalSessionState? sessionState;

  const LeaderboardSyncReport({
    this.timetableRows = 0,
    this.subjectsSynced = 0,
    this.subjectsFailed = 0,
    this.failures = const [],
    this.signedInDuringSync = false,
    this.sessionState,
  });

  bool get ok => timetableRows > 0 || subjectsSynced > 0;
}
