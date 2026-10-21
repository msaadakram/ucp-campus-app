/// The class-sync pipeline shared by the app shell and the leaderboard.
///
/// When a student opens a leaderboard the app proves three things, in
/// this order, and the student SEES each step:
///
///   1. the student is signed in to the portal (Microsoft account ->
///      Horizon session cookie) — without a session nothing can be read;
///   2. the TIMETABLE (read with that session cookie) — it says which
///      sections the student is in, so the server can build the class
///      roster;
///   3. every subject's GRADE PAGE — the HTML is fetched, parsed and
///      published with the student's id, so the server knows the marks;
///   4. the BOARD of the selected subject is requested with the subject
///      AND the student's id — the server answers with the classmates'
///      grades and the student's own grade.
///
/// This whole path works WITHOUT the Chrome extension: the app reads the
/// portal with the student's own session and publishes what it finds.
library;

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

  const LeaderboardSyncReport({
    this.timetableRows = 0,
    this.subjectsSynced = 0,
    this.subjectsFailed = 0,
    this.failures = const [],
    this.signedInDuringSync = false,
  });

  bool get ok => timetableRows > 0 || subjectsSynced > 0;
}
