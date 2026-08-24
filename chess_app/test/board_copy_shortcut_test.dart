import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/core/services/board_on_screen.dart';
import 'package:chess_app/widgets/desktop_shortcuts.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// Ctrl+C copies the position, the way the right click already does.
///
/// The interesting half is not that it copies — it is that it copies from the
/// board that is on screen, and that a text field keeps its own copy. A
/// shortcut above the whole app that quietly ate Ctrl+C in every comment box
/// would be a bad trade for a convenience on the board.
void main() {
  late List<String> copied;

  setUp(() {
    BoardOnScreen.reset();
    copied = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpBoard(WidgetTester tester, {bool withField = false}) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = ChessBoardController();
    addTearDown(controller.dispose);

    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              if (withField) const TextField(autofocus: true),
              ChessBoardWithOverlay(
                controller: controller,
                boardOrientation: PlayerColor.white,
                boardSize: 300,
                isAllowedToMove: false,
                isDrawingMode: false,
                drawingStartSquare: null,
                arrows: const [],
                engineArrows: const [],
                onMove: (_, __) {},
                onSquareTapForDrawing: (_) {},
              ),
            ],
          ),
        ),
      ),
    ]);
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => DesktopShortcuts(
        router: router,
        child: child ?? const SizedBox.shrink(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> pressCtrlC(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  testWidgets('Ctrl+C copies the position of the board on screen',
      (tester) async {
    await pumpBoard(tester);
    await pressCtrlC(tester);

    expect(copied, hasLength(1));
    expect(copied.single, startsWith('rnbqkbnr/pppppppp'));
  });

  testWidgets('a text field keeps its own Ctrl+C', (tester) async {
    // Otherwise copying a comment would put a chess position on the clipboard,
    // which is the sort of thing nobody reports and everybody works around.
    await pumpBoard(tester, withField: true);
    await tester.enterText(find.byType(TextField), 'beli stoji bolje');
    await tester.pump();

    // With something selected, the field has a copy of its own to do — and it
    // is the one that must win, since it is where the reader is.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(copied, ['beli stoji bolje'],
        reason: 'polje za tekst mora da zadrži svoj Ctrl+C');
  });

  testWidgets('a board that is gone is not copied from', (tester) async {
    await pumpBoard(tester);
    expect(BoardOnScreen.isPresent, isTrue);

    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pump();

    expect(BoardOnScreen.isPresent, isFalse,
        reason: 'tabla koja je nestala mora da se odjavi');
  });

  test('the last board drawn is the one the keyboard means', () {
    // A dialog with a board over a screen with a board: while it is open the
    // keys mean the dialog's, and when it closes they mean the screen's again.
    BoardOnScreen.reset();
    final copied = <String>[];
    void screen() => copied.add('screen');
    void dialog() => copied.add('dialog');

    BoardOnScreen.register(screen);
    BoardOnScreen.copyPosition();
    BoardOnScreen.register(dialog);
    BoardOnScreen.copyPosition();
    BoardOnScreen.forget(dialog);
    BoardOnScreen.copyPosition();

    expect(copied, ['screen', 'dialog', 'screen']);
  });
}
