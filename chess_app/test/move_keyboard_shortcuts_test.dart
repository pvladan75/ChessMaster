import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/widgets/game_screen/move_keyboard_shortcuts.dart';

/// A cursor that only remembers where it was told to go.
class _FakeCursor extends MoveCursor {
  int index = 0;
  bool atEnd = false;

  /// What lies forward. Two of them make this a fork, which is the one case
  /// where the arrow key has to ask rather than move.
  List<MoveBranch> branches = const [];
  int? taken;

  @override
  List<MoveBranch> get forwardBranches => branches;

  @override
  void takeBranch(int index) => taken = index;

  @override
  bool get canGoBack => index > 0;
  @override
  bool get canGoForward => !atEnd;

  @override
  void first() => index = 0;
  @override
  void previous() => index -= 1;
  @override
  void next() => index += 1;
  @override
  void last() {
    index = 99;
    atEnd = true;
  }

  @override
  String? get currentFen => null;
}

/// The keys that walk a line of moves.
///
/// The test worth having here is the first one. A key press is offered to
/// whatever holds the focus and then to its ancestors, so a binding that sits
/// *below* the focused node is never asked — and a freshly opened screen leaves
/// the focus on the route itself. Without the wrapper claiming it, the arrows
/// did nothing until the reader happened to click something on the screen
/// first, which is the kind of fault that gets reported as "sometimes it
/// works".
void main() {
  late _FakeCursor cursor;
  var changes = 0;

  Future<void> pump(WidgetTester tester,
      {bool enabled = true, bool withField = false}) async {
    cursor = _FakeCursor();
    changes = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MoveKeyboardShortcuts(
          cursor: cursor,
          onChanged: () => changes++,
          enabled: enabled,
          child: Column(
            children: [
              if (withField) const TextField(),
              const Text('tabla'),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('the arrows work before anything has been clicked',
      (tester) async {
    await pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(cursor.index, 1);
    expect(changes, 1);
  });

  testWidgets('each key moves where its own arrow points', (tester) async {
    await pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(cursor.index, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(cursor.index, 99);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(cursor.index, 0);
  });

  testWidgets('Home and End say the same as up and down', (tester) async {
    await pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(cursor.index, 99);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(cursor.index, 0);
  });

  testWidgets('a screen that may not be walked is not walked', (tester) async {
    // A seat that does not drive the shared board, or a position being recalled
    // before its answer is shown.
    await pump(tester, enabled: false);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(cursor.index, 0);
    expect(changes, 0);
  });

  testWidgets('at a fork the right arrow asks instead of walking',
      (tester) async {
    // The rule, and the reason it is not written on one screen: at a fork
    // "forward" has more than one meaning, and a strip that takes the first
    // child every time is a strip on which the other lines cannot be reached at
    // all. The mouse and the keyboard must not disagree about that — one
    // opening a chooser and the other silently taking the main line is worse
    // than either behaviour on its own.
    await pump(tester);
    cursor.branches = const [
      MoveBranch(label: 'Nf3', isMain: true),
      MoveBranch(label: 'Bc4'),
    ];

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(cursor.index, 0, reason: 'na račvanju se ne ide bez pitanja');
    expect(find.text('Odavde ide više linija — kojom?'), findsOneWidget);

    await tester.tap(find.text('Bc4'));
    await tester.pumpAndSettle();
    expect(cursor.taken, 1);
  });

  testWidgets('closing the chooser leaves the board where it was',
      (tester) async {
    // Being asked and saying nothing is not the same as choosing the main line.
    await pump(tester);
    cursor.branches = const [
      MoveBranch(label: 'Nf3', isMain: true),
      MoveBranch(label: 'Bc4'),
    ];

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(cursor.taken, isNull);
    expect(cursor.index, 0);
  });

  testWidgets('one way forward is not a question', (tester) async {
    // A model that does not branch answers with an empty list and is never
    // asked — which is every replayed line in this app.
    await pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(find.text('Odavde ide više linija — kojom?'), findsNothing);
    expect(cursor.index, 1);
  });

  testWidgets('a text field keeps the arrows while it has the focus',
      (tester) async {
    await pump(tester, withField: true);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Rd8');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(cursor.index, 0,
        reason: 'dok je fokus u polju, strelice pripadaju polju');
  });
}
