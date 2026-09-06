// The gate for P3a of `docs/PLAN-STUDIO-REDIZAJN.md` — §6, saving.
//
// Written before the work. What it is for, in one sentence: **after the first
// save the draft has to learn what the server called it, or the trainer's
// second press of „Sačuvaj" makes a second tutorial and their third makes a
// third.**
//
// Both routes already answer with `RETURNING *`, so the row comes back carrying
// `position_list` with the ids the server minted. Until now
// `LessonApiService.save` and `.update` threw that body away and answered
// `String?`.
//
// ---------------------------------------------------------------------------
// WHY THE OLD SIGNATURES SURVIVE
//
// `Future<String?>` is not kept out of politeness. Three gate files —
// `lesson_editor_test.dart`, `lesson_answer_stays_hidden_test.dart` and
// `lesson_step_order_test.dart` — fake the server by **overriding `update`**,
// and `docs/PLAN-STUDIO-REDIZAJN.md` §8 requires all three to pass unedited.
// Changing that return type would have forced three protected gates open to
// make a convenience change.
//
// So there is one implementation and two shapes: `updateTutorial` does the work
// and answers with the row, `update` is `(await updateTutorial(…)).error`. The
// editor panel goes on calling `update`; the studio calls `commitDraft`, which
// calls the row-returning pair.
//
// ---------------------------------------------------------------------------
// THE ONE JUDGEMENT CALL IN HERE
//
// A server that answers success but says nothing about the steps. The real one
// never does — it returns the whole row — but a save that the server accepted
// **is** a save, and answering „nije sačuvano" over a row that is in the
// database is the worse of the two lies.
//
// So: the id is taken, no step id is guessed, and the next save is left to the
// backend's own guard, which is loud and already worded for a trainer — „Koraci
// su stigli bez svojih oznaka. Osvežite tutorijal pa ga sačuvajte ponovo."
// (`routes/lessons.js`, the 409). Inventing a second refusal here would only
// mean two sentences for one fault, and this one would arrive earlier and know
// less.
//
// Ids are never assigned by guessing an alignment. A list of a different length
// is a list this code cannot match to its sections, and matching it wrongly is
// a child's schedule attached to the wrong part of the tutorial.
// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_save.dart';

const String openingFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// A response that can carry Serbian.
///
/// `http.Response(String, …)` encodes with **latin1** unless the content type
/// says otherwise, and this server's sentences are the trainer's own — „Rešenje
/// „Nf3" ne može da se odigra u ovoj poziciji." A mock that cannot hold a `đ`
/// throws where the real server would have answered, and the failure arrives
/// dressed as „Nije moguće doći do servera." — a network error, for a bug in
/// the fixture.
http.Response _json(Map<String, dynamic> body, int code) => http.Response(
      jsonEncode(body),
      code,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Every request that went out, and what the server answered.
///
/// The server is modelled rather than stubbed: it mints an id for a step that
/// arrives without one and keeps the id of a step that has one, which is what
/// `buildLessonStep` does and is the entire behaviour this file is about.
class _Server {
  _Server({this.failWith, this.answerSteps = true});

  final List<({String method, String path, Map<String, dynamic> body})> seen =
      [];

  /// When set, every request is refused with this sentence.
  final String? failWith;

  /// When false the row comes back without `position_list` — the shape a
  /// server that told us nothing about the steps would have.
  final bool answerSteps;

  int _next = 0;

  List<Map<String, dynamic>> get posts => [
        for (final r in seen)
          if (r.method == 'POST') r.body,
      ];

  List<Map<String, dynamic>> get puts => [
        for (final r in seen)
          if (r.method == 'PUT') r.body,
      ];

  LessonApiService get api => LessonApiService(
        authToken: 'tok',
        client: MockClient((req) async {
          final body = req.body.isEmpty
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(jsonDecode(req.body) as Map);
          seen.add((method: req.method, path: req.url.path, body: body));

          if (failWith != null) {
            return _json({'error': failWith}, 422);
          }

          final sent = (body['positionList'] as List?) ?? const [];
          final stored = [
            for (final raw in sent)
              {
                ...Map<String, dynamic>.from(raw as Map),
                'id': (raw['id'] as String?) ?? 'srv${_next++}',
              },
          ];

          return _json({
            'id': 77,
            'title': body['title'],
            if (answerSteps) 'position_list': stored,
          }, req.method == 'POST' ? 201 : 200);
        }),
      );
}

TutorialDraft twoSections() => TutorialDraft(
      title: 'Opozicija',
      sections: [
        TutorialSection.fromStep({
          'fen': openingFen,
          'pgn': '1. e4 { Centar. } e5',
          'title': 'Uvod',
        }),
        TutorialSection.fromStep({
          'fen': openingFen,
          'title': 'Pitanje',
          'kind': 'ask_move',
          'instruction': 'Nađi potez.',
          'solutionSan': 'e4',
        }),
      ],
    );

void main() {
  group('the service answers with the row it was given', () {
    test('a save comes back with the id and the stored steps', () async {
      final server = _Server();
      final result = await server.api.saveTutorial(
        title: 'Opozicija',
        positionList: [
          {'fen': openingFen, 'title': 'Uvod', 'kind': 'show'},
        ],
      );

      expect(result.ok, isTrue);
      expect(result.id, 77);
      expect(result.steps.single['id'], 'srv0',
          reason: 'the ids the server minted did not come back, so nothing '
              'can learn them');
    });

    test('an update comes back the same way', () async {
      final server = _Server();
      final result = await server.api.updateTutorial(
        id: 77,
        title: 'Opozicija',
        positionList: [
          {'id': 'keepme', 'fen': openingFen, 'title': 'Uvod', 'kind': 'show'},
        ],
      );

      expect(result.ok, isTrue);
      expect(result.steps.single['id'], 'keepme');
    });

    test('a refusal keeps the server’s own sentence', () async {
      // The rule this class has always kept: a refusal is passed on in the
      // server's words. „Rešenje ne može da se odigra u ovoj poziciji" is
      // something a trainer can act on; „Čuvanje nije uspelo" is not.
      final server = _Server(failWith: 'Pozicija nije ispravna.');
      final result =
          await server.api.saveTutorial(title: 'X', positionList: []);

      expect(result.ok, isFalse);
      expect(result.error, 'Pozicija nije ispravna.');
      expect(result.id, isNull);
    });

    test('the old shape still answers with just the sentence', () async {
      // Three gate files fake the server by overriding `update`, and the plan
      // requires them to pass unedited. This is what keeps that true.
      final ok = _Server();
      expect(await ok.api.update(id: 77, title: 'X'), isNull);

      final bad = _Server(failWith: 'Nešto je pošlo naopako.');
      expect(await bad.api.save(title: 'X', fen: openingFen),
          'Nešto je pošlo naopako.');
    });
  });

  group('the first save teaches the draft what it is', () {
    test('a draft that has never been saved is posted, once', () async {
      final server = _Server();
      final draft = twoSections();

      final error = await commitDraft(draft, server.api);

      expect(error, isNull);
      expect(server.posts.length, 1);
      expect(server.puts, isEmpty);
      expect(server.posts.single['title'], 'Opozicija');
      expect(
          (server.posts.single['positionList'] as List)
              .map((s) => s['title'])
              .toList(),
          ['Uvod', 'Pitanje'],
          reason: 'the parts reached the server out of order');
    });

    test('and then knows its id and every step id', () async {
      final server = _Server();
      final draft = twoSections();
      await commitDraft(draft, server.api);

      expect(draft.lessonId, 77);
      expect(draft.sections.map((s) => s.stepId).toList(), ['srv0', 'srv1']);
    });

    test('a second save updates, and carries the ids with it', () async {
      // The whole point of the phase. Without this the trainer's second press
      // makes a second tutorial, and their students' schedules point at the
      // first.
      final server = _Server();
      final draft = twoSections();
      await commitDraft(draft, server.api);
      await commitDraft(draft, server.api);

      expect(server.posts.length, 1, reason: 'it made a second tutorial');
      expect(server.puts.length, 1);
      expect(
          (server.puts.single['positionList'] as List)
              .map((s) => s['id'])
              .toList(),
          ['srv0', 'srv1'],
          reason: 'the steps went back without their ids — every schedule row '
              'and every recorded answer naming them is orphaned');
    });

    test('a part written here becomes pristine the moment it is saved',
        () async {
      // After a save the stored text is what the server holds, so the part must
      // go back byte-identical next time rather than through a fresh export
      // with a new `[Date]` header on it.
      //
      // The part is **built here rather than read from a step**, and that is
      // the whole test. A part that arrived through `fromStep` is already
      // pristine, so it stays byte-identical whether or not the save records
      // anything — which is how the first version of this test passed with
      // `markSaved` writing no text at all. A mutation found that; the fix is
      // to start from the one state that can tell the difference.
      final server = _Server();
      final draft = TutorialDraft(
        title: 'Nov tutorijal',
        sections: [TutorialSection.blank(fen: openingFen, title: 'Uvod')],
      );
      draft.sections.single.root.comment = 'Pogledaj centar.';
      expect(draft.sections.single.isPristine, isFalse,
          reason: 'nothing has been saved yet, so there is no stored text');

      await commitDraft(draft, server.api);

      expect(draft.sections.single.isPristine, isTrue,
          reason: 'the part did not learn what the server stored, so the next '
              'save re-exports a line nobody edited');
      expect(draft.sections.single.storedPgn,
          (server.posts.single['positionList'] as List).single['pgn']);
    });

    test('an untouched part goes back byte-identical', () async {
      final server = _Server();
      final draft = twoSections();
      await commitDraft(draft, server.api);
      await commitDraft(draft, server.api);
      await commitDraft(draft, server.api);

      final second = (server.puts[0]['positionList'] as List).first['pgn'];
      final third = (server.puts[1]['positionList'] as List).first['pgn'];
      expect(third, second);
      expect(draft.sections.first.isPristine, isTrue);
    });

    test('an edit after a save is written, and the id survives it', () async {
      final server = _Server();
      final draft = twoSections();
      await commitDraft(draft, server.api);

      draft.sections.first.root.children.first.comment = 'Druga rečenica.';
      await commitDraft(draft, server.api);

      final sent = (server.puts.single['positionList'] as List).first;
      expect(sent['pgn'].toString(), contains('Druga rečenica.'));
      expect(sent['id'], 'srv0');
      expect(draft.sections.first.isPristine, isTrue,
          reason: 'the edit was saved but the part still thinks its stored '
              'text is the old one');
      expect(draft.sections.first.storedPgn, sent['pgn']);
    });
  });

  group('what a failure must not do', () {
    test('a refused save leaves the draft unsaved', () async {
      // If a failed POST set `lessonId`, the next attempt would PUT to a
      // tutorial that does not exist — and the trainer would be told their
      // tutorial is gone rather than that it was never written.
      final server = _Server(failWith: 'Pozicija nije ispravna.');
      final draft = twoSections();

      final error = await commitDraft(draft, server.api);

      expect(error, 'Pozicija nije ispravna.');
      expect(draft.lessonId, isNull);
      expect(draft.sections.every((s) => s.stepId == null), isTrue);
    });

    test('a server that says nothing about the steps still saved', () async {
      // See the note at the top of this file. The write happened; refusing to
      // admit it would be the worse lie. No step id is guessed, and the next
      // save meets the backend's own 409, which is loud and already worded.
      final server = _Server(answerSteps: false);
      final draft = twoSections();

      final error = await commitDraft(draft, server.api);

      expect(error, isNull);
      expect(draft.lessonId, 77);
      expect(draft.sections.every((s) => s.stepId == null), isTrue);
    });

    test('a step list of the wrong length is never matched up', () async {
      // Matching it by position would attach a child's progress to the wrong
      // part of the tutorial — silently, because nothing joins on a step id.
      final server = _Server();
      final draft = twoSections();
      // The server answers with one step for the two that were sent.
      final api = LessonApiService(
        authToken: 'tok',
        client: MockClient((req) async => _json({
              'id': 77,
              'position_list': [
                {'id': 'only', 'fen': openingFen, 'title': 'Uvod'},
              ],
            }, 201)),
      );

      final error = await commitDraft(draft, api);

      expect(error, isNull);
      expect(draft.lessonId, 77);
      expect(draft.sections.every((s) => s.stepId == null), isTrue);
      expect(server.seen, isEmpty);
    });
  });
}
