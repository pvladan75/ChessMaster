// `docs/PLAN-LISTE.md`, phase 6 — pattern B for the Repertoire.
//
// A wide window gets a pane beside the list: the chosen repertoire's root
// position, the line that reached it, and what can be done with it. Below
// `Breakpoints.wide` nothing changes — the row opens, exactly as today.
//
// **The claim this file exists for is that the pane costs nothing.**
// `RepertoireSummary` already carries `rootFen`, `rootPath`, `viaSan`, `color`
// and `moves`, so the pane is drawn from the list the screen already has.
// Measured before a line was written, which is why the plan says „no new
// request" rather than „one small request". A pane that quietly walks the
// graph per selection would look identical on screen and cost a third of a
// second each time — the very thing the progress count was deleted for on
// 16.9.2026 (`repertoire_list_card_test.dart`). So the fake counts what the
// screen asks the server, and the case reads the **request**, not the picture
// (rule 7).
//
// The other thing worth stating: on a wide window a row **selects** instead of
// opening, and the pane carries „Open". That is not the Library's rule, and
// the difference is deliberate rather than an oversight — a Library card has
// two tap targets, its board and the rest of it, so the board could become
// „show me" and the card could go on opening. A repertoire row has one. Where
// there is one target and a pane, the target selects; where there are two, the
// second one does.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/repertoire/screens/repertoire_list_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

/// Two repertoires that can be told apart on sight: different sides,
/// different roots, and only one of them with a line to its root.
class _Api extends RepertoireApiService {
  _Api()
      : super(
          client: MockClient((req) async {
            calls.add(req.url.path);
            return http.Response(jsonEncode({'items': []}), 200);
          }),
        );

  /// Every path this screen asked the server for, in order.
  static final List<String> calls = [];

  @override
  Future<List<RepertoireSummary>> list() async => const [
        RepertoireSummary(
          id: 3,
          name: 'Benoni',
          color: 'w',
          // A real starting position, so the pane's board has something to
          // draw and the side to move is a fact rather than a default.
          rootFen:
              'rnbqkb1r/pp1p1ppp/4pn2/2pP4/8/8/PPP1PPPP/RNBQKBNR w KQkq - 0 4',
          rootPath: ['d4', 'Nf6', 'c4', 'c5', 'd5', 'e6'],
          moves: 98,
        ),
        RepertoireSummary(
          id: 7,
          name: 'Italijanka',
          color: 'b',
          rootFen:
              'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3',
          moves: 1,
          viaSan: 'Bc4',
        ),
      ];
}

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  _Api.calls.clear();
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
    home: RepertoireListScreen(api: _Api()),
  ));
  await tester.pumpAndSettle();
}

/// Taps the row of [name] — the one target a repertoire row has.
Future<void> _tapRow(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('choosing a repertoire asks the server nothing', (tester) async {
    // The phase's whole premise. Three selections in turn, and the request log
    // must not grow by one — the summary already holds everything the pane
    // draws.
    //
    // **On master this is red for the wrong reason** and is labelled so
    // rather than dressed up: with no pane the first tap opens the build
    // screen, so the second tap finds nothing to press. Its job is to guard
    // the pane once the pane exists — the day somebody gives it a board walk
    // or a progress count, this is what goes red.
    await _pump(tester, const Size(1400, 900));
    final before = List<String>.from(_Api.calls);

    await _tapRow(tester, 'Benoni');
    await _tapRow(tester, 'Italijanka');
    await _tapRow(tester, 'Benoni');

    expect(_Api.calls, before,
        reason: 'the pane fetched something the list already had');
  });

  testWidgets('the pane draws the chosen root and the line that reached it',
      (tester) async {
    await _pump(tester, const Size(1400, 900));

    await _tapRow(tester, 'Benoni');

    // The line to the root. Nothing on the card says it, so this is the pane
    // speaking and not the list — asserting the side or `viaSan` instead
    // would have been satisfied by the row that was already there.
    expect(find.textContaining('1. d4 Nf6 2. c4'), findsOneWidget);
    // And the board it reached, which only the pane draws.
    expect(find.byType(BoardThumbnail), findsOneWidget);
  });

  testWidgets('the pane follows the row that was tapped', (tester) async {
    await _pump(tester, const Size(1400, 900));

    await _tapRow(tester, 'Benoni');
    expect(find.textContaining('1. d4 Nf6 2. c4'), findsOneWidget);

    await _tapRow(tester, 'Italijanka');

    expect(find.textContaining('1. d4 Nf6 2. c4'), findsNothing,
        reason: 'the pane is still drawing the repertoire chosen before');
  });

  testWidgets(
      'a repertoire with no line to its root says so rather than '
      'inventing one', (tester) async {
    // `rootPath` is empty for every repertoire made before it was stored, and
    // for one started from a pasted position. The card already refuses to
    // invent an opening there and the pane must not either.
    await _pump(tester, const Size(1400, 900));

    await _tapRow(tester, 'Italijanka');

    expect(tester.takeException(), isNull);
    expect(find.textContaining('From the start'), findsOneWidget);
  });

  testWidgets('only the chosen row is marked, and by an outline',
      (tester) async {
    await _pump(tester, const Size(1400, 900));

    BorderSide sideOf(String name) => (tester
            .widget<Card>(
                find.ancestor(of: find.text(name), matching: find.byType(Card)))
            .shape as RoundedRectangleBorder)
        .side;

    expect(sideOf('Benoni').width, 0, reason: 'marked before anything chosen');

    await _tapRow(tester, 'Benoni');

    expect(sideOf('Benoni').width, greaterThan(0));
    expect(sideOf('Italijanka').width, 0);
  });

  testWidgets('the board is seen from the side the repertoire is for',
      (tester) async {
    // The whole point of a repertoire is what *you* would play here, so a
    // Black repertoire's root is drawn from Black's side. A board that always
    // faced White would look right in every screenshot and wrong to the
    // person using it.
    await _pump(tester, const Size(1400, 900));

    await _tapRow(tester, 'Italijanka');
    expect(
        tester
            .widget<BoardThumbnail>(find.byType(BoardThumbnail))
            .isWhiteBottom,
        isFalse);

    await _tapRow(tester, 'Benoni');
    expect(
        tester
            .widget<BoardThumbnail>(find.byType(BoardThumbnail))
            .isWhiteBottom,
        isTrue);
  });

  testWidgets('with nothing chosen the pane says what it is for',
      (tester) async {
    await _pump(tester, const Size(1400, 900));

    expect(find.textContaining('Choose a repertoire'), findsOneWidget);
  });

  testWidgets('on a narrow window the row opens, as it does today',
      (tester) async {
    await _pump(tester, const Size(800, 900));

    await _tapRow(tester, 'Benoni');

    // Opening pushes the build screen over this one; the list's own app bar
    // title is what says we left.
    expect(find.text('Repertoire'), findsNothing,
        reason: 'the row selected instead of opening on a narrow window');
  });

  testWidgets('nothing overflows at either size', (tester) async {
    await _pump(tester, const Size(840, 700));
    expect(tester.takeException(), isNull);

    await _pump(tester, const Size(1400, 900));
    await _tapRow(tester, 'Benoni');
    expect(tester.takeException(), isNull);
  });
}
