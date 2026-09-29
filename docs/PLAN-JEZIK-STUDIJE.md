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
| 4 | the manual under `site/`, the live-check items, the numbers in `CLAUDE.md` | lead |

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
