// The words for a puzzle theme, and the themes a puzzle homework may ask for,
// held to the list the server reads (chess_backend/test/fixtures/
// puzzle_themes.json; the server's half is chess_backend/test/
// homework_themes.test.js).
//
// Found 1.10.2026: both homework dialogs offered „rook endgame" and „pawn
// endgame", which the server dropped, so such a homework went out as puzzles
// of any kind; „Assign drill" ticked a suggested weakness it drew no chip for,
// out of the trainer's reach; and six motifs the server trains had no words.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/assignments/widgets/create_assignment_dialog.dart';
import 'package:chess_app/features/homework/widgets/homework_item_pickers.dart';
import 'package:chess_app/theme/app_colors.dart';

final Map<String, dynamic> _shared = jsonDecode(
  File('../chess_backend/test/fixtures/puzzle_themes.json').readAsStringSync(),
) as Map<String, dynamic>;

List<String> _list(String key) => (_shared[key] as List).cast<String>();

/// What a puzzle homework keeps on the server: the motifs and the phases.
Set<String> get _kept => {..._list('motifs'), ..._list('phases')};

Widget _host(void Function(BuildContext) open) => MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () => open(c),
            child: const Text('open'),
          ),
        ),
      ),
    );

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// The theme of every chip on the screen, read back from its words: what the
/// trainer is offered, not a list in the code. A chip whose words are no
/// label's stays as it reads, so a failure names it.
List<String> _chipThemes(WidgetTester tester) {
  final byWords = {for (final e in themeLabels.entries) e.value: e.key};
  return tester.widgetList<FilterChip>(find.byType(FilterChip)).map((chip) {
    final words = (chip.label as Text).data!;
    return byWords[words] ?? words;
  }).toList();
}

CreateAssignmentDialog _drillDialog(
  List<String> suggested, {
  http.Client? client,
}) =>
    CreateAssignmentDialog(
      api: AssignmentApiService(authToken: 't', client: client),
      studentId: 7,
      studentName: 'Ana',
      suggestedThemes: suggested,
    );

void main() {
  test('the app has the same words as the server', () {
    expect(
      themeLabels,
      equals(Map<String, String>.from(_shared['labels'] as Map)),
    );
  });

  test('every motif the server trains has words', () {
    expect(_list('motifs').where((t) => !themeLabels.containsKey(t)), isEmpty);
  });

  testWidgets('every chip of a homework puzzle set is a theme the server keeps',
      (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_host((c) => pickPuzzleCriteria(c)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final themes = _chipThemes(tester);
    expect(themes, isNotEmpty);
    expect(themes.where((t) => !_kept.contains(t)), isEmpty);
    // The owner's choice (a), 1.10.2026: the endgame chips stay, and filter.
    expect(themes, containsAll(['rookEndgame', 'pawnEndgame']));
  });

  testWidgets('every chip of „Assign drill" is a theme the server keeps',
      (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(
      _host((c) =>
          showDialog<bool>(context: c, builder: (_) => _drillDialog(const []))),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final themes = _chipThemes(tester);
    expect(themes, isNotEmpty);
    expect(themes.where((t) => !_kept.contains(t)), isEmpty);
    expect(themes, containsAll(['rookEndgame', 'pawnEndgame']));
    // The next case stands on this: the usual chips leave zugzwang out.
    expect(themes, isNot(contains('zugzwang')));
  });

  testWidgets(
      'a suggested weakness with no chip of its own is drawn ticked, '
      'can be unticked, and the request carries what the chips show',
      (tester) async {
    _tallScreen(tester);
    final posts = <Map<String, dynamic>>[];
    final client = MockClient((req) async {
      if (req.method == 'POST' && req.url.path.endsWith('/assignments')) {
        posts.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response(
            jsonEncode({
              'assignment': {'id': 1}
            }),
            201);
      }
      return http.Response('[]', 200);
    });
    await tester.pumpWidget(
      _host((c) => showDialog<bool>(
            context: c,
            builder: (_) =>
                _drillDialog(const ['zugzwang', 'pin'], client: client),
          )),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final zugzwang = find.widgetWithText(FilterChip, 'zugzwang');
    expect(zugzwang, findsOneWidget,
        reason: 'a ticked theme the trainer cannot see cannot be unticked');
    expect(tester.widget<FilterChip>(zugzwang).selected, isTrue);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'pin'))
          .selected,
      isTrue,
    );

    await tester.ensureVisible(zugzwang);
    await tester.tap(zugzwang);
    await tester.pump();
    expect(tester.widget<FilterChip>(zugzwang).selected, isFalse);

    await tester.ensureVisible(find.text('Assign'));
    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();

    expect(posts, hasLength(1));
    expect(posts.single['themes'], ['pin']);
  });
}
