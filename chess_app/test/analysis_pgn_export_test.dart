/// „Save as .pgn" — the Analysis export, which until now could only reach the
/// clipboard.
///
/// The saving itself is a platform channel and cannot happen in a test, so
/// `debugSavePgnFile` stands in for it and the tests ask what it was handed:
/// the text, the name, and what the screen does with each of the three answers
/// the picker can give — a path, a cancel, and a failure.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/dialogs/analysis_studio_dialogs.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';

void main() {
  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  AnalysisNode treeWithAMove() {
    final root = AnalysisNode(fen: startFen);
    final child = root.addChild(
      childFen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
      san: 'e4',
      uci: 'e2e4',
    );
    child.comment = 'The king pawn takes a central square.';
    return root;
  }

  Future<void> openExport(WidgetTester tester, AnalysisNode root) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () =>
                exportPgnDialog(context, PgnExporterService.exportToPgn(root)),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  tearDown(() => debugSavePgnFile = null);

  testWidgets('the file gets the text the dialog is showing', (tester) async {
    String? sent;
    debugSavePgnFile = ({required fileName, required pgn}) async {
      sent = pgn;
      return r'C:\games\analysis.pgn';
    };

    final root = treeWithAMove();
    await openExport(tester, root);
    await tester.tap(find.byKey(const Key('export-pgn-save-file')));
    await tester.pumpAndSettle();

    // One writer for the file and the screen: a saved PGN that is not the text
    // the trainer was looking at is the whole reason this test exists.
    expect(sent, isNotNull);
    expect(sent, contains('1. e4'));
    expect(sent, contains('The king pawn takes a central square.'));
  });

  testWidgets('the name ends in .pgn and carries the date', (tester) async {
    String? name;
    debugSavePgnFile = ({required fileName, required pgn}) async {
      name = fileName;
      return r'C:\games\analysis.pgn';
    };

    await openExport(tester, treeWithAMove());
    await tester.tap(find.byKey(const Key('export-pgn-save-file')));
    await tester.pumpAndSettle();

    expect(name, isNotNull);
    expect(name, endsWith('.pgn'));
    expect(name, pgnFileNameFor(DateTime.now()));
  });

  test('the name is the day, zero-padded', () {
    expect(pgnFileNameFor(DateTime(2026, 9, 2)), 'analysis-2026-09-02.pgn');
    expect(pgnFileNameFor(DateTime(2026, 12, 31)), 'analysis-2026-12-31.pgn');
  });

  testWidgets('a saved file closes the dialog and says where it went',
      (tester) async {
    debugSavePgnFile =
        ({required fileName, required pgn}) async => r'D:\chess\game.pgn';

    await openExport(tester, treeWithAMove());
    await tester.tap(find.byKey(const Key('export-pgn-save-file')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing,
        reason: 'the dialog has done what it was opened for');
    // The path, because „Saved" alone leaves a trainer hunting for the file.
    expect(find.textContaining(r'D:\chess\game.pgn'), findsOneWidget);
  });

  testWidgets('a cancelled save says nothing and leaves the dialog open',
      (tester) async {
    debugSavePgnFile = ({required fileName, required pgn}) async => null;

    await openExport(tester, treeWithAMove());
    await tester.tap(find.byKey(const Key('export-pgn-save-file')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing,
        reason: 'somebody who cancelled a save knows that they cancelled it');
  });

  testWidgets('a save that throws is reported and keeps the dialog',
      (tester) async {
    debugSavePgnFile = ({required fileName, required pgn}) async =>
        throw StateError('no such directory');

    await openExport(tester, treeWithAMove());
    await tester.tap(find.byKey(const Key('export-pgn-save-file')));
    await tester.pumpAndSettle();

    // The dialog stays: the text is still there to be copied, which is the
    // fallback when saving is what failed.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('could not be saved'), findsOneWidget);
  });

  testWidgets('the three actions fit a 360 dp phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    debugSavePgnFile =
        ({required fileName, required pgn}) async => r'D:\chess\game.pgn';

    await openExport(tester, treeWithAMove());

    // Reachable, not merely present: a release build paints no overflow
    // stripes, it simply clips — and a button past the edge cannot be pressed.
    await tester.tap(find.byKey(const Key('export-pgn-save-file')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the clipboard still gets it', (tester) async {
    // The button that was there before this one: saving is an addition, not a
    // replacement, and the dialog copies on open.
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await openExport(tester, treeWithAMove());

    expect(copied, hasLength(1));
    expect(copied.single, PgnExporterService.exportToPgn(treeWithAMove()));
  });
}
