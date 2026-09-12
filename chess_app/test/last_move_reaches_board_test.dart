import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A screen that keeps track of the last move must hand it to a board.
///
/// ## Why this is read off the source
///
/// Phase 1 of `docs/PLAN-OZNAKE-NA-TABLI.md` moved the last-move marker from an
/// overlay above the pieces to a layer inside `SkinnedChessBoard`. Two
/// mutations survived the whole suite afterwards — the analysis studio and the
/// drill screen quietly not forwarding it — because neither screen is built in
/// any widget test: one needs an engine and a session, the other a route with
/// a category on it. Both are the kind of screen this repository has more than
/// once found to be testable after twenty minutes of trying, and both are worth
/// that twenty minutes; neither is worth it inside this phase.
///
/// So the invariant is asserted where it can be: **the fields and the call are
/// in the same file.** A screen that declares `_lastMoveFrom` has gone to the
/// trouble of tracking a move, and a tracked move that reaches no board is the
/// shape this plan exists to fix — five of fifteen screens drawing nothing,
/// every layer correct.
///
/// It is deliberately not "every board gets a last move": the replay player and
/// the engine-line dialog pass none on purpose, and a gate that failed them
/// would be argued with rather than satisfied.
///
/// ## How it reads
///
/// By matching parentheses, never by slicing a fixed number of characters —
/// this repository has paid for the slice twice, once at 1600 characters and
/// once at 400. Strings and line comments are blanked first, because an
/// argument list is found by counting brackets and a bracket inside a string is
/// not one.
void main() {
  /// [source] with line comments and string literals replaced by spaces of the
  /// same length, so every offset still addresses the same character.
  String blanked(String source) {
    final out = source.split('');
    var i = 0;
    while (i < out.length) {
      final ch = source[i];
      if (ch == '/' && i + 1 < source.length && source[i + 1] == '/') {
        while (i < source.length && source[i] != '\n') {
          out[i++] = ' ';
        }
        continue;
      }
      if (ch == "'" || ch == '"') {
        final quote = ch;
        out[i++] = ' ';
        while (i < source.length && source[i] != quote) {
          // A quote escaped inside a literal does not end it.
          if (source[i] == r'\' && i + 1 < source.length) out[i++] = ' ';
          if (i < source.length) out[i++] = ' ';
        }
        if (i < source.length) out[i++] = ' ';
        continue;
      }
      i++;
    }
    return out.join();
  }

  /// The argument list of every call to [name] in [source], each read to its own
  /// matching close bracket.
  List<String> callsTo(String source, String name) {
    final masked = blanked(source);
    final found = <String>[];
    var from = 0;
    while (true) {
      final at = masked.indexOf('$name(', from);
      if (at < 0) return found;
      var depth = 0;
      var i = at + name.length;
      final start = i + 1;
      for (; i < masked.length; i++) {
        if (masked[i] == '(') depth++;
        if (masked[i] == ')') {
          depth--;
          if (depth == 0) break;
        }
      }
      // An unbalanced call means the reader is broken, not the code.
      expect(i, lessThan(masked.length),
          reason: 'no matching bracket for $name( at offset $at');
      found.add(source.substring(start, i));
      from = i;
    }
  }

  Iterable<File> dartFiles(String root) sync* {
    for (final entity in Directory(root).listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) yield entity;
    }
  }

  test('a screen that tracks the last move gives it to a board', () {
    final offences = <String>[];
    var checked = 0;

    for (final file in dartFiles('lib')) {
      final source = file.readAsStringSync();
      // The field, not a mention: `_lastMoveFrom` in a comment is not tracking.
      if (!RegExp(r'^\s*String\?\s+_lastMoveFrom\s*;', multiLine: true)
          .hasMatch(source)) {
        continue;
      }
      checked++;

      final calls = [
        ...callsTo(source, 'SkinnedChessBoard'),
        ...callsTo(source, 'ChessBoardWithOverlay'),
      ];
      if (calls.isEmpty) {
        offences.add('${file.path}: tracks a last move and builds no board');
        continue;
      }
      if (!calls.any(
          (c) => c.contains('lastMoveFrom:') && c.contains('lastMoveTo:'))) {
        offences.add('${file.path}: builds a board and passes neither '
            'lastMoveFrom nor lastMoveTo to any of them');
      }
    }

    // A gate that checked nothing would pass. Five screens track a last move as
    // of 12.9.2026; the bar is left below that so adding one is not a failure,
    // and far enough above zero that a renamed field is.
    expect(checked, greaterThanOrEqualTo(4),
        reason: 'only $checked screens were found to track a last move, so the '
            'pattern this test recognises has probably been renamed and it is '
            'no longer checking anything');

    expect(offences, isEmpty,
        reason: 'a move is being tracked and never drawn:\n'
            '${offences.join('\n')}');
  });

  test('the reader itself works, on source written to break it', () {
    const sample = '''
      // SkinnedChessBoard(lastMoveFrom: 'a1', lastMoveTo: 'a2')
      final label = 'SkinnedChessBoard(lastMoveFrom: x)';
      SkinnedChessBoard(
        controller: c,
        onMove: () => log('a ) bracket in a string'),
        lastMoveFrom: from,
        lastMoveTo: to,
      );
''';
    final calls = callsTo(sample, 'SkinnedChessBoard');
    expect(calls, hasLength(1),
        reason: 'the call in the comment and the one in the string literal are '
            'not calls, and a reader that counts them would pass a file whose '
            'only real call passes nothing');
    expect(calls.single, contains('lastMoveFrom:'));
    expect(calls.single, contains('lastMoveTo:'));
  });
}
