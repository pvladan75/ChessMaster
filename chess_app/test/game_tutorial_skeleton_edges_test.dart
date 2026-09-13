// What the ten games of the skeleton's gate cannot reach, answered by the
// harness anyway.
//
// Batch 70's report measured it: switching the port to Dart's naive sort and to
// Dart's `.round()` left all 39 gate tests green, because no fixture game has a
// cost tie at the `max_moments` cut or a masters share that is exactly a half.
// A rule no test can fail is a rule nobody has checked, so
// `tools/game_annotate/export_fixtures.py` builds variants of two real games —
// g01 with its book shares replaced by ties, g09 with three pairs of costs made
// equal, one of them across the cut — and records what `skeleton.py` itself
// makes of them in `test/fixtures/game_tutorial/edge_cases.json`.
//
// Two of the rules are rounding rules, and they differ in opposite ways:
//
//  * Python's `round` is half-to-even only on a value that is **exactly** a
//    half. `100 * 0.545` is `54.50000000000001`, which Python rounds to 55; a
//    tolerance that calls it a tie gives 54.
//  * Python's `'%.1f'` rounds an exact binary tie to even, and Dart's
//    `toStringAsFixed(1)` rounds it away from zero: `2.5` → `2.5`, but `0.25`
//    → `0.2` against `0.3`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_assembly.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_moments.dart';

Map<String, dynamic> _cases() => jsonDecode(
        File('test/fixtures/game_tutorial/edge_cases.json').readAsStringSync())
    as Map<String, dynamic>;

/// Where two JSON values part, as a path.
String? _firstDifference(Object? expected, Object? actual, [String at = r'$']) {
  if (expected is Map && actual is Map) {
    for (final key in {...expected.keys, ...actual.keys}) {
      if (!expected.containsKey(key)) return '$at.$key: not in the harness';
      if (!actual.containsKey(key)) return '$at.$key: missing';
      final found = _firstDifference(expected[key], actual[key], '$at.$key');
      if (found != null) return found;
    }
    return null;
  }
  if (expected is List && actual is List) {
    if (expected.length != actual.length) {
      return '$at: ${expected.length} items in the harness, ${actual.length} here';
    }
    for (var i = 0; i < expected.length; i++) {
      final found = _firstDifference(expected[i], actual[i], '$at[$i]');
      if (found != null) return found;
    }
    return null;
  }
  if (expected != actual || (expected is String) != (actual is String)) {
    return '$at: harness ${jsonEncode(expected)}, here ${jsonEncode(actual)}';
  }
  return null;
}

Object? _asJson(Object? value) => jsonDecode(jsonEncode(value));

void main() {
  final cases = _cases();

  test('every share the harness answered, including exact and near halves', () {
    final rows = cases['shareWords'] as List;
    // Not vacuous: the probe must have found both kinds of tie.
    expect(rows.length, greaterThan(15));
    for (final row in rows) {
      expect(shareWords(row[0] as num), row[1], reason: 'share ${row[0]}');
    }
  });

  test('a book whose shares are ties reads as the harness reads it', () {
    final facts = cases['bookFacts'] as Map<String, dynamic>;
    expect(
        _firstDifference(cases['bookMoments'], _asJson(skeletonMoments(facts))),
        isNull);
  });

  test('costs that tie across the cut are offered in the harness order', () {
    final facts = cases['tiedFacts'] as Map<String, dynamic>;
    final moments = skeletonMoments(facts);
    expect(_firstDifference(cases['tiedMoments'], _asJson(moments)), isNull);
    // And the variant really does tie: the pair across the cut shares a cost.
    expect(cases['tiedPairs'], hasLength(3));
  });

  // The rule „a question names its answer or its square" has two halves, and
  // for every move but castling the square half fires on its own — so deleting
  // the answer half left every other test green. `O-O-O`'s last two characters
  // are `-O`, which a lowercased sentence never contains.
  test('a question that writes its castling answer is reported', () {
    final expected = cases['castledExpected'] as Map<String, dynamic>;
    final assembly = assembleSkeleton(
        cases['castledFacts'] as Map<String, dynamic>,
        cases['castledAnswer'] as String);
    expect(
        _firstDifference(expected['report'], _asJson(assembly.report)), isNull);
    expect(
        (assembly.report['claims'] as List)
            .where((c) => '$c'.endsWith('names its answer or its square')),
        isNotEmpty);
  });

  // Not from the harness, and it does not need to be: python-chess's
  // `parse_san` raises on a move it cannot play, so the harness stops too. What
  // is being ruled out is the Dart failure python has no version of —
  // `Chess.move` answering false and leaving the board where it was, so every
  // later position of the whole game is written from the wrong board in
  // silence.
  test('a game move that cannot be played stops the assembly', () {
    final game = jsonDecode(
        File('test/fixtures/game_tutorial/g08_nimzowitsch-defense.json')
            .readAsStringSync()) as Map<String, dynamic>;
    final facts = game['facts'] as Map<String, dynamic>;
    final rows = facts['rows'] as List;
    final end = rows.where((r) => (r as Map)['played'] != null).length;
    // The last move of the game is filler in both of g08's moments' shapes,
    // so only the whole-game writer ever plays it.
    ((rows[end - 1] as Map)['played'] as Map)['move'] = 'Ke9';
    expect(() => assembleSkeleton(facts, game['answer'] as String),
        throwsA(isA<StateError>()));
  });
}
