/// What a label is allowed to be, in one place.
///
/// Labels are `saved_lessons.tags`: the column the saved-position dialog has
/// always written, that `GET /lessons/labels` lists and that the
/// `includeTags`/`excludeTags` filter reads. Until 11.9.2026 the only writer
/// was a human typing into a chip field, where „trim it and do not add the same
/// one twice" was the whole rule and it lived in the dialog.
///
/// The JSON import is the second writer, and it is a machine: a generated file
/// can carry an empty string, the same label twice in two spellings, or one
/// long enough to overflow `VARCHAR(255)` — which arrives as a 500 that reads
/// as „importing is broken". Hence one reading of the rule, shared.
library;

/// The longest a single label may be. `saved_lessons.tags` is
/// `VARCHAR(255)[]`, and a longer one is refused by Postgres rather than
/// shortened.
const int maxLabelLength = 255;

/// How many labels one tutorial may carry.
///
/// Not a database limit — an array has no length — but a filter panel draws one
/// chip per label, and a tutorial with fifty of them is a tutorial nobody can
/// see the name of. Anything past this is dropped rather than refused: a label
/// too many is not worth failing an import over.
const int maxLabelsPerLesson = 12;

/// Trimmed, non-empty, deduplicated, and short enough to store.
///
/// Deduplication is **case-insensitive and keeps the first spelling**, because
/// „Endgame" and „endgame" are two chips in the filter panel and one idea in
/// the trainer's head. The first spelling wins so that a label typed by a
/// person is not rewritten by a file imported later.
List<String> normaliseLabels(Iterable<String> raw) {
  final out = <String>[];
  final seen = <String>{};
  for (final entry in raw) {
    final cleaned = entry.trim();
    if (cleaned.isEmpty) continue;
    final short = cleaned.length > maxLabelLength
        ? cleaned.substring(0, maxLabelLength)
        : cleaned;
    if (!seen.add(short.toLowerCase())) continue;
    out.add(short);
    if (out.length == maxLabelsPerLesson) break;
  }
  return out;
}
