/// A sentence made of vocabulary tokens — `docs/PLAN-GOVOR-IZ-KLIPOVA.md` §2.
///
/// One list, two renderings: [text] is what the screen draws and [tokens] is
/// what the voice plays, so the sentence heard and the sentence shown are
/// equal by construction.
library;

import 'package:chess_app/core/speech/vocabulary.dart';

class SpokenLine {
  SpokenLine(Iterable<SpeechToken> tokens)
      : tokens = List<SpeechToken>.unmodifiable(tokens);

  final List<SpeechToken> tokens;

  /// The tokens' texts joined with spaces. A phrase carries its own
  /// punctuation and is never given a second one; a run of cut tokens ends
  /// with a full stop, also before a following phrase, and a cut token whose
  /// text already ends in one („lets the win go. The position is now lost.")
  /// closes the run without a second. „Check" is the one cut token that is a
  /// sentence of its own in its carrier („Black plays bishop e5. Check."), so
  /// it closes the run before it and is closed itself. Every sentence starts
  /// with a capital, because a run may open with a move („king d5 loses the
  /// draw") and the clip for „king" is the same clip either way.
  late final String text = _text();

  String _text() {
    final sentences = <String>[];
    final run = <String>[];
    void closeRun({bool stop = true}) {
      if (run.isEmpty) return;
      sentences.add(stop ? '${run.join(' ')}.' : run.join(' '));
      run.clear();
    }

    for (final token in tokens) {
      if (token.kind == SpeechTokenKind.phrase) {
        closeRun();
        sentences.add(token.text);
      } else if (token.id == 'check') {
        closeRun();
        sentences.add('${token.text}.');
      } else {
        run.add(token.text);
        if (token.text.endsWith('.')) closeRun(stop: false);
      }
    }
    closeRun();
    return sentences
        .map((s) => '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }

  @override
  bool operator ==(Object other) {
    if (other is! SpokenLine || other.tokens.length != tokens.length) {
      return false;
    }
    for (var i = 0; i < tokens.length; i++) {
      if (other.tokens[i].id != tokens[i].id) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(tokens.map((t) => t.id));

  @override
  String toString() => 'SpokenLine(${tokens.map((t) => t.id).join(', ')})';
}
