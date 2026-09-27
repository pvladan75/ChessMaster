/// The engine glue Preparation's screen needs from [StockfishService]:
/// attach while the screen is shown and either switch is on, release when it
/// is not, and keep the last evaluation and lines it was told.
///
/// A third copy of what `AnalysisStudioScreen` and the room's
/// `chess_game_screen.dart` each hold privately inside their own `State`.
/// Kept in this one small class, under `lib/features/preparation/`, so it can
/// be lifted to a shared home later — deliberately not attempted in this
/// batch, and said in the phase 1 report rather than done quietly.
library;

import 'package:chess_app/core/services/eval_parsing.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/stockfish_service.dart';

class PreparationEngine {
  PreparationEngine([StockfishService? service])
      : _service = service ?? StockfishService();

  final StockfishService _service;

  /// Off on arrival, both of them — asked for by every screen this glue was
  /// copied from, and by D11 here too.
  bool showEvaluation = false;
  bool showEvalBar = false;

  /// This board's own dials (phase 2 of `docs/PLAN-PRIPREMA.md`) — not two
  /// numbers written into a request, but state a trainer can move, as the
  /// room's `_analysisDepth`/`_analysisLines` are.
  int analysisDepth = AppSettingsService.instance.analysisDepth;
  int analysisLines = AppSettingsService.instance.analysisLines;

  Map<int, AnalysisLine> lines = {};
  double eval = 0.0;
  String evalString = '0.00';
  int evalDepth = 18;

  bool _attached = false;

  bool get isOn => showEvaluation || showEvalBar;
  bool get isOnline => _service.isOnline;
  bool get isCustomEngineActive => _service.isCustomEngineActive;

  /// For `showEngineSettingsDialog`, which the room's own „More" opens too.
  StockfishService get service => _service;

  /// A dial moved: remembered here, kept in the app's settings, and the
  /// caller re-asks the engine (`triggerAnalysis`) about the position it
  /// stands on.
  void setAnalysisDepth(int depth) {
    analysisDepth = depth;
    AppSettingsService.instance.setAnalysisDepth(depth);
  }

  void setAnalysisLines(int lines) {
    analysisLines = lines;
    AppSettingsService.instance.setAnalysisLines(lines);
  }

  Future<void> init() => _service.initEngine();

  /// Registers this screen with the engine. Safe to call more than once —
  /// only the first, while not already attached, does anything.
  void attach({
    required String Function() getFen,
    required void Function(String reason) onRefused,
    required void Function() onChanged,
  }) {
    if (_attached) return;
    _attached = true;
    _service.attach(
      this,
      getFen: getFen,
      isEnabled: () => isOn,
      onRefused: onRefused,
      onEvaluation: (evaluation, bestMove, continuation, multipv, depth,
          isFinal, analyzedFen) {
        if (multipv != 1) return;
        eval = parseWhiteRelativeEval(evaluation) ?? 0.0;
        evalString = evaluation;
        evalDepth = depth;
        onChanged();
      },
      onMultiPV: (linesMap) {
        lines = linesMap;
        onChanged();
      },
    );
  }

  /// Hands the engine back to whoever else wants it — a screen pushed on top,
  /// or nobody. Safe to call while not attached.
  void detach() {
    if (!_attached) return;
    _attached = false;
    _service.detach(this);
  }

  /// Re-asks the engine about [fen], or stops it, following [isOn].
  ///
  /// Called on a move, on a jump **and on either switch**, as the Analysis
  /// screen does: an engine switched on over a position nobody has touched
  /// answers for that position, it does not wait for the next move.
  void triggerAnalysis(String fen) {
    if (isOn) {
      _service.stopAnalysis();
      _service.setMultiPV(analysisLines);
      _service.analyzePosition(fen, depth: analysisDepth);
    } else {
      stopNow();
    }
  }

  /// Stops the search immediately, with no debounce — safe to call from a
  /// switch that just turned itself off.
  void stopNow() {
    _service.stopAnalysis();
    lines = {};
  }

  /// Switches both off and forgets what they found — leaving the screen
  /// (D11: „no engine, once the screen is gone") or asked for directly.
  void reset() {
    showEvaluation = false;
    showEvalBar = false;
    lines = {};
    _service.stopAnalysis();
  }
}
