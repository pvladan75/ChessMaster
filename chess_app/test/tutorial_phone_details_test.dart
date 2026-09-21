// Labels and language on a phone — item 6 of the owner's review of
// 21.9.2026, from his report of 20.9.2026: „U portret orjentaciji ne vide se
// label i jezik tutorijala."
//
// Left out of the phone layout on purpose in phase 6b, and said so in its own
// header — but a tutorial made on a phone then had no labels to be found by in
// the Library and no language, and the language decides the voice that reads
// it. „More" → „Details…" opens a sheet with the **same** two fields the
// desktop draws (`_labelsField`, `_languageField`), so there is no second
// copy of either rule.
//
// Asserted on the save request, not on the screen (rule 7): a field that is
// drawn and wired to nothing looks exactly like one that works.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_handover.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Answers every save with an id and remembers what it was sent.
class _RecordingApi extends LessonApiService {
  _RecordingApi._(this.seen, http.Client client)
      : super(authToken: 'tok', client: client);

  final List<({String method, String path, Map<String, dynamic> body})> seen;

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
        return http.Response(jsonEncode({'id': 77}), 201);
      }),
    );
  }

  List<Map<String, dynamic>> get saves => [
        for (final r in seen)
          if (r.method == 'POST' && r.path.endsWith('/lessons/save')) r.body,
      ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final session = UserSession(
      token: 'tok', id: 7, email: 'a@b.c', name: 'Trener', role: 'trener');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  Future<_RecordingApi> openPhone(WidgetTester tester, Size size) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _RecordingApi();
    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.fromAnalysis(TutorialHandover.position(_startFen)),
        lessonApi: api,
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'overflow on opening');
    // The phone layout, not the desktop's narrow branch: the phone's own bar.
    expect(find.byKey(const Key('phone-more')), findsOneWidget);
    return api;
  }

  /// Inside the test, not in a `tearDown` — see `tutorial_phone_layout_test`.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    debugDefaultTargetPlatformOverride = null;
  }

  Future<void> openDetails(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('phone-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Details…'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'overflow in the sheet');
  }

  for (final (name, size) in [
    ('portrait, 360 × 640', const Size(360, 640)),
    ('landscape, 640 × 360', const Size(640, 360)),
  ]) {
    testWidgets('$name: labels and language reach the save', (tester) async {
      final api = await openPhone(tester, size);

      // Not on the screen until asked for — the phone's room is the board's.
      expect(find.byKey(const Key('tutorial-labels')), findsNothing);

      await openDetails(tester);
      await tester.enterText(
          find.byKey(const Key('tutorial-labels')), 'endgame, rook');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tutorial-language')));
      await tester.pumpAndSettle();
      // The closed button draws its entries too; the open menu's is the last.
      await tester.tap(find.text('German').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<String?>>(
                find.byKey(const Key('tutorial-language')))
            .value,
        'de',
        reason: 'the sheet did not redraw with what was picked',
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('phone-title')), 'Rooks');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('phone-save')));
      await tester.pumpAndSettle();

      expect(api.saves, hasLength(1), reason: 'nothing was saved');
      expect(api.saves.single['tags'], ['endgame', 'rook']);
      expect(api.saves.single['language'], 'de');
      await close(tester);
    });
  }

  testWidgets('the sheet shows what the tutorial already says', (tester) async {
    // Opened a second time, the fields hold what was typed the first time —
    // the same controller the desktop's fields use, not a copy made per sheet.
    await openPhone(tester, const Size(360, 640));
    await openDetails(tester);
    await tester.enterText(
        find.byKey(const Key('tutorial-labels')), 'opposition');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await openDetails(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('tutorial-labels')))
          .controller
          ?.text,
      'opposition',
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await close(tester);
  });
}
