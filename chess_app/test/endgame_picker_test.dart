import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/endgame_trainer/models/endgame_puzzle.dart'
    show EndgameMode;
import 'package:chess_app/features/endgame_trainer/screens/endgame_picker_screen.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_api_service.dart';
import 'package:chess_app/models/user_session.dart';

class _FakeApi extends EndgameApiService {
  _FakeApi(this.catalog) : super(authToken: '');

  final EndgameCatalog? catalog;

  @override
  Future<EndgameCatalog?> fetchCatalog({
    EndgameMode? mode,
    bool includeOnline = false,
  }) async =>
      catalog;
}

EndgameCatalog catalog() => EndgameCatalog.fromJson({
      'families': [
        {
          'id': 'rooks',
          'name': 'Topovske završnice',
          'count': 1769,
          'endings': [
            {
              'material': 'KRPPvKR',
              'label': 'top i dva pešaka protiv topa',
              'count': 945,
              'bands': {'b2200': 500, 'b2000': 445},
            },
            {
              'material': 'KRPvKR',
              'label': 'top i pešak protiv topa',
              'count': 824,
              'bands': {'b2200': 300, 'b2000': 524},
            },
          ],
        },
        {
          'id': 'pawns',
          'name': 'Pešačke završnice',
          'count': 146,
          'endings': [
            {
              'material': 'KPPvKP',
              'label': 'dva pešaka protiv pešaka',
              'count': 146,
              'bands': {'b2000': 146},
            },
          ],
        },
      ],
      'bands': [
        {'id': 'b2000', 'name': '2000 - 2200'},
        {'id': 'b2200', 'name': '2200 - 2400'},
      ],
      'oppositeBishops': 0,
    });

Widget wrap(Widget child) => MaterialApp(home: child);

Widget picker({
  EndgameCatalog? withCatalog,
  void Function(EndgameChoice)? onStart,
}) =>
    EndgamePickerScreen(
      session: UserSession(
          token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik'),
      mode: EndgameMode.draw,
      api: _FakeApi(withCatalog ?? catalog()),
      onStart: onStart ?? (_) {},
    );

void main() {
  // Until 30.9.2026 the picker opened with everything ticked and its biggest
  // family open, and these cases held that. The owner asked for the opposite
  // — nothing ticked, every family shut — so they were rewritten in the open:
  // each now starts from nothing and ticks what it needs.

  testWidgets('opens with nothing chosen and every family shut',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(picker()));
    await tester.pumpAndSettle();

    expect(find.text('Topovske završnice'), findsOneWidget);
    expect(find.text('Pešačke završnice'), findsOneWidget);
    // Shut: the shapes under a family are not drawn.
    expect(find.text('top i dva pešaka protiv topa'), findsNothing);
    expect(find.byIcon(Icons.expand_less), findsNothing);
    // Nothing ticked, so nothing to start.
    final boxes = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(boxes, hasLength(2));
    expect(boxes.every((b) => b.value == false), isTrue,
        reason: 'a family opened ticked');
    expect(find.textContaining('No positions match'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('ticking a family adds its positions to the total',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(picker()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pešačke završnice'));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 146 positions'), findsOneWidget);

    await tester.tap(find.text('Topovske završnice'));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 1915 positions'), findsOneWidget);
  });

  testWidgets('a level narrows the total without another request',
      (tester) async {
    // The counts arrive split by band precisely so this addition happens here.
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(picker()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Topovske završnice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pešačke završnice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2200 - 2400'));
    await tester.pumpAndSettle();

    expect(find.text('Selected: 800 positions'), findsOneWidget);
  });

  testWidgets('an emptied choice cannot be started', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(picker()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Topovske završnice'));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 1769 positions'), findsOneWidget);
    await tester.tap(find.text('Topovske završnice'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No positions match'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('a full choice sends no filter, a partial one sends the keys',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    EndgameChoice? chosen;
    await tester.pumpWidget(wrap(picker(onStart: (choice) => chosen = choice)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Topovske završnice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pešačke završnice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(chosen!.materialsParam, isNull,
        reason: 'sve izabrano = bez filtera');

    await tester.tap(find.text('Pešačke završnice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(chosen!.materialsParam, 'KRPPvKR,KRPvKR');
  });

  testWidgets('an unreachable catalog says so and offers to try again',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(picker(
      withCatalog: const EndgameCatalog(families: [], bands: []),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
