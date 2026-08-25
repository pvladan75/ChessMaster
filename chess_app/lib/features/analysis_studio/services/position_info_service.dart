class PositionPhaseInfo {
  final int pieceCount;
  final bool isEndgame;
  final bool isSyzygyReady;
  final String openingName;

  PositionPhaseInfo({
    required this.pieceCount,
    required this.isEndgame,
    required this.isSyzygyReady,
    required this.openingName,
  });
}

class PositionInfoService {
  static final Map<String, String> _knownOpeningsByFenPrefix = {
    'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR':
        '1. e4 (King\'s Pawn Opening)',
    'rnbqkbnr/pppp1ppp/4p3/8/4P3/8/PPPP1PPP/RNBQKBNR':
        'Francuska Odbrana (French Defense)',
    'rnbqkbnr/pp1ppppp/2p5/8/4P3/8/PPPP1PPP/RNBQKBNR':
        'Karo-Kan (Caro-Kann Defense)',
    'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR':
        '1. d4 (Queen\'s Pawn Opening)',
    'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR': '1. e4 e5 (Open Game)',
    'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R':
        'Sicilijanska ili Kraljev Skakač',
    'r1bqkbnr/pppp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R':
        'Španska Partija (Ruy Lopez)',
    'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R':
        'Italijanska Partija (Italian Game)',
    'rnbqkbnr/ppppp1pp/8/5p2/4P3/8/PPPP1PPP/RNBQKBNR': 'Holandska / Danac',
    'rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR':
        'Skandinavska Odbrana (Scandinavian)',
    'rnbqkb1r/pppppppp/5n2/8/3P4/8/PPP1PPPP/RNBQKBNR':
        'Indijska Odbrana (Indian Defense)',
    'rnbqkbnr/ppp1pppp/8/3p4/2PP4/8/PP2PPPP/RNBQKBNR':
        'Damin Gambit (Queen\'s Gambit)',
  };

  /// Analyzes FEN and returns piece count, phase, Syzygy readiness, and opening name.
  static PositionPhaseInfo analyzeFen(String fen) {
    final boardFen = fen.trim().split(' ')[0];
    int count = 0;
    for (int i = 0; i < boardFen.length; i++) {
      final char = boardFen[i];
      if (RegExp(r'[rnbqkpRNBQKP]').hasMatch(char)) {
        count++;
      }
    }

    final isEndgame = count <= 7;
    final isSyzygyReady = isEndgame;

    String opening = 'Središnjica / Nepoznato Otvaranje';
    for (var entry in _knownOpeningsByFenPrefix.entries) {
      if (boardFen.startsWith(entry.key)) {
        opening = entry.value;
        break;
      }
    }

    if (isEndgame) {
      opening = 'Završnica ($count figura - Syzygy Tablebase Podrška Spremna)';
    }

    return PositionPhaseInfo(
      pieceCount: count,
      isEndgame: isEndgame,
      isSyzygyReady: isSyzygyReady,
      openingName: opening,
    );
  }
}
