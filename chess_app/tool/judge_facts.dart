/// The review's verdicts written into the harness's input facts —
/// `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 1b.
///
///     set JUDGE_FACTS_DIR=<a folder>   (default ../tools/game_annotate/input)
///     set JUDGE_FACTS_GAMES=g01_scandinavian-defense,…   (default: the ten)
///     flutter test tool/judge_facts.dart
///
/// Since 1b a tutorial's moments are the moves the review's own judge
/// (`GameReviewJudge`) calls mistakes, and the only moves the player found; the
/// app writes those verdicts into the facts it builds, as `played.judged`, and
/// the skeleton — the app's and `skeleton.py` — reads nothing else. The
/// harness has no judge of its own and must not grow one (rule 12), so the
/// verdicts of its input games are written here, by the app's judge, into the
/// files `export_fixtures.py` reads.
///
/// **On each game's own answers, not a live engine** (`test/support/
/// facts_engine.dart`): every position the judge asks is answered from the
/// candidates stored in the facts, and the played move alone from the stored
/// answer of the position after it. So the verdicts are the rule applied to
/// the very numbers the fixtures hold, they come out the same on every run and
/// every machine, and the test that runs the tutorial end to end reaches them
/// again with the same stand-in. No tablebase is asked (the engine judges the
/// endings, as when the tablebase does not answer).
///
/// Run it after `make_facts.py` builds or re-costs a game, then
/// `python export_fixtures.py`. A test rather than a script for the reason
/// `game_facts.dart` gives, and in `tool/` so the suite's count is untouched.
library;

import 'dart:convert';
import 'dart:io';

import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/game_analysis_walker_service.dart'
    show BlunderAlertSide;
import 'package:chess_app/core/services/game_review_judge.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/review_verdicts.dart';

import '../test/support/facts_engine.dart';

const _tenGames = [
  'g01_scandinavian-defense',
  'g02_french-defense',
  'g03_scandinavian-defense',
  'g04_saragossa-opening',
  'g05_french-defense',
  'g06_zukertort-opening',
  'g07_english-opening',
  'g08_nimzowitsch-defense',
  'g09_caro-kann-defense',
  'g10_english-opening',
];

void main() {
  final dir = Platform.environment['JUDGE_FACTS_DIR'] ??
      '../tools/game_annotate/input';
  final chosen = Platform.environment['JUDGE_FACTS_GAMES'];
  final games = chosen == null || chosen.trim().isEmpty
      ? _tenGames
      : chosen.split(',').map((g) => g.trim()).toList();

  for (final name in games) {
    test(name, () async {
      final file = File('$dir/${name}_facts.json');
      final facts =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final rows = (facts['rows'] as List).cast<Map<String, dynamic>>();

      final start = rows.first['fen'] as String;
      final board = chess.Chess.fromFEN(start);
      final uci = <String>[];
      for (final row in rows) {
        final played = row['played'] as Map<String, dynamic>?;
        if (played == null) break;
        played.remove('judged');
        expect(board.move(played['move'] as String), isTrue,
            reason: '${played['label']} does not play');
        final m = board.history.last.move;
        uci.add('${m.fromAlgebraic}${m.toAlgebraic}${m.promotion?.name ?? ''}');
      }

      final result = await GameReviewJudge(
        analyzer: factsEngine(facts),
        book: (fens) => factsMasters(facts, fens),
        tablebase: (_) async => null,
      ).review(
        startingFen: start,
        uciMoves: uci,
        depth: facts['depth'] as int,
        puzzles: BlunderAlertSide.both,
      );
      expect(result, isNotNull);
      applyReviewVerdicts(rows, result!);

      final judged = [
        for (final r in rows)
          if ((r['played'] as Map?)?['judged'] != null)
            (r['played'] as Map)['judged'] as Map,
      ];
      expect(judged.length, uci.length,
          reason: 'every move played carries a verdict');
      final mistakes = judged.where((j) => j['mistake'] == true).length;
      final only = judged.where((j) => j['only'] == true).length;
      final unsettled = judged.where((j) => j['unsettled'] == true).length;
      final unjudged = judged.where((j) => j.containsKey('unjudged')).length;
      // ignore: avoid_print
      print('$name: $mistakes mistakes, $only only moves, '
          '$unsettled unsettled, $unjudged unjudged');

      file.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(facts));
    });
  }
}
