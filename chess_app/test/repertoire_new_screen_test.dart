import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/repertoire/screens/repertoire_new_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// Making a repertoire without typing a FEN.
///
/// The screen exists because the first version asked for one in a text field,
/// and the first person to use it pasted half a placement string and was told
/// only "nije sačuvano". Both halves of that are tested here: that the opening
/// can be played out on the board instead, and that a refusal says which
/// refusal it is.
class _FakeApi extends RepertoireApiService {
  _FakeApi({this.error})
      : super(client: MockClient((_) async => http.Response('{}', 500)));

  final String? error;

  String? lastFen;
  String? lastColor;
  String? lastName;
  List<String>? lastPath;

  @override
  Future<({RepertoireSummary? made, String? error})> create({
    required String name,
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
  }) async {
    lastName = name;
    lastColor = color;
    lastFen = rootFen;
    lastPath = rootPath;
    if (error != null) return (made: null, error: error);
    return (
      made: RepertoireSummary(
        id: 1,
        name: name,
        color: color,
        rootFen: rootFen,
        rootPath: rootPath,
        moves: 0,
      ),
      error: null,
    );
  }
}

void main() {
  /// A stand-in for the ECO dataset. The real one loads through `compute()`,
  /// and an isolate never finishes inside `testWidgets` — awaiting it hung a
  /// run until it was killed at ten minutes.
  String? sicilian(String fen) =>
      fen.startsWith('rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR')
          ? 'Sicilian Defense'
          : null;

  Future<void> pump(
    WidgetTester tester,
    _FakeApi api, {
    String? startFen,
    Size size = const Size(500, 1100),
    String? Function(String fen)? nameFor,
    (String, String)? Function()? openingPicker,
    void Function(RepertoireSummary?)? onDone,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final made =
                    await Navigator.of(context).push<RepertoireSummary>(
                  MaterialPageRoute(
                    builder: (_) => RepertoireNewScreen(
                      api: api,
                      startFen: startFen,
                      // Every pump gets one, so no test ever reaches for the
                      // real dataset by accident.
                      nameFor: nameFor ?? (_) => null,
                      openingPicker: openingPicker,
                    ),
                  ),
                );
                onDone?.call(made);
              },
              child: const Text('otvori'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('otvori'));
    await tester.pumpAndSettle();
  }

  Future<void> play(WidgetTester tester, String from, String to) async {
    final finder = find.byType(ChessBoardWithOverlay);
    final widget = tester.widget<ChessBoardWithOverlay>(finder);
    final rect = tester.getRect(finder);
    final square = widget.boardSize / 8;
    Offset at(String name) {
      final file = name.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = name.codeUnitAt(1) - '1'.codeUnitAt(0);
      final col =
          widget.boardOrientation == PlayerColor.black ? 7 - file : file;
      final row =
          widget.boardOrientation == PlayerColor.black ? rank : 7 - rank;
      return rect.topLeft + Offset((col + 0.5) * square, (row + 0.5) * square);
    }

    await tester.tapAt(at(from));
    await tester.pumpAndSettle();
    await tester.tapAt(at(to));
    await tester.pumpAndSettle();
  }

  Future<void> playSmithMorra(WidgetTester tester) async {
    // 1.e4 c5 2.d4 cxd4 3.c3 dxc3 4.Nxc3 — Black to move.
    for (final move in [
      ['e2', 'e4'],
      ['c7', 'c5'],
      ['d2', 'd4'],
      ['c5', 'd4'],
      ['c2', 'c3'],
      ['d4', 'c3'],
      ['b1', 'c3'],
    ]) {
      await play(tester, move[0], move[1]);
    }
  }

  testWidgets('the opening is played out, and the line is written down',
      (tester) async {
    final api = _FakeApi();
    await pump(tester, api);

    await playSmithMorra(tester);

    expect(find.textContaining('1. e4 c5 2. d4 cxd4'), findsOneWidget);
    expect(find.textContaining('4. Nxc3'), findsOneWidget);
  });

  testWidgets('the side and the position are one decision', (tester) async {
    // Building for White in a position where Black is to move used to be an
    // error message after the fact. Now the button simply is not alive, and the
    // line above it says why.
    final api = _FakeApi();
    await pump(tester, api);

    await playSmithMorra(tester);

    final button = find.widgetWithText(FilledButton, 'Napravi');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.textContaining('Na potezu je crni'), findsOneWidget);

    await tester.tap(find.text('Crni'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Smit-Mora, crni');
    await tester.pump();

    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });

  testWidgets('the name is suggested from the opening, and can be overwritten',
      (tester) async {
    // The ECO dataset is bundled, so this costs no request and no token.
    final api = _FakeApi();
    await pump(tester, api, nameFor: sicilian);

    await play(tester, 'e2', 'e4');
    await play(tester, 'c7', 'c5');
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, contains('Sicilian'));
    expect(field.controller!.text, endsWith('beli'));
    expect(find.textContaining('Predloženo iz baze otvaranja'), findsOneWidget);

    // And once the reader writes their own, the suggestion stops correcting
    // them: a field that keeps rewriting what you typed is worse than one that
    // never helped.
    await tester.enterText(find.byType(TextField).first, 'Moja Sicilijanka');
    await tester.pump();
    await play(tester, 'g1', 'f3');
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Moja Sicilijanka',
    );
  });

  testWidgets('an opening can be chosen by name instead of played out',
      (tester) async {
    // The short way to the same place: naming the Smith-Morra rather than
    // spelling it out in seven moves. The line, the position and the name all
    // arrive together.
    final api = _FakeApi();
    await pump(
      tester,
      api,
      openingPicker: () => (
        'Sicilian Defense: Smith-Morra Gambit Accepted',
        '1. e4 c5 2. d4 cxd4 3. c3 dxc3 4. Nxc3',
      ),
    );

    await tester.tap(find.text('Nađi otvaranje'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1. e4 c5 2. d4 cxd4'), findsOneWidget);
    expect(find.textContaining('4. Nxc3'), findsOneWidget);
    // Black is to move there, so that is the side the repertoire is for.
    expect(find.textContaining('Na potezu je crni'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, contains('Smith-Morra'));
    expect(field.controller!.text, endsWith('crni'));
  });

  testWidgets('a book line the board refuses stops rather than half-loading',
      (tester) async {
    // Half a line quietly loaded is a position nobody asked for, wearing the
    // name of one they did.
    final api = _FakeApi();
    await pump(
      tester,
      api,
      openingPicker: () => ('Nešto', '1. e4 c5 2. Qh9 d4'),
    );

    await tester.tap(find.text('Nađi otvaranje'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1. e4 c5'), findsOneWidget);
    expect(find.textContaining('d4'), findsNothing);
  });

  testWidgets('a dead button says what it is waiting for', (tester) async {
    // Found on a desktop window: the position was right, the line under the
    // board was green, and "Napravi" was grey with nothing anywhere saying that
    // the name was empty. A control that knows why it will not work and does
    // not say is the same fault as an error message that lumps three causes
    // into one sentence.
    final api = _FakeApi();
    await pump(tester, api);

    await play(tester, 'e2', 'e4');
    await play(tester, 'c7', 'c5');

    final button = find.widgetWithText(FilledButton, 'Napravi');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.text('Upišite ime repertoara.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Gering');
    await tester.pump();

    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    expect(find.text('Upišite ime repertoara.'), findsNothing);
  });

  testWidgets('on a wide window the fields stay beside the board',
      (tester) async {
    // Unconstrained, the name field ran the whole width of a desktop window,
    // a metre from the board it belongs to.
    final api = _FakeApi();
    await pump(tester, api, size: const Size(1600, 900));

    final field = tester.getSize(find.byType(TextField).first);
    expect(field.width, lessThanOrEqualTo(560));
  });

  testWidgets('what is saved is the position that was played', (tester) async {
    RepertoireSummary? made;
    final api = _FakeApi();
    await pump(tester, api, onDone: (m) => made = m);

    await playSmithMorra(tester);
    await tester.tap(find.text('Crni'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Smit-Mora, crni');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Napravi'));
    await tester.pumpAndSettle();

    expect(api.lastName, 'Smit-Mora, crni');
    expect(api.lastColor, 'b');
    expect(api.lastFen,
        startsWith('rnbqkbnr/pp1ppppp/8/8/4P3/2N5/PP3PPP/R1BQKBNR b'));
    expect(made?.name, 'Smit-Mora, crni');
  });

  testWidgets('a move can be taken back, and the whole line reset',
      (tester) async {
    final api = _FakeApi();
    await pump(tester, api);

    await play(tester, 'e2', 'e4');
    await play(tester, 'c7', 'c5');
    expect(find.textContaining('1. e4 c5'), findsOneWidget);

    await tester.tap(find.text('Nazad'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1. e4'), findsOneWidget);
    expect(find.textContaining('c5'), findsNothing);

    await tester.tap(find.text('Ispočetka'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Odigrajte poteze'), findsOneWidget);
  });

  /// Types a name and presses the button, which is all the failure cases need.
  Future<void> tryToSave(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'Smit-Mora');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Napravi'));
    await tester.pumpAndSettle();
  }

  // The two below are separate tests rather than one with two pumps: the second
  // screen would be pushed on top of the first, and the finder would then be
  // looking at a screen that is no longer the one on top.
  testWidgets('a stopped server says so, and says where to look',
      (tester) async {
    final api =
        _FakeApi(error: 'Server nije dostupan — proverite da li backend radi.');
    await pump(tester, api);

    await tryToSave(tester);

    expect(find.textContaining('proverite da li backend radi'), findsOneWidget);
  });

  testWidgets('a taken name is a different sentence from a stopped server',
      (tester) async {
    // The whole point of this round: one message for three causes is the same
    // silent failure this project keeps meeting, one layer up — and it was on
    // screen the first time somebody used this.
    final api = _FakeApi(error: 'Već imate repertoar sa tim imenom.');
    await pump(tester, api);

    await tryToSave(tester);

    expect(find.text('Već imate repertoar sa tim imenom.'), findsOneWidget);
    expect(find.textContaining('backend'), findsNothing);
  });

  testWidgets('a position handed in decides the side it opens on',
      (tester) async {
    final api = _FakeApi();
    await pump(
      tester,
      api,
      startFen: 'rnbqkbnr/pp1ppppp/8/8/4P3/2N5/PP3PPP/R1BQKBNR b KQkq - 0 4',
    );

    expect(find.textContaining('Na potezu je crni'), findsOneWidget);
    expect(
      tester
          .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
          .boardOrientation,
      PlayerColor.black,
    );
  });

  testWidgets('the screen fits a 360 dp phone', (tester) async {
    final api = _FakeApi();
    await pump(tester, api, size: const Size(360, 640));
    expect(tester.takeException(), isNull);

    await play(tester, 'e2', 'e4');
    expect(tester.takeException(), isNull);
  });
}
