// The lead's gate for what a part is *called* — written after batch 57, for a
// gap the batch's own gate could not see.
//
// `docs/gates/tutorial_delovi_test.dart` asks the panel to show „Deo 1" and
// „Deo 2" in the right order, and `TutorialSectionsPanel` satisfies that by
// labelling every generated-looking title from its own row index. So emptying
// `_renumberGeneratedTitles()` in the screen left all fourteen of those tests
// green: the panel drew the right words over the wrong data.
//
// The stored title is not decoration. `TutorialSection.toJson` sends it as the
// step's `title`, which is what the child's lesson step is called — so a part
// moved to the front while its stored name still says „Deo 2" ships a tutorial
// whose steps are numbered the other way round from the screen that wrote them.
//
// It asserts on the **request**, for the same reason
// `tutorial_authoring_test.dart` does: the screen is not the artefact.
//
// Proved by mutation before being believed: with the body of
// `_renumberGeneratedTitles` removed, the reorder test below fails on the
// title, and the delovi gate stays green.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_handover.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';

class _RecordingApi extends LessonApiService {
  _RecordingApi._(this.saves, http.Client client)
      : super(authToken: 'tok', client: client);

  final List<Map<String, dynamic>> saves;

  factory _RecordingApi() {
    final saves = <Map<String, dynamic>>[];
    return _RecordingApi._(
      saves,
      MockClient((req) async {
        if (req.method == 'POST' && req.url.path.endsWith('/lessons/save')) {
          saves.add(Map<String, dynamic>.from(jsonDecode(req.body) as Map));
        }
        return http.Response(jsonEncode({'id': 77}), 201);
      }),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  final session = UserSession(
    token: 'tok',
    id: 7,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  group('the rule about a generated name', () {
    test('a studio-written name is one word and a number', () {
      expect(isGeneratedSectionTitle('Deo 1'), isTrue);
      expect(isGeneratedSectionTitle('Deo 12'), isTrue);
      // Tutorials written before the word changed are still on the server, and
      // reordering one must renumber it rather than leave „Primer 3" second.
      expect(isGeneratedSectionTitle('Primer 3'), isTrue);
      expect(isGeneratedSectionTitle('  Deo 2  '), isTrue);
    });

    test('a name the trainer wrote is never renumbered over', () {
      expect(isGeneratedSectionTitle('Matni motiv'), isFalse);
      expect(isGeneratedSectionTitle('Deo'), isFalse);
      expect(isGeneratedSectionTitle('Deo 3a'), isFalse);
      expect(isGeneratedSectionTitle('Primer sa damom'), isFalse);
    });

    test('the name is one-based, the index is not', () {
      expect(generatedSectionTitle(0), 'Deo 1');
      expect(generatedSectionTitle(4), 'Deo 5');
    });
  });

  group('what is stored follows what is shown', () {
    Future<_RecordingApi> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = _RecordingApi();
      await tester.pumpWidget(MaterialApp(
        home: TutorialStudioScreen(
          session: session,
          entry:
              TutorialEntry.fromAnalysis(TutorialHandover.position(startFen)),
          lessonApi: api,
        ),
      ));
      await tester.pumpAndSettle();
      return api;
    }

    Future<void> type(WidgetTester tester, String key, String value) async {
      await tester.enterText(find.byKey(Key(key)), value);
      await tester.pumpAndSettle();
    }

    Future<void> tapText(WidgetTester tester, String label) async {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('a reordered part is stored under the name the panel shows',
        (tester) async {
      final api = await open(tester);
      await type(tester, 'tutorial-title', 'Dva dela');
      await type(tester, 'example-sentence', 'Ovo je prvi.');

      await tapText(tester, '+ Dodaj deo');
      await tapText(tester, 'Nova pozicija');
      await type(tester, 'example-sentence', 'Ovo je drugi.');

      await tester.tap(find.byTooltip('Pomeri gore'));
      await tester.pumpAndSettle();

      await tapText(tester, 'Sačuvaj tutorijal');
      await tester.pumpAndSettle();

      expect(api.saves, hasLength(1));
      final list = (api.saves.single['positionList'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      expect(list, hasLength(2));

      // The part that moved to the front carries its own work *and* the front
      // part's name — both, or the tutorial the child opens is numbered the
      // other way round from the one the trainer wrote.
      expect(list.first['pgn'].toString(), contains('Ovo je drugi.'),
          reason: 'the part did not move, only its row did');
      expect(list.first['title'], 'Deo 1',
          reason: 'the panel shows „Deo 1" here and the server is being told '
              'something else');
      expect(list.last['pgn'].toString(), contains('Ovo je prvi.'));
      expect(list.last['title'], 'Deo 2');

      await close(tester);
    });
  });
}
