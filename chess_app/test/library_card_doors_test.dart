// What a Library card offers, per kind — from the owner's review of
// 21.9.2026, items 3 and 7.
//
// **3. A puzzle set and an analysis can be deleted from the shelf.** Reported
// on 21.9.2026 against TODO-provera 211.4: „Nema dugme za brisanje." The
// cards of those two kinds had no button at all; deleting a set was possible
// only from Analysis → „Saved puzzle sets", a place the owner had already said
// he could not find. The server routes existed for both.
//
// **7. A position is not sent; it is made into an exercise first.** The
// owner's rule of 19.9.2026 (185.5): „Pozicija mora da se prvo ubaci u
// zadatak, gde joj se daje smisao." Since phase 10 a scan with no printed
// solution *is* a position and sits under Positions — but its card still
// offered „Assign to student" (205.3), a door the server can only refuse.
// Such a card now offers „Make exercise", the same sheet the room opens, on
// that card's own position.
//
// **A recording is deleted from the shelf too** (22.9.2026, the owner asked
// whether recordings live on the server — they do, in `session_recordings` —
// and for a way to delete them there).
//
// Every card is found by its own key, so a tooltip that another card also
// carries cannot answer for this one (rule 5).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/puzzle_set_api_service.dart';
import 'package:chess_app/core/services/puzzle_set_repository.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/exercises/widgets/make_exercise_sheet.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/screens/library_screen.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/lesson_recording_api.dart';
import 'package:chess_app/theme/app_colors.dart';

const _unsolvedFen = '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1';
const _solvedFen = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';
const _positionFen = '8/8/8/4k3/8/8/4P3/4K3 w - - 0 1';

/// One server behind every seam the screen has, recording what it is asked.
class _Server {
  _Server({this.refuseDeletes = false});

  /// A server that answers every DELETE with 500 — the case where the shelf
  /// must keep the card and say so, rather than pretend.
  final bool refuseDeletes;
  final List<String> requests = [];

  http.Client get client => MockClient((req) async {
        final path = req.url.path;
        requests.add('${req.method} $path');
        if (req.method == 'DELETE') {
          return http.Response('{}', refuseDeletes ? 500 : 200);
        }
        if (path.endsWith('/library/positions')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'kind': 'scan',
                  'id': 's1',
                  'title': 'Book, no solution',
                  'fen': _unsolvedFen,
                  'sourceTitle': 'Endgames',
                  'sourcePage': 12,
                },
                {
                  'kind': 'scan',
                  'id': 's2',
                  'title': 'Book, with solution',
                  'fen': _solvedFen,
                  'hasSolution': true,
                  'solutionSan': 'Ra8#',
                  'assignable': true,
                },
                {
                  'kind': 'position',
                  'id': 'p1',
                  'title': 'Kept from the room',
                  'fen': _positionFen,
                },
                {
                  'kind': 'recording',
                  'id': '44',
                  'title': 'Lucena, recorded',
                  'fen': '',
                },
                {
                  'kind': 'analysis',
                  'id': '31',
                  'title': 'Sicilian notes',
                  'fen': _positionFen,
                },
              ],
            }),
            200,
          );
        }
        if (path.endsWith('/puzzle-sets')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'set-1',
                  'title': 'Blunders vs Ana',
                  'createdAt': '2026-09-20T10:00:00.000',
                  'puzzles': [
                    {
                      'id': 'set-1-a',
                      'fen': '8/8/8/8/8/8/8/K6k w - - 0 1',
                      'themeLabel': 'fork',
                      'themeKey': 'fork',
                      'swing': 2.5,
                      'sourceMoveSan': 'Nf3',
                      'sourcePlyIndex': 4,
                    }
                  ],
                }
              ],
            }),
            200,
          );
        }
        if (path.endsWith('/lessons/labels')) return http.Response('[]', 200);
        if (path.endsWith('/lessons')) return http.Response('[]', 200);
        return http.Response('{}', 404);
      });

  List<String> deletes() =>
      requests.where((r) => r.startsWith('DELETE')).toList();
}

Future<_Server> _open(WidgetTester tester, {bool refuseDeletes = false}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final server = _Server(refuseDeletes: refuseDeletes);
  final client = server.client;
  AnalysisPersistenceService.setInstance(
      AnalysisPersistenceService.withClient(client));
  addTearDown(AnalysisPersistenceService.resetInstance);

  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
    home: LibraryScreen(
      session: UserSession(
          token: 'tok', id: 1, email: 'e', name: 'N', role: 'trener'),
      positionLibrary: PositionLibraryService(authToken: 'tok', client: client),
      lessonApi: LessonApiService(authToken: 'tok', client: client),
      exerciseApi: ExerciseApiService(authToken: 'tok', client: client),
      puzzleSets: PuzzleSetRepository(
        api: PuzzleSetApiService(authToken: 'tok', client: client),
      ),
      recordingApi: LessonRecordingApi(authToken: 'tok', client: client),
    ),
  ));
  await tester.pumpAndSettle();
  return server;
}

Finder _card(String kindAndId) =>
    find.byKey(ValueKey('library-row-$kindAndId'));

Finder _button(String kindAndId, String tooltip) =>
    find.descendant(of: _card(kindAndId), matching: find.byTooltip(tooltip));

void main() {
  group('7: a position is made into an exercise, not sent', () {
    testWidgets('a scan with no solution offers „Make exercise", not „Assign"',
        (tester) async {
      await _open(tester);
      expect(_card('scan-s1'), findsOneWidget, reason: 'the card is missing');

      expect(_button('scan-s1', 'Assign to student'), findsNothing,
          reason: 'a position the server can only refuse is offered as '
              'homework');
      expect(_button('scan-s1', 'Make exercise'), findsOneWidget);
      expect(_button('scan-s1', 'Add to tutorial'), findsOneWidget,
          reason: 'a position still goes into a tutorial as it did');
    });

    testWidgets('a saved position offers „Make exercise" too', (tester) async {
      await _open(tester);
      expect(_card('position-p1'), findsOneWidget);
      expect(_button('position-p1', 'Make exercise'), findsOneWidget);
      expect(_button('position-p1', 'Assign to student'), findsNothing);
    });

    testWidgets('an exercise keeps „Assign" and is not offered to be made',
        (tester) async {
      await _open(tester);
      expect(_card('scan-s2'), findsOneWidget);
      expect(_button('scan-s2', 'Assign to student'), findsOneWidget,
          reason: 'the rule took the door away from real exercises as well');
      expect(_button('scan-s2', 'Make exercise'), findsNothing);
    });

    testWidgets('„Make exercise" opens the sheet on that card\'s position',
        (tester) async {
      await _open(tester);
      await tester.tap(_button('scan-s1', 'Make exercise'));
      await tester.pumpAndSettle();

      final sheet =
          tester.widget<MakeExerciseSheet>(find.byType(MakeExerciseSheet));
      expect(sheet.moveTree?.root.fen, _unsolvedFen,
          reason: 'the sheet opened on some other board');
      // Nothing has been played on it, so „Find the move" is answered on the
      // exercise's own screen — the phase 14 door, not a red refusal.
      expect(find.text('Play the move'), findsOneWidget);
    });
  });

  group('3: a puzzle set and an analysis are deleted from the shelf', () {
    testWidgets('a puzzle set: asked, sent, and gone from the shelf',
        (tester) async {
      final server = await _open(tester);
      expect(_card('puzzleSet-set-1'), findsOneWidget);

      await tester.tap(_button('puzzleSet-set-1', 'Delete puzzle set'));
      await tester.pumpAndSettle();
      expect(server.deletes(), isEmpty,
          reason: 'deleted before the reader was asked');
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(server.deletes(), ['DELETE /puzzle-sets/set-1']);
      expect(_card('puzzleSet-set-1'), findsNothing);
    });

    testWidgets('an analysis: asked, sent, and gone from the shelf',
        (tester) async {
      final server = await _open(tester);
      expect(_card('analysis-31'), findsOneWidget);

      await tester.tap(_button('analysis-31', 'Delete analysis'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(server.deletes(), ['DELETE /analysis/31']);
      expect(_card('analysis-31'), findsNothing);
    });

    testWidgets('a refused delete keeps the card and says so', (tester) async {
      // The recurring bug of this codebase, in the one shape this door could
      // take: a card that vanishes while the server still has it, and is back
      // on the next load.
      final server = await _open(tester, refuseDeletes: true);

      await tester.tap(_button('puzzleSet-set-1', 'Delete puzzle set'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(server.deletes(), ['DELETE /puzzle-sets/set-1']);
      expect(_card('puzzleSet-set-1'), findsOneWidget,
          reason: 'the card went although the server refused');
      expect(find.textContaining('could not be deleted'), findsOneWidget);

      await tester.tap(_button('analysis-31', 'Delete analysis'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(_card('analysis-31'), findsOneWidget,
          reason: 'the card went although the server refused');
    });
  });

  group('a recording is deleted from the shelf', () {
    testWidgets('asked, sent, and gone from the shelf', (tester) async {
      final server = await _open(tester);
      expect(_card('recording-44'), findsOneWidget);
      expect(_button('recording-44', 'Play'), findsOneWidget,
          reason: 'the delete took the place of „Play"');

      await tester.tap(_button('recording-44', 'Delete recording'));
      await tester.pumpAndSettle();
      expect(server.deletes(), isEmpty,
          reason: 'deleted before the reader was asked');
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(server.deletes(), ['DELETE /recordings/44']);
      expect(_card('recording-44'), findsNothing);
      // Gone from the shelf is the whole answer: no message after a delete
      // (the owner, 22.9.2026 — deleting many queued one message each).
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('„Cancel" sends nothing and keeps the card', (tester) async {
      final server = await _open(tester);
      await tester.tap(_button('recording-44', 'Delete recording'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(server.deletes(), isEmpty);
      expect(_card('recording-44'), findsOneWidget);
    });

    testWidgets('a refused delete keeps the card and says so', (tester) async {
      final server = await _open(tester, refuseDeletes: true);
      await tester.tap(_button('recording-44', 'Delete recording'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(server.deletes(), ['DELETE /recordings/44']);
      expect(_card('recording-44'), findsOneWidget,
          reason: 'the card went although the server refused');
      expect(find.textContaining('could not be deleted'), findsOneWidget);
    });
  });
}
