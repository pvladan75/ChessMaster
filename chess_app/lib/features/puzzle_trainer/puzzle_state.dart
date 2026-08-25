import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:chess_app/services/puzzle_engine.dart';

enum PuzzleStatus {
  idle,
  loading,
  playing,
  opponentTurn,
  solved,
  failed,
  switchingBranch,
}

class PuzzleTrainerState {
  final Map<String, dynamic>? currentPuzzle;
  final String? currentFen;
  final String? initialFen;
  final PuzzleStatus status;
  final PuzzleEngine? engine;
  final String? errorMessage;
  final PlayerColor puzzleOrientation;
  final String? selectedCategory;
  final String selectedMateDepth;
  final String selectedBasicMateType;
  final bool showEvalBar;
  final bool showEvaluation;
  final bool isBackendConnected;

  const PuzzleTrainerState({
    this.currentPuzzle,
    this.currentFen,
    this.initialFen,
    this.status = PuzzleStatus.idle,
    this.engine,
    this.errorMessage,
    this.puzzleOrientation = PlayerColor.white,
    this.selectedCategory,
    this.selectedMateDepth = '2',
    this.selectedBasicMateType = 'Lako (Mat kralj i kraljica)',
    this.showEvalBar = true,
    this.showEvaluation = false,
    this.isBackendConnected = true,
  });

  PuzzleTrainerState copyWith({
    Map<String, dynamic>? currentPuzzle,
    String? currentFen,
    String? initialFen,
    PuzzleStatus? status,
    PuzzleEngine? engine,
    String? errorMessage,
    PlayerColor? puzzleOrientation,
    String? selectedCategory,
    String? selectedMateDepth,
    String? selectedBasicMateType,
    bool? showEvalBar,
    bool? showEvaluation,
    bool? isBackendConnected,
  }) {
    return PuzzleTrainerState(
      currentPuzzle: currentPuzzle ?? this.currentPuzzle,
      currentFen: currentFen ?? this.currentFen,
      initialFen: initialFen ?? this.initialFen,
      status: status ?? this.status,
      engine: engine ?? this.engine,
      errorMessage: errorMessage,
      puzzleOrientation: puzzleOrientation ?? this.puzzleOrientation,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedMateDepth: selectedMateDepth ?? this.selectedMateDepth,
      selectedBasicMateType:
          selectedBasicMateType ?? this.selectedBasicMateType,
      showEvalBar: showEvalBar ?? this.showEvalBar,
      showEvaluation: showEvaluation ?? this.showEvaluation,
      isBackendConnected: isBackendConnected ?? this.isBackendConnected,
    );
  }
}
