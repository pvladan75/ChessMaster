import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

import 'package:chess_app/core/speech/clip_voice.dart';
import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_drill_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/widgets/speakable_info.dart';

/// Phase 2 of `docs/PLAN-JEDNOSTAVNOST.md`: the panels that now read
/// themselves out.
///
/// Every test here pumps a **real panel**. `SpeakableInfo` on its own is
/// already covered by `phase0_widgets_test.dart`, and a test that builds one by
/// hand with a sentence typed into the test file proves only that the widget
/// speaks whatever it is handed — it would pass just as well after somebody
/// removed the wrapper from every screen in the app.
///
/// The seam that makes pumping the real thing possible: a `SpeakableInfo`
/// inside a screen takes no injected service, it reads `SpeechService.instance`.
/// `init` accepts an engine, so the singleton can be pointed at a fake one and
/// the screens stay exactly as they ship.
class _Engine implements TtsEngine {
  final List<String> said = [];
  int stops = 0;

  @override
  Future<List<String>> languages() async => const ['en-US'];

  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> speak(String text) async {
    said.add(text);
  }

  @override
  Future<void> stop() async => stops += 1;
}

/// The clips' voice, which only remembers the lines it was asked to play.
///
/// Phase 4c of `docs/PLAN-GOVOR-IZ-KLIPOVA.md` moved both repertoire screens
/// from the device voice to the clips, so what these cases listen to is the
/// `SpokenLine`s a screen hands over — token ids, not strings — and the device
/// voice is kept only to say it was never asked.
class _Clips extends ClipVoice {
  _Clips({this.failOnSpeak = false, required this.device});

  final bool failOnSpeak;
  final _Engine device;
  final List<SpokenLine> lines = [];

  List<String> get said =>
      [for (final l in lines) l.tokens.map((t) => t.id).join(' ')];

  @override
  Future<void> load(AssetBundle bundle) async {}

  @override
  Future<void> speak(SpokenLine line) async {
    if (failOnSpeak) throw StateError('nema glasa');
    lines.add(line);
  }

  @override
  Future<void> stop() async {}
}

/// Points the singleton the panels read at a fake clip voice, and sets the
/// setting they check.
Future<_Clips> _speech({
  required bool enabled,
  bool failOnSpeak = false,
}) async {
  final device = _Engine();
  final clips = _Clips(failOnSpeak: failOnSpeak, device: device);
  await SpeechService.instance.init(
    enabled: enabled,
    rate: 0.5,
    engine: device,
    clipVoice: clips,
  );
  // A sentence said once in an earlier test is not said again, so the dedup
  // has to be cleared or the next pump is silent for the wrong reason.
  SpeechService.instance.forget();
  final settings = AppSettingsService.instance;
  await settings.init();
  await settings.setSpeechEnabled(enabled);
  return clips;
}

const _smithMorra =
    'rnbqkbnr/pp1ppppp/8/8/4P3/2N5/PP3PPP/R1BQKBNR b KQkq - 0 4';

/// 1.e4 e6 2.d4 d5 3.e5 — the French Advance, Black to move.
const _advance =
    'rnbqkbnr/ppp2ppp/4p3/3pP3/3P4/8/PPP2PPP/RNBQKBNR b KQkq - 0 3';

/// A judge that asks Lichess nothing. The build screen must draw its question
/// without a book behind it.
class _SilentJudge implements OpeningJudgeService {
  @override
  Future<OpeningJudgeLookup> judge(String fen, String move) async =>
      const OpeningJudgeLookup.unavailable('not-configured');

  @override
  Future<OpponentRepliesLookup> replies(String fen) async =>
      const OpponentRepliesLookup.unavailable('not-configured');

  @override
  void clearCache() {}
}

/// A drill server with no server: one question, or none.
class _FakeApi extends RepertoireApiService {
  _FakeApi({this.item = _smithMorra, this.positions = 6})
      : super(client: MockClient((_) async => http.Response('{}', 500)));

  final String? item;
  final int positions;

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
  }) async =>
      null;

  /// A right answer with a covered reply — the case that carries the line on
  /// by itself and leaves the verdict behind it.
  @override
  Future<DrillAnswer?> answerDrill({
    required String color,
    required String fen,
    required String uci,
    bool revealed = false,
    bool practice = false,
    bool onlyIfDue = false,
  }) async =>
      const DrillAnswer(
        outcome: 'primary',
        primary: RepertoireMove(uci: 'b8c6', san: 'Nc6', role: 'primary'),
        intervalDays: 6,
        reply: 'g1f3',
        replyCovered: true,
      );

  @override
  Future<({DrillItem? item, DrillStats stats})> nextDrill({
    required String color,
  }) async =>
      (
        item: item == null
            ? null
            : DrillItem(fen: item!, fresh: false, repetitions: 3, moves: 2),
        stats: DrillStats(
          positions: positions,
          due: positions == 0 ? 0 : 2,
          known: positions == 0 ? 0 : 1,
          fresh: positions == 0 ? 0 : 3,
        ),
      );
}

/// Everything the panel actually draws, in the order it draws it.
///
/// The assertions below compare *this* with what reached the engine, rather
/// than comparing one literal in the test file with another.
String _shown(WidgetTester tester, Finder panel) => tester
    .widgetList<Text>(find.descendant(of: panel, matching: find.byType(Text)))
    .map((t) => t.data ?? '')
    .where((s) => s.isNotEmpty)
    .join(' ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpDrill(
    WidgetTester tester, {
    String? item = _smithMorra,
    int positions = 6,
    Size size = const Size(500, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: RepertoireDrillScreen(
        name: 'Smit-Mora, crni',
        color: 'b',
        api: _FakeApi(item: item, positions: positions),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Plays a move by tapping the two squares, the way a student does.
  Future<void> play(WidgetTester tester, String from, String to) async {
    final finder = find.byType(ChessBoardWithOverlay);
    final board = tester.widget<ChessBoardWithOverlay>(finder);
    final rect = tester.getRect(finder);
    final square = board.boardSize / 8;
    Offset at(String name) {
      final file = name.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = name.codeUnitAt(1) - '1'.codeUnitAt(0);
      final col = board.boardOrientation == PlayerColor.black ? 7 - file : file;
      final row = board.boardOrientation == PlayerColor.black ? rank : 7 - rank;
      return rect.topLeft + Offset((col + 0.5) * square, (row + 0.5) * square);
    }

    await tester.tapAt(at(from));
    await tester.pumpAndSettle();
    await tester.tapAt(at(to));
    await tester.pumpAndSettle();
  }

  testWidgets('the drill asks its question out loud, word for word',
      (tester) async {
    final clips = await _speech(enabled: true);
    await pumpDrill(tester);

    final panel = find.byType(SpeakableInfo);
    expect(panel, findsOneWidget);
    final shown = _shown(tester, panel);
    // What is drawn, asserted first: the voice is then judged against the
    // screen rather than against a sentence typed into this file.
    //
    // SUPERSEDED: „What do you play as Black? Play the move you chose for this
    // position." — one sentence now, from the clips, and the second one is
    // deleted rather than said.
    expect(shown, 'What do you play with Black?');
    expect(clips.said, ['what_play_black']);
    expect(clips.lines.single.text, shown);
    expect(clips.device.said, isEmpty);
  });

  testWidgets('the verdict is spoken as it is written', (tester) async {
    final clips = await _speech(enabled: true);
    await pumpDrill(tester);

    await play(tester, 'b8', 'c6');

    // SUPERSEDED: the verdict used to be spoken only as „Correct — Nc6 ·
    // opponent f3 · returns in 6 days", the line it left behind it once the
    // walk had moved on. It is one line now, said when its panel is drawn, and
    // the panel is the only one on the screen until the walk moves on.
    final verdict = find.byType(SpeakableInfo);
    expect(verdict, findsOneWidget);
    final shown = _shown(tester, verdict);
    expect(shown, startsWith('Correct. White plays knight f3'));
    expect(clips.said, [
      'what_play_black',
      'correct white_plays piece_knight sq_f3 returns_in nmid_6 days_tail',
    ]);
    expect(clips.lines.last.text, shown);

    // The walk-on beat: the next question speaks, and nothing is carried over.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(clips.said.last, 'what_play_black');
    expect(clips.said, hasLength(3));
  });

  testWidgets('izgradnja reads the question it is asking', (tester) async {
    // Found live 3.9.2026: „ništa se ne čuje kad uđem u izgradnju repertoara".
    // Phase 2 wrapped this screen's banner, note and finished sentence and
    // missed the one panel that asks the reader for something — which is the
    // rule the whole feature is built on.
    final clips = await _speech(enabled: true);
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: RepertoireBuildScreen(
        name: 'French Defense: Advance — crni',
        color: 'b',
        rootFen: _advance,
        rootPath: const ['e4', 'e6', 'd4', 'd5', 'e5'],
        api: RepertoireApiService(
            client: MockClient((_) async => http.Response('{}', 500))),
        judge: _SilentJudge(),
        analyse: (fen, depth, multiPV) async => const [],
      ),
    ));
    await tester.pumpAndSettle();

    final asked = find.text('What do you play with Black?');
    expect(asked, findsOneWidget);
    final panel =
        find.ancestor(of: asked, matching: find.byType(SpeakableInfo));
    expect(panel, findsOneWidget);
    // `contains`, not equality: this screen also writes a note saying it could
    // not read where the reader had got to, and since 4.9.2026 that note is
    // spoken too. Both sentences are wanted; only one of them is this test's.
    expect(clips.said, contains('what_play_black'));
    expect(clips.lines.map((l) => l.text), contains(_shown(tester, panel)));
    expect(clips.device.said, isEmpty);
  });

  testWidgets('izgradnja reads the sentence saying what just happened',
      (tester) async {
    // Reported live 4.9.2026, twice over — the plural messages („Dodate 2
    // pozicije", „sa njom je iz reda izašla još 1 pozicija") were written,
    // shown, and never heard: the panel that carries them was a plain grey
    // caption, while the identical sentence on the finished screen could
    // speak. Every one of those messages goes through this one `_note`, so the
    // note reached here — the server did not answer about where the reader had
    // got to — is the same panel the findings were about.
    final clips = await _speech(enabled: true);
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: RepertoireBuildScreen(
        name: 'French Defense: Advance — crni',
        color: 'b',
        rootFen: _advance,
        rootPath: const ['e4', 'e6', 'd4', 'd5', 'e5'],
        api: RepertoireApiService(
            client: MockClient((_) async => http.Response('{}', 500))),
        judge: _SilentJudge(),
        analyse: (fen, depth, multiPV) async => const [],
      ),
    ));
    await tester.pumpAndSettle();

    // SUPERSEDED: „Could not read your progress — starting from the repertoire
    // opening position." — the clips' own sentence.
    final note = find.textContaining('Could not read your progress');
    expect(note, findsOneWidget, reason: 'poruka mora da se vidi');
    final panel = find.ancestor(of: note, matching: find.byType(SpeakableInfo));
    expect(panel, findsOneWidget,
        reason: 'poruka o tome šta se upravo desilo mora da može da se čuje');
    expect(clips.said, contains('progress_not_read'));
    expect(clips.lines.map((l) => l.text), contains(_shown(tester, panel)));
  });

  testWidgets('nothing due says so on arrival, and again when asked',
      (tester) async {
    // SUPERSEDED: „says so, and only when asked" — the screen said nothing by
    // itself and the speaker beside it said it. Phase 4c of
    // `docs/PLAN-GOVOR-IZ-KLIPOVA.md` speaks it when it appears, like every
    // other sentence the table lists, and the speaker still says it again.
    final clips = await _speech(enabled: true);
    await pumpDrill(tester, item: null, positions: 0);

    final panel = find.byType(SpeakableInfo);
    expect(panel, findsOneWidget);
    final shown = _shown(tester, panel);
    expect(shown, 'Nothing to drill yet.');
    expect(clips.said, ['nothing_to_drill_yet']);

    await tester
        .tap(find.descendant(of: panel, matching: find.byType(IconButton)));
    await tester.pumpAndSettle();
    expect(clips.said, ['nothing_to_drill_yet', 'nothing_to_drill_yet']);
  });

  testWidgets('turning speech on reads the question already on screen',
      (tester) async {
    // The bug the owner found live on 3.9.2026: the panel spoke only when it
    // was built or when its words changed, and the app-bar switch is neither.
    // So the drill stayed silent on the question in front of the reader and
    // the first thing spoken was the verdict at the end of the line.
    final clips = await _speech(enabled: false);
    await pumpDrill(tester);
    expect(clips.said, isEmpty);

    final panel = find.byType(SpeakableInfo);
    final shown = _shown(tester, panel);
    expect(shown, 'What do you play with Black?');

    // The app-bar switch, used the way item 92 tells the reader to use it.
    await tester.tap(find.byType(SpeechToggleButton));
    await tester.pumpAndSettle();

    expect(clips.said, ['what_play_black']);
    expect(clips.lines.single.text, shown);
  });

  testWidgets('with speech off the drill says nothing at all', (tester) async {
    final clips = await _speech(enabled: false);
    await pumpDrill(tester);

    // Off is the default, so this is the screen most readers see.
    expect(clips.said, isEmpty);
    expect(clips.device.said, isEmpty);
    expect(find.text('What do you play with Black?'), findsOneWidget);
  });

  testWidgets('a machine with no voice still draws the whole drill',
      (tester) async {
    final clips = await _speech(enabled: true, failOnSpeak: true);
    await pumpDrill(tester);

    // The voice was reached and refused; the panel it was decorating is still
    // there, and nothing was thrown at the framework.
    expect(clips.said, isEmpty);
    expect(tester.takeException(), isNull);
    expect(find.text('What do you play with Black?'), findsOneWidget);
    expect(find.byType(SpeechToggleButton), findsOneWidget);
  });

  testWidgets('the drill, speaker and all, fits a 360 dp phone',
      (tester) async {
    // A release build paints no overflow stripes — in a test build it throws.
    // The app bar grew a button in this batch, which is where a row breaks.
    await _speech(enabled: true);
    await pumpDrill(tester, size: const Size(360, 640));
    expect(tester.takeException(), isNull);
    expect(find.byType(SpeechToggleButton), findsOneWidget);
  });
}
