import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/lessons/widgets/lesson_step_editor_panel.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_studio_availability.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';

/// The three things a trainer can do to a tutorial they already have: edit it,
/// rename it, and keep it while making another version.
///
/// The one that has to be asserted on the **request** rather than on the screen
/// is the rename. `PUT /lessons/:id` tells „leave the steps alone" apart from
/// „there are none now" by whether the body mentions `positionList` at all, so
/// a rename that sends an empty list writes `position_list = NULL` and every
/// step of the tutorial is gone — silently, with nothing joining on them to
/// complain. The app already had a rename that did exactly this;
/// `lesson_rename_keeps_steps.test.js` exists on the server because of it.
class _RecordingApi extends LessonApiService {
  _RecordingApi._(this.seen, http.Client client)
      : super(authToken: 'tok', client: client);

  /// Answers the way the real server answers, and remembers what it was asked.
  ///
  /// The status codes matter: `clone` accepts **201** and reads `id` off the
  /// row it gets back, so a mock that answers 200 with some other shape makes
  /// the clone path fail while the test still passes — it would only be
  /// asserting that a POST went out.
  factory _RecordingApi() {
    final seen = <({String method, String path, Map<String, dynamic> body})>[];
    return _RecordingApi._(
      seen,
      MockClient((req) async {
        seen.add((
          method: req.method,
          path: req.url.path,
          body: req.body.isEmpty
              ? const <String, dynamic>{}
              : Map<String, dynamic>.from(jsonDecode(req.body) as Map),
        ));

        final cloned = seen.any((r) => r.path.contains('/clone'));

        if (req.method == 'GET' && req.url.path.endsWith('/labels')) {
          return http.Response('[]', 200);
        }
        if (req.method == 'GET' && req.url.path.endsWith('/lessons')) {
          return http.Response(
            jsonEncode([
              {
                'id': 42,
                'title': 'Stari naziv',
                'description': 'Opis',
                'tags': <String>[],
                'position_list': [
                  {'id': 'aaaa1111', 'fen': _fen, 'title': 'Korak 1'},
                ],
              },
              // The copy appears in the list only once it has been made, the
              // way a refetch after a clone would see it.
              if (cloned)
                {
                  'id': 43,
                  'title': 'Stari naziv (kopija)',
                  'description': 'Opis',
                  'tags': <String>[],
                  'position_list': [
                    {'id': 'bbbb2222', 'fen': _fen, 'title': 'Korak 1'},
                  ],
                },
            ]),
            200,
          );
        }
        if (req.method == 'POST' && req.url.path.contains('/clone')) {
          return http.Response(
            jsonEncode({'id': 43, 'title': 'Stari naziv (kopija)'}),
            201,
          );
        }
        if (req.method == 'PUT') {
          return http.Response(jsonEncode({'id': 42}), 200);
        }
        return http.Response('{}', 200);
      }),
    );
  }

  final List<({String method, String path, Map<String, dynamic> body})> seen;
}

const _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

void main() {
  // Which editor „Uredi" opens is decided by `isTutorialStudioAvailable` since
  // D8 of `docs/PLAN-STUDIO-REDIZAJN.md`: the studio on Windows, this panel
  // everywhere else. These tests are about *which tutorial* the editor is given
  // — the copy rather than the original, the one that was chosen — so they pin
  // the answer rather than depending on the machine the suite happens to run
  // on. Without this they pass on a developer's Windows box and fail on CI's
  // Linux runner, or the other way round, which is the local-versus-CI shape
  // this project has already paid for once.
  //
  // The Windows side of that door has its own file:
  // `test/tutorial_editor_door_test.dart`.
  setUp(() => debugTutorialStudioAvailable = false);
  tearDown(() => debugTutorialStudioAvailable = null);

  Future<_RecordingApi> openLibrary(WidgetTester tester) async {
    final api = _RecordingApi();
    // Wide enough for the two-column layout, where the saved tutorials live.
    //
    // Nothing here suppresses layout errors, and that is deliberate: the first
    // version of this file muted `FlutterError.onError` for every RenderFlex
    // message, which made it green over a real overflow — the filter panel's
    // title, clipped by 91 px inside the sidebar. In a release build that is
    // not a warning, it is a silent clip. Fixed in `matrix_filter_panel.dart`
    // instead.
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: ChessGamePage(
        userSession: UserSession(
            id: 1, token: 'tok', email: 'e', name: 'N', role: 'trener'),
        roomCode: 'STUDIO',
        initialRole: 'trener',
        lessonApi: api,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Stari naziv'), findsWidgets,
        reason: 'the saved tutorial must be on screen before anything is asked '
            'of it');
    return api;
  }

  Future<void> chooseAction(WidgetTester tester, String label) async {
    final menu = find.byTooltip('Opcije').first;
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('a rename never mentions the steps', (tester) async {
    final api = await openLibrary(tester);

    await chooseAction(tester, 'Preimenuj');
    expect(find.text('Preimenuj tutorijal'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Novi naziv');
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    final put = api.seen.firstWhere(
      (r) => r.method == 'PUT' && r.path.contains('42'),
      orElse: () => (method: '', path: '', body: const <String, dynamic>{}),
    );
    expect(put.method, 'PUT', reason: 'the rename never reached the server');
    expect(put.body['title'], 'Novi naziv');
    expect(put.body.containsKey('positionList'), isFalse,
        reason: 'a body that mentions positionList at all can null the column; '
            'an empty list is not "leave them alone"');
  });

  testWidgets('saving as a new version opens the copy, not the original',
      (tester) async {
    final api = await openLibrary(tester);

    await chooseAction(tester, 'Sačuvaj kao novu verziju');

    final clone = api.seen.firstWhere(
      (r) => r.path.contains('/clone'),
      orElse: () => (method: '', path: '', body: const <String, dynamic>{}),
    );
    expect(clone.method, 'POST');
    expect(clone.path, contains('/lessons/42/clone'));

    // The point of the action: the trainer is left in the copy. Landing back in
    // the original is how somebody edits the version they meant to keep.
    expect(find.byType(LessonStepEditorPanel), findsOneWidget);
    expect(find.text('Stari naziv (kopija)'), findsWidgets);
  });

  testWidgets('editing opens the step editor on the tutorial chosen',
      (tester) async {
    await openLibrary(tester);

    await chooseAction(tester, 'Uredi tutorijal');

    expect(find.byType(LessonStepEditorPanel), findsOneWidget);
    expect(find.text('Stari naziv'), findsWidgets);
  });

  testWidgets(
      'editing the positions of an existing tutorial is still reachable',
      (tester) async {
    // The menu replaced the only route to the course dialog, and the step
    // editor cannot add, remove or reorder steps until batch F. Without this
    // entry a trainer could no longer change which positions a tutorial is
    // made of.
    await openLibrary(tester);

    await chooseAction(tester, 'Izmeni pozicije');

    expect(find.text('Izmeni tutorijal'), findsWidgets);
  });
}
