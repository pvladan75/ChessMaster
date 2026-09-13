/// How a detector's findings become words.
///
/// A move's comment has three readers who cannot share a machine separator: a
/// trainer ticking findings in the comment dialog, a language model reading a
/// reviewed game, and a voice reading an imported tutorial aloud. Until
/// 13.9.2026 findings were clauses behind labels and prefixes — „Pin: …",
/// „Watch out — …", „Resolved — …" — joined with „ | ", and every one of those
/// was repeated word for word by a model and read out by a voice. So a finding
/// is one sentence, a comment is sentences joined by a space, and the dialog
/// finds a finding in a comment by its sentence rather than by splitting on a
/// character. [TacticalMotifDetector] and [PositionalEvaluatorService] both
/// write through here.
library;

const _countWords = {
  2: 'two',
  3: 'three',
  4: 'four',
  5: 'five',
  6: 'six',
  7: 'seven',
  8: 'eight',
};

/// "three", "eight"; a number past eight stays a number.
String countWord(int count) => _countWords[count] ?? '$count';

/// "once", "twice", "three times".
String timesWord(int count) => switch (count) {
      1 => 'once',
      2 => 'twice',
      _ => '${countWord(count)} times',
    };

/// "a", "a and b", "a, b and c".
String joinAnd(List<String> items) {
  if (items.length <= 1) return items.join();
  return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
}

final _ending = RegExp(r'[.!?]$');

String _ended(String text) => _ending.hasMatch(text) ? text : '$text.';

/// A clause as a sentence: first letter capitalised, a full stop at the end
/// unless it already ends. Empty for a clause with nothing in it.
String sentence(String clause) {
  final text = clause.trim();
  if (text.isEmpty) return '';
  return _ended('${text[0].toUpperCase()}${text.substring(1)}');
}

/// One comment out of several parts. Each part is ended if it has no ending —
/// a trainer's own note included, so the sentence after it does not run into
/// it when read aloud — and nothing else about a part is rewritten.
String joinSentences(Iterable<String> parts) => parts
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .map(_ended)
    .join(' ');

/// Which of a move's candidate findings a stored [comment] already holds, and
/// what is left of it once they are taken out — the trainer's own note, or a
/// comment in a wording that is no longer written.
///
/// Found by the sentence and not by splitting: a separator character is a
/// character a trainer can type, and two findings of one kind used to be one
/// clause that the old split cut in two and could never match again.
({Set<String> tactical, Set<String> positional, String leftover})
    splitCommentForChecklist(
  String comment,
  List<String> tacticalCandidates,
  List<String> positionalCandidates,
) {
  var rest = comment;
  Set<String> take(List<String> candidates) {
    final found = <String>{};
    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;
      final at = rest.indexOf(candidate);
      if (at < 0) continue;
      found.add(candidate);
      rest = rest.replaceRange(at, at + candidate.length, ' ');
    }
    return found;
  }

  final tactical = take(tacticalCandidates);
  final positional = take(positionalCandidates);
  return (
    tactical: tactical,
    positional: positional,
    leftover: rest.replaceAll(RegExp(r'\s+'), ' ').trim(),
  );
}
