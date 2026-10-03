// The screen half of phase 2's gate — `docs/PLAN-GOVOR-IZ-KLIPOVA.md`: the
// pilot screen (`AiStudioScreen`, puzzle mode) speaks the table of D3 through
// `SpeechService.speakLine`, and what it speaks is what it draws (D4).
//
// The pure half — `SpokenLine`, `MoveWords` and `ClipVoice.stitch` — is
// `spoken_line_test.dart`. Here the screen is the real one, the engine is
// never asked (a puzzle's replies come out of its own solution tree, a drill's
// out of the puzzle's `moves`), the server is a `MockClient`, and the voice is
// a fake `ClipVoice` that records the `SpokenLine`s it was handed, so the
// cases assert **token ids**, not bytes. One case uses the real `ClipVoice`
// with the real clips from `rootBundle` and a fake `ClipPlayer`, and reads the
// bytes.
//
// Positions are chosen so that nothing else on the screen can mistake them:
// the reply a puzzle plays is whatever its solution tree says, and the
// reader's own move is a pawn push that no position here makes a rule of.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/speech/clip_voice.dart';
import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/core/speech/vocabulary.dart';
import 'package:chess_app/core/speech/wav_clip.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/ai_studio_screen.dart';
import 'package:chess_app/screens/settings_screen.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';

import 'support/landscape.dart';

final _session = UserSession(
    id: 1, token: 'tok', email: 'e@x.com', name: 'N', role: 'ucenik');

// ── fakes ────────────────────────────────────────────────────────────────

/// A clip voice that records the lines it was asked to speak.
class _FakeClipVoice extends ClipVoice {
  _FakeClipVoice();

  final List<SpokenLine> lines = [];
  int stops = 0;

  /// When set, `speak` does not finish until this completes.
  Completer<void>? hold;

  /// When set, `speak` throws it — a voice that cannot play.
  Object? throwOnSpeak;

  /// Each line as the ids of its tokens, which is what the cases compare.
  List<String> get said =>
      [for (final l in lines) l.tokens.map((t) => t.id).join(' ')];

  @override
  Future<void> load(AssetBundle bundle) async {}

  @override
  Future<void> speak(SpokenLine line) {
    lines.add(line);
    final error = throwOnSpeak;
    if (error != null) throw error;
    return hold?.future ?? Future<void>.value();
  }

  @override
  Future<void> stop() async => stops++;
}

/// The service, counting the stops it is asked for.
class _CountingSpeech extends SpeechService {
  _CountingSpeech() : super.forSubclass();

  int stopCalls = 0;

  @override
  Future<void> stop() {
    stopCalls++;
    return super.stop();
  }
}

/// A player that keeps the bytes it was handed.
class _RecordingPlayer implements ClipPlayer {
  final List<Uint8List> played = [];
  int stops = 0;

  @override
  Future<void> play(Uint8List wav) async => played.add(wav);

  @override
  Future<void> stop() async => stops++;
}

/// A bundle with every clip in it, one 10 ms silence each, except [missing].
class _Bundle extends AssetBundle {
  _Bundle({this.missing});

  final String? missing;

  static Uint8List _wav() {
    final pcm = Uint8List((kSpeechSampleRate * 10 ~/ 1000) * 2);
    return ClipVoice.stitch(
        SpokenLine([SpeechVocabulary.takes]),
        (_) => WavClip(
            sampleRate: kSpeechSampleRate,
            channels: 1,
            bitsPerSample: 16,
            pcm: pcm));
  }

  @override
  Future<ByteData> load(String key) async {
    if (missing != null && key == 'assets/speech/$missing.wav') {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return ByteData.sublistView(_wav());
  }

  @override
  Future<T> loadStructuredData<T>(
          String key, Future<T> Function(String value) parser) async =>
      parser('');
}

class _Rig {
  _Rig(this.speech, this.voice);

  final _CountingSpeech speech;
  final _FakeClipVoice voice;
}

/// A service on a fake device voice and a fake clip voice, switched [enabled],
/// with the setting the speaker button reads set to match.
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

Map<String, dynamic> _puzzle(String fen, Map<String, dynamic> solutions,
        {List<String> moves = const []}) =>
    {
      'puzzle_id': 't1',
      'fen': fen,
      'moves': moves,
      'solutions': solutions,
      'winning_move_uci': solutions.isEmpty ? '' : solutions.keys.first,
    };

http.Client _server(Map<String, dynamic> puzzle, [List<Uri>? asked]) =>
    MockClient((request) async {
      asked?.add(request.url);
      final path = request.url.path;
      if (request.method == 'GET' && path.endsWith('/api/puzzles/next')) {
        return http.Response(
            jsonEncode({'puzzle': puzzle, 'userRating': 1500}), 200,
            headers: {'content-type': 'application/json'});
      }
      if (path.endsWith('/api/puzzles/submit')) {
        return http.Response('{"ratingChange":5,"newRating":1505}', 200);
      }
      return http.Response('{}', 200);
    });

// ── the screen ───────────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester,
  SpeechService speech, {
  String category = 'mate_puzzle',
  String depth = '2',
  Size size = const Size(800, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: AiStudioScreen(
        userSession: _session,
        initialCategory: category,
        mateDepth: depth,
        speech: speech,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Leaves the screen, so its timers are gone before the test ends.
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _tapSquare(WidgetTester tester, String square) async {
  final rect = tester.getRect(find.byType(SkinnedChessBoard).first);
  final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = int.parse(square.substring(1));
  final size = rect.width / 8;
  await tester.tapAt(rect.topLeft +
      Offset(file * size + size / 2, (8 - rank) * size + size / 2));
  await tester.pump();
}

Future<void> _move(WidgetTester tester, String from, String to) async {
  await _tapSquare(tester, from);
  await _tapSquare(tester, to);
}

/// The reader plays [from]→[to], and the screen has time to answer.
Future<void> _moveAndWait(WidgetTester tester, String from, String to) async {
  await _move(tester, from, to);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 1200));
  await tester.pump();
}

/// A mate in two whose reply is [reply]: the reader pushes a pawn, the puzzle
/// answers with [reply], and the reader would then push it again.
Map<String, dynamic> _replyPuzzle(String fen, String reply,
        {String user = 'a2a3', String next = 'a3a4'}) =>
    _puzzle(fen, {
      user: {
        reply: {next: 'CHECKMATE'}
      }
    });

const _taskMate2 = 'white_to_move mate_in n_2';
const _keepGoing = 'correct_keep_going';

void main() {
  setUpAll(loadRoboto);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── 1. the task, drawn and spoken ──────────────────────────────────────

  group('a puzzle appears', () {
    testWidgets(
        'the task is spoken, and the title is the line it was spoken '
        'from (D4)', (tester) async {
      final rig = await _rig();
      await http.runWithClient(() async {
        await _pump(tester, rig.speech);
        expect(rig.voice.said, [_taskMate2]);
        expect(rig.voice.lines.single.text, 'White to move. Mate in 2.');
        // The sentence the screen draws is the sentence it spoke — once, and
        // with no emoji in it: the side is an icon beside the text.
        expect(find.text(rig.voice.lines.single.text), findsOneWidget);
        expect(find.textContaining('⚪'), findsNothing);
        expect(find.textContaining('⚫'), findsNothing);
        expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
        await _leave(tester);
      },
          () => _server(
              _puzzle('7k/7p/8/8/8/8/P7/K7 w - - 0 1', {'a2a3': 'CHECKMATE'})));
    });

    testWidgets('Black to move, and Find the winning path, are said as such',
        (tester) async {
      final rig = await _rig();
      await http.runWithClient(() async {
        await _pump(tester, rig.speech, category: 'winning_position');
        expect(rig.voice.said, ['black_to_move find_winning_path']);
        expect(
            find.text('Black to move. Find the winning path.'), findsOneWidget);
        expect(find.byIcon(Icons.circle), findsWidgets);
        await _leave(tester);
      }, () => _server(_puzzle('7k/7p/8/8/8/8/P7/K7 b - - 0 1', {})));
    });

    testWidgets('the next puzzle is spoken again, even in the same words',
        (tester) async {
      final rig = await _rig();
      await http.runWithClient(() async {
        await _pump(tester, rig.speech);
        expect(rig.voice.said, [_taskMate2]);
        // "Next" is the filled button under the board (phase 1 of
        // docs/PLAN-EKRANI.md; it was "Next Position" in the header).
        final next = find.widgetWithText(FilledButton, 'Next');
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(rig.voice.said, [_taskMate2, _taskMate2]);
        await _leave(tester);
      },
          () => _server(
              _puzzle('7k/7p/8/8/8/8/P7/K7 w - - 0 1', {'a2a3': 'CHECKMATE'})));
    });

    testWidgets('the same puzzle drawn again is not spoken again',
        (tester) async {
      final rig = await _rig();
      await http.runWithClient(() async {
        await _pump(tester, rig.speech);
        expect(rig.voice.said, [_taskMate2]);
        // Held sideways, the screen draws the same task in another header.
        tester.view.physicalSize = const Size(1000, 700);
        await tester.pumpAndSettle();
        expect(find.text('White to move. Mate in 2.'), findsOneWidget);
        // Back upright, and drawn a third time.
        tester.view.physicalSize = const Size(800, 900);
        await tester.pumpAndSettle();
        expect(rig.voice.said, [_taskMate2]);
        await _leave(tester);
      },
          () => _server(
              _puzzle('7k/7p/8/8/8/8/P7/K7 w - - 0 1', {'a2a3': 'CHECKMATE'})));
    });
  });

  // ── 2. the opponent's reply, said by D1 ────────────────────────────────

  group('the opponent replies', () {
    // (name, position with White to move, the reader's move, the reply, the
    // tokens it must be said as, the text it must draw)
    final cases = <(String, String, String, String, String, String)>[
      (
        'a plain move',
        '7k/7p/8/3n4/8/8/P7/K5N1 w - - 0 1',
        'a2a3',
        'd5b6',
        'black_plays piece_knight sq_b6',
        'Black plays knight b6.'
      ),
      (
        'a capture says takes, and the square after it',
        '7k/7p/8/8/8/1K6/P7/6Nr w - - 0 1',
        'a2a3',
        'h1g1',
        'black_plays piece_rook takes sqx_g1',
        'Black plays rook takes g1.'
      ),
      (
        'a check',
        '7r/6k1/8/8/8/8/P7/4K3 w - - 0 1',
        'a2a3',
        'h8e8',
        'black_plays piece_rook sq_e8 check',
        'Black plays rook e8. Check.'
      ),
      (
        'castling',
        'r3k2r/8/8/8/8/8/P7/4K3 w kq - 0 1',
        'a2a3',
        'e8g8',
        'black_castles_kingside',
        'Black castles kingside.'
      ),
      (
        'a promotion',
        '7k/8/8/8/8/K7/3p4/8 w - - 0 1',
        'a3b4',
        'd2d1q',
        'black_plays piece_pawn sq_d1 promotes_to prom_queen',
        'Black plays pawn d1 promotes to queen.'
      ),
      (
        'an ambiguous move, with the letter of the rook that moves (D11)',
        'r6r/4k3/8/8/8/8/P7/4K3 w - - 0 1',
        'a2a3',
        'a8d8',
        'black_plays piece_rook file_a sq_d8',
        'Black plays rook a d8.'
      ),
    ];

    for (final (name, fen, user, reply, tokens, text) in cases) {
      testWidgets(name, (tester) async {
        final rig = await _rig();
        await http.runWithClient(() async {
          await _pump(tester, rig.speech);
          await _moveAndWait(
              tester, user.substring(0, 2), user.substring(2, 4));
          // The task, the verdict on the reader's move, and the reply — in
          // that order, each once.
          expect(rig.voice.said, [_taskMate2, _keepGoing, tokens]);
          expect(rig.voice.lines.last.text, text);
          await _leave(tester);
        }, () => _server(_replyPuzzle(fen, reply, user: user, next: 'h8h7')));
      });
    }

    testWidgets(
        'the reply is read off the move that was played, not off '
        'the squares of its text', (tester) async {
      final rig = await _rig();
      await http.runWithClient(() async {
        await _pump(tester, rig.speech);
        await _moveAndWait(tester, 'a2', 'a3');
        // No token anywhere is a square pair or a piece letter.
        final reply = rig.voice.lines.last;
        expect(reply.tokens.map((t) => t.id), isNot(contains('sq_d5')));
        expect(reply.text, isNot(contains('d5b6')));
        expect(reply.text, isNot(contains('d5')));
        await _leave(tester);
      },
          () => _server(
              _replyPuzzle('7k/7p/8/3n4/8/8/P7/K5N1 w - - 0 1', 'd5b6')));
    });
  });

  // ── 2b. the other defence: said first, drawn when the sentence is over ──

  group('the other defence', () {
    // A puzzle whose first move has two replies in the tree: the reader mates
    // after the first, the board goes back, and the second is announced.
    Map<String, dynamic> twoDefences() => _puzzle(
          '7k/7p/8/3n4/8/8/P7/K5N1 w - - 0 1',
          {
            'a2a3': {
              // Two defences with two different answers: defences answered
              // by the same move are folded into one by the screen.
              'd5b6': {'a3a4': 'CHECKMATE'},
              'h7h6': {'g1h3': 'CHECKMATE'},
            }
          },
        );

    String fenOnBoard(WidgetTester tester) => tester
        .widget<SkinnedChessBoard>(find.byType(SkinnedChessBoard).first)
        .controller
        .getFen();

    testWidgets(
        'the board goes back, the voice says the other defence, and the move '
        'is drawn only when the sentence has been said', (tester) async {
      final rig = await _rig();
      await http.runWithClient(() async {
        await _pump(tester, rig.speech);
        await _moveAndWait(tester, 'a2', 'a3');
        expect(rig.voice.said.last, 'black_plays piece_knight sq_b6');
        // The mating move of the first line; the verdict is said at once,
        // the supposition 600 ms later — and from here the voice is held.
        await _move(tester, 'a3', 'a4');
        await tester.pump(const Duration(milliseconds: 100));
        // „Correct." alone: the line is over and the board goes back, so
        // „Keep going." would be wrong here (the owner, 3.10.2026, [265.7]).
        expect(rig.voice.said.last, 'correct');
        final hold = Completer<void>();
        rig.voice.hold = hold;
        await tester.pump(const Duration(milliseconds: 700));
        expect(rig.voice.said.last, 'now_suppose_black_plays piece_pawn sq_h6');
        expect(rig.voice.lines.last.text, 'Now suppose Black plays pawn h6.');
        // Said, not yet drawn: the pawn is still on h7 and the board is the
        // position after the reader's first move.
        expect(fenOnBoard(tester), startsWith('7k/7p/8/3n4/8/P7/8/K5N1 b'));
        hold.complete();
        rig.voice.hold = null;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(fenOnBoard(tester), startsWith('7k/8/7p/3n4/8/P7/8/K5N1 w'));
        await _leave(tester);
      }, () => _server(twoDefences()));
    });

    testWidgets('with speech off the other defence is drawn at once',
        (tester) async {
      final rig = await _rig(enabled: false);
      await http.runWithClient(() async {
        await _pump(tester, rig.speech);
        await _moveAndWait(tester, 'a2', 'a3');
        await _move(tester, 'a3', 'a4');
        await tester.pump(const Duration(milliseconds: 800));
        expect(rig.voice.said, isEmpty);
        expect(fenOnBoard(tester), startsWith('7k/8/7p/3n4/8/P7/8/K5N1 w'));
        await _leave(tester);
      }, () => _server(twoDefences()));
    });

    testWidgets('a line queued behind another completes when it has been said',
        (tester) async {
      final rig = await _rig();
      final first = Completer<void>();
      rig.voice.hold = first;
      unawaited(rig.speech.speakLine(SpokenLine([SpeechVocabulary.checkmate])));
      var done = false;
      unawaited(rig.speech
          .speakLine(SpokenLine([SpeechVocabulary.puzzleSolved]), force: true)
          .then((_) => done = true));
      await tester.pump();
      expect(done, isFalse);
      rig.voice.hold = null;
      first.complete();
      await tester.pump();
      await tester.pump();
      expect(done, isTrue);
      expect(rig.voice.said, ['checkmate', 'puzzle_solved']);
    });
  });

  // ── 3. the verdicts ────────────────────────────────────────────────────

  group('the verdicts', () {
    testWidgets(
        'a right move that does not end the puzzle: correct, keep '
        'going', (tester) async {
      final rig = await _rig();
      await http.runWithClient(() async {
        await _pump(tester, rig.speech);
        await _moveAndWait(tester, 'a2', 'a3');
        expect(rig.voice.said[1], _keepGoing);
        expect(rig.voice.lines[1].text, 'Correct. Keep going.');
        await _leave(tester);
      },
          () => _server(
              _replyPuzzle('7k/7p/8/3n4/8/8/P7/K5N1 w - - 0 1', 'd5b6')));
    });

    testWidgets('a wrong move: incorrect, try another move', (tester) async {
      final rig = await _rig();
      await http.runWithClient(() async {
        await _pump(tester, rig.speech);
        await _move(tester, 'a2', 'a3');
        await tester.pumpAndSettle();
        // The sentence the voice says is the sentence the panel draws; it was
        // the title of a bottom sheet („Incorrect Move!").
        expect(find.text('Incorrect. Try another move.'), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        expect(rig.voice.said, [_taskMate2, 'incorrect_try_another']);
        expect(rig.voice.lines.last.text, 'Incorrect. Try another move.');
        await _leave(tester);
      },
          () => _server(
              _puzzle('7k/7p/8/8/8/8/P7/K7 w - - 0 1', {'a2a4': 'CHECKMATE'})));
    });

    testWidgets('mate delivered: checkmate, puzzle solved', (tester) async {
      final rig = await _rig();
      await http.runWithClient(() async {
        await _pump(tester, rig.speech, depth: '1');
        await _move(tester, 'a1', 'a8');
        await tester.pumpAndSettle();
        expect(rig.voice.said,
            ['white_to_move mate_in n_1', 'checkmate puzzle_solved']);
        expect(rig.voice.lines.last.text, 'Checkmate. Puzzle solved.');
        await _leave(tester);
      },
          () => _server(_puzzle(
              '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1', {'a1a8': 'CHECKMATE'})));
    });

    testWidgets(
        'the drill is lost: the reply that mates, then checkmate, '
        'Stockfish wins', (tester) async {
      final rig = await _rig();
      await http.runWithClient(() async {
        await _pump(tester, rig.speech, category: 'winning_position');
        await _moveAndWait(tester, 'b2', 'b3');
        await tester.pumpAndSettle();
        expect(find.text('Stockfish delivered checkmate. Try again.'),
            findsOneWidget);
        expect(rig.voice.said, [
          'white_to_move find_winning_path',
          'black_plays piece_rook sq_a1 checkmate',
          'checkmate stockfish_wins_try_again',
        ]);
        expect(
            rig.voice.lines.last.text, 'Checkmate. Stockfish wins. Try again.');
        await _leave(tester);
      },
          () => _server(_puzzle('r5k1/8/8/8/8/8/1P3PPP/6K1 w - - 0 1', {},
              moves: ['a8a1'])));
    });

    testWidgets(
        'the drill is drawn by stalemate: draw by stalemate, try '
        'again', (tester) async {
      final rig = await _rig();
      await http.runWithClient(() async {
        await _pump(tester, rig.speech, category: 'winning_position');
        await _moveAndWait(tester, 'a2', 'a3');
        await tester.pumpAndSettle();
        expect(find.text('The game is drawn: stalemate. Try again.'),
            findsOneWidget);
        expect(rig.voice.said, [
          'white_to_move find_winning_path',
          'black_plays piece_queen sq_g3',
          'draw_stalemate',
        ]);
        expect(rig.voice.lines.last.text, 'Draw by stalemate. Try again.');
        await _leave(tester);
      },
          () => _server(_puzzle('6k1/8/8/4q3/p7/8/P7/7K w - - 0 1', {},
              moves: ['e5g3'])));
    });

    testWidgets('a voice that throws cannot stop the move or the dialog',
        (tester) async {
      final rig = await _rig();
      rig.voice.throwOnSpeak = StateError('no sound card');
      await http.runWithClient(() async {
        await _pump(tester, rig.speech, category: 'winning_position');
        await _moveAndWait(tester, 'b2', 'b3');
        await tester.pumpAndSettle();
        expect(find.text('Stockfish delivered checkmate. Try again.'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        await _leave(tester);
      },
          () => _server(_puzzle('r5k1/8/8/8/8/8/1P3PPP/6K1 w - - 0 1', {},
              moves: ['a8a1'])));
    });
  });

  // ── 4. speech off ──────────────────────────────────────────────────────

  group('speech off', () {
    testWidgets(
        'nothing is spoken, and the speaker button turns it on and '
        'speaks the task', (tester) async {
      final rig = await _rig(enabled: false);
      await http.runWithClient(() async {
        await _pump(tester, rig.speech);
        await _moveAndWait(tester, 'a2', 'a3');
        expect(rig.voice.lines, isEmpty);
        // The title is still the sentence.
        expect(find.text('White to move. Mate in 2.'), findsOneWidget);

        await tester.tap(find.byTooltip('Enable reading aloud'));
        await tester.pumpAndSettle();
        expect(rig.voice.said, [_taskMate2]);
        expect(AppSettingsService.instance.speechEnabled, isTrue);
        await _leave(tester);
      },
          () => _server(
              _replyPuzzle('7k/7p/8/3n4/8/8/P7/K5N1 w - - 0 1', 'd5b6')));
    });
  });

  // ── 6. one queue ───────────────────────────────────────────────────────

  group('one queue (D9) — the device voice went on 3.10.2026, the queue stayed',
      () {
    test('the same line twice in a row is spoken once, unless forced',
        () async {
      final voice = _FakeClipVoice();
      final speech = SpeechService.forSubclass();
      await speech.init(enabled: true, clipVoice: voice);
      final line = SpokenLine([SpeechVocabulary.puzzleSolved]);

      await speech.speakLine(line);
      await speech.speakLine(line);
      expect(voice.lines, hasLength(1));
      await speech.speakLine(line, force: true);
      expect(voice.lines, hasLength(2));
      speech.forget();
      await speech.speakLine(line);
      expect(voice.lines, hasLength(3));
    });

    test('stop cuts a line off and covers both voices', () async {
      final voice = _FakeClipVoice();
      final speech = SpeechService.forSubclass();
      await speech.init(enabled: true, clipVoice: voice);
      await speech.stop();
      expect(voice.stops, 1);
    });
  });

  // ── 7. leaving the screen ──────────────────────────────────────────────

  group('leaving the screen', () {
    testWidgets('stops the voice', (tester) async {
      final rig = await _rig();
      await http.runWithClient(() async {
        await _pump(tester, rig.speech);
        expect(rig.speech.stopCalls, 0);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
        expect(rig.speech.stopCalls, 1);
        expect(rig.voice.stops, 1);
      },
          () => _server(
              _replyPuzzle('7k/7p/8/3n4/8/8/P7/K5N1 w - - 0 1', 'd5b6')));
    });
  });

  // ── the real clips, the real stitching, the bytes ──────────────────────

  group('the real clips', () {
    testWidgets(
        'a reply reaches the player as one RIFF file with 50 ms before '
        'its square and nothing elsewhere', (tester) async {
      final player = _RecordingPlayer();
      final voice = ClipVoice(player: player);
      final speech = SpeechService.forSubclass();
      await tester.runAsync(() async {
        await speech.init(
            enabled: true, clipVoice: voice, clipBundle: rootBundle);
        await AppSettingsService.instance.init();
        await AppSettingsService.instance.setSpeechEnabled(true);
      });
      expect(speech.state, SpeechState.ready, reason: speech.failureReason);

      // The clips as the bundle has them, read the way the app reads them.
      final clips = <String, WavClip>{};
      await tester.runAsync(() async {
        for (final id in [
          'white_to_move',
          'mate_in',
          'n_2',
          'black_plays',
          'piece_rook',
          'takes',
          'sqx_g1',
        ]) {
          final data = await rootBundle.load('assets/speech/$id.wav');
          clips[id] = WavClip.parse(Uint8List.sublistView(data))!;
        }
      });

      await http.runWithClient(() async {
        await _pump(tester, speech);
        await _moveAndWait(tester, 'a2', 'a3');
        expect(player.played, hasLength(3));

        int frames(String id) => clips[id]!.frames;
        final pause = kSpeechSampleRate * kPauseBeforeSquareMs ~/ 1000;

        // "White to move. Mate in 2." has no square: the three clips, joined.
        final task = WavClip.parse(player.played[0])!;
        expect(task.pcm.length,
            (frames('white_to_move') + frames('mate_in') + frames('n_2')) * 2);

        // "Black plays rook takes g1.": one pause, before the square.
        final reply = WavClip.parse(player.played[2])!;
        final expected = BytesBuilder();
        expected.add(clips['black_plays']!.pcm);
        expected.add(clips['piece_rook']!.pcm);
        expected.add(clips['takes']!.pcm);
        expected.add(Uint8List(pause * 2));
        expected.add(clips['sqx_g1']!.pcm);
        expect(reply.sampleRate, kSpeechSampleRate);
        expect(reply.channels, 1);
        expect(reply.bitsPerSample, 16);
        expect(
            reply.pcm.length,
            (frames('black_plays') +
                    frames('piece_rook') +
                    frames('takes') +
                    pause +
                    frames('sqx_g1')) *
                2);
        expect(reply.pcm, expected.takeBytes());
        await _leave(tester);
      },
          () => _server(
              _replyPuzzle('7k/7p/8/8/8/1K6/P7/6Nr w - - 0 1', 'h1g1')));
    });
  });

  // ── 9. a broken bundle is loud ─────────────────────────────────────────

  group('a clip missing from the bundle (D10)', () {
    test('sets failed, and the reason names the token', () async {
      final voice = _FakeClipVoiceLoading();
      final speech = SpeechService.forSubclass();
      await speech.init(
          enabled: true,
          clipVoice: voice,
          clipBundle: _Bundle(missing: 'sq_e5'));
      expect(speech.state, SpeechState.failed);
      expect(speech.failureReason, contains('sq_e5'));
      expect(speech.canSpeakNow(), isFalse);
      await speech.speakLine(SpokenLine([SpeechVocabulary.checkmate]));
      expect(voice.spoken, isEmpty);
    });

    test('a bundle with every clip is ready', () async {
      final speech = SpeechService.forSubclass();
      await speech.init(
          enabled: true,
          clipVoice: ClipVoice(player: _RecordingPlayer()),
          clipBundle: _Bundle());
      expect(speech.state, SpeechState.ready);
      expect(speech.failureReason, isNull);
    });

    test('a clip that is not a WAVE file names its token too', () async {
      final speech = SpeechService.forSubclass();
      await speech.init(
          enabled: true,
          clipVoice: ClipVoice(player: _RecordingPlayer()),
          clipBundle: _JunkBundle('n_7'));
      expect(speech.state, SpeechState.failed);
      expect(speech.failureReason, contains('n_7'));
    });

    testWidgets('Settings says it, beside the speech switch', (tester) async {
      final speech = SpeechService.instance;
      await speech.init(
          enabled: true,
          clipVoice: ClipVoice(player: _RecordingPlayer()),
          clipBundle: _Bundle(missing: 'file_c'));
      expect(speech.state, SpeechState.failed);

      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: SettingsScreen(session: _session),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      final reason = find.textContaining('file_c');
      await tester.ensureVisible(reason);
      expect(reason, findsOneWidget);

      // Leave the singleton as the other files expect to find it.
      await speech.init(
          enabled: false,
          clipVoice: ClipVoice(player: _RecordingPlayer()),
          clipBundle: _Bundle());
      await tester.pumpWidget(const SizedBox());
    });
  });
}

/// A clip voice that loads for real and records what it is asked to speak.
class _FakeClipVoiceLoading extends ClipVoice {
  _FakeClipVoiceLoading() : super(player: _RecordingPlayer());

  final List<SpokenLine> spoken = [];

  @override
  Future<void> speak(SpokenLine line) async => spoken.add(line);
}

/// A bundle whose clip [broken] is not a WAVE file.
class _JunkBundle extends _Bundle {
  _JunkBundle(this.broken);

  final String broken;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'assets/speech/$broken.wav') {
      return ByteData.sublistView(Uint8List.fromList(List.filled(64, 7)));
    }
    return super.load(key);
  }
}
