// The trainer's orientation, from the studio to the child.
//
// Reported live on 7.9.2026: the board turned over between parts of one
// tutorial. Two faults, one on each side of the wire. The part *did* remember
// which way round it stood, but `TutorialSection.toJson` never sent it, so the
// child's viewer fell back to working it out from whose turn it was — and the
// screen wrote the orientation it happened to be showing into whichever part
// was opened, so the stored choice of the part being opened was overwritten
// before anyone could save it.
//
// It asserts on the request. „The board looks right" is not evidence that
// anything left the screen — the P7a lesson.

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

class _RecordingApi extends LessonApiService {
  _RecordingApi._(this.saves, http.Client client)
      : super(authToken: 'tok', client: client);

  final List<Map<String, dynamic>> saves;

  factory _RecordingApi() {
    final saves = <Map<String, dynamic>>[];
    return _RecordingApi._(
      saves,
      MockClient((req) async {
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  const endgameFen = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';
  const blackToMove = '6k1/5ppp/8/8/8/8/5PPP/R5K1 b - - 0 1';

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

  Map<String, dynamic> lessonOf(List<Map<String, dynamic>> steps) => {
        'id': 41,
        'title': 'Otvaranje',
        'position_list': steps,
      };

  Future<_RecordingApi> open(
      WidgetTester tester, List<Map<String, dynamic>> steps) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final api = _RecordingApi();
    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.saved(lessonOf(steps)),
        lessonApi: api,
      ),
    ));
    await tester.pumpAndSettle();
    return api;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> flip(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Okreni tablu').first);
    await tester.pumpAndSettle();
  }

  Future<List<dynamic>> save(WidgetTester tester, _RecordingApi api) async {
    await tester.tap(find.text('Save tutorial'));
    await tester.pumpAndSettle();
    expect(api.saves, hasLength(1), reason: 'one tutorial is one write');
    return api.saves.single['positionList'] as List;
  }

  testWidgets('the way round the trainer left the board is sent',
      (tester) async {
    final api = await open(tester, [
      {'fen': startFen, 'title': 'Deo 1', 'kind': 'show'},
    ]);

    await flip(tester);
    final sent = await save(tester, api);

    expect((sent.single as Map)['blackOrientation'], isTrue);

    await close(tester);
  });

  testWidgets('and „white" is sent as a decision, not left out',
      (tester) async {
    // The viewer reads an absent field as „nobody said, guess from the side to
    // move". A trainer who left a black-to-move position the white way round
    // has said something, and it has to travel.
    final api = await open(tester, [
      {'fen': startFen, 'title': 'Deo 1', 'kind': 'show'},
    ]);

    final sent = await save(tester, api);

    expect((sent.single as Map)['blackOrientation'], isFalse);

    await close(tester);
  });

  testWidgets('each part keeps its own, across a visit to another part',
      (tester) async {
    final api = await open(tester, [
      {'fen': startFen, 'title': 'Deo 1', 'kind': 'show'},
      {'fen': endgameFen, 'title': 'Deo 2', 'kind': 'show'},
    ]);

    // Part one is turned round, part two is left alone.
    await flip(tester);
    await tester.tap(find.text('Deo 2'));
    await tester.pumpAndSettle();

    final sent = await save(tester, api);

    expect((sent.first as Map)['blackOrientation'], isTrue,
        reason: 'opening another part wrote its orientation over this one');
    expect((sent.last as Map)['blackOrientation'], isFalse,
        reason: 'the part being opened inherited the screen instead of '
            'restoring what it had stored');

    await close(tester);
  });

  testWidgets('a part added after this one starts the same way round',
      (tester) async {
    // „Novi prikaz" → „Odavde" continues the part in front of it, and the
    // child crosses that join without the pieces being reloaded — so a board
    // that flips at the join is the one thing the join exists to prevent. The
    // trainer met it the other way round: they turned the board, added a part,
    // and White was at the bottom again. Reported live on 7.9.2026.
    final api = await open(tester, [
      {'fen': startFen, 'title': 'Deo 1', 'kind': 'show'},
    ]);

    await flip(tester);
    await tester.tap(find.text('New demonstration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('From here'));
    await tester.pumpAndSettle();

    final sent = await save(tester, api);

    expect(sent, hasLength(2));
    expect((sent.last as Map)['blackOrientation'], isTrue,
        reason: 'the new part came up the other way round from the one it '
            'continues');

    await close(tester);
  });

  testWidgets('and so does one started on a board of its own', (tester) async {
    // Somebody writing from Black's side is still writing from Black's side on
    // the next diagram.
    final api = await open(tester, [
      {'fen': startFen, 'title': 'Deo 1', 'kind': 'show'},
    ]);

    await flip(tester);
    await tester.tap(find.text('New demonstration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New board'));
    await tester.pumpAndSettle();

    final sent = await save(tester, api);

    expect((sent.last as Map)['blackOrientation'], isTrue);

    await close(tester);
  });

  testWidgets('a saved orientation comes back when the tutorial is reopened',
      (tester) async {
    final api = await open(tester, [
      {
        'fen': startFen,
        'title': 'Deo 1',
        'kind': 'show',
        'blackOrientation': true,
      },
    ]);

    final sent = await save(tester, api);

    expect((sent.single as Map)['blackOrientation'], isTrue,
        reason: 'reopening and saving without touching anything turned the '
            'board back round');

    await close(tester);
  });

  group('a part written before the field existed', () {
    // The one direction that could quietly change a child's screen: the studio
    // sends the field on every save, so an old tutorial reopened and saved
    // without being touched would tell the viewer something it had never been
    // told. What it tells it has to be what the viewer was already doing.

    test('adopts the guess the viewer was already making', () {
      final section = TutorialSection.fromStep({
        'id': 'aaaa1111',
        'title': 'Deo 1',
        'fen': blackToMove,
      });

      expect(section.blackOrientation, isTrue);
      expect(section.toJson()['blackOrientation'], isTrue,
          reason: 'reading absence as „White" turns every black-to-move part '
              'of every old tutorial round on the next save');
    });

    test('and a stored „false" is still obeyed', () {
      final section = TutorialSection.fromStep({
        'id': 'aaaa2222',
        'title': 'Deo 1',
        'fen': blackToMove,
        'blackOrientation': false,
      });

      expect(section.blackOrientation, isFalse);
    });
  });
}
