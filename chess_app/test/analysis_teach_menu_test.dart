// The one door from Analysis into teaching material — the sheet itself.
//
// Phase 1 of docs/PLAN-REORGANIZACIJA.md (S2). The Analysis screen does not
// build in a widget test (an engine and three network services start with
// it), so the sheet is its own widget and is tested alone: which rows it draws
// for what it was given, and that a row closes the sheet and then calls its
// callback. What the screen does with each callback is the flow each existing
// test already drives (`game_tutorial_flow_test`, `tutorial_ulaz_test`).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/widgets/teach_menu.dart';
import 'package:chess_app/theme/app_colors.dart';

void main() {
  final calls = <String>[];
  setUp(calls.clear);

  Widget host({
    bool hasLine = true,
    bool hasGame = true,
  }) =>
      MaterialApp(
        theme: ThemeData.light()
            .copyWith(extensions: const [AppColorTokens.light]),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showTeachMenu(
                  context,
                  hasLine: hasLine,
                  hasGame: hasGame,
                  onNewFromPosition: () => calls.add('newPosition'),
                  onNewFromLine: () => calls.add('newLine'),
                  onNewFromGame: () => calls.add('newGame'),
                  onAddPosition: () => calls.add('addPosition'),
                  onAddLine: () => calls.add('addLine'),
                  onEdit: () => calls.add('edit'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  Future<void> open(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  List<String> rowsShown(WidgetTester tester) => tester
      .widgetList<ListTile>(find.byType(ListTile))
      .map((t) => (t.title as Text).data!)
      .toList();

  testWidgets('with a line and a game: six rows, in order', (tester) async {
    await open(tester, host());
    expect(find.text(TeachMenuSheet.title), findsOneWidget);
    expect(rowsShown(tester), [
      'New tutorial from this position',
      'New tutorial from this line',
      'New tutorial from this game',
      'Add this position to a tutorial…',
      'Add this line to a tutorial…',
      'Open a tutorial to edit…',
    ]);
    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('on a bare position: no line rows, no game row', (tester) async {
    await open(tester, host(hasLine: false, hasGame: false));
    expect(rowsShown(tester), [
      'New tutorial from this position',
      'Add this position to a tutorial…',
      'Open a tutorial to edit…',
    ]);
  });

  for (final (label, expected) in [
    ('New tutorial from this position', 'newPosition'),
    ('New tutorial from this line', 'newLine'),
    ('New tutorial from this game', 'newGame'),
    ('Add this position to a tutorial…', 'addPosition'),
    ('Add this line to a tutorial…', 'addLine'),
    ('Open a tutorial to edit…', 'edit'),
  ]) {
    testWidgets('„$label" closes the sheet, then calls $expected once',
        (tester) async {
      await open(tester, host());
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(calls, [expected]);
      expect(find.byType(TeachMenuSheet), findsNothing,
          reason: 'the sheet is still open under whatever the row pushed');
    });
  }

  testWidgets('fits a 360 dp phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await open(tester, host());
    expect(tester.takeException(), isNull);
    expect(find.byType(TeachMenuSheet), findsOneWidget);
  });
}
