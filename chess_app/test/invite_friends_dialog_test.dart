import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The invite dialog inside a lesson, and the two lines that made it useless.
///
/// Reported live on 25.8.2026: *"zašto dok sam u sesiji ne mogu nikog da
/// pozovem?"* — the dialog said **Nemate sačuvanih prijatelja** to a trainer
/// sitting in a room with two accepted students. Nothing was refused and
/// nothing was empty; the answer was simply never read.
///
/// ```dart
/// friendsList = jsonDecode(res.body);   // the route answers { "friends": [...] }
/// } catch (e) {
///   // quiet fail
/// }
/// ```
///
/// `GET /friends` returns an object. Decoding it into a `List<dynamic>` threw a
/// TypeError on every call there has ever been, and the catch underneath
/// swallowed it — so a failure to *read* the list came out as a list that is
/// empty. Same shape as everything else this project keeps paying for: "I could
/// not ask" arriving as "there is nobody", with `home_screen.dart` reading the
/// very same endpoint correctly four hundred lines away.
void main() {
  final source = File('lib/screens/chess_game_screen.dart').readAsStringSync();

  /// The dialog's body, matched by braces rather than by slicing a fixed
  /// number of characters — the guard written that way in this repo ran into
  /// the next function and kept passing after the check it watched was gone.
  String bodyOf(String needle) {
    final start = source.indexOf(needle);
    if (start == -1) throw StateError('nije nađeno u izvoru: $needle');
    final open = source.indexOf('{', start);
    var depth = 0;
    for (var i = open; i < source.length; i++) {
      if (source[i] == '{') depth++;
      if (source[i] == '}') {
        depth--;
        if (depth == 0) return source.substring(start, i + 1);
      }
    }
    throw StateError('nezatvorena zagrada posle: $needle');
  }

  final dialog = bodyOf('void _showInSessionInviteFriendsDialog()');

  test('the dialog body was actually found, or the rest proves nothing', () {
    expect(dialog.length, greaterThan(400));
    expect(dialog, contains('/friends'));
  });

  test('the answer is unwrapped, not decoded straight into a list', () {
    expect(dialog, contains("['friends']"),
        reason: 'ruta vraća { "friends": [...] } — bez raspakivanja lista je '
            'uvek prazna, ma koliko učenika trener imao');
  });

  test('a spisak that could not be loaded does not read as an empty one', () {
    expect(dialog, contains('loadError'),
        reason: '„nisam mogao da pitam" ne sme da izađe kao „nemate nikoga"');
    expect(dialog, isNot(contains('// quiet fail')),
        reason: 'tiho gutanje greške je baš kvar zbog koga ovaj test postoji');
  });
}
