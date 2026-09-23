import 'dart:convert';
import 'dart:typed_data';

import 'scanned_position.dart';

/// The image path of the position scanner — phase 3 of
/// `docs/PLAN-SKENER-SLIKE.md`. A book whose diagrams are pictures is read
/// against a calibration: the positions of a few of its own boards, given by
/// the trainer. These are the shapes `POST /scans/images` and
/// `/scans/calibrations/:hash` speak.

/// A board of the book, named the way the server names it: its page and its
/// place on that page, from 1, in reading order. The same file gives the same
/// names on every upload, which is what lets a calibration be remembered.
class BoardRef {
  const BoardRef(this.page, this.index);

  final int page;
  final int index;

  factory BoardRef.fromJson(Map<String, dynamic> json) =>
      BoardRef((json['page'] as num).toInt(), (json['index'] as num).toInt());

  @override
  bool operator ==(Object other) =>
      other is BoardRef && other.page == page && other.index == index;

  @override
  int get hashCode => Object.hash(page, index);

  @override
  String toString() => 'p. $page · $index';
}

/// One calibration board: where it is, and the position the trainer set up.
/// `placement` is the board part of a FEN only — whose move it is plays no
/// part in how a book draws its pieces. `ignore` names squares with a
/// teaching mark on them (a cross, a dashed line).
class CalibrationBoard {
  const CalibrationBoard({
    required this.ref,
    required this.placement,
    this.ignore = const [],
  });

  final BoardRef ref;
  final String placement;
  final List<String> ignore;

  factory CalibrationBoard.fromJson(Map<String, dynamic> json) =>
      CalibrationBoard(
        ref: BoardRef.fromJson(json),
        placement: json['fen'].toString().split(' ').first,
        ignore: (json['ignore'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'page': ref.page,
        'index': ref.index,
        'fen': placement,
        if (ignore.isNotEmpty) 'ignore': ignore,
      };
}

/// A board as the server found it, before anything was read: its picture.
class FoundBoard {
  const FoundBoard({required this.ref, required this.preview});

  final BoardRef ref;

  /// The board's picture from the book, 256 px (a JPEG since phase 3e: a
  /// whole book is browsed through these).
  final Uint8List preview;

  factory FoundBoard.fromJson(Map<String, dynamic> json) => FoundBoard(
        ref: BoardRef.fromJson(json),
        preview: base64Decode(json['preview'].toString()),
      );
}

/// One board read against a calibration, before the trainer has agreed.
///
/// Everything the reader was unsure of travels with it: [uncertain] names the
/// squares to look at, [legal] says whether the placement is a position at
/// all. The side to move is never read — a diagram does not print it — so it
/// starts as White and [sideTouched] records whether anyone said otherwise.
class ReadBoard {
  ReadBoard({
    required this.ref,
    required this.placement,
    required this.uncertain,
    required this.legal,
    required this.preview,
    bool? accepted,
  }) : accepted = accepted ?? legal;

  final BoardRef ref;
  String placement;
  List<String> uncertain;
  bool legal;
  final Uint8List preview;

  /// Whether the trainer wants it saved. A board that is not a position cannot
  /// be saved, so it starts unselected.
  bool accepted;
  String sideToMove = 'w';
  bool sideTouched = false;

  /// Set up in the editor by the trainer, every square looked at — the only
  /// boards trusted to join a calibration ([calibrationGrownBy]).
  bool fixedByHand = false;

  String get fen => '$placement $sideToMove - - 0 1';

  void flipSide() {
    sideToMove = sideToMove == 'w' ? 'b' : 'w';
    sideTouched = true;
  }

  /// The board as the save path takes it. The side to move counts as
  /// unknown — so the row is flagged `needsReview` — until the trainer has
  /// touched it, exactly as the font path treats a side the book did not give.
  ScannedPosition toScannedPosition() => ScannedPosition(
        fen: fen,
        page: ref.page,
        sideSource: sideTouched ? 'trainer' : 'unknown',
      );

  factory ReadBoard.fromJson(Map<String, dynamic> json) => ReadBoard(
        ref: BoardRef.fromJson(json),
        placement: json['placement'].toString(),
        uncertain:
            (json['uncertain'] as List?)?.map((e) => e.toString()).toList() ??
                [],
        legal: json['legal'] == true,
        preview: base64Decode(json['preview'].toString()),
      );
}

/// What `POST /scans/images` answered.
class ImageScanResult {
  const ImageScanResult({
    required this.needsCalibration,
    required this.scannedFrom,
    required this.scannedTo,
    this.pageCount = 0,
    this.boards = const [],
    this.positions = const [],
    this.composed = const [],
    this.unseen = const [],
  });

  /// True when no calibration was sent: [boards] is filled — the book's
  /// boards on those pages, which is how the trainer browses it — and
  /// [positions] is empty.
  final bool needsCalibration;
  final int scannedFrom;
  final int scannedTo;

  /// Pages in the whole book.
  final int pageCount;
  final List<FoundBoard> boards;
  final List<ReadBoard> positions;

  /// Classes no calibration board showed, guessed from the same piece on the
  /// other colour — `R/light` and the like. Worth one more calibration board.
  final List<String> composed;

  /// Pieces no calibration board showed on either colour — `q` and the like.
  /// They are not read at all: a square holding one comes out as something
  /// else, marked only when it looks like nothing known.
  final List<String> unseen;

  factory ImageScanResult.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) =>
        ((json[key] as List?) ?? const [])
            .map((e) => e as Map<String, dynamic>)
            .toList();
    return ImageScanResult(
      needsCalibration: json['needsCalibration'] == true,
      scannedFrom: (json['scannedFrom'] as num?)?.toInt() ?? 0,
      scannedTo: (json['scannedTo'] as num?)?.toInt() ?? 0,
      pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
      boards: list('boards').map(FoundBoard.fromJson).toList(),
      // The boards the trainer set up are positions from the book too, and
      // were confirmed by being set up: they are offered for saving with the
      // rest, in the book's order.
      positions: [
        ...list('positions'),
        ...list('calibration'),
      ].map(ReadBoard.fromJson).toList()
        ..sort((a, b) => a.ref.page != b.ref.page
            ? a.ref.page - b.ref.page
            : a.ref.index - b.ref.index),
      composed:
          (json['composed'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      unseen: (json['unseen'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }
}

/// The twelve pieces, in the order the coverage table lists them.
const pieceLetters = 'PNBRQKpnbrqk';

const _pieceNames = {
  'P': 'white pawn',
  'N': 'white knight',
  'B': 'white bishop',
  'R': 'white rook',
  'Q': 'white queen',
  'K': 'white king',
  'p': 'black pawn',
  'n': 'black knight',
  'b': 'black bishop',
  'r': 'black rook',
  'q': 'black queen',
  'k': 'black king',
};

/// `q` → „black queen".
String pieceName(String letter) => _pieceNames[letter] ?? letter;

/// `R/light` → „a white rook on a light square".
String classWords(String pieceClass) {
  final parts = pieceClass.split('/');
  return 'a ${pieceName(parts.first)} on a ${parts.last} square';
}

/// What the reader knows of one piece on one colour of square.
enum ClassState {
  /// A calibration board shows it: it is read.
  seen,

  /// Only the other colour is shown: it is composed from that, and every
  /// square read as it is marked.
  guessed,

  /// Neither colour is shown: it is not read at all.
  unknown,
}

/// What a set of calibration boards teaches the reader — phase 3e of
/// `docs/PLAN-SKENER-SLIKE.md`. The reader compares a square only with
/// examples on its own colour and never by where it stands, so what a
/// calibration needs is 24 classes: 12 pieces on a light and a dark square.
/// Worked out from the placements alone, so the table on the screen follows
/// every board the moment it is set up.
class CalibrationCoverage {
  CalibrationCoverage._(this.counts, this.absent);

  /// [absent] names pieces the trainer says the book never draws: they are
  /// not asked for.
  factory CalibrationCoverage.of(Iterable<String> placements,
      {Set<String> absent = const {}}) {
    final counts = <String, int>{};
    for (final placement in placements) {
      for (final c in pieceClassesOf(placement)) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }
    return CalibrationCoverage._(counts, absent);
  }

  /// Boards showing each class, `R/light` → 2.
  final Map<String, int> counts;
  final Set<String> absent;

  ClassState stateOf(String piece, {required bool dark}) {
    final want = '$piece/${dark ? 'dark' : 'light'}';
    final other = '$piece/${dark ? 'light' : 'dark'}';
    if ((counts[want] ?? 0) > 0) return ClassState.seen;
    if ((counts[other] ?? 0) > 0) return ClassState.guessed;
    return ClassState.unknown;
  }

  /// Pieces on neither colour, leaving out the ones said to be absent.
  List<String> get unknownPieces => [
        for (final p in pieceLetters.split(''))
          if (!absent.contains(p) &&
              stateOf(p, dark: false) == ClassState.unknown)
            p
      ];

  /// Classes composed from the other colour: `R/light` and the like.
  List<String> get guessedClasses => [
        for (final p in pieceLetters.split(''))
          for (final dark in const [false, true])
            if (stateOf(p, dark: dark) == ClassState.guessed)
              '$p/${dark ? 'dark' : 'light'}'
      ];

  /// Reading may start once no piece is unknown: an unknown piece is read as
  /// something else, and a guessed class is at least marked.
  bool get ready => unknownPieces.isEmpty;

  /// What is still needed, most needed first: unknown pieces, then guessed
  /// classes. Empty when everything is shown.
  String get stillNeeded {
    final parts = [
      for (final p in unknownPieces) 'a ${pieceName(p)}, on any square',
      for (final c in guessedClasses) classWords(c),
    ];
    return parts.join('; ');
  }
}

/// The classes [placement] shows that none of [others] does — what a board
/// adds to the rest of a calibration.
Set<String> classesAddedBy(String placement, Iterable<String> others) {
  final rest = <String>{for (final o in others) ...pieceClassesOf(o)};
  return pieceClassesOf(placement).difference(rest);
}

/// The piece classes a placement shows, as the reader names them:
/// `R/dark` for a white rook on a dark square. a8 is light.
Set<String> pieceClassesOf(String placement) {
  final classes = <String>{};
  final ranks = placement.split('/');
  for (var row = 0; row < ranks.length && row < 8; row++) {
    var file = 0;
    for (final ch in ranks[row].split('')) {
      final empty = int.tryParse(ch);
      if (empty != null) {
        file += empty;
        continue;
      }
      classes.add('$ch/${(file + row) % 2 == 1 ? 'dark' : 'light'}');
      file++;
    }
  }
  return classes;
}

/// The most boards a calibration may hold — the server's `MAX_CALIBRATION`.
const maxCalibrationBoards = 8;

/// What saving did to a book's calibration: the whole new list, and which
/// boards joined and left. [added] empty means nothing changed.
class CalibrationGrowth {
  const CalibrationGrowth(this.boards, this.added, this.removed);
  final List<CalibrationBoard> boards;
  final List<CalibrationBoard> added;
  final List<CalibrationBoard> removed;
}

/// A book's calibration grown by what was just saved — the owner's questions
/// of 23.9.2026: „zar ne mogu pozicije koje sam ispravio da služe kao
/// kalibracija?", and then „da bude dinamička": pages 1–20 have no white
/// queen on a light square, page 31 does, and confirming it teaches the book.
///
/// A calibration is the ground truth every later reading of the book stands
/// on, so only a board the trainer **set up in the editor** is taken — every
/// square looked at, as in the calibration itself; one ticked as it was read
/// could carry the very mistake it would then teach. And only for what the
/// calibration lacks: a board joins when it shows a class the reader had to
/// guess (`composed`), the board covering the most first, until nothing is
/// guessed.
///
/// When the calibration is full, a board that joins takes the place of one
/// that is **redundant** — every class it shows is shown by another board
/// that stays — so no class the reader already has is ever lost for one it
/// lacks. The one with the fewest pieces goes, being the least evidence. With
/// no redundant board the new one waits: nothing is evicted blind.
CalibrationGrowth calibrationGrownBy({
  required List<CalibrationBoard> current,
  required Iterable<ReadBoard> saved,
  required List<String> composed,
  int max = maxCalibrationBoards,
}) {
  final missing = composed.toSet();
  final boards = [...current];
  final taken = {for (final c in current) c.ref};
  final candidates = [
    for (final b in saved)
      if (b.fixedByHand && b.accepted && b.legal && !taken.contains(b.ref)) b
  ];
  final added = <CalibrationBoard>[];
  final removed = <CalibrationBoard>[];

  /// A board whose every class another board in [pool] also shows.
  CalibrationBoard? redundantIn(List<CalibrationBoard> pool) {
    CalibrationBoard? pick;
    var pickPieces = 1 << 30;
    for (final b in pool) {
      final others = <String>{
        for (final o in pool)
          if (!identical(o, b)) ...pieceClassesOf(o.placement)
      };
      final mine = pieceClassesOf(b.placement);
      if (!others.containsAll(mine)) continue;
      if (mine.isEmpty) return b;
      final pieces = b.placement.replaceAll(RegExp(r'[0-9/]'), '').length;
      if (pieces < pickPieces) {
        pick = b;
        pickPieces = pieces;
      }
    }
    return pick;
  }

  while (missing.isNotEmpty && candidates.isNotEmpty) {
    ReadBoard? best;
    var bestCount = 0;
    for (final b in candidates) {
      final count = pieceClassesOf(b.placement).intersection(missing).length;
      if (count > bestCount) {
        best = b;
        bestCount = count;
      }
    }
    if (best == null) break;
    candidates.remove(best);
    final joining = CalibrationBoard(ref: best.ref, placement: best.placement);
    if (boards.length >= max) {
      // Judged with the newcomer in: what it shows counts as covered.
      final out = redundantIn([...boards, joining]);
      if (out == null || identical(out, joining)) continue;
      boards.remove(out);
      if (!added.remove(out)) removed.add(out);
    }
    boards.add(joining);
    added.add(joining);
    missing.removeAll(pieceClassesOf(best.placement));
  }
  return CalibrationGrowth(boards, added, removed);
}
