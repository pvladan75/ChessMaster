import 'package:flutter/services.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/models/pgn_span.dart';
import 'package:chess_app/move_tree.dart';

class PgnExporterService {
  /// Converts an AnalysisNode tree into standard PGN text format.
  static String exportToPgn(
    AnalysisNode rootNode, {
    Map<String, String>? customHeaders,
  }) =>
      exportWithSpans(rootNode, customHeaders: customHeaders).pgn;

  /// The same text, and where each node's move and comment sit in it.
  ///
  /// One writer for both, so the map can never describe a different string from
  /// the one it is handed out with.
  static PgnWithSpans exportWithSpans(
    AnalysisNode rootNode, {
    Map<String, String>? customHeaders,
  }) {
    final buffer = StringBuffer();
    final spans = <PgnSpan>[];

    // Default Headers
    final now = DateTime.now();
    final dateStr =
        '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';

    final headers = {
      'Event': 'Analysis Studio Session',
      // Bez dijakritike namerno: PGN izvozni format je po standardu ASCII/Latin-1,
      // a „Š" nije u Latin-1 — stroži čitači bi ga prikazali kao smeće.
      'Site': 'Chess trainer',
      'Date': dateStr,
      'Round': '1',
      'White': 'Player',
      'Black': 'Analysis Engine',
      'Result': '*',
      if (!rootNode.fen
          .startsWith('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR')) ...{
        'SetUp': '1',
        'FEN': rootNode.fen,
      },
      if (rootNode.timeControl != null) 'TimeControl': rootNode.timeControl!,
      ...?customHeaders,
    };

    headers.forEach((key, val) {
      buffer.writeln('[$key "$val"]');
    });
    buffer.writeln();

    // The note about the starting position goes ahead of move one. A step is
    // often nothing but a diagram and a sentence about it — „pogledaj polje
    // d5" — and until this line that sentence was the one thing an export
    // could not carry.
    final rootComment = _commentText(rootNode);
    if (rootComment != null) {
      final start = buffer.length;
      buffer.write(rootComment);
      spans.add(PgnSpan(
        nodeId: rootNode.id,
        kind: PgnSpanKind.comment,
        start: start,
        end: buffer.length,
      ));
      buffer.write(' ');
    }

    // Format tree recursively
    final isWhiteToMove = rootNode.fen.contains(' w ');
    final startMoveNum = _extractMoveNumberFromFen(rootNode.fen);

    _formatNodeChildren(
      buffer,
      spans,
      rootNode,
      startMoveNum,
      isWhiteToMove,
    );

    buffer.write(' *');

    // The offsets are into what the caller gets back, not into the buffer.
    // `trim()` takes whitespace off both ends, and while today's headers mean
    // there is never any at the front, a span that is right only because of
    // that is a span that goes wrong the day somebody writes a blank line
    // ahead of them.
    final raw = buffer.toString();
    final pgn = raw.trim();
    final lead = raw.length - raw.trimLeft().length;
    return PgnWithSpans(
      pgn: pgn,
      spans: lead == 0
          ? spans
          : [
              for (final span in spans)
                PgnSpan(
                  nodeId: span.nodeId,
                  kind: span.kind,
                  start: span.start - lead,
                  end: span.end - lead,
                ),
            ],
    );
  }

  static void _formatNodeChildren(
    StringBuffer buffer,
    List<PgnSpan> spans,
    AnalysisNode parent,
    int moveNum,
    bool isWhiteTurn,
  ) {
    if (parent.children.isEmpty) return;

    // Main line child (index 0)
    final mainChild = parent.children.first;
    _writeMoveToken(buffer, spans, mainChild, moveNum, isWhiteTurn);

    // Variations (index 1 to N)
    if (parent.children.length > 1) {
      for (int i = 1; i < parent.children.length; i++) {
        final varChild = parent.children[i];
        buffer.write(' (');
        _writeMoveToken(buffer, spans, varChild, moveNum, isWhiteTurn,
            isVariationStart: true);
        _formatNodeChildren(
          buffer,
          spans,
          varChild,
          isWhiteTurn ? moveNum : moveNum + 1,
          !isWhiteTurn,
        );
        buffer.write(')');
      }
    }

    // Continue down main line
    final nextMoveNum = isWhiteTurn ? moveNum : moveNum + 1;
    _formatNodeChildren(
      buffer,
      spans,
      mainChild,
      nextMoveNum,
      !isWhiteTurn,
    );
  }

  static void _writeMoveToken(
    StringBuffer buffer,
    List<PgnSpan> spans,
    AnalysisNode node,
    int moveNum,
    bool isWhiteTurn, {
    bool isVariationStart = false,
  }) {
    if (buffer.isNotEmpty && !buffer.toString().endsWith('(')) {
      buffer.write(' ');
    }

    if (isWhiteTurn) {
      buffer.write('$moveNum. ');
    } else if (isVariationStart) {
      buffer.write('$moveNum... ');
    }

    // The move number is left out of the span on purpose: „1." belongs to the
    // notation rather than to the node, and a caret in it is not a caret in a
    // move.
    final moveStart = buffer.length;
    buffer.write(node.moveSan ?? '');

    if (node.nag != null && node.nag!.isNotEmpty) {
      buffer.write(node.nag);
    }
    // The NAG is inside it, because „e4!" is one thing a trainer clicks on.
    spans.add(PgnSpan(
      nodeId: node.id,
      kind: PgnSpanKind.move,
      start: moveStart,
      end: buffer.length,
    ));

    final comment = _commentText(node);
    if (comment != null) {
      buffer.write(' ');
      final commentStart = buffer.length;
      buffer.write(comment);
      spans.add(PgnSpan(
        nodeId: node.id,
        kind: PgnSpanKind.comment,
        start: commentStart,
        end: buffer.length,
      ));
    }
  }

  /// One node's beats as successive `{ words [%cal …] [%csl …] }` groups, or
  /// null when it has nothing to say.
  ///
  /// One builder rather than one per call site: the root's note and a move's
  /// note must be written in the same dialect, since both are read back by the
  /// same parser. Mirrors `MoveTree._writeComment` exactly — the two are read
  /// back by the same parser and must agree on it.
  ///
  /// **An empty beat is not written**, and the clock — the node's, not any
  /// one beat's — is written once, in the last group written at all. A
  /// position with one beat is written exactly as it always was, because
  /// that is the single-group case.
  static String? _commentText(AnalysisNode node) {
    // No `[%eval …]` any more. A node stopped carrying the engine's number on
    // 4.9.2026, and an export writes what the tree holds — the reader's own
    // comment, the NAG above, and what they drew.
    final said = node.beats.where((b) => !b.isEmpty).toList();
    final clock = node.clockSeconds;
    if (said.isEmpty) {
      if (clock == null) return null;
      return '{ ${MoveTree.pgnClock(clock)} }';
    }
    final groups = <String>[];
    for (var i = 0; i < said.length; i++) {
      final beat = said[i];
      final parts = <String>[];
      if (beat.comment.isNotEmpty) parts.add(beat.comment);
      // The same two tags `MoveTree` writes, in the same order. A studio
      // export is read back by `MoveTree.parsePgn`, so if these two
      // disagreed about the dialect an arrow would survive one direction and
      // not the other.
      if (beat.arrows.isNotEmpty) {
        parts.add('[%cal ${beat.arrows.map((a) => a.toString()).join(',')}]');
      }
      if (beat.squares.isNotEmpty) {
        parts.add('[%csl ${beat.squares.map((s) => s.toString()).join(',')}]');
      }
      // The clock read in from an online game, written back in its own
      // command so the next read finds it
      // (docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, phase 3).
      if (i == said.length - 1 && clock != null) {
        parts.add(MoveTree.pgnClock(clock));
      }
      groups.add('{ ${parts.join(" ")} }');
    }
    return groups.join(' ');
  }

  static int _extractMoveNumberFromFen(String fen) {
    try {
      final parts = fen.trim().split(' ');
      if (parts.length >= 6) {
        return int.parse(parts[5]);
      }
    } catch (_) {}
    return 1;
  }

  /// Copies PGN to Clipboard
  static Future<void> copyToClipboard(String pgnText) async {
    await Clipboard.setData(ClipboardData(text: pgnText));
  }
}
