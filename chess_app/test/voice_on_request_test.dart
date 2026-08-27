import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **The microphone opens when somebody asks for it, and not before.**
///
/// Until 27.8.2026 `_initAudioChat()` was called unconditionally from
/// `initState`: entering a room fetched a token, joined the Agora channel and
/// started the meter, whether or not anyone meant to talk. From the user's log,
/// 22.8.2026 — eighteen seconds of voice billed for a session nobody spoke in.
///
/// The cost is the smaller half. The other half is that the microphone was
/// opened before anybody said they wanted a conversation, in an app whose users
/// are mostly children.
///
/// Read from the source rather than driven through the widget, because the room
/// screen needs a live socket to build and this rule is about a call that must
/// **not** happen — the easiest kind of rule to break by accident and the
/// hardest to notice, since nothing fails when it is broken. Every check here
/// was proven by mutation: remove the guard it names and it goes red.
void main() {
  final source = File('lib/screens/chess_game_screen.dart').readAsStringSync();

  /// A function body, matched by braces rather than sliced at a fixed length —
  /// the guard written that way in this repo ran past the end of its function
  /// and kept passing after the check it watched was deleted.
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

  /// A comment that names a call is not a call — and the comment in `initState`
  /// saying why the voice is *not* joined there would otherwise fail this file.
  /// Braces are matched on the raw source first: an unbalanced brace inside a
  /// comment can only make a body come out too long, which shows up as a
  /// failure rather than as a guard that quietly stops guarding.
  String withoutComments(String code) => code.split('\n').map((line) {
        final at = line.indexOf('//');
        return at == -1 ? line : line.substring(0, at);
      }).join('\n');

  final initState = withoutComments(bodyOf('void initState() {'));
  final rejoin = withoutComments(bodyOf('Future<void> _rejoinVoice() async'));

  test('the bodies were actually found, or the rest proves nothing', () {
    // The failure this repo has already paid for: a source-reading guard that
    // matched something else and passed forever.
    expect(initState.length, greaterThan(400));
    expect(initState, contains('initSocket()'));
    expect(rejoin, contains('_initAudioChat'));
  });

  test('entering a room does not enter the voice', () {
    expect(initState.contains('_initAudioChat'), isFalse,
        reason: 'ulazak u sobu nije zahtev za razgovor');
    expect(initState.contains('_joinVoice'), isFalse,
        reason: 'kanal se otvara na dugme, ne pri ulasku');
  });

  test('the voice has exactly two ways in, and both are deliberate', () {
    // `_joinVoice` (the button) and `_rejoinVoice` (a right that changed while
    // the voice was already on). A third call site is how this bug comes back.
    final callSites =
        'await _initAudioChat();'.allMatches(withoutComments(source)).length;
    expect(callSites, 2,
        reason: 'nov poziv _initAudioChat znači nov način da se mikrofon '
            'otvori bez pitanja');
  });

  test('a right that changes while the voice is off does not turn it on', () {
    // `voice_level_changed` arrives whenever the trainer grants or takes back
    // the microphone — including for somebody who never joined the voice. Left
    // ungated it would open a channel on the trainer's press, on the student's
    // device.
    expect(rejoin, contains('if (!isVoiceOn) return;'));
  });

  test('the button is the door: _joinVoice is wired to onPressed', () {
    expect(source, contains('onPressed: _joinVoice'));
    expect(source, contains('onPressed: _leaveVoice'),
        reason: 'ono što se uključuje mora moći i da se isključi');
  });

  test('the studio has no voice at all', () {
    final join = withoutComments(bodyOf('Future<void> _joinVoice() async'));
    expect(join, contains("widget.roomCode == 'STUDIO'"),
        reason: 'u studiju nema s kim da se priča, a kanal se svejedno '
            'naplaćuje');
  });
}
