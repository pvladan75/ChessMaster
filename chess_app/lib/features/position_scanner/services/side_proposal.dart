import 'package:chess/chess.dart' as chess;

/// How much the engine's answer is worth believing.
enum ProposalConfidence {
  /// One side mates and the other does not. In a puzzle collection this is as
  /// close to certain as an engine gets.
  high,

  /// One side is decisively better. Strong, but a book position can be a
  /// defensive task where the side to move is the one *worse* off.
  medium,

  /// Both sides have something, or neither does. Nothing useful to say.
  none,
}

/// What the engine thinks about whose move it is — a proposal, never a verdict.
///
/// The whole point of the scanner's confirmation flow is that a machine must not
/// answer a question nobody asked. This class exists so the engine's opinion can
/// be shown *beside* the position rather than written into it: the trainer still
/// decides, and where the engine disagrees with a side already settled, the
/// disagreement is the thing worth showing.
class SideProposal {
  const SideProposal({
    required this.side,
    required this.confidence,
    required this.reason,
    required this.whiteEval,
    required this.blackEval,
  });

  /// `'w'`, `'b'`, or null when the engine has nothing to offer.
  final String? side;
  final ProposalConfidence confidence;

  /// A sentence a person can read, in the app's language.
  final String reason;

  /// The evaluations as the engine gave them, both from White's perspective.
  final String whiteEval;
  final String blackEval;

  bool get hasAnswer => side != null && confidence != ProposalConfidence.none;

  /// True when the engine's answer contradicts a side that is already recorded.
  bool disagreesWith(String storedSide) => hasAnswer && side != storedSide;

  static const SideProposal empty = SideProposal(
    side: null,
    confidence: ProposalConfidence.none,
    reason: 'motor nema mišljenje',
    whiteEval: '',
    blackEval: '',
  );
}

/// Engine eval string to a number, from White's perspective.
///
/// Mate is worth more than any material score and a faster mate more than a
/// slower one, so `M1` outranks `M5` outranks `+9.00`. Returns null for
/// anything unparseable rather than guessing a zero, because "the engine said
/// level" and "we could not read the engine" must not look the same.
double? parseEval(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  final mate = RegExp(r'^([+-]?)M(\d+)$').firstMatch(text);
  if (mate != null) {
    final moves = int.parse(mate.group(2)!);
    final magnitude = 1000.0 - moves;
    return mate.group(1) == '-' ? -magnitude : magnitude;
  }

  return double.tryParse(text.replaceAll('+', ''));
}

/// Is this board even playable with that side to move?
///
/// A position where the side *not* to move stands in check cannot arise in a
/// game, so it answers the question on its own and costs no engine time.
bool isPlayableWith(String fen, String side) {
  try {
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.length < 4) return false;
    parts[1] = side;
    parts[3] = '-';
    final board = chess.Chess.fromFEN(parts.join(' '));
    return board.generate_moves().isNotEmpty || board.in_checkmate;
  } catch (_) {
    return false;
  }
}

/// Decide from two evaluations of the same board, one per side to move.
///
/// Both come in from White's perspective, so the mover's own advantage is the
/// score for white and its negation for black. In a book the side to move is
/// the one with something to play — that is what a puzzle *is* — so the side
/// whose move buys it far more is the proposal.
SideProposal decideSide({
  required String whiteEval,
  required String blackEval,
  double decisiveGap = 3.0,
}) {
  final white = parseEval(whiteEval);
  final black = parseEval(blackEval);
  if (white == null || black == null) {
    return SideProposal(
      side: null,
      confidence: ProposalConfidence.none,
      reason: 'motor nije dao ocenu za obe strane',
      whiteEval: whiteEval,
      blackEval: blackEval,
    );
  }

  final whiteMoverGain = white; // white to move, white's own score
  final blackMoverGain = -black; // black to move, from black's side

  final whiteMates = whiteEval.contains('M') && !whiteEval.startsWith('-');
  final blackMates = blackEval.contains('M') && blackEval.startsWith('-');

  if (whiteMates != blackMates) {
    final side = whiteMates ? 'w' : 'b';
    return SideProposal(
      side: side,
      confidence: ProposalConfidence.high,
      reason: side == 'w'
          ? 'beli matira ($whiteEval), crni nema mat'
          : 'crni matira ($blackEval), beli nema mat',
      whiteEval: whiteEval,
      blackEval: blackEval,
    );
  }

  final gap = (whiteMoverGain - blackMoverGain).abs();
  if (gap >= decisiveGap) {
    final side = whiteMoverGain > blackMoverGain ? 'w' : 'b';
    return SideProposal(
      side: side,
      confidence: ProposalConfidence.medium,
      reason: side == 'w'
          ? 'potez mnogo više vredi belom ($whiteEval naspram $blackEval)'
          : 'potez mnogo više vredi crnom ($blackEval naspram $whiteEval)',
      whiteEval: whiteEval,
      blackEval: blackEval,
    );
  }

  return SideProposal(
    side: null,
    confidence: ProposalConfidence.none,
    reason: 'obe strane imaju slično — motor ne razlikuje',
    whiteEval: whiteEval,
    blackEval: blackEval,
  );
}
