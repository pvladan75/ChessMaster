// Every door but the board splits a fork — phase 2 of
// `docs/PLAN-MAPA-DELOVA.md`, D2. `splitAtForks` is held to its order in
// `tutorial_split_at_forks_test.dart`; this file holds each door to calling
// it, by feeding it a tree that forks and asking that no part of what comes
// out does, and that the film shows every move.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/studio_lesson_step.dart';
import 'package:chess_app/features/lessons/models/lesson_step_line.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_handover.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/pgn_game_import.dart';
import 'package:chess_app/features/tutorial_studio/services/section_split.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/account_local_state.dart';

import 'support/tutorial_part_fixtures.dart';

/// A part's line, as its moves.
List<String> _line(TutorialSection part) => [
      for (AnalysisNode n = part.root;
          n.children.isNotEmpty;
          n = n.children.first)
        n.children.first.moveSan!,
    ];

/// D2's order for [manyForksPart], which `tutorial_split_at_forks_test` holds
/// `splitAtForks` to. Written out here too, so a door that split some other
/// way would not pass by agreeing with a function it does not call.
const _manyForksLines = [
  ['Be3', 'Nxe3', 'fxe3'],
  ['Bc1', 'Nxe5'],
  ['Bg5', 'Nxe5', 'Rfe1'],
  ['h6'],
  ['Bxf6', 'Qxf6'],
  ['Rxe5'],
  ['cxd4', 'cxd4'],
];

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

  Future<void> open(WidgetTester tester, TutorialEntry entry,
      {LessonApiService? api}) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Closed even when the case fails half way: a screen left standing is
    // the next case's neighbour.
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: entry,
        lessonApi: api,
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Closes the screen, which writes the draft, and reads it back.
  Future<TutorialDraft> closeAndRead(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    final stored = await tester.runAsync(TutorialDraftService.instance.load);
    return stored!;
  }

  group('the handover from Analysis', () {
    testWidgets('into a new tutorial: every fork is a part', (tester) async {
      await open(
        tester,
        TutorialEntry.fromAnalysis(
          TutorialHandover.tree(manyForksPart().root),
          intoOpenDraft: false,
        ),
      );
      final draft = await closeAndRead(tester);

      expect(draft.sections.map(_line), _manyForksLines);
      expect(draft.sections.any(partForks), isFalse);
      expect(draft.selected, 0);
    });

    testWidgets('into the tutorial being written: the same', (tester) async {
      await tester.runAsync(() => TutorialDraftService.instance.flush(
            TutorialDraft(
              title: 'Opozicija',
              sections: [partOf(standardStart, '1. e4 {Zapamti ovo.} *')],
            ),
            epoch: AccountLocalState.epoch,
          ));
      await open(
        tester,
        TutorialEntry.fromAnalysis(TutorialHandover.tree(manyForksPart().root)),
      );
      final draft = await closeAndRead(tester);

      expect(draft.title, 'Opozicija',
          reason: 'the case needs the handover into the open draft');
      expect(draft.sections.map(_line), _manyForksLines,
          reason: 'the handover replaces the open part, and splits it');
      expect(draft.sections.any(partForks), isFalse);
    });
  });

  group('the PGN tab\'s Apply', () {
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

    var nextLessonId = 410;

    Map<String, dynamic> lessonOn(String fen) => {
          'id': nextLessonId++,
          'title': 'Top protiv skakača',
          'position_list': [
            {'id': 'step-1', 'fen': fen, 'title': 'First', 'kind': 'show'},
          ],
        };

    Future<void> applyText(WidgetTester tester, String text) async {
      await tester.tap(find.byKey(const Key('pgn-tab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pgn-field')), text);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pgn-apply')));
      await tester.pumpAndSettle();
    }

    Future<List<List<String>>> savedLines(WidgetTester tester) async {
      await tester.tap(find.text('Save tutorial'));
      await tester.pumpAndSettle();
      return [
        for (final part in saves.last['positionList'] as List)
          LessonStepLine.read(
            fen: (part as Map)['fen'].toString(),
            pgn: part['pgn']?.toString(),
          ).line.movesSan,
      ];
    }

    testWidgets('the owner\'s example becomes the three parts of 12.9',
        (tester) async {
      // The order the owner checked live on 12.9.2026 (`[151.7]`): up to the
      // fork, the new line, the original continuation.
      await open(tester, TutorialEntry.saved(lessonOn(ownerExampleFen)),
          api: recordingApi());
      await applyText(tester, ownerExamplePgn);

      expect(
          find.text('Applied as 3 parts: every side line is a part of its '
              'own.'),
          findsOneWidget);
      expect(await savedLines(tester), [
        ['Ra1', 'Kc6'],
        ['Ra8', 'Bb2'],
        ['Ra6', 'Bb2', 'c3', 'Kb5'],
      ]);
      expect((saves.last['positionList'] as List).first['id'], 'step-1',
          reason: 'the part that starts where it did keeps its step id');
    });

    testWidgets('a text with no side line is one part, as before',
        (tester) async {
      await open(tester, TutorialEntry.saved(lessonOn(ownerExampleFen)),
          api: recordingApi());
      await applyText(tester, '1. Ra1 Kc6 2. Ra6 *');

      expect(find.text('Applied.'), findsOneWidget);
      expect(await savedLines(tester), [
        ['Ra1', 'Kc6', 'Ra6'],
      ]);
    });
  });

  // Doors 4 and 5 are one door: „Open" and „Save" both read the
  // `positionList` an import made, so it is split where it is made.
  group('an import', () {
    TutorialDraft opened(ImportedTutorial t) =>
        TutorialDraft.fromLesson(t.asLesson);

    test('a JSON part that forks becomes parts, numbered where they stand', () {
      final t = readTutorialJson(
        jsonEncode({
          'title': 'Knjiga',
          'positionList': [
            {'fen': forkPosition, 'pgn': manyForksPgn},
            {'fen': 'not a position', 'pgn': '1. e4'},
          ],
        }),
        fileName: 'knjiga.json',
      );

      expect(t.positionList, hasLength(8));
      final draft = opened(t);
      expect(draft.sections.take(7).map(_line), _manyForksLines);
      expect(draft.sections.any(partForks), isFalse);
      expect(t.problems.map((p) => p.partNumber), [8],
          reason: 'the broken part is the eighth on the screen, not the '
              'second in the file');
      expect(t.positionList.any((s) => s.containsKey('id')), isFalse);
    });

    test('a part that does not fork is imported as it was written', () {
      const pgn = '17. Bg5 {The bishop pins.}   Nxe5 *';
      final t = readTutorialJson(jsonEncode({
        'title': 'Knjiga',
        'positionList': [
          {'fen': forkPosition, 'pgn': pgn, 'title': 'Pin'},
        ],
      }));
      expect(t.positionList.single['pgn'], pgn);
      expect(t.positionList.single['title'], 'Pin');
    });

    test('a part the reader cannot replay whole is left as it is', () {
      // Its report says what is wrong; splitting what the reader made of it
      // would save a shorter line under a clean report.
      const pgn = '1. e4 (1. d4 d5) e5 2. Kxe8 *';
      final t = readTutorialJson(jsonEncode({
        'title': 'Knjiga',
        'positionList': [
          {'fen': standardStart, 'pgn': pgn},
        ],
      }));
      expect(t.positionList.single['pgn'], pgn);
      expect(t.problems.single.fault, ImportFault.damaged);
    });

    test('a PGN game with a variation becomes one part per line', () {
      final t = tutorialFromGame(
        '[Event "Lekcija"]\n[FEN "$ownerExampleFen"]\n[SetUp "1"]\n\n'
        '$ownerExamplePgn\n',
      );
      expect(opened(t).sections.map(_line), [
        ['Ra1', 'Kc6'],
        ['Ra8', 'Bb2'],
        ['Ra6', 'Bb2', 'c3', 'Kb5'],
      ]);
      expect(t.problems, isEmpty);
    });
  });

  // Door 6: Analysis „Add this line to a tutorial…". The screen builds its
  // services itself, so the two halves are held here — what a line becomes,
  // and the one request that carries it. The route's half, whole or not at
  // all, is `chess_backend/test/lesson_steps_append.test.js`.
  group('a line from Analysis', () {
    List<List<String>> lines(List<StudioLessonStep> steps) =>
        [for (final s in steps) s.line.movesSan];

    test('from the start: one step per line, in D2\'s order', () {
      final root = manyForksPart().root;
      final signature = treeSignature(root);
      final steps = StudioLessonStep.partsFrom(root);

      expect(lines(steps), _manyForksLines);
      expect(steps.every((s) => s.replays), isTrue);
      expect(treeSignature(root), signature,
          reason: 'the tree on the Analysis screen was changed');
    });

    test('from a move inside the line: the lines from there on', () {
      final root = manyForksPart().root;
      final rfe1 = root.children.first.children.first.children.first;
      expect(rfe1.moveSan, 'Rfe1');
      final steps = StudioLessonStep.partsFrom(rfe1);

      expect(lines(steps), [
        ['h6'],
        ['Bxf6', 'Qxf6'],
        ['Rxe5'],
        ['cxd4', 'cxd4'],
      ]);
      expect(steps.first.fen, rfe1.fen);
    });

    test('a line with no side line is one step, as before', () {
      final steps =
          StudioLessonStep.partsFrom(partOf(forkPosition, '17. Bg5 *').root);
      expect(lines(steps), [
        ['Bg5'],
      ]);
    });

    test('appendSteps sends them in one request, in order', () async {
      final sent = <http.Request>[];
      final api = LessonApiService(
        authToken: 'tok',
        client: MockClient((req) async {
          sent.add(req);
          return http.Response('{}', 201);
        }),
      );
      final steps = StudioLessonStep.partsFrom(ownerExamplePart().root);

      final error = await api.appendSteps(
        lessonId: 5,
        steps: [for (final s in steps) s.toJson(title: 'New task')],
      );

      expect(error, isNull);
      expect(sent, hasLength(1));
      expect(sent.single.url.path, '/lessons/5/steps');
      final body = jsonDecode(sent.single.body) as Map;
      expect(body.containsKey('step'), isFalse);
      expect([
        for (final s in body['steps'] as List)
          LessonStepLine.read(fen: s['fen'], pgn: s['pgn']).line.movesSan,
      ], [
        ['Ra1', 'Kc6'],
        ['Ra8', 'Bb2'],
        ['Ra6', 'Bb2', 'c3', 'Kb5'],
      ]);
    });
  });
}
