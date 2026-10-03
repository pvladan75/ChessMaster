// Phase 4d's gate — `docs/PLAN-GOVOR-IZ-KLIPOVA.md`: the repertoire walkthrough
// speaks the table the owner approved on 3.10.2026 through
// `SpeechService.speakLine`, and what it speaks is what it draws (D4). The
// device voice is never asked anything on this screen.
//
// Modelled on `speech_repertoire_test.dart` (phase 4c): the screen is the real
// one, the server is a fake service, and the voice is a fake `ClipVoice` that
// records the `SpokenLine`s it was handed, so the cases assert **token ids**.
//
// The wording change of this phase: the owner approved „In 42 percent of
// games.", but the speech engine reports „42 percent" as one word and the
// cutter cannot split it, so a share is said „in 42 of 100 games".
//
// The rule of *when* a stop speaks did not change and several cases pin it: a
// fork, a hole, a note and the return beat speak; an ordinary move on the
// trunk is drawn and silent.

import 'dart:io';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/speech/clip_voice.dart';
import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_walkthrough_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/widgets/speakable_info.dart';

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
  _CountingSpeech(super.engine) : super.forSubclass();

  int stopCalls = 0;

  @override
  Future<void> stop() {
    stopCalls++;
    return super.stop();
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

/// The walkthrough's server: a tree, and the notes the student has written.
class _Api extends RepertoireApiService {
  _Api(this.tree, {this.commentsByKey = const {}})
      : super(client: MockClient((_) async => http.Response('{}', 500)));

  final RepertoireTree tree;
  final Map<String, RepertoireComment> commentsByKey;

  @override
  Future<RepertoireTree?> repertoireTree({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    String? gateUci,
    String? breadth,
    int? maxPly,
    List<String> alongPath = const [],
  }) async =>
      tree;

  @override
  Future<Map<String, RepertoireComment>> comments(
          {required String color}) async =>
      commentsByKey;
}

// ── fixtures: real positions, because a sentence names a move ───────────

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

String _fenAfter(String fen, String uci) {
  final board = chess.Chess.fromFEN(fen);
  final ok = board.move({
    'from': uci.substring(0, 2),
    'to': uci.substring(2, 4),
    if (uci.length > 4) 'promotion': uci.substring(4, 5),
  });
  if (!ok) throw StateError('$uci is not legal in $fen');
  return board.fen;
}

final _afterE4 = _fenAfter(_start, 'e2e4');
final _afterE5 = _fenAfter(_afterE4, 'e7e5');

RepertoireTreeMove _mine(String from, String uci, String san,
        {String role = 'primary',
        List<RepertoireTreeMove> children = const []}) =>
    RepertoireTreeMove(
      uci: uci,
      san: san,
      fen: _fenAfter(from, uci),
      mine: true,
      role: role,
      state: 'decided',
      children: children,
    );

RepertoireTreeMove _their(String uci, String san, double share,
        {String state = 'decided',
        List<RepertoireTreeMove> children = const []}) =>
    RepertoireTreeMove(
      uci: uci,
      san: san,
      fen: _fenAfter(_afterE4, uci),
      mine: false,
      share: share,
      state: state,
      children: children,
    );

RepertoireTreeMove _e4(List<RepertoireTreeMove> replies) =>
    _mine(_start, 'e2e4', 'e4', children: replies);

RepertoireTree _tree(List<RepertoireTreeMove> replies) =>
    RepertoireTree(rootFen: _start, children: [_e4(replies)]);

// ── the screen ───────────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester,
  _Rig rig,
  _Api api, {
  void Function(String fen)? onBuildHere,
}) async {
  tester.view.physicalSize = const Size(500, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: RepertoireWalkthroughScreen(
      key: UniqueKey(),
      name: 'Gate',
      color: 'w',
      rootFen: _start,
      api: api,
      onBuildHere: onBuildHere,
      speech: rig.speech,
    ),
  ));
  await tester.pumpAndSettle();
}

/// One press of the strip's forward button.
Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.chevron_right));
  await tester.pumpAndSettle();
}

/// Takes the reply at [index] from a fork: at a fork the forward button asks
/// which line, so the chips are the way along.
Future<void> _chip(WidgetTester tester, int index) async {
  await tester.tap(find.byType(ActionChip).at(index));
  await tester.pumpAndSettle();
}

/// Leaves the screen, so nothing outlives the test.
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

/// The source of [path] with its `//` comment lines taken out.
String _code(String path) => File(path)
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

/// The argument list of every `SpeakableInfo(` in [source], read by matching
/// the brackets (strings skipped), each reduced to its own top level.
List<String> _speakableCalls(String source) {
  final calls = <String>[];
  var from = 0;
  while (true) {
    final at = source.indexOf('SpeakableInfo(', from);
    if (at < 0) return calls;
    from = at + 'SpeakableInfo('.length;
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

const _forkOfThree =
    'your_move_main_line opponent_has_replies nmid_3 replies_tail '
    'piece_pawn sq_e5 in_games nmid_55 of_100_games '
    'piece_pawn sq_c5 in_games nmid_31 of_100_games no_reply '
    'piece_pawn sq_e6 in_games nmid_14 of_100_games';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('the stops that are drawn and not spoken', () {
    testWidgets('a trunk move and the alternative', (tester) async {
      final rig = await _rig();
      // Two moves of mine at the root: the first is the main line, the second
      // the alternative, which the tour reaches by coming back to the root.
      final tree = RepertoireTree(rootFen: _start, children: [
        _e4([_their('e7e5', 'e5', 0.55)]),
        _mine(_start, 'd2d4', 'd4', role: 'alternate'),
      ]);
      await _pump(tester, rig, _Api(tree));

      expect(find.text('Your move. Main line.'), findsOneWidget);
      await _next(tester); // e5: drawn
      expect(rig.voice.said, isEmpty);

      await _next(tester); // back to the root before d4: the return speaks
      expect(rig.voice.said, hasLength(1));
      rig.voice.lines.clear();

      await _next(tester);
      expect(find.text('Your move. The alternative.'), findsOneWidget);
      expect(rig.voice.said, isEmpty);
      await _leave(tester);
    });
    testWidgets('a covered reply with a share', (tester) async {
      final rig = await _rig();
      await _pump(tester, rig, _Api(_tree([_their('e7e5', 'e5', 0.55)])));
      await _next(tester);

      expect(find.text('Black plays pawn e5. In 55 of 100 games.'),
          findsOneWidget);
      expect(rig.voice.said, isEmpty);
      await _leave(tester);
    });

    testWidgets('a reply under one in a hundred', (tester) async {
      final rig = await _rig();
      await _pump(tester, rig, _Api(_tree([_their('e7e5', 'e5', 0.004)])));
      await _next(tester);

      expect(find.text('Black plays pawn e5. In less than one of 100 games.'),
          findsOneWidget);
      expect(rig.voice.said, isEmpty);
      await _leave(tester);
    });

    testWidgets('a reply with no share', (tester) async {
      final rig = await _rig();
      await _pump(tester, rig, _Api(_tree([_their('e7e5', 'e5', 0)])));
      await _next(tester);

      expect(find.text('Black plays pawn e5.'), findsOneWidget);
      expect(rig.voice.said, isEmpty);
      await _leave(tester);
    });
  });

  group('the stops that speak', () {
    testWidgets('a hole speaks, ends in no_reply_here and keeps its button',
        (tester) async {
      final rig = await _rig();
      String? built;
      await _pump(
          tester, rig, _Api(_tree([_their('c7c5', 'c5', 0.31, state: 'open')])),
          onBuildHere: (fen) => built = fen);
      await _next(tester);

      expect(rig.voice.said, [
        'black_plays piece_pawn sq_c5 in_head nmid_31 of_100_games '
            'no_reply_here'
      ]);
      expect(
          find.text('Black plays pawn c5. In 31 of 100 games. '
              'You have no reply here.'),
          findsOneWidget);
      // The button stays, and nothing of it is said.
      expect(find.text('Prepare reply'), findsOneWidget);
      await tester.tap(find.text('Prepare reply'));
      expect(built, _fenAfter(_afterE4, 'c7c5'));
      expect(rig.voice.lines, hasLength(1));
      await _leave(tester);
    });

    testWidgets('a fork of three, one of them a hole: the exact line',
        (tester) async {
      final rig = await _rig();
      await _pump(
          tester,
          rig,
          _Api(_tree([
            _their('e7e5', 'e5', 0.55),
            _their('c7c5', 'c5', 0.31, state: 'open'),
            _their('e7e6', 'e6', 0.14),
          ])));

      // Tour order, and „No reply." straight after the hole.
      expect(rig.voice.said, [_forkOfThree]);
      expect(
          find.text('Your move. Main line. From here the opponent has 3 '
              'replies. Pawn e5 in 55 of 100 games. Pawn c5 in 31 of 100 '
              'games. No reply. Pawn e6 in 14 of 100 games.'),
          findsOneWidget);
      expect(
          rig.voice.lines.single.text,
          'Your move. Main line. From here the opponent has 3 replies. Pawn '
          'e5 in 55 of 100 games. Pawn c5 in 31 of 100 games. No reply. '
          'Pawn e6 in 14 of 100 games.');
      await _leave(tester);
    });

    testWidgets('a fork of five names three and counts two', (tester) async {
      final rig = await _rig();
      await _pump(
          tester,
          rig,
          _Api(_tree([
            _their('e7e5', 'e5', 0.30),
            _their('c7c5', 'c5', 0.25),
            _their('e7e6', 'e6', 0.20),
            _their('c7c6', 'c6', 0.15),
            _their('d7d5', 'd5', 0.10),
          ])));

      expect(
          rig.voice.said.single,
          'your_move_main_line opponent_has_replies nmid_5 replies_tail '
          'piece_pawn sq_e5 in_games nmid_30 of_100_games '
          'piece_pawn sq_c5 in_games nmid_25 of_100_games '
          'piece_pawn sq_e6 in_games nmid_20 of_100_games '
          'and_head nmid_2 more_replies_tail');
      expect(find.textContaining('And 2 more replies.'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('a fork of four counts one more reply', (tester) async {
      final rig = await _rig();
      await _pump(
          tester,
          rig,
          _Api(_tree([
            _their('e7e5', 'e5', 0.30),
            _their('c7c5', 'c5', 0.25),
            _their('e7e6', 'e6', 0.20),
            _their('c7c6', 'c6', 0.15),
          ])));

      expect(rig.voice.said.single, endsWith('of_100_games one_more_reply'));
      expect(rig.voice.said.single, isNot(contains('and_head')));
      expect(find.textContaining('And one more reply.'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('a note: „you left a note" is said, the note is only drawn',
        (tester) async {
      final rig = await _rig();
      final tree = _tree([_their('e7e5', 'e5', 0.55)]);
      await _pump(
          tester,
          rig,
          _Api(tree, commentsByKey: {
            fenKeyOf(tree.children.single.fen): RepertoireComment(
                fenKey: fenKeyOf(tree.children.single.fen), body: 'Watch f7.'),
          }));

      expect(rig.voice.said, ['your_move_main_line left_note']);
      expect(find.text('Your move. Main line. You left a note here.'),
          findsOneWidget);
      expect(find.text('Watch f7.'), findsOneWidget);
      expect(rig.voice.lines.single.text, isNot(contains('f7')));
      expect(rig.tts.said, isEmpty);
      await _leave(tester);
    });

    testWidgets('a share of a hundred uses the hundred', (tester) async {
      final rig = await _rig();
      await _pump(
          tester, rig, _Api(_tree([_their('c7c5', 'c5', 1.0, state: 'open')])));
      await _next(tester);

      expect(
          rig.voice.said.single,
          'black_plays piece_pawn sq_c5 in_head nmid_100 of_100_games '
          'no_reply_here');
      expect(find.textContaining('In 100 of 100 games.'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets(
        'the return beat: both lines named, always spoken, and the '
        'fork named again', (tester) async {
      final rig = await _rig();
      await _pump(
          tester,
          rig,
          _Api(_tree([
            _their('e7e5', 'e5', 0.55),
            _their('c7c5', 'c5', 0.31),
            _their('e7e6', 'e6', 0.14),
          ])));
      expect(rig.voice.said, [_forkOfThree.replaceAll(' no_reply', '')]);
      await _chip(tester, 0); // e5: drawn, silent
      expect(rig.voice.lines, hasLength(1));

      await _next(tester); // back to e4 before c5
      expect(
          rig.voice.said.last,
          'we_saw_line_after piece_pawn sq_e5 now_comes piece_pawn sq_c5 '
          'opponent_has_replies nmid_3 replies_tail '
          'piece_pawn sq_e5 in_games nmid_55 of_100_games '
          'piece_pawn sq_c5 in_games nmid_31 of_100_games '
          'piece_pawn sq_e6 in_games nmid_14 of_100_games');
      expect(rig.voice.lines, hasLength(2));
      expect(
          find.textContaining(
              'We saw the line after pawn e5. Now comes pawn c5. From here '
              'the opponent has 3 replies.'),
          findsOneWidget);
      expect(rig.voice.lines.last.text,
          startsWith('We saw the line after pawn e5. Now comes pawn c5.'));
      await _leave(tester);
    });
  });

  group('the switch and the voice', () {
    testWidgets('speech off: nothing is said and the card has no speaker',
        (tester) async {
      final rig = await _rig(enabled: false);
      await _pump(
          tester,
          rig,
          _Api(_tree([
            _their('e7e5', 'e5', 0.55),
            _their('c7c5', 'c5', 0.31, state: 'open'),
            _their('e7e6', 'e6', 0.14),
          ])));
      await _chip(tester, 0);
      await _next(tester);
      await _next(tester);

      expect(rig.voice.lines, isEmpty);
      expect(
          find.descendant(
              of: find.byType(SpeakableInfo),
              matching: find.byType(IconButton)),
          findsNothing);
      await _leave(tester);
    });

    testWidgets('speech on: the card has its speaker', (tester) async {
      final rig = await _rig();
      await _pump(tester, rig, _Api(_tree([_their('e7e5', 'e5', 0.55)])));

      expect(
          find.descendant(
              of: find.byType(SpeakableInfo),
              matching: find.byType(IconButton)),
          findsOneWidget);
      await _leave(tester);
    });

    testWidgets('the device voice is never asked', (tester) async {
      final rig = await _rig();
      await _pump(
          tester,
          rig,
          _Api(_tree([
            _their('e7e5', 'e5', 0.55,
                children: [_mine(_afterE5, 'g1f3', 'Nf3')]),
            _their('c7c5', 'c5', 0.31, state: 'open'),
            _their('e7e6', 'e6', 0.14),
          ])));
      await _chip(tester, 0);
      for (var i = 0; i < 5; i++) {
        await _next(tester);
      }
      expect(rig.voice.lines, isNotEmpty);
      expect(rig.tts.said, isEmpty);
      await _leave(tester);
    });

    testWidgets('moving along the tour does not stop the voice, leaving does',
        (tester) async {
      final rig = await _rig();
      await _pump(
          tester,
          rig,
          _Api(_tree([
            _their('e7e5', 'e5', 0.55),
            _their('c7c5', 'c5', 0.31, state: 'open'),
            _their('e7e6', 'e6', 0.14),
          ])));
      final before = rig.speech.stopCalls;
      await _chip(tester, 0);
      await _next(tester);
      expect(rig.speech.stopCalls, before,
          reason: 'the reader ends a sentence by moving on, not by a stop');

      await _leave(tester);
      expect(rig.speech.stopCalls, greaterThan(before),
          reason: 'a sentence must not outlive its screen');
    });

    test(
        'the screen never calls the device voice, or a SpeakableInfo '
        'without a line', () {
      const path =
          'lib/features/repertoire/screens/repertoire_walkthrough_screen.dart';
      final code = _code(path);
      expect(code, isNot(contains('.speak(')));
      expect(code.replaceAll('widget.speech ?? SpeechService.instance', ''),
          isNot(contains('SpeechService.instance')),
          reason: 'the screen speaks through its seam');
      final calls = _speakableCalls(code);
      expect(calls, isNotEmpty);
      for (final call in calls) {
        expect(call, contains('line:'),
            reason: 'a SpeakableInfo with no line is the device voice\'s');
      }
    });

    test('the reader finds a SpeakableInfo that has a text and no line', () {
      // A guard that cannot fail is not one.
      final calls =
          _speakableCalls("SpeakableInfo(text: x, child: Text('a(b'));\n"
              'SpeakableInfo(text: x.text, line: x, child: Row());');
      expect(calls, hasLength(2));
      expect(calls[0], isNot(contains('line:')));
      expect(calls[1], contains('line:'));
    });
  });
}
