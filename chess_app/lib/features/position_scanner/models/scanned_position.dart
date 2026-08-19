/// One position the scanner read out of a page, before anyone has agreed it is
/// right.
///
/// Everything the parser was unsure about travels with the position instead of
/// being dropped: [problem] says the printed solution would not play, and
/// [sideSource] says how confidently we know whose move it is. The screen exists
/// to put both in front of a person, so neither may be quietly discarded here.
class ScannedPosition {
  ScannedPosition({
    required this.fen,
    required this.page,
    this.label,
    this.sideSource = 'nepoznato',
    this.solutionSan,
    this.solutionLegal,
    this.themesText,
    this.repairs = const [],
    this.problem,
    bool? accepted,
  }) : accepted = accepted ?? true;

  /// Full FEN, including the side to move — editing the side rewrites this.
  String fen;

  final int page;
  final String? label;

  /// How the side to move was decided: `resenje`, `jedina legalna strana`, or
  /// `nepoznato`. Shown to the trainer, because "we guessed" and "the book said
  /// so" deserve different amounts of trust.
  final String sideSource;

  final String? solutionSan;
  final bool? solutionLegal;
  final String? themesText;
  final List<String> repairs;

  /// Set when the parser could not reconcile the position with the book.
  final String? problem;

  /// Whether the trainer wants this one saved. Everything starts accepted:
  /// discarding is a decision, and so is keeping, but only one of them can be
  /// the default without hiding work.
  bool accepted;

  bool get needsReview => problem != null || sideSource == 'nepoznato';

  String get sideToMove => fen.split(' ').length > 1 ? fen.split(' ')[1] : 'w';

  /// Flips whose move it is. The commonest correction on this screen by far,
  /// since a diagram does not print it and many books never say.
  void flipSide() {
    final parts = fen.split(' ');
    if (parts.length < 2) return;
    parts[1] = parts[1] == 'w' ? 'b' : 'w';
    // A stale en passant square belongs to the other side's last move and makes
    // the position illegal once the mover changes.
    if (parts.length > 3) parts[3] = '-';
    fen = parts.join(' ');
  }

  factory ScannedPosition.fromJson(Map<String, dynamic> json) =>
      ScannedPosition(
        fen: json['fen']?.toString() ?? '',
        page: (json['page'] as num?)?.toInt() ?? 0,
        label: json['label']?.toString(),
        sideSource: json['sideSource']?.toString() ?? 'nepoznato',
        solutionSan: json['solutionSan']?.toString(),
        solutionLegal: json['solutionLegal'] as bool?,
        themesText: json['themesText']?.toString(),
        repairs:
            (json['repairs'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        problem: json['problem']?.toString(),
      );

  Map<String, dynamic> toConfirmJson() => {
        'fen': fen,
        'page': page,
        if (label != null) 'label': label,
        if (solutionSan != null && solutionLegal == true)
          'solutionSan': solutionSan,
        'themes': _themes(),
        'needsReview': needsReview,
      };

  /// The book's own words for the motif, split into tags. `pin/undermine`
  /// becomes two; `interference/skewer` likewise. Left as the book wrote them
  /// rather than mapped onto Lichess names — that translation needs a decision
  /// per book, and a wrong tag is worse than the author's own word.
  List<String> _themes() {
    final text = themesText?.trim();
    if (text == null || text.isEmpty) return const [];
    return text
        .split(RegExp(r'[/,\s]+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && t.length <= 40)
        .take(12)
        .toList();
  }
}

/// A position that has been confirmed and stored — the other end of the scan.
///
/// Grouped by [sourceTitle] in the UI, because a trainer thinks in books, not
/// in rows: "the twenty pages of mates I pulled out of that book last week".
class SavedPosition {
  SavedPosition({
    required this.puzzleId,
    required this.fen,
    required this.sideToMove,
    this.solutionSan,
    this.instruction,
    this.themes = const [],
    this.sourceTitle,
    this.sourcePage,
    this.sourceLabel,
    bool needsReview = false,
  }) : needsReviewFlag = needsReview;

  final String puzzleId;

  /// Mutable because settling the side to move rewrites it in place — the
  /// server returns the corrected FEN and the card must show it at once.
  String fen;
  String sideToMove;
  bool needsReviewFlag;
  final String? solutionSan;

  /// What the student is asked to do. A board with no task is not an exercise —
  /// a child sent this position used to see pieces and nothing else.
  String? instruction;

  final List<String> themes;
  final String? sourceTitle;
  final int? sourcePage;
  final String? sourceLabel;

  bool get needsReview => needsReviewFlag;

  /// Records the trainer's answer locally after the server has stored it.
  void settleSide(String side, String newFen) {
    sideToMove = side;
    fen = newFen;
    needsReviewFlag = false;
  }

  factory SavedPosition.fromJson(Map<String, dynamic> json) => SavedPosition(
        puzzleId: json['puzzle_id']?.toString() ?? '',
        fen: json['fen']?.toString() ?? '',
        sideToMove: json['side_to_move']?.toString() ?? 'w',
        solutionSan: json['solution_san']?.toString(),
        instruction: json['instruction']?.toString(),
        themes: (json['themes'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        sourceTitle: json['source_title']?.toString(),
        sourcePage: (json['source_page'] as num?)?.toInt(),
        sourceLabel: json['source_label']?.toString(),
        needsReview: json['needs_review'] == true,
      );
}

/// What one scan produced.
class ScanResult {
  ScanResult({
    required this.documentName,
    required this.pageCount,
    required this.scannedFrom,
    required this.scannedTo,
    required this.font,
    required this.positions,
  });

  final String documentName;
  final int pageCount;
  final int scannedFrom;
  final int scannedTo;
  final String font;
  final List<ScannedPosition> positions;

  int get needingReview => positions.where((p) => p.needsReview).length;

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        documentName: json['documentName']?.toString() ?? 'dokument',
        pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
        scannedFrom: (json['scannedFrom'] as num?)?.toInt() ?? 0,
        scannedTo: (json['scannedTo'] as num?)?.toInt() ?? 0,
        font: json['font']?.toString() ?? '',
        positions: (json['positions'] as List? ?? [])
            .map((e) => ScannedPosition.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
