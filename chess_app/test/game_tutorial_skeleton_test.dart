// The gate for phase 1 of `docs/PLAN-SKELET.md` — the skeleton ported from
// `tools/game_annotate/skeleton.py` into the app.
//
// Written before the batch. It moves to
// `chess_app/test/game_tutorial_skeleton_test.dart` in the merge commit.
//
// **Every expectation below was written by the harness.** The fixtures in
// `chess_app/test/fixtures/game_tutorial/` are computed from `skeleton.py` by
// `tools/game_annotate/export_fixtures.py`, and `--check` fails the day the two
// part. Nothing here is a hand-written opinion about what a sentence should
// say: it is what the reference implementation says, for ten real games, a
// model's real answer to each, and five bad answers the harness also judged.
//
// ---------------------------------------------------------------------------
// ALREADY PORTED, AND NOT TO BE WRITTEN AGAIN
//
// `lib/features/tutorial_studio/services/game_tutorial/evaluation_words.dart`:
// `wordsFor`, `standing`, `evaluationLevels`. Held to the harness by
// `test/game_tutorial_evaluation_words_test.dart`. **A second threshold table
// anywhere in the batch is a finding** — `mistake_kind` and the filler read the
// same steps the words are spoken in.
//
// ---------------------------------------------------------------------------
// THE FROZEN CONTRACT
//
// Three new files beside `evaluation_words.dart`, pure Dart — no `dart:io`, no
// Flutter widgets, no network, no engine. Facts go in as the facts file's own
// JSON (`Map<String, dynamic>`), because phase 2's builder will produce exactly
// that shape and be held to `make_facts.py` the same way.
//
//   skeleton_parameters.dart
//     class SkeletonParameters {
//       const SkeletonParameters({this.minCost = 1.0, this.near = 0.3,
//           this.maxCorrect = 3, this.maxMoments = 8, this.leadPlies = 3,
//           this.answerPlies = 4});
//       Map<String, dynamic> toJson();   // the harness's keys: min_cost, ...
//     }
//
//   skeleton_moments.dart                      skeleton.moments + play,
//     List<Map<String, dynamic>> skeletonMoments(   material, cost_text,
//         Map<String, dynamic> facts,               share_words, book_words
//         {SkeletonParameters parameters = const SkeletonParameters()});
//
//   skeleton_assembly.dart                     skeleton.assemble, _claims,
//     class SkeletonAssembly {                    _clean, whole_game, LEXICON,
//       final Map<String, dynamic> report;        mistake_kind, filler_words,
//       final Map<String, dynamic>? tutorial;     book_summary, stamp_of
//       final Map<String, dynamic>? tutorialGame;
//     }
//     SkeletonAssembly assembleSkeleton(
//         Map<String, dynamic> facts, String answerText,
//         {SkeletonParameters parameters = const SkeletonParameters()});
//
// One more file is allowed in that folder and not required:
// `board_queries.dart`, for the board questions python-chess answers and
// `package:chess` does not (point 7 below). A fifth is not allowed.
//
// `report` is the harness's `meta['skeleton']`; `tutorial` and `tutorialGame`
// are `tutorial.json` and `tutorial-game.json`, and both are null exactly when
// the harness wrote neither (an answer that is not JSON).
//
// **The prompt is not ported.** It moves to the server in phase 3, as the one
// copy; the app sends the moments. Do not port `prompt()` or `PROMPT`.
//
// ---------------------------------------------------------------------------
// HOW A PART'S `pgn` IS WRITTEN — the one place byte equality is not asked
//
// Through `StudioLessonStep.from(root)`, over a chain of `AnalysisNode`s
// carrying each move's SAN, fen and comment — the app's one writer. **Never
// `PgnExporterService` directly** (the tutorial feature reaches it only through
// `StudioLessonStep`), and never a hand-built string.
//
// So the fixtures' `pgn` (python-chess, wrapped at 80 columns) cannot match
// byte for byte, and the gate reads both back through `LessonStepLine` — the
// child's reader — and compares the moves, the root comment and every move's
// comment with runs of whitespace collapsed. That this comparison can be passed
// was proved before the batch: `test/game_tutorial_evaluation_words_test.dart`
// rebuilds every part of every fixture through `StudioLessonStep.from` and gets
// the harness's reading back. **Every other field is JSON-equal.**
//
// ---------------------------------------------------------------------------
// WHERE PYTHON AND DART DISAGREE — read before translating
//
//  1. **`List.sort` is not stable in Dart.** The harness sorts candidate
//     moments by cost with ties left in game order, then cuts to `max_moments`,
//     then re-sorts by index. Sort by (cost descending, index ascending).
//  2. **Python's `round` is half-to-even**: `share_words` writes `'%d%%' %
//     round(100 * share)`, and 12.5 is 12 there and 13 with `.round()`.
//  3. **`'%.1f' % x` rounds an exact binary tie to even; `toStringAsFixed(1)`
//     rounds it away from zero**: `0.25` is `0.2` in Python and `0.3` in Dart.
//     Measured after batch 70 — this line said the two agreed, which was a
//     guess, and no fixture game has such a share, so the gate could not say
//     otherwise. `test/game_tutorial_skeleton_edges_test.dart` can.
//  4. **`'%+d'`** writes `+0` and `+2`: material in the lead-in and answer
//     intros.
//  5. **`'%s' % 1.0` is `1.0`, and `'%s' % 2` is `2`.** `cost_pawns` keeps the
//     type the facts JSON gave it; do not convert it to a double and back.
//  6. **Dictionary order is output.** The harness walks `moment['slots']` in
//     insertion order, and the claims in the report come out in that order. A
//     Dart `Map` literal keeps insertion order too — insert in the same order.
//  7. **python-chess answers questions `package:chess` has no method for**:
//     `board.attacks(square)` (every square one piece attacks, by geometry,
//     whatever stands there), `board.is_pinned(color, square)`, and
//     `is_en_passant`, all in `play()`. `tactical_motif_detector.dart` has a
//     private `_isAbsolutelyPinned` and a private `_legalCapturerSquares` —
//     the second is a question about legal captures, not python-chess's
//     `attacks`, so it is not the same answer. Whether to lift the pin check
//     out of the detector or write a small helper is the batch's call; the
//     gate decides whether it answers what the harness answered.
//  8. **`re` and `RegExp`**: Python 3's `\w` and `\b` count accented letters
//     as word characters; a Dart `RegExp`'s do not, **even with
//     `unicode: true`** (JavaScript semantics). The fixtures are English, so
//     translate the patterns as written and do not try to emulate Python's
//     Unicode word boundary — a divergence the fixtures cannot see is not
//     one to invent code for. `\s` is Unicode-aware on both sides.
//  9. **`json.loads` of text that is not JSON** is `the answer is not JSON` and
//     no tutorial at all — `jsonDecode` throws `FormatException`, and the
//     report must say the same sentence.
// 10. **`str(text or '')`** in `_clean` turns a number or `null` a model put in
//     a slot into text. `tags[:2]` is taken after cleaning.
// 11. **`sorted(set(given) - wanted)`** is code-point order, which is what
//     `String.compareTo` gives.
//
// ---------------------------------------------------------------------------
// WHAT THE BATCH MUST NOT TOUCH
//
// `tools/game_annotate/` — the reference, and `export_fixtures.py` with it;
// `chess_app/test/fixtures/game_tutorial/`; `evaluation_words.dart` and its
// test. If a fixture looks wrong, **stop and say so**: a port that edits the
// expectation it is judged against has proved nothing, and a disagreement with
// the harness is the lead's to settle in the harness first.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/lessons/models/lesson_step_line.dart';
import 'package:chess_app/move_tree.dart' show ChessArrow;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_assembly.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_moments.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_parameters.dart';

const _fixtures = 'test/fixtures/game_tutorial';
const _port = 'lib/features/tutorial_studio/services/game_tutorial';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> _games() {
  final files = Directory(_fixtures)
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'g\d\d_[a-z-]+\.json$').hasMatch(f.path))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [for (final f in files) _read(f.path)];
}

/// Where two JSON values part, as a path. A whole-document mismatch says
/// nothing a translator can act on.
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
  // `2 == 2.0` is true for `num`, which is JSON's own equality.
  if (expected != actual || (expected is String) != (actual is String)) {
    return '$at: harness ${jsonEncode(expected)}, here ${jsonEncode(actual)}';
  }
  return null;
}

/// Round-trips through JSON, so a port's `Map<String, Object>` and the
/// fixture's `Map<String, dynamic>` compare as the documents they are.
Object? _asJson(Object? value) => jsonDecode(jsonEncode(value));

String _spaced(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// The arrows of one node as text, in the order they were written.
List<String> _arrows(List<ChessArrow> arrows) =>
    [for (final a in arrows) a.toString()];

/// Two tutorials agree: every field JSON-equal except each part's `pgn`,
/// which is compared by what the child's reader reads back.
void _expectTutorial(
  Map<String, dynamic>? expected,
  Map<String, dynamic>? actual,
  String name,
) {
  if (expected == null) {
    expect(actual, isNull, reason: '$name: the harness wrote no tutorial');
    return;
  }
  expect(actual, isNotNull, reason: '$name: the harness wrote a tutorial');
  final want = _asJson(expected) as Map<String, dynamic>;
  final got = _asJson(actual) as Map<String, dynamic>;

  final wantSteps = want['positionList'] as List;
  final gotSteps = (got['positionList'] as List?) ?? const [];
  expect(gotSteps, hasLength(wantSteps.length), reason: '$name: parts');

  for (var i = 0; i < wantSteps.length; i++) {
    final w = Map<String, dynamic>.of(wantSteps[i] as Map<String, dynamic>);
    final g = Map<String, dynamic>.of(gotSteps[i] as Map<String, dynamic>);
    final wantPgn = w.remove('pgn') as String? ?? '';
    final gotPgn = g.remove('pgn') as String? ?? '';
    expect(_firstDifference(w, g, '$name.positionList[$i]'), isNull);

    if (wantPgn.trim().isEmpty) {
      expect(gotPgn.trim(), isEmpty, reason: '$name part ${i + 1}: no line');
      continue;
    }
    final fen = w['fen'] as String;
    final harness = LessonStepLine.read(fen: fen, pgn: wantPgn).line;
    final port = LessonStepLine.read(fen: fen, pgn: gotPgn);
    expect(port.rejectedMoves, 0, reason: '$name part ${i + 1}: replays');
    expect(
      port.line.movesSan,
      harness.movesSan,
      reason: '$name part ${i + 1}: moves',
    );
    expect(
      _spaced(port.line.rootComment),
      _spaced(harness.rootComment),
      reason: '$name part ${i + 1}: the words before the first move',
    );
    // **Drawn, not only said.** Until 15.9.2026 this loop compared the words
    // and nothing else, so an arrow the harness writes and the port does not
    // — or the other way round — passed the gate in silence. The blue arrow of
    // a fork had been drawn since 14.9.2026 and was never once compared here.
    // `[%cal]` is read back out of the comment by the same parser, so the two
    // dialects (python-chess writes the tag first, this app writes it last)
    // cannot make this differ.
    expect(
      _arrows(port.line.rootArrows),
      _arrows(harness.rootArrows),
      reason: '$name part ${i + 1}: what is drawn on its board',
    );
    for (var m = 0; m < harness.movesSan.length; m++) {
      expect(
        _spaced(port.line.comments[m]),
        _spaced(harness.comments[m]),
        reason: '$name part ${i + 1}, ${harness.movesSan[m]}: its words',
      );
      expect(
        _arrows(port.line.arrows[m]),
        _arrows(harness.arrows[m]),
        reason: '$name part ${i + 1}, ${harness.movesSan[m]}: what it draws',
      );
    }
  }
  expect(
    _firstDifference(
      {...want}..remove('positionList'),
      {...got}..remove('positionList'),
      name,
    ),
    isNull,
  );
}

void main() {
  final games = _games();

  test('the ten games of the harness are all here', () {
    expect(games, hasLength(10));
  });

  test('the parameters are the harness defaults, under the harness names', () {
    for (final game in games) {
      expect(
        _firstDifference(
          game['parameters'],
          _asJson(const SkeletonParameters().toJson()),
        ),
        isNull,
      );
    }
  });

  group('the moments offered', () {
    for (final game in games) {
      test('${game['game']}', () {
        final facts = game['facts'] as Map<String, dynamic>;
        final moments = skeletonMoments(facts);
        expect(
          _firstDifference(game['expected']['moments'], _asJson(moments)),
          isNull,
        );
      });
    }
  });

  group('the report on the model\'s answer', () {
    for (final game in games) {
      test('${game['game']}', () {
        final assembly = assembleSkeleton(
          game['facts'] as Map<String, dynamic>,
          game['answer'] as String,
        );
        expect(
          _firstDifference(
            game['expected']['report'],
            _asJson(assembly.report),
          ),
          isNull,
        );
      });
    }
  });

  group('both tutorials', () {
    for (final game in games) {
      test('${game['game']}: key moments and the whole game', () {
        final assembly = assembleSkeleton(
          game['facts'] as Map<String, dynamic>,
          game['answer'] as String,
        );
        _expectTutorial(
          game['expected']['tutorial'] as Map<String, dynamic>?,
          assembly.tutorial,
          'tutorial',
        );
        _expectTutorial(
          game['expected']['tutorialGame'] as Map<String, dynamic>?,
          assembly.tutorialGame,
          'tutorialGame',
        );
      });
    }
  });

  group('answers that are not good ones — reported, never patched', () {
    final file = _read('$_fixtures/answer_cases.json');
    final game = games.firstWhere((g) => g['game'] == file['game']);
    for (final c in file['cases'] as List) {
      test('${c['name']}', () {
        final assembly = assembleSkeleton(
          game['facts'] as Map<String, dynamic>,
          c['answer'] as String,
        );
        final expected = c['expected'] as Map<String, dynamic>;
        expect(
          _firstDifference(expected['report'], _asJson(assembly.report)),
          isNull,
        );
        _expectTutorial(
          expected['tutorial'] as Map<String, dynamic>?,
          assembly.tutorial,
          'tutorial',
        );
        _expectTutorial(
          expected['tutorialGame'] as Map<String, dynamic>?,
          assembly.tutorialGame,
          'tutorialGame',
        );
      });
    }
  });

  test('reading the facts does not change them', () {
    for (final game in games.take(3)) {
      final facts = game['facts'] as Map<String, dynamic>;
      final before = jsonEncode(facts);
      skeletonMoments(facts);
      assembleSkeleton(facts, game['answer'] as String);
      expect(jsonEncode(facts), before, reason: '${game['game']}');
    }
  });

  test('the port is pure, and writes a part through the one writer', () {
    final files = Directory(_port)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(
      files.map((f) => f.uri.pathSegments.last),
      containsAll([
        'skeleton_parameters.dart',
        'skeleton_moments.dart',
        'skeleton_assembly.dart',
        'evaluation_words.dart',
      ]),
    );
    for (final file in files) {
      final imports = file
          .readAsLinesSync()
          .where((l) => l.trimLeft().startsWith('import '))
          .join('\n');
      final name = file.uri.pathSegments.last;
      expect(imports, isNot(contains('pgn_exporter_service')), reason: name);
      expect(imports, isNot(contains('dart:io')), reason: name);
      expect(imports, isNot(contains('package:flutter/')), reason: name);
      expect(imports, isNot(contains('package:http')), reason: name);
    }
  });
}
