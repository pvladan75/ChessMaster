import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/fen_legality.dart';

class StockfishService {
  // ─── SINGLETON ───
  static final StockfishService _instance = StockfishService._internal();
  factory StockfishService() => _instance;
  StockfishService._internal();

  Function(String evaluation, String bestMove, String continuation, int multipv,
      int depth, bool isFinal, String analyzedFen)? onEvaluationChanged;
  Function(Map<int, AnalysisLine> lines)? onMultiPVUpdated;

  /// Said when a position is refused before the engine ever sees it. Mirrors
  /// the native service, which is where the reason this exists is written down.
  Function(String reason)? onPositionRefused;

  final Map<int, AnalysisLine> _engineLines = {};

  bool _isActive = false;
  int _requestId = 0;
  int _currentMultiPV = 1;

  // ─── THE REVIEW'S HOLD (see the native service for the full story) ───
  Object? _heldBy;
  final ValueNotifier<bool> _held = ValueNotifier(false);
  ValueListenable<bool> get held => _held;

  final ValueNotifier<int> _refusedWhileHeld = ValueNotifier(0);
  ValueListenable<int> get refusedWhileHeld => _refusedWhileHeld;

  int? _pendingMultiPV;

  @visibleForTesting
  int get debugRequestId => _requestId;
  @visibleForTesting
  int get debugMultiPV => _currentMultiPV;

  void hold(Object owner) {
    _heldBy = owner;
    _held.value = true;
  }

  void release(Object owner) {
    if (!identical(_heldBy, owner)) return;
    _heldBy = null;
    _held.value = false;
    final pending = _pendingMultiPV;
    _pendingMultiPV = null;
    if (pending != null) _currentMultiPV = pending;
    _activateTopSubscriber();
  }

  bool get isActive => _isActive;
  bool get isSupported => true;
  bool get isOnline => true;
  bool get isCustomEngineActive => false;

  Future<void> initEngine() async {
    _isActive = true;
  }

  void clearCallbacks() {
    onEvaluationChanged = null;
    onMultiPVUpdated = null;
    onPositionRefused = null;
  }

  // ─── SUBSCRIBER STACK ───
  // Mirrors the native implementation: screens attach while on top of the
  // navigation stack, and detaching reactivates the screen underneath rather
  // than leaving the shared engine with no listener.
  final List<_EngineSubscriber> _subscribers = [];

  void attach(
    Object owner, {
    Function(String evaluation, String bestMove, String continuation,
            int multipv, int depth, bool isFinal, String analyzedFen)?
        onEvaluation,
    Function(Map<int, AnalysisLine> lines)? onMultiPV,
    Function(String reason)? onRefused,
    String Function()? getFen,
    bool Function()? isEnabled,
  }) {
    _subscribers.removeWhere((s) => identical(s.owner, owner));
    _subscribers.add(_EngineSubscriber(owner, onEvaluation, onMultiPV,
        onRefused: onRefused, getFen: getFen, isEnabled: isEnabled));
    _activateTopSubscriber();
  }

  void detach(Object owner) {
    _subscribers.removeWhere((s) => identical(s.owner, owner));
    stopAnalysis();
    _activateTopSubscriber();
  }

  void reactivateTopSubscriber() {
    stopAnalysis();
    _activateTopSubscriber();
  }

  void _activateTopSubscriber() {
    if (_held.value) return;
    if (_subscribers.isEmpty) {
      onEvaluationChanged = null;
      onMultiPVUpdated = null;
      onPositionRefused = null;
      return;
    }
    final top = _subscribers.last;
    onEvaluationChanged = top.onEvaluation;
    onMultiPVUpdated = top.onMultiPV;
    onPositionRefused = top.onRefused;

    final active = top.isEnabled?.call() ?? true;
    final currentFen = top.getFen?.call();
    if (active && currentFen != null && currentFen.isNotEmpty) {
      analyzePosition(currentFen);
    }
  }

  Future<void> analyzePosition(String fen,
      {int depth = 10, bool isInfinite = false}) async {
    if (_held.value) {
      _refusedWhileHeld.value++;
      return;
    }
    await _analyzePositionNow(fen, depth: depth, isInfinite: isInfinite);
  }

  /// The actual work, bypassing the hold: the review's own
  /// [analyzePositionSync] calls this directly, since a review's search is
  /// what the hold exists to protect, not to block.
  Future<void> _analyzePositionNow(String fen,
      {int depth = 10, bool isInfinite = false}) async {
    // Same door, same guard — see the native service for why it is here and
    // not on the screens.
    final illegal = fenIllegalReason(fen);
    if (illegal != null) {
      _isActive = false;
      onPositionRefused?.call(illegal);
      return;
    }
    _isActive = true;

    final reqId = ++_requestId;

    final targetDepth = isInfinite ? 50 : depth.clamp(5, 50);

    try {
      final url =
          'https://stockfish.online/api/s/v2.php?fen=${Uri.encodeComponent(fen)}&depth=$targetDepth';
      final response = await http.get(Uri.parse(url));

      if (reqId != _requestId) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          String eval = '0.00';
          if (data['mate'] != null) {
            final mate = data['mate'] as int;
            eval = mate > 0 ? 'M$mate' : '-M${mate.abs()}';
          } else if (data['evaluation'] != null) {
            final double score = (data['evaluation'] as num).toDouble();
            eval = score > 0 ? '+$score' : '$score';
          }

          String bestMove = '-';
          if (data['bestmove'] != null) {
            final bestStr = data['bestmove'] as String;
            final match = RegExp(r'bestmove\s+(\S+)').firstMatch(bestStr);
            if (match != null) {
              bestMove = match.group(1)!;
            }
          }

          String continuation = '';
          if (data['continuation'] != null) {
            continuation = data['continuation'] as String;
          }

          if (onEvaluationChanged != null) {
            onEvaluationChanged!(
                eval, bestMove, continuation, 1, targetDepth, true, fen);
          }

          _engineLines[1] = AnalysisLine.fromPv(
            multipv: 1,
            eval: eval,
            pvString: continuation.isNotEmpty ? continuation : bestMove,
            startingFen: fen,
          );
          if (onMultiPVUpdated != null) {
            onMultiPVUpdated!(_engineLines);
          }
        }
      }
    } catch (_) {
      // Ignore network errors gracefully
    }
  }

  void stopAnalysis() {
    if (_held.value) return;
    _requestId++;
    _isActive = false;
  }

  void setMultiPV(int count) {
    if (_held.value) {
      _pendingMultiPV = count;
      return;
    }
    _currentMultiPV = count;
  }

  /// Deliberately does not clear callbacks — see the native implementation.
  void dispose() {
    stopAnalysis();
  }

  void shutdown() {
    _isActive = false;
    onEvaluationChanged = null;
    onMultiPVUpdated = null;
  }

  /// The web engine keeps no answers: its build is not ours to name.
  Future<String?> answerStoreName() async => null;

  /// [searchMoves] is ignored: the web/online engine answers with whatever it
  /// already computed and cannot be told to restrict its search to one move
  /// — the review's judge detects the mismatch and falls back around it.
  Future<List<AnalysisLine>> analyzePositionSync(
    String fen, {
    required int depth,
    required int multiPV,
    List<String>? searchMoves,
    Duration timeout = const Duration(seconds: 10),
    void Function(List<AnalysisLine> partial)? onProgress,
  }) async {
    await _analyzePositionNow(fen, depth: depth);
    // A concurrent call to analyzePosition() for a different fen can
    // supersede this one's request (see the `reqId != _requestId` guard
    // above) and leave `_engineLines` holding that other call's result —
    // don't hand a caller an answer for a position it didn't ask about.
    final lines = _engineLines.values
        .where((line) => line.startingFen.isEmpty || line.startingFen == fen)
        .toList();
    // The web/stub engine has no intermediate output to report, so the only
    // progress there is to report is the answer itself.
    if (onProgress != null && lines.isNotEmpty) onProgress(lines);
    return lines;
  }
}

/// One screen's registration with the shared engine.
class _EngineSubscriber {
  final Object owner;
  final Function(String evaluation, String bestMove, String continuation,
      int multipv, int depth, bool isFinal, String analyzedFen)? onEvaluation;
  final Function(Map<int, AnalysisLine> lines)? onMultiPV;
  final Function(String reason)? onRefused;
  final String Function()? getFen;
  final bool Function()? isEnabled;

  _EngineSubscriber(this.owner, this.onEvaluation, this.onMultiPV,
      {this.onRefused, this.getFen, this.isEnabled});
}
