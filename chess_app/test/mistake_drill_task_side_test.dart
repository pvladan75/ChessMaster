// Phase 3 of docs/PLAN-EKRANI.md, the case its gate did not ask: the task
// names the side to move in the position of the mistake, before an answer
// *and after one*. The panel is built after the answer is played on the
// board, and a task read from the board's own turn then named the other side
// („Black to move" over a position where White was to play).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/archive/models/mistake_item.dart';
import 'package:chess_app/features/archive/screens/mistake_drill_screen.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/theme/app_theme.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

import 'features/archive/mistake_drill_screen_test.dart'
    show FakeArchiveApiService;

/// After 1.e4: Black to move, and the best reply was ...e5.
const _blackToMove =
    'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';

class _Api extends FakeArchiveApiService {
  @override
  Future<List<MistakeItem>> fetchMistakesDue({int limit = 20}) async => [
        MistakeItem(
          id: 'm1',
          gameId: 'g',
          fenBefore: _blackToMove,
          playedUci: 'c7c5',
          bestUci: 'e7e5',
          swingCp: 80,
          playedAt: DateTime(2026, 9, 12),
          kind: 'engine',
          ply: 1,
          dueAt: DateTime(2026, 10, 3),
          intervalDays: 1,
          lapses: 0,
          repetitions: 0,
        ),
      ];
}

void main() {
  testWidgets('the task names the side of the position, before and after',
      (tester) async {
    ArchiveApiService.setMock(_Api());
    tester.view.physicalSize = const Size(1536, 792);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const MistakeDrillScreen(),
    ));
    await tester.pumpAndSettle();
    const task = 'Black to move. Recall the better move.';
    expect(find.text(task), findsOneWidget);

    tester
        .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
        .onMove('a7', 'a6', '');
    await tester.pumpAndSettle();
    expect(find.text(task), findsOneWidget,
        reason: 'after the answer the board is on the other side\'s turn');
    expect(find.text('White to move. Recall the better move.'), findsNothing);
  });
}
