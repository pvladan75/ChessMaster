/// Reading Dart source the way a gate needs to: code, comments and string
/// literals told apart.
///
/// Walked rather than matched with a regular expression, because a regular
/// expression cannot tell code from writing about code. This repository's
/// comments quote retired labels („Not 'Snimljeni časovi' any more"), name the
/// classes a file deliberately does not call, and explain the parameters that
/// were removed — so a check that matched text would fail the explanation, or
/// pass by matching the comment that says a thing is gone. Three gates here
/// have already done each of those.
///
/// Lifted out of `manual_labels_test.dart` on 15.9.2026, when a second gate
/// needed the same walk, rather than written a second time beside it.
library;

/// What one piece of a source file is.
///
/// An interpolation is code that sits inside a literal — `'${x.minRating}'`
/// reads a field — and is its own kind so that it neither hides the code it is
/// nor splits the sentence it is inside.
enum SourcePart { code, comment, literal, interpolation }

/// The file in order. A literal comes first and its interpolations follow it;
/// the literal's text has a single space where each one was.
List<({SourcePart kind, String text})> partsOf(String src) {
  final parts = <({SourcePart kind, String text})>[];
  final code = StringBuffer();

  void flushCode() {
    if (code.isEmpty) return;
    parts.add((kind: SourcePart.code, text: code.toString()));
    code.clear();
  }

  var i = 0;
  while (i < src.length) {
    if (src.startsWith('//', i)) {
      final end = src.indexOf('\n', i);
      final stop = end < 0 ? src.length : end;
      flushCode();
      parts.add((kind: SourcePart.comment, text: src.substring(i + 2, stop)));
      i = stop;
      continue;
    }
    if (src.startsWith('/*', i)) {
      final end = src.indexOf('*/', i + 2);
      flushCode();
      parts.add((
        kind: SourcePart.comment,
        text: src.substring(i + 2, end < 0 ? src.length : end),
      ));
      i = end < 0 ? src.length : end + 2;
      continue;
    }
    final c = src[i];
    if (c != "'" && c != '"') {
      code.write(c);
      i++;
      continue;
    }
    // A raw string's `r` went into the code buffer on the way past; it is part
    // of the literal.
    final raw = i > 0 && src[i - 1] == 'r';
    if (raw) {
      final text = code.toString();
      code.clear();
      if (text.isNotEmpty) code.write(text.substring(0, text.length - 1));
    }
    flushCode();
    final slot = parts.length;
    parts.add((kind: SourcePart.literal, text: ''));
    final quote = src.startsWith(c * 3, i) ? c * 3 : c;
    final buf = StringBuffer();
    var j = i + quote.length;
    while (j < src.length && !src.startsWith(quote, j)) {
      if (quote.length == 1 && src[j] == '\n') break;
      if (!raw && src[j] == r'\' && j + 1 < src.length) {
        buf.write(src[j + 1] == 'n' ? '\n' : src[j + 1]);
        j += 2;
      } else if (!raw && src.startsWith(r'${', j)) {
        j++; // past the `$`, so the count starts on the brace it opens
        final open = j;
        var depth = 0;
        do {
          if (src[j] == '{') depth++;
          if (src[j] == '}') depth--;
          j++;
        } while (j < src.length && depth > 0);
        parts.add((
          kind: SourcePart.interpolation,
          text: src.substring(open + 1, j - 1),
        ));
        buf.write(' ');
      } else if (!raw &&
          src[j] == r'$' &&
          j + 1 < src.length &&
          RegExp('[A-Za-z_]').hasMatch(src[j + 1])) {
        final open = j + 1;
        j++;
        while (j < src.length && RegExp('[A-Za-z0-9_]').hasMatch(src[j])) {
          j++;
        }
        parts.add((
          kind: SourcePart.interpolation,
          text: src.substring(open, j),
        ));
        buf.write(' ');
      } else {
        buf.write(src[j]);
        j++;
      }
    }
    parts[slot] = (kind: SourcePart.literal, text: buf.toString());
    i = j + quote.length;
  }
  flushCode();
  return parts;
}

/// The code of [src] with every comment and literal blanked, interpolations
/// kept — what a check for an identifier or a call should read.
String codeOf(String src) => partsOf(src)
    .map((p) => p.kind == SourcePart.code || p.kind == SourcePart.interpolation
        ? ' ${p.text} '
        : ' ')
    .join();

/// Every comment in [src], one entry per comment.
List<String> commentsOf(String src) => [
      for (final p in partsOf(src))
        if (p.kind == SourcePart.comment) p.text,
    ];

/// The string literals of one Dart source, as the compiler would join them.
///
/// Comments are skipped; adjacent literals are joined, as a long sentence is
/// written across lines; an interpolation becomes a space, so „Resume session"
/// matches `'Resume session ${code}'`.
List<String> literalsIn(String src) {
  final joined = <String>[];
  // True while nothing but whitespace, or the previous literal's own
  // interpolations, stands since the last literal.
  var adjacent = false;
  for (final p in partsOf(src)) {
    switch (p.kind) {
      case SourcePart.literal:
        if (adjacent) {
          joined[joined.length - 1] = joined.last + p.text;
        } else {
          joined.add(p.text);
        }
        adjacent = true;
      case SourcePart.interpolation:
        break;
      case SourcePart.code:
        if (p.text.trim().isNotEmpty) adjacent = false;
      case SourcePart.comment:
        adjacent = false;
    }
  }
  return [for (final s in joined) s.replaceAll(RegExp(r'\s+'), ' ').trim()];
}
