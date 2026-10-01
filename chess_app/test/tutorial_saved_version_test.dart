// The saved version of a tutorial — phase 2 of docs/PLAN-STUDIO-ISTORIJA.md.
//
// Reported 11.9.2026: a part deleted and never saved was still deleted when
// the tutorial was opened again. The studio adopted the draft this device kept
// of it without a word, and nothing led back to what the server held. These
// tests open the studio against a fake server that serves a saved version, and
// read the **request** the next save sends: a question that looks right and a
// save that sends the device's parts anyway is the fault this phase exists for.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
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
import 'package:chess_app/services/account_local_state.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _question = 'This tutorial has changes you have not saved';

/// A server holding one tutorial. `GET /lessons/:id` answers [row], or fails
/// when it is null; a save keeps the step ids it is sent and mints the rest,
/// as `services/lessonSteps.js` does. Either answer can be held back.
class _Backend {
  Map<String, dynamic>? row;
  Completer<void>? holdFetch;
  Completer<void>? holdSave;
  final saves = <Map<String, dynamic>>[];
  final methods = <String>[];
  var _minted = 0;

  late final LessonApiService api =
      LessonApiService(authToken: 'tok', client: MockClient(_answer));

  Future<http.Response> _answer(http.Request req) async {
    if (req.method == 'GET' &&
        RegExp(r'/lessons/\d+$').hasMatch(req.url.path)) {
      await holdFetch?.future;
      final r = row;
      return r == null
          ? http.Response('{"error":"down"}', 500)
          : http.Response(jsonEncode(r), 200);
    }
    final body = req.body.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(req.body) as Map);
    if (!body.containsKey('positionList')) return http.Response('{}', 200);
    await holdSave?.future;
    saves.add(body);
    methods.add(req.method);
    final stored = [
      for (final step in body['positionList'] as List)
        {
          ...Map<String, dynamic>.from(step as Map),
          'id': step['id'] ?? 'minted${_minted++}',
        },
    ];
    return http.Response(
      jsonEncode({'id': row?['id'] ?? 77, 'position_list': stored}),
      req.method == 'POST' ? 201 : 200,
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
  var nextLessonId = 700;

  Map<String, dynamic> saved({String title = 'Opozicija'}) => {
        'id': nextLessonId++,
        'title': title,
        'language': 'de',
        'position_list': [
          {'id': 'aaa', 'fen': _start, 'title': 'Uvod', 'kind': 'show'},
          {
            'id': 'bbb',
            'fen': _start,
            'title': 'Nastavak',
            'kind': 'show',
            'pgn': '1. e4 e5',
          },
        ],
      };

  /// What this device keeps of [row] — read the way the studio reads it, so
  /// only what a test changes afterwards differs from the server.
  Future<TutorialDraft> keep(Map<String, dynamic> row,
      [void Function(TutorialDraft)? change]) async {
    final draft = TutorialDraft.fromLesson(row);
    change?.call(draft);
    await TutorialDraftService.instance
        .flush(draft, epoch: AccountLocalState.epoch);
    return draft;
  }

  Future<void> open(
      WidgetTester tester, _Backend backend, Map<String, dynamic> listRow,
      {Size size = const Size(1600, 1200)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.saved(listRow),
        lessonApi: backend.api,
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// A tutorial the server has never seen.
  Future<void> openBlank(WidgetTester tester, _Backend backend) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: const TutorialEntry.blank('Opozicija'),
        lessonApi: backend.api,
      ),
    ));
    await tester.pumpAndSettle();
  }

  final discard = find.byKey(const Key('discard-changes'));
  final undo = find.byKey(const Key('tutorial-undo'));
  final saveButton = find.widgetWithText(FilledButton, 'Save tutorial');

  bool enabled(WidgetTester tester, Finder button) =>
      tester.widget<IconButton>(button).onPressed != null;

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(saveButton).onPressed != null;

  /// A change that touches no part: the title. For a case that has to save
  /// right after the draft became the saved version again, when „Save
  /// tutorial" has nothing to send and is greyed.
  Future<void> retitle(WidgetTester tester, String title) async {
    await tester.enterText(find.byKey(const Key('tutorial-title')), title);
    await tester.pumpAndSettle();
  }

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

  Future<Map<String, dynamic>> save(
      WidgetTester tester, _Backend backend) async {
    // A greyed button taps silently, and `saves.last` would then throw on an
    // empty list or read the previous save. Said here instead.
    expect(saveEnabled(tester), isTrue, reason: 'nothing to save');
    final before = backend.saves.length;
    await tap(tester, saveButton);
    expect(backend.saves, hasLength(before + 1));
    return backend.saves.last;
  }

  List<Object?> idsOf(Map<String, dynamic> body) =>
      [for (final p in body['positionList'] as List) (p as Map)['id']];

  String pgnOf(Map<String, dynamic> body, int part) =>
      ((body['positionList'] as List)[part] as Map)['pgn']?.toString() ?? '';

  testWidgets('a part deleted and never saved is asked about, not adopted',
      (tester) async {
    // The owner's report. The saved version is the one with both parts.
    final row = saved();
    await keep(row, (d) => d.removeSection(1));
    final backend = _Backend()..row = row;

    await open(tester, backend, row);

    expect(find.text(_question), findsOneWidget);
    await tap(tester, find.text('Open the saved version'));

    // Until [151.6] this saved straight away. The saved version on screen has
    // nothing to send now, so a title that touches no part is changed first.
    expect(saveEnabled(tester), isFalse);
    await retitle(tester, 'Opozicija 2');
    expect(idsOf(await save(tester, backend)), ['aaa', 'bbb'],
        reason: 'the saved version is what goes out, ids and all');
  });

  testWidgets('continuing keeps the changes, and they can still be discarded',
      (tester) async {
    final row = saved();
    await keep(row, (d) => d.removeSection(1));
    final backend = _Backend()..row = row;
    await open(tester, backend, row);

    await tap(tester, find.text('Continue with my changes'));
    expect(enabled(tester, discard), isTrue);
    expect(idsOf(await save(tester, backend)), ['aaa']);
  });

  testWidgets('opening the saved version is one undo from the changes',
      (tester) async {
    final row = saved();
    await keep(row, (d) => d.removeSection(1));
    final backend = _Backend()..row = row;
    await open(tester, backend, row);

    await tap(tester, find.text('Open the saved version'));
    await tap(tester, undo);

    expect(idsOf(await save(tester, backend)), ['aaa'],
        reason: 'the question promised the changes were not lost');
  });

  testWidgets(
      'a kept draft that differs only in where the trainer stood is not a '
      'change', (tester) async {
    final row = saved();
    await keep(row, (d) {
      d.selected = 1;
      d.section.cursorNode = d.section.root.children.first;
    });
    final backend = _Backend()..row = row;

    await open(tester, backend, row);

    expect(find.text(_question), findsNothing);
    expect(enabled(tester, discard), isFalse);
  });

  testWidgets('a kept draft from before the language field is not a change',
      (tester) async {
    // Kept on 10.9.2026 and never saved since: it does not know its language,
    // and saving it would leave the server's as it is.
    final row = saved();
    final older = Map<String, dynamic>.from(row)..remove('language');
    await keep(older);
    final backend = _Backend()..row = row;

    await open(tester, backend, row);

    expect(find.text(_question), findsNothing);
    expect(enabled(tester, discard), isFalse);
    expect(enabled(tester, undo), isFalse,
        reason: 'taking on the server\'s language is not a step to undo');
  });

  testWidgets('a server that cannot be asked opens the changes, and says so',
      (tester) async {
    final row = saved();
    await keep(row, (d) => d.removeSection(1));
    final backend = _Backend(); // no saved version to be had

    await open(tester, backend, row);

    expect(find.text(_question), findsNothing);
    expect(find.textContaining('Could not reach the server'), findsOneWidget);
    await play(tester, 'e2', 'e4');
    expect(enabled(tester, discard), isFalse,
        reason: 'no version nobody could read is offered to go back to');
    expect(idsOf(await save(tester, backend)), ['aaa']);
  });

  testWidgets('changes made before the server answers are not swapped out',
      (tester) async {
    final row = saved();
    await keep(row, (d) => d.removeSection(1));
    final backend = _Backend()
      ..row = row
      ..holdFetch = Completer<void>();
    await open(tester, backend, row);

    await play(tester, 'e2', 'e4');
    backend.holdFetch!.complete();
    await tester.pumpAndSettle();

    expect(find.text(_question), findsNothing,
        reason: 'a question about a draft the trainer is already writing');
    expect(enabled(tester, discard), isTrue);
    final body = await save(tester, backend);
    expect(idsOf(body), ['aaa']);
    expect(pgnOf(body, 0), contains('e4'));
  });

  testWidgets('a list row older than the last save opens as the saved version',
      (tester) async {
    // Saved elsewhere after the library list was read: the row the studio
    // was opened with is not what the server holds.
    final row = saved(title: 'Opozicija, revised');
    final listRow = Map<String, dynamic>.from(row)
      ..['title'] = 'Opozicija'
      ..['position_list'] = [(row['position_list'] as List).first];
    final backend = _Backend()..row = row;

    await open(tester, backend, listRow);

    expect(find.text(_question), findsNothing,
        reason: 'nothing of the trainer\'s was on screen to ask about');
    expect(enabled(tester, undo), isFalse);
    // Until [151.6] this saved straight away; the server's version on screen
    // has nothing to send now. A move in the first part leaves the title and
    // the ids this case reads.
    expect(saveEnabled(tester), isFalse);
    await play(tester, 'e2', 'e4');
    final body = await save(tester, backend);
    expect(body['title'], 'Opozicija, revised');
    expect(idsOf(body), ['aaa', 'bbb']);
  });

  testWidgets('discarding puts the saved version back, and undo takes it away',
      (tester) async {
    final row = saved();
    final backend = _Backend()..row = row;
    await open(tester, backend, row);
    expect(enabled(tester, discard), isFalse, reason: 'nothing to discard');

    await play(tester, 'e2', 'e4');
    expect(enabled(tester, discard), isTrue);

    await tap(tester, discard);
    expect(enabled(tester, discard), isFalse);
    // Until [151.6] a save here sent the part without e4. The saved version
    // has nothing to send now, which is the same fact read off the button.
    expect(saveEnabled(tester), isFalse,
        reason: 'the saved version is back: nothing to send');

    await tap(tester, undo);
    expect(enabled(tester, discard), isTrue,
        reason: 'the change is back, and so is the way to discard it');
    expect(pgnOf(await save(tester, backend), 0), contains('e4'));
  });

  testWidgets('discarding after the first save keeps the one tutorial',
      (tester) async {
    // What the first save sent had no lesson id and no step ids yet. Put back
    // as it was, the next save would make a second tutorial.
    final backend = _Backend();
    await openBlank(tester, backend);

    await play(tester, 'e2', 'e4');
    await save(tester, backend);
    await play(tester, 'e7', 'e5');
    await tap(tester, discard);
    // Until [151.6] this saved straight after the discard, which has nothing
    // to send now; a title touches no part and no id.
    await retitle(tester, 'Opozicija 2');
    final body = await save(tester, backend);

    expect(backend.methods, ['POST', 'PUT'],
        reason: 'the same tutorial, not a second one');
    expect(idsOf(body), ['minted0'],
        reason: 'the part keeps the id its first save gave it');
    expect(pgnOf(body, 0), isNot(contains('e5')));
  });

  testWidgets('taking on the server\'s language is not undone with a change',
      (tester) async {
    final row = saved();
    await keep(Map<String, dynamic>.from(row)..remove('language'));
    final backend = _Backend()..row = row;
    await open(tester, backend, row);

    await play(tester, 'e2', 'e4');
    await tap(tester, undo);

    // Until [151.6] this saved straight after the undo, which is back to the
    // saved version and has nothing to send now; the title is not the language.
    await retitle(tester, 'Opozicija 2');
    expect((await save(tester, backend))['language'], 'de');
  });

  testWidgets('after a save, discarding goes back to that save',
      (tester) async {
    final row = saved();
    final backend = _Backend()..row = row;
    await open(tester, backend, row);

    await play(tester, 'e2', 'e4');
    await save(tester, backend);
    expect(enabled(tester, discard), isFalse);

    await play(tester, 'e7', 'e5');
    await tap(tester, discard);

    // Until [151.6] this saved straight after the discard, which has nothing
    // to send now; a title touches no part.
    await retitle(tester, 'Opozicija 2');
    final pgn = pgnOf(await save(tester, backend), 0);
    expect(pgn, contains('e4'));
    expect(pgn, isNot(contains('e5')));
  });

  testWidgets('what is typed while a save is out is not counted as saved',
      (tester) async {
    final row = saved();
    final backend = _Backend()
      ..row = row
      ..holdSave = Completer<void>();
    await open(tester, backend, row);

    await play(tester, 'e2', 'e4');
    await tester.tap(find.text('Save tutorial'));
    await tester.pump();
    await tester.enterText(
        find.byKey(const Key('tutorial-title')), 'Opozicija 2');
    backend.holdSave!.complete();
    await tester.pumpAndSettle();

    expect(enabled(tester, discard), isTrue,
        reason: 'the new title never reached the server');
  });

  // „Save tutorial" is greyed when pressing it would send nothing new — the
  // owner's report of 11.9.2026, [151.6] in docs/TODO-provera.md: it never
  // was, not even right after a save. „Nothing new" is the rule „Discard
  // changes" already stands on, so the two cannot disagree about whether the
  // draft is the saved version.
  group('Save tutorial is greyed', () {
    testWidgets('while what is on screen is the saved version', (tester) async {
      final row = saved();
      final backend = _Backend()..row = row;
      await open(tester, backend, row);
      expect(saveEnabled(tester), isFalse, reason: 'opened as it was saved');

      await play(tester, 'e2', 'e4');
      expect(saveEnabled(tester), isTrue);

      await save(tester, backend);
      expect(saveEnabled(tester), isFalse,
          reason: 'the owner\'s report: still pressable right after a save');

      await play(tester, 'e7', 'e5');
      expect(saveEnabled(tester), isTrue);
      await tap(tester, discard);
      expect(saveEnabled(tester), isFalse,
          reason: 'discarding is back to the save');
    });

    testWidgets('never for a tutorial the server has not got', (tester) async {
      await openBlank(tester, _Backend());
      expect(saveEnabled(tester), isTrue,
          reason: 'there is no saved version for it to be');
    });

    testWidgets('never when the saved version could not be read',
        (tester) async {
      final row = saved();
      await open(tester, _Backend(), row); // the fetch fails
      expect(saveEnabled(tester), isTrue,
          reason: 'a version nobody could read is not one the draft is known '
              'to equal');
    });

    testWidgets(
        'while a save is on its way, so a second tap is not a second '
        'tutorial', (tester) async {
      // The first save of a new tutorial has no lesson id to edit, so a tap
      // before its answer arrives was a second POST: two tutorials.
      final backend = _Backend()..holdSave = Completer<void>();
      await openBlank(tester, backend);
      await play(tester, 'e2', 'e4');

      await tester.tap(saveButton);
      await tester.pump();
      final pressableWhileOut = saveEnabled(tester);
      await tester.tap(saveButton);
      await tester.pump();
      backend.holdSave!.complete();
      await tester.pumpAndSettle();

      expect(backend.methods, ['POST'], reason: 'one tutorial, not two');
      expect(pressableWhileOut, isFalse, reason: 'a save is on its way');
      expect(saveEnabled(tester), isFalse, reason: 'and nothing left to save');
    });

    testWidgets('on the phone too', (tester) async {
      final row = saved();
      final backend = _Backend()..row = row;
      await open(tester, backend, row, size: const Size(360, 640));
      final phoneSave = find.byKey(const Key('phone-save'));
      expect(enabled(tester, phoneSave), isFalse);

      await play(tester, 'e2', 'e4');
      expect(enabled(tester, phoneSave), isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('fetchTutorial', () {
    Future<Map<String, dynamic>?> fetch(int id, http.Response answer) =>
        LessonApiService(
          authToken: 'tok',
          client: MockClient((_) async => answer),
        ).fetchTutorial(id);

    test('takes the tutorial that was asked for', () async {
      final row = await fetch(
          5, http.Response(jsonEncode({'id': 5, 'position_list': []}), 200));
      expect(row?['id'], 5);
    });

    test('takes nothing that is not that tutorial with its steps', () async {
      for (final answer in [
        http.Response(jsonEncode({'id': 6, 'position_list': []}), 200),
        http.Response(jsonEncode({'id': 5, 'position_list': null}), 200),
        http.Response(jsonEncode([]), 200),
        http.Response('not json', 200),
        http.Response(jsonEncode({'error': 'Tutorial not found.'}), 404),
      ]) {
        expect(await fetch(5, answer), isNull, reason: answer.body);
      }
    });
  });
}
