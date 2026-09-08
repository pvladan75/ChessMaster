// The gate for batch F — add, remove and reorder in `LessonStepEditorPanel`.
// Phase 4c of docs/PLAN-TUTORIJAL.md.
//
// Written before the batch, and kept in `docs/gates/` until it lands: a gate
// naming controls nobody has built does not compile, and a suite that does not
// compile says nothing about anything else. It moves to
// `chess_app/test/lesson_step_order_test.dart` in the merge commit, the way the
// vocabulary, branching and authoring gates were moved.
//
// It asserts on the **request body**, not on the list on screen. Every one of
// the three operations is a rearrangement of identity, and identity is not
// something a screen can show you.
//
// ---------------------------------------------------------------------------
// WHY THIS BATCH IS DANGEROUS, AND WHAT THE SERVER WILL NOT CATCH
//
// A step's `id` is its identity. `assignment_items.step_key` and
// `review_items.step_key` name steps by that value and **nothing joins on it**,
// so an id that changes is a child's schedule and a child's recorded answers
// quietly pointing at nothing. `buildLessonStep` says this in as many words:
// „an id quietly regenerated is a student's schedule quietly orphaned, with no
// error anywhere."
//
// `PUT /lessons/:id` has a guard against exactly that — the 409 „Koraci su
// stigli bez svojih oznaka" — **and it cannot fire for this batch.** Read it in
// `chess_backend/routes/lessons.js`: it requires
// `storedList.length === steps.length`. Adding a step or removing one changes
// the length, so the guard is skipped and the write goes through whatever the
// ids look like. For add and remove, this file is the only thing standing
// between a trainer and an orphaned history.
//
// Three rules follow, and each has a test here:
//
//   * **reorder changes order and nothing else** — the same ids, the same
//     count, every other field byte-identical, in the new sequence;
//   * **a new step is sent with no `id` at all**, so the server mints one.
//     Never a copy of the id of the step it was added beside:
//     `assignment_items` has a UNIQUE index on `(assignment_id, step_key)`, so
//     two steps sharing an id is not a cosmetic fault;
//   * **removing a step drops exactly that id** and leaves every other one
//     alone.
//
// The child's side survives a removal already, and was checked rather than
// assumed: `getDue` in `spacedRepetitionService.js` resolves a review row
// through `stepByKey` and ends with `.filter((item) => item.step !== null)`, so
// a row naming a step that no longer exists simply stops appearing. **No
// backend work is needed for this batch, and none is allowed.**
//
// ---------------------------------------------------------------------------
// THE FROZEN CONTRACT FOR BATCH F
//
//   Key('step-title')          the step's name          „Naziv koraka"
//   „Dodaj korak"              inserts after the selected step, which becomes
//                              the selected one; same position, empty of
//                              everything else, kind `show`
//   „Obriši korak"             asks first, then removes the selected step
//   Tooltip „Pomeri gore"      moves the selected step one place earlier
//   Tooltip „Pomeri dole"      one place later; both disabled at the ends
//
// **Up and down rather than drag.** `ReorderableListView` is the prettier
// answer and a trainer with twelve steps would want it; it is also the answer
// whose gesture is hard to drive and easy to get subtly wrong. This batch is
// meant to be mechanical. Drag is a later, separate decision.
//
// **A title field, because without it the batch is not usable.** The panel
// edits the instruction, the kind, the choices and the answer, and not the
// name — so three added steps would all arrive at the server as „Pozicija",
// which is what `buildLessonStep` writes when a title is missing, and the
// trainer could not tell them apart in the very list this batch is about.
//
// **Nothing is saved until „Sačuvaj korak".** All three operations change the
// list in memory, like every other edit in this panel.
//
// **The last step cannot be removed.** `PUT` writes `position_list = NULL` for
// an empty list — see the `steps.length > 0 ? … : null` in the route — so a
// tutorial emptied here is a tutorial whose steps are gone with nothing to
// join on and complain. A one-step tutorial refuses, in a sentence.
//
// **Not asserted here** because they are already asserted elsewhere, and both
// files must stay green unchanged: `test/lesson_editor_test.dart` (the server
// is the only authority on what a step may be; the preview does not judge) and
// `test/lesson_answer_stays_hidden_test.dart` (a question does not carry the
// line that answers it). If a test in either has to be edited for this batch to
// pass, that is a finding, not a chore.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/lessons/widgets/lesson_step_editor_panel.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    return AppSettingsService.instance.init();
  });

  const fenA = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';
  const fenB = '4k3/8/8/8/8/8/4P3/4K3 w - - 0 1';
  const fenC = '8/8/8/3k4/8/8/3PK3/8 w - - 0 1';

  final session = UserSession(
    token: 't',
    id: 1,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  /// Three steps, each with the id the server gave it.
  Map<String, dynamic> lesson() => {
        'id': 7,
        'title': 'Završnice',
        'position_list': [
          {
            'id': 'aaaa1111',
            'fen': fenA,
            'title': 'Prvi',
            'instruction': 'Nađi mat u jednom potezu.',
            'kind': 'ask_move',
            'solutionSan': 'Ra8#',
          },
          {'id': 'bbbb2222', 'fen': fenB, 'title': 'Drugi'},
          {'id': 'cccc3333', 'fen': fenC, 'title': 'Treći'},
        ],
      };

  Map<String, dynamic> oneStepLesson() => {
        'id': 7,
        'title': 'Završnice',
        'position_list': [
          {'id': 'aaaa1111', 'fen': fenA, 'title': 'Jedini'},
        ],
      };

  Future<_FakeApi> openEditor(WidgetTester tester,
      {Map<String, dynamic>? withLesson}) async {
    // A desktop panel: a 300 px board and a column of fields, and the default
    // 800x600 surface leaves „Sačuvaj korak" off the bottom.
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _FakeApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LessonStepEditorPanel(
          session: session,
          api: api,
          lesson: withLesson ?? lesson(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return api;
  }

  /// Picks a step by its name **in the list**, not anywhere the name appears.
  ///
  /// Scoped to the `ListTile` on purpose: this batch also gives the panel a
  /// title field, so once a step is selected its name is on screen twice and a
  /// bare `find.text` matches both. The first version of this helper did not
  /// scope, and batch 55 worked around it by appending a zero-width space to
  /// the title in the text field — shipping an invisible character into a field
  /// a trainer edits, to keep a finder unique. The gate was wrong, not the
  /// panel.
  Future<void> select(WidgetTester tester, String title) async {
    await tester.tap(find.descendant(
      of: find.byType(ListTile),
      matching: find.text(title),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> tapTooltip(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save step'));
    await tester.pumpAndSettle();
  }

  List<String?> idsOf(List<Map<String, dynamic>> steps) =>
      [for (final s in steps) s['id'] as String?];

  group('reorder moves a step and changes nothing else', () {
    testWidgets('the ids travel with their steps, in the new order',
        (tester) async {
      final api = await openEditor(tester);

      await select(tester, 'Treći');
      await tapTooltip(tester, 'Move up');
      await save(tester);

      final sent = api.saved.single;
      expect(idsOf(sent), ['aaaa1111', 'cccc3333', 'bbbb2222'],
          reason: 'a step that changes place must keep its id: '
              'assignment_items and review_items name it by that value and '
              'nothing joins on it');
      expect(sent.map((s) => s['fen']).toList(), [fenA, fenC, fenB],
          reason: 'the order moved but the positions did not follow it');
    });

    testWidgets('everything else about the moved step is byte-identical',
        (tester) async {
      // The whole step travels, not just its id and its board. A reorder that
      // rebuilds the maps can drop the answer or the kind, and the trainer sees
      // a list in the right order with a question that no longer asks anything.
      final before = Map<String, dynamic>.from(
          (lesson()['position_list'] as List).first as Map);

      final api = await openEditor(tester);
      await select(tester, 'Prvi');
      await tapTooltip(tester, 'Move down');
      await save(tester);

      final moved = api.saved.single.firstWhere((s) => s['id'] == 'aaaa1111');
      expect(moved['kind'], before['kind']);
      expect(moved['solutionSan'], before['solutionSan']);
      expect(moved['instruction'], before['instruction']);
      expect(moved['title'], before['title']);
      expect(moved['fen'], before['fen']);
    });

    testWidgets('the selection follows the step, not the slot', (tester) async {
      // Otherwise the trainer moves „Treći" up and is now editing „Drugi",
      // with „Treći"'s sentence still in the field, one keystroke from writing
      // it onto the wrong step.
      await openEditor(tester);

      await select(tester, 'Treći');
      await tapTooltip(tester, 'Move up');

      // Asserted on the name in the editor, not on the absence of some other
      // step's sentence. The first version of this test only ruled out landing
      // on „Prvi", and a mutation that left the selection on the old slot —
      // where „Drugi" now sits, which has no sentence either — walked straight
      // through it. A guard nobody has watched fail is not a guard.
      expect(
          tester
              .widget<TextField>(find.byKey(const Key('step-title')))
              .controller
              ?.text,
          'Treći',
          reason: 'the editor is showing another step than the one that moved');
    });

    testWidgets('the ends do not offer a move that has nowhere to go',
        (tester) async {
      // Read off the button rather than off the tooltip: `find.byTooltip`
      // matches the `Tooltip` that wraps the button, and casting that to an
      // `IconButton` fails for a reason that has nothing to do with the batch.
      IconButton moveButton(String tooltip) => tester.widget<IconButton>(
            find.descendant(
              of: find.byTooltip(tooltip),
              matching: find.byType(IconButton),
            ),
          );

      await openEditor(tester);

      await select(tester, 'Prvi');
      expect(moveButton('Move up').onPressed, isNull);

      await select(tester, 'Treći');
      expect(moveButton('Move down').onPressed, isNull);
    });
  });

  group('a step that is added is a new step', () {
    testWidgets('it goes out with no id, so the server mints one',
        (tester) async {
      // The one this batch exists to get right, and the one the server cannot
      // catch: the 409 guard needs the stored and sent lists to be the same
      // length, and adding a step makes them differ.
      final api = await openEditor(tester);

      await select(tester, 'Prvi');
      await tapText(tester, 'Add step');
      await save(tester);

      final sent = api.saved.single;
      expect(sent, hasLength(4));
      expect(idsOf(sent).where((id) => id == null), hasLength(1),
          reason: 'a new step must carry no id at all — `buildLessonStep` '
              'generates one, and anything the client invents is either a '
              'collision or a refusal');
      expect(idsOf(sent).whereType<String>().toSet(),
          {'aaaa1111', 'bbbb2222', 'cccc3333'},
          reason: 'an existing id was changed or lost while adding');
    });

    testWidgets('it lands after the step it was added from, and is selected',
        (tester) async {
      final api = await openEditor(tester);

      await select(tester, 'Prvi');
      await tapText(tester, 'Add step');
      await tester.enterText(find.byKey(const Key('step-title')), 'Ubačeni');
      await tester.pumpAndSettle();
      await save(tester);

      final sent = api.saved.single;
      expect(sent[1]['id'], isNull, reason: 'the new step is not in slot 2');
      expect(sent[1]['title'], 'Ubačeni',
          reason: 'the editor was not showing the step that was just added, '
              'so the name went onto another one');
      expect(sent[1]['fen'], fenA,
          reason: 'a new step starts on the position you added it from — that '
              'is what makes „show, then ask" one board rather than two');
    });

    testWidgets('it is empty of everything it did not inherit', (tester) async {
      // Standing on an `ask_move` step with a solution, adding a step must not
      // carry that question across. The position is deliberate; the question is
      // not.
      final api = await openEditor(tester);

      await select(tester, 'Prvi');
      await tapText(tester, 'Add step');
      await save(tester);

      final added = api.saved.single[1];
      expect(added['kind'] == null || added['kind'] == 'show', isTrue);
      expect(added['solutionSan'], isNull,
          reason: 'the new step inherited the previous step\'s answer');
      expect(added['instruction'], isNull);
      expect(added['pgn'], isNull,
          reason: 'inheriting the line is how a question ends up carrying the '
              'move that answers it');
    });
  });

  group('a step that is removed takes only itself', () {
    testWidgets('it asks first', (tester) async {
      // Not undoable, and not local: a child may have answered this step.
      final api = await openEditor(tester);

      await select(tester, 'Drugi');
      await tapText(tester, 'Delete step');

      // Asserted inside the dialog: „Drugi" is on a list tile as well, so
      // `findsWidgets` on the whole screen would have passed with no dialog at
      // all.
      expect(find.byType(AlertDialog), findsOneWidget,
          reason: 'a step was deleted without asking');
      expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining('Drugi'),
          ),
          findsOneWidget,
          reason: 'the question has to name the step being deleted, or a '
              'trainer with twelve of them is guessing');
      expect(api.saved, isEmpty, reason: 'a delete wrote before it was asked');
    });

    testWidgets('saying no keeps it', (tester) async {
      final api = await openEditor(tester);

      await select(tester, 'Drugi');
      await tapText(tester, 'Delete step');
      await tapText(tester, 'Cancel');
      await save(tester);

      expect(idsOf(api.saved.single), ['aaaa1111', 'bbbb2222', 'cccc3333']);
    });

    testWidgets('saying yes drops exactly that id', (tester) async {
      final api = await openEditor(tester);

      await select(tester, 'Drugi');
      await tapText(tester, 'Delete step');
      await tapText(tester, 'Delete');
      await save(tester);

      expect(idsOf(api.saved.single), ['aaaa1111', 'cccc3333'],
          reason: 'removing one step disturbed the identity of another');
    });

    testWidgets('the last step is refused, and nothing is sent',
        (tester) async {
      // `PUT` writes `position_list = NULL` for an empty list, and a tutorial
      // whose steps are gone has nothing left to join on and complain.
      final api = await openEditor(tester, withLesson: oneStepLesson());

      await tapText(tester, 'Delete step');
      await tester.pumpAndSettle();

      // Refused outright rather than asked about: there is no answer to the
      // question that leaves the tutorial in one piece.
      expect(find.byType(AlertDialog), findsNothing,
          reason: 'it offered to do the one thing it must not do');
      await save(tester);
      expect(idsOf(api.saved.single), ['aaaa1111'],
          reason: 'the only step of the tutorial went out deleted, and `PUT` '
              'writes position_list = NULL for an empty list');
    });
  });

  group('nothing reaches the server until the trainer saves', () {
    testWidgets('add, move and delete are all still local', (tester) async {
      final api = await openEditor(tester);

      await select(tester, 'Prvi');
      await tapText(tester, 'Add step');
      await tapTooltip(tester, 'Move down');
      await select(tester, 'Treći');
      await tapText(tester, 'Delete step');
      await tapText(tester, 'Delete');

      expect(api.saved, isEmpty,
          reason: 'the panel wrote to the server on its own; every other edit '
              'here waits for „Sačuvaj korak" and these must too');
    });
  });
}

class _FakeApi extends LessonApiService {
  _FakeApi() : super(authToken: 't');

  /// Every `positionList` the editor sent, in order.
  ///
  /// Always answers success: every refusal this file asserts happens before a
  /// request goes out, so a failing server would only hide which of the two
  /// stopped it.
  final List<List<Map<String, dynamic>>> saved = [];

  @override
  Future<String?> update({
    required int id,
    required String title,
    String? description,
    List<String>? tags,
    String? fen,
    String? pgn,
    List<Map<String, dynamic>>? positionList,
  }) async {
    if (positionList != null) saved.add(positionList);
    return null;
  }
}
