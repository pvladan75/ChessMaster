// „Insert a line here" through the studio's own controls — phase 3 of
// docs/PLAN-STUDIO-ISTORIJA.md.
//
// The owner's example, played the way a trainer would: stand on Kc6, press
// the button on that beat's card, play 2. Ra8 Bb2, save. Every assertion reads
// the save **request** and reads each part's line back through
// `LessonStepLine`, the child's parser — the three parts the child will get,
// not the three rows the screen draws.

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
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

const _fen = '8/3k4/1n3b2/8/8/8/2PK4/2R5 w - - 0 1';
const _pgn = '{The rook has a job. [%csl Gc1]} '
    '1. Ra1 {Rook to the a-file. [%cal Ga1a8]} '
    'Kc6 {The king steps up. [%csl Rc6]} '
    '2. Ra6 {The knight is pinned. [%cal Ga6c6]} '
    'Bb2 {The bishop hits a1. [%csl Gb2]} '
    '3. c3 {The pawn closes the diagonal. [%cal Gc2c3]} '
    'Kb5 {And the rook is attacked. [%csl Ra6]}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final session = UserSession(
    token: 't',
    id: 7,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  // One id per test: the studio adopts a stored draft whose `lessonId`
  // matches, and flushes its own on dispose.
  var nextLessonId = 800;

  Map<String, dynamic> lesson(List<Map<String, dynamic>> parts) => {
        'id': nextLessonId++,
        'title': 'The rook behind',
        'language': 'en',
        'position_list': parts,
      };

  final example = {
    'id': 'orig',
    'fen': _fen,
    'title': 'Ra1',
    'kind': 'show',
    'pgn': _pgn,
  };

  Future<List<Map<String, dynamic>>> open(
      WidgetTester tester, Map<String, dynamic> row) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
    final saves = <Map<String, dynamic>>[];
    var minted = 0;
    final api = LessonApiService(
      authToken: 'tok',
      client: MockClient((req) async {
        final body = req.body.isEmpty
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(jsonDecode(req.body) as Map);
        if (!body.containsKey('positionList')) {
          return http.Response('{"error":"not here"}', 404);
        }
        saves.add(body);
        return http.Response(
          jsonEncode({
            'id': row['id'],
            'position_list': [
              for (final s in body['positionList'] as List)
                {...(s as Map), 'id': s['id'] ?? 'minted${minted++}'},
            ],
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.saved(row),
        lessonApi: api,
      ),
    ));
    await tester.pumpAndSettle();
    return saves;
  }

  final insert = find.byKey(const Key('insert-line'));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> play(WidgetTester tester, String from, String to) async {
    tester
        .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay).first)
        .onMove(from, to, '');
    await tester.pumpAndSettle();
  }

  Future<List<Map<String, dynamic>>> save(
      WidgetTester tester, List<Map<String, dynamic>> saves) async {
    await tap(tester, find.text('Save tutorial'));
    return [
      for (final p in saves.last['positionList'] as List)
        Map<String, dynamic>.from(p as Map),
    ];
  }

  LessonStepLine read(Map<String, dynamic> part) => LessonStepLine.read(
      fen: part['fen'] as String, pgn: part['pgn'] as String?);

  testWidgets('the owner\'s example: cut at Kc6, play 2. Ra8 Bb2, save',
      (tester) async {
    final saves = await open(tester, lesson([example]));

    await tap(tester, find.byKey(const Key('beat-2'))); // after 1... Kc6
    await tap(tester, insert);
    // On the new line's first position — the rook on a1, not on c1 where the
    // part started — so this move is only legal if the board moved there.
    await play(tester, 'a1', 'a8');
    await play(tester, 'f6', 'b2');

    final parts = await save(tester, saves);
    expect(parts.map((p) => p['id']), ['orig', null, null],
        reason: 'the first part is still the step a child has progress on');

    final a = read(parts[0]);
    expect(a.replays, isTrue);
    expect(a.line.movesSan, ['Ra1', 'Kc6']);
    expect(a.line.rootComment, 'The rook has a job.');
    expect(a.line.comments, ['Rook to the a-file.', 'The king steps up.']);
    expect(a.line.squares[1].single.toString(), 'Rc6');

    final b = read(parts[1]);
    expect(b.replays, isTrue);
    expect(b.line.movesSan, ['Ra8', 'Bb2']);
    expect(parts[1]['fen'], a.line.fens.last,
        reason: 'the new line starts where the first part stops');
    expect(b.line.rootSquares.single.toString(), 'Rc6');

    final c = read(parts[2]);
    expect(c.replays, isTrue);
    expect(parts[2]['fen'], a.line.fens.last);
    expect(c.line.movesSan, ['Ra6', 'Bb2', 'c3', 'Kb5']);
    expect(c.line.comments, [
      'The knight is pinned.',
      'The bishop hits a1.',
      'The pawn closes the diagonal.',
      'And the rook is attacked.',
    ]);
    expect(c.line.arrows[0].single.toString(), contains('a6c6'));
    expect(c.line.squares[3].single.toString(), 'Ra6');
  });

  testWidgets('one undo puts the part back as it was', (tester) async {
    final saves = await open(tester, lesson([example]));

    await tap(tester, find.byKey(const Key('beat-2')));
    await tap(tester, insert);
    await tap(tester, find.byKey(const Key('tutorial-undo')));

    final parts = await save(tester, saves);
    expect(parts.map((p) => p['id']), ['orig']);
    expect(read(parts.single).line.movesSan, hasLength(6));
  });

  testWidgets('the new line starts with the drawing tool off', (tester) async {
    // The rule of 7.9.2026: a trainer who has arrived on a new beat must not
    // find the toolbar still lit, or their first click on the board draws
    // instead of playing the line they came to play.
    await open(tester, lesson([example]));
    await tap(tester, find.byKey(const Key('beat-2')));
    await tap(tester, find.byKey(const Key('annotate-arrow')));
    ChessBoardWithOverlay board() => tester.widget<ChessBoardWithOverlay>(
        find.byType(ChessBoardWithOverlay).first);
    expect(board().isDrawingMode, isTrue, reason: 'the premise');

    await tap(tester, insert);

    expect(board().isDrawingMode, isFalse);
  });

  testWidgets('the button is on the beat the trainer stands on, and only there',
      (tester) async {
    await open(tester, lesson([example]));

    await tap(tester, find.byKey(const Key('beat-2')));
    expect(insert, findsOneWidget);
    expect(
        find.descendant(of: find.byKey(const Key('beat-2')), matching: insert),
        findsOneWidget);
  });

  testWidgets(
      'a question placed at a part\'s starting position leaves the id on '
      'the original line', (tester) async {
    // The sibling cut, „Find the move", on the same part: standing on the
    // starting position there is no demonstration in front, and the part
    // carrying the whole line is still the step a child's progress names.
    final saves = await open(tester, lesson([example]));

    await tap(tester, find.byKey(const Key('ask-move')));
    final parts = await save(tester, saves);

    expect(parts.map((p) => p['kind']), ['ask_move', 'show']);
    expect(parts.map((p) => p['id']), [null, 'orig'],
        reason: 'the server mints a new id for a part sent without one');
    expect(parts[1]['title'], 'Ra1');
    expect(read(parts[1]).line.movesSan, hasLength(6));
  });

  testWidgets('a part with no line to cut draws no button', (tester) async {
    await open(
      tester,
      lesson([
        {'id': 'still', 'fen': _fen, 'title': 'Look at a1', 'kind': 'show'},
        {'id': 'ask', 'fen': _fen, 'title': 'Your move', 'kind': 'ask_move'},
      ]),
    );
    expect(insert, findsNothing, reason: 'a still position');

    await tap(tester, find.text('Your move'));
    expect(insert, findsNothing, reason: 'a question carries no line');
  });
}
