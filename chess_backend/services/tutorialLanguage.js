// tutorialLanguage.js — the languages a tutorial may say it is written in.
// Phase 1 of docs/PLAN-JEZIK-GLASA.md.
//
// **Seven, and only seven**: the ones whose moves can be said properly, which
// are exactly the vocabularies in `spokenMoves.js`. A language whose moves
// would be read out in English words is not offered — the owner's decision of
// 11.9.2026. Adding one here without a vocabulary there is the fault this list
// exists to prevent, so a test holds the two against each other.
//
// `null` is the eighth state and the common one: **not said**. It means what
// every tutorial meant before this column existed — the voice the reader chose
// in Settings — and it is not English. Nothing here turns one into the other.
//
// The one reader of these codes on the server. Every route that writes the
// column asks `isTutorialLanguage` rather than carrying its own list.

const TUTORIAL_LANGUAGES = Object.freeze(['en', 'sr-Latn', 'sr-Cyrl', 'de', 'es', 'it', 'fr']);

function isTutorialLanguage(value) {
  return typeof value === 'string' && TUTORIAL_LANGUAGES.includes(value);
}

/// What a write may do with the column, from what the request said.
///
/// `{ ok: true, value }` with a code or null, or `{ ok: false, error }` for a
/// value that is neither — refused rather than stored, because a tutorial
/// marked with a language nobody can read is worse than one that says nothing.
/// An empty string is treated as null: a cleared dropdown is „not said".
function readTutorialLanguage(value) {
  if (value === null || value === '') return { ok: true, value: null };
  if (isTutorialLanguage(value)) return { ok: true, value };
  return {
    ok: false,
    error: `A tutorial's language must be one of ${TUTORIAL_LANGUAGES.join(', ')}, or nothing.`,
  };
}

module.exports = { TUTORIAL_LANGUAGES, isTutorialLanguage, readTutorialLanguage };
