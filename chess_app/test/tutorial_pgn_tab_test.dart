import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/models/lesson_step_line.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/arrow_colors.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// T2 of `docs/PLAN-PGN-TEKST.md` — the part as text, and the text as a
/// surface.
///
/// Two things are being proved, and only one of them is the tab. The other is
/// the door: until now the only PGN import in this app went through
/// `_importPgn`, which keeps the main line and throws away every comment, every
/// mark and every variation — so an annotated line from a book, an engine or a
/// language model could not enter a tutorial except by being replayed move by
/// move and retyped. Applying text is that door, and it goes through
/// `LessonStepLine`, the reader the child's screen uses.
///
/// **Everything below asserts on the model or on the request.** A text field
/// holding the right characters proves nothing about what a child will open, so
/// the assertions save and read the line back through the one reader.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  final session = UserSession(
    token: 't',
    id: 7,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  late List<Map<String, dynamic>> saves;

  LessonApiService recordingApi() {
    saves = [];
    return LessonApiService(
      authToken: 'tok',
      client: MockClient((req) async {
        if (req.body.isNotEmpty) {
          final body = jsonDecode(req.body);
          if (body is Map && body.containsKey('positionList')) {
            saves.add(Map<String, dynamic>.from(body));
          }
        }
        return http.Response(jsonEncode({'id': 77}), 201);
      }),
    );
  }

  var nextLessonId = 400;

  Map<String, dynamic> lessonWith({String? pgn, String id = 'step-1'}) => {
        'id': nextLessonId++,
        'title': 'Otvaranje',
        'position_list': [
          {
            'id': id,
            'fen': startFen,
            'title': 'Deo 1',
            if (pgn != null) 'pgn': pgn,
            'kind': 'show',
          },
        ],
      };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  Future<void> open(WidgetTester tester, Map<String, dynamic> lesson) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.saved(lesson),
        lessonApi: recordingApi(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openTab(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('pgn-tab')));
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const Key('pgn-field')))
      .controller!
      .text;

  Future<void> typeInto(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('pgn-field')), text);
    await tester.pumpAndSettle();
  }

  ChessBoardWithOverlay board(WidgetTester tester) => tester
      .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay).first);

  Future<void> apply(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('pgn-apply')));
    await tester.pumpAndSettle();
  }

  /// What leaves the screen, read back through the child's own reader.
  Future<LessonStepLine> saveAndRead(WidgetTester tester) async {
    await tester.tap(find.text('Save tutorial'));
    await tester.pumpAndSettle();
    expect(saves, hasLength(1), reason: 'one tutorial is one write');
    final step = (saves.single['positionList'] as List).single as Map;
    return LessonStepLine.read(
      fen: step['fen'].toString(),
      pgn: step['pgn']?.toString(),
    );
  }

  group('the part as text', () {
    testWidgets('the tab shows the line the part already carries',
        (tester) async {
      await open(tester, lessonWith(pgn: '1. e4 { Zauzima centar. } e5'));
      await openTab(tester);

      final text = fieldText(tester);
      expect(text, contains('e4'));
      expect(text, contains('Zauzima centar.'));
      expect(text, contains('e5'));

      await close(tester);
    });

    testWidgets('the legend names every colour the catalogue has',
        (tester) async {
      // Generated, never listed: the picker was once written out by hand as
      // four colours while the catalogue held five, and the fifth could not be
      // chosen by anybody for months.
      await open(tester, lessonWith(pgn: '1. e4'));
      await openTab(tester);

      for (final colour in ArrowColor.all) {
        expect(find.textContaining(colour.name.toLowerCase()), findsWidgets,
            reason: '${colour.name} is missing from the legend, so its letter '
                'means nothing to the trainer');
      }

      await close(tester);
    });

    testWidgets('a part that is only a sentence shows that sentence',
        (tester) async {
      await open(tester, lessonWith(pgn: '{ Pogledaj polje d5. } *'));
      await openTab(tester);

      expect(fieldText(tester), contains('Pogledaj polje d5.'));

      await close(tester);
    });
  });

  group('applying text', () {
    testWidgets('a line typed in reaches the child', (tester) async {
      await open(tester, lessonWith(pgn: '1. e4'));
      await openTab(tester);

      await typeInto(tester, '1. d4 d5 2. c4 { Gambit. }');
      await apply(tester);

      final step = await saveAndRead(tester);

      expect(step.replays, isTrue);
      expect(step.line.movesSan, ['d4', 'd5', 'c4']);
      expect(step.line.comments.last, 'Gambit.',
          reason: 'the comment was applied to a different move than the one it '
              'was written on: ${step.line.comments}');

      await close(tester);
    });

    testWidgets('an arrow written as a tag arrives as an arrow',
        (tester) async {
      // The whole point of keeping the standard dialect: this is what Lichess
      // and every book exporter write, and it needs no reader of our own.
      await open(tester, lessonWith(pgn: '1. e4'));
      await openTab(tester);

      await typeInto(tester, '1. e4 { Ovde. [%cal Gd2d4][%csl Rd5] }');
      await apply(tester);

      final step = await saveAndRead(tester);

      expect(step.line.arrows.first.map((a) => a.toString()), ['Gd2d4']);
      expect(step.line.squares.first.map((s) => s.toString()), ['Rd5']);

      await close(tester);
    });

    testWidgets('nothing is applied until the button is pressed',
        (tester) async {
      await open(tester, lessonWith(pgn: '1. e4 e5'));
      await openTab(tester);

      await typeInto(tester, '1. d4 d5');

      final step = await saveAndRead(tester);

      expect(step.line.movesSan, ['e4', 'e5'],
          reason: 'typing changed the part before the trainer said to — half a '
              'written move is not a line, and this is what a live parse would '
              'do to a tutorial while somebody types');

      await close(tester);
    });

    testWidgets('a move that cannot be played is refused, and nothing changes',
        (tester) async {
      await open(tester, lessonWith(pgn: '1. e4 e5'));
      await openTab(tester);

      // The typed line is a **different** one, and only its last move is
      // impossible. The first version of this test typed the part's own line
      // plus a bad move, so „refused" and „applied without the move it could
      // not read" came to the same two moves — and a mutation that dropped the
      // refusal passed it. What this rule protects against is exactly that
      // second reading: a trainer watching their line come back shorter, with
      // no error anywhere.
      await typeInto(tester, '1. d4 d5 2. Qh8');
      await apply(tester);

      expect(find.textContaining('1'), findsWidgets,
          reason: 'the refusal does not say how many moves were dropped');

      final step = await saveAndRead(tester);
      expect(step.line.movesSan, ['e4', 'e5'],
          reason: 'a text with a move that cannot be played was applied '
              'anyway, and the moves it did understand replaced the part');

      await close(tester);
    });

    testWidgets('the part keeps its identity across an apply', (tester) async {
      // `assignment_items.step_key` and `review_items.step_key` name a step by
      // this id and nothing joins on it, so a part that loses it takes a
      // child's progress with it — silently.
      await open(tester, lessonWith(pgn: '1. e4', id: 'step-77'));
      await openTab(tester);

      await typeInto(tester, '1. d4');
      await apply(tester);

      await tester.tap(find.text('Save tutorial'));
      await tester.pumpAndSettle();

      final step = (saves.single['positionList'] as List).single as Map;
      expect(step['id'], 'step-77');
      // Stored as „Deo 1": a generated name is written back in the app's
      // words, which is how old tutorials lose the Serbian one.
      expect(step['title'], 'Part 1');

      await close(tester);
    });

    testWidgets('an applied part is no longer written back as its old text',
        (tester) async {
      // The pristine cache: an untouched part is sent as the exact text it was
      // read from, and a part whose text was applied is not untouched.
      await open(tester, lessonWith(pgn: '1. e4'));
      await openTab(tester);

      await typeInto(tester, '1. d4');
      await apply(tester);

      final step = await saveAndRead(tester);

      expect(step.line.movesSan, ['d4'],
          reason: 'the old stored text was sent instead of the applied one');

      await close(tester);
    });

    testWidgets('the timeline shows the line that was applied', (tester) async {
      await open(tester, lessonWith(pgn: '1. e4'));
      await openTab(tester);

      await typeInto(tester, '1. d4 d5');
      await apply(tester);

      await tester.tap(find.byKey(const Key('tok-tab')));
      await tester.pumpAndSettle();

      expect(find.textContaining('1. d4'), findsWidgets,
          reason: 'the tree was replaced but the surface reading it was not '
              'told, so the trainer is looking at the line they replaced');

      await close(tester);
    });

    testWidgets('and it leaves the trainer standing on the last move typed',
        (tester) async {
      // A trainer presses „Primeni" having just written a move on the end of
      // the text. Being put back on the opening position means finding the way
      // to it again after every application — reported live on 7.9.2026, on
      // the very fix that made a line ending in `Nxb4*` applicable at all.
      await open(tester, lessonWith(pgn: '1. e4'));
      await openTab(tester);

      await typeInto(tester, '1. d4 d5 2. c4');
      await apply(tester);

      await tester.tap(find.byKey(const Key('tok-tab')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('beat-3')),
          matching: find.byKey(const Key('beat-current')),
        ),
        findsOneWidget,
        reason: 'the last beat of the applied line is the one stood on',
      );

      await close(tester);
    });
  });

  group('the trainer is the one who types in the field', () {
    testWidgets('a move played on the board does not wipe unapplied text',
        (tester) async {
      // The field follows the tree when the tree moves — a move played, an
      // arrow drawn — but not over the top of something the trainer has
      // written and not yet applied. Without the guard this is the shape of it:
      // they type a line, reach for the board, and their text is gone.
      await open(tester, lessonWith(pgn: '1. e4'));
      await openTab(tester);
      await typeInto(tester, '1. d4 d5 { Moj tekst. }');

      // A legal move **from the position the cursor is on** — the root, white
      // to move — and one that is not already in the line, so the tree really
      // changes and the exported text with it. The first version played a
      // black move from a white-to-move position: nothing happened, and the
      // mutation this test exists for went on passing.
      board(tester).onMove('d2', 'd4', '');
      await tester.pumpAndSettle();

      expect(fieldText(tester), contains('Moj tekst.'),
          reason: 'the tree changed and took the trainer unapplied text with '
              'it');

      await close(tester);
    });
  });

  group('leaving the tab', () {
    testWidgets('unapplied text is still there when you come back',
        (tester) async {
      await open(tester, lessonWith(pgn: '1. e4'));
      await openTab(tester);
      await typeInto(tester, '1. d4 d5');

      await tester.tap(find.byKey(const Key('tok-tab')));
      await tester.pumpAndSettle();
      await openTab(tester);

      expect(fieldText(tester), contains('d5'),
          reason: 'the trainer left the tab for a moment and their text was '
              'thrown away');

      await close(tester);
    });

    testWidgets('and it is not applied on the way out either', (tester) async {
      await open(tester, lessonWith(pgn: '1. e4'));
      await openTab(tester);
      await typeInto(tester, '1. d4 d5');

      await tester.tap(find.byKey(const Key('tok-tab')));
      await tester.pumpAndSettle();

      final step = await saveAndRead(tester);
      expect(step.line.movesSan, ['e4'],
          reason: 'switching tabs applied the text quietly, which is the one '
              'thing an explicit „Primeni" exists to prevent');

      await close(tester);
    });
  });
}
