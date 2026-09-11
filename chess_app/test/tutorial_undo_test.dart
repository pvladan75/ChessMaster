// Undo and redo in the studio — phase 1 of docs/PLAN-STUDIO-ISTORIJA.md.
//
// Reported 11.9.2026: a part deleted and not saved was still deleted when the
// tutorial was opened again, and nothing could bring it back. These tests
// drive the studio through its own controls and read the **request** a save
// sends afterwards, because an undo that looks right on screen and sends the
// old ids wrong is the one that would cost a student their progress.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// A server that keeps the step ids it is sent and mints one for a part that
/// arrives without, as `services/lessonSteps.js` does, and answers with the
/// stored list, as `POST /lessons/save` and `PUT /lessons/:id` do.
class _Server extends LessonApiService {
  _Server._(this.saves, http.Client client)
      : super(authToken: 'tok', client: client);

  final List<({String method, Map<String, dynamic> body})> saves;

  factory _Server() {
    final saves = <({String method, Map<String, dynamic> body})>[];
    var minted = 0;
    return _Server._(
      saves,
      MockClient((req) async {
        final body = req.body.isEmpty
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(jsonDecode(req.body) as Map);
        if (!body.containsKey('positionList')) {
          return http.Response('{}', 200);
        }
        saves.add((method: req.method, body: body));
        final stored = [
          for (final step in body['positionList'] as List)
            {
              ...Map<String, dynamic>.from(step as Map),
              'id': step['id'] ?? 'minted${minted++}',
            },
        ];
        return http.Response(
          jsonEncode({'id': 77, 'position_list': stored}),
          req.method == 'POST' ? 201 : 200,
        );
      }),
    );
  }
}

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
  var nextLessonId = 600;

  Map<String, dynamic> twoParts() => {
        'id': nextLessonId++,
        'title': 'Opozicija',
        'language': null,
        'position_list': [
          {'id': 'aaa', 'fen': _start, 'title': 'Uvod', 'kind': 'show'},
          {'id': 'bbb', 'fen': _start, 'title': 'Nastavak', 'kind': 'show'},
        ],
      };

  Future<_Server> open(WidgetTester tester, TutorialEntry entry) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    final server = _Server();
    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: entry,
        lessonApi: server,
      ),
    ));
    await tester.pumpAndSettle();
    return server;
  }

  final undoButton = find.byKey(const Key('tutorial-undo'));
  final redoButton = find.byKey(const Key('tutorial-redo'));

  bool enabled(WidgetTester tester, Finder button) =>
      tester.widget<IconButton>(button).onPressed != null;

  Future<void> tap(WidgetTester tester, Finder button) async {
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> play(WidgetTester tester, String from, String to) async {
    tester
        .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay).first)
        .onMove(from, to, '');
    await tester.pumpAndSettle();
  }

  Future<Map<String, dynamic>> save(WidgetTester tester, _Server server) async {
    await tester.tap(find.text('Save tutorial'));
    await tester.pumpAndSettle();
    return server.saves.last.body;
  }

  List<Map<String, dynamic>> partsOf(Map<String, dynamic> body) => [
        for (final p in body['positionList'] as List)
          Map<String, dynamic>.from(p as Map),
      ];

  testWidgets('nothing to undo when the studio opens, something after a change',
      (tester) async {
    await open(tester, TutorialEntry.saved(twoParts()));
    expect(enabled(tester, undoButton), isFalse);
    expect(enabled(tester, redoButton), isFalse);

    await play(tester, 'e2', 'e4');
    expect(enabled(tester, undoButton), isTrue);
    expect(enabled(tester, redoButton), isFalse);
  });

  testWidgets('a deleted part comes back, with its own step id',
      (tester) async {
    // The owner's report, reversed. The id is the half that matters: a part
    // back on screen under a new id is a student's progress cut off from it.
    final server = await open(tester, TutorialEntry.saved(twoParts()));

    await tester.tap(find.byTooltip('Delete part'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(partsOf(await save(tester, server)), hasLength(1));

    await tap(tester, undoButton);
    final parts = partsOf(await save(tester, server));

    expect(parts.map((p) => p['id']), ['aaa', 'bbb']);
  });

  testWidgets('a move is taken back and played again', (tester) async {
    final server = await open(tester, TutorialEntry.saved(twoParts()));

    await play(tester, 'e2', 'e4');
    await tap(tester, undoButton);
    expect(partsOf(await save(tester, server)).first['pgn'] ?? '',
        isNot(contains('e4')));

    await tap(tester, redoButton);
    expect(partsOf(await save(tester, server)).first['pgn'], contains('e4'));
  });

  testWidgets('a sentence typed without a pause is one undo', (tester) async {
    await open(tester, TutorialEntry.saved(twoParts()));
    final field = find.byKey(const Key('example-sentence'));

    // Letter by letter, the way a keyboard delivers it.
    for (final text in ['B', 'Be', 'Bel', 'Beli', 'Beli p', 'Beli počinje.']) {
      await tester.enterText(field, text);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    await tap(tester, undoButton);

    expect(tester.widget<TextField>(field).controller!.text, '',
        reason: 'one undo takes the whole sentence');
    expect(enabled(tester, undoButton), isFalse);
  });

  testWidgets('Ctrl+Z in a text field undoes the move played after it',
      (tester) async {
    // On Windows a field keeps its focus while a piece is dragged on the
    // board, so the move is played with the caret still in the title. The
    // field's own undo would take back letters and leave the move standing.
    final server = await open(tester, TutorialEntry.saved(twoParts()));
    await tester.tap(find.byKey(const Key('tutorial-title')));
    await tester.pump();
    await play(tester, 'e2', 'e4');
    expect(
        tester
            .widget<EditableText>(find.descendant(
                of: find.byKey(const Key('tutorial-title')),
                matching: find.byType(EditableText)))
            .focusNode
            .hasFocus,
        isTrue,
        reason: 'the premise: the caret is still in the field');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    final body = await save(tester, server);
    expect(partsOf(body).first['pgn'] ?? '', isNot(contains('e4')));
    expect(body['title'], 'Opozicija', reason: 'and the title is untouched');
  });

  testWidgets('walking the line and choosing a part are not changes',
      (tester) async {
    await open(tester, TutorialEntry.saved(twoParts()));

    await tester.tap(find.text('Nastavak'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uvod'));
    await tester.pumpAndSettle();

    expect(enabled(tester, undoButton), isFalse);
  });

  testWidgets('an undo past a save keeps the tutorial and its step ids',
      (tester) async {
    // A snapshot from before the first save has no lesson id and no step ids.
    // Restored as it was, the next save would make a second tutorial and mint
    // a new id for the part.
    final server = await open(tester, const TutorialEntry.blank('Opozicija'));

    await play(tester, 'e2', 'e4');
    final first = await save(tester, server);
    expect(server.saves.last.method, 'POST');
    expect(partsOf(first).single['id'], isNull);

    await tap(tester, undoButton);
    final second = await save(tester, server);

    expect(server.saves.last.method, 'PUT',
        reason: 'the same tutorial, not a second one');
    expect(partsOf(second).single['id'], 'minted0',
        reason: 'the part keeps the id its first save gave it');
  });

  testWidgets('an undo restores the part\'s own fields', (tester) async {
    // Every field of the open part is read back from the part on a restore.
    // A kind left at the screen's value would be written back over it.
    final server = await open(tester, TutorialEntry.saved(twoParts()));

    await tester.tap(find.byKey(const Key('example-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask for answer from list').last);
    await tester.pumpAndSettle();

    await tap(tester, undoButton);
    expect(partsOf(await save(tester, server)).first['kind'], 'show');
  });

  testWidgets('the task and an answer are each a step of their own',
      (tester) async {
    // Neither field used to record its change, so an edit to either was taken
    // back together with whatever the trainer did next.
    await open(
      tester,
      TutorialEntry.saved({
        'id': nextLessonId++,
        'title': 'Opozicija',
        'language': null,
        'position_list': [
          {
            'id': 'aaa',
            'fen': _start,
            'title': 'Pitanje',
            'kind': 'ask_choice',
            'instruction': 'What does White gain?',
            'choices': [
              {'text': 'The centre.', 'correct': true},
              {'text': 'A pawn.', 'correct': false},
            ],
          },
        ],
      }),
    );
    String text(String key) =>
        tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

    await tester.enterText(
        find.byKey(const Key('example-instruction')), 'What now?');
    await tester.enterText(find.byKey(const Key('example-choice-0')), 'Space.');
    await tester.enterText(find.byKey(const Key('tutorial-title')), 'Renamed');
    await tester.pumpAndSettle();

    await tap(tester, undoButton);
    expect(text('tutorial-title'), 'Opozicija');
    expect(text('example-choice-0'), 'Space.');
    expect(text('example-instruction'), 'What now?');

    await tap(tester, undoButton);
    expect(text('example-choice-0'), 'The centre.');
    expect(text('example-instruction'), 'What now?');

    await tap(tester, undoButton);
    expect(text('example-instruction'), 'What does White gain?');
  });

  testWidgets('a draft taken from this device is where undo stops',
      (tester) async {
    // The studio adopts the kept draft of the same tutorial a frame after it
    // opens. Undo must go back to that, not to the server's version it opened
    // with — which would be the owner's lost part again, by another road.
    final lesson = twoParts();
    final kept = TutorialDraft.fromLesson(lesson)
      ..title = 'Kept on this device';
    await TutorialDraftService.instance.flush(kept);

    final server = await open(tester, TutorialEntry.saved(lesson));
    expect(enabled(tester, undoButton), isFalse);

    await play(tester, 'e2', 'e4');
    await tap(tester, undoButton);

    expect((await save(tester, server))['title'], 'Kept on this device');
  });

  testWidgets('an undo is kept on this device', (tester) async {
    // Closing the window after an undo keeps what is on screen, not what was
    // undone.
    await open(tester, TutorialEntry.saved(twoParts()));

    await play(tester, 'e2', 'e4');
    await tap(tester, undoButton);
    await tester.pump(const Duration(seconds: 1));

    final kept = await TutorialDraftService.instance.load();
    expect(kept!.sections.first.root.children, isEmpty);
  });
}
