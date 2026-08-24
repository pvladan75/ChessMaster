import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/screens/shortcuts_screen.dart';

/// The page that makes every other shortcut findable.
///
/// Two things are worth holding here. That the list draws on the narrowest
/// phone, because a release build clips an overflowing row without a word of
/// warning and half a line would simply not be there. And that what it claims
/// is what the app answers — the list is only useful while it is true.
void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ShortcutsScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('every shortcut in the list is on the screen', (tester) async {
    // Tall on purpose: a ListView builds what it can show, and a group that
    // scrolled off the bottom would read as a group that is missing.
    await pumpAt(tester, const Size(1200, 2400));

    for (final group in kShortcutGroups) {
      expect(find.text(group.title), findsOneWidget);
      for (final shortcut in group.shortcuts) {
        expect(find.text(shortcut.what), findsOneWidget,
            reason: 'nedostaje: ${shortcut.what}');
        for (final key in shortcut.keys) {
          expect(find.text(key), findsWidgets,
              reason: 'nedostaje taster: $key');
        }
      }
    }
  });

  testWidgets('the list fits a 360 dp phone without overflowing',
      (tester) async {
    // In a test build an overflow throws; in a release build it is silently
    // clipped. That difference is why this size is written down.
    await pumpAt(tester, const Size(360, 640));

    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('every key the app binds is written down here', () {
    // The page and the bindings are two lists that have to agree, and nothing
    // in Dart makes them. A key added to a screen and left out of the page is a
    // key nobody will ever find — which is the whole reason the page exists, so
    // it is read out of the sources that do the binding.
    const label = {
      'escape': 'Esc',
      'comma': ',',
      'f1': 'F1',
      'arrowLeft': '←',
      'arrowRight': '→',
      'arrowUp': '↑',
      'arrowDown': '↓',
      'home': 'Home',
      'end': 'End',
      'keyC': 'C',
      'digit1': '1',
      'digit2': '2',
      'digit3': '3',
      'digit4': '4',
      'keyN': 'N',
      'keyR': 'R',
      'keyH': 'H',
      'keyT': 'T',
      'keyU': 'U',
      'space': 'Razmak',
      'equal': '+',
      'numpadAdd': '+',
      'minus': '−',
      'numpadSubtract': '−',
    };

    // Every source, and not a list of the files that bind keys today. That
    // list was three files long and already wrong: the move tree binds + and
    // − and neither was on the page, because the file that grew a shortcut was
    // never added to it. A test that has to be maintained to keep working is
    // exactly the thing it was written to replace.
    const wrapper = 'lib/widgets/action_key_shortcuts.dart';
    expect(File(wrapper).existsSync(), isTrue,
        reason: 'izuzeti fajl je preimenovan — proveriti zašto je izuzet');

    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        // The wrapper names the keys it *stands aside* for — space and Enter
        // belong to whatever button has the focus — and binds none of its own.
        // The keys it presses are named by the screens that use it.
        .where((f) => !f.path.endsWith('action_key_shortcuts.dart'))
        .map((f) => f.readAsStringSync())
        .join('\n');

    final bound = RegExp(r'LogicalKeyboardKey\.(\w+)')
        .allMatches(sources)
        .map((m) => m[1]!)
        // Control appears as the modifier on a chord, not as a key of its own.
        .where((key) => !key.startsWith('control'))
        .toSet();

    final listed = {
      for (final group in kShortcutGroups)
        for (final shortcut in group.shortcuts) ...shortcut.keys,
    };

    expect(bound.length, greaterThan(4),
        reason:
            'nijedan taster nije pročitan iz izvora — test ništa ne dokazuje');

    final missing = [
      for (final key in bound)
        if (!listed.contains(label[key] ?? key)) key,
    ];

    expect(missing, isEmpty,
        reason: 'ovi tasteri su vezani u kodu, a nisu na spisku prečica: '
            '${missing.join(', ')}');
    expect(listed, contains('Ctrl'));
  });
}
