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
  Future<EndgameCatalog?> fetchCatalog({EndgameMode? mode}) async => catalog;
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
  testWidgets('opens with everything chosen and the whole total showing',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(picker()));
    await tester.pumpAndSettle();

    // Nothing has to be ticked before the reader can do anything: pressing the
    // button straight away is what the two hub buttons used to do on their own.
    expect(find.text('Izabrano: 1915 pozicija'), findsOneWidget);
    expect(find.text('Topovske završnice'), findsOneWidget);
    // The biggest family is open, so the list does not look empty.
    expect(find.text('top i dva pešaka protiv topa'), findsOneWidget);
  });

  testWidgets('unticking a family takes its positions out of the total',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(picker()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pešačke završnice'));
    await tester.pumpAndSettle();

    expect(find.text('Izabrano: 1769 pozicija'), findsOneWidget);
  });

  testWidgets('a level narrows the total without another request',
      (tester) async {
    // The counts arrive split by band precisely so this addition happens here.
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(picker()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2200 - 2400'));
    await tester.pumpAndSettle();

    expect(find.text('Izabrano: 800 pozicija'), findsOneWidget);
  });

  testWidgets('an empty choice cannot be started', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(picker()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Topovske završnice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pešačke završnice'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nijedna pozicija'), findsOneWidget);
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

    await tester.tap(find.text('Počni'));
    await tester.pumpAndSettle();
    expect(chosen!.materialsParam, isNull,
        reason: 'sve izabrano = bez filtera');

    await tester.tap(find.text('Pešačke završnice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Počni'));
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

    expect(find.textContaining('nije dostupan'), findsOneWidget);
    expect(find.text('Pokušaj ponovo'), findsOneWidget);
  });
}
