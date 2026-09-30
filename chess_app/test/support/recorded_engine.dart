/// The real engine's answers, recorded — what a position study's tests are
/// built from.
///
/// `tool/position_study.dart` with `STUDY_RECORD=1` wrote the files under
/// `test/fixtures/position_study/`: every search a study asked Stockfish 19
/// for at depth 20, and every answer Lichess's tablebase gave. Played back
/// here they give the builder exactly what the engine gave it, so a test sees
/// the study a reader would.
///
/// **A question the recording does not hold is answered with nothing and
/// written down**, never thrown: the builder forgives an engine that falls
/// silent — it counts the search as lost and leaves that branch out — so a
/// fake that threw would hide behind the code that forgives it. Assert
/// [unanswered] is empty.
library;

import 'dart:convert';
import 'dart:io';

import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart'
    show SyzygyResult;
import 'package:chess_app/models/analysis_models.dart';

class RecordedEngine {
  RecordedEngine._(this.fen, this.depth, this._searches, this._tables);

  /// `owner1`, `owner2`, `owner3`, `own1`, `classic5`, `classic6`.
  factory RecordedEngine.read(String name) {
    final data = jsonDecode(
        File('test/fixtures/position_study/${name}_engine.json')
            .readAsStringSync()) as Map<String, dynamic>;
    return RecordedEngine._(
      data['fen'] as String,
      data['depth'] as int,
      {
        for (final s in (data['searches'] as List).cast<Map<String, dynamic>>())
          _key(s['fen'] as String, s['multiPV'] as int):
              (s['lines'] as List).cast<Map<String, dynamic>>(),
      },
      {
        for (final t
            in (data['tablebase'] as List).cast<Map<String, dynamic>>())
          t['fen'] as String: t['answer'] as Map<String, dynamic>?,
      },
    );
  }

  /// The position the recording is of, and the depth it was searched at.
  final String fen;
  final int depth;

  final Map<String, List<Map<String, dynamic>>> _searches;
  final Map<String, Map<String, dynamic>?> _tables;

  /// Every search asked for, in order: `(fen, lines)`.
  final List<(String, int)> asked = [];

  /// Every tablebase question asked, in order.
  final List<String> askedTablebase = [];

  /// Questions the recording had no answer to.
  final List<String> unanswered = [];

  /// Lines to answer with instead of the recording's, by position — for a
  /// case that needs the engine to have said something else.
  final Map<String, List<Map<String, dynamic>>> instead = {};

  /// Searches that come back at a depth short of what was asked, by
  /// position: a search its timeout stopped.
  final Set<String> short = {};

  static String _key(String fen, int lines) => '$lines|$fen';

  Future<List<AnalysisLine>> analyzer(
    String fen, {
    required int depth,
    required int multiPV,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    asked.add((fen, multiPV));
    final lines = instead[fen] ?? _recorded(fen, multiPV);
    if (lines == null) {
      unanswered.add('$multiPV lines for $fen');
      return const [];
    }
    return [
      for (final l in lines)
        AnalysisLine.fromPv(
          multipv: l['multipv'] as int,
          depth: short.contains(fen) ? depth - 3 : l['depth'] as int,
          eval: l['evaluation'] as String,
          pvString: l['pv'] as String,
          startingFen: fen,
        ),
    ];
  }

  /// The recording for [fen] with [lines] lines — or, as the app's own store
  /// of answers serves it, the first [lines] of a recording with more.
  List<Map<String, dynamic>>? _recorded(String fen, int lines) {
    final exact = _searches[_key(fen, lines)];
    if (exact != null) return exact;
    for (var more = lines + 1; more <= 8; more++) {
      final wider = _searches[_key(fen, more)];
      if (wider != null) return wider.take(lines).toList();
    }
    return null;
  }

  Future<SyzygyResult?> tablebase(String fen) async {
    askedTablebase.add(fen);
    if (!_tables.containsKey(fen)) {
      unanswered.add('the tablebase for $fen');
      return null;
    }
    final answer = _tables[fen];
    return answer == null ? null : SyzygyResult.fromJson(fen, answer);
  }
}
