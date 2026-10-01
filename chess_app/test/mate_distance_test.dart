// The tablebase's distance to mate, read as moves from the mover's side.
//
// Held to the real answers in `chess_backend/test/fixtures/tablebase_best.json`
// (rule 12): a position's own count and the count of its best move must say
// the same „mate in N", and the count of the move that loses fastest must say
// one move more for the opponent than the position after it does.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/mate_distance.dart';

void main() {
  final cases = (jsonDecode(
          File('../chess_backend/test/fixtures/tablebase_best.json')
              .readAsStringSync()) as Map<String, dynamic>)['cases']
      as List<dynamic>;

  Map<String, dynamic> byWhy(String start) => cases
      .cast<Map<String, dynamic>>()
      .firstWhere((c) => (c['why'] as String).startsWith(start));

  test('a won position and its best move are the same mate', () {
    // The owner's rook ending: dtm 55 plies for Black, Kf3 then -54.
    final c = byWhy("the owner's rook ending");
    final answer = c['answer'] as Map<String, dynamic>;
    final best = (answer['moves'] as List).first as Map<String, dynamic>;
    expect(mateInFromPosition(answer['dtm'] as int), 28);
    expect(mateInAfterMove(best['dtm'] as int), 28);
    expect(mateLabel(28), 'mate in 28');
  });

  test('a lost position and its longest defence are the same mate', () {
    // After Kf3: dtm -54 for White, and Rb7 holds 53 plies for Black.
    final c = byWhy('the defence DTZ got wrong');
    final answer = c['answer'] as Map<String, dynamic>;
    final best = (answer['moves'] as List).first as Map<String, dynamic>;
    expect(mateInFromPosition(answer['dtm'] as int), -27);
    expect(mateInAfterMove(best['dtm'] as int), -27);
    expect(mateLabel(-27), 'mated in 27');
  });

  test('a mate carries no distance and is mate in one', () {
    final c = byWhy('mate in one');
    final answer = c['answer'] as Map<String, dynamic>;
    final mate = (answer['moves'] as List).first as Map<String, dynamic>;
    expect(mate['dtm'], isNull);
    expect(mateInFromPosition(answer['dtm'] as int), 1);
    expect(mateInAfterMove(null, checkmate: true), 1);
  });

  test('every best move of a decided position agrees with the position', () {
    var compared = 0;
    for (final c in cases.cast<Map<String, dynamic>>()) {
      final answer = c['answer'] as Map<String, dynamic>;
      final best = (answer['moves'] as List).first as Map<String, dynamic>;
      final own = mateInFromPosition(answer['dtm'] as int?);
      final after = mateInAfterMove(best['dtm'] as int?,
          checkmate: best['checkmate'] == true);
      if (own == null || after == null) continue;
      expect(after, own, reason: c['why'] as String);
      compared++;
    }
    expect(compared, greaterThanOrEqualTo(8));
  });

  test('nothing known is nothing said: null, and zero on a draw', () {
    expect(mateInFromPosition(null), isNull);
    expect(mateInFromPosition(0), isNull);
    expect(mateInAfterMove(null), isNull);
    expect(mateInAfterMove(0), isNull);
    expect(mateLabel(null), isNull);
  });
}
