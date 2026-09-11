/// The name a tutorial part gets when the trainer has not named it, and how
/// such a name is recognised again.
///
/// One rule in one place, because batch 57 wrote it in five: the same regex
/// stood in four mutation methods of `TutorialStudioScreen` and once more in
/// `TutorialSectionsPanel`, each compiling it inside a loop over the parts.
/// Three hand-written copies of one condition is how the `status = 'accepted'`
/// bug got in, and this one decides which of a trainer's titles it is allowed
/// to overwrite.
///
/// It lives beside the lesson models rather than in the studio because more
/// than the studio reads it: the studio writes these names, and the child's
/// viewer and the room show the ones already stored.
library;

/// „Part 3" for the third part.
///
/// It was „Deo 3" until 11.9.2026 — the one Serbian word the English pivot left
/// in the studio, because it has no letter a Serbian-text gate could see.
String generatedSectionTitle(int index) => 'Part ${index + 1}';

/// Whether [title] is a name the studio generated rather than one the trainer
/// wrote — the only kind [generatedSectionTitle] may renumber over.
///
/// „Deo" and „Primer" are here as well as „Part" because tutorials named with
/// them are still on the server. Reordering one must renumber it rather than
/// leave „Primer 3" standing second, and the child's viewer must show it as
/// „Part 3" rather than as a Serbian word in an English app.
bool isGeneratedSectionTitle(String title) =>
    _generatedSectionTitle.hasMatch(title.trim());

final RegExp _generatedSectionTitle = RegExp(r'^(Part|Deo|Primer)\s+\d+$');

/// How a stored part name is shown to a reader: a generated one — „Deo 2"
/// saved before the English pivot, or „Part 2" — as [generatedSectionTitle] of
/// where the part actually stands, and a trainer's own name as they wrote it.
///
/// Null when the part has no name at all, so each caller keeps the fallback
/// its own sentence needs. Tutorials already on the server keep „Deo N" until
/// a trainer saves them again, which is why this is read at every place a
/// stored name reaches a screen rather than fixed once on the way in.
String? shownPartTitle(String? stored, int index) {
  final title = stored?.trim() ?? '';
  if (title.isEmpty) return null;
  return isGeneratedSectionTitle(title) ? generatedSectionTitle(index) : title;
}
