import 'package:chess/chess.dart' as chess;

class EngineMove {
  final String display;
  final String from;
  final String to;
  final String san;

  EngineMove({
    required this.display,
    required this.from,
    required this.to,
    required this.san,
  });
}

class AnalysisLine {
  final int multipv;
  final int depth;
  final String
      evaluation; // Evaluacija fiksirana iz ugla Belog (+ za belog, - za crnog)
  final String bestMoveLan; // e.g. e2e4
  final String bestMoveSan; // e.g. e4 ili Qe2
  final String continuationLan;
  final String continuationSan; // 1. e4 e5 2. Nf3
  final List<String> sanMoveList; // ['e4', 'e5', 'Nf3']
  final List<String> fenList; // FEN state after each move in continuation line
  final String fromSquare;
  final String toSquare;

  String get startingFen => fenList.isNotEmpty ? fenList.first : '';

  AnalysisLine({
    required this.multipv,
    this.depth = 0,
    required this.evaluation,
    required this.bestMoveLan,
    required this.bestMoveSan,
    required this.continuationLan,
    required this.continuationSan,
    required this.sanMoveList,
    required this.fenList,
    required this.fromSquare,
    required this.toSquare,
  });

  static AnalysisLine fromPv({
    required int multipv,
    int depth = 0,
    required String eval,
    required String pvString,
    required String startingFen,
  }) {
    final tokens = pvString
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return AnalysisLine(
        multipv: multipv,
        depth: depth,
        evaluation: eval,
        bestMoveLan: '',
        bestMoveSan: '',
        continuationLan: '',
        continuationSan: '',
        sanMoveList: [],
        fenList: [startingFen],
        fromSquare: '',
        toSquare: '',
      );
    }

    final bestMoveLan = tokens.first;
    String fromSq = bestMoveLan.length >= 2 ? bestMoveLan.substring(0, 2) : '';
    String toSq = bestMoveLan.length >= 4 ? bestMoveLan.substring(2, 4) : '';

    final List<String> sanMoveList = [];
    final List<String> fenList = [startingFen];
    final List<String> numberedSanTokens = [];

    try {
      final game = chess.Chess.fromFEN(startingFen);
      final isWhiteToMoveAtStart = game.turn == chess.Color.WHITE;

      for (int i = 0; i < tokens.length; i++) {
        final tok = tokens[i];
        if (tok.length < 4) break;
        final from = tok.substring(0, 2);
        final to = tok.substring(2, 4);
        final promo = tok.length > 4 ? tok[4] : null;

        // Save current turn & move number before making move
        final turnBeforeMove = game.turn;
        final fenBefore = game.fen;
        final parts = fenBefore.split(' ');
        final moveNum =
            int.tryParse(parts.length > 5 ? parts[5] : '1') ?? (i ~/ 2 + 1);

        final moveMap = {'from': from, 'to': to, 'promotion': promo};
        final ok = game.move(moveMap);
        if (!ok) break;

        final moveObj = game.history.last.move;
        game.undo_move();
        final san = game.move_to_san(moveObj);
        game.move(moveMap);

        sanMoveList.add(san);
        fenList.add(game.fen);

        if (turnBeforeMove == chess.Color.WHITE) {
          numberedSanTokens.add('$moveNum. $san');
        } else {
          if (i == 0 && !isWhiteToMoveAtStart) {
            numberedSanTokens.add('$moveNum... $san');
          } else {
            numberedSanTokens.add(san);
          }
        }
      }
    } catch (_) {
      // Fallback if parsing fails
    }

    final bestMoveSan =
        sanMoveList.isNotEmpty ? sanMoveList.first : bestMoveLan;
    final continuationSan =
        numberedSanTokens.isNotEmpty ? numberedSanTokens.join(' ') : pvString;

    return AnalysisLine(
      multipv: multipv,
      depth: depth,
      evaluation: eval,
      bestMoveLan: bestMoveLan,
      bestMoveSan: bestMoveSan,
      continuationLan: pvString,
      continuationSan: continuationSan,
      sanMoveList: sanMoveList,
      fenList: fenList,
      fromSquare: fromSq,
      toSquare: toSq,
    );
  }
}
