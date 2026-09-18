// homework_editor_test.dart — the gate of phase 3's app half.
// docs/PLAN-DOMACI-ZADATAK.md §5, the trainer's homework editor.
//
// Copy into chess_app/test/ and leave it there green. Written 17.9.2026 by the
// lead, **red on master**: nothing under `lib/features/homework/` exists yet.
//
// The gate of the phase is the one rule the server already keeps and the editor
// must not break: **an item keeps its key across a reorder.** The list the
// editor sends is the list it shows, each existing item carrying the key it
// came with; positions are the server's business. A key that follows the index
// is the bug `assignment_items.step_key` and `review_items.step_key` were both
// migrated for, and a sent homework points back at these keys.
//
// Everything here asserts on the **request** rather than on a fake's answer:
// a `MockClient` replies to whatever it is handed, so a wrong body — or a
// wrong URL — is invisible unless it is read (CLAUDE.md rule 7, and the
// `/api/assignments` slip of phase 2b).
//
// What the implementer must provide, exactly:
//
//   lib/features/homework/models/homework.dart
//     enum HomeworkItemKind { lesson, positions, puzzles, engineGame }
//     String wireKindOf(HomeworkItemKind kind);      // 'lesson' … 'engine_game'
//     HomeworkItemKind? kindFromWire(String wire);   // null when unknown
//     class HomeworkItem {
//       final String? itemKey;         // null for an item not yet saved
//       final HomeworkItemKind kind;
//       final Map<String, dynamic> task;
//       final bool gate;
//       HomeworkItem copyWith({bool? gate, Map<String, dynamic>? task});
//       Map<String, dynamic> toJson();               // itemKey omitted when null
//       static HomeworkItem? fromJson(Map<String, dynamic> json);  // null when unreadable
//     }
//     class Homework {
//       final int? id; final String title; final String? instructions;
//       final List<HomeworkItem> items;
//       Map<String, dynamic> toJson();               // title, instructions, items
//       static Homework? fromJson(Map<String, dynamic> json);
//     }
//
//   lib/features/homework/services/homework_api_service.dart
//     class HomeworkApiService {
//       HomeworkApiService({required String authToken, http.Client? client});
//       Future<List<Homework>> list();
//       Future<Homework?> load(int id);
//       Future<Homework?> save(Homework homework);    // POST when id is null, else PUT
//       Future<bool> remove(int id);
//     }
//
//   lib/features/homework/screens/homework_editor_screen.dart
//     class HomeworkEditorScreen extends StatefulWidget {
//       const HomeworkEditorScreen({super.key, this.homeworkId, required this.api});
//       final int? homeworkId;  final HomeworkApiService api;
//     }
//
// The editor's controls carry these keys, so this gate can drive them:
//   Key('homework-title')                 the title field
//   Key('homework-instructions')          the instructions field
//   Key('homework-save')                  saves (POST or PUT)
//   Key('homework-item-<itemKey or new-N>')     one row
//   Key('homework-up-<itemKey or new-N>')       move it earlier
//   Key('homework-down-<itemKey or new-N>')     move it later
//   Key('homework-remove-<itemKey or new-N>')   take it out
//   Key('homework-gate-<itemKey or new-N>')     „not before the previous is done"
// where `new-N` numbers the items added in this sitting, in the order added.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/homework/models/homework.dart';
import 'package:chess_app/features/homework/screens/homework_editor_screen.dart';
import 'package:chess_app/features/homework/services/homework_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'support/landscape.dart';

/// Three saved items, as the server returns them: a tutorial, a set of
/// positions and a puzzle set, with keys that are nothing like their indexes.
Map<String, dynamic> _saved() => {
      'id': 7,
      'title': 'Thursday',
      'instructions': 'Read first, then solve.',
      'items': [
        {
          'item_key': 'ia1b2c3d4',
          'position': 0,
          'kind': 'lesson',
          'task': {'lessonId': 31},
          'gate': false,
        },
        {
          'item_key': 'ie5f6a7b8',
          'position': 1,
          'kind': 'positions',
          'task': {
            'puzzleIds': ['cust_x1', 'cust_x2']
          },
          'gate': true,
        },
        {
          'item_key': 'i90c1d2e3',
          'position': 2,
          'kind': 'puzzles',
          'task': {
            'count': 6,
            'themes': ['pin'],
            'minRating': null,
            'maxRating': null
          },
          'gate': false,
        },
      ],
    };

/// Drives the editor with a client that records every request and answers with
/// whatever the body said, so a save looks like a save.
class _Recorder {
  final List<http.Request> requests = [];

  http.Client client() => MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(jsonEncode(_saved()), 200);
        }
        return http.Response(
            jsonEncode(_saved()), request.method == 'POST' ? 201 : 200);
      });

  Map<String, dynamic>? bodyOf(String method) {
    final sent = requests.where((r) => r.method == method);
    if (sent.isEmpty) return null;
    return jsonDecode(sent.last.body) as Map<String, dynamic>;
  }

  http.Request? lastOf(String method) {
    final sent = requests.where((r) => r.method == method);
    return sent.isEmpty ? null : sent.last;
  }
}

Future<_Recorder> _open(WidgetTester tester,
    {int? homeworkId = 7, Size size = const Size(360, 800)}) async {
  final recorder = _Recorder();
  final api = HomeworkApiService(authToken: 'tok', client: recorder.client());
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: HomeworkEditorScreen(homeworkId: homeworkId, api: api),
  ));
  await tester.pumpAndSettle();
  return recorder;
}

List<String> _keysInBody(Map<String, dynamic> body) => (body['items'] as List)
    .map((i) => (i as Map<String, dynamic>)['itemKey'] as String?)
    .map((k) => k ?? '(new)')
    .toList();

void main() {
  // Real glyphs: the rows below are measured as well as searched.
  setUpAll(loadRoboto);

  group('the editor', () {
    testWidgets('opens a saved homework and shows its items in order',
        (tester) async {
      final recorder = await _open(tester);

      expect(recorder.lastOf('GET')?.url.path, endsWith('/homeworks/7'));
      expect(find.byKey(const Key('homework-item-ia1b2c3d4')), findsOneWidget);
      expect(find.byKey(const Key('homework-item-ie5f6a7b8')), findsOneWidget);
      expect(find.byKey(const Key('homework-item-i90c1d2e3')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // In the trainer's order, top to bottom.
      final first =
          tester.getRect(find.byKey(const Key('homework-item-ia1b2c3d4')));
      final second =
          tester.getRect(find.byKey(const Key('homework-item-ie5f6a7b8')));
      final third =
          tester.getRect(find.byKey(const Key('homework-item-i90c1d2e3')));
      expect(first.top, lessThan(second.top));
      expect(second.top, lessThan(third.top));
    });

    testWidgets('a reorder sends the same keys in the new order — the gate',
        (tester) async {
      final recorder = await _open(tester);

      // The last item moves to the top: two taps of „up".
      await tester.tap(find.byKey(const Key('homework-up-i90c1d2e3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('homework-up-i90c1d2e3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('homework-save')));
      await tester.pumpAndSettle();

      final body = recorder.bodyOf('PUT');
      expect(body, isNotNull, reason: 'a saved homework is saved with PUT');
      expect(recorder.lastOf('PUT')?.url.path, endsWith('/homeworks/7'));
      expect(_keysInBody(body!), ['i90c1d2e3', 'ia1b2c3d4', 'ie5f6a7b8'],
          reason: 'every key travels with its item; only the order changed');
      // No position is sent: ordering is the list, and the server numbers it.
      for (final item in body['items'] as List) {
        expect((item as Map).containsKey('position'), isFalse);
      }
    });

    testWidgets('an item taken out is simply absent, and the rest keep keys',
        (tester) async {
      final recorder = await _open(tester);

      await tester.tap(find.byKey(const Key('homework-remove-ie5f6a7b8')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('homework-save')));
      await tester.pumpAndSettle();

      expect(_keysInBody(recorder.bodyOf('PUT')!), ['ia1b2c3d4', 'i90c1d2e3']);
    });

    testWidgets('the gate switch travels per item', (tester) async {
      final recorder = await _open(tester);

      await tester.tap(find.byKey(const Key('homework-gate-ia1b2c3d4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('homework-save')));
      await tester.pumpAndSettle();

      final items = (recorder.bodyOf('PUT')!['items'] as List)
          .cast<Map<String, dynamic>>();
      final first = items.firstWhere((i) => i['itemKey'] == 'ia1b2c3d4');
      expect(first['gate'], isTrue);
      // Untouched items keep what they had: the second one gates already.
      final second = items.firstWhere((i) => i['itemKey'] == 'ie5f6a7b8');
      expect(second['gate'], isTrue);
      // „Done means solved" was a second switch; the owner removed it on
      // 18.9.2026 (`docs/PLAN-EXERCISE.md` §8.3). Nothing of it may travel.
      for (final item in items) {
        expect(item.containsKey('requireSolved'), isFalse);
      }
      expect(find.byKey(const Key('homework-solved-ia1b2c3d4')), findsNothing);
    });

    testWidgets('the title and the instructions are what was typed',
        (tester) async {
      final recorder = await _open(tester);

      await tester.enterText(find.byKey(const Key('homework-title')), 'Friday');
      await tester.enterText(find.byKey(const Key('homework-instructions')),
          'Tutorial, then two positions.');
      await tester.tap(find.byKey(const Key('homework-save')));
      await tester.pumpAndSettle();

      final body = recorder.bodyOf('PUT')!;
      expect(body['title'], 'Friday');
      expect(body['instructions'], 'Tutorial, then two positions.');
    });

    testWidgets('a homework that was never saved is created, not updated',
        (tester) async {
      final recorder = await _open(tester, homeworkId: null);

      expect(recorder.lastOf('GET'), isNull,
          reason: 'there is nothing to load');
      await tester.enterText(
          find.byKey(const Key('homework-title')), 'New one');
      await tester.tap(find.byKey(const Key('homework-save')));
      await tester.pumpAndSettle();

      expect(recorder.bodyOf('PUT'), isNull);
      final body = recorder.bodyOf('POST');
      expect(body, isNotNull, reason: 'a new homework is a POST');
      expect(recorder.lastOf('POST')?.url.path, endsWith('/homeworks'));
      expect(body!['title'], 'New one');
      expect(body['items'], isEmpty);
    });

    for (final size in [const Size(360, 800), const Size(800, 360)]) {
      testWidgets('fits at ${size.width.toInt()}×${size.height.toInt()}',
          (tester) async {
        await _open(tester, size: size);
        expect(tester.takeException(), isNull);
        // Every row's controls are on screen, not clipped past the edge.
        for (final key in ['ia1b2c3d4', 'ie5f6a7b8', 'i90c1d2e3']) {
          final row = find.byKey(Key('homework-item-$key'));
          expect(row, findsOneWidget);
          final rect = tester.getRect(row);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width + 0.01));
        }
      });
    }
  });

  group('the model', () {
    test('an item survives the round trip, key and all', () {
      final homework = Homework.fromJson(_saved())!;
      expect(homework.id, 7);
      expect(homework.items.map((i) => i.itemKey),
          ['ia1b2c3d4', 'ie5f6a7b8', 'i90c1d2e3']);
      expect(homework.items.map((i) => i.kind), [
        HomeworkItemKind.lesson,
        HomeworkItemKind.positions,
        HomeworkItemKind.puzzles,
      ]);
      expect(homework.items[1].gate, isTrue);
      expect(homework.items[1].task['puzzleIds'], ['cust_x1', 'cust_x2']);

      final wire = homework.toJson();
      expect(_keysInBody(wire), ['ia1b2c3d4', 'ie5f6a7b8', 'i90c1d2e3']);
      expect((wire['items'] as List).first, containsPair('kind', 'lesson'));
    });

    test('a new item sends no key at all, rather than an empty one', () {
      const item = HomeworkItem(
        itemKey: null,
        kind: HomeworkItemKind.engineGame,
        task: {
          'fen': '4k3/8/8/8/8/8/8/4K2R w - - 0 1',
          'side': 'w',
          'goal': 'win'
        },
        gate: false,
      );
      final wire = item.toJson();
      expect(wire.containsKey('itemKey'), isFalse);
      expect(wire['kind'], 'engine_game',
          reason: 'the wire spelling, not the enum');
    });

    test('the wire spellings are the ones the server checks', () {
      expect(wireKindOf(HomeworkItemKind.lesson), 'lesson');
      expect(wireKindOf(HomeworkItemKind.positions), 'positions');
      expect(wireKindOf(HomeworkItemKind.puzzles), 'puzzles');
      expect(wireKindOf(HomeworkItemKind.engineGame), 'engine_game');
      for (final kind in HomeworkItemKind.values) {
        expect(kindFromWire(wireKindOf(kind)), kind);
      }
      expect(kindFromWire('video'), isNull,
          reason: 'an unknown kind is refused');
    });

    test('an unreadable item is refused rather than guessed', () {
      expect(HomeworkItem.fromJson({'kind': 'video', 'task': {}}), isNull);
      expect(HomeworkItem.fromJson({'task': {}}), isNull);
      expect(Homework.fromJson({'items': []}), isNull, reason: 'no title');
    });
  });
}
