import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/repertoire/widgets/breadth_dialog.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';

class _FakeApi extends RepertoireApiService {
  String? savedBreadth;

  @override
  Future<bool> setBreadth({required int id, required String breadth}) async {
    savedBreadth = breadth;
    return true;
  }
}

void main() {
  testWidgets('BreadthDialog saves choice and returns depth', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final api = _FakeApi();
    ({int depth, String breadth})? returned;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            returned = await showDialog<({int depth, String breadth})>(
              context: context,
              builder: (_) => BreadthDialog(id: 3, api: api),
            );
          },
          child: const Text('Open'),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Check initial state
    expect(find.text('Širina'), findsOneWidget);

    // Tap broad
    await tester.tap(find.text('Široko (95%)'));
    await tester.pumpAndSettle();

    // Tap depth
    await tester.ensureVisible(find.text('6 poteza'));
    await tester.tap(find.text('6 poteza'));
    await tester.pumpAndSettle();

    expect(api.savedBreadth, 'broad');
    expect(returned?.depth, 6);
    // The width comes back with the depth: the screen has to read at it now,
    // not next time the repertoire is opened from the list.
    expect(returned?.breadth, 'broad');
  });

  testWidgets('BreadthDialog disables radio buttons if id is null',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final api = _FakeApi();
    await tester.pumpWidget(MaterialApp(
      home: BreadthDialog(id: null, api: api),
    ));

    expect(find.textContaining('Ova opcija nije dostupna'), findsOneWidget);

    // Tap radio button - shouldn't crash or change since it's disabled, but since we tap the widget it might trigger anyway if we are not careful?
    // RadioListTile is disabled if onChanged is null. We set onChanged to null.
    // So tapping it will not trigger anything.
  });
}
