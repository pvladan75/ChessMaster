import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:chess_app/services/puzzle_api_service.dart';
import 'package:chess_app/services/puzzle_engine.dart';
import 'package:chess_app/features/puzzle_trainer/puzzle_state.dart';

final puzzleNotifierProvider =
    StateNotifierProvider<PuzzleNotifier, PuzzleTrainerState>((ref) {
  return PuzzleNotifier();
});

class PuzzleNotifier extends StateNotifier<PuzzleTrainerState> {
  PuzzleNotifier() : super(const PuzzleTrainerState());

  void selectCategory(String? category, {String? mateDepth}) {
    state = state.copyWith(
      selectedCategory: category,
      selectedMateDepth: mateDepth ?? state.selectedMateDepth,
      status: category == null ? PuzzleStatus.idle : PuzzleStatus.loading,
    );
  }

  void toggleEvalBar() {
    state = state.copyWith(showEvalBar: !state.showEvalBar);
  }

  void toggleEvaluation() {
    state = state.copyWith(showEvaluation: !state.showEvaluation);
  }

  void setBackendConnected(bool isConnected) {
    state = state.copyWith(isBackendConnected: isConnected);
  }

  Future<void> loadNextPuzzle({
    required String userToken,
    String? excludeId,
  }) async {
    state = state.copyWith(status: PuzzleStatus.loading, errorMessage: null);

    final puzzleData = await PuzzleApiService.instance.fetchNextPuzzle(
      type: state.selectedCategory ?? 'mate_puzzle',
      mateDepth: state.selectedMateDepth,
      excludeId: excludeId,
      userToken: userToken,
    );

    if (puzzleData == null || puzzleData['fen'] == null) {
      state = state.copyWith(
        status: PuzzleStatus.failed,
        errorMessage: 'Greška pri učitavanju zagonetke sa servera.',
      );
      return;
    }

    final String fen = puzzleData['fen'];
    final Map<String, dynamic> solutions =
        Map<String, dynamic>.from(puzzleData['solutions'] ?? {});
    final isWhite = fen.contains(' w ');

    final engine = PuzzleEngine(solutions);

    state = state.copyWith(
      currentPuzzle: puzzleData,
      currentFen: fen,
      initialFen: fen,
      status: PuzzleStatus.playing,
      engine: engine,
      puzzleOrientation: isWhite ? PlayerColor.white : PlayerColor.black,
    );
  }

  void onUserMove(String moveUci) {
    if (state.engine == null) return;

    final result = state.engine!.playUserMove(moveUci);

    if (result == MoveValidationResult.incorrect) {
      state = state.copyWith(status: PuzzleStatus.failed);
    } else if (result == MoveValidationResult.checkmate ||
        state.engine!.isFullySolved) {
      state = state.copyWith(status: PuzzleStatus.solved);
      _submitResult(solved: true);
    } else {
      state = state.copyWith(status: PuzzleStatus.opponentTurn);
      _playOpponentTurn();
    }
  }

  void _playOpponentTurn() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (state.engine == null) return;

      final oppMove = state.engine!.playOpponentResponse();
      if (oppMove != null) {
        state = state.copyWith(status: PuzzleStatus.playing);
      }
    });
  }

  void retryPuzzle() {
    if (state.initialFen == null || state.currentPuzzle == null) return;

    final Map<String, dynamic> solutions =
        Map<String, dynamic>.from(state.currentPuzzle!['solutions'] ?? {});
    final engine = PuzzleEngine(solutions);

    state = state.copyWith(
      currentFen: state.initialFen,
      status: PuzzleStatus.playing,
      engine: engine,
    );
  }

  Future<void> _submitResult({required bool solved}) async {
    final puzzleId = state.currentPuzzle?['id']?.toString();
    if (puzzleId == null) return;

    await PuzzleApiService.instance.submitPuzzleResult(
      puzzleId: puzzleId,
      solved: solved,
      userToken: '',
    );
  }
}
