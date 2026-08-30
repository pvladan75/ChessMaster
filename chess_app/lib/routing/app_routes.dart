/// Every navigable destination in the app, in one place.
///
/// Paths are the contract: they show up in deep links and in restored
/// navigation state, so treat a change here as a breaking change.
abstract final class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';

  /// Live lesson/game room. `:roomCode` is the join code; an optional `role`
  /// query parameter seeds the local role until the server confirms it.
  static const String room = '/room/:roomCode';

  /// Analysis board. Optional `fen` query parameter opens a specific position;
  /// without it the screen restores the user's autosaved draft.
  static const String analysis = '/analysis';

  /// Recorded lesson playback.
  static const String replay = '/replay/:recordingId';

  /// Adaptive tactics training on the Lichess puzzle set.
  static const String tactics = '/tactics';

  /// Endgame technique on positions mined from master games. The mode is a
  /// query parameter because converting a win and holding a draw are separate
  /// exercises, not two views of one.
  static const String endgames = '/endgames';

  /// Walking a real game from where it first went wrong, stopping at every
  /// mistake in it. A game rather than a position, which is why it is its own
  /// route and its own screen.
  static const String blunderGames = '/endgames/blunders';

  /// Choosing which endings to practise, and at which level, before any board
  /// is drawn. The mode rides on the query the same way as for [endgames].
  static const String endgamePicker = '/endgames/picker';

  /// The crossroads of practice: what there is to train, as a list of cards and
  /// nothing else. It draws no board, which is the whole point of it being its
  /// own place - choosing and doing were one 2662-line screen.
  static const String training = '/training';

  /// One working screen for the exercises that share a board and a verdict.
  /// `category` says which: mate_puzzle, basic_mate or winning_position, with
  /// `depth` for the first and `level` for the second. Three near-identical
  /// screens would be three places to fix the same bug.
  static const String trainingDrill = '/training/drill';

  /// The student's own opening repertoire: the list of what they have started,
  /// and the screen that asks them what they would play. Its own route because
  /// it is a place, and because the training hub and Settings both name it.
  static const String repertoire = '/repertoire';

  /// Homework, from the student's side: what has been set, and what is done.
  static const String assignments = '/assignments';

  /// One assignment's result, graded. `:id` is the assignment; an optional
  /// `title` rides along so the heading is right before the fetch answers, and
  /// the screen lives without it.
  static const String assignmentReview = '/assignments/:id/review';

  /// The positions of a custom assignment, as a grid to work through.
  static const String assignmentOverview = '/assignments/:id/positions';

  /// An assignment that is a lesson rather than a set of positions.
  static const String assignmentLesson = '/assignments/:id/lesson';

  /// The puzzles of an assignment that are still unanswered, in order. Its own
  /// path rather than a list of ids on `/tactics`: a list of ids is not a path,
  /// and "what is left of this homework" is a place - the remainder is worked
  /// out from the assignment when it opens.
  static const String assignmentTactics = '/assignments/:id/tactics';

  /// Spaced repetition: whatever is due today, in one sitting.
  static const String review = '/review';

  /// One student's progress, for whoever teaches them. `name` is decoration on
  /// the same terms as the assignment's title.
  static const String studentProgress = '/students/:id';

  /// Reading positions out of a trainer's own book and confirming them.
  static const String scan = '/scan';

  /// Positions the trainer has already confirmed and kept.
  static const String savedPositions = '/scan/saved';

  /// App settings pushed *over* the current screen. Distinct from the Settings
  /// tab inside the home shell: this variant keeps the analysis board or a live
  /// room mounted underneath, so closing it returns the user exactly where they
  /// were rather than tearing their work down.
  static const String preferences = '/preferences';

  /// The keyboard shortcuts, written down. A place rather than a dialog because
  /// two things that must not know about each other open it — the F1 key and a
  /// row in Settings — and a path is what both can name.
  static const String shortcuts = '/shortcuts';

  /// Correcting the stated year of birth. The gate itself is not a route — it
  /// draws over the whole app until it is answered — but the answer has to stay
  /// reachable afterwards: somebody who typed 2017 instead of 1997 must not be
  /// locked out by a field they can never open again.
  static const String birthYear = '/birth-year';

  // ── Builders, so callers never hand-assemble a path ──

  static String roomPath(String roomCode, {String? role}) {
    final query = role == null || role.isEmpty ? '' : '?role=$role';
    return '/room/${Uri.encodeComponent(roomCode)}$query';
  }

  static String analysisPath({String? fen}) {
    if (fen == null || fen.isEmpty) return analysis;
    return '$analysis?fen=${Uri.encodeComponent(fen)}';
  }

  static String replayPath(int recordingId) => '/replay/$recordingId';

  static String assignmentReviewPath(int id, {String? title}) =>
      '/assignments/$id/review${title == null || title.isEmpty ? '' : '?title=${Uri.encodeComponent(title)}'}';

  static String assignmentOverviewPath(int id) => '/assignments/$id/positions';

  static String assignmentTacticsPath(int id) => '/assignments/$id/tactics';

  static String assignmentLessonPath(int id) => '/assignments/$id/lesson';

  static String studentProgressPath(int id, {String? name}) =>
      '/students/$id${name == null || name.isEmpty ? '' : '?name=${Uri.encodeComponent(name)}'}';

  /// The drill, with the exercise it is opening. [depth] belongs to the mate
  /// puzzles and [level] to basic mating; passing the wrong one is harmless and
  /// ignored, which is why they are named rather than positional.
  static String drillPath(String category, {String? depth, String? level}) {
    final query = <String>[
      'category=$category',
      if (depth != null && depth.isNotEmpty) 'depth=$depth',
      if (level != null && level.isNotEmpty)
        'level=${Uri.encodeComponent(level)}',
    ].join('&');
    return '$trainingDrill?$query';
  }

  /// The player's own archive: they hand over a PGN export and the importer
  /// turns it into rows. The entry point for the whole feature, because the
  /// report below is meaningless against an archive nobody has imported yet.
  static const String archiveImport = '/archive/import';

  /// Where the same early choice keeps going badly. `subject` is the handle the
  /// archive was imported under and is required — the report is per-player, and
  /// this screen has no way to guess which player. It rides in the query rather
  /// than the path so a handle with a slash in it cannot break the route.
  static const String archiveLeaks = '/archive/leaks';

  static String archiveLeaksPath(String subject) =>
      '$archiveLeaks?subject=${Uri.encodeQueryComponent(subject)}';

  static const String archiveMistakes = '/archive/mistakes';

  static const String archiveRepertoire = '/archive/repertoire';

  /// The endgames the tablebases say were thrown away. `subject` is the handle
  /// the archive was imported under and is required, for the same reason the
  /// leak report needs one: the audit is per-player and this screen cannot
  /// guess which.
  static const String archiveEndgames = '/archive/endgames';

  static String archiveEndgamesPath(String subject) =>
      '$archiveEndgames?subject=${Uri.encodeQueryComponent(subject)}';

  /// Internal design gallery for design review and visual component inspection.
  static const String designGallery = '/design-gallery';
}
