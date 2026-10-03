// Phase 4c's gate — `docs/PLAN-GOVOR-IZ-KLIPOVA.md`: the repertoire's build
// screen and its drill speak the table the owner approved on 3.10.2026 through
// `SpeechService.speakLine`, and what they speak is what they draw (D4). The
// device voice is never asked anything on either screen.
//
// Modelled on `speech_endgames_test.dart`: the screens are the real ones, the
// server is a fake service (nothing here is about the wire), and the voice is
// a fake `ClipVoice` that records the `SpokenLine`s it was handed, so the
// cases assert **token ids**, not bytes.
//
// The drawn text is each line's `.text`. Where a case pins a sentence word for
// word it pins a line whose runs are each closed by a sentence of the table's
// own; where a line is two open runs in a row (a move, then a reply that is
// also a move) the case asserts `drawn == what the voice was handed` and the
// words that are there either way, because that is what the screen owes.

import 'dart:io';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/speech/clip_voice.dart';
import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/features/analysis_studio/services/opening_explorer_service.dart';
import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_drill_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/speakable_info.dart';

// ── fakes ────────────────────────────────────────────────────────────────

/// A clip voice that records the lines it was asked to speak.
class _FakeClipVoice extends ClipVoice {
  _FakeClipVoice();

  final List<SpokenLine> lines = [];

  List<String> get said =>
      [for (final l in lines) l.tokens.map((t) => t.id).join(' ')];

  @override
  Future<void> load(AssetBundle bundle) async {}

  @override
  Future<void> speak(SpokenLine line) {
    lines.add(line);
    return Future<void>.value();
  }

  @override
  Future<void> stop() async {}
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

/// A judge with nothing behind it: the build screen must draw its question
/// without a book behind it.
class _Judge implements OpeningJudgeService {
  @override
  Future<OpeningJudgeLookup> judge(String fen, String move) async =>
      const OpeningJudgeLookup.unavailable('not-configured');

  @override
  Future<OpponentRepliesLookup> replies(String fen) async =>
      const OpponentRepliesLookup.unavailable('not-configured');

  @override
  void clearCache() {}
}

/// 1.e4 c5 2.d4 cxd4 3.c3 dxc3 4.Nxc3, Black to move.
const _smithMorra =
    'rnbqkbnr/pp1ppppp/8/8/4P3/2N5/PP3PPP/R1BQKBNR b KQkq - 0 4';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// The French Advance, Black to move — the root of the tree below.
const _advance =
    'rnbqkbnr/ppp2ppp/4p3/3pP3/3P4/8/PPP2PPP/RNBQKBNR b KQkq - 0 3';
const _afterC5 =
    'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/8/PPP2PPP/RNBQKBNR w KQkq c6 0 4';
const _afterC3 =
    'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/2P5/PP3PPP/RNBQKBNR b KQkq - 0 4';

String _keyOf(String fen) => fen.split(' ').take(4).join(' ');

/// The position after a line of SAN moves from the start of a game.
String _fenAfter(List<String> sans) {
  final board = chess.Chess();
  for (final san in sans) {
    board.move(san);
  }
  return board.fen;
}

/// The build screen's server: it remembers what was kept and entered, hands it
/// back, and refuses on request.
class _BuildApi extends RepertoireApiService {
  _BuildApi({this.walk, this.withTree = false})
      : super(client: MockClient((_) async => http.Response('{}', 500)));

  /// What the walk answers; null is a server that did not.
  RepertoireFrontier? walk;
  final bool withTree;

  final Map<String, List<RepertoireMove>> kept = {};
  final Map<String, ({String uci, String san})> topReplies = {};
  bool keepFails = false;
  bool enterFails = false;
  bool removeOpponentFails = false;

  @override
  Future<RepertoireFrontier?> frontier({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    String? gateUci,
  }) async =>
      walk;

  @override
  Future<List<RepertoireMove>> movesAt({
    required String color,
    required String fen,
  }) async =>
      List.of(kept[_keyOf(fen)] ?? const []);

  @override
  Future<({bool saved, ({String uci, String san, String fen})? topReply})>
      keepMove({
    required String color,
    required String fen,
    required String uci,
    required String san,
    String? verdict,
  }) async {
    if (keepFails) return (saved: false, topReply: null);
    final list = kept.putIfAbsent(_keyOf(fen), () => []);
    list.add(RepertoireMove(
      uci: uci,
      san: san,
      role: list.isEmpty ? 'primary' : 'alternate',
    ));
    final top = topReplies[uci];
    if (top == null) return (saved: true, topReply: null);
    final board = chess.Chess.fromFEN(fen)
      ..move({'from': uci.substring(0, 2), 'to': uci.substring(2, 4)});
    return (
      saved: true,
      topReply: (uci: top.uci, san: top.san, fen: board.fen),
    );
  }

  @override
  Future<bool> addOpponentMove({
    required String color,
    required String fen,
    required String uci,
    String? san,
  }) async =>
      !enterFails;

  @override
  Future<bool> removeOpponentMove({
    required String color,
    required String fen,
    required String uci,
  }) async =>
      !removeOpponentFails;

  @override
  Future<({List<String> keys, int decisions})?> orphansOfRemoving({
    required String color,
    required String fen,
    required String uci,
  }) async =>
      (keys: const <String>[], decisions: 0);

  @override
  Future<void> recordAttempt({
    required String color,
    required String fen,
    required String uci,
    String? san,
    String? verdict,
    bool kept = false,
    bool lookedUp = false,
  }) async {}

  @override
  Future<RepertoireTree?> repertoireTree({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int maxPly = 16,
    String? gateUci,
  }) async =>
      withTree
          ? const RepertoireTree(
              rootFen: _advance,
              rootPath: ['e4', 'e6', 'd4', 'd5', 'e5'],
              children: [
                RepertoireTreeMove(
                  uci: 'c7c5',
                  san: 'c5',
                  fen: _afterC5,
                  mine: true,
                  role: 'primary',
                  children: [
                    RepertoireTreeMove(
                      uci: 'c2c3',
                      san: 'c3',
                      fen: _afterC3,
                      mine: false,
                      share: 0.64,
                      state: 'open',
                    ),
                  ],
                ),
              ],
            )
          : null;
}

/// The drill's server: one question, or none, and an answer from a table.
class _DrillApi extends RepertoireApiService {
  _DrillApi({this.item = _smithMorra, this.stats = _stats})
      : super(client: MockClient((_) async => http.Response('{}', 500)));

  static const _stats = DrillStats(positions: 6, due: 2, known: 1, fresh: 3);

  static const primary = RepertoireMove(
    uci: 'b8c6',
    san: 'Nc6',
    role: 'primary',
  );

  final String? item;
  final DrillStats stats;

  /// What `drillLine` answers; null is a server that did not.
  DrillLine? line;
  final Map<String?, DrillLine?> linesByVia = {};

  /// What `answerDrill` answers. Null grades the move against [primary].
  DrillAnswer? answer;

  @override
  Future<List<DrillBranch>> drillBranches({
    required String color,
    String? rootFen,
    List<String> rootPath = const [],
    String? gateUci,
    String? breadth,
    List<int>? ids,
  }) async =>
      const [];

  @override
  Future<DrillLine?> drillLine({
    required String color,
    String? rootFen,
    List<String> rootPath = const [],
    String? fromFen,
    String? viaFen,
    String? viaUci,
    List<String> exclude = const [],
    bool ahead = false,
    String? gateUci,
    String? breadth,
    List<int>? ids,
  }) async {
    if (linesByVia.containsKey(viaUci)) return linesByVia[viaUci];
    return line;
  }

  @override
  Future<({DrillItem? item, DrillStats stats})> nextDrill(
          {required String color}) async =>
      (
        item: item == null
            ? null
            : DrillItem(fen: item!, fresh: false, repetitions: 3, moves: 2),
        stats: stats,
      );

  @override
  Future<RepertoireMove?> revealDrill({
    required String color,
    required String fen,
  }) async =>
      primary;

  @override
  Future<DrillAnswer?> answerDrill({
    required String color,
    required String fen,
    required String uci,
    bool revealed = false,
    bool practice = false,
    bool onlyIfDue = false,
  }) async =>
      answer ??
      DrillAnswer(
        outcome: uci == 'b8c6' ? 'primary' : 'unknown',
        primary: primary,
        intervalDays: 1,
        reply: 'g1f3',
      );
}

/// An answer to the drill, with the parts a case varies.
DrillAnswer _answer(
  String outcome, {
  bool withPrimary = true,
  int? days,
  String? reply,
  bool covered = true,
  bool practice = false,
}) =>
    DrillAnswer(
      outcome: outcome,
      primary:
          withPrimary && outcome != 'unprepared' ? _DrillApi.primary : null,
      intervalDays: days,
      reply: reply,
      replyCovered: covered,
      practice: practice,
    );

// ── driving the screens ──────────────────────────────────────────────────

Future<void> _pumpBuild(
  WidgetTester tester,
  _Rig rig,
  _BuildApi api, {
  String color = 'b',
  String rootFen = _smithMorra,
  Size size = const Size(500, 1000),
  Future<List<AnalysisLine>> Function(String, int, int)? analyse,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: RepertoireBuildScreen(
      key: UniqueKey(),
      name: 'Gate',
      color: color,
      rootFen: rootFen,
      api: api,
      judge: _Judge(),
      explore: (fen) async => OpeningExplorerLookup.ok(OpeningExplorerResult(
          fen: fen, white: 0, draws: 0, black: 0, moves: const [])),
      analyse: analyse ?? (fen, depth, multiPV) async => const [],
      speech: rig.speech,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _pumpDrill(
  WidgetTester tester,
  _Rig rig,
  _DrillApi api, {
  String color = 'b',
  String? rootFen,
  String? fromFen,
  Size size = const Size(500, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: RepertoireDrillScreen(
      key: UniqueKey(),
      name: 'Gate',
      color: color,
      rootFen: rootFen,
      fromFen: fromFen,
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

/// Lets the drill's walk-on beat run out.
Future<void> _walkOn(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pumpAndSettle();
}

/// The source of [path] with its `//` comment lines taken out, so a word the
/// code explains is not mistaken for a word the code uses.
String _code(String path) => File(path)
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

/// The argument list of every `SpeakableInfo(` in [source], read by matching
/// the brackets (strings skipped, so a bracket in a sentence is not one), each
/// reduced to what stands at its own top level — the named arguments and
/// nothing a nested widget passes.
List<String> _speakableCalls(String source) {
  final calls = <String>[];
  var from = 0;
  while (true) {
    final at = source.indexOf('SpeakableInfo(', from);
    if (at < 0) return calls;
    from = at + 'SpeakableInfo('.length;
    // `SpeakableInfo(` inside a longer name, such as `_NotSpeakableInfo(`.
    if (at > 0 && RegExp(r'[A-Za-z0-9_]').hasMatch(source[at - 1])) continue;
    var depth = 1;
    final top = StringBuffer();
    var i = from;
    while (i < source.length && depth > 0) {
      final c = source[i];
      if (c == "'" || c == '"') {
        final quote = c;
        i++;
        while (i < source.length && source[i] != quote) {
          if (source[i] == r'\') i++;
          i++;
        }
        i++;
        if (depth == 1) top.write('<string>');
        continue;
      }
      if (c == '(' || c == '[' || c == '{') depth++;
      if (c == ')' || c == ']' || c == '}') depth--;
      if (depth == 1 && c != ')') top.write(c);
      i++;
    }
    calls.add(top.toString());
  }
}

const _qBlack = 'what_play_black';
const _qWhite = 'what_play_white';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── Build ──────────────────────────────────────────────────────────────

  group('build: a position asks for your move', () {
    testWidgets('Black: said and drawn once, in the clips\' own words',
        (tester) async {
      final rig = await _rig();
      final api = _BuildApi(
          walk: const RepertoireFrontier(
              decided: 0, open: [FrontierNode(fen: _smithMorra, path: [])]));
      await _pumpBuild(tester, rig, api);

      expect(rig.voice.said, [_qBlack]);
      expect(rig.voice.lines.single.text, 'What do you play with Black?');
      expect(find.text('What do you play with Black?'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('White: the same question, the other side', (tester) async {
      final rig = await _rig();
      final api = _BuildApi(
          walk: const RepertoireFrontier(
              decided: 0, open: [FrontierNode(fen: _start, path: [])]));
      await _pumpBuild(tester, rig, api, color: 'w', rootFen: _start);

      expect(rig.voice.said, [_qWhite]);
      expect(find.text('What do you play with White?'), findsOneWidget);
      expect(find.text('What do you play with Black?'), findsNothing);
      await _leave(tester);
    });

    testWidgets('the same question is not said again for a new position',
        (tester) async {
      // Spoken when it becomes a different question, as it always was: two
      // positions in a row ask the same thing and the voice says it once.
      final rig = await _rig();
      final api = _BuildApi(
          walk: RepertoireFrontier(decided: 0, open: [
        const FrontierNode(fen: _smithMorra, path: []),
        FrontierNode(fen: _fenAfter(['e4', 'c5', 'Nf3']), path: const ['Nf3']),
      ]));
      await _pumpBuild(tester, rig, api);
      expect(rig.voice.said, [_qBlack]);

      await tester.ensureVisible(find.text('Next position'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next position'));
      await tester.pumpAndSettle();
      expect(rig.voice.said, [_qBlack]);
      await _leave(tester);
    });
  });

  group('build: standing on your move', () {
    testWidgets('says which opponent moves to prepare, naming the move',
        (tester) async {
      final rig = await _rig();
      final api = _BuildApi(
          walk: const RepertoireFrontier(
              decided: 0, open: [FrontierNode(fen: _smithMorra, path: [])]))
        ..kept[_keyOf(_smithMorra)] = [
          const RepertoireMove(uci: 'b8c6', san: 'Nc6', role: 'primary'),
        ];
      await _pumpBuild(tester, rig, api);

      await _play(tester, 'b8', 'c6');

      expect(rig.voice.said, [
        _qBlack,
        'after_head piece_knight sq_c6 which_opponent_moves',
      ]);
      // No comma and no dash: the drawn text is the line's own.
      expect(rig.voice.lines.last.text,
          'After knight c6 which opponent moves do you prepare?');
      expect(find.text(rig.voice.lines.last.text), findsOneWidget);
      await _leave(tester);
    });
  });

  group('build: a move of yours is saved', () {
    testWidgets('with a reply in the book: the move, then the reply',
        (tester) async {
      final rig = await _rig();
      final api = _BuildApi(
          walk: const RepertoireFrontier(
              decided: 0, open: [FrontierNode(fen: _smithMorra, path: [])]))
        ..topReplies['b8c6'] = (uci: 'g1f3', san: 'Nf3');
      await _pumpBuild(tester, rig, api);

      await _play(tester, 'b8', 'c6');

      expect(rig.voice.said, [
        _qBlack,
        'piece_knight sq_c6 is_in_your_repertoire most_played_reply_is '
            'piece_knight sq_f3',
      ]);
      expect(
          find.text('Knight c6 is in your repertoire. '
              'The most played reply is knight f3.'),
          findsOneWidget);
      expect(rig.voice.lines.last.text,
          'Knight c6 is in your repertoire. The most played reply is knight f3.');
      await _leave(tester);
    });

    testWidgets('with the book silent: it says so, and what to do',
        (tester) async {
      final rig = await _rig();
      final api = _BuildApi(
          walk: const RepertoireFrontier(
              decided: 0, open: [FrontierNode(fen: _smithMorra, path: [])]));
      await _pumpBuild(tester, rig, api);

      await _play(tester, 'b8', 'c6');

      expect(rig.voice.said, [
        _qBlack,
        'after_head piece_knight sq_c6 which_opponent_moves',
        'piece_knight sq_c6 is_in_your_repertoire book_no_reply',
      ]);
      expect(
          find.text('Knight c6 is in your repertoire. '
              'The book has no reply here. '
              'Play the opponent move you want to prepare.'),
          findsOneWidget);
      // The old note's own sentence is gone, not drawn beside the new one.
      expect(find.textContaining('is in your repertoire, with'), findsNothing);
      await _leave(tester);
    });

    testWidgets('a castling move is said whole, without a second "plays"',
        (tester) async {
      // The side is part of a castling move's own words, so it has no head to
      // drop and is said as it stands.
      const castle = 'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R b KQkq - 0 1';
      final rig = await _rig();
      final api = _BuildApi(
          walk: const RepertoireFrontier(
              decided: 0, open: [FrontierNode(fen: castle, path: [])]));
      await _pumpBuild(tester, rig, api, rootFen: castle);

      // Black castles kingside through the king's two-square step.
      await _play(tester, 'e8', 'g8');

      expect(rig.voice.said.last,
          'black_castles_kingside is_in_your_repertoire book_no_reply',
          reason: 'one token carries the side and the move');
      await _leave(tester);
    });
  });

  group('build: everything is answered', () {
    testWidgets('one sentence, said on arrival; the long line under it is gone',
        (tester) async {
      final rig = await _rig();
      final api = _BuildApi(
          walk: const RepertoireFrontier(decided: 4, open: <FrontierNode>[]));
      await _pumpBuild(tester, rig, api);

      expect(rig.voice.said, ['answered_every_position']);
      expect(find.text('You have answered every position in this repertoire.'),
          findsOneWidget);
      expect(find.textContaining('Everything is saved'), findsNothing);
      expect(find.textContaining('goes deeper'), findsNothing);

      // The speaker beside it plays the same line again, once.
      await tester.tap(find.byTooltip('Read aloud'));
      await tester.pumpAndSettle();
      expect(rig.voice.said,
          ['answered_every_position', 'answered_every_position']);
      await _leave(tester);
    });
  });

  group('build: a server or an engine that did not answer', () {
    testWidgets('the save of your own move', (tester) async {
      final rig = await _rig();
      final api = _BuildApi(
          walk: const RepertoireFrontier(
              decided: 0, open: [FrontierNode(fen: _smithMorra, path: [])]))
        ..keepFails = true;
      await _pumpBuild(tester, rig, api);

      await _play(tester, 'b8', 'c6');

      expect(rig.voice.said, [_qBlack, 'move_not_saved']);
      expect(find.text('The move was not saved. The server did not respond.'),
          findsOneWidget);
      expect(find.textContaining('— server did not respond'), findsNothing);
      // The board went back to the question it was asking.
      expect(find.text('What do you play with Black?'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('the save of an opponent move', (tester) async {
      final rig = await _rig();
      final api = _BuildApi(
          walk: const RepertoireFrontier(
              decided: 0, open: [FrontierNode(fen: _smithMorra, path: [])]))
        ..kept[_keyOf(_smithMorra)] = [
          const RepertoireMove(uci: 'b8c6', san: 'Nc6', role: 'primary'),
        ]
        ..enterFails = true;
      await _pumpBuild(tester, rig, api);
      await _play(tester, 'b8', 'c6');
      final before = rig.voice.said.length;

      await _play(tester, 'g1', 'f3');

      expect(rig.voice.said.sublist(before), ['opponent_move_not_saved']);
      expect(
          find.text(
              'The opponent move was not saved. The server did not respond.'),
          findsOneWidget);
      await _leave(tester);
    });

    testWidgets('the removal of an opponent move', (tester) async {
      final rig = await _rig();
      final api = _BuildApi(
          walk: const RepertoireFrontier(
              decided: 1, open: [FrontierNode(fen: _advance, path: [])]),
          withTree: true)
        ..removeOpponentFails = true;
      await _pumpBuild(tester, rig, api,
          rootFen: _advance, size: const Size(1400, 900));
      final before = rig.voice.said.length;

      await tester.longPress(find.text('4. c3 64% ?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete this opponent move'));
      await tester.pumpAndSettle();

      expect(rig.voice.said.sublist(before), ['opponent_move_not_removed']);
      expect(
          find.text(
              'The opponent move was not removed. The server did not respond.'),
          findsOneWidget);
      await _leave(tester);
    });

    testWidgets('the engine that said nothing', (tester) async {
      final rig = await _rig();
      final api = _BuildApi(
          walk: const RepertoireFrontier(
              decided: 0, open: [FrontierNode(fen: _smithMorra, path: [])]));
      await _pumpBuild(tester, rig, api);

      await tester.tap(find.text('Ask engine'));
      await tester.pumpAndSettle();

      expect(rig.voice.said, [_qBlack, 'engine_no_response']);
      expect(find.text('The engine did not respond in time.'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('the progress that could not be read', (tester) async {
      final rig = await _rig();
      final api = _BuildApi();
      await _pumpBuild(tester, rig, api);

      // Both lines are said and neither is lost; the one-slot queue keeps the
      // newer of two waiting, and two is what this arrival makes.
      expect(rig.voice.said, unorderedEquals([_qBlack, 'progress_not_read']));
      expect(
          find.text(
              'Could not read your progress. Starting from the opening position.'),
          findsOneWidget);
      expect(find.textContaining('repertoire opening position'), findsNothing);
      await _leave(tester);
    });
  });

  // ── Drill ──────────────────────────────────────────────────────────────

  group('drill: a position asks', () {
    testWidgets('Black: one sentence, and the second one is deleted',
        (tester) async {
      final rig = await _rig();
      await _pumpDrill(tester, rig, _DrillApi());

      expect(rig.voice.said, [_qBlack]);
      expect(rig.voice.lines.single.text, 'What do you play with Black?');
      expect(find.text('What do you play with Black?'), findsOneWidget);
      expect(find.textContaining('Play the move you chose'), findsNothing);
      await _leave(tester);
    });

    testWidgets('White: the other side', (tester) async {
      final rig = await _rig();
      await _pumpDrill(tester, rig, _DrillApi(item: _start), color: 'w');

      expect(rig.voice.said, [_qWhite]);
      expect(find.text('What do you play with White?'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('Show: your move as a move, and the question is not repeated',
        (tester) async {
      final rig = await _rig();
      await _pumpDrill(tester, rig, _DrillApi());

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(rig.voice.said, [
        _qBlack,
        'your_move_is piece_knight sq_c6 play_it',
      ]);
      expect(rig.voice.lines.last.text, 'Your move is knight c6. Play it.');
      expect(find.text('Your move is knight c6. Play it.'), findsOneWidget);
      expect(find.text('What do you play with Black?'), findsOneWidget);
      await _leave(tester);
    });
  });

  group('drill: the verdict', () {
    testWidgets('correct, a covered reply, and it returns tomorrow',
        (tester) async {
      final rig = await _rig();
      final api = _DrillApi()
        ..answer = _answer('primary', days: 1, reply: 'g1f3');
      await _pumpDrill(tester, rig, api);

      await _play(tester, 'b8', 'c6');

      expect(rig.voice.said, [
        _qBlack,
        'correct white_plays piece_knight sq_f3 returns_tomorrow',
      ]);
      expect(rig.voice.lines.last.text,
          'Correct. White plays knight f3. Returns tomorrow.');
      expect(find.text('Correct. White plays knight f3. Returns tomorrow.'),
          findsOneWidget);
      // The title with the move the student played is gone: the line says it.
      expect(find.textContaining('Correct —'), findsNothing);
      await _leave(tester);
    });

    testWidgets('how long until it returns, in every form', (tester) async {
      // Derived from the rounding's own bands, not from round numbers: days
      // under a week are days, under thirty are weeks rounded, and past that
      // months rounded; one week and one month have words of their own.
      final table = <(int?, String, String?)>[
        (null, '', null),
        (0, 'returns_minutes', 'Returns in a few minutes.'),
        (1, 'returns_tomorrow', 'Returns tomorrow.'),
        (3, 'returns_in nmid_3 days_tail', 'Returns in 3 days.'),
        (6, 'returns_in nmid_6 days_tail', 'Returns in 6 days.'),
        (7, 'returns_week', 'Returns in a week.'),
        (10, 'returns_week', 'Returns in a week.'),
        (14, 'returns_in nmid_2 weeks_tail', 'Returns in 2 weeks.'),
        (20, 'returns_in nmid_3 weeks_tail', 'Returns in 3 weeks.'),
        (29, 'returns_in nmid_4 weeks_tail', 'Returns in 4 weeks.'),
        (30, 'returns_month', 'Returns in a month.'),
        (44, 'returns_month', 'Returns in a month.'),
        (45, 'returns_in nmid_2 months_tail', 'Returns in 2 months.'),
        (90, 'returns_in nmid_3 months_tail', 'Returns in 3 months.'),
      ];
      for (final (days, ids, drawn) in table) {
        final rig = await _rig();
        final api = _DrillApi()..answer = _answer('primary', days: days);
        await _pumpDrill(tester, rig, api);

        await _play(tester, 'b8', 'c6');

        final expected = ids.isEmpty ? 'correct' : 'correct $ids';
        expect(rig.voice.said.last, expected, reason: 'days: $days');
        if (drawn != null) {
          expect(rig.voice.lines.last.text, 'Correct. $drawn',
              reason: 'days: $days');
          expect(find.text('Correct. $drawn'), findsOneWidget,
              reason: 'days: $days');
        } else {
          expect(find.text('Correct.'), findsOneWidget);
        }
        await _leave(tester);
      }
    });

    testWidgets('also yours: the main move, the reply, when it returns',
        (tester) async {
      final rig = await _rig();
      final api = _DrillApi()
        ..answer = _answer('alternate', days: 1, reply: 'g1f3');
      await _pumpDrill(tester, rig, api);

      await _play(tester, 'd7', 'd6');

      expect(rig.voice.said.last,
          'also_yours your_main_move_is piece_knight sq_c6 white_plays piece_knight sq_f3 returns_tomorrow');
      final text = rig.voice.lines.last.text;
      expect(text, startsWith('Also yours. Your main move is knight c6'));
      expect(text, contains('knight f3'));
      expect(text, endsWith('Returns tomorrow.'));
      expect(find.text(text), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('also yours with no main move to name', (tester) async {
      final rig = await _rig();
      final api = _DrillApi()
        ..answer = _answer('alternate', withPrimary: false, days: 1);
      await _pumpDrill(tester, rig, api);

      await _play(tester, 'd7', 'd6');

      expect(
          rig.voice.said.last, 'also_yours your_main_move_is returns_tomorrow',
          reason: 'what is not known is not said');
      await _leave(tester);
    });

    testWidgets('incorrect: the move that was wanted, and no reply',
        (tester) async {
      final rig = await _rig();
      final api = _DrillApi()
        ..answer = _answer('unknown', days: 0, reply: 'g1f3');
      await _pumpDrill(tester, rig, api);

      await _play(tester, 'g8', 'f6');

      expect(rig.voice.said.last,
          'incorrect your_move_is piece_knight sq_c6 returns_minutes');
      expect(rig.voice.lines.last.text,
          'Incorrect. Your move is knight c6. Returns in a few minutes.');
      expect(find.textContaining('Incorrect —'), findsNothing);
      await _leave(tester);
    });

    testWidgets('incorrect with no move to name', (tester) async {
      final rig = await _rig();
      final api = _DrillApi()
        ..answer = _answer('unknown', withPrimary: false, days: 1);
      await _pumpDrill(tester, rig, api);

      await _play(tester, 'g8', 'f6');

      expect(rig.voice.said.last, 'incorrect your_move_is returns_tomorrow');
      await _leave(tester);
    });

    testWidgets('a position you never covered', (tester) async {
      final rig = await _rig();
      final api = _DrillApi()..answer = _answer('unprepared');
      await _pumpDrill(tester, rig, api);

      await _play(tester, 'b8', 'c6');

      expect(rig.voice.said.last, 'not_covered_position');
      expect(
          find.text('You have not covered this position. '
              'Open build to decide what you play.'),
          findsOneWidget);
      expect(find.textContaining('so no rating'), findsNothing);
      await _leave(tester);
    });

    testWidgets('a reply you never covered, in the same line', (tester) async {
      final rig = await _rig();
      final api = _DrillApi()
        ..answer = _answer('primary', days: 6, reply: 'a2a3', covered: false);
      await _pumpDrill(tester, rig, api);

      await _play(tester, 'b8', 'c6');

      expect(
          rig.voice.said.last,
          'correct white_plays piece_pawn sq_a3 not_covered_reply '
          'returns_in nmid_6 days_tail');
      expect(
          find.text('Correct. White plays pawn a3. '
              'You have not covered this reply. Returns in 6 days.'),
          findsOneWidget);
      // And it stops there, as it always did: no question follows it.
      await _walkOn(tester);
      expect(rig.voice.said, hasLength(2));
      expect(find.text('Continue line'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('ahead of schedule is appended to the line, nothing drawn long',
        (tester) async {
      final rig = await _rig();
      final api = _DrillApi()
        ..answer = _answer('primary', practice: true, reply: 'g1f3');
      await _pumpDrill(tester, rig, api);

      await _play(tester, 'b8', 'c6');

      expect(rig.voice.said.last,
          'correct white_plays piece_knight sq_f3 ahead_of_schedule');
      expect(
          find.text('Correct. White plays knight f3. '
              'Ahead of schedule. The rating is not recorded.'),
          findsOneWidget);
      expect(find.textContaining('Drill ahead of schedule'), findsNothing);
      expect(find.textContaining('Returns'), findsNothing);
      await _leave(tester);
    });

    testWidgets('ahead of schedule on a position never covered',
        (tester) async {
      final rig = await _rig();
      final api = _DrillApi()..answer = _answer('unprepared', practice: true);
      await _pumpDrill(tester, rig, api);

      await _play(tester, 'b8', 'c6');

      expect(rig.voice.said.last, 'not_covered_position ahead_of_schedule');
      await _leave(tester);
    });
  });

  group('drill: walking on', () {
    testWidgets('the next question speaks and no verdict is repeated',
        (tester) async {
      final rig = await _rig();
      final api = _DrillApi()
        ..answer = _answer('primary', days: 6, reply: 'g1f3');
      await _pumpDrill(tester, rig, api);

      await _play(tester, 'b8', 'c6');
      final verdict = rig.voice.said.last;
      expect(verdict, startsWith('correct '));

      await _walkOn(tester);

      expect(rig.voice.said, [_qBlack, verdict, _qBlack],
          reason: 'one verdict, said once, when its panel was drawn');
      // Nothing the old walk carried: neither the string nor its words.
      expect(find.textContaining('opponent f3'), findsNothing);
      expect(find.textContaining('returns in 6 days'), findsNothing);
      expect(find.textContaining('Correct'), findsNothing);
      expect(find.text('What do you play with Black?'), findsOneWidget);
      await _leave(tester);
    });
  });

  group('drill: nothing to do', () {
    testWidgets('nothing due, and nothing built yet', (tester) async {
      var rig = await _rig();
      await _pumpDrill(
          tester,
          rig,
          _DrillApi(
              item: null,
              stats:
                  const DrillStats(positions: 20, due: 0, known: 9, fresh: 0)));
      expect(rig.voice.said, ['nothing_due']);
      expect(find.text('Nothing due.'), findsOneWidget);
      await _leave(tester);

      rig = await _rig();
      await _pumpDrill(
          tester,
          rig,
          _DrillApi(
              item: null,
              stats:
                  const DrillStats(positions: 0, due: 0, known: 0, fresh: 0)));
      expect(rig.voice.said, ['nothing_to_drill_yet']);
      expect(find.text('Nothing to drill yet.'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('nothing due in a branch, and nothing built in it',
        (tester) async {
      var rig = await _rig();
      var api = _DrillApi()
        ..line = const DrillLine(
          reason: 'nothing-due',
          stats: DrillStats(positions: 1, due: 0, known: 0, fresh: 0),
        );
      await _pumpDrill(tester, rig, api,
          rootFen: _smithMorra, fromFen: _smithMorra);
      expect(rig.voice.said, ['nothing_due_branch']);
      expect(find.text('Nothing due in this branch.'), findsOneWidget);
      await _leave(tester);

      rig = await _rig();
      api = _DrillApi()
        ..line = const DrillLine(
          reason: 'nothing-built',
          stats: DrillStats(positions: 0, due: 0, known: 0, fresh: 0),
        );
      await _pumpDrill(tester, rig, api,
          rootFen: _smithMorra, fromFen: _smithMorra);
      expect(rig.voice.said, ['nothing_to_drill_branch']);
      expect(find.text('Nothing to drill in this branch.'), findsOneWidget);
      await _leave(tester);
    });

    /// A line through a fork, to stand on a road and find nothing behind it.
    DrillLine forked() => DrillLine(
          rootPath: const ['e4'],
          startFen: _fenAfter(['e4']),
          prefix: const [
            LineMove(
              uci: 'c7c5',
              san: 'c5',
              mine: true,
              role: 'alternate',
              alts: [LineAlternative(uci: 'e7e5', san: 'e5')],
            ),
            LineMove(uci: 'd2d4', san: 'd4', mine: false),
          ],
          question: DrillItem(
            fen: _fenAfter(['e4', 'c5', 'd4']),
            fresh: true,
            repetitions: 0,
            moves: 1,
            path: const ['c5', 'd4'],
          ),
          stats: const DrillStats(positions: 6, due: 1, known: 2, fresh: 3),
        );

    Future<void> chooseRoad(WidgetTester tester) async {
      await tester.tap(find.text('Another decision'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drill e5'));
      await tester.pumpAndSettle();
    }

    testWidgets('nothing due after a road you chose, naming its move',
        (tester) async {
      final rig = await _rig();
      final api = _DrillApi()..line = forked();
      api.linesByVia['e7e5'] = const DrillLine(
        reason: 'nothing-due',
        stats: DrillStats(positions: 6, due: 0, known: 2, fresh: 0),
      );
      await _pumpDrill(tester, rig, api, rootFen: _fenAfter(['e4']));
      final before = rig.voice.said.length;

      await chooseRoad(tester);

      expect(rig.voice.said.sublist(before),
          ['nothing_due_after piece_pawn sq_e5']);
      expect(find.text('Nothing due after pawn e5.'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('nothing to drill after a road, with the tail that ends it',
        (tester) async {
      final rig = await _rig();
      final api = _DrillApi()..line = forked();
      api.linesByVia['e7e5'] = const DrillLine(
        reason: 'nothing-built',
        stats: DrillStats(positions: 0, due: 0, known: 0, fresh: 0),
      );
      await _pumpDrill(tester, rig, api, rootFen: _fenAfter(['e4']));
      final before = rig.voice.said.length;

      await chooseRoad(tester);

      expect(rig.voice.said.sublist(before),
          ['nothing_to_drill_after piece_pawn sq_e5 yet_tail']);
      expect(find.text('Nothing to drill after pawn e5 yet.'), findsOneWidget);
      await _leave(tester);
    });
  });

  // ── Both ───────────────────────────────────────────────────────────────

  group('both screens', () {
    testWidgets('with speech off nothing is played and nothing is drawn twice',
        (tester) async {
      var rig = await _rig(enabled: false);
      final api = _BuildApi(
          walk: const RepertoireFrontier(
              decided: 0, open: [FrontierNode(fen: _smithMorra, path: [])]))
        ..topReplies['b8c6'] = (uci: 'g1f3', san: 'Nf3');
      await _pumpBuild(tester, rig, api);
      await _play(tester, 'b8', 'c6');
      expect(rig.voice.lines, isEmpty);
      expect(find.text('What do you play with Black?'), findsOneWidget);
      expect(
          find.text('Knight c6 is in your repertoire. '
              'The most played reply is knight f3.'),
          findsOneWidget);
      await _leave(tester);

      rig = await _rig(enabled: false);
      final drill = _DrillApi()
        ..answer = _answer('primary', days: 1, reply: 'g1f3');
      await _pumpDrill(tester, rig, drill);
      await _play(tester, 'b8', 'c6');
      expect(rig.voice.lines, isEmpty);
      expect(find.text('Correct. White plays knight f3. Returns tomorrow.'),
          findsOneWidget);
      expect(find.text('What do you play with Black?'), findsNothing,
          reason: 'the verdict replaced the question');
      await _leave(tester);
    });

    testWidgets('the speaker plays a line once, and turns speech on',
        (tester) async {
      final rig = await _rig(enabled: false);
      await _pumpDrill(tester, rig, _DrillApi());
      expect(rig.voice.lines, isEmpty);

      await tester.tap(find.byTooltip('Enable reading aloud').first);
      await tester.pumpAndSettle();

      expect(rig.voice.said, [_qBlack]);
      await _leave(tester);
    });

    testWidgets(
        'the switch in the bar turns the drill own voice on and it says '
        'the question already on screen', (tester) async {
      // The switch is part of the seam: pointed at the singleton it would turn
      // on a voice this screen is not using, and the question would stay
      // unsaid.
      final rig = await _rig(enabled: false);
      await _pumpDrill(tester, rig, _DrillApi());
      expect(rig.voice.lines, isEmpty);

      await tester.tap(find.byType(SpeechToggleButton));
      await tester.pumpAndSettle();

      expect(rig.voice.said, [_qBlack]);
      await _leave(tester);
    });

    testWidgets('leaving either screen stops the voice', (tester) async {
      var rig = await _rig();
      await _pumpBuild(
          tester,
          rig,
          _BuildApi(
              walk: const RepertoireFrontier(
                  decided: 0,
                  open: [FrontierNode(fen: _smithMorra, path: [])])));
      var stops = rig.speech.stopCalls;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(rig.speech.stopCalls, greaterThan(stops),
          reason: 'the build screen');

      rig = await _rig();
      await _pumpDrill(tester, rig, _DrillApi());
      stops = rig.speech.stopCalls;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(rig.speech.stopCalls, greaterThan(stops), reason: 'the drill');
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('the device voice is never asked on either screen',
        (tester) async {
      var rig = await _rig();
      final build = _BuildApi(
          walk: const RepertoireFrontier(
              decided: 0, open: [FrontierNode(fen: _smithMorra, path: [])]))
        ..topReplies['b8c6'] = (uci: 'g1f3', san: 'Nf3');
      await _pumpBuild(tester, rig, build);
      await _play(tester, 'b8', 'c6');
      await tester.tap(find.text('Ask engine'));
      await tester.pumpAndSettle();
      expect(rig.voice.lines, isNotEmpty);
      await _leave(tester);

      rig = await _rig();
      final drill = _DrillApi()
        ..answer = _answer('primary', days: 6, reply: 'g1f3');
      await _pumpDrill(tester, rig, drill);
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      await _play(tester, 'b8', 'c6');
      await _walkOn(tester);
      expect(rig.voice.lines, isNotEmpty);
      await _leave(tester);
    });

    test(
        'neither screen calls the device voice, or draws a sentence it '
        'cannot say', () {
      for (final path in [
        'lib/features/repertoire/screens/repertoire_build_screen.dart',
        'lib/features/repertoire/screens/repertoire_drill_screen.dart',
      ]) {
        final code = _code(path);
        expect(code, isNot(contains('.speak(')), reason: path);
        // The one place the singleton is named is the seam's own default.
        expect(code.replaceAll('widget.speech ?? SpeechService.instance', ''),
            isNot(contains('SpeechService.instance')),
            reason: '$path speaks through its seam');
        final calls = _speakableCalls(code);
        expect(calls.length, greaterThanOrEqualTo(4),
            reason: '$path: the reader must have found the panels');
        for (final call in calls) {
          expect(call, contains('line:'),
              reason: '$path: a SpeakableInfo with no line is the device '
                  'voice\'s: $call');
        }
      }
    });

    test('the reader finds a SpeakableInfo that has a text and no line', () {
      // A guard that cannot fail is not one: this is the shape it must catch,
      // and the shapes it must not.
      const bad =
          "return SpeakableInfo(text: x, autoSpeak: true, child: Text('a(b'));";
      const good =
          "return SpeakableInfo(text: x.text, line: x, child: Row(children: [Text('a')]));";
      final calls = _speakableCalls('$bad\n$good');
      expect(calls, hasLength(2));
      expect(calls[0], isNot(contains('line:')));
      expect(calls[1], contains('line:'));
      // A nested widget's own `line:` is not the call's.
      final nested =
          _speakableCalls('SpeakableInfo(text: x, child: Foo(line: y))');
      expect(nested.single, isNot(contains('line:')));
    });
  });
}
