// Saving an analysis under a name that is already taken — item 4 of the
// owner's review of 21.9.2026, from TODO-provera 201.9:
//
//   „Kada se čuva analiza i ako staviš isto ime kao već sačuvana, treba da se
//   pita da li hoću da je pregazim. Ovako se snima preko postojeće bez glasa."
//
// Measured before building: the server never overwrote anything — `POST
// /analysis` only inserts — so the same name made a second row that looked
// exactly like the first. Now the one save door both screens use
// (`promptSaveAnalysisDialog`, Analysis and Preparation alike) asks
// „Replace / Keep both" when the name is taken, and „Replace" writes over
// that row through `PUT /analysis/:id`.
//
// Every assertion reads the requests (rule 7): what matters is which of POST
// and PUT reached the server, and with what.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/analysis_studio/dialogs/analysis_studio_dialogs.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

class _Server {
  _Server({this.refuseReplace = false});

  final bool refuseReplace;
  final List<http.Request> requests = [];

  /// What the account already has: „Najdorf" is taken.
  static final _saved = [
    {
      'id': 31,
      'title': 'Najdorf',
      'starting_fen': _start,
      'created_at': '2026-09-20T10:00:00Z',
    },
    {
      'id': 32,
      'title': 'Caro-Kann',
      'starting_fen': _start,
      'created_at': '2026-09-19T10:00:00Z',
    },
  ];

  http.Client client() => MockClient((req) async {
        requests.add(req);
        if (req.method == 'GET' && req.url.path == '/analysis') {
          return http.Response(jsonEncode(_saved), 200);
        }
        if (req.method == 'POST' && req.url.path == '/analysis') {
          final body = jsonDecode(req.body) as Map;
          return http.Response(
              jsonEncode({
                'id': 40,
                'title': body['title'],
                'starting_fen': body['startingFen'],
                'created_at': '2026-09-21T10:00:00Z',
              }),
              201);
        }
        if (req.method == 'PUT' && req.url.path == '/analysis/31') {
          if (refuseReplace) return http.Response('{"error":"x"}', 500);
          final body = jsonDecode(req.body) as Map;
          return http.Response(
              jsonEncode({
                'id': 31,
                'title': body['title'],
                'starting_fen': body['startingFen'],
                'created_at': '2026-09-20T10:00:00Z',
              }),
              200);
        }
        return http.Response('{}', 404);
      });

  List<String> writes() => [
        for (final r in requests)
          if (r.method == 'POST' || r.method == 'PUT')
            '${r.method} ${r.url.path}',
      ];

  Map<String, dynamic> bodyOf(String method) =>
      jsonDecode(requests.lastWhere((r) => r.method == method).body)
          as Map<String, dynamic>;
}

AnalysisNode _tree() {
  final root = AnalysisNode(fen: _start);
  root.addChild(
    childFen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
    san: 'e4',
    uci: 'e2e4',
  );
  return root;
}

Future<_Server> _saveAs(WidgetTester tester, String title,
    {bool refuseReplace = false}) async {
  final server = _Server(refuseReplace: refuseReplace);
  AnalysisPersistenceService.setInstance(
      AnalysisPersistenceService.withClient(server.client()));
  addTearDown(AnalysisPersistenceService.resetInstance);

  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: Scaffold(
      body: Builder(
        builder: (context) => FilledButton(
          key: const Key('open-save'),
          onPressed: () => promptSaveAnalysisDialog(
            context,
            rootNode: _tree(),
            userSession: UserSession(
                token: 'tok', id: 5, email: 'e', name: 'N', role: 'trener'),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.byKey(const Key('open-save')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), title);
  await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
  await tester.pumpAndSettle();
  return server;
}

void main() {
  testWidgets('a new name is saved at once, with no question', (tester) async {
    final server = await _saveAs(tester, 'Sveshnikov');
    expect(find.text('Replace'), findsNothing);
    expect(server.writes(), ['POST /analysis']);
    expect(server.bodyOf('POST')['title'], 'Sveshnikov');
  });

  testWidgets('a taken name asks first, and nothing is written yet',
      (tester) async {
    final server = await _saveAs(tester, 'Najdorf');
    expect(find.textContaining('already exists'), findsOneWidget,
        reason: 'the same name was saved without a word');
    expect(server.writes(), isEmpty,
        reason: 'something was written before the trainer answered');
  });

  testWidgets('„Replace" writes over that analysis, and makes no second one',
      (tester) async {
    final server = await _saveAs(tester, 'Najdorf');
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();

    expect(server.writes(), ['PUT /analysis/31']);
    final body = server.bodyOf('PUT');
    expect(body['title'], 'Najdorf');
    expect(body['startingFen'], _start);
    expect((body['tree'] as Map)['children'], hasLength(1),
        reason: 'the tree that was replaced in is not the one on the board');
    expect(find.textContaining('replaced'), findsOneWidget);
  });

  testWidgets('„Keep both" saves a second one, as before', (tester) async {
    final server = await _saveAs(tester, 'Najdorf');
    await tester.tap(find.text('Keep both'));
    await tester.pumpAndSettle();
    expect(server.writes(), ['POST /analysis']);
  });

  testWidgets('„Cancel" writes nothing at all', (tester) async {
    final server = await _saveAs(tester, 'Najdorf');
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(server.writes(), isEmpty);
  });

  testWidgets('the name is the same name whatever its case or spaces',
      (tester) async {
    // „najdorf " and „Najdorf" read as one name to a person, and would sit
    // side by side in the Library looking like one.
    final server = await _saveAs(tester, '  najdorf ');
    expect(find.textContaining('already exists'), findsOneWidget);
    expect(server.writes(), isEmpty);
  });

  testWidgets('a refused replace says so, not „saved"', (tester) async {
    final server = await _saveAs(tester, 'Najdorf', refuseReplace: true);
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(server.writes(), ['PUT /analysis/31']);
    expect(find.textContaining('failed'), findsOneWidget);
    expect(find.textContaining('replaced'), findsNothing);
  });
}
