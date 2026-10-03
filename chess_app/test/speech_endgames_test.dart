// Phase 4b's gate — `docs/PLAN-GOVOR-IZ-KLIPOVA.md`: the endgame trainer (solve
// mode and the „play to the end" drill) and the blunder walk speak the table
// the owner approved on 3.10.2026 through `SpeechService.speakLine`, and what
// they speak is what they draw (D4). The Hint is gone from both.
//
// Modelled on `speech_tactics_test.dart`: the screens are the real ones, the
// server is a fake service (nothing here is about the wire), and the voice is
// a fake `ClipVoice` that records the `SpokenLine`s it was handed, so the
// cases assert **token ids**, not bytes.
//
// The drawn text is each line's `.text` — `SpokenLine` writes the capital and
// closes a run on a cut token that ends a sentence — with one hand-drawn
// exception: a list of moves is drawn with commas, which the clips have no
// word for.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/speech/clip_voice.dart';
import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/features/endgame_trainer/models/endgame_puzzle.dart';
import 'package:chess_app/features/endgame_trainer/screens/blunder_walk_screen.dart';
import 'package:chess_app/features/endgame_trainer/screens/endgame_trainer_screen.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

UserSession _session() => UserSession(
    token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik');

// ── fakes ────────────────────────────────────────────────────────────────

/// The device voice, which only remembers what it was told.
class _Tts implements TtsEngine {
  final List<String> said = [];

  @override
  Future<List<String>> languages() async => const ['en-US'];
  @override
  Future<void> setLanguage(String language) async {}
  @override
  Future<void> setSpeechRate(double rate) async {}
  @override
  Future<void> speak(String text) async => said.add(text);
  @override
  Future<void> stop() async {}
}

/// A clip voice that records the lines it was asked to speak.
class _FakeClipVoice extends ClipVoice {
  _FakeClipVoice();

  final List<SpokenLine> lines = [];

  /// When set, `speak` throws it — a voice that cannot play.
  Object? throwOnSpeak;

  List<String> get said =>
      [for (final l in lines) l.tokens.map((t) => t.id).join(' ')];

  @override
  Future<void> load(AssetBundle bundle) async {}

  @override
  Future<void> speak(SpokenLine line) {
    lines.add(line);
    final error = throwOnSpeak;
    if (error != null) throw error;
    return Future<void>.value();
  }

  @override
  Future<void> stop() async {}
}

/// The service, counting the stops it is asked for.
class _CountingSpeech extends SpeechService {
  _CountingSpeech(super.engine) : super.forSubclass();

  int stopCalls = 0;
  int forgetCalls = 0;

  @override
  Future<void> stop() {
    stopCalls++;
    return super.stop();
  }

  @override
  void forget() {
    forgetCalls++;
    super.forget();
  }
}

class _Rig {
  _Rig(this.speech, this.voice, this.tts);

  final _CountingSpeech speech;
  final _FakeClipVoice voice;
  final _Tts tts;
}

Future<_Rig> _rig({bool enabled = true}) async {
  final tts = _Tts();
  final voice = _FakeClipVoice();
  final speech = _CountingSpeech(tts);
  await speech.init(enabled: enabled, rate: 0.5, engine: tts, clipVoice: voice);
  final settings = AppSettingsService.instance;
  await settings.init();
  await settings.setSpeechEnabled(enabled);
  return _Rig(speech, voice, tts);
}

/// Serves one position, answers the drill from a queue, and reads the tables
/// as it is told to.
class _Api extends EndgameApiService {
  _Api(this.puzzle) : super(authToken: '');

  final EndgamePuzzle puzzle;

  /// What `judgeDrillMove` answers, one per call. Empty answers „the
  /// tablebase did not answer" — which is also what a solve-mode reply
  /// request gets, and a reply that never comes costs only the reply.
  final List<DrillJudgeResult> judged = [];

  /// When set, `judgeDrillMove` waits for it.
  Completer<void>? judgeGate;

  TablebaseReadout? readout;

  @override
  Future<EndgameFetchResult> fetchNext({
    EndgameMode? mode,
    String? excludeId,
    String? material,
    String? band,
    bool oppositeOnly = false,
    bool includeOnline = false,
  }) async =>
      EndgameFetchResult(EndgameFetchOutcome.ok, puzzle);

  @override
  Future<DrillJudgeResult> judgeDrillMove({
    required String fen,
    required String move,
  }) async {
    final gate = judgeGate;
    if (gate != null) await gate.future;
    if (judged.isEmpty) {
      return const DrillJudgeResult(DrillJudgeOutcome.unavailable);
    }
    return judged.removeAt(0);
  }

  @override
  Future<TablebaseReadout?> fetchReadout({
    required String fen,
    required EndgameMode goal,
  }) async =>
      readout;

  @override
  Future<bool> keepForLater({
    required String fen,
    required String title,
    required String description,
  }) async =>
      true;
}

// ── the positions ────────────────────────────────────────────────────────

EndgamePuzzle _puzzle({
  required String fen,
  required String mode,
  required List<String> winning,
  String source = 'syzygy',
  String? played,
  String id = 'eg_speech',
}) =>
    EndgamePuzzle.fromJson({
      'puzzle_id': id,
      'fen': fen,
      'type': 'KPvKP',
      'mode': mode,
      'winning_moves': winning,
      'piece_count': 4,
      'source': source,
      'difficulty': 'medium',
      if (played != null) 'played_move': played,
    });

/// White to keep the win: Kd2, Kf1 and the underpromotion e8=N hold.
EndgamePuzzle _win({
  List<String> winning = const ['e1d2', 'e1f1', 'e7e8n'],
  String? played = 'Kd1',
  String source = 'syzygy',
}) =>
    _puzzle(
      fen: '8/4P3/8/8/8/8/1p6/4K2k w - - 0 1',
      mode: 'win',
      winning: winning,
      played: played,
      source: source,
    );

/// Black to hold the draw: Re1 and Rf1 hold.
EndgamePuzzle _draw({String? played = 'Kg6'}) => _puzzle(
      fen: '8/5pk1/8/8/8/8/5PK1/r7 b - - 0 55',
      mode: 'draw',
      winning: const ['a1f1', 'a1e1'],
      played: played,
    );

/// A draw with no pawns: the one whose „Conclude draw" is offered.
EndgamePuzzle _pawnless() => _puzzle(
      fen: '1r4k1/8/8/8/8/8/8/1R4K1 b - - 0 1',
      mode: 'draw',
      winning: const ['b8a8', 'b8c8'],
    );

DrillJudgeResult _step({
  required bool held,
  String goal = 'win',
  String outcome = 'win',
  String san = 'Kd2',
  String uci = 'e1d2',
  String fen = '8/5pk1/8/8/8/8/5PK1/4r3 w - - 1 56',
  String? replyUci,
  String? finished,
}) =>
    DrillJudgeResult(
      DrillJudgeOutcome.ok,
      step: DrillStep(
        held: held,
        goal: goal,
        outcome: outcome,
        playedSan: san,
        playedUci: uci,
        fen: fen,
        replyUci: replyUci,
        replySan: replyUci == null ? null : 'x',
        finished: finished,
      ),
    );

// ── driving the trainer ──────────────────────────────────────────────────

Future<void> _pumpTrainer(
  WidgetTester tester,
  _Rig rig,
  _Api api, {
  Size size = const Size(1200, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: EndgameTrainerScreen(
      key: UniqueKey(),
      session: _session(),
      api: api,
      speech: rig.speech,
    ),
  ));
  await tester.pumpAndSettle();
}

/// Leaves the screen, so its timers are gone before the test ends.
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 6));
}

Offset _at(WidgetTester tester, String name) {
  final board = find.byType(ChessBoardWithOverlay);
  final widget = tester.widget<ChessBoardWithOverlay>(board);
  final rect = tester.getRect(board);
  final square = widget.boardSize / 8;
  final file = name.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = name.codeUnitAt(1) - '1'.codeUnitAt(0);
  final black = widget.boardOrientation == PlayerColor.black;
  final col = black ? 7 - file : file;
  final row = black ? rank : 7 - rank;
  return rect.topLeft + Offset((col + 0.5) * square, (row + 0.5) * square);
}

Future<void> _play(WidgetTester tester, String from, String to) async {
  await tester.tapAt(_at(tester, from));
  await tester.pumpAndSettle();
  await tester.tapAt(_at(tester, to));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// What the voice was asked to say since [from].
List<String> _since(_Rig rig, int from) => rig.voice.said.sublist(from);

/// The source of [path] with its `//` comment lines taken out, so a word the
/// code explains is not mistaken for a word the code uses.
String _code(String path) => File(path)
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

const _taskWinWhite = 'white_to_move keep_the_win';
const _storyWin =
    'in_the_game_white_played piece_king sq_d1 and_dropped_the_win';
const _taskDrawBlack = 'black_to_move hold_the_draw';
const _storyDraw =
    'in_the_game_black_played piece_king sq_g6 and_lost_the_draw';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── 1. a position appears ──────────────────────────────────────────────

  group('solving: a position appears', () {
    testWidgets(
        'the task and then the story are said, and drawn from the lines they '
        'were said from (D4)', (tester) async {
      final rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_win()));
      expect(rig.voice.said, [_taskWinWhite, _storyWin]);
      expect(rig.voice.lines.first.text, 'White to move. Keep the win.');
      expect(find.text(rig.voice.lines.first.text), findsOneWidget);
      expect(
          find.text('In the game, White played king d1 and dropped the win.'),
          findsOneWidget);
      // No dash in anything drawn: the old „to move — keep the win".
      expect(find.textContaining('—'), findsNothing);
      expect(rig.tts.said, isEmpty);
      await _leave(tester);
    });

    testWidgets('a draw is said as a draw, from Black\'s side', (tester) async {
      final rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_draw()));
      expect(rig.voice.said, [_taskDrawBlack, _storyDraw]);
      expect(find.text('Black to move. Hold the draw.'), findsOneWidget);
      expect(find.text('In the game, Black played king g6 and lost the draw.'),
          findsOneWidget);
      await _leave(tester);
    });

    testWidgets('a position that came from no game has no story',
        (tester) async {
      final rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_win(played: null)));
      expect(rig.voice.said, [_taskWinWhite]);
      expect(find.textContaining('In the game'), findsNothing);
      await _leave(tester);
    });

    testWidgets('the next position is said again, in the same words',
        (tester) async {
      final rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_win()));
      expect(rig.voice.said, hasLength(2));
      final forgot = rig.speech.forgetCalls;
      await _tap(tester, 'Skip');
      expect(rig.speech.forgetCalls, greaterThan(forgot));
      expect(
          rig.voice.said, [_taskWinWhite, _storyWin, _taskWinWhite, _storyWin]);
      await _leave(tester);
    });
  });

  // ── 2. the verdicts ────────────────────────────────────────────────────

  group('solving: the verdicts', () {
    testWidgets('a right move with others left says how many', (tester) async {
      final rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_win()));
      final before = rig.voice.lines.length;
      await _play(tester, 'e1', 'd2');
      // One line: the verdict and the count together, so the opponent's reply
      // — which comes from the server a moment later — finds the voice's one
      // waiting place free.
      expect(_since(rig, before), ['correct_win_kept other_moves_to_find n_2']);
      expect(rig.voice.lines.last.text,
          'Correct. The win is kept. Other moves to find: 2.');
      expect(find.text('Correct. The win is kept. Other moves to find: 2.'),
          findsOneWidget);
      expect(find.textContaining('—'), findsNothing);
      await _leave(tester);
    });

    testWidgets('the last move left says you found every one', (tester) async {
      final rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_draw()));
      await _play(tester, 'a1', 'f1');
      expect(find.text('Correct. The draw is held. Other moves to find: 1.'),
          findsOneWidget);
      await _tap(tester, 'Find the rest (1/2)');
      final before = rig.voice.lines.length;
      await _play(tester, 'a1', 'e1');
      expect(_since(rig, before), ['correct_draw_held found_every_move']);
      expect(
          find.text('Correct. The draw is held. You found every move that '
              'holds.'),
          findsOneWidget);
      await _leave(tester);
    });

    testWidgets('the only move says so', (tester) async {
      final rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_win(winning: const ['e1d2'])));
      final before = rig.voice.lines.length;
      await _play(tester, 'e1', 'd2');
      expect(_since(rig, before), ['correct_win_kept only_move']);
      expect(find.text('Correct. The win is kept. That was the only move.'),
          findsOneWidget);
      await _leave(tester);
    });

    testWidgets('a wrong move, judged exactly: the win and the draw',
        (tester) async {
      var rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_win()));
      var before = rig.voice.lines.length;
      await _play(tester, 'e1', 'e2');
      expect(_since(rig, before), ['wrong_drops_win']);
      expect(
          find.text('That move drops the win. Try another.'), findsOneWidget);
      await _leave(tester);

      rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_draw()));
      before = rig.voice.lines.length;
      await _play(tester, 'g7', 'g6');
      expect(_since(rig, before), ['wrong_loses_draw']);
      expect(
          find.text('That move loses the draw. Try another.'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('a wrong move, judged by the engine: it says so',
        (tester) async {
      var rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_win(source: 'engine')));
      var before = rig.voice.lines.length;
      await _play(tester, 'e1', 'e2');
      expect(_since(rig, before), ['engine_drops_win']);
      expect(
          find.text('The engine judges that this move drops the win. '
              'Try another.'),
          findsOneWidget);
      await _leave(tester);

      rig = await _rig();
      final draw = EndgamePuzzle.fromJson({
        'puzzle_id': 'eg_engine_draw',
        'type': 'KPvKP',
        'fen': '8/5pk1/8/8/8/8/5PK1/r7 b - - 0 55',
        'mode': 'draw',
        'winning_moves': ['a1f1', 'a1e1'],
        'piece_count': 4,
        'source': 'engine',
      });
      await _pumpTrainer(tester, rig, _Api(draw));
      before = rig.voice.lines.length;
      await _play(tester, 'g7', 'g6');
      expect(_since(rig, before), ['engine_loses_draw']);
      await _leave(tester);
    });

    testWidgets('a move already found is said to be', (tester) async {
      final rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_draw()));
      await _play(tester, 'a1', 'f1');
      await _tap(tester, 'Find the rest (1/2)');
      final before = rig.voice.lines.length;
      await _play(tester, 'a1', 'f1');
      expect(_since(rig, before), ['already_found']);
      expect(find.text('You already found that move. Look for another.'),
          findsOneWidget);
      await _leave(tester);
    });

    testWidgets(
        'back after a wrong move in the drill: Restored, said and drawn',
        (tester) async {
      final rig = await _rig();
      final api = _Api(_draw());
      await _pumpTrainer(tester, rig, api);
      await _tap(tester, 'Play to the end');
      api.judged.add(_step(
          held: false,
          goal: 'draw',
          outcome: 'loss',
          san: 'Rg1+',
          uci: 'a1g1',
          fen: '8/5pk1/8/8/8/8/5PK1/6r1 w - - 1 56'));
      await _play(tester, 'a1', 'g1');
      final before = rig.voice.lines.length;
      await _tap(tester, 'Take back');
      expect(_since(rig, before), ['restored']);
      expect(
          find.text('Restored to the position before that move. Try another.'),
          findsOneWidget);
      await _leave(tester);
    });
  });

  // ── 3. Show solution, and the solved task line ─────────────────────────

  group('solving: Show solution and Solved', () {
    testWidgets('one holding move: the answer is the task line',
        (tester) async {
      final rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_win(winning: const ['e1d2'])));
      final before = rig.voice.lines.length;
      await _tap(tester, 'Show solution');
      expect(_since(rig, before), ['only_move_keeps_win_is piece_king sq_d2']);
      expect(find.text('The only move that keeps the win is king d2.'),
          findsOneWidget);
      // No separate „Answer shown" sentence, and the old one is gone.
      expect(find.textContaining('Answer shown'), findsNothing);
      await _leave(tester);
    });

    testWidgets('several: the moves one after another, drawn with commas',
        (tester) async {
      final rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_win()));
      final before = rig.voice.lines.length;
      await _tap(tester, 'Show solution');
      expect(_since(rig, before), [
        'these_moves_keep_win piece_king sq_d2 piece_king sq_f1 piece_pawn '
            'sq_e8 promotes_to prom_knight'
      ]);
      // The one place the drawn text is not the line's own: the clips have no
      // word for a comma.
      expect(
          find.text('These moves keep the win: king d2, king f1, pawn e8 '
              'promotes to knight.'),
          findsOneWidget);
      await _leave(tester);
    });

    testWidgets('a draw says hold, and a check is not a sentence of its own',
        (tester) async {
      final rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_draw()));
      final before = rig.voice.lines.length;
      await _tap(tester, 'Show solution');
      expect(_since(rig, before), [
        'these_moves_hold_draw piece_rook sq_e1 piece_rook sq_f1',
      ]);
      expect(find.text('These moves hold the draw: rook e1, rook f1.'),
          findsOneWidget);
      await _leave(tester);
    });

    testWidgets(
        'solved: the task line says it, and it is not said a second time '
        'after the verdict', (tester) async {
      final rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_win(winning: const ['e1d2'])));
      final before = rig.voice.lines.length;
      await _play(tester, 'e1', 'd2');
      expect(find.text('Solved. The win is kept.'), findsOneWidget);
      expect(_since(rig, before), ['correct_win_kept only_move'],
          reason: 'the task only repeats the verdict that was just said');
      // The speaker still reads it, for whoever asks.
      await tester.tap(find.byTooltip('Read aloud'));
      await tester.pumpAndSettle();
      expect(_since(rig, before).last, 'solved_win_kept');
      expect(find.textContaining('—'), findsNothing);
      await _leave(tester);
    });

    testWidgets('a solved draw says held', (tester) async {
      final rig = await _rig();
      final draw = _puzzle(
          fen: '8/5pk1/8/8/8/8/5PK1/r7 b - - 0 55',
          mode: 'draw',
          winning: const ['a1f1']);
      await _pumpTrainer(tester, rig, _Api(draw));
      await _play(tester, 'a1', 'f1');
      expect(find.text('Solved. The draw is held.'), findsOneWidget);
      await _leave(tester);
    });
  });

  // ── 4. the drill ───────────────────────────────────────────────────────

  group('the drill', () {
    testWidgets('the task: win, draw and punish', (tester) async {
      var rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_win(played: null)));
      var before = rig.voice.lines.length;
      await _tap(tester, 'Play to the end');
      expect(_since(rig, before), ['play_to_end_win']);
      expect(find.text('Play to the end. Keep the win.'), findsOneWidget);
      expect(find.textContaining('Opponent'), findsNothing);
      await _leave(tester);

      rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_draw()));
      before = rig.voice.lines.length;
      await _tap(tester, 'Play to the end');
      expect(_since(rig, before), ['play_to_end_draw']);
      expect(find.text('Play to the end. Hold the draw.'), findsOneWidget);
      await _tap(tester, 'Back to task');
      before = rig.voice.lines.length;
      await _tap(tester, 'Punish');
      expect(_since(rig, before), ['punish_blunder']);
      expect(find.text('Punish the blunder. Play the win to the end.'),
          findsOneWidget);
      expect(find.textContaining('—'), findsNothing);
      await _leave(tester);
    });

    testWidgets('starting over says the task again', (tester) async {
      final rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_win(played: null)));
      await _tap(tester, 'Play to the end');
      final before = rig.voice.lines.length;
      await _tap(tester, 'Start over');
      expect(_since(rig, before), ['play_to_end_win']);
      await _leave(tester);
    });

    testWidgets('a move that holds: Good, and the opponent\'s reply as a move',
        (tester) async {
      final rig = await _rig();
      final api = _Api(_draw());
      await _pumpTrainer(tester, rig, api);
      await _tap(tester, 'Play to the end');
      api.judged.add(_step(
        held: true,
        goal: 'draw',
        outcome: 'draw',
        san: 'Re1',
        uci: 'a1e1',
        replyUci: 'f2f3',
        fen: '8/5pk1/8/8/8/5P2/6K1/4r3 b - - 0 56',
      ));
      final before = rig.voice.lines.length;
      await _play(tester, 'a1', 'e1');
      expect(_since(rig, before),
          ['good_keep_going', 'white_plays piece_pawn sq_f3']);
      expect(find.text('Good. Keep going.'), findsOneWidget);
      expect(find.text('White plays pawn f3.'), findsOneWidget);
      // Not the old „Correct — draw held. Opponent plays f3."
      expect(find.textContaining('—'), findsNothing);
      expect(find.textContaining('Opponent plays'), findsNothing);
      await _leave(tester);
    });

    testWidgets(
        'a held draw with a claim says how many moves are left, at the claim '
        'and after each move', (tester) async {
      final rig = await _rig();
      final api = _Api(_pawnless())
        ..readout = const TablebaseReadout(
          goal: 'draw',
          outcome: 'draw',
          holding: 2,
          total: 3,
          pawnless: true,
          deadDraw: false,
          moves: [],
        );
      await _pumpTrainer(tester, rig, api);
      await _tap(tester, 'Play to the end');
      var before = rig.voice.lines.length;
      await _tap(tester, 'Conclude draw');
      expect(_since(rig, before), ['moves_left_to_hold n_8']);
      expect(find.text('Moves left to hold: 8.'), findsOneWidget);

      api.judged.add(_step(
        held: true,
        goal: 'draw',
        outcome: 'draw',
        san: 'Rc8',
        uci: 'b8c8',
        replyUci: 'b1b2',
        fen: '2r3k1/8/8/8/8/8/1R6/6K1 b - - 2 2',
      ));
      before = rig.voice.lines.length;
      await _play(tester, 'b8', 'c8');
      expect(_since(rig, before), [
        'good_keep_going moves_left_to_hold n_7',
        'white_plays piece_rook sq_b2',
      ]);
      expect(find.text('Good. Keep going. Moves left to hold: 7.'),
          findsOneWidget);
      await _leave(tester);
    });

    testWidgets('a move that loses the draw: the move and the tail',
        (tester) async {
      final rig = await _rig();
      final api = _Api(_draw());
      await _pumpTrainer(tester, rig, api);
      await _tap(tester, 'Play to the end');
      api.judged.add(_step(
          held: false,
          goal: 'draw',
          outcome: 'loss',
          san: 'Rg1+',
          uci: 'a1g1',
          fen: '8/5pk1/8/8/8/8/5PK1/6r1 w - - 1 56'));
      final before = rig.voice.lines.length;
      await _play(tester, 'a1', 'g1');
      expect(_since(rig, before), ['piece_rook sq_g1 loses_draw_drill_stops']);
      // A line that begins with a move begins with a piece's clip: the screen
      // gives it its capital, and one full stop.
      expect(find.text('Rook g1 loses the draw. The drill stops here.'),
          findsOneWidget);
      await _leave(tester);
    });

    testWidgets('a move that lets the win go: lost, or only a draw',
        (tester) async {
      var rig = await _rig();
      var api = _Api(_win(played: null));
      await _pumpTrainer(tester, rig, api);
      await _tap(tester, 'Play to the end');
      api.judged.add(_step(
          held: false,
          outcome: 'loss',
          san: 'Kd1',
          uci: 'e1d1',
          fen: '8/4P3/8/8/8/8/1p6/3K3k b - - 1 1'));
      var before = rig.voice.lines.length;
      await _play(tester, 'e1', 'd1');
      expect(_since(rig, before), ['piece_king sq_d1 lets_win_go_lost']);
      expect(find.text('King d1 lets the win go. The position is now lost.'),
          findsOneWidget);
      await _leave(tester);

      rig = await _rig();
      api = _Api(_win(played: null));
      await _pumpTrainer(tester, rig, api);
      await _tap(tester, 'Play to the end');
      api.judged.add(_step(
          held: false,
          outcome: 'draw',
          san: 'Kd1',
          uci: 'e1d1',
          fen: '8/4P3/8/8/8/8/1p6/3K3k b - - 1 1'));
      before = rig.voice.lines.length;
      await _play(tester, 'e1', 'd1');
      expect(_since(rig, before), ['piece_king sq_d1 lets_win_go_draw']);
      await _leave(tester);
    });

    testWidgets('the drill\'s ends: mate, a draw held, nothing left to hold',
        (tester) async {
      var rig = await _rig();
      var api = _Api(_win(played: null));
      await _pumpTrainer(tester, rig, api);
      await _tap(tester, 'Play to the end');
      api.judged.add(_step(held: true, finished: 'mate'));
      var before = rig.voice.lines.length;
      await _play(tester, 'e1', 'd2');
      expect(_since(rig, before), ['checkmate_completed']);
      expect(find.text('Checkmate. Drill completed.'), findsOneWidget);
      await _leave(tester);

      rig = await _rig();
      api = _Api(_draw());
      await _pumpTrainer(tester, rig, api);
      await _tap(tester, 'Play to the end');
      api.judged.add(_step(
          held: true,
          goal: 'draw',
          outcome: 'draw',
          san: 'Re1',
          uci: 'a1e1',
          finished: 'repetition'));
      before = rig.voice.lines.length;
      await _play(tester, 'a1', 'e1');
      expect(_since(rig, before), ['draw_held_completed']);
      expect(find.text('Draw held. Drill completed.'), findsOneWidget);
      await _leave(tester);

      rig = await _rig();
      api = _Api(_pawnless())
        ..readout = const TablebaseReadout(
          goal: 'draw',
          outcome: 'draw',
          holding: 3,
          total: 3,
          pawnless: true,
          deadDraw: true,
          moves: [],
        );
      await _pumpTrainer(tester, rig, api);
      await _tap(tester, 'Play to the end');
      before = rig.voice.lines.length;
      await _tap(tester, 'Conclude draw');
      expect(_since(rig, before), ['draw_nothing_to_hold']);
      expect(find.text('Draw. Nothing left to hold.'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets(
        'the tablebase is silent: said, drawn, and the move is put back',
        (tester) async {
      final rig = await _rig();
      final api = _Api(_draw());
      await _pumpTrainer(tester, rig, api);
      await _tap(tester, 'Play to the end');
      api.judged.add(const DrillJudgeResult(DrillJudgeOutcome.unavailable));
      var before = rig.voice.lines.length;
      await _play(tester, 'a1', 'e1');
      expect(_since(rig, before), ['tablebase_silent']);
      expect(
          find.text('The tablebase is not answering. Try again in a moment.'),
          findsOneWidget);
      expect(find.textContaining('currently unavailable'), findsNothing);

      // The findings button meets the same silence.
      await _tap(tester, 'Tablebase findings');
      expect(_since(rig, before), ['tablebase_silent', 'tablebase_silent']);
      await _leave(tester);
    });

    testWidgets('„Checking tablebases…" is drawn and never said',
        (tester) async {
      final rig = await _rig();
      final api = _Api(_draw())..judgeGate = Completer<void>();
      await _pumpTrainer(tester, rig, api);
      await _tap(tester, 'Play to the end');
      final before = rig.voice.lines.length;
      await tester.tapAt(_at(tester, 'a1'));
      await tester.pumpAndSettle();
      await tester.tapAt(_at(tester, 'e1'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Checking tablebases…'), findsOneWidget);
      expect(_since(rig, before), isEmpty);
      api.judgeGate!.complete();
      await tester.pumpAndSettle();
      await _leave(tester);
    });
  });

  // ── 5. the blunder walk ────────────────────────────────────────────────

  group('the blunder walk', () {
    testWidgets(
        'at a mistake: the task with the move inside it, then the instruction',
        (tester) async {
      final rig = await _rig();
      await _pumpWalk(tester, rig);
      expect(rig.voice.said, [
        'black_played piece_rook sq_d3 here_lost_draw',
        'play_move_holds_draw',
      ]);
      expect(find.text('Black played rook d3 here and lost the draw.'),
          findsOneWidget);
      expect(find.text('Play the move that holds the draw.'), findsOneWidget);
      expect(find.textContaining('—'), findsNothing);
      expect(rig.tts.said, isEmpty);
      await _leaveWalk(tester);
    });

    testWidgets('a right move, and then the game goes forward on its own',
        (tester) async {
      final rig = await _rig();
      await _pumpWalk(tester, rig);
      final before = rig.voice.lines.length;
      await _play(tester, 'f3', 'b3');
      expect(_since(rig, before).first, 'correct game_continues');
      expect(
          find.text('Correct. The game continues as played.'), findsOneWidget);
      // Between mistakes the task is one short instruction.
      expect(_since(rig, before), ['correct game_continues', 'go_forward']);
      expect(find.text('Go forward to the next mistake.'), findsOneWidget);
      expect(find.textContaining('The board is only played'), findsNothing);

      // And at the next mistake it is the mistake again.
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(find.text('White played pawn h4 here and let the win go.'),
          findsOneWidget);
      expect(find.text('Play the move that holds the win.'), findsOneWidget);
      await _leaveWalk(tester);
    });

    testWidgets('a wrong move: the move, said as a move, and what it costs',
        (tester) async {
      final rig = await _rig();
      await _pumpWalk(tester, rig);
      final before = rig.voice.lines.length;
      await _play(tester, 'f3', 'f8');
      expect(_since(rig, before), ['piece_rook sq_f8 does_not_hold_draw']);
      expect(find.text('Rook f8 does not hold the draw. Try another move.'),
          findsOneWidget);
      await _leaveWalk(tester);
    });

    testWidgets('a wrong move that should have kept the win', (tester) async {
      final rig = await _rig();
      await _pumpWalk(tester, rig, game: _winGame());
      final before = rig.voice.lines.length;
      await _play(tester, 'c6', 'c7');
      expect(_since(rig, before), ['piece_king sq_c7 also_lets_win_go']);
      expect(find.text('King c7 also lets the win go. Try another move.'),
          findsOneWidget);
      await _leaveWalk(tester);
    });

    testWidgets('the refutation: the task line names the move', (tester) async {
      final rig = await _rig();
      await _pumpWalk(tester, rig);
      await _play(tester, 'f3', 'b3');
      // Step back onto the answered mistake.
      final back = find.byIcon(Icons.chevron_left);
      for (var i = 0; i < 6; i++) {
        final button = tester.widget<IconButton>(
            find.ancestor(of: back, matching: find.byType(IconButton)));
        if (button.onPressed == null) break;
        await tester.tap(back);
        await tester.pumpAndSettle();
        if (find.text('Why it is bad').evaluate().isNotEmpty) break;
      }
      final before = rig.voice.lines.length;
      await tester.tap(find.text('Why it is bad'));
      await tester.pumpAndSettle();
      expect(_since(rig, before), ['watch_refutation_of piece_rook sq_d3']);
      expect(find.text('Watch the refutation of rook d3.'), findsOneWidget);
      expect(find.textContaining('This is how'), findsNothing);
      expect(find.textContaining('The board cannot be played'), findsNothing);
      await _leaveWalk(tester);
    });

    testWidgets(
        'the end: Game finished, with what was found out of how many, from '
        'two different numbers', (tester) async {
      final rig = await _rig();
      await _pumpWalk(tester, rig);
      // Shown, not found: one of the two is not counted.
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(find.text('Holding moves were: Rb3, Rf2.'), findsOneWidget,
          reason: 'a list of notation is drawn, not said');
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      await _play(tester, 'c6', 'c5');
      // The rest of the game plays out, a move at a time.
      final before = rig.voice.lines.length;
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 900));
      }
      await tester.pumpAndSettle();
      expect(_since(rig, before), ['game_finished_found nmid_1 of n_2']);
      expect(find.text('Game finished. Found 1 of 2.'), findsOneWidget);
      expect(find.textContaining('Game over'), findsNothing);
      await _leaveWalk(tester);
    });

    testWidgets('the last mistake of a game that ends on it', (tester) async {
      final rig = await _rig();
      await _pumpWalk(tester, rig, game: _oneMoveGame());
      final before = rig.voice.lines.length;
      await _play(tester, 'f3', 'b3');
      expect(_since(rig, before).first, 'correct last_mistake_game_over');
      expect(find.text('Correct. That was the last mistake. Game over.'),
          findsOneWidget);
      await _leaveWalk(tester);
    });

    testWidgets('saving is a message, never a line of the panel',
        (tester) async {
      final rig = await _rig();
      await _pumpWalk(tester, rig);
      final before = rig.voice.lines.length;
      await tester.tap(find.text('Save for later'));
      await tester.pumpAndSettle();
      expect(_since(rig, before), isEmpty);
      expect(find.textContaining('Saved to the Library'), findsOneWidget);
      await _leaveWalk(tester);
    });
  });

  // ── 6. speech off ──────────────────────────────────────────────────────

  group('speech off', () {
    testWidgets(
        'the trainer says nothing, and the speaker turns it on and says the '
        'task once', (tester) async {
      final rig = await _rig(enabled: false);
      await _pumpTrainer(tester, rig, _Api(_win()));
      await _play(tester, 'e1', 'e2');
      expect(rig.voice.lines, isEmpty);
      // The task, the story and the verdict are still drawn.
      expect(find.text('White to move. Keep the win.'), findsOneWidget);
      expect(find.textContaining('In the game, White played'), findsOneWidget);
      expect(
          find.text('That move drops the win. Try another.'), findsOneWidget);

      await tester.tap(find.byTooltip('Enable reading aloud'));
      await tester.pumpAndSettle();
      expect(rig.voice.said, [_taskWinWhite]);
      expect(AppSettingsService.instance.speechEnabled, isTrue);
      await _leave(tester);
    });

    testWidgets('the walk says nothing, and the speaker says its task once',
        (tester) async {
      final rig = await _rig(enabled: false);
      await _pumpWalk(tester, rig);
      expect(rig.voice.lines, isEmpty);
      expect(find.text('Black played rook d3 here and lost the draw.'),
          findsOneWidget);
      await tester.tap(find.byTooltip('Enable reading aloud'));
      await tester.pumpAndSettle();
      expect(rig.voice.said, ['black_played piece_rook sq_d3 here_lost_draw']);
      await _leaveWalk(tester);
    });
  });

  // ── 7. leaving ─────────────────────────────────────────────────────────

  group('leaving the screen', () {
    testWidgets('the trainer stops the voice', (tester) async {
      final rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_win()));
      final before = rig.speech.stopCalls;
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
      expect(rig.speech.stopCalls, before + 1);
    });

    testWidgets('the blunder walk stops the voice', (tester) async {
      final rig = await _rig();
      await _pumpWalk(tester, rig);
      final before = rig.speech.stopCalls;
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
      expect(rig.speech.stopCalls, before + 1);
    });
  });

  // ── 8. no Hint ─────────────────────────────────────────────────────────

  group('no Hint (the owner, 3.10.2026)', () {
    testWidgets('the trainer has no Hint button and no key for it',
        (tester) async {
      final rig = await _rig();
      await _pumpTrainer(tester, rig, _Api(_win()));
      expect(find.text('Hint'), findsNothing);
      expect(find.byIcon(Icons.lightbulb_outline), findsNothing);
      expect(find.text('Show solution'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('the walk has none either', (tester) async {
      final rig = await _rig();
      await _pumpWalk(tester, rig);
      expect(find.text('Hint'), findsNothing);
      expect(find.byIcon(Icons.lightbulb_outline), findsNothing);
      await _leaveWalk(tester);
    });

    test('the model and the screen carry no hint', () {
      final model =
          _code('lib/features/endgame_trainer/models/endgame_puzzle.dart');
      final screen = _code(
          'lib/features/endgame_trainer/screens/endgame_trainer_screen.dart');
      expect(model, isNot(contains('revealHint')));
      expect(model, isNot(contains('usedHint')));
      expect(screen, isNot(contains('_showHint')));
      expect(screen, isNot(contains('_hintSquare')));
      expect(screen, isNot(contains("'Hint'")));
      expect(screen, isNot(contains('keyH')));
    });
  });

  // ── 9. one voice ───────────────────────────────────────────────────────

  group('one voice', () {
    testWidgets(
        'the device voice is never asked anything on the trainer, from the '
        'first position to the drill\'s last verdict', (tester) async {
      final rig = await _rig();
      final api = _Api(_draw());
      await _pumpTrainer(tester, rig, api);
      await _play(tester, 'g7', 'g6');
      await _play(tester, 'a1', 'f1');
      await _tap(tester, 'Show');
      await _tap(tester, 'Play to the end');
      api.judged.add(_step(held: true, finished: 'mate'));
      await _play(tester, 'a1', 'e1');
      await _tap(tester, 'Next');
      expect(rig.voice.lines, isNotEmpty);
      expect(rig.tts.said, isEmpty);
      await _leave(tester);
    });

    testWidgets('and never on the walk', (tester) async {
      final rig = await _rig();
      await _pumpWalk(tester, rig);
      await _play(tester, 'f3', 'f8');
      await _play(tester, 'f3', 'b3');
      await tester.pump(const Duration(milliseconds: 900));
      expect(rig.voice.lines, isNotEmpty);
      expect(rig.tts.said, isEmpty);
      await _leaveWalk(tester);
    });

    test('neither screen, nor their panel, calls the device voice', () {
      for (final path in [
        'lib/features/endgame_trainer/screens/endgame_trainer_screen.dart',
        'lib/features/endgame_trainer/screens/blunder_walk_screen.dart',
        'lib/widgets/endgame_info_panel.dart',
      ]) {
        final code = _code(path);
        expect(code, isNot(contains('.speak(')), reason: path);
        expect(code, isNot(contains('SpeechService.instance.stop')),
            reason: '$path stops through its seam');
      }
    });

    testWidgets('a voice that throws stops no move and no verdict',
        (tester) async {
      final rig = await _rig();
      rig.voice.throwOnSpeak = StateError('no sound card');
      await _pumpTrainer(tester, rig, _Api(_win()));
      await _play(tester, 'e1', 'd2');
      expect(find.text('Correct. The win is kept. Other moves to find: 2.'),
          findsOneWidget);
      await _leave(tester);
    });
  });
}

// ── driving the walk ─────────────────────────────────────────────────────

/// Seger - Lambert 2005: two mistakes, alternating sides, the first of them
/// Black's Rd3 that lost the draw, the second White's h4 that let the win go.
BlunderGame _walkGame() => BlunderGame.fromJson({
      'game_id': 'bg_test',
      'white': 'Seger, Ruediger',
      'black': 'Lambert, Andreas',
      'start_fen': '8/8/k1K5/P6R/8/5r2/7P/8 b - - 1 59',
      'moves': ['Rd3', 'h4', 'Rd1', 'Rh6', 'Kxa5', 'Rc4'],
      'blunders': [
        {
          'ply': 0,
          'fen': '8/8/k1K5/P6R/8/5r2/7P/8 b - - 1 59',
          'side': 'black',
          'played': 'Rd3',
          'played_uci': 'f3d3',
          'should_play': ['Rb3', 'Rf2'],
          'should_play_uci': ['f3b3', 'f3f2'],
          'outcome_before': 'draw',
          'outcome_after': 'loss',
          'material': 'KRPPvKR',
        },
        {
          'ply': 1,
          'fen': '8/8/k1K5/P6R/8/3r4/7P/8 w - - 2 60',
          'side': 'white',
          'played': 'h4',
          'played_uci': 'h2h4',
          'should_play': ['Kc5'],
          'should_play_uci': ['c6c5'],
          'outcome_before': 'win',
          'outcome_after': 'draw',
          'material': 'KRPPvKR',
        },
      ],
    });

/// One mistake that lost a win, for the sentence about the wrong move.
BlunderGame _winGame() => BlunderGame.fromJson({
      'game_id': 'bg_win',
      'white': 'A',
      'black': 'B',
      'start_fen': '8/8/k1K5/P6R/8/3r4/7P/8 w - - 2 60',
      'moves': ['h4', 'Rd1'],
      'blunders': [
        {
          'ply': 0,
          'fen': '8/8/k1K5/P6R/8/3r4/7P/8 w - - 2 60',
          'side': 'white',
          'played': 'h4',
          'played_uci': 'h2h4',
          'should_play': ['Kc5'],
          'should_play_uci': ['c6c5'],
          'outcome_before': 'win',
          'outcome_after': 'draw',
        },
      ],
    });

/// A game whose only mistake is its last move.
BlunderGame _oneMoveGame() => BlunderGame.fromJson({
      'game_id': 'bg_one',
      'white': 'A',
      'black': 'B',
      'start_fen': '8/8/k1K5/P6R/8/5r2/7P/8 b - - 1 59',
      'moves': ['Rd3'],
      'blunders': [
        {
          'ply': 0,
          'fen': '8/8/k1K5/P6R/8/5r2/7P/8 b - - 1 59',
          'side': 'black',
          'played': 'Rd3',
          'played_uci': 'f3d3',
          'should_play': ['Rb3', 'Rf2'],
          'should_play_uci': ['f3b3', 'f3f2'],
          'outcome_before': 'draw',
          'outcome_after': 'loss',
        },
      ],
    });

class _WalkApi extends EndgameApiService {
  _WalkApi(this.game) : super(authToken: '');

  final BlunderGame game;

  @override
  Future<GameFetchResult> fetchNextGame({
    int? minBlunders,
    int? maxBlunders,
    int? minElo,
    int? maxElo,
    String? material,
    String? excludeId,
    bool includeOnline = false,
  }) async =>
      GameFetchResult(EndgameFetchOutcome.ok, game);

  @override
  Future<List<String>?> fetchBestLine({
    required String fen,
    int plies = 10,
  }) async =>
      const ['Kf1', 'Ra1+'];

  @override
  Future<bool> keepForLater({
    required String fen,
    required String title,
    required String description,
  }) async =>
      true;
}

Future<void> _pumpWalk(
  WidgetTester tester,
  _Rig rig, {
  BlunderGame? game,
}) async {
  tester.view.physicalSize = const Size(500, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: BlunderWalkScreen(
      key: UniqueKey(),
      session: _session(),
      api: _WalkApi(game ?? _walkGame()),
      speech: rig.speech,
    ),
  ));
  await tester.pumpAndSettle();
}

/// Leaves the walk, so its playback and arrow timers are gone.
Future<void> _leaveWalk(WidgetTester tester) => _leave(tester);
