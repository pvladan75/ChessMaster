/// Parts moving between tutorials — „spoji tutorijale / izdvoji delove".
///
/// Two operations and one rule: **they are copies**. A part that reached a
/// second tutorial still carrying its `stepId` is a child's progress showing up
/// in the wrong half of a tutorial, and the source keeping its parts is what
/// makes extraction a single write that cannot half-succeed. The owner chose
/// copying over moving on 20.9.2026 for exactly that reason.
///
/// Most of this runs with no widget tree at all, which is what
/// `TutorialDraftController` was separated out for.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_controller.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_parts_transfer.dart';
import 'package:chess_app/features/tutorial_studio/widgets/part_picker_dialog.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// A part that says something, so it has a name of its own to be found by.
TutorialSection _part(String says, {String? stepId}) {
  final root = AnalysisNode(fen: _startFen)..comment = says;
  return TutorialSection(root: root, stepId: stepId);
}

/// One `position_list` entry as the server stores it.
Map<String, dynamic> _step(String id, String says) => {
      'id': id,
      'fen': _startFen,
      'pgn': '{ $says }',
      'kind': 'show',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('addSectionsFrom', () {
    test('replaces the blank part of a tutorial that has not been started', () {
      final c = TutorialDraftController(draft: TutorialDraft());
      expect(c.draft.sections, hasLength(1), reason: 'the blank one');

      final added = c.addSectionsFrom([_part('first'), _part('second')]);

      expect(added, 2);
      expect(c.draft.sections, hasLength(2),
          reason: 'the blank part is replaced, not pushed in front');
      expect(c.draft.sections.first.root.comment, 'first');
      expect(c.draft.selected, 0);
    });

    test(
        'appends to a tutorial that has something in it, and stands on the '
        'first part that arrived', () {
      final c = TutorialDraftController(
        draft: TutorialDraft(title: 'Mine', sections: [_part('mine')]),
      );

      final added = c.addSectionsFrom([_part('theirs'), _part('theirs too')]);

      expect(added, 2);
      expect(
        [for (final s in c.draft.sections) s.root.comment],
        ['mine', 'theirs', 'theirs too'],
      );
      expect(c.draft.selected, 1, reason: 'the first part that arrived');
    });

    test('a named tutorial with nothing written in it is still replaced', () {
      // Found by the doors test, not by design: the first version asked
      // `isEmptyDraft`, which also wants an empty *title* because it answers a
      // different question — „is this stored draft worth resuming". A trainer
      // who names the tutorial before doing anything else is exactly the one
      // who would have been left with a stray blank „Part 1" in front of
      // everything they fetched.
      final c = TutorialDraftController(draft: TutorialDraft(title: 'Mine'));

      c.addSectionsFrom([_part('theirs')]);

      expect(c.draft.sections, hasLength(1));
      expect(c.draft.sections.single.root.comment, 'theirs');
      expect(c.draft.title, 'Mine', reason: 'the name is theirs');
    });

    test('a part the trainer named is kept, blank or not', () {
      // The other side of the same boundary: nothing is written in this part
      // either, but it has a name of its own, and a name is something meant.
      final mine = _part('')..title = 'The pawn ending';
      final c = TutorialDraftController(
        draft: TutorialDraft(title: 'Mine', sections: [mine]),
      );

      c.addSectionsFrom([_part('theirs')]);

      expect(c.draft.sections, hasLength(2));
      expect(c.draft.sections.first.title, 'The pawn ending');
    });

    test('the parts that arrive carry no step id', () {
      final c = TutorialDraftController(draft: TutorialDraft());
      c.addSectionsFrom([_part('borrowed', stepId: 'step_from_elsewhere')]);

      expect(c.draft.sections.single.stepId, isNull);
    });

    test('the source is not touched, and does not share a tree', () {
      final source = _part('theirs');
      final c = TutorialDraftController(
        draft: TutorialDraft(sections: [_part('mine')]),
      );
      c.addSectionsFrom([source]);

      c.draft.sections.last.root.comment = 'edited here';

      expect(source.root.comment, 'theirs',
          reason: 'editing the copy must not reach back into the tutorial it '
              'came from');
    });

    test('nothing offered is nothing done', () {
      final c = TutorialDraftController(draft: TutorialDraft());
      expect(c.addSectionsFrom([]), 0);
      expect(c.draft.sections, hasLength(1));
      expect(c.canUndo, isFalse);
    });

    test('it can be undone', () {
      final c = TutorialDraftController(
        draft: TutorialDraft(sections: [_part('mine')]),
      );
      c.addSectionsFrom([_part('theirs')]);
      expect(c.draft.sections, hasLength(2));

      c.undo();
      expect(c.draft.sections, hasLength(1));
      expect(c.draft.sections.single.root.comment, 'mine');
    });
  });

  group('copiesOf', () {
    TutorialDraftController threeParts() => TutorialDraftController(
          draft: TutorialDraft(sections: [
            _part('one', stepId: 'a'),
            _part('two', stepId: 'b'),
            _part('three', stepId: 'c'),
          ]),
        );

    test('answers in the tutorial order, not the order they were ticked', () {
      final copies = threeParts().copiesOf([2, 0]);
      expect([for (final s in copies) s.root.comment], ['one', 'three']);
    });

    test('an index twice is one part', () {
      expect(threeParts().copiesOf([1, 1]), hasLength(1));
    });

    test('copies, with no step id and no shared tree', () {
      final c = threeParts();
      final copies = c.copiesOf([0]);

      expect(copies.single.stepId, isNull);
      copies.single.root.comment = 'edited';
      expect(c.draft.sections.first.root.comment, 'one');
    });

    test('changes nothing in the tutorial it read', () {
      final c = threeParts();
      c.copiesOf([0, 1, 2]);
      expect(c.draft.sections, hasLength(3));
      expect(c.canUndo, isFalse, reason: 'reading is not an edit');
    });
  });

  group('loadPartsOf', () {
    test('reads a saved tutorial into parts', () async {
      final api = LessonApiService(
        authToken: 't',
        client: MockClient((req) async => http.Response(
            jsonEncode({
              'id': 7,
              'title': 'Endings',
              'tags': ['rook'],
              'language': 'en',
              'position_list': [_step('s1', 'first'), _step('s2', 'second')],
            }),
            200)),
      );

      final source = await loadPartsOf(api, 7);

      expect(source, isNotNull);
      expect(source!.title, 'Endings');
      expect(source.parts, hasLength(2));
      expect(source.tags, ['rook']);
      expect(source.language, 'en');
    });

    test('a tutorial that cannot be read is null, never an empty list',
        () async {
      final api = LessonApiService(
        authToken: 't',
        client: MockClient((req) async => http.Response('{}', 500)),
      );
      // The difference matters on screen: "could not be read" sends the trainer
      // back to try again, "no parts" tells them their tutorial is empty.
      expect(await loadPartsOf(api, 7), isNull);
    });
  });

  group('extractToNewTutorial', () {
    late List<Map<String, dynamic>> written;

    LessonApiService api({int status = 201}) {
      written = [];
      return LessonApiService(
        authToken: 't',
        client: MockClient((req) async {
          if (req.method == 'POST' && req.url.path.endsWith('/lessons/save')) {
            written.add(jsonDecode(req.body) as Map<String, dynamic>);
            if (status != 201) {
              return http.Response(
                  jsonEncode({'error': 'The solution cannot be played.'}),
                  status);
            }
            return http.Response(
                jsonEncode({
                  'id': 99,
                  'lesson': {'id': 99},
                }),
                201);
          }
          return http.Response('{}', 200);
        }),
      );
    }

    PartsSource source() => (
          lessonId: 7,
          title: 'Endings',
          parts: const <TutorialSection>[],
          language: 'en',
          languageKnown: true,
          tags: ['rook', 'endgame'],
        );

    test('writes exactly the parts it was given, in order', () async {
      final service = api();
      final outcome = await extractToNewTutorial(
        api: service,
        title: 'Rook endings',
        parts: [_part('first'), _part('second')],
        from: source(),
      );

      expect(outcome.error, isNull);
      expect(outcome.lessonId, 99);
      expect(written, hasLength(1));
      expect(written.single['title'], 'Rook endings');
      expect(written.single['positionList'], hasLength(2));
    });

    test(
        'the new tutorial inherits the language and the labels, not the '
        'description', () async {
      final service = api();
      await extractToNewTutorial(
        api: service,
        title: 'Rook endings',
        parts: [_part('first')],
        from: source(),
      );

      final body = written.single;
      expect(body['language'], 'en');
      expect(body['tags'], containsAll(<String>['rook', 'endgame']));
      // A description describes the tutorial the parts left, not this one.
      expect(body['description'], anyOf(isNull, ''));
    });

    test('no name is refused before anything is sent', () async {
      final service = api();
      final outcome = await extractToNewTutorial(
        api: service,
        title: '   ',
        parts: [_part('first')],
      );

      expect(outcome.lessonId, isNull);
      expect(outcome.error, contains('name'));
      expect(written, isEmpty, reason: 'nothing may reach the server');
    });

    test('no parts is refused before anything is sent', () async {
      final service = api();
      final outcome = await extractToNewTutorial(
        api: service,
        title: 'Rook endings',
        parts: const [],
      );

      expect(outcome.error, isNotNull);
      expect(written, isEmpty);
    });

    test("a refusal comes back in the server's own words", () async {
      final service = api(status: 400);
      final outcome = await extractToNewTutorial(
        api: service,
        title: 'Rook endings',
        parts: [_part('first')],
      );

      expect(outcome.lessonId, isNull);
      expect(outcome.error, contains('cannot be played'),
          reason: 'a sentence a trainer can act on, not one we invented');
    });

    test('what is written carries no step id from where it came from',
        () async {
      final service = api();
      await extractToNewTutorial(
        api: service,
        title: 'Rook endings',
        parts: [_part('first', stepId: 'step_from_elsewhere')],
      );

      final sent = (written.single['positionList'] as List).single as Map;
      expect(sent['id'], isNot('step_from_elsewhere'));
    });
  });

  group('the part picker', () {
    Future<PartChoice?> open(
      WidgetTester tester, {
      String? nameLabel,
      String initialName = '',
    }) async {
      PartChoice? answer;
      var closed = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                answer = await showPartPickerDialog(
                  context,
                  title: 'Parts',
                  labels: const ['one', 'two', 'three'],
                  confirmLabel: 'Add',
                  nameLabel: nameLabel,
                  initialName: initialName,
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      addTearDown(() => expect(closed, anyOf(isTrue, isFalse)));
      return answer;
    }

    testWidgets('everything is ticked on the way in', (tester) async {
      await open(tester);
      expect(find.text('3 parts chosen'), findsOneWidget);
    });

    testWidgets('unticking two leaves one, in tutorial order', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('part-picker-0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('part-picker-2')));
      await tester.pumpAndSettle();

      expect(find.text('1 part chosen'), findsOneWidget);
    });

    testWidgets('nothing ticked puts the button out of reach', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('part-picker-all')));
      await tester.pumpAndSettle();

      expect(find.text('0 parts chosen'), findsOneWidget);
      final button = tester
          .widget<ElevatedButton>(find.byKey(const Key('part-picker-confirm')));
      expect(button.onPressed, isNull);
    });

    testWidgets('a new tutorial with no name cannot be created',
        (tester) async {
      await open(tester, nameLabel: 'Name');
      final button = tester
          .widget<ElevatedButton>(find.byKey(const Key('part-picker-confirm')));
      expect(button.onPressed, isNull,
          reason: 'the server refuses a nameless tutorial; say so before the '
              'work, not after it');

      await tester.enterText(
          find.byKey(const Key('part-picker-name')), 'Named');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ElevatedButton>(
                find.byKey(const Key('part-picker-confirm')))
            .onPressed,
        isNotNull,
      );
    });
  });
}
