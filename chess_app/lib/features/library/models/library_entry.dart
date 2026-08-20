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
}

LibraryKind? libraryKindFrom(String? raw) => switch (raw) {
      'scan' => LibraryKind.scan,
      'position' => LibraryKind.position,
      'analysis' => LibraryKind.analysis,
      _ => null,
    };

String libraryKindWire(LibraryKind kind) => switch (kind) {
      LibraryKind.scan => 'scan',
      LibraryKind.position => 'position',
      LibraryKind.analysis => 'analysis',
    };

String libraryKindLabel(LibraryKind kind) => switch (kind) {
      LibraryKind.scan => 'iz knjige',
      LibraryKind.position => 'sačuvane pozicije',
      LibraryKind.analysis => 'analize',
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

  factory LibraryEntry.fromJson(Map<String, dynamic> json) => LibraryEntry(
        kind: libraryKindFrom(json['kind']?.toString()) ?? LibraryKind.position,
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Bez naziva',
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
      );

  static String? _text(dynamic value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  /// A short line under the title: where it came from, in the trainer's terms.
  String get subtitle {
    if (kind == LibraryKind.scan) {
      final page = sourcePage == null ? null : 'str. $sourcePage';
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
