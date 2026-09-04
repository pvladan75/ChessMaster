import 'package:flutter/services.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';

class PgnExporterService {
  /// Converts an AnalysisNode tree into standard PGN text format.
  static String exportToPgn(
    AnalysisNode rootNode, {
    Map<String, String>? customHeaders,
  }) {
    final buffer = StringBuffer();

    // Default Headers
    final now = DateTime.now();
    final dateStr =
        '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';

    final headers = {
      'Event': 'Analysis Studio Session',
      // Bez dijakritike namerno: PGN izvozni format je po standardu ASCII/Latin-1,
      // a „Š" nije u Latin-1 — stroži čitači bi ga prikazali kao smeće.
      'Site': 'Sahovski trener',
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
      ...?customHeaders,
    };

    headers.forEach((key, val) {
      buffer.writeln('[$key "$val"]');
    });
    buffer.writeln();

    // Format tree recursively
    final isWhiteToMove = rootNode.fen.contains(' w ');
    final startMoveNum = _extractMoveNumberFromFen(rootNode.fen);

    _formatNodeChildren(
      buffer,
      rootNode,
      startMoveNum,
      isWhiteToMove,
    );

    buffer.write(' *');
    return buffer.toString().trim();
  }

  static void _formatNodeChildren(
    StringBuffer buffer,
    AnalysisNode parent,
    int moveNum,
    bool isWhiteTurn,
  ) {
    if (parent.children.isEmpty) return;

    // Main line child (index 0)
    final mainChild = parent.children.first;
    _writeMoveToken(buffer, mainChild, moveNum, isWhiteTurn);

    // Variations (index 1 to N)
    if (parent.children.length > 1) {
      for (int i = 1; i < parent.children.length; i++) {
        final varChild = parent.children[i];
        buffer.write(' (');
        _writeMoveToken(buffer, varChild, moveNum, isWhiteTurn,
            isVariationStart: true);
        _formatNodeChildren(
          buffer,
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
      mainChild,
      nextMoveNum,
      !isWhiteTurn,
    );
  }

  static void _writeMoveToken(
    StringBuffer buffer,
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

    buffer.write(node.moveSan ?? '');

    if (node.nag != null && node.nag!.isNotEmpty) {
      buffer.write(node.nag);
    }

    final commentParts = <String>[];
    // No `[%eval …]` any more. A node stopped carrying the engine's number on
    // 4.9.2026, and an export writes what the tree holds — the reader's own
    // comment, and the NAG above.
    if (node.comment.isNotEmpty) {
      commentParts.add(node.comment);
    }

    if (commentParts.isNotEmpty) {
      buffer.write(' { ${commentParts.join(" ")} }');
    }
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
