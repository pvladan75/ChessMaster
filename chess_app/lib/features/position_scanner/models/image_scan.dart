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

  /// The board's picture from the book, a 256 px PNG.
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
    this.boards = const [],
    this.suggested = const [],
    this.positions = const [],
    this.composed = const [],
  });

  /// True when no calibration was sent: [boards] and [suggested] are filled,
  /// [positions] is empty.
  final bool needsCalibration;
  final int scannedFrom;
  final int scannedTo;
  final List<FoundBoard> boards;
  final List<BoardRef> suggested;
  final List<ReadBoard> positions;

  /// Classes no calibration board showed, guessed from the same piece on the
  /// other colour — `R/light` and the like. Worth one more calibration board.
  final List<String> composed;

  factory ImageScanResult.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) =>
        ((json[key] as List?) ?? const [])
            .map((e) => e as Map<String, dynamic>)
            .toList();
    return ImageScanResult(
      needsCalibration: json['needsCalibration'] == true,
      scannedFrom: (json['scannedFrom'] as num?)?.toInt() ?? 0,
      scannedTo: (json['scannedTo'] as num?)?.toInt() ?? 0,
      boards: list('boards').map(FoundBoard.fromJson).toList(),
      suggested: list('suggested').map(BoardRef.fromJson).toList(),
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
    );
  }
}
