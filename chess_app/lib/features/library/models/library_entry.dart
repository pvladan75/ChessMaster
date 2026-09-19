/// One entry on the trainer's shelf, whichever shelf it actually came from.
///
/// Three tables feed this: positions scanned out of a book, single boards saved
/// from the studio, and saved variation trees. They are not merged server-side
/// and this is not a merge either — [kind] stays visible, because a tree of
/// variations and a mate in one are not the same thing to anyone using them.
/// What the type buys is one list to look at, where before a scanned position
/// could not be put into a lesson at all.
enum LibraryKind {
  /// Read out of the trainer's own book. The only kind that carries a solution.
  scan,

  /// A single board saved from the studio — `saved_lessons` without steps.
  position,

  /// A saved variation tree. Listed without the tree; whoever takes one loads
  /// it separately, because the tree is the heavy half.
  analysis,

  /// A tutorial — `saved_lessons` *with* steps. Phase 3 of
  /// `docs/PLAN-REORGANIZACIJA.md` (S3): one library of everything a user
  /// keeps, so the shelf the studio writes to is on it too.
  tutorial,

  /// A recording of a session, this user's own. Played, never put on a board.
  recording,

  /// A puzzle set written by „Review entire game". Device-local: the server
  /// never sees one, so it has no wire name and `libraryKindFrom` never
  /// answers it — the client adds these rows itself.
  puzzleSet,
}

LibraryKind? libraryKindFrom(String? raw) => switch (raw) {
      'scan' => LibraryKind.scan,
      'position' => LibraryKind.position,
      'analysis' => LibraryKind.analysis,
      'tutorial' => LibraryKind.tutorial,
      'recording' => LibraryKind.recording,
      _ => null,
    };

/// The name the server knows a kind by. A puzzle set has none — asking the
/// server for one is a programming error, not a request.
String libraryKindWire(LibraryKind kind) => switch (kind) {
      LibraryKind.scan => 'scan',
      LibraryKind.position => 'position',
      LibraryKind.analysis => 'analysis',
      LibraryKind.tutorial => 'tutorial',
      LibraryKind.recording => 'recording',
      LibraryKind.puzzleSet => throw ArgumentError(
          'a puzzle set is device-local and has no wire kind'),
    };

String libraryKindLabel(LibraryKind kind) => switch (kind) {
      LibraryKind.scan => 'from book',
      LibraryKind.position => 'saved positions',
      LibraryKind.analysis => 'analyses',
      LibraryKind.tutorial => 'tutorials',
      LibraryKind.recording => 'recordings',
      LibraryKind.puzzleSet => 'puzzle sets',
    };

class LibraryEntry {
  const LibraryEntry({
    required this.kind,
    required this.id,
    required this.title,
    required this.fen,
    required this.assignable,
    this.blockedReason,
    this.instruction,
    this.pgn,
    this.solutionSan,
    this.themes = const [],
    this.hasSolution = false,
    this.needsReview = false,
    this.fromTrainer = false,
    this.sourceTitle,
    this.sourcePage,
    this.sourceLabel,
    this.partsCount,
    this.hasVideo = false,
    this.rendering = false,
    this.createdAt,
    this.origin = 'book',
    this.task,
  });

  final LibraryKind kind;

  /// `puzzle_id` for a scan, the row id as text otherwise. Only ever compared,
  /// never parsed — the two id spaces are different and must not be mixed.
  final String id;

  final String title;
  final String fen;

  /// What the student is asked to do here. Only a scanned position carries one
  /// today; it must travel when the position enters a lesson, or the child gets
  /// a board with no question on it again.
  final String? instruction;

  final String? pgn;

  /// The author's move, where one is known. A lesson is read rather than
  /// solved, so nothing plays it — it travels so the step can later become
  /// homework without the move having been lost on the way in.
  final String? solutionSan;

  final List<String> themes;
  final bool hasSolution;
  final bool needsReview;

  /// Whether this may be set as homework, decided by the server so the rule
  /// lives in one place. [blockedReason] is the server's own words for why not.
  final bool assignable;
  final String? blockedReason;

  /// Someone else's material, readable because they teach this user.
  final bool fromTrainer;

  final String? sourceTitle;
  final int? sourcePage;
  final String? sourceLabel;

  /// A tutorial's number of parts; null for every other kind.
  final int? partsCount;

  /// A tutorial or a recording that has a film ready to download.
  final bool hasVideo;

  /// A tutorial whose film is being drawn right now.
  final bool rendering;

  final DateTime? createdAt;

  /// Who wrote this exercise — `'book'` | `'manual'` | `'mistakes'`. Only a
  /// scan carries one on the wire; every other kind reads the default, which
  /// is never asked (`docs/PLAN-EXERCISE.md`, phase 4, `exerciseOriginOf`
  /// reads only what an exercise actually is).
  final String origin;

  /// What the student is asked to do, as `GET /library/positions` sends it —
  /// `{type:'find'}` or the game task shape, with its own `fen`. Null on
  /// every row written before tasks existed, which `exerciseAskOf` reads as
  /// „find".
  final Map<String, dynamic>? task;

  /// An exercise is a position **plus something to judge an answer by**
  /// (decision 1 of `docs/PLAN-EXERCISE.md`): a scan that carries a solution,
  /// or one whose task is a game, which its ending judges. A scan whose book
  /// printed no answer is a position that happens to come from a book — it
  /// gets its meaning by being put in an exercise.
  ///
  /// Until phase 10 this was `kind == scan`, and with `exerciseAskOf` reading
  /// a task-less row as „find" every scanned diagram stood on the Exercises
  /// shelf and in the homework picker, where the server then refused it (the
  /// owner's live pass of 19.9.2026). One home: the chips, the picker, the
  /// row's subtitle and the preview all ask this.
  bool get isExercise =>
      kind == LibraryKind.scan && (hasSolution || task?['type'] == 'game');

  factory LibraryEntry.fromJson(Map<String, dynamic> json) => LibraryEntry(
        kind: libraryKindFrom(json['kind']?.toString()) ?? LibraryKind.position,
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Untitled',
        fen: json['fen']?.toString() ?? '',
        instruction: _text(json['instruction']),
        pgn: _text(json['pgn']),
        solutionSan: _text(json['solutionSan']),
        themes: (json['themes'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        hasSolution: json['hasSolution'] == true,
        needsReview: json['needsReview'] == true,
        assignable: json['assignable'] == true,
        blockedReason: _text(json['blockedReason']),
        fromTrainer: json['fromTrainer'] == true,
        sourceTitle: _text(json['sourceTitle']),
        sourcePage: (json['sourcePage'] as num?)?.toInt(),
        sourceLabel: _text(json['sourceLabel']),
        partsCount: (json['partsCount'] as num?)?.toInt(),
        hasVideo: json['hasVideo'] == true,
        rendering: json['rendering'] == true,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
        origin: _text(json['origin']) ?? 'book',
        task: (json['task'] as Map?)?.cast<String, dynamic>(),
      );

  static String? _text(dynamic value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  /// A short line under the title: where it came from, in the trainer's terms.
  String get subtitle {
    if (kind == LibraryKind.scan) {
      final page = sourcePage == null ? null : 'p. $sourcePage';
      return [sourceTitle, page].whereType<String>().join(' · ');
    }
    return libraryKindLabel(kind);
  }
}

/// One course a position can be appended to.
class CourseSummary {
  const CourseSummary({
    required this.id,
    required this.title,
    required this.stepCount,
  });

  final int id;
  final String title;
  final int stepCount;
}
