// studyTranslation.js — the words of a study in the reader's language.
// Phase 1 of docs/PLAN-JEZIK-STUDIJE.md.
//
// **The words are written in English and then translated**, because the app's
// truth check reads English: a sentence written in Serbian from the start would
// pass it unread. So the model writes the English as it always has, and every
// slot of the answer is translated here by the code that translates a tutorial
// (`tutorialTranslation.js`): its prompt, its answer reader and its judge —
// every move, square and move number back token for token, no Cyrillic in a
// Latin-script language — and what the judge refused is asked for once more,
// with the reasons.
//
// **A slot whose translation is refused twice is refused** (the owner's L3):
// it is named in `refused` and has no text, and the English is never put in
// its place. The app leaves it out of the tree, as it leaves out an untrue
// sentence.
//
// The one home of this: the route (`routes/studyWords.js`) and the measuring
// tool (`tools/position_study/translate.js`) both call `translateSlots`.

const { isTutorialLanguage, TUTORIAL_LANGUAGES } = require('./tutorialLanguage');
const {
  judgeTranslation, buildTranslationPrompt, readTranslationAnswer, chunksOf,
} = require('./tutorialTranslation');

/// The model the words are translated by. Phase 0 measured it: 105 of 105
/// sentences through the judge in Serbian and in German, 17 to 26 s a study.
const TRANSLATION_MODEL = 'deepseek-flash';

/// How long one translation request may take. The slowest of phase 0's
/// twenty-four took 26 s.
const TRANSLATION_TIMEOUT_S = 45;

/// No translation request starts later than this after the study's request
/// arrived. With the words' two attempts of at most 100 s each, the first
/// translation starts by 200 s; with this, the last one ends by 285 s, under
/// nginx's 300. A request that would start later is not asked, and what it
/// would have translated is refused.
const LAST_START_S = 240;

/// The language a request asks its words in: a code, or null for English.
/// Absent, null, '' and 'en' are all today's request — English, and nothing
/// translated. Anything else must be one of the tutorial's languages; a
/// RangeError names what is wrong.
function readStudyLanguage(value) {
  if (value === undefined || value === null || value === '' || value === 'en') return null;
  if (isTutorialLanguage(value)) return value;
  throw new RangeError(`language must be one of ${TUTORIAL_LANGUAGES.join(', ')}.`);
}

/// [slots] (`{ "m1.move": "..." }`) translated into [code].
///
/// Each slot is sent as a tutorial's comment (`p1.c<k>`), which is what the
/// prompt describes as a sentence said about a position or a move, and what
/// the judge checks for braces. [record] is told every request's tokens.
/// [startedAt] is when the study's request arrived, in the clock [now] reads.
///
/// Returns `{ slots, refused, firstRefused, requests }`: the translations that
/// passed, the slot ids that did not, the ones the first request did not pass
/// (what phase 0 measures), and how many requests were made. A provider that
/// fails throws its `LlmUnavailable`, as the words' own call does.
async function translateSlots({
  provider,
  slots,
  code,
  record,
  startedAt = Date.now(),
  now = Date.now,
}) {
  const ids = Object.keys(slots);
  const keyOf = Object.fromEntries(ids.map((id, i) => [id, `p1.c${i + 1}`]));
  const items = Object.fromEntries(ids.map((id) => [keyOf[id], slots[id]]));
  let requests = 0;

  async function ask(wanted, note) {
    const answered = {};
    for (const chunk of chunksOf(wanted)) {
      if ((now() - startedAt) / 1000 > LAST_START_S) break;
      const reply = await provider.complete(buildTranslationPrompt(chunk, code, note));
      requests += 1;
      await record(reply.usage.total);
      // An answer that is not the shape asked for answers nothing; the judge
      // then reads every item of the chunk as missing, and asks again.
      Object.assign(answered, readTranslationAnswer(reply.content) || {});
    }
    return answered;
  }

  let translated = ids.length ? await ask(items, null) : {};
  let faults = judgeTranslation(items, translated, { code });
  const idOf = Object.fromEntries(ids.map((id) => [keyOf[id], id]));
  const firstRefused = Object.keys(faults).filter((key) => key in idOf).map((key) => idOf[key]);
  const retry = Object.fromEntries(
    Object.keys(faults).filter((key) => key in items).map((key) => [key, items[key]]),
  );
  if (Object.keys(retry).length) {
    const note = 'Your earlier translation of the items below was rejected. '
      + 'Translate them again and follow every rule above.\n\n'
      + Object.keys(retry).map((key) => `- ${key}: ${faults[key].reason}`).join('\n');
    translated = { ...translated, ...(await ask(retry, note)) };
    faults = judgeTranslation(items, translated, { code });
  }

  // An id the model invented refuses the answer it came in, as it refuses a
  // tutorial's: a model that makes up an item is not trusted with the rest.
  const invented = Object.keys(faults).some((key) => !(key in items));
  const out = {};
  const refused = [];
  for (const id of ids) {
    if (invented || faults[keyOf[id]]) refused.push(id);
    else out[id] = translated[keyOf[id]];
  }
  return {
    slots: out, refused, firstRefused, requests,
  };
}

module.exports = {
  TRANSLATION_MODEL,
  TRANSLATION_TIMEOUT_S,
  LAST_START_S,
  readStudyLanguage,
  translateSlots,
};
