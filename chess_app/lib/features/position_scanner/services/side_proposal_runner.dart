import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/services/stockfish_service_native.dart';

import '../models/scanned_position.dart';
import 'side_proposal.dart';

/// Runs the engine over saved positions to propose whose move it is.
///
/// Sequential on purpose. The engine is a shared singleton that the analysis
/// board also uses, and `analyzePositionSync` is the entry point built to keep
/// one query's answer from being handed to another; firing several at once
/// would put that right back.
///
/// Every position costs two searches — the same board once with each side to
/// move — because the question is not "what is the best move" but "which side
/// has something to play", and that is exactly what a puzzle is.
class SideProposalRunner {
  SideProposalRunner({StockfishService? engine})
      : _engine = engine ?? StockfishService();

  final StockfishService _engine;
  bool _cancelled = false;

  void cancel() => _cancelled = true;

  /// Starts the engine, then reports whether it is one that can answer.
  ///
  /// Must be awaited before the check: `isOnline` is decided by whether a local
  /// binary is actually running, and the flag that says so is only set by
  /// `initEngine`. Reading it first reported "no local engine" to a trainer who
  /// had one configured and had simply not opened the analysis board yet.
  ///
  /// The question is worth asking at all because on Windows the app otherwise
  /// goes to a cloud engine, and a diagram lifted out of a book is precisely the
  /// position no online database has ever seen — a batch would grind through
  /// every entry and return nothing.
  Future<bool> ensureUsableEngine() async {
    await _engine.initEngine();
    return !_engine.isOnline;
  }

  Duration _timeoutFor(int depth) {
    if (depth <= 14) return const Duration(seconds: 8);
    if (depth <= 20) return const Duration(seconds: 15);
    return const Duration(seconds: 30);
  }

  String _withSide(String fen, String side) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.length < 4) return fen;
    parts[1] = side;
    parts[3] =
        '-'; // the en passant square belongs to the other side's last move
    return parts.join(' ');
  }

  Future<String> _evalFor(String fen, int depth) async {
    final lines = await _engine.analyzePositionSync(
      fen,
      depth: depth,
      multiPV: 1,
      timeout: _timeoutFor(depth),
    );
    return lines.isEmpty ? '' : lines.first.evaluation;
  }

  /// Works through [positions], reporting each answer as it lands.
  ///
  /// Results arrive one at a time rather than in a batch at the end so a long
  /// run is useful while it is still going, and so cancelling keeps whatever
  /// was already learned.
  Future<void> run(
    List<SavedPosition> positions, {
    required int depth,
    required void Function(String puzzleId, SideProposal proposal) onResult,
    required void Function(int done, int total) onProgress,
  }) async {
    _cancelled = false;
    await _engine.initEngine();

    for (var i = 0; i < positions.length; i++) {
      if (_cancelled) {
        AppLogger.log(
            '[SideProposal] Prekinuto na ${i + 1}/${positions.length}.');
        return;
      }
      final position = positions[i];

      SideProposal proposal;
      try {
        // A board only one side can legally be to move in answers itself, and
        // costs no search at all.
        final whitePlayable = isPlayableWith(position.fen, 'w');
        final blackPlayable = isPlayableWith(position.fen, 'b');
        if (whitePlayable != blackPlayable) {
          final side = whitePlayable ? 'w' : 'b';
          proposal = SideProposal(
            side: side,
            confidence: ProposalConfidence.high,
            reason: 'samo ${side == 'w' ? 'beli' : 'crni'} može biti na potezu',
            whiteEval: '',
            blackEval: '',
          );
        } else {
          final whiteEval = await _evalFor(_withSide(position.fen, 'w'), depth);
          if (_cancelled) return;
          final blackEval = await _evalFor(_withSide(position.fen, 'b'), depth);
          proposal = decideSide(whiteEval: whiteEval, blackEval: blackEval);
        }
      } catch (e) {
        AppLogger.log('[SideProposal] ${position.puzzleId}: $e');
        proposal = SideProposal.empty;
      }

      onResult(position.puzzleId, proposal);
      onProgress(i + 1, positions.length);
    }
  }
}
