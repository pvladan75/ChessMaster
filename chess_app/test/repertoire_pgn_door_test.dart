/// The door to the repertoire's PGN export.
///
/// `repertoire_pgn_export_test.dart` holds what the file says; this holds that
/// there is a way to ask for one. A capability that exists at every layer and
/// is reachable from nowhere the user goes is a capability they do not have —
/// which this repository has now met with the arrows nothing wrote, the branch
/// sheet nobody could open, and the delete that lived one screen away from
/// every list of tutorials.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/analysis_studio/services/pgn_file_saver.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_list_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
const _afterE5 =
    'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2';

class _Api extends RepertoireApiService {
  _Api({this.tree, this.written = const {}})
      : super(client: MockClient((_) async => http.Response('{}', 200)));

  final RepertoireTree? tree;
  final Map<String, RepertoireComment> written;

  /// What the export asked the server for.
  int? askedForPly;
  String? askedForColor;

  @override
  Future<List<RepertoireSummary>> list() async => const [
        RepertoireSummary(
            id: 3, name: 'King\'s Pawn', color: 'w', rootFen: _start, moves: 2),
      ];

  @override
  Future<RepertoireTree?> repertoireTree({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int maxPly = 16,
    String? gateUci,
  }) async {
    askedForPly = maxPly;
    askedForColor = color;
    return tree;
  }

  @override
  Future<Map<String, RepertoireComment>> comments({
    required String color,
  }) async =>
      written;
}

RepertoireTree _oneLine({bool truncated = false}) => RepertoireTree(
      rootFen: _start,
      children: [
        RepertoireTreeMove(
          uci: 'e2e4',
          san: 'e4',
          fen: _afterE4,
          mine: true,
          role: 'primary',
          children: [
            RepertoireTreeMove(
              uci: 'e7e5',
              san: 'e5',
              fen: _afterE5,
              mine: false,
              share: 0.4,
              state: 'open',
            ),
          ],
        ),
      ],
      maxPly: 40,
      truncated: truncated,
    );

Future<void> _pump(WidgetTester tester, _Api api) async {
  tester.view.physicalSize = const Size(500, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(MaterialApp(home: RepertoireListScreen(api: api)));
  await tester.pumpAndSettle();
}

Future<void> _export(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Export as PGN'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => debugSavePgnFile = null);

  testWidgets('a repertoire can be exported from the list it lives on',
      (tester) async {
    final api = _Api(tree: _oneLine());
    await _pump(tester, api);

    await _export(tester);

    expect(find.text('Exported PGN Text'), findsOneWidget);
    expect(find.textContaining('1. e4 e5'), findsOneWidget);
  });

  testWidgets('the file is named after the repertoire', (tester) async {
    String? name;
    String? text;
    debugSavePgnFile = ({required fileName, required pgn}) async {
      name = fileName;
      text = pgn;
      return r'C:\openings\kings-pawn.pgn';
    };
    await _pump(tester, _Api(tree: _oneLine()));

    await _export(tester);
    await tester.tap(find.byKey(const Key('export-pgn-save-file')));
    await tester.pumpAndSettle();

    expect(name, 'King\'s-Pawn.pgn');
    expect(text, contains('[Event "Repertoire: King\'s Pawn"]'));
  });

  testWidgets('the notes written on those positions go into the file',
      (tester) async {
    // The screen's half of "comments by default". The exporter's own half is
    // in `repertoire_pgn_export_test.dart`; what this asks is whether this
    // screen reads them at all, which is a separate question and was a
    // separate line of code.
    await _pump(
      tester,
      _Api(tree: _oneLine(), written: {
        fenKeyOf(_afterE4): const RepertoireComment(
          fenKey: _afterE4,
          body: 'I meet everything with the open game.',
        ),
      }),
    );

    await _export(tester);

    expect(find.textContaining('I meet everything with the open game.'),
        findsOneWidget);
  });

  testWidgets('the whole tree is asked for, not a screen\'s worth',
      (tester) async {
    final api = _Api(tree: _oneLine());
    await _pump(tester, api);

    await _export(tester);

    expect(api.askedForPly, 40);
    expect(api.askedForColor, 'w');
  });

  testWidgets('a file the server cut short says so', (tester) async {
    await _pump(tester, _Api(tree: _oneLine(truncated: true)));

    await _export(tester);

    expect(find.textContaining('Only the first 20 moves'), findsOneWidget);
  });

  testWidgets('a repertoire with no moves is not exported as an empty file',
      (tester) async {
    await _pump(tester, _Api(tree: RepertoireTree(rootFen: _start)));

    await _export(tester);

    expect(find.text('Exported PGN Text'), findsNothing);
    expect(find.textContaining('no moves'), findsOneWidget);
  });

  testWidgets('a server that did not answer is not an empty repertoire',
      (tester) async {
    await _pump(tester, _Api(tree: null));

    await _export(tester);

    expect(find.text('Exported PGN Text'), findsNothing);
    expect(find.textContaining('did not answer'), findsOneWidget);
  });
}
