# A study in the reader's language

The owner, 29.9.2026: Position Study writes its comments in English. It should
write them in the language the reader chooses — into the move tree, and into
the tutorial made from a study.

## Settled, and not to be reopened

| | |
|---|---|
| Owner, 29.9.2026 | L1: the language is chosen in the study's dialog („Comments in"), and the choice is remembered |
| Owner, 29.9.2026 | L2: it covers the study, the tutorial made from it, and the two single-item doors of the same route — „Generate AI comment" on a move and the repertoire's „AI on position". Not Review's „Comment key moments with AI", not the tutorial from a game |
| Owner, 29.9.2026 | L3: a sentence whose translation is refused twice is **left out and counted**, as an untrue sentence is — never left in English |
| Owner, 29.9.2026 | L4: a study in another language is **one unit** of `ai_studies` (one of `ai_comments` for a single comment); the translation's tokens are counted, not a unit of `ai_translations` |
| `PLAN-STUDIJA-POZICIJE.md` | the model writes words only; the server checks shape, the app checks truth |
| `PLAN-JEZIK-GLASA.md` | the seven languages whose moves can be said, and only those (`TutorialLanguage`, `tutorialLanguage.js`) |
| `PLAN-PRIPREMA.md`, phase 9 | the translation's prompt and judge, held to one fixture with the batch tool |

## Why the words are written in English and then translated

The app's truth check (`judgeStudyWords`: `claimsFor`, `structureClaims`,
`defenderClaims`) reads English words — „fork", „pin", „isolated", „no
defender", „passed pawn". A sentence written directly in Serbian would pass it
unread: an invented „dvostruki napad" would be written into the tree, and
nothing would say that the check had stopped checking. Seven vocabularies of
that check, with Serbian's cases, are not worth building.

So the English is written and judged as today, and **only its words are
translated**, by the code that translates a tutorial
(`services/tutorialTranslation.js`): its prompt, with the chess terms of each
language, and its judge — every move, square and move number back token for
token (`Nf3`, never `Sf3`), no Cyrillic in a Latin-script language — asked once
more with the reasons for what it refused.

## The shape

**One request, not two.** The study's request says `language`; the server
writes the English, checks its shape, translates every slot it kept, and
answers both:

```
POST /study-words          { position, side, items, language: "sr-Latn" }
POST /study-words/comment  { ..., language: "sr-Latn" }
200 { slots: {...English...},
      translated: { language: "sr-Latn", slots: {...}, refused: ["m3.move", ...] },
      attempts, tokens, model }
```

- The app judges the English as today, and writes into the tree, for every
  slot it kept, **that slot's translation** — or nothing, when the translation
  was refused (L3). Refused English is never looked up in `translated`.
- One request keeps L4 true by construction: a separate translation route
  would be a door to translate any text for nothing, and would need a ticket
  to prove its text came from a study.
- A slot the app later refuses was translated for nothing. Phase 0 of the
  study plan refused 3 to 5 sentences in 109; their tokens are the price of not
  having a second door.
- `language` absent or `en` is today's request, byte for byte: no translation
  asked for, no new field in the answer.
- A translation that fails as a whole (the model unreachable after the English
  came back) is the study's words refused: the English is not written in its
  place (L3), the unit is refunded as for any failure, and the lines are
  written as they always are.

**The wait.** The server asks the words at most twice and the translation at
most twice; the app waits 230 s for the words today and nginx 300. Phase 0
says whether the translation fits under that, and by how much.

**The tutorial.** „Open as a tutorial" hands the studio the tree **and the
language** (`TutorialHandover`), so the draft says it and the film is spoken by
that language's voice.

## Roadmap

| phase | what | who |
|---|---|---|
| 0 | **measurement**: the twelve positions of the study plan's phase 0, the kept sentences translated into Serbian (Latin) and German by `tools/position_study/translate.js` through the server's own translation code; the owner reads the report | lead |
| 1 ✅ | the server: `language` on both routes, the translation inside the handler, `translated` in the answer, the tokens under the route's own token metric — **built 29.9.2026**, see §5 | lead |
| 2 ✅ | the app: „Comments in" in the study's dialog, remembered; the two single-item doors read the same choice and say which language they wrote in; the tree written from `translated`; the done view counts what was left out — **built 29.9.2026**, see §6 | lead |
| 3 ✅ | „Open as a tutorial" carries the language — **built 29.9.2026**, see §7 | lead |
| 4 ✅ | the manual under `site/`, the live-check items, the numbers in `CLAUDE.md` — **done 29.9.2026**: `analysis.html` and `repertoire.html` say „Comments in", the live pass is [252.1]–[252.7] in `TODO-provera.md` | lead |
| 5 | the owner's live pass, [252.1]–[252.7] | owner |

Phase 0's gate is the owner's reading. Every later phase's gate is its tests,
each watched red first.

## 4a. Phase 0, measured on 29.9.2026

The twelve positions of `tools/position_study/positions.json` at depth 20 on
Stockfish 19, the English from `deepseek-v4-pro` (today's server), the check
the app runs, and the kept sentences translated by `deepseek-flash` through
`services/tutorialTranslation.js` (`tools/position_study/translate.js`, the
report by `translation_reading.js`). The twelve studies offered 109 slots and
the app kept 105.

| | Serbian (Latin) | German |
|---|---|---|
| sentences passed by the translation judge | 105 of 105 | 105 of 105 |
| at the first request | 94 — one study's whole answer was not the shape asked for, and the second request passed all eleven | 105 |
| refused for notation, braces or script | none | none |
| tokens, twelve studies | 74,706 (6,200 a study) | 66,417 (5,500 a study) |
| seconds a study, median and max | 18.6, 26.2 | 17.4, 24.5 |

Beside it, the English: 17 to 123 seconds a study (median about 59) and 92,581
tokens for the twelve — so a translated study waits about a third longer and
spends about 1.8 times the tokens, the added ones on the cheaper model.

**The Serbian, read.** The terms are the app's (skakač, lovac, kvalitet,
vezivanje, dvostruki napad, slobodan pešak, poluotvorena linija), the sides are
lower case, the moves are the source's token for token. Three faults, all of
language rather than of chess: „tablebase" came back as „tabelarna baza"
(the term table has no row for it), „ima pešak više" for „pešaka više", and
„belov višak pešaka". None is a wrong claim; each is a row or a sentence of the
shared prompt, which the tutorial translation would gain from too.

**The wait is the one number that moves the design.** The worst case is two
attempts at the words and two at the translation: 2 x 123 + 2 x 26 is about
300 s, which is nginx's limit and past the app's 230. So phase 1 asks the
translation's second attempt only while the request is under 240 s, and the
app waits 290.

## 5. Phase 1, built on 29.9.2026

`services/studyTranslation.js` is the one home: `readStudyLanguage` (absent,
null, '' and `en` are English; the six other tutorial languages are taken;
anything else is a 400 before a credit) and `translateSlots`, which the route
and `tools/position_study/translate.js` both call. The route asks it once the
English has passed the shape check, and answers
`translated: { language, slots, refused }` beside the English; a request in
English has no new field and asks no translation. The translator is
`deepseek-flash` with 45 s a request, and no translation request starts after
240 s (`LAST_START_S`), so two attempts at the words (2 x 100 s) and the
translation end by 285 s, under nginx's 300. A provider failure during the
translation is a 503 and the credit handed back — the English is not sent in
its place (L3).

The shared prompt gained the owner's three corrections of phase 0 (a row for
„tablebase" → „baza završnica", „ima pešaka više", „beli"/„belog" and never
„belov"). The twelve studies translated again with it: 105 of 105 at the first
request, none of the three slips, 72,168 tokens, 17.3 s median and 26.1 s max.

Tests: `test/study_translation.test.js`, 18 cases (backend 1895 → **1913**,
measured with and without `.env`; 2072 with a database, derived — the cases
touch none). Ten mutations, each caught by the case meant for it; the one
that first survived — the route answering `refused: []` whatever the
translation refused — had no route-level case with a refusal, and has one now.

**Phase 2 has one number to carry**: the app waits 230 s for the words and
must wait 290 now (`kStudyWordsTimeout`).

## 6. Phase 2, built on 29.9.2026

`AppSettingsService.studyLanguage` (`app_study_language`) holds the choice;
`chosenStudyLanguage()` reads it as a code the server takes, or null for
English and for a code this build does not know. `runPositionStudy`,
`commentOnMove` and `commentOnPosition` take `language`, send it only when it
is not English, judge the English as before, and write for every slot the
check kept **its translation, or nothing** (`_inLanguage`); an answer with no
`translated`, or one in another language, writes no comment at all and says
so (`untranslated`). `StudyResult` carries `language` and `untranslated`, and
the done view says how many comments the translation lost.
„Generate AI comment" and „AI on position" pass the same choice and show
`studyLanguageNote` under the text. The app waits 290 s.

The menu took the width of its widest item and overflowed a 360 dp dialog by
75 px in the screen test's font, while the dialog test, which loads Roboto,
passed: it is now `isExpanded` in a `Flexible` beside its label, with an
ellipsis, and the dialog test reads `didExceedMaxLines` on „Serbian
(Cyrillic)" on the phone. A drawing of the dialog in the real font, at 360 x
640 and 1280 x 800, found the menu's text larger than its label; its style is
now the label's, merged with the surrounding text style.

Tests: 18 (app 5087 → **5105**, a full run with nothing else running; analyze
the same 22 infos). Seventeen mutations, each caught by the case meant for it.

## 7. Phase 3, built on 29.9.2026

`TutorialHandover` carries `language`, and „Open as a tutorial" gives it the
study's language when the study wrote comments in one; a study in English, or
one that wrote none, leaves the tutorial's language unsaid, as before. A new
tutorial takes it. The tutorial being written takes it only when it has said
none; one in another language keeps its own — its parts were written in it —
and the trainer is told so; a saved tutorial whose language the draft does not
know is left alone, since a save from it does not write the column.

Tests: 6 (app 5105 → **5111**, a full run with nothing else running; analyze
the same 22). Seven mutations, each caught by the case meant for it. The first
two cases were red for their fixture: a handover of one bare position is not a
tutorial anybody started, and the draft slot does not give one back — a study
hands over moves and comments, and now the fixture does too.

## 8. A tutorial made from a game, in the reader's language

The owner, 29.9.2026, on „Make a tutorial from this game": can it be in another
language too? L2 had left it out; the owner's answers the same day:

| | |
|---|---|
| G1 | the language is chosen in that dialog, and the tutorial the trainer picks (Key moments or Whole game) is translated **whole** before it opens in the studio, unsaved as today |
| G2 | the choice is **one setting** with the study's „Comments in", shown in both dialogs |
| G3 | a translated tutorial is **one unit** of `ai_tutorials`; the translation's tokens are counted under `ai_tutorial_tokens`, no unit of `ai_translations` |

**Why whole and not by slot, as the study is.** A tutorial from a game holds
sentences the app writes itself — the lexicon of `fillerWords` („…hands the
opponent the better game. Now White is slightly better."), the turning points
the model left unsaid, the recap, the book summary — which no model slot
carries. Translating the slots would leave those in English, a tutorial in two
languages. The whole tutorial is what `POST /lessons/:id/translate` already
translates and proves: its prose items, its judge, the merge, and
`proveUntouched`, which holds every move, arrow and square to the source.

### 8a. Phase 5, measured on 29.9.2026

The twenty tutorials of the app's fixtures — ten games, each as Key moments
and Whole game, the app's own assembly of the recorded model answers —
translated whole by `services/tutorialTranslation.js` with `deepseek-flash`
(`tools/game_tutorial_translate/measure.js`):

| | Serbian (Latin) | German |
|---|---|---|
| tutorials passed by the judge and proved untouched | 20 of 20 | 20 of 20 |
| at the first request | 20 | 20 |
| texts translated | 762 | 762 |
| characters, all twenty | 66,082 (at most 5,048 a tutorial — one request each; a chunk is 12,000) | same |
| seconds a tutorial, median and max | 31.0, 47.5 | 28.3, 40.6 |
| tokens | 229,502 (11,500 a tutorial) | 226,131 |

**The Serbian, read.** Two slips of language, both a line of the shared
prompt: a side „je bolje" where it is „je bolji" / „stoji bolje" („crni je
jasno bolje"), and the master book called „baza velemajstora" /
„velemajstorske partije" — the book is games of players rated 2200 or more,
„majstorske partije". No wrong move, square or claim.

### 8b. The shape

- **One request after the words**, `POST /lessons/from-game/translate
  { language, tutorial: { title, description, steps } }`: signed in, a
  limiter, the entitlement the words route asks (`ai_tutorials`), the request
  checked (the seven languages but English, steps shaped as a tutorial's,
  caps), a configured model — and **no quota unit** (G3); every attempt's
  tokens under `ai_tutorial_tokens`. It answers the tutorial translated and
  proved, or a 422 with the texts that did not pass twice.
- **One home for „translate a tutorial"**: the steps of
  `POST /lessons/:id/translate` — items, ask by chunk, judge, ask again,
  merge, prove — move into a service both routes call; the saved route keeps
  its copy and its `ai_translations`.
- **No door a study did not have**: a saved tutorial can be translated
  without a unit already (`ai_translations` is counted, not limited — Q3 of
  `PLAN-PRIPREMA.md`), so a route that takes the tutorial in the body opens
  nothing new; it asks the entitlement the words asked.
- **The wait**: one request of at most 47.5 s measured, twice at the most at
  100 s each, under nginx's 300; the app waits 230 s.
- **A translation that fails twice** opens nothing mixed: the trainer is told,
  and offered the tutorial in English (see the question below).
- **The studio** opens the translated tutorial with its `language` set, so its
  film is spoken in it.

### 8c. Roadmap

| phase | what | who |
|---|---|---|
| 5 ✅ | measurement (above) | lead |
| 6 ✅ | the server: the shared service, the new route, the two prompt lines — **built 29.9.2026**, see §8d | lead |
| 7 ✅ | the app: „Comments in" in the dialog (the study's setting), the translation after the choice, its progress and refusal, the studio told the language — **built 29.9.2026**, see §8e | lead |
| 8 ✅ | the manual and the live-check items — **done 29.9.2026**: `analysis.html`, [252.8]–[252.12] | lead |
| 9 | the owner's live pass, [252.8]–[252.12] | owner |

### 8d. Phase 6, built on 29.9.2026

`translateTutorial` (`services/tutorialTranslation.js`) is the one home of the
steps a tutorial is translated by — items, ask by chunk, judge, ask again,
merge, prove — and both routes call it: `POST /lessons/:id/translate` keeps its
copy and its `ai_translations`, and the new `POST /lessons/from-game/translate`
(`routes/gameTutorialWords.js`) takes the tutorial in the body
(`readTutorialToTranslate`: the six languages that are not English, 1–80 parts,
a position and a line each, at most 40,000 characters of words), asks the
entitlement the words asked and no unit of the quota, counts every attempt's
tokens under `ai_tutorial_tokens`, and answers the tutorial translated with its
`language`, or a 422 naming what did not pass twice. The measuring tool
translates through the same function.

The shared prompt gained the two corrections of §8a. The twenty tutorials
translated into Serbian again with it: 20 of 20 at the first request, both
slips gone („majstorske partije" 20 times, no „velemajstor…", no side that „je
bolje"), 35.1 s median and 58.7 s at most, one request each.

Tests: `test/game_tutorial_translate.test.js`, 11 cases, standing on a real
tutorial from the app's fixtures (backend 1913 → **1924**, measured with and
without `.env`; 2083 with a database, derived — the cases touch none). Eleven
mutations: ten caught by the case meant for each; the eleventh changed only the
English half of the prompt's new row, which the case does not read, and
deleting the row turned it red.

### 8e. Phases 7 and 8, built on 29.9.2026

`CommentsLanguageMenu` (`lib/features/analysis_studio/widgets/`) is the one
home of „Comments in": the study's dialog and „Make a tutorial from this game"
both draw it, and both store the choice in `AppSettingsService.studyLanguage`
(G2). The depth dialog says, under a language that is not English, that the
tutorial will be translated whole and that it takes up to a minute more;
`GameTutorialSettings` carries the language. After the trainer picks Key
moments or Whole game, **only that one** is translated
(`translateGameTutorial`, `translate_client.dart`) under a dialog that cannot
be dismissed; it opens with its `language`, so the studio marks the draft and
the film is spoken in it. A translation refused twice, or not answered, opens
„Not translated into …" with the reason, `Close`, which opens nothing, and
`Open in English`, which opens the tutorial as written — never a tutorial half
translated. The app waits 230 s.

The manual's Analysis page says all of it; the live pass is [252.8]–[252.12]
in `TODO-provera.md` (Analyse → Tutorijal iz partije).

Tests: 9 (app 5111 → **5120**, a full run with nothing else running; analyze
the same 22). Fourteen mutations, each caught by the case meant for it. A
drawing of the depth dialog in Roboto at 360 x 640 and 1280 x 800 showed the
label, the whole of „Serbian (Cyrillic)" and the note, with „Start" on the
screen.
