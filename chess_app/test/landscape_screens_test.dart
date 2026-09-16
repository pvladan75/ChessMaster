// Every board screen held sideways, pumped whole.
//
// `landscape_board_layout_test.dart` proves the layout; this proves each screen
// actually reaches it — and that what the screen puts in its slots fits there.
// A layout nobody uses, or a strip too wide for the column it was given, is the
// kind of thing only a release build on a phone would otherwise show, and it
// shows it by clipping, silently.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/archive/screens/mistake_drill_screen.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/custom_puzzle_solver_screen.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/lessons/widgets/lesson_step_editor_panel.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_new_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/reviews/screens/review_session_screen.dart';
import 'package:chess_app/features/tactics_trainer/screens/tactics_trainer_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/ai_studio_screen.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/screens/replay_player_screen.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';

import 'support/landscape.dart';
import 'features/archive/mistake_drill_screen_test.dart'
    show FakeArchiveApiService;

final _session =
    UserSession(id: 1, token: 'tok', email: 'e', name: 'N', role: 'korisnik');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const phones = landscapePhones;

  group('Analysis Studio', () {
    Widget screen() => AnalysisStudioScreen(
          userSession: _session,
          initialFen:
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        );

    for (final size in phones) {
      testWidgets('at ${size.width.toInt()}×${size.height.toInt()}',
          (tester) async {
        await pumpAt(tester, size, screen());
        expectBoardBeside(tester, size);
        // The compact bar, and a board as tall as what is under it.
        final body = size.height - LandscapeBoardLayout.compactToolbarHeight;
        final board = tester.getRect(find.byType(BoardWithCoordinates).first);
        expect(board.height, greaterThan(body - 40));
      });
    }

    testWidgets('upright, the strip stays under the board', (tester) async {
      await pumpAt(tester, const Size(360, 800), screen());
      expect(tester.takeException(), isNull);
      expect(find.byType(LandscapeBoardLayout), findsNothing);
      final board = tester.getRect(find.byType(BoardWithCoordinates).first);
      expect(tester.getRect(find.byType(MoveNavigationControls)).top,
          greaterThan(board.bottom));
    });
  });

  group('My mistakes', () {
    setUp(() => ArchiveApiService.setMock(FakeArchiveApiService()));

    for (final size in phones) {
      testWidgets('at ${size.width.toInt()}×${size.height.toInt()}',
          (tester) async {
        await pumpAt(tester, size, const MistakeDrillScreen());
        expectBoardBeside(tester, size);
        expectOnScreen(tester, size, find.text('Show answer'));

        await tester.tap(find.text('Show answer'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectOnScreen(tester, size, find.text('Hard'));
        expectOnScreen(tester, size, find.text('Easy'));
      });
    }
  });

  group('Assignment positions', () {
    final detail = AssignmentDetail(
      assignment: const Assignment(
        id: 4,
        title: 'Mate in one',
        instructions: 'By Friday',
        totalItems: 2,
      ),
      items: [
        AssignmentItem(puzzleId: 'c1', position: 0),
        AssignmentItem(puzzleId: 'c2', position: 1),
      ],
      customPositions: const [
        CustomPosition(
          puzzleId: 'c1',
          fen: '6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1',
          sideToMove: 'w',
          instruction: 'White mates in one',
        ),
        CustomPosition(
          puzzleId: 'c2',
          fen: '6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1',
          sideToMove: 'w',
        ),
      ],
    );

    for (final size in phones) {
      testWidgets(
          'at ${size.width.toInt()}×${size.height.toInt()}, '
          'an answered position keeps its buttons on screen', (tester) async {
        await pumpAt(
          tester,
          size,
          CustomPuzzleSolverScreen(
            session: _session,
            detail: detail,
            positions: detail.customPositions,
            startIndex: 0,
            answered: const {'c1': true},
          ),
        );
        expectBoardBeside(tester, size);
        expectOnScreen(tester, size, find.text('Next unsolved'));
        expectOnScreen(tester, size, find.text('Solution and comments'));
      });
    }
  });

  /// Answers every request by its path, for the screens that build their own
  /// API service and so can only be faked at the client.
  http.Client serve(Map<String, Object> byPath) => MockClient((request) async {
        for (final entry in byPath.entries) {
          if (request.url.path.endsWith(entry.key)) {
            return http.Response(jsonEncode(entry.value), 200);
          }
        }
        return http.Response('{}', 404);
      });

  const mateInOne = '6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1';

  group('Review', () {
    final server = {
      '/reviews/due': {
        'items': [
          {
            'id': 1,
            'lessonId': 2,
            'stepKey': 'k',
            'lessonTitle': 'Back rank',
            'step': {
              'title': 'Mate',
              'fen': mateInOne,
              'pgn': '1. Ra8#',
              'kind': 'ask_move',
            },
          },
        ],
        'stats': {'total': 1, 'due': 1},
      },
      '/reviews/stats': {'total': 1, 'due': 1},
    };

    for (final size in phones) {
      testWidgets('at ${size.width.toInt()}×${size.height.toInt()}',
          (tester) async {
        await http.runWithClient(() async {
          await pumpAt(tester, size, ReviewSessionScreen(session: _session));
          expectBoardBeside(tester, size);
          final reveal = find.byType(ElevatedButton);
          expectOnScreen(tester, size, reveal);

          await tester.tap(reveal.first);
          await tester.pumpAndSettle();
          expectBoardBeside(tester, size);
        }, () => serve(server));
      });
    }
  });

  group('Tactics', () {
    final server = {
      '/api/puzzles/adaptive': {
        'puzzle': {
          'puzzle_id': 'p1',
          // Before the opponent's mistake, as the server stores it.
          'fen': '6k1/5ppp/8/8/8/8/8/R5K1 b - - 0 1',
          'setup_move': 'h7h6',
          'solution': ['a1a8'],
          'rating': 1200,
          'themes': ['mateIn1'],
        },
        'selection': {'targetRating': 1200},
      },
    };

    for (final size in phones) {
      testWidgets('at ${size.width.toInt()}×${size.height.toInt()}',
          (tester) async {
        await http.runWithClient(() async {
          await pumpAt(tester, size, TacticsTrainerScreen(session: _session));
          expectBoardBeside(tester, size);
          expectOnScreen(tester, size, find.byType(OutlinedButton));
        }, () => serve(server));
      });
    }
  });

  group('New repertoire', () {
    Widget screen() => RepertoireNewScreen(
          api: RepertoireApiService(
              client: MockClient((_) async => http.Response('{}', 500))),
          // Never the real ECO dataset: it loads through an isolate that does
          // not finish inside a widget test.
          nameFor: (_) => null,
        );

    for (final size in phones) {
      testWidgets('at ${size.width.toInt()}×${size.height.toInt()}',
          (tester) async {
        await pumpAt(tester, size, screen());
        expectBoardBeside(tester, size);
        expectOnScreen(tester, size, find.byType(FilledButton));
      });
    }

    testWidgets('typing the name with the keyboard up does not overflow',
        (tester) async {
      await pumpAt(tester, const Size(800, 360), screen());
      await tester.tap(find.byType(TextField));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.testTextInput.isVisible, isTrue);
    });
  });

  group('Replay', () {
    final server = {
      '/recordings/7': {
        'id': 7,
        'title': 'Back rank ideas',
        'host_name': 'Trainer',
        'timeline_json': [
          {
            'timestampMs': 0,
            'eventType': 'fen',
            'data': {'fen': mateInOne}
          },
          {
            'timestampMs': 4000,
            'eventType': 'fen',
            'data': {'fen': mateInOne}
          },
        ],
      },
    };

    for (final size in phones) {
      testWidgets('at ${sizeLabel(size)}', (tester) async {
        await http.runWithClient(() async {
          await pumpAt(tester, size,
              ReplayPlayerScreen(recordingId: 7, userSession: _session));
          expectBoardBeside(tester, size);
          expectOnScreen(tester, size, find.byType(Slider));
          expectOnScreen(tester, size, find.byType(FloatingActionButton));
        }, () => serve(server));
      });
    }
  });

  group('Exercises (AI Studio)', () {
    for (final size in phones) {
      testWidgets('at ${sizeLabel(size)}', (tester) async {
        await pumpAt(
          tester,
          size,
          ProviderScope(
            child: AiStudioScreen(
              userSession: _session,
              initialCategory: 'basic_mate',
              basicMateLevel: 'Srednje',
            ),
          ),
        );
        expectBoardBeside(tester, size);
        expectOnScreen(tester, size, find.byTooltip('Next Position'));
      });
    }
  });

  group('Tutorial step editor (Android)', () {
    Widget screen() => Scaffold(
          appBar: AppBar(title: const Text('Tutorial parts')),
          body: LessonStepEditorPanel(
            session: _session,
            api: LessonApiService(
              authToken: 't',
              client: MockClient((_) async => http.Response('{}', 500)),
            ),
            lesson: const {
              'id': 7,
              'title': 'Back rank',
              'position_list': [
                {'id': 'a1', 'fen': mateInOne, 'title': 'First'},
                {'id': 'b2', 'fen': mateInOne, 'title': 'Second'},
              ],
            },
          ),
        );

    for (final size in phones) {
      testWidgets('at ${sizeLabel(size)}', (tester) async {
        await pumpAt(tester, size, screen());
        expectBoardBeside(tester, size);
        expectOnScreen(tester, size, find.text('Save step'));
        expectOnScreen(tester, size, find.text('Preview'));
      });
    }

    testWidgets('typing a title keeps the keyboard open', (tester) async {
      await pumpAt(tester, const Size(800, 360), screen());
      await tester.tap(find.byKey(const Key('step-title')));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(find.byKey(const Key('step-title')), 'Mate');
      await tester.pump();
      expect(find.text('Mate'), findsWidgets);
    });
  });

  group('Studio room', () {
    Widget screen() => ChessGamePage(
          roomCode: 'STUDIO',
          userSession: UserSession(
              token: 't', id: 7, email: 'a@b.c', name: 'T', role: 'trener'),
          lessonApi: LessonApiService(
            authToken: 'tok',
            client: MockClient((_) async => http.Response('[]', 200)),
          ),
        );

    for (final size in phones) {
      testWidgets('at ${sizeLabel(size)}', (tester) async {
        await pumpAt(tester, size, screen());
        expectBoardBeside(tester, size);
        expect(find.byType(MoveNavigationControls), findsOneWidget);
        // The lessons sidebar is in the drawer, not beside the board.
        expect(find.text('Tutorials and positions'), findsNothing);
      });
    }
  });
}
