import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

import 'package:chess_app/core/services/speech_text.dart';
import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_drill_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/widgets/unconfirmed_banner.dart';
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
  _Engine({this.failOnSpeak = false});

  final bool failOnSpeak;
  final List<String> said = [];
  int stops = 0;

  @override
  Future<List<String>> languages() async => const ['sr-RS'];

  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> speak(String text) async {
    if (failOnSpeak) throw StateError('nema glasa');
    said.add(text);
  }

  @override
  Future<void> stop() async => stops += 1;
}

/// Points the singleton the panels read at a fake engine, and sets the setting
/// they check.
Future<_Engine> _speech({
  required bool enabled,
  bool failOnSpeak = false,
}) async {
  final engine = _Engine(failOnSpeak: failOnSpeak);
  await SpeechService.instance.init(
    enabled: enabled,
    rate: 0.5,
    engine: engine,
  );
  // A sentence said once in an earlier test is not said again, so the dedup
  // has to be cleared or the next pump is silent for the wrong reason.
  SpeechService.instance.forget();
  final settings = AppSettingsService.instance;
  await settings.init();
  await settings.setSpeechEnabled(enabled);
  return engine;
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
  bool get hasPersonalToken => false;

  @override
  Future<OpeningJudgeLookup> judge(String fen, String move,
          {int? minRating}) async =>
      const OpeningJudgeLookup.unavailable('no-token');

  @override
  Future<OpponentRepliesLookup> replies(String fen, {int? minRating}) async =>
      const OpponentRepliesLookup.unavailable('no-token');

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
    int? minRating,
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
    int? minRating,
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
    int? minRating,
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
    final engine = await _speech(enabled: true);
    await pumpDrill(tester);

    final panel = find.byType(SpeakableInfo);
    expect(panel, findsOneWidget);
    final shown = _shown(tester, panel);
    // What is drawn, asserted first: the voice is then judged against the
    // screen rather than against a sentence typed into this file.
    expect(shown, contains('Šta igrate crnim?'));
    expect(
      shown,
      contains('Odigrajte potez koji ste izabrali za ovu poziciju.'),
    );
    expect(engine.said, [speakable(shown)]);
  });

  testWidgets('the verdict is spoken as it is written', (tester) async {
    final engine = await _speech(enabled: true);
    await pumpDrill(tester);

    await play(tester, 'b8', 'c6');
    // The walk-on beat: the verdict is what the line leaves behind it.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    // Two panels now: the verdict, then the next question under it.
    final verdict = find.byType(SpeakableInfo).first;
    final shown = _shown(tester, verdict);
    expect(shown, startsWith('Tačno — Nc6'));
    expect(engine.said, contains(speakable(shown)));
  });

  testWidgets('izgradnja reads the question it is asking', (tester) async {
    // Found live 3.9.2026: „ništa se ne čuje kad uđem u izgradnju repertoara".
    // Phase 2 wrapped this screen's banner, note and finished sentence and
    // missed the one panel that asks the reader for something — which is the
    // rule the whole feature is built on.
    final engine = await _speech(enabled: true);
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

    final asked = find.text('Šta igrate crnim?');
    expect(asked, findsOneWidget);
    final panel =
        find.ancestor(of: asked, matching: find.byType(SpeakableInfo));
    expect(panel, findsOneWidget);
    // `contains`, not equality: this screen also writes a note saying it could
    // not read where the reader had got to, and since 4.9.2026 that note is
    // spoken too. Both sentences are wanted; only one of them is this test's.
    expect(engine.said, contains(speakable(_shown(tester, panel))));
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
    final engine = await _speech(enabled: true);
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

    final note = find.textContaining('Nije moglo da se pročita dokle ste');
    expect(note, findsOneWidget, reason: 'poruka mora da se vidi');
    final panel = find.ancestor(of: note, matching: find.byType(SpeakableInfo));
    expect(panel, findsOneWidget,
        reason: 'poruka o tome šta se upravo desilo mora da može da se čuje');
    expect(engine.said, contains(speakable(_shown(tester, panel))));
  });

  testWidgets('the banner speaks the count it is showing', (tester) async {
    final engine = await _speech(enabled: true);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UnconfirmedBanner(total: 4, onOpenWizard: () {}),
      ),
    ));
    await tester.pumpAndSettle();

    // It is not a question, so it waits to be asked.
    expect(engine.said, isEmpty);
    final panel = find.byType(SpeakableInfo);
    final shown = _shown(tester, panel);
    expect(shown, '4 nepotvrđenih u grafu');

    await tester
        .tap(find.descendant(of: panel, matching: find.byType(IconButton)));
    await tester.pumpAndSettle();
    expect(engine.said, [speakable(shown)]);
  });

  testWidgets('nothing due says so, and only when asked', (tester) async {
    final engine = await _speech(enabled: true);
    await pumpDrill(tester, item: null, positions: 0);

    final panel = find.byType(SpeakableInfo);
    expect(panel, findsOneWidget);
    final shown = _shown(tester, panel);
    expect(shown, 'Još nema šta da se vežba.');
    expect(engine.said, isEmpty);

    await tester
        .tap(find.descendant(of: panel, matching: find.byType(IconButton)));
    await tester.pumpAndSettle();
    expect(engine.said, [speakable(shown)]);
  });

  testWidgets('turning speech on reads the question already on screen',
      (tester) async {
    // The bug the owner found live on 3.9.2026: the panel spoke only when it
    // was built or when its words changed, and the app-bar switch is neither.
    // So the drill stayed silent on the question in front of the reader and
    // the first thing spoken was the verdict at the end of the line.
    final engine = await _speech(enabled: false);
    await pumpDrill(tester);
    expect(engine.said, isEmpty);

    final panel = find.byType(SpeakableInfo);
    final shown = _shown(tester, panel);
    expect(shown, contains('Šta igrate crnim?'));

    // The app-bar switch, used the way item 92 tells the reader to use it.
    await tester.tap(find.byType(SpeechToggleButton));
    await tester.pumpAndSettle();

    expect(engine.said, [speakable(shown)]);
  });

  testWidgets('with speech off the drill says nothing at all', (tester) async {
    final engine = await _speech(enabled: false);
    await pumpDrill(tester);

    // Off is the default, so this is the screen most readers see.
    expect(engine.said, isEmpty);
    expect(find.text('Šta igrate crnim?'), findsOneWidget);
  });

  testWidgets('a machine with no voice still draws the whole drill',
      (tester) async {
    final engine = await _speech(enabled: true, failOnSpeak: true);
    await pumpDrill(tester);

    // The engine was reached and refused; the panel it was decorating is still
    // there, and nothing was thrown at the framework.
    expect(engine.said, isEmpty);
    expect(tester.takeException(), isNull);
    expect(find.text('Šta igrate crnim?'), findsOneWidget);
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
