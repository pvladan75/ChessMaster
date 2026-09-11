// A tutorial's language on its way through the app — phase 3 of
// docs/PLAN-JEZIK-GLASA.md.
//
// **Three answers on the wire, and every test here reads the request.** The
// server keeps the column when a save does not mention it, clears it on an
// explicit null, and stores a code. A draft that does not know its language —
// one kept on this device before the field existed — must say nothing, or it
// wipes a language somebody set elsewhere. That failure would be silent: the
// screen looks the same, and a child's tutorial goes back to the wrong voice.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import_save.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_save.dart';

const openingFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Every body the app sent, and a server that accepts all of them.
class _Wire {
  final bodies = <Map<String, dynamic>>[];

  LessonApiService get api => LessonApiService(
        authToken: 'token',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          bodies.add(body);
          return http.Response(
            jsonEncode({'id': 31, 'position_list': body['positionList'] ?? []}),
            request.method == 'POST' ? 201 : 200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
}

Map<String, dynamic> _savedRow({Object? language = _absent, int id = 31}) => {
      'id': id,
      'title': 'Opozicija',
      if (language != _absent) 'language': language,
      'position_list': [
        {
          'id': 'a3f9c1d2',
          'fen': openingFen,
          'title': 'Part 1',
          'kind': 'show'
        },
      ],
    };

const _absent = Object();

void main() {
  group('a saved tutorial, opened and saved again', () {
    test('keeps the language it was stored with', () async {
      final wire = _Wire();
      final draft = TutorialDraft.fromLesson(_savedRow(language: 'sr-Latn'));
      expect(await commitDraft(draft, wire.api), isNull);
      expect(wire.bodies.single['language'], 'sr-Latn');
    });

    test('that said nothing says „not said", out loud', () async {
      // The row carried the key with a null: the draft knows the answer, and
      // the answer is none. Sending it is harmless and keeps the rule simple —
      // a draft that knows always says.
      final wire = _Wire();
      final draft = TutorialDraft.fromLesson(_savedRow(language: null));
      await commitDraft(draft, wire.api);
      expect(wire.bodies.single.containsKey('language'), isTrue);
      expect(wire.bodies.single['language'], isNull);
    });

    test('from a server without the column does not mention it', () async {
      // An older server answers rows with no `language` key. Saving that
      // draft must not invent „not said" and clear a column the next server
      // version will have.
      final wire = _Wire();
      final draft = TutorialDraft.fromLesson(_savedRow());
      expect(draft.languageKnown, isFalse);
      await commitDraft(draft, wire.api);
      expect(wire.bodies.single.containsKey('language'), isFalse);
    });

    test('with a language chosen sends that one, and clearing it sends null',
        () async {
      final wire = _Wire();
      final draft = TutorialDraft.fromLesson(_savedRow());
      draft.language = 'de';
      await commitDraft(draft, wire.api);
      expect(wire.bodies.last['language'], 'de');

      draft.language = null;
      await commitDraft(draft, wire.api);
      expect(wire.bodies.last.containsKey('language'), isTrue,
          reason: 'a trainer who clears it has said something');
      expect(wire.bodies.last['language'], isNull);
    });
  });

  group('the draft kept on this device', () {
    test('round-trips its language, „not said" included', () {
      final serbian = TutorialDraft.fromJson(
          (TutorialDraft(title: 'x', language: 'sr-Cyrl').toJson()));
      expect(serbian.language, 'sr-Cyrl');
      expect(serbian.languageKnown, isTrue);

      final unsaid = TutorialDraft.fromJson(TutorialDraft(title: 'x').toJson());
      expect(unsaid.language, isNull);
      expect(unsaid.languageKnown, isTrue,
          reason: 'a new tutorial knows its answer, and the answer is none');
    });

    test('written before the field existed stays silent on save', () async {
      // Exactly the slot a trainer upgrading mid-tutorial has on disk: the
      // modern shape, with no `language` key at all.
      final old = TutorialDraft.fromJson({
        'lessonId': 31,
        'title': 'Opozicija',
        'selected': 0,
        'sections': [
          TutorialSection.blank(fen: openingFen, title: 'Part 1').toLocalJson(),
        ],
      });
      expect(old.languageKnown, isFalse);

      // And it stays unknowing through its own save slot — a draft that
      // forgot and was written again must not come back as „not said".
      final again = TutorialDraft.fromJson(old.toJson());
      expect(again.languageKnown, isFalse);

      final wire = _Wire();
      await commitDraft(again, wire.api);
      expect(wire.bodies.single.containsKey('language'), isFalse);
    });

    test('in the shape from before P1 cannot know one', () {
      final ancient = TutorialDraft.fromJson({
        'title': 'Opozicija',
        'examples': [
          {'fen': openingFen, 'title': 'Part 1'},
        ],
      });
      expect(ancient.languageKnown, isFalse);
    });
  });

  group('a tutorial file', () {
    String file(Object? language) => jsonEncode({
          'title': 'The weak square f7',
          if (language != _absent) 'language': language,
          'positionList': [
            {'fen': openingFen, 'title': 'Part 1', 'kind': 'show', 'pgn': ''},
          ],
        });

    test('in one of the seven is imported in it, and clean', () {
      final read = readTutorialJson(file('sr-Latn'));
      expect(read.language, 'sr-Latn');
      expect(read.clean, isTrue);
      expect(TutorialDraft.fromLesson(read.asLesson).language, 'sr-Latn');
    });

    test('without the field is „not said", and clean', () {
      final read = readTutorialJson(file(_absent));
      expect(read.language, isNull);
      expect(read.clean, isTrue);
      final draft = TutorialDraft.fromLesson(read.asLesson);
      expect(draft.languageKnown, isTrue,
          reason: 'an imported tutorial is new, so it knows its answer');
    });

    test(
        'in a language the app cannot read aloud is imported without it, '
        'and says so', () {
      for (final code in ['pt', 'sr', 'EN', 5]) {
        final read = readTutorialJson(file(code));
        expect(read.language, isNull, reason: '$code');
        expect(read.storable, isTrue,
            reason: 'a wrong language is no reason to lose the tutorial');
        expect(read.problems.single.fault, ImportFault.damaged);
        expect(read.problems.single.sentence, contains('"$code"'));
      }
    });

    test('saved straight to the library carries its language', () async {
      final wire = _Wire();
      await saveImportedTutorials([
        readTutorialJson(file('fr')),
        readTutorialJson(file(_absent)),
        readTutorialJson(file('pt')),
      ], wire.api);
      expect(
          wire.bodies.map((b) => b['language']).toList(), ['fr', null, null]);
      expect(wire.bodies.every((b) => b.containsKey('language')), isTrue,
          reason: 'a new tutorial states its answer; the server never guesses');
    });

    test('keeps its language when the batch is labelled', () {
      expect(
          readTutorialJson(file('it')).withLabels(['endgame']).language, 'it');
    });
  });
}
