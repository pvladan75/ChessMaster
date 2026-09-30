// The tablebase's moves arrive best first, and the app keeps that order.
//
// `chess_backend/test/fixtures/tablebase_best.json` holds real answers of
// Lichess's tablebase; `best` is the first move of Lichess's own list. The
// server's `bestReply` is held to picking it from the moves in any order; the
// app's reader is held here to keeping the order it was given, because the
// position study plays the first move that keeps the result (rule 12: when
// two ends must agree, share one fixture).
//
// Until 30.9.2026 `SyzygyResult.fromJson` sorted the moves again by the
// result and then by the smallest DTZ. That put a lost side's quickest
// collapse first and threw the distance to mate away, and the owner's rook
// ending was studied as a repetition.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';

void main() {
  final cases = (jsonDecode(
          File('../chess_backend/test/fixtures/tablebase_best.json')
              .readAsStringSync()) as Map<String, dynamic>)['cases']
      as List<dynamic>;

  test('the fixture holds the cases it was written for', () {
    expect(cases.length, greaterThanOrEqualTo(10));
  });

  for (final c in cases.cast<Map<String, dynamic>>()) {
    test('the order is kept: ${c['why']}', () {
      final answer = c['answer'] as Map<String, dynamic>;
      final result = SyzygyResult.fromJson(c['fen'] as String, answer);
      expect(
        [for (final m in result.moves) m.uci],
        [for (final m in answer['moves'] as List) (m as Map)['uci']],
      );
      expect(result.moves.first.uci, c['best']);
      expect(result.moves.first.dtm, (answer['moves'] as List).first['dtm']);
    });
  }
}
