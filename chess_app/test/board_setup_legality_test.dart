// The editor must not let a position that is not chess onto a board.
//
// The FEN tab has refused one since 30.8.2026, when a hand-made position with
// no king reached the engine and took the application down; the room's paste
// field and the tutorial importer refuse one too. The editor was the one door
// that did not, so the very fault the guard was written for could still be
// built by hand, one piece at a time.
//
// Asked for on 19.9.2026: „onemogućiti da se nelegalna pozicija uopšte postavi
// na tablu (ne samo bez kralja, već i sa 2 bela kralja, 10 pešaka…)".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/widgets/board_setup_dialog.dart';
import 'package:chess_app/theme/app_colors.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

void main() {
  /// The dialog on a desktop, with the editor showing, and whatever it hands
  /// over collected so a test can ask whether anything left at all.
  Future<List<String>> open(WidgetTester tester) async {
    final delivered = <String>[];
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: Scaffold(
        body: Builder(
          builder: (context) => AnalysisBoardSetupDialog(
            initialFen: _startFen,
            onPositionSet: delivered.add,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    tester.widget<TabBar>(find.byType(TabBar)).controller!.animateTo(1);
    await tester.pumpAndSettle();
    return delivered;
  }

  final confirm =
      find.widgetWithText(ElevatedButton, 'Generate and Set Position');
  final reason = find.byKey(const ValueKey('builder-illegal'));

  bool enabled(WidgetTester tester) =>
      tester.widget<ElevatedButton>(confirm).onPressed != null;

  String reasonText(WidgetTester tester) => tester.widget<Text>(reason).data!;

  /// Arms [piece] and puts it on the square at [row], [col] — row 0 is the
  /// eighth rank, as in the FEN this writes.
  Future<void> place(
      WidgetTester tester, String piece, int row, int col) async {
    await tester.tap(find.byKey(ValueKey('palette-$piece')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('square-$row-$col')));
    await tester.pumpAndSettle();
  }

  Future<void> clearBoard(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear board'));
    await tester.pumpAndSettle();
  }

  testWidgets('the starting position is offered, not refused', (tester) async {
    // The baseline, and it has to be green before any red below means
    // anything: a guard that refuses everything refuses nothing in particular.
    await open(tester);
    expect(reason, findsNothing);
    expect(enabled(tester), isTrue);
  });

  testWidgets('an empty board is refused, and nothing leaves the dialog',
      (tester) async {
    final delivered = await open(tester);
    await clearBoard(tester);

    expect(reason, findsOneWidget);
    expect(reasonText(tester), contains('kings'));
    expect(enabled(tester), isFalse);

    // The part that matters: the button is not merely grey. Tapping it must
    // hand nothing over and leave the dialog open, so a position that is not
    // chess cannot reach a board by any route through this tab.
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(delivered, isEmpty);
    expect(find.byType(AnalysisBoardSetupDialog), findsOneWidget);
  });

  testWidgets('a second white king is refused', (tester) async {
    final delivered = await open(tester);
    await place(tester, 'K', 4, 4);

    expect(reason, findsOneWidget);
    expect(reasonText(tester), contains('more than one white king'));
    expect(enabled(tester), isFalse);
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(delivered, isEmpty);
  });

  testWidgets('a ninth and a tenth white pawn are refused', (tester) async {
    final delivered = await open(tester);
    await place(tester, 'P', 4, 0);
    // Nine is already too many, but the report said ten, and the second one
    // proves the reason is counting rather than tripping once.
    expect(reasonText(tester), contains('Too many pawns'));
    await place(tester, 'P', 4, 1);

    expect(reasonText(tester), contains('Too many pawns'));
    expect(reasonText(tester), contains('10'));
    expect(enabled(tester), isFalse);
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(delivered, isEmpty);
  });

  testWidgets('a pawn on the last rank is refused', (tester) async {
    await open(tester);
    await clearBoard(tester);
    await place(tester, 'K', 7, 4); // white king, first rank
    await place(tester, 'k', 0, 0); // black king, eighth rank
    expect(enabled(tester), isTrue, reason: 'two kings alone are a position');

    await place(tester, 'P', 0, 4); // a white pawn on the eighth rank
    expect(reasonText(tester), contains('eighth rank'));
    expect(enabled(tester), isFalse);
  });

  testWidgets('and the side not to move may not already be in check',
      (tester) async {
    await open(tester);
    await clearBoard(tester);
    await place(tester, 'K', 7, 4);
    await place(tester, 'k', 0, 4);
    // A white rook on the file the black king stands on, with White to move:
    // Black is in check on a move that is not theirs, which no game reaches.
    await place(tester, 'R', 4, 4);
    expect(reasonText(tester), contains('not to move'));
    expect(enabled(tester), isFalse);
  });

  testWidgets('a legal position built by hand is handed over', (tester) async {
    // The other half of every refusal: the editor still works. Without this
    // the whole file is satisfied by a guard that never says yes.
    final delivered = await open(tester);
    await clearBoard(tester);
    await place(tester, 'K', 7, 4);
    // h8, not a8: a black king on a8 with a white queen on e4 is in check
    // along the long diagonal, on a move that is White's. The first draft of
    // this test put it there and the guard refused it — which is the guard
    // working, and a fair warning that „a couple of kings and a queen" is not
    // automatically a position.
    await place(tester, 'k', 0, 7);
    await place(tester, 'Q', 4, 4);

    expect(reason, findsNothing);
    expect(enabled(tester), isTrue);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(delivered, hasLength(1));
    expect(delivered.single, startsWith('7k/8/8/8/4Q3/8/8/4K3'));
  });
}
