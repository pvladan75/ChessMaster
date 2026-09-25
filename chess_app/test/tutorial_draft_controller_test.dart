// The tutorial being written, with no widget tree at all — phase 6a of
// docs/PLAN-REORGANIZACIJA.md.
//
// `TutorialDraftController` is the class docs/PLAN-STUDIO-REDIZAJN.md §4 drew
// and the screen never got: the draft, the open part, the cursor, the
// history and the saved version, behind methods a layout calls. The plan's
// gate for the extraction is in two halves. The studio's 543 widget tests
// pass unedited, which says the desktop layout still does what it did; this
// file says the controller does it without a frame, which is what the seam
// was for and what the phone layout (6b) will stand on.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_controller.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';

const _start = TutorialDraft.startFen;
const _afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';

TutorialDraftController _blank({String title = ''}) => TutorialDraftController(
      draft: TutorialDraft(
        title: title,
        sections: [TutorialSection.blank(fen: _start, title: 'Part 1')],
      ),
    );

/// A server that accepts every save and hands back ids, remembering what
/// it was sent.
({LessonApiService api, List<Map<String, dynamic>> sent}) _server() {
  final sent = <Map<String, dynamic>>[];
  final api = LessonApiService(
    authToken: 'tok',
    client: MockClient((req) async {
      final body = Map<String, dynamic>.from(jsonDecode(req.body) as Map);
      sent.add(body);
      final steps = body['positionList'] as List;
      return http.Response(
        jsonEncode({
          'id': 42,
          'position_list': [
            for (var i = 0; i < steps.length; i++)
              {...steps[i] as Map, 'id': 'step$i'},
          ],
        }),
        req.method == 'POST' ? 201 : 200,
      );
    }),
  );
  return (api: api, sent: sent);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  test('a two-part tutorial, built without a frame', () {
    final c = _blank(title: 'Opozicija');
    var redraws = 0;
    c.addListener(() => redraws++);

    expect(c.playMove('e2', 'e4', ''), MoveOutcome.played);
    expect(c.cursor.moveSan, 'e4');
    expect(c.cursor.fen, _afterE4);
    expect(c.lastMove, (from: 'e2', to: 'e4'));

    final before = c.generation;
    c.addSection(continueFromEnd: true);
    expect(c.draft.sections, hasLength(2));
    expect(c.draft.selected, 1);
    expect(c.section.root.fen, _afterE4,
        reason: '„From here" continues on the position the line reached');
    expect(c.generation, before + 1,
        reason: 'a new open part is a structural change');
    expect(c.lastMove, isNull);

    // Every part shows (docs/PLAN-TUTORIJAL-VIDEO.md, phase 4): a move played
    // in the second part is its line, never an answer kept aside.
    expect(c.playMove('e7', 'e5', ''), MoveOutcome.played);
    expect(c.section.root.children.single.moveSan, 'e5');

    final list = c.draft.positionList;
    expect(list, hasLength(2));
    expect(list[0]['fen'], _start);
    expect(list[1]['fen'], _afterE4);
    for (final part in list) {
      for (final field in ['kind', 'instruction', 'solutionSan', 'choices']) {
        expect(part.containsKey(field), isFalse, reason: field);
      }
    }
    expect(redraws, greaterThan(0));
  });

  test('undo takes one change back, redo brings it forward', () {
    final c = _blank(title: 'Undo');
    expect(c.canUndo, isFalse);

    c.playMove('e2', 'e4', '');
    expect(c.canUndo, isTrue);

    c.undo();
    expect(c.root.children, isEmpty);
    expect(c.cursor, same(c.root));
    expect(c.canRedo, isTrue);

    c.redo();
    expect(c.root.children.single.moveSan, 'e4');
    expect(c.cursor.moveSan, 'e4', reason: 'the cursor comes back with it');
  });

  test('typing is one undo step, a move is another', () {
    final c = _blank();
    c.setTitle('O');
    c.setTitle('Op');
    c.setTitle('Opozicija');
    c.playMove('e2', 'e4', '');

    c.undo();
    expect(c.draft.title, 'Opozicija');
    expect(c.root.children, isEmpty);
    c.undo();
    expect(c.draft.title, '', reason: 'a sentence typed without a pause');
    expect(c.canUndo, isFalse);
  });

  test('deleting a move moves the cursor off it, in one step', () {
    final c = _blank(title: 'Delete');
    c.playMove('e2', 'e4', '');
    c.playMove('e7', 'e5', '');
    final e4 = c.root.children.single;

    c.deleteNode(e4);
    expect(c.root.children, isEmpty);
    expect(c.cursor, same(c.root),
        reason: 'a cursor left inside a detached subtree is a board showing '
            'a position the part no longer holds');

    c.undo();
    expect(c.root.children.single.children.single.moveSan, 'e5',
        reason: 'the move back and the move away are one change');
  });

  test('the ids a save handed out survive an undo past it', () async {
    final c = _blank(title: 'Ids');
    c.playMove('e2', 'e4', '');
    final server = _server();

    expect(await c.save(server.api), isNull);
    expect(c.draft.lessonId, 42);
    expect(c.section.stepId, 'step0');
    expect(server.sent.single['title'], 'Ids');

    // A save changes nothing the trainer wrote, so it does not add a step:
    // the one undo goes back past it, to a snapshot taken before any id
    // existed.
    c.undo();
    expect(c.root.children, isEmpty);
    expect(c.draft.lessonId, 42,
        reason: 'a restored snapshot without an id would make the next save '
            'a second tutorial');
    expect(c.section.stepId, 'step0',
        reason: 'the part gets back the id its key was given');

    // And the next save edits, rather than creates.
    c.playMove('d2', 'd4', '');
    expect(await c.save(server.api), isNull);
    expect(server.sent, hasLength(2));
    expect(server.sent.last['positionList'].single['id'], 'step0');
    expect(c.hasUnsavedChanges, isFalse);
  });

  test('the one refusal left is a missing title', () {
    final c = _blank();
    expect(c.validate(), 'Tutorial must have a title.');

    c.setTitle('Titled');
    c.playMove('e2', 'e4', '');
    expect(c.validate(), isNull,
        reason: 'a part with a line is what a part is, not a leaked answer');
  });

  test('selecting a part stands on its root; the last move is forgotten', () {
    final c = _blank(title: 'Select');
    c.playMove('e2', 'e4', '');
    c.addSection(continueFromEnd: false);
    expect(c.section.root.fen, _start);

    c.select(0);
    expect(c.draft.selected, 0);
    expect(c.cursor, same(c.root));
    expect(c.lastMove, isNull);

    c.select(9);
    expect(c.draft.selected, 0, reason: 'out of range is ignored');
  });

  test('the last part cannot be removed; the rest renumber', () {
    final c = _blank(title: 'Parts');
    expect(c.removeSection(0), isFalse);

    c.addSection(continueFromEnd: false);
    c.addSection(continueFromEnd: false);
    expect(c.draft.sections.map((s) => s.title).toList(),
        ['Part 1', 'Part 2', 'Part 3']);

    c.renameSection(1, '  Mine  ');
    expect(c.removeSection(0), isTrue);
    expect(c.draft.sections.map((s) => s.title).toList(), ['Mine', 'Part 2'],
        reason: 'a name the trainer typed is theirs; the generated ones '
            'renumber');
  });

  test('the saved version is remembered, compared and discardable', () {
    final c = _blank(title: 'Saved');
    final saved = TutorialDraft(
      title: 'Saved',
      sections: [TutorialSection.blank(fen: _start, title: 'Part 1')],
    );

    expect(c.rememberSaved(saved), isFalse);
    expect(c.hasUnsavedChanges, isFalse);
    expect(c.savedVersionKnown, isTrue);

    c.playMove('e2', 'e4', '');
    expect(c.hasUnsavedChanges, isTrue);

    c.discardChanges();
    expect(c.root.children, isEmpty);
    expect(c.hasUnsavedChanges, isFalse);
    expect(c.canUndo, isTrue,
        reason: 'recorded like any other change, so it is one undo away');
  });

  test('flush writes the draft to this device as it stands', () async {
    final c = _blank(title: 'Kept');
    c.playMove('e2', 'e4', '');
    await c.flush();

    final stored = await TutorialDraftService.instance.load();
    expect(stored?.title, 'Kept');
    expect(stored?.section.root.children.single.moveSan, 'e4');
  });

  test('a line read from text replaces the part\'s, cursor at its end', () {
    final c = _blank(title: 'Text');
    final other = _blank();
    other.playMove('d2', 'd4', '');
    other.playMove('d7', 'd5', '');

    c.replaceLine(other.root);
    expect(c.root, same(other.root));
    expect(c.cursor.moveSan, 'd5');
    expect(c.lastMove, isNull);
  });
}
