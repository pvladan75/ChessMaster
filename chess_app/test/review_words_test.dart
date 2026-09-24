// The words for a whole-game review — docs/PLAN-ZAGONETKE-IZ-PARTIJE.md,
// §3a and phase 3.
//
// The engine writes the facts, the model only the words, and the app judges
// them: every slot goes through the tutorial's one claim check (`claimsFor`)
// in its third mode, where a move the text names must be in the moment's own
// lines. The request is held word for word to the fixture the server's tests
// read too (`docs/gates/review_words_request.json`, rule 12: two ends that
// must agree share one fixture), and the words land in the game without ever
// writing over a comment already there.

import 'dart:convert';
import 'dart:io';

import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/game_analysis_walker_service.dart';
import 'package:chess_app/core/services/game_review_judge.dart';
import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/core/services/mistake_rule.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/review_words.dart';
import 'package:chess_app/features/analysis_studio/widgets/keep_puzzles_panel.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_assembly.dart';
import 'package:chess_app/models/analysis_models.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// The fixture's game: 1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. O-O Bc5.
const _game = [
  'e2e4',
  'e7e5',
  'g1f3',
  'b8c6',
  'f1c4',
  'g8f6',
  'e1g1',
  'f8c5',
];

List<String> _fens() {
  final board = chess.Chess.fromFEN(_start);
  final fens = [_start];
  for (final u in _game) {
    board.move({'from': u.substring(0, 2), 'to': u.substring(2, 4)});
    fens.add(board.fen);
  }
  return fens;
}

AnalysisLine _line(String fen, String eval, String pv, [int multipv = 1]) =>
    AnalysisLine.fromPv(
      multipv: multipv,
      depth: 20,
      eval: eval,
      pvString: pv,
      startingFen: fen,
    );

/// The review the fixture stands on: 3. Bc4 a mistake (d4 was better, Nf6
/// punishes), 4...Bc5 the only move and found; every other move judged and
/// clean.
GameReviewResult _review({String bestEval = '+0.60'}) {
  final fens = _fens();
  final board = chess.Chess.fromFEN(_start);
  final moves = <ReviewedMove>[];
  for (var i = 0; i < _game.length; i++) {
    final u = _game[i];
    board.move({'from': u.substring(0, 2), 'to': u.substring(2, 4)});
    final sanText = board.pgn().split(RegExp(r'\s+')).last;
    final white = i.isEven;
    if (i == 4) {
      moves.add(ReviewedMove(
        ply: i,
        san: sanText,
        uci: u,
        fenBefore: fens[i],
        fenAfter: fens[i + 1],
        whiteMoved: white,
        judgement: const MoveJudgement(18, MistakeReason.lostChances),
        depth: 20,
        bestLine: _line(fens[i], bestEval, 'd2d4 e5d4 f3d4'),
        secondLine: _line(fens[i], '+0.40', 'b1c3 g8f6', 2),
        replyLine: _line(fens[i + 1], '+0.20', 'g8f6 d2d3'),
        walkBestUci: 'd2d4',
      ));
    } else if (i == 7) {
      moves.add(ReviewedMove(
        ply: i,
        san: sanText,
        uci: u,
        fenBefore: fens[i],
        fenAfter: fens[i + 1],
        whiteMoved: white,
        judgement: const MoveJudgement(0, null),
        depth: 20,
        bestLine: _line(fens[i], '+0.10', 'f8c5 d2d3'),
        secondLine: _line(fens[i], '+1.80', 'f8e7', 2),
        walkBestUci: 'f8c5',
      ));
    } else {
      moves.add(ReviewedMove(
        ply: i,
        san: sanText,
        uci: u,
        fenBefore: fens[i],
        fenAfter: fens[i + 1],
        whiteMoved: white,
        judgement: const MoveJudgement(0, null),
        depth: 20,
      ));
    }
  }
  return GameReviewResult(moves: moves, reviewDepth: 20);
}

/// White's clocks after each move of a 3+2 game: 11 s after 2. Nf3, 12 s
/// after 3. Bc4 — so Bc4 took 11 − 12 + 2 = 1 second.
const _clocks = <double?>[170, 175, 11, 160, 12, 150, 10, 140];

ReviewWordsRequest _request({GameReviewResult? result}) => reviewWordsRequest(
      result: result ?? _review(),
      mistakePlies: const [4],
      foundPlies: const [7],
      clocks: _clocks,
      timeControl: '180+2',
      opening: 'Italian Game',
    )!;

Map<String, dynamic> _fixture() => jsonDecode(
      File('../docs/gates/review_words_request.json').readAsStringSync(),
    ) as Map<String, dynamic>;

Map<String, String> _fixtureAnswer() {
  final answer = jsonDecode(_fixture()['answer'] as String) as Map;
  return (answer['slots'] as Map).cast<String, String>();
}

void main() {
  group('the request', () {
    test('is the shared fixture, word for word', () {
      final built = _request().toJson();
      expect(jsonEncode(built), jsonEncode(_fixture()['request']));
    });

    test('a found move has no refutation; a mistake has three slots', () {
      final r = _request();
      expect(r.moments.map((m) => m.kind),
          [ReviewMomentKind.mistake, ReviewMomentKind.found]);
      expect(r.moments[0].slots.keys, ['played', 'better', 'refutation']);
      expect(r.moments[1].slots.keys, ['played']);
      expect(r.moments[1].refutation, isEmpty);
    });

    test(
        'the clock is a fact: time left, and the time spent from the '
        'increment', () {
      expect(
          _request().moments[0].facts,
          contains(
              "12 seconds left on White's clock; the move took 1 second."));
      final noControl = reviewWordsRequest(
        result: _review(),
        mistakePlies: const [4],
        foundPlies: const [],
        clocks: _clocks,
      )!;
      expect(noControl.moments[0].facts,
          contains("12 seconds left on White's clock."));
      expect(noControl.moments[0].facts, isNot(contains('took')));
      // A review started two moves into the game reads the clock two places
      // on (`ReviewedGame.clocks` holds every move from the game's start).
      final later = reviewWordsRequest(
        result: _review(),
        mistakePlies: const [4],
        foundPlies: const [],
        clocks: const [300, 300, ..._clocks],
        clockOffset: 2,
        timeControl: '180+2',
      )!;
      expect(
          later.moments[0].facts,
          contains(
              "12 seconds left on White's clock; the move took 1 second."));
    });

    test('the chances are words, never numbers', () {
      final text = jsonEncode(_request().toJson());
      expect(text, isNot(matches(RegExp(r'[+-]\d+\.\d+'))));
      expect(_request().moments[0].facts,
          contains('With the best move, d4, White is slightly better'));
    });

    test(
        'at most ten moments: the mistakes first by chances lost, then the '
        'only moves', () {
      // Twelve mistakes and one only move, on a game long enough to hold
      // them: every white move of a knight dance, each judged a mistake with
      // a loss that grows with its ply.
      const dance = ['g1f3', 'g8f6', 'f3g1', 'f6g8'];
      final board = chess.Chess.fromFEN(_start);
      final moves = <ReviewedMove>[];
      for (var i = 0; i < 28; i++) {
        final u = dance[i % 4];
        final before = board.fen;
        board.move({'from': u.substring(0, 2), 'to': u.substring(2, 4)});
        final mistake = i.isEven && i < 24;
        final found = i == 25;
        moves.add(ReviewedMove(
          ply: i,
          san: board.pgn().split(RegExp(r'\s+')).last,
          uci: u,
          fenBefore: before,
          fenAfter: board.fen,
          whiteMoved: i.isEven,
          judgement: MoveJudgement(
            mistake ? 10.0 + i : 0,
            mistake ? MistakeReason.lostChances : null,
          ),
          bestLine: (mistake || found)
              ? _line(before, '+0.30', mistake ? 'b1c3' : u)
              : null,
        ));
      }
      final result = GameReviewResult(moves: moves, reviewDepth: 20);
      final r = reviewWordsRequest(
        result: result,
        mistakePlies: [for (var i = 0; i < 24; i += 2) i],
        foundPlies: const [25],
      )!;
      expect(r.moments.length, kReviewWordsMoments);
      expect(r.moments.every((m) => m.kind == ReviewMomentKind.mistake), isTrue,
          reason: 'twelve mistakes fill ten places before an only move');
      // The two smallest losses (plies 0 and 2) are the ones left out.
      expect(r.moments.map((m) => m.ply), [for (var i = 4; i < 24; i += 2) i]);
      expect(r.moments.map((m) => m.id), [for (var i = 1; i <= 10; i++) 'm$i']);
    });

    test('no moment, no request', () {
      expect(
        reviewWordsRequest(
          result: _review(),
          mistakePlies: const [],
          foundPlies: const [],
        ),
        isNull,
      );
    });
  });

  group('the claim check, third mode', () {
    test('a text naming only the moment\'s line moves is accepted', () {
      final verdict = judgeReviewWords(_request(), _fixtureAnswer());
      expect(verdict.refused, isEmpty);
      expect(verdict.accepted, 4);
      expect(verdict.byPly[4]!.better, startsWith('d4 opens'));
      expect(verdict.byPly[7]!.played, startsWith('Bc5'));
    });

    test('a move outside the lines is refused, the other slots kept', () {
      final answer = {
        ..._fixtureAnswer(),
        'm1.refutation': 'Nf6 hits e4, and after Qe2 White holds.',
      };
      final verdict = judgeReviewWords(_request(), answer);
      expect(verdict.refused,
          ['m1.refutation names Qe2, a move not in its lines']);
      expect(verdict.byPly[4]!.refutation, isNull);
      expect(verdict.byPly[4]!.played, isNotNull);
      expect(verdict.accepted, 3);
    });

    test('a move of another moment\'s lines is outside this one\'s', () {
      final answer = {'m2.played': 'Bc5, as Nxd4 would have allowed.'};
      final verdict = judgeReviewWords(_request(), answer);
      expect(
          verdict.refused, ['m2.played names Nxd4, a move not in its lines']);
      expect(verdict.byPly, isEmpty);
    });

    test('a win the facts do not hold is refused', () {
      final verdict = judgeReviewWords(
          _request(), {'m1.better': 'd4 wins a pawn by force.'});
      expect(verdict.refused.single, contains('says a move wins'));
    });

    test('the question mode still refuses its answer', () {
      final claims = claimsFor('q', 'Look at Nf3 here.', {
        'question': true,
        'names': ['Nf3', 'f3'],
      });
      expect(claims, contains('q names its answer or its square'));
      final other = claimsFor('q', 'Not Qh5.', {
        'question': true,
        'names': ['Nf3', 'f3'],
      });
      expect(other, contains('q names Qh5, a move that is not the answer'));
    });

    test(
        'without lines, the check stays the tutorial\'s: a named move is '
        'not judged', () {
      expect(claimsFor('s', 'Qe2 was calmer.', {'text': ''}), isEmpty);
    });
  });

  group('the words in the game', () {
    List<AnalysisNode> chainOf(AnalysisNode root) {
      final chain = <AnalysisNode>[];
      var node = root;
      final board = chess.Chess.fromFEN(_start);
      for (final u in _game) {
        board.move({'from': u.substring(0, 2), 'to': u.substring(2, 4)});
        node = node.addChild(
          childFen: board.fen,
          san: board.pgn().split(RegExp(r'\s+')).last,
          uci: u,
        );
        chain.add(node);
      }
      return chain;
    }

    test(
        'on the game\'s move, the better line and the refutation, which is '
        'a line of its own', () {
      final root = AnalysisNode(fen: _start);
      final chain = chainOf(root);
      final verdict = judgeReviewWords(_request(), _fixtureAnswer());
      final marked = GameAnalysisWalkerService().markMistakes(
        chain: chain,
        result: _review(),
        words: verdict.byPly,
        insertRefutation: true,
      );
      expect(marked, 1);
      final bc4 = chain[4];
      expect(bc4.nag, '??');
      expect(bc4.comment, 'Bc4 lets Black gain time against e4.');
      final better = chain[3].children.firstWhere((c) => c.moveSan == 'd4');
      expect(better.comment,
          'Better move. d4 opens the centre while Black is still developing.');
      expect(better.nag, '!');
      // The refutation's first move is the game's own reply here (3...Nf6):
      // the words go on it, it is not labelled a line beside itself, and the
      // game's main line is unchanged.
      expect(identical(bc4.children.first, chain[5]), isTrue);
      expect(chain[5].comment,
          'Nf6 hits e4, and White has to defend instead of attack.');
      expect(chain[5].nag, isNot('!'));
      expect(chain[7].comment, startsWith('Bc5 develops'));
    });

    test(
        'a refutation the game did not play is inserted beside it, after '
        'the game\'s own reply', () {
      final root = AnalysisNode(fen: _start);
      final chain = chainOf(root);
      final fens = _fens();
      final review = _review();
      final moves = [...review.moves];
      moves[4] = ReviewedMove(
        ply: 4,
        san: 'Bc4',
        uci: 'f1c4',
        fenBefore: fens[4],
        fenAfter: fens[5],
        whiteMoved: true,
        judgement: const MoveJudgement(18, MistakeReason.lostChances),
        bestLine: _line(fens[4], '+0.60', 'd2d4 e5d4 f3d4'),
        replyLine: _line(fens[5], '+0.20', 'd7d5 e4d5'),
      );
      GameAnalysisWalkerService().markMistakes(
        chain: chain,
        result: GameReviewResult(moves: moves, reviewDepth: 20),
        words: {4: const MomentWords(refutation: 'd5 opens the centre.')},
        insertRefutation: true,
      );
      final bc4 = chain[4];
      expect(bc4.children.first, same(chain[5]), reason: 'the game goes on');
      final refutation = bc4.children[1];
      expect(refutation.moveSan, 'd5');
      expect(refutation.comment, 'Refutation. d5 opens the centre.');
      expect(refutation.children.single.moveSan, 'exd5');
    });

    test('a comment already there survives a review', () {
      final root = AnalysisNode(fen: _start);
      final chain = chainOf(root);
      chain[4].comment = 'My own note.';
      chain[7].comment = 'Mine too.';
      // The owner's own sideline with the better move, commented.
      final fens = _fens();
      final board = chess.Chess.fromFEN(fens[4])..move('d4');
      chain[3].addChild(childFen: board.fen, san: 'd4', uci: 'd2d4').comment =
          'My line.';
      final verdict = judgeReviewWords(_request(), _fixtureAnswer());
      GameAnalysisWalkerService().markMistakes(
        chain: chain,
        result: _review(),
        words: verdict.byPly,
        insertRefutation: true,
      );
      expect(chain[4].comment, 'My own note.');
      expect(chain[7].comment, 'Mine too.');
      final d4 = chain[3].children.firstWhere((c) => c.moveSan == 'd4');
      expect(d4.comment, 'My line.');
    });

    test('without the box, no refutation line and no words', () {
      final root = AnalysisNode(fen: _start);
      final chain = chainOf(root);
      final fens = _fens();
      final moves = [..._review().moves];
      moves[4] = ReviewedMove(
        ply: 4,
        san: 'Bc4',
        uci: 'f1c4',
        fenBefore: fens[4],
        fenAfter: fens[5],
        whiteMoved: true,
        judgement: const MoveJudgement(18, MistakeReason.lostChances),
        bestLine: _line(fens[4], '+0.60', 'd2d4 e5d4 f3d4'),
        replyLine: _line(fens[5], '+0.20', 'd7d5 e4d5'),
      );
      GameAnalysisWalkerService().markMistakes(
        chain: chain,
        result: GameReviewResult(moves: moves, reviewDepth: 20),
      );
      expect(chain[4].children.length, 1);
      expect(chain[4].comment, isEmpty);
      final better = chain[3].children.firstWhere((c) => c.moveSan == 'd4');
      expect(better.comment, 'Better move');
    });
  });

  group('the words in the puzzles', () {
    test(
        'a mistake explains the answer, then the game\'s move; a found '
        'move, itself', () {
      final verdict = judgeReviewWords(_request(), _fixtureAnswer());
      expect(
        puzzleWordsOf(verdict.byPly[4], ReviewMomentKind.mistake),
        'd4 opens the centre while Black is still developing. '
        'Bc4 lets Black gain time against e4.',
      );
      expect(puzzleWordsOf(verdict.byPly[7], ReviewMomentKind.found),
          startsWith('Bc5 develops'));
      expect(puzzleWordsOf(null, ReviewMomentKind.found), isNull);
    });

    test('a kept puzzle sends its words, and none when it has none', () {
      final fens = _fens();
      final p = LocalPuzzle(
        id: 'mistake_4',
        kind: PuzzleKind.mistake,
        fen: fens[4],
        sourcePlyIndex: 4,
        playedSan: 'Bc4',
        playedUci: 'f1c4',
        answers: const ['d4'],
        bestLine: const ['d4', 'exd4', 'Nxd4'],
        refutationLine: const ['Nf6', 'd3'],
        bestChances: 60,
        playedChances: 42,
      );
      expect(puzzleExerciseDraft(p, name: 'G')!.review!.containsKey('words'),
          isFalse);
      final withWords = p.withWords('d4 opens the centre.');
      expect(puzzleExerciseDraft(withWords, name: 'G')!.review!['words'],
          'd4 opens the centre.');
    });
  });
}
