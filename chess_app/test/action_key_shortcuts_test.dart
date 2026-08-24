import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/widgets/action_key_shortcuts.dart';

/// The single keys that press a button the screen is already showing.
///
/// Three things are worth holding, and each of them is a fault this project has
/// already paid for once. That a key works on a freshly opened screen, before
/// anything has been clicked. That a key with nothing behind it is *declined*
/// rather than swallowed, so whoever else wants it still gets it — Ctrl+C took
/// copying away from every text field in the app by being a callback instead of
/// an action. And that a letter belongs to the text field while one is being
/// typed into.
void main() {
  late int pressed;
  late int outer;

  /// The wrapper under an outer binding for the same keys. If the wrapper
  /// swallows a key it had nothing to do with, [outer] stays at zero and that
  /// is exactly what the test is looking for.
  Future<void> pump(
    WidgetTester tester, {
    required bool offered,
    bool withField = false,
    bool withButton = false,
  }) async {
    pressed = 0;
    outer = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyN): () => outer++,
            const SingleActivator(LogicalKeyboardKey.space): () => outer++,
          },
          child: ActionKeyShortcuts(
            bindings: {
              LogicalKeyboardKey.keyN: offered ? () => pressed++ : null,
              LogicalKeyboardKey.space: offered ? () => pressed++ : null,
            },
            child: Column(
              children: [
                if (withField) const TextField(),
                if (withButton)
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('dugme'),
                  ),
                const Text('tabla'),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('the key works before anything has been clicked', (tester) async {
    await pump(tester, offered: true);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pump();

    expect(pressed, 1);
    expect(outer, 0, reason: 'taster je odrađen ovde i ne putuje dalje');
  });

  testWidgets('a key whose button is not on the screen is passed on',
      (tester) async {
    await pump(tester, offered: false);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pump();

    expect(pressed, 0);
    expect(outer, 1,
        reason: 'odbijen taster mora da putuje dalje, a ne da nestane');
  });

  testWidgets('a text field keeps its letters while it has the focus',
      (tester) async {
    await pump(tester, offered: true, withField: true);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pump();

    expect(pressed, 0, reason: 'dok se kuca, slovo pripada polju');
  });

  testWidgets('space belongs to the button that has the focus', (tester) async {
    // Somebody walking the screen with Tab has to be able to press what they
    // landed on. The letters have no such rival; space does.
    await pump(tester, offered: true, withButton: true);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(pressed, 1, reason: 'dok ništa drugo ne drži fokus, razmak je naš');

    Focus.of(tester.element(find.text('dugme'))).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(pressed, 1, reason: 'fokusirano dugme samo odgovara na razmak');
  });
}
