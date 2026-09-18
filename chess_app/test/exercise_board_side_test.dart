// A game exercise's board is turned to the side the student plays — in the
// Library's row and in the preview. Added by the lead while grading phase 4 of
// docs/PLAN-EXERCISE.md: the mutation „the board faces White always" survived
// the gate and the worker's own tests, so nothing was looking.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/library/models/library_entry.dart';
import 'package:chess_app/features/library/widgets/board_preview_dialog.dart';
import 'package:chess_app/features/library/widgets/library_list.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

const _kpk = '8/8/8/4k3/8/4K3/4P3/8 b - - 0 1';

LibraryEntry _exercise(String id, Map<String, dynamic>? task) =>
    LibraryEntry.fromJson({
      'kind': 'scan',
      'id': id,
      'title': id,
      'fen': _kpk,
      'assignable': true,
      'origin': 'manual',
      if (task != null) 'task': task,
    });

final _asBlack = _exercise(
    'as_black', {'type': 'game', 'fen': _kpk, 'side': 'b', 'goal': 'hold'});
final _asWhite = _exercise(
    'as_white', {'type': 'game', 'fen': _kpk, 'side': 'w', 'goal': 'win'});
// A find exercise has no side of its own: White at the bottom, as a diagram.
final _find = _exercise('find', {'type': 'find'});

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

bool _whiteBottomIn(WidgetTester tester, Finder scope) => tester
    .widget<BoardThumbnail>(
        find.descendant(of: scope, matching: find.byType(BoardThumbnail)))
    .isWhiteBottom;

void main() {
  testWidgets('a row turns the board to the student\'s side', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(LibraryList(
      entries: [_asBlack, _asWhite, _find],
      onOpen: (_) {},
    )));
    await tester.pumpAndSettle();

    Finder row(String id) => find.byKey(ValueKey('library-row-scan-$id'));
    expect(_whiteBottomIn(tester, row('as_black')), isFalse);
    expect(_whiteBottomIn(tester, row('as_white')), isTrue);
    expect(_whiteBottomIn(tester, row('find')), isTrue);
  });

  testWidgets('the preview turns it the same way', (tester) async {
    await tester.pumpWidget(_wrap(BoardPreviewDialog(entry: _asBlack)));
    await tester.pumpAndSettle();
    expect(_whiteBottomIn(tester, find.byType(BoardPreviewDialog)), isFalse);

    await tester.pumpWidget(_wrap(BoardPreviewDialog(entry: _asWhite)));
    await tester.pumpAndSettle();
    expect(_whiteBottomIn(tester, find.byType(BoardPreviewDialog)), isTrue);
  });
}
