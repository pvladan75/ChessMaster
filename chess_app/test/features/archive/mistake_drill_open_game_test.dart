// "Open this game in Analysis" on an archive mistake — D4 of
// `docs/PLAN-SKELET.md`: the archive's way to a tutorial is the Analysis door.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/services/game_from_moves.dart';
import 'package:chess_app/features/analysis_studio/services/open_game_in_analysis.dart';
import 'package:chess_app/features/archive/models/mistake_item.dart';
import 'package:chess_app/features/archive/models/mistake_recurrence.dart';
import 'package:chess_app/features/archive/screens/mistake_drill_screen.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/theme/app_theme.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

class _Archive implements ArchiveApiService {
  _Archive({this.missing = false});

  final bool missing;
  final asked = <String>[];

  @override
  Future<List<MistakeItem>> fetchMistakesDue({int limit = 20}) async => [
        MistakeItem(
          id: 'mistake_1',
          gameId: '77',
          ply: 3,
          fenBefore: _start,
          playedUci: 'e2e4',
          bestUci: 'd2d4',
          kind: 'engine',
          intervalDays: 1,
          repetitions: 0,
          lapses: 0,
          dueAt: DateTime(2026, 9, 14),
          playedAt: DateTime(2026, 9, 1),
          opponent: 'somebody',
          subjectColor: 'b',
        ),
      ];

  @override
  Future<MistakeRecurrence> fetchMistakeRecurrence() async =>
      const MistakeRecurrence();

  @override
  Future<({String startFen, List<String> uciMoves, String? subjectColor})>
      fetchGameMoves(String gameId) async {
    asked.add(gameId);
    if (missing) throw Exception('That game is no longer in your archive.');
    return (
      startFen: _start,
      uciMoves: const ['e2e4', 'e7e5', 'g1f3', 'b8c6'],
      subjectColor: 'b',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, _Archive archive) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  ArchiveApiService.setMock(archive);
  await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const MistakeDrillScreen()));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => debugOpenGameInAnalysis = null);

  testWidgets(
      'the game of the mistake opens on the mistake, on the player\'s side',
      (tester) async {
    final opened = <AnalysisGame>[];
    debugOpenGameInAnalysis = (context, game) async => opened.add(game);
    final archive = _Archive();
    await _pump(tester, archive);

    final button = find.byKey(const Key('mistake-open-game'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(archive.asked, ['77']);
    expect(opened, hasLength(1));
    expect(opened.single.uciMoves, ['e2e4', 'e7e5', 'g1f3', 'b8c6']);
    expect(opened.single.cursorPly, 3);
    expect(opened.single.blackOrientation, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a game no longer in the archive is said, and nothing opens',
      (tester) async {
    final opened = <AnalysisGame>[];
    debugOpenGameInAnalysis = (context, game) async => opened.add(game);
    await _pump(tester, _Archive(missing: true));

    final button = find.byKey(const Key('mistake-open-game'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(opened, isEmpty);
    expect(
        find.text('That game is no longer in your archive.'), findsOneWidget);
  });
}
