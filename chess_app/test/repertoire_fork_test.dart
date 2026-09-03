import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/widgets/fork_repertoire_dialog.dart';

/// The Ruy Lopez after 3.Bb5, Black to move — the position forked from.
const ruyLopez =
    'r1bqkbnr/pppp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3';

/// The real service over a client that answers, and writes down every request
/// it was given.
///
/// Deliberately **not** a fake with `create` overridden: the property worth
/// proving is that a fork writes no move, and a fake that intercepts one method
/// says nothing about the calls it does not intercept. Every request the dialog
/// causes lands in [seen], so a `keepMove` added tomorrow fails this test.
class _RecordingApi extends RepertoireApiService {
  _RecordingApi._(this.seen, http.Client client) : super(client: client);

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
        return http.Response(
          jsonEncode({
            'id': 99,
            'name': 'novo',
            'color': 'w',
            'rootFen': ruyLopez,
            'moves': 0,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  final List<({String method, String path, Map<String, dynamic> body})> seen;
}

/// The book without its asset: `OpeningBookService` loads through `compute()`,
/// which never completes inside `testWidgets`.
class _FakeBook extends OpeningBookService {
  _FakeBook({this.entry}) : super.test();

  final OpeningBookEntry? entry;

  @override
  OpeningBookEntry? lookupByFen(String fen) => entry;
}

Future<void> _open(
  WidgetTester tester, {
  required RepertoireApiService api,
  required OpeningBookService book,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ForkRepertoireDialog(
        color: 'w',
        rootFen: ruyLopez,
        rootPath: const ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5'],
        api: api,
        openingBook: book,
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('the name is prefilled from the opening book', (tester) async {
    await _open(
      tester,
      api: _RecordingApi(),
      book: _FakeBook(
        entry: OpeningBookEntry(
            eco: 'C60', name: 'Ruy Lopez', pgn: '1. e4 e5 2. Nf3 Nc6 3. Bb5'),
      ),
    );

    expect(find.text('C60 · Ruy Lopez'), findsOneWidget);
  });

  testWidgets('a position the book cannot name leaves the field empty',
      (tester) async {
    await _open(tester, api: _RecordingApi(), book: _FakeBook());

    // Empty and honest, rather than a name invented from the SAN path.
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty);
  });

  testWidgets('a fork creates a row and writes no move', (tester) async {
    final api = _RecordingApi();
    await _open(
      tester,
      api: api,
      book: _FakeBook(
          entry: OpeningBookEntry(eco: 'C60', name: 'Ruy Lopez', pgn: '')),
    );

    await tester.tap(find.text('Izdvoji'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The whole of it: one request, and it is the door.
    expect(api.seen.length, 1);
    expect(api.seen.single.method, 'POST');
    expect(api.seen.single.path, endsWith('/repertoire'));
    expect(api.seen.single.body['rootFen'], ruyLopez);
    expect(api.seen.single.body['rootPath'],
        const ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
    expect(api.seen.single.body['color'], 'w');
    expect(api.seen.single.body['name'], 'C60 · Ruy Lopez');
    // No gate was chosen, so none is sent.
    expect(api.seen.single.body.containsKey('viaUci'), isFalse);
  });

  testWidgets('an empty name creates nothing', (tester) async {
    final api = _RecordingApi();
    await _open(tester, api: api, book: _FakeBook());

    await tester.tap(find.text('Izdvoji'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.seen, isEmpty);
  });
}
