// The review belongs to the app, not to the dialog —
// docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, phase 1.2b.
//
// Until 1.2b the whole-game review ran inside its dialog: the dialog held the
// walk, a barrier tap was blocked so the walk would not be lost, and the marks
// were written into the nodes of the Analysis screen that opened it. On the
// phone the review takes some fifteen minutes (phase 0), so the owner decided
// on 24.9.2026 that it runs in the background: started from the dialog, it
// then belongs to the app. The result lands on the *game* — whichever live
// board holds it when the run ends, else the one-slot draft if it still holds
// that game — found by its moves, not by the nodes of a screen that may be
// gone; a sign-out in the middle stops it; the engine is held from the first
// search to the last.
//
// The engine answers by position (White's winning chances, as the judge's own
// test speaks), the book and the tablebase answer nothing, so every case says
// exactly what the judge sees.

import 'dart:async';
import 'dart:math' as math;

import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/eval_cache.dart';
import 'package:chess_app/core/services/game_analysis_walker_service.dart';
import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_draft_service.dart';
import 'package:chess_app/features/analysis_studio/services/game_from_moves.dart';
import 'package:chess_app/features/analysis_studio/services/game_review_runner.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/masters_walk.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/account_local_state.dart';
import 'package:chess_app/services/stockfish_service.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// 1.e4 e5 2.Nf3 Nc6 3.Bc4 Nf6 — White moves at plies 0, 2 and 4, Black at
/// 1, 3 and 5. Thirty-two men: the tablebase is never asked.
const _italian = ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6'];

/// 1.d4 d5 — another game, for a draft or a board that holds something else.
const _queensPawn = ['d2d4', 'd7d5'];

/// White's winning chances [w] as the evaluation the app spells, from White's
/// side — the same helper the judge's own test speaks in.
String c(double w) {
  final cp = (-math.log(100 / w - 1) / 0.00368208).round();
  final pawns = cp / 100;
  return pawns >= 0 ? '+${pawns.toStringAsFixed(2)}' : pawns.toStringAsFixed(2);
}

class _Game {
  _Game(this.start, this.ucis) {
    fens.add(start);
    final game = chess.Chess.fromFEN(start);
    for (final u in ucis) {
      final ok = game.move({
        'from': u.substring(0, 2),
        'to': u.substring(2, 4),
      });
      if (!ok) throw StateError('not a legal move: $u');
      fens.add(game.fen);
    }
  }

  final String start;
  final List<String> ucis;
  final List<String> fens = [];

  List<String> otherMoves(int i) => [
        for (final m in legalMoves(chess.Chess.fromFEN(fens[i])))
          '${m['from']}${m['to']}${m['promotion'] ?? ''}',
      ].where((u) => i >= ucis.length || u != ucis[i]).toList();
}

/// The engine as the review sees it: answers position i of [game] at White's
/// chances [chances][i], the move played there searched alone at what the next
/// position is worth. Every question, hold and release goes into [log], in
/// order.
class _Engine implements StockfishService {
  _Engine(this.game, this.whiteChances)
      : value = [for (final w in whiteChances) c(w)];

  final _Game game;

  /// White's winning chances at each position — kept alongside [value] (the
  /// formatted string) so a second line can be built at an exact gap below
  /// the first, for the side actually to move there.
  final List<double> whiteChances;
  final List<String> value;
  final List<String> log = [];

  /// Called with the position's index before it is answered.
  void Function(int i)? onAsk;

  List<String> get asked => log.where((e) => e.startsWith('p')).toList();

  @override
  Future<List<AnalysisLine>> analyzePositionSync(
    String fen, {
    required int depth,
    required int multiPV,
    List<String>? searchMoves,
    Duration timeout = const Duration(seconds: 10),
    void Function(List<AnalysisLine> partial)? onProgress,
  }) async {
    final i = game.fens.indexOf(fen);
    if (i < 0) throw StateError('asked about a position not in the game');
    log.add('p$i d$depth pv$multiPV${searchMoves == null ? '' : ' only'}');
    onAsk?.call(i);
    AnalysisLine line(int pv, String evaluation, String uci) =>
        AnalysisLine.fromPv(
          multipv: pv,
          depth: depth,
          eval: evaluation,
          pvString: uci,
          startingFen: fen,
        );
    if (searchMoves != null) {
      return [line(1, value[i + 1], searchMoves.first)];
    }
    final others = game.otherMoves(i);
    // Phase 1.3 (docs/PLAN-ZAGONETKE-IZ-PARTIJE.md): a puzzle needs the
    // second line at least `kStandsOut` chances below the first, for the
    // side to move — the same value as the first (as this used to answer)
    // finds no puzzle at all under `B`, which is the expected red, not a bug
    // in the rule. 20 chances below, for whoever is to move at [i]: White's
    // own chances shift by −20 there, Black's by the mirrored +20.
    final secondWhite = (i.isEven ? whiteChances[i] - 20 : whiteChances[i] + 20)
        .clamp(1.0, 99.0);
    return [
      line(1, value[i], others.first),
      if (multiPV >= 2 && others.length > 1) line(2, c(secondWhite), others[1]),
    ];
  }

  /// No name: the store keeps these answers in memory, for this run only.
  @override
  Future<String?> answerStoreName() async => null;

  @override
  void hold(Object owner) => log.add('hold');

  @override
  void release(Object owner) => log.add('release');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<MastersWalk> _noBook(List<String> fens) async =>
    (known: const <String, Map<String, dynamic>>{}, unavailable: null);

/// A live board: the tree a screen holds, and how often it was told the
/// review landed on it.
class _Board implements ReviewBoard {
  _Board(this.reviewRoot);

  @override
  final AnalysisNode reviewRoot;

  int landed = 0;

  @override
  void reviewLanded() => landed++;
}

AnalysisNode _tree(List<String> ucis) =>
    analysisTreeFromMoves(_start, ucis).root;

/// The node of the move played at [ply] on the main line.
AnalysisNode _moveAt(AnalysisNode root, int ply) {
  var node = root;
  for (var i = 0; i <= ply; i++) {
    node = node.children.first;
  }
  return node;
}

List<String?> _nags(AnalysisNode root) {
  final out = <String?>[];
  var node = root;
  while (node.children.isNotEmpty) {
    node = node.children.first;
    out.add(node.nag);
  }
  return out;
}

bool _anyNag(AnalysisNode node) =>
    node.nag != null || node.children.any(_anyNag);

/// White errs at ply 4 (50 → 20: thirty chances); Black at ply 5 (Black's 80
/// → 40: forty). Every other move keeps the balance.
const _twoMistakes = <double>[50, 50, 50, 50, 50, 20, 60];

GameReviewRunner _runner() =>
    GameReviewRunner(book: _noBook, tablebase: (_) async => null);

void main() {
  // A sign-out's wipe reaches path_provider; with the binding up that is a
  // missing plugin, caught, rather than an error thrown out of the wipe.
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Game italian;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EvalCache.instance.clear();
    italian = _Game(_start, _italian);
  });

  group('where the result lands', () {
    test(
      'the review runs with no screen, and lands on the board that holds '
      'the game — found by its moves, not by the nodes it was started on',
      () async {
        final runner = _runner();
        final shown = _tree(_italian);
        final board = _Board(shown);
        runner.attachBoard(board);
        addTearDown(() => runner.detachBoard(board));

        // Started on a copy: the screen that started it is not the one it
        // lands on.
        final startedOn = _tree(_italian);
        final run = runner.start(
          root: startedOn,
          start: startedOn,
          options: const ReviewOptions(depth: 20, markMistakes: true),
          engine: _Engine(italian, _twoMistakes),
        );
        await run.finished;

        expect(run.status, ReviewRunStatus.done);
        expect(run.landing, ReviewLanding.onBoard);
        expect(board.landed, 1);
        expect(_nags(shown), [null, null, null, null, '??', '??']);
        expect(run.marked, 2);
        // The better move beside the mistake, as Blunder Alert always did.
        final parent = _moveAt(shown, 3);
        expect(parent.children, hasLength(2));
        expect(parent.children[1].nag, '!');
      },
    );

    test(
      'with no board, the draft that holds the game takes the marks',
      () async {
        final runner = _runner();
        final root = _tree(_italian);
        await AnalysisDraftService.instance.flush(
          rootNode: root,
          currentNode: _moveAt(root, 1),
          blackOrientation: true,
          epoch: AccountLocalState.epoch,
        );

        final run = runner.start(
          root: root,
          start: root,
          options: const ReviewOptions(depth: 20, markMistakes: true),
          engine: _Engine(italian, _twoMistakes),
        );
        await run.finished;

        expect(run.landing, ReviewLanding.inDraft);
        final draft = await AnalysisDraftService.instance.load();
        expect(_nags(draft!.rootNode), [null, null, null, null, '??', '??']);
        expect(
          draft.blackOrientation,
          isTrue,
          reason: 'the draft is the reader\'s, not only its moves',
        );
        expect(draft.resolveCurrentNode().fen, italian.fens[2]);
      },
    );

    test(
      'a draft that holds another game is left alone, and it is said',
      () async {
        final runner = _runner();
        final other = _tree(_queensPawn);
        await AnalysisDraftService.instance.flush(
          rootNode: other,
          currentNode: other,
          blackOrientation: false,
          epoch: AccountLocalState.epoch,
        );

        final root = _tree(_italian);
        final run = runner.start(
          root: root,
          start: root,
          options: const ReviewOptions(depth: 20, markMistakes: true),
          engine: _Engine(italian, _twoMistakes),
        );
        await run.finished;

        expect(run.landing, ReviewLanding.notLanded);
        final draft = await AnalysisDraftService.instance.load();
        expect(_anyNag(draft!.rootNode), isFalse);
        expect(draft.rootNode.children.single.moveUci, 'd2d4');
      },
    );

    test('a board that lost the moves does not take the marks', () async {
      final runner = _runner();
      // The reader deleted the last two moves while the review ran.
      final shown = _tree(_italian.sublist(0, 4));
      final board = _Board(shown);
      runner.attachBoard(board);
      addTearDown(() => runner.detachBoard(board));

      final root = _tree(_italian);
      final run = runner.start(
        root: root,
        start: root,
        options: const ReviewOptions(depth: 20, markMistakes: true),
        engine: _Engine(italian, _twoMistakes),
      );
      await run.finished;

      expect(run.landing, ReviewLanding.notLanded);
      expect(board.landed, 0);
      expect(_anyNag(shown), isFalse);
    });

    test(
        'a live board owns the draft: with a board attached the draft is '
        'never written, even when it still holds the game', () async {
      final runner = _runner();
      final saved = _tree(_italian);
      await AnalysisDraftService.instance.flush(
        rootNode: saved,
        currentNode: saved,
        blackOrientation: false,
        epoch: AccountLocalState.epoch,
      );
      // The board has moved on to another game; its own save will overwrite
      // the draft, so marks written there would be lost and called landed.
      final board = _Board(_tree(_queensPawn));
      runner.attachBoard(board);
      addTearDown(() => runner.detachBoard(board));

      final run = runner.start(
        root: saved,
        start: saved,
        options: const ReviewOptions(depth: 20, markMistakes: true),
        engine: _Engine(italian, _twoMistakes),
      );
      await run.finished;

      expect(run.landing, ReviewLanding.notLanded);
      final draft = await AnalysisDraftService.instance.load();
      expect(_anyNag(draft!.rootNode), isFalse);
    });

    test(
      'reviewed from a position forward, only those moves are judged',
      () async {
        final runner = _runner();
        final shown = _tree(_italian);
        final board = _Board(shown);
        runner.attachBoard(board);
        addTearDown(() => runner.detachBoard(board));

        final engine = _Engine(italian, _twoMistakes);
        final run = runner.start(
          root: shown,
          start: _moveAt(shown, 4), // after 3.Bc4: only 3...Nf6 is reviewed
          options: const ReviewOptions(depth: 20, markMistakes: true),
          engine: engine,
        );
        await run.finished;

        expect(run.result!.moves, hasLength(1));
        expect(_nags(shown), [null, null, null, null, null, '??']);
        expect(
          engine.asked.where((a) => a.startsWith('p4 ')),
          isEmpty,
          reason: 'a position before the start was searched',
        );
      },
    );
  });

  group('what is left, and for whom', () {
    test('only the side chosen is marked', () async {
      for (final (side, expected) in [
        (BlunderAlertSide.white, [null, null, null, null, '??', null]),
        (BlunderAlertSide.black, [null, null, null, null, null, '??']),
      ]) {
        EvalCache.instance.clear();
        final runner = _runner();
        final shown = _tree(_italian);
        final board = _Board(shown);
        runner.attachBoard(board);
        final run = runner.start(
          root: shown,
          start: shown,
          options: ReviewOptions(depth: 20, markMistakes: true, side: side),
          engine: _Engine(italian, _twoMistakes),
        );
        await run.finished;
        runner.detachBoard(board);
        expect(_nags(shown), expected, reason: '$side');
        expect(run.marked, 1, reason: '$side');
      }
    });

    test(
      'without Blunder Alert nothing is marked; puzzles only when asked',
      () async {
        final runner = _runner();
        final shown = _tree(_italian);
        final board = _Board(shown);
        runner.attachBoard(board);
        addTearDown(() => runner.detachBoard(board));

        final run = runner.start(
          root: shown,
          start: shown,
          options: const ReviewOptions(depth: 20, findPuzzles: true),
          engine: _Engine(italian, _twoMistakes),
        );
        await run.finished;

        expect(_anyNag(shown), isFalse);
        expect(board.landed, 0, reason: 'nothing was asked to land');
        expect(run.puzzles, hasLength(2));
        // Worst first: Black's forty before White's thirty.
        expect(run.puzzles.first.sourcePlyIndex, 5);

        runner.dismiss();
        EvalCache.instance.clear();
        final capped = runner.start(
          root: shown,
          start: shown,
          options: const ReviewOptions(
            depth: 20,
            markMistakes: true,
            findPuzzles: true,
            maxPuzzles: 1,
          ),
          engine: _Engine(italian, _twoMistakes),
        );
        await capped.finished;
        expect(capped.puzzles.single.sourcePlyIndex, 5);

        runner.dismiss();
        EvalCache.instance.clear();
        final none = runner.start(
          root: shown,
          start: shown,
          options: const ReviewOptions(depth: 20, markMistakes: true),
          engine: _Engine(italian, _twoMistakes),
        );
        await none.finished;
        expect(none.puzzles, isEmpty);
      },
    );
  });

  group('the run itself', () {
    test(
      'the engine is held before the first search and let go after the last',
      () async {
        final runner = _runner();
        final root = _tree(_italian);
        final engine = _Engine(italian, _twoMistakes);
        final run = runner.start(
          root: root,
          start: root,
          options: const ReviewOptions(depth: 20, markMistakes: true),
          engine: engine,
        );
        await run.finished;

        expect(engine.log.first, 'hold');
        expect(engine.log.last, 'release');
        expect(engine.log.where((e) => e == 'hold'), hasLength(1));
        expect(engine.log.where((e) => e == 'release'), hasLength(1));
      },
    );

    test(
      'stopped, it lets the engine go and leaves nothing on the game',
      () async {
        final runner = _runner();
        final shown = _tree(_italian);
        final board = _Board(shown);
        runner.attachBoard(board);
        addTearDown(() => runner.detachBoard(board));

        final engine = _Engine(italian, _twoMistakes);
        engine.onAsk = (i) {
          if (i == 3) runner.cancel();
        };
        final run = runner.start(
          root: shown,
          start: shown,
          options: const ReviewOptions(depth: 20, markMistakes: true),
          engine: engine,
        );
        await run.finished;

        expect(run.status, ReviewRunStatus.cancelled);
        expect(engine.log.last, 'release');
        expect(board.landed, 0);
        expect(_anyNag(shown), isFalse);
      },
    );

    test(
      'a sign-out in the middle stops the review, and nothing lands',
      () async {
        final runner = _runner();
        final shown = _tree(_italian);
        final board = _Board(shown);
        runner.attachBoard(board);
        addTearDown(() => runner.detachBoard(board));

        final engine = _Engine(italian, _twoMistakes);
        engine.onAsk = (i) {
          // The wipe raises the epoch at once; what it clears follows.
          if (i == 3) unawaited(AccountLocalState.clear());
        };
        final run = runner.start(
          root: shown,
          start: shown,
          options: const ReviewOptions(depth: 20, markMistakes: true),
          engine: engine,
        );
        await run.finished;

        expect(run.status, ReviewRunStatus.cancelled);
        expect(board.landed, 0);
        expect(_anyNag(shown), isFalse);
        expect(engine.log.last, 'release');
        expect(
          engine.asked.where((a) => a.startsWith('p6 ')),
          isEmpty,
          reason: 'the walk went on after the account was gone',
        );
      },
    );

    test('one review at a time', () async {
      final runner = _runner();
      final root = _tree(_italian);
      final engine = _Engine(italian, _twoMistakes);
      final first = runner.start(
        root: root,
        start: root,
        options: const ReviewOptions(depth: 20, markMistakes: true),
        engine: engine,
      );
      expect(runner.isRunning, isTrue);
      expect(
        () => runner.start(
          root: root,
          start: root,
          options: const ReviewOptions(depth: 20, markMistakes: true),
          engine: engine,
        ),
        throwsStateError,
      );
      await first.finished;
      expect(runner.isRunning, isFalse);
      expect(
        runner.current,
        same(first),
        reason: 'a finished run stays until it is dismissed',
      );

      final second = runner.start(
        root: root,
        start: root,
        options: const ReviewOptions(depth: 20, markMistakes: true),
        engine: engine,
      );
      await second.finished;
      expect(runner.current, same(second));
      runner.dismiss();
      expect(runner.current, isNull);
    });

    test(
        'started again, it asks the engine nothing it already answered, and '
        'counts what came from the store', () async {
      final runner = _runner();
      final root = _tree(_italian);
      final engine = _Engine(italian, _twoMistakes);
      final first = runner.start(
        root: root,
        start: root,
        options: const ReviewOptions(depth: 20, markMistakes: true),
        engine: engine,
      );
      await first.finished;
      expect(first.tally.searched, greaterThan(0));
      final askedFirst = engine.asked.length;

      runner.dismiss();
      final second = runner.start(
        root: root,
        start: root,
        options: const ReviewOptions(depth: 20, markMistakes: true),
        engine: engine,
      );
      await second.finished;
      expect(
        engine.asked.length,
        askedFirst,
        reason: 'a stopped review resumes; it does not start again',
      );
      expect(second.tally.searched, 0);
      expect(second.tally.fromStore, greaterThanOrEqualTo(7));
    });
  });
}
