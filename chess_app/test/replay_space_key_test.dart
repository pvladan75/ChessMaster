import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Space plays and pauses the recording, and it presses a button that is on the
/// screen.
///
/// Read as text rather than pumped, and that is a compromise worth naming: the
/// replay screen fetches the lesson over HTTP from `initState` with no way to
/// hand it a stub, so a widget test of it would be a test of a failed fetch.
/// What can still be checked is the rule the whole set of shortcuts rests on —
/// the key calls the same handler the button under the board calls, so the two
/// cannot drift into two behaviours. The wrapper's own behaviour, including
/// standing aside for a focused button, is tested in
/// `action_key_shortcuts_test.dart`.
void main() {
  test('the space key and the play button call the same handler', () {
    final source =
        File('lib/screens/replay_player_screen.dart').readAsStringSync();

    expect(source.contains('ActionKeyShortcuts'), isTrue,
        reason: 'ekran sa snimkom više ne veže nijedan taster');

    final bound = RegExp(r'LogicalKeyboardKey\.space:[^,]*?(_\w+)')
        .firstMatch(source)
        ?.group(1);
    expect(bound, isNotNull, reason: 'razmak nije vezan ni za šta');

    final buttons = RegExp(r'onPressed:\s*(_\w+)')
        .allMatches(source)
        .map((m) => m.group(1))
        .toSet();

    expect(buttons, contains(bound),
        reason: 'razmak zove $bound, a ispod table nema dugmeta koje zove isto '
            '— prečica ne sme da bude jedini put do radnje');
  });
}
