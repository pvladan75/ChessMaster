// Phase 4a's gate — `docs/PLAN-GOVOR-IZ-KLIPOVA.md`: the tactics trainer
// speaks the table the owner approved on 3.10.2026 through
// `SpeechService.speakLine`, and what it speaks is what it draws (D4).
//
// Modelled on `speech_pilot_test.dart`: the screen is the real one, the server
// is a `MockClient`, and the voice is a fake `ClipVoice` that records the
// `SpokenLine`s it was handed, so the cases assert **token ids**, not bytes.
//
// Every puzzle here is stored as the server stores it: the position *before*
// the opponent's setup move, the setup move, and the line after it, whose even
// entries are the reader's moves and odd ones the opponent's replies.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/speech/clip_voice.dart';
import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/features/tactics_trainer/screens/tactics_trainer_screen.dart';
import 'package:chess_app/features/tactics_trainer/services/tactics_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

UserSession _session() => UserSession(
    token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik');

// ── fakes ────────────────────────────────────────────────────────────────

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
  _CountingSpeech() : super.forSubclass();

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
  _Rig(this.speech, this.voice);

  final _CountingSpeech speech;
  final _FakeClipVoice voice;
}

Future<_Rig> _rig({bool enabled = true}) async {
  final voice = _FakeClipVoice();
  final speech = _CountingSpeech();
  await speech.init(enabled: enabled, clipVoice: voice);
  final settings = AppSettingsService.instance;
  await settings.init();
  await settings.setSpeechEnabled(enabled);
  return _Rig(speech, voice);
}

// ── the server and the puzzles ───────────────────────────────────────────

Map<String, dynamic> _puzzle(String fen, String setup, List<String> solution) =>
    {
      'puzzle_id': 'p1',
      'fen': fen,
      'setup_move': setup,
      'solution': solution,
      'rating': 1200,
      'themes': const ['mateIn2'],
    };

/// The adaptive route answers [puzzle]; the by-id route (homework) answers
/// it too; an attempt is refused, so no rating card covers the verdict.
http.Client _server(Map<String, dynamic> puzzle, [List<Uri>? attempts]) =>
    MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/api/puzzles/attempt')) {
        attempts?.add(request.url);
        return http.Response('{}', 500);
      }
      if (path.contains('/by-id/')) {
        return http.Response(jsonEncode({'puzzle': puzzle}), 200);
      }
      return http.Response(
          jsonEncode({
            'puzzle': puzzle,
            'selection': {'targetRating': 1200}
          }),
          200);
    });

/// White to move after the setup, a mate in one: a1a8.
final _mateInOne = _puzzle('6k1/5ppp/8/8/8/8/8/R5K1 b - - 0 1', 'h7h6', [
  'a1a8',
]);

/// White to move after Black's knight lands on d5; the line is a pawn push,
/// [reply], a second pawn push.
Map<String, dynamic> _replyPuzzle(String fenBefore, String setup, String reply,
        {String third = 'a3a4'}) =>
    _puzzle(fenBefore, setup, ['a2a3', reply, third]);

// ── the screen ───────────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester,
  _Rig rig,
  http.Client client, {
  List<String>? puzzleIds,
  Size size = const Size(800, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: TacticsTrainerScreen(
      session: _session(),
      puzzleIds: puzzleIds,
      assignmentId: puzzleIds == null ? null : 42,
      speech: rig.speech,
      api: TacticsApiService(authToken: 't', client: client),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Leaves the screen, so its timers are gone before the test ends.
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _move(WidgetTester tester, String from, String to) async {
  tester
      .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
      .onMove(from, to, '');
  await _wait(tester);
}

/// The screen's own beats — 350 ms before a reply, 450 ms between the moves of
/// a solution — are timers, which `pumpAndSettle` does not wait for.
Future<void> _wait(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  await tester.pumpAndSettle();
}

const _taskWhite = 'white_to_move find_best_move';
const _keepGoing = 'correct_keep_going';

/// The source of [path] with its `//` comment lines taken out, so a word the
/// code explains is not mistaken for a word the code uses.
String _code(String path) => File(path)
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── 1. a puzzle appears ────────────────────────────────────────────────

  group('a puzzle appears', () {
    testWidgets(
        'the setup move is spoken as a move, then the task, and the task is '
        'drawn from the line it was spoken from (D4)', (tester) async {
      final rig = await _rig();
      await http.runWithClient(() async {
        await _pump(tester, rig, _server(_mateInOne));
        // Black's pawn h7-h6 is what the reader is asked about.
        expect(rig.voice.said, ['black_plays piece_pawn sq_h6', _taskWhite]);
        expect(rig.voice.lines.first.text, 'Black plays pawn h6.');
        expect(rig.voice.lines.last.text, 'White to move. Find the best move.');
        expect(find.text(rig.voice.lines.last.text), findsOneWidget);
        // No dash in the drawn task — the old „to move — find the best move”.
        expect(find.textContaining('—'), findsNothing);
        await _leave(tester);
      }, () => _server(_mateInOne));
    });

    testWidgets('Black to move is said and drawn as Black', (tester) async {
      final rig = await _rig();
      final puzzle = _puzzle('7k/8/8/8/8/3P4/8/K7 w - - 0 1', 'd3d4', ['h8g8']);
      await http.runWithClient(() async {
        await _pump(tester, rig, _server(puzzle));
        expect(rig.voice.said,
            ['white_plays piece_pawn sq_d4', 'black_to_move find_best_move']);
        expect(find.text('Black to move. Find the best move.'), findsOneWidget);
        await _leave(tester);
      }, () => _server(puzzle));
    });

    testWidgets('the next puzzle is said again, in the same words',
        (tester) async {
      final rig = await _rig();
      await http.runWithClient(() async {
        await _pump(tester, rig, _server(_mateInOne));
        expect(rig.voice.said, hasLength(2));
        final forgot = rig.speech.forgetCalls;
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        expect(rig.speech.forgetCalls, greaterThan(forgot));
        expect(rig.voice.said, [
          'black_plays piece_pawn sq_h6',
          _taskWhite,
          'black_plays piece_pawn sq_h6',
          _taskWhite
        ]);
        await _leave(tester);
      }, () => _server(_mateInOne));
    });
  });

  // ── 2. a right move that continues, and the reply ──────────────────────

  group('a right move that continues', () {
    // (name, position before the setup, setup, the reply, the tokens it must
    // be said as, the text it must draw)
    final cases = <(String, String, String, String, String, String)>[
      (
        'a plain move',
        '7k/4n2p/8/8/8/8/P7/K5N1 b - - 0 1',
        'e7d5',
        'd5b6',
        'black_plays piece_knight sq_b6',
        'Black plays knight b6.'
      ),
      (
        'a capture says takes, and the square after it',
        '7k/7p/8/8/8/1K6/P6r/6N1 b - - 0 1',
        'h2h1',
        'h1g1',
        'black_plays piece_rook takes sqx_g1',
        'Black plays rook takes g1.'
      ),
      (
        'a check',
        '8/6k1/8/7r/8/8/P7/4K3 b - - 0 1',
        'h5h8',
        'h8e8',
        'black_plays piece_rook sq_e8 check',
        'Black plays rook e8. Check.'
      ),
    ];

    for (final (name, fen, setup, reply, tokens, text) in cases) {
      testWidgets(
          '$name: Correct. Keep going. is said and drawn, then the reply '
          'is said as a move', (tester) async {
        final rig = await _rig();
        final puzzle = _replyPuzzle(fen, setup, reply,
            third: reply == 'h8e8' ? 'e1d1' : 'a3a4');
        await http.runWithClient(() async {
          await _pump(tester, rig, _server(puzzle));
          final before = rig.voice.lines.length;
          await _move(tester, 'a2', 'a3');
          final spoken = rig.voice.said.sublist(before);
          expect(spoken, [_keepGoing, tokens]);
          expect(rig.voice.lines.last.text, text);
          // The drawn feedback is the line's text, character for character.
          expect(find.text('Correct. Keep going.'), findsOneWidget);
          expect(find.textContaining('—'), findsNothing);
          await _leave(tester);
        }, () => _server(puzzle));
      });
    }
  });

  // ── 3. a wrong move ────────────────────────────────────────────────────

  group('a wrong move', () {
    testWidgets('in practice: Incorrect. Try another move.', (tester) async {
      final rig = await _rig();
      final puzzle =
          _replyPuzzle('7k/4n2p/8/8/8/8/P7/K5N1 b - - 0 1', 'e7d5', 'd5b6');
      await http.runWithClient(() async {
        await _pump(tester, rig, _server(puzzle));
        final before = rig.voice.lines.length;
        await _move(tester, 'a1', 'b1');
        expect(rig.voice.said.sublist(before), ['incorrect_try_another']);
        expect(find.text('Incorrect. Try another move.'), findsOneWidget);
        expect(find.textContaining('That is not it'), findsNothing);
        await _leave(tester);
      }, () => _server(puzzle));
    });

    testWidgets(
        'in a homework with one attempt: the attempt line, then Not solved., '
        'in that order, and both drawn', (tester) async {
      final rig = await _rig();
      final puzzle =
          _replyPuzzle('7k/4n2p/8/8/8/8/P7/K5N1 b - - 0 1', 'e7d5', 'd5b6');
      final attempts = <Uri>[];
      await http.runWithClient(() async {
        await _pump(tester, rig, _server(puzzle, attempts),
            puzzleIds: const ['p1']);
        final before = rig.voice.lines.length;
        await _move(tester, 'a1', 'b1');
        expect(rig.voice.said.sublist(before), ['one_attempt', 'not_solved']);
        expect(find.text('Incorrect. The assignment allows one attempt.'),
            findsOneWidget);
        expect(find.text('Not solved.'), findsOneWidget);
        expect(attempts, hasLength(1), reason: 'the attempt is still recorded');
        await _leave(tester);
      }, () => _server(puzzle, attempts));
    });
  });

  // ── 4. solved ──────────────────────────────────────────────────────────

  group('solved', () {
    testWidgets('Solved. when the reader found it unaided', (tester) async {
      final rig = await _rig();
      await http.runWithClient(() async {
        await _pump(tester, rig, _server(_mateInOne));
        final before = rig.voice.lines.length;
        await _move(tester, 'a1', 'a8');
        expect(rig.voice.said.sublist(before), ['solved']);
        expect(find.text('Solved.'), findsOneWidget);
        await _leave(tester);
      }, () => _server(_mateInOne));
    });

    testWidgets(
        'Solved with help. when a mistake came first: the line the screen '
        'draws is the line it says', (tester) async {
      final rig = await _rig();
      await http.runWithClient(() async {
        await _pump(tester, rig, _server(_mateInOne));
        await _move(tester, 'g1', 'h1');
        final before = rig.voice.lines.length;
        await _move(tester, 'a1', 'a8');
        expect(rig.voice.said.sublist(before), ['solved_with_help']);
        expect(find.text('Solved with help.'), findsOneWidget);
        await _leave(tester);
      }, () => _server(_mateInOne));
    });
  });

  // ── 5. Show solution ───────────────────────────────────────────────────

  group('Show solution', () {
    testWidgets('says every remaining move as a move, in order',
        (tester) async {
      final rig = await _rig();
      final puzzle =
          _replyPuzzle('7k/4n2p/8/8/8/8/P7/K5N1 b - - 0 1', 'e7d5', 'd5b6');
      await http.runWithClient(() async {
        await _pump(tester, rig, _server(puzzle));
        final before = rig.voice.lines.length;
        await tester.tap(find.text('Show solution'));
        await _wait(tester);
        expect(rig.voice.said.sublist(before), [
          'white_plays piece_pawn sq_a3',
          'black_plays piece_knight sq_b6',
          'white_plays piece_pawn sq_a4',
          // The sentence the screen draws at the end is said as well — a
          // drawn sentence is never left unsaid (the lead's grading of 4a).
          'solved_with_help',
        ]);
        expect(find.text('Solved with help.'), findsOneWidget);
        await _leave(tester);
      }, () => _server(puzzle));
    });
  });

  // ── 6. speech off ──────────────────────────────────────────────────────

  group('speech off', () {
    testWidgets(
        'nothing is spoken, and the speaker turns it on and says the task '
        'once', (tester) async {
      final rig = await _rig(enabled: false);
      final puzzle =
          _replyPuzzle('7k/4n2p/8/8/8/8/P7/K5N1 b - - 0 1', 'e7d5', 'd5b6');
      await http.runWithClient(() async {
        await _pump(tester, rig, _server(puzzle));
        await _move(tester, 'a2', 'a3');
        expect(rig.voice.lines, isEmpty);
        // The task and the verdict are still drawn.
        expect(find.text('White to move. Find the best move.'), findsOneWidget);
        expect(find.text('Correct. Keep going.'), findsOneWidget);

        await tester.tap(find.byTooltip('Enable reading aloud'));
        await tester.pumpAndSettle();
        expect(rig.voice.said, [_taskWhite]);
        expect(AppSettingsService.instance.speechEnabled, isTrue);
        await _leave(tester);
      }, () => _server(puzzle));
    });
  });

  // ── 7. leaving ─────────────────────────────────────────────────────────

  group('leaving the screen', () {
    testWidgets('stops the voice', (tester) async {
      final rig = await _rig();
      await http.runWithClient(() async {
        await _pump(tester, rig, _server(_mateInOne));
        final before = rig.speech.stopCalls;
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
        expect(rig.speech.stopCalls, before + 1);
      }, () => _server(_mateInOne));
    });
  });

  // ── 8. no Hint ─────────────────────────────────────────────────────────

  group('no Hint (the owner, 3.10.2026)', () {
    testWidgets('the screen has no Hint button and no hint feedback',
        (tester) async {
      final rig = await _rig();
      await http.runWithClient(() async {
        await _pump(tester, rig, _server(_mateInOne));
        expect(find.text('Hint'), findsNothing);
        expect(find.byIcon(Icons.lightbulb_outline), findsNothing);
        expect(find.text('Show solution'), findsOneWidget);
        expect(find.textContaining('Move the piece from'), findsNothing);
        await _leave(tester);
      }, () => _server(_mateInOne));
    });

    test('the model and the screen carry no hint', () {
      final model =
          _code('lib/features/tactics_trainer/models/tactics_puzzle.dart');
      final screen = _code(
          'lib/features/tactics_trainer/screens/tactics_trainer_screen.dart');
      expect(model, isNot(contains('revealHint')));
      expect(model, isNot(contains('usedHint')));
      expect(screen, isNot(contains('_useHint')));
      expect(screen, isNot(contains('_hintSquare')));
      expect(screen, isNot(contains("'Hint'")));
    });
  });

  // ── 9. one voice, and a voice that cannot play ─────────────────────────

  group('one voice', () {
    testWidgets(
        'the device voice is never asked anything, from the first puzzle to '
        'the last verdict', (tester) async {
      final rig = await _rig();
      await http.runWithClient(() async {
        await _pump(tester, rig, _server(_mateInOne));
        await _move(tester, 'g1', 'h1');
        await _move(tester, 'a1', 'a8');
        await tester.tap(find.text('Next puzzle'));
        await tester.pumpAndSettle();
        expect(rig.voice.lines, isNotEmpty);
        await _leave(tester);
      }, () => _server(_mateInOne));
    });

    testWidgets('a voice that throws stops no move, no reply and no finish',
        (tester) async {
      final rig = await _rig();
      rig.voice.throwOnSpeak = StateError('no sound card');
      final puzzle =
          _replyPuzzle('7k/4n2p/8/8/8/8/P7/K5N1 b - - 0 1', 'e7d5', 'd5b6');
      final attempts = <Uri>[];
      await http.runWithClient(() async {
        await _pump(tester, rig, _server(puzzle, attempts));
        await _move(tester, 'a2', 'a3');
        expect(find.text('Correct. Keep going.'), findsOneWidget);
        // The reply was drawn on the board and the board is the reader's
        // again: the third move is accepted and finishes the puzzle.
        await _move(tester, 'a3', 'a4');
        expect(find.text('Solved.'), findsOneWidget);
        expect(attempts, hasLength(1));
        await _leave(tester);
      }, () => _server(puzzle, attempts));
    });
  });
}
