/// The class-sync pipeline shared by the app shell and the leaderboard.
///
/// When a student opens a leaderboard the app must be able to prove three
/// things, in this order:
///
///   1. the student is signed in to the portal (Microsoft account ->
///      Horizon session cookie) — without a session nothing can be read;
///   2. the TIMETABLE (read with that session cookie) — it says which
///      sections the student is in, so the server can build the class
///      roster;
///   3. every subject's GRADE PAGE — parsed and published so the
///      student's marks reach the server and the board can rank them.
///
/// Only then is the board fetched, class by class.
library;

/// Step of the sync pipeline (drives the progress UI).
enum LeaderboardSyncStage {
  /// Checking the portal sign-in / session cookie.
  session,

  /// Reading the timetable with the session cookie.
  timetable,

  /// Reading + publishing each subject's grade page.
  grades,

  /// Fetching the class boards.
  board,
}

/// Human label for a stage.
String leaderboardSyncStageLabel(LeaderboardSyncStage stage) {
  switch (stage) {
    case LeaderboardSyncStage.session:
      return 'Checking your portal sign-in';
    case LeaderboardSyncStage.timetable:
      return 'Reading your timetable';
    case LeaderboardSyncStage.grades:
      return 'Reading your grade pages';
    case LeaderboardSyncStage.board:
      return 'Loading class boards';
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
