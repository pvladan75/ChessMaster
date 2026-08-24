import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A screen that has the move strip has the arrow keys, read as text.
///
/// The two belong together — the strip is the buttons, the keys are the same
/// four actions without the mouse — but nothing makes them arrive together, and
/// the sixth screen is exactly where one gets forgotten. That is a silent
/// failure: the screen works, the buttons work, and only someone who reaches
/// for the keyboard finds out, on that one screen, that it does nothing.
void main() {
  /// The strip inside a dialog. A dialog takes the focus while it is open, so
  /// binding the arrows there would take them from the screen underneath, which
  /// is the one the reader is walking.
  const exempt = {'lib/widgets/engine_line_dialog.dart'};

  test('every screen with the move strip answers the arrow keys', () {
    final withStrip = <String>[];
    final withoutKeys = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (exempt.contains(path)) continue;

      final source = entity.readAsStringSync();
      if (!source.contains('MoveNavigationControls(')) continue;
      // The strip's own file, and the keyboard wrapper's, are not screens.
      if (path.endsWith('move_navigation_controls.dart')) continue;

      withStrip.add(path);
      if (!source.contains('MoveKeyboardShortcuts')) withoutKeys.add(path);
    }

    expect(withStrip.length, greaterThan(4),
        reason: 'traka nije nađena ni na pet ekrana — test ništa ne dokazuje');
    expect(withoutKeys, isEmpty,
        reason:
            'ovi ekrani imaju traku za poteze, a ne odgovaraju na strelice: '
            '${withoutKeys.join(', ')}');
  });
}
