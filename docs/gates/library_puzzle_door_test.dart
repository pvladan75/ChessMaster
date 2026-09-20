// A puzzle set on the Library shelf can be opened from there.
//
// Reported live by the owner, 20.9.2026: „Library - Puzzle sets. Klikom na set
// puzzle se ništa ne dešava." He had already said, one item earlier, that he
// did not know where saved puzzles live at all — and the Library is where he
// looked. The two reports are one fault.
//
// It was not a regression and it was not hidden: `library_screen.dart` said so
// in a comment — *drawn, but tapping it does nothing* — because the only way
// into puzzle mode was the Analysis screen the set was extracted in. A card on
// a shelf that answers nothing is the rule this project keeps paying for: every
// layer can be right and the feature still unreachable.
//
// The door is the shape the screen already has. `AnalysisStudioScreen` takes
// `initialFen`, `initialGame` and `initialTree`, each of them a caller saying
// „open exactly this"; `initialPuzzles` is the fourth and behaves like the
// other three, the device draft included — the caller asked for this set, so
// a draft must not overwrite it.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/core/services/local_puzzle_set_storage_service.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/screens/library_screen.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';

/// A server with an empty shelf: everything this file is about is device-local
/// (`LocalPuzzleSetStorageService`), and a puzzle set has no wire kind at all,
/// so the rows under test never come from here.
http.Client _server() => MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('/library/positions')) {
        return http.Response(jsonEncode({'items': <Object>[]}), 200);
      }
      if (path.endsWith('/lessons/labels')) return http.Response('[]', 200);
      if (path.endsWith('/lessons')) return http.Response('[]', 200);
      return http.Response('{}', 404);
    });

LocalPuzzle _puzzle(String id, String theme) => LocalPuzzle(
      id: id,
      fen: '8/8/8/8/8/8/8/K6k w - - 0 1',
      themeLabel: theme,
      themeKey: theme,
      swing: 2.5,
      sourceMoveSan: 'Nf3',
      sourcePlyIndex: 4,
    );

/// Seeds the real storage key with JSON the model itself produced — the same
/// fixture shape phase 3a used, so both ends of this feature are stood up from
/// one writer (rule 12).
///
/// [withDraft] puts an analysis draft on the device as well, which is the
/// state the „wins over the draft" rule is about and the only state in which
/// it can fail.
Future<void> _seed(List<SavedPuzzleSet> sets, {bool withDraft = false}) async {
  final values = <String, Object>{
    'analysis_studio_puzzle_sets':
        jsonEncode(sets.map((s) => s.toJson()).toList()),
  };
  if (withDraft) {
    final root = AnalysisNode(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
    root.addChild(
      childFen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
      san: 'e4',
      uci: 'e2e4',
    );
    values['analysis_studio_draft'] = jsonEncode({
      'tree': root.toJson(),
      'path': [0],
      'blackOrientation': false,
      'savedAt': DateTime(2026, 9, 19).toIso8601String(),
    });
  }
  SharedPreferences.setMockInitialValues(values);
}

/// Two sets, so "it opened *a* set" cannot pass for "it opened *that* set".
///
/// Their puzzles carry **different themes**, which is what makes the second
/// case bite: the screen announces the theme of the puzzle it loads, so the
/// set that was actually opened is readable off the screen rather than off the
/// widget's constructor. A fixture whose two sets held the same puzzle would
/// be green whichever one opened (rule 6).
List<SavedPuzzleSet> _twoSets() => [
      SavedPuzzleSet(
        id: 'set-newer',
        title: 'Newer set',
        createdAt: DateTime(2026, 9, 19),
        puzzles: [_puzzle('newer-a', 'fork'), _puzzle('newer-b', 'fork')],
      ),
      SavedPuzzleSet(
        id: 'set-older',
        title: 'Older set',
        createdAt: DateTime(2026, 9, 12),
        puzzles: [_puzzle('older-a', 'skewer')],
      ),
    ];

Future<void> _openLibrary(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final client = _server();
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
    home: LibraryScreen(
      session: UserSession(
          token: 'tok', id: 1, email: 'e', name: 'N', role: 'trener'),
      positionLibrary: PositionLibraryService(authToken: 'tok', client: client),
      lessonApi: LessonApiService(authToken: 'tok', client: client),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Taps the card a set's title is drawn on, rather than a key or a type: the
/// claim is about what a reader reaches by touching the thing they can see.
Future<void> _tapSet(WidgetTester tester, String title) async {
  final card = find.text(title);
  expect(card, findsOneWidget, reason: '„$title" is not on the shelf at all');
  await tester.tap(card);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('tapping a puzzle set opens it', (tester) async {
    await _seed(_twoSets());
    await _openLibrary(tester, const Size(1400, 900));

    await _tapSet(tester, 'Newer set');

    expect(find.byType(AnalysisStudioScreen), findsOneWidget,
        reason: 'the card is drawn on the shelf and answers nothing');
  });

  testWidgets('it opens that set, not another', (tester) async {
    await _seed(_twoSets());
    await _openLibrary(tester, const Size(1400, 900));

    await _tapSet(tester, 'Older set');

    // The screen names the theme of the puzzle it loaded. Both sets open the
    // same board, so the theme is the only thing that tells them apart — and
    // it is what a reader sees, not what the constructor was passed.
    expect(find.textContaining('skewer'), findsOneWidget,
        reason: 'a set opened, but not the one that was tapped');
    expect(find.textContaining('fork'), findsNothing);
  });

  testWidgets('a set with no puzzles says so instead of opening empty',
      (tester) async {
    await _seed([
      SavedPuzzleSet(
        id: 'set-empty',
        title: 'Empty set',
        createdAt: DateTime(2026, 9, 19),
        puzzles: const [],
      ),
    ]);
    await _openLibrary(tester, const Size(1400, 900));

    await _tapSet(tester, 'Empty set');

    expect(find.byType(AnalysisStudioScreen), findsNothing);
    expect(find.textContaining('no puzzles'), findsOneWidget);
  });

  testWidgets('on a phone the same tap reaches the same door', (tester) async {
    // The owner looks at this on the phone, and the Library draws one column
    // there. The door must not be a wide-window affordance.
    await _seed(_twoSets());
    await _openLibrary(tester, const Size(360, 760));

    await _tapSet(tester, 'Newer set');

    expect(find.byType(AnalysisStudioScreen), findsOneWidget);
  });

  testWidgets(
      'a draft on the device does not replace the set that was asked '
      'for', (tester) async {
    // The rule the other three „open exactly this" parameters already carry:
    // a caller who names a thing beats the scratch draft. Without a draft on
    // the device this claim cannot fail, so the fixture puts one there.
    await _seed(_twoSets(), withDraft: true);
    await _openLibrary(tester, const Size(1400, 900));

    await _tapSet(tester, 'Older set');

    expect(find.textContaining('skewer'), findsOneWidget,
        reason: 'the device draft opened instead of the set that was tapped');
    expect(find.text('1. e4'), findsNothing,
        reason: 'the draft was restored over the puzzle set');
  });

  testWidgets('the shelf still draws the sets it always drew', (tester) async {
    // Guarding: the fix must be a door, not a deletion. „Delete the card" also
    // makes the dead tap go away.
    await _seed(_twoSets());
    await _openLibrary(tester, const Size(1400, 900));

    expect(find.text('Newer set'), findsOneWidget);
    expect(find.text('Older set'), findsOneWidget);
  });
}
