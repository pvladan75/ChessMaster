# The closing plan

Written 8.9.2026, after the owner's live pass through tutorial authoring and a
review of what the four open questions would actually cost. **The scope is
frozen by this document**: what is not in it does not get built before release,
and the reason for each exclusion is written down so the decision does not have
to be taken twice.

**The phases are logical, not calendar.** The owner has other obligations and
will not necessarily move one phase per day. The *order* is fixed — a phase does
not start before the one in front of it is finished — but no date is promised
anywhere in this file, and none should be added to it.

## What was decided

The table as decided on 8.9.2026, with what has happened to each row since.
**Updated 11.9.2026** at the owner's request, because two „out" rows had been
reversed by the owner's own later decisions and the table still said „out".

| | 8.9.2026 | Why | Where it stands, 11.9.2026 |
|---|---|---|---|
| Video of a tutorial | **in** | Server-side, through the renderer that already exists | **Built** — Phase 2, 9.9.2026 |
| „Predloži rečenicu" in the studio | **in** | LLM writes prose about a chosen position, never moves | **Postponed**, not dropped — the owner chose to start Phase 4 first (11.9.2026). The Gemini key has no billing: about 20 requests a day |
| One board-setup dialog | **in** | Two files with the same name is a fault, not a preference | **Built** — Phase 1a, 8.9.2026 |
| Naming the board screens | **in** | Renaming entries, **not** merging screens | **Built** — Phase 1b, 8.9.2026 |
| TTS through a public API | out | See „What is deliberately not being done" | **Reversed — in.** Azure Speech is a provider for the film's narration (`TTS_PROVIDER`), piper stays the fallback, 11.9.2026. The app itself still reads with the device's voices |
| Video rendered on the device | out | Same | Unchanged — out |
| A user's manual and the site's content | **in** | The answer to „ne snalazim se u moru funkcija" | **In progress** — Phase 4, started 11.9.2026, **in English** (decided 8.9.2026, below) |
| Monetisation beyond what is built | out | Same | Unchanged — out |
| Reorganising the app by function | out | Same | Unchanged — out |
| Translating the app | out | No i18n layer exists; ~1700 Serbian literals | **Replaced** — the app went English-only on 8.9.2026, in place and with no i18n layer. A second interface language is still out |

**Added after the freeze, each by the owner's decision** — the scope this
document froze grew by these, and each has its own plan:

| | Plan | Where it stands, 11.9.2026 |
|---|---|---|
| A trainer's own voice over a tutorial, and its film | `PLAN-SNIMANJE.md`, part one | **Built** 10.9.2026, phases 0–6; live checks 138–141 |
| A render that leaves the request, and one refused before drawing | `PLAN-SNIMANJE.md`, part two, items 4–5 | **Built** 10.9.2026. Chunking and the overnight lane are not |
| A tutorial read in its own language's voice | `PLAN-JEZIK-GLASA.md` | **Built** 11.9.2026; live check 150 |
| Undo, the saved version, a line inserted into a part | `PLAN-STUDIO-ISTORIJA.md` | **Built** 11.9.2026; live check 151 |
| The audience, General Audience 13+ | this document, below | **Decided and built** 8.9.2026 |

## Phase 1 — the freeze, and two cuts

Nothing new is designed after this phase. Two things are cut because they are
faults rather than improvements.

### 1a. One dialog for setting up a position

Reported live on 8.9.2026: the same act has two different dialogs. It does —
**two files, both named `board_setup_dialog.dart`**:

* `lib/widgets/board_setup_dialog.dart` — 393 lines, a piece-placement editor
  and nothing else. Takes `onFenGenerated` and **no `initialFen`**, so it always
  opens on the standard position and cannot be opened on the board in front of
  you. Used by the room. This is the one the owner called good.
* `lib/features/analysis_studio/widgets/board_setup_dialog.dart` — 820 lines,
  tabbed: FEN entry, PGN import (file, chess.com, Lichess), an opening picker, a
  game selector. Takes `initialFen`, `onPositionSet`, and an optional
  `onPgnLoaded`. Used by the Analysis Studio and by the tutorial studio.

So this is not one thing written twice — it is a better *editor* and a better
*shell*, and the resolution is neither „delete A" nor „delete B":

**One dialog. The shell is B, its first tab is A's editor, opened on the
position the caller is looking at. A is deleted.** The room passes the board's
current FEN where it passed nothing. Nothing else about the room changes.

The gate for it:

1. Every entry — room, Analysis Studio, tutorial studio — reaches the same
   dialog, and a source-reading test fails if a second one appears.
2. The room's dialog opens on the position that is on the board, which it never
   could before.
3. The tutorial studio's entry behaves as it does today: no `onPgnLoaded`,
   because importing a PGN into a tree is the Analysis Studio's job and a second
   importer beside the first is how the two disagree.
4. **The palette is legible.** The owner's words: „u ovom se crne figure skoro i
   ne vide od iste pozadine". Read as a luminance problem, not a hue one — the
   owner is colourblind and their sign-off proves lightness and shape, never
   colour.

### 1b. The names say what the screen is for

Three screens carry a board and side panels, and two of them look alike enough
that the owner asked why both exist:

* the room with a student in it — „Soba: 589388"
* the same room alone, with the lesson library on the left — **„Šahovski
  studio"**
* the analysis board — **„Tabla za Analizu"**

and a fourth, „Studio za tutorijal", takes the word *studio* a third time.

**The screens are not merged.** They do different work, they were built for
different work, and merging them is the multi-week job this plan exists to
avoid. What changes is the name and the door: each entry says what the screen is
for, and the word „studio" belongs to exactly one of them.

**The names, delegated to me on 8.9.2026 and settled here.** One word from the
owner changes any of them; until then these are what the app and the
documentation both say, because the documentation is written against them.

| Screen | Was | Is |
|---|---|---|
| The room with a student in it | „Soba: 589388" | unchanged |
| The same room alone, with the library | „Šahovski studio" | **„Priprema"** |
| The analysis board | „Tabla za Analizu" | **„Analiza"** |
| Writing a tutorial | „Studio za tutorijal" | unchanged |

The reasoning, because the names have to survive somebody disagreeing with
them. „Šahovski studio" and „Tabla za Analizu" were not merely similar-looking;
their own descriptions on the home screen described the same thing — „Samostalni
rad, FEN postavljanje, PGN i Stockfish analiza" against „Slobodna šahovska tabla
za duboku analizu … rad sa PGN/FEN pozicijama". No wonder the owner asked why
both exist. The difference is not the board:

* **Priprema** is where your own saved positions and tutorials are, on a board,
  with drawing and recording — the room without a student in it. It is about
  *your material*.
* **Analiza** is the engine, the opening database and the tree of variations.
  It is about *a position*.

„Priprema" is preferred over „Moja tabla" and „Radna soba" because it names the
work rather than the furniture, and because it is the word a trainer already
uses for what they do there. And the word „studio" is left in exactly one
place, which is the whole point of the exercise.

The rename obeys the glossary contract (`docs/TABELA-RECNIK-2026-09.md`): the
strings gate takes a table of decided replacements, so the new names go in that
table and the sweep is checked against it. The home-screen descriptions are
rewritten with them — a name that says one thing under a sentence that says
another is worse than the old name.

### 1c. The freeze

After 1a and 1b, no new feature is designed. Anything found from here on is
either a fault (fixed), or written into `docs/TODO-provera.md` and left.

## Phase 2 — a tutorial becomes a video

### What already exists

`chess_backend/videoRenderer.js`, 319 lines, verified live: `@napi-rs/canvas`
draws one PNG per second, `ffmpeg` turns the pipe into an MP4 with an audio
track. It is driven from `POST /recordings/:id/export`, takes a title, a list of
events, an optional audio file, a duration, a perspective, a resolution, a piece
set and a board theme, and it already ages its output out on a retention timer.
`ENT.MP4_EXPORT` already exists as a paid entitlement.

Its event shape is small:

```js
{ timestampMs, eventType: 'init' | 'move', data: { fen, from, to, san } }
```

### What it does not do, which is the work

**It draws no arrows, no coloured squares and no sentence.** For a recorded
lesson that was right — the voice carried the teaching. For a tutorial it is
most of the teaching: `[%cal]`, `[%csl]` and the trainer's sentence are what a
part *is*, and a video without them is a slideshow of positions.

So Phase 2 is four pieces, in this order:

1. **A tutorial becomes a list of events.** `beatsOf` already turns a part into
   the beats a child meets, in the child's order; a video is those beats with a
   timestamp each. Every part of the tutorial in sequence, joins included.
   Pure function, gated by tests, no screen involved.
2. **A dwell time per beat.** There is no voice to wait for, so the sentence
   has to stay up long enough to be read: proportional to its length, with a
   floor. A beat with nothing written keeps today's short beat.
3. **The renderer learns three things**: a caption band under the board for the
   sentence, `[%cal]` arrows, `[%csl]` squares. The board's orientation comes
   from the part's `blackOrientation` — the field that already travels to the
   child — mapped onto the renderer's `perspective`.
4. **The route and the door.** A tutorial export beside the recording export,
   metered by the entitlement that already exists, and one button where a
   trainer already stands: the saved-tutorials list.

**The video is silent, by decision.** The sentences are on screen. Audio would
need TTS, and TTS is out of scope — see below. Nothing in this phase makes
adding a voice later harder: the renderer already takes an audio file.

The gate for it: a two-part tutorial with a comment, an arrow and a coloured
square renders to a file that plays, with the arrow on the move it belongs to,
the sentence readable, and the board the way round the trainer left it.

## Phase 3 — „Predloži rečenicu" in the studio

**Postponed on 11.9.2026, not dropped.** The owner chose to start Phase 4 first,
which breaks this document's rule that a phase waits for the one in front of
it — deliberately, and written here so the order is not read as an accident.
Before it is built, the Gemini key needs billing: without it the key allows
about 20 requests a day.

### What already exists

`chess_backend/geminiService.js`, `gemini-flash-latest`, with
`explainPosition` and `generateMoveComment`, both carrying a hand-written
fallback for when there is no key. Wired into puzzles and game analysis, and
metered: `ENT.AI_COMMENTS`, quotas 10 / 500 / 2000 / unlimited by tier.

### The rule this feature is built under

**The model writes prose about a position the trainer has already chosen. It
never proposes, plays, or edits a move.** A model that invents a variation is
worse than no help at all, because the material goes to children and the trainer
would be reviewing chess rather than reviewing writing.

Concretely:

1. One button on the current beat card in „Tok". It fills the sentence field
   and nothing else — not the kind, not the task, not the answers, and never the
   tree.
2. **Nothing is saved by pressing it.** The trainer edits or deletes the text
   like any other; the draft is written by the same path as typing.
3. What travels: the FEN, the move that arrived at the beat, and the engine's
   evaluation if it is already on screen. **Not the tutorial's other parts, not
   the trainer's name, not any child's name or id.** The smallest thing that can
   answer the question.
4. A refusal is a sentence, not a silence: no key, no quota left, or no answer
   all say so, and the field is left exactly as it was.

The gate for it: the button never changes a tree; a failed call leaves the
field untouched; the request carries a position and nothing about a person.

## Phase 4 — the manual, and the site

**Started 11.9.2026 — `docs/PLAN-PRIRUCNIK.md` carries it**, with the owner's
decisions: the manual is pages on the site with a link from the app, words only
until the app is frozen, and the worker writes most of the chapters.

**Promoted, on the owner's reading, and they are right.** „Najveći problem je
nepostojanje dokumentacije koja bi pomogla korisniku da se snađe u moru
funkcija. Dobra dokumentacija može da nadomesti i malo klimavu organizaciju."

That sentence is what makes this a phase rather than a chore at the end. The
app's organisation is not being rebuilt — that decision is in this document —
so the manual is not describing the structure, it **is** the structure the user
gets. It is therefore written after the features are frozen and built, and
against the names from Phase 1b.

1. **A user's manual, in English** (written „in Serbian" on 8.9.2026 and
   changed the same day with the app — see „Superseded on 8.9.2026" below).
   Task-shaped rather than screen-shaped: what
   a trainer wants to do, and which door it is behind. „Napravi tutorijal",
   „Pošalji ga đaku", „Vidi šta je dete uradilo", „Pripremi repertoar",
   „Analiziraj partiju". A screen-by-screen tour is what the app already is,
   and it is what the owner is complaining about.
2. **The site, filled in.** `docs/TODO-objavljivanje.md` §3a already says the
   site is a precondition rather than marketing — the privacy policy and the
   parent's consent text are served from it. What it needs beyond the legal
   pages is the same manual, and a page that says what the app is for.
3. **What the child and the parent see** is its own short piece, and it is not
   the trainer's manual with the words changed.

Translation is **not** part of this — see below.

## Phase 5 — the verification list, triaged

The number in the first draft of this plan was wrong, and the owner corrected
it: **most of the 592 undocumented items have been seen working**, they were
walked before this recording system existed, and a large part of the rest
describes features that were changed or abandoned. What the list is short of is
*bookkeeping*, not testing.

So this phase is triage of the list rather than a march through it. Measured on
8.9.2026:

| | |
|---|---|
| 1037 | verification items in `docs/TODO-provera.md` |
| 418 | confirmed live and recorded |
| 592 | not recorded — mostly seen, some stale, a few genuinely unwalked |
| 20 | marked as failing |
| 6 | untestable as written |

Three piles, and the work is putting each item in one:

* **Stale** — describes something the app no longer does. Retired to
  `docs/arhiva/` with a line saying which change retired it. This is expected to
  be the biggest pile and it costs almost nothing per item.
* **Seen** — the owner remembers walking it and the feature has not changed
  since. Recorded as such, with the honest note that it was not recorded at the
  time.
* **Genuinely unwalked** — the only pile that costs anything, and the rule for
  what must be walked before release is:

**A gate — must be walked before release:**

1. Anything a child or a parent touches: consent, the age gate, what a minor's
   account can do, what reaches a parent.
2. Anything that takes money or grants a paid right.
3. The paths a first real user walks end to end: sign up, find a trainer, be
   accepted, get a tutorial, do it; and on the other side: sign up, invite a
   student, write a tutorial, send it.
4. The 20 items already marked as failing. A known fault at release is a
   decision; a forgotten one is an accident.

**Not a gate — recorded as unverified:** everything else, moved to
`docs/arhiva/` with its status intact and a sentence saying it was never
watched. That sentence is the deliverable. „Tested in code, never run live" has
already hidden one real fault in this project (`getDue`, a missing import that
compiled), and the honest record is what makes the next person look.

## Phase 6 — publishing

`docs/TODO-objavljivanje.md`, in the dependency order it already has. Its long
poles are external and cannot be compressed by working harder: the Play Console
product setup, the service account for purchase verification, RTDN, the first
real purchase, and the app-size question that Stockfish's 114 MB opens. The
backend also has to be switched on — the droplet is provisioned and the service
deliberately stopped, and that switch happens once, in one direction, when a
domain is chosen.

## What is deliberately not being done

**Video rendered on the user's device.** The reason for wanting it was cost, and
the cost it avoids is a few processor-seconds per video on a droplet whose
`exports/` already expires. What it would add is an ffmpeg binary in a Windows
build that is already fighting its size, a frame renderer written a second time
in Dart, and a class of failure that only appears on other people's machines.
If it is ever wanted, it is **additive**: the same event list, a different
renderer.

**TTS through a public API.** Roughly $4–16 per million characters; a beat is
about 120 characters, so a tutorial is about 2400 and a thousand of them read
once is $10–40 — cheap, but only with a cache, because the same sentence
otherwise pays on every play. It is worth revisiting only if the device voice's
Serbian is materially worse to the ear, which is a thirty-second test and not a
build. Its one genuine attraction is that it sends the trainer's own text and
never a child's voice or name.

**Superseded on 9.9.2026, and the supersession is the shorter rule.** The owner:
*„srpski jezik u njoj je nebitan, važno je kako će izgledati na engleskom. Meni
ne treba da se bilo šta izgovara na srpskom, samo na engleskom za sad."* So
there is **no Serbian speech at all**, by any route, and the per-artefact
language problem below is not a decision deferred — it is a decision made the
other way. Everything spoken or synthesised is English until the owner says
otherwise; a trainer who writes a Serbian sentence gets it read in an English
voice, and that is accepted rather than worked around. What follows is kept
because it is the reasoning that would have to be revisited if that ever
changes.

**Reversed on 11.9.2026 for the film: Azure Speech.** The owner's own account
answered with 655 voices in 154 languages, four of them Serbian, and the film's
narration can be synthesised through it (`TTS_PROVIDER`, with piper kept as the
fallback). The cost argument above stands, and it is why the film's clips are
cached. The app itself still reads with the device's own voices.

**Narrowed on 11.9.2026 — see `docs/PLAN-JEZIK-GLASA.md`.** It changed: a
tutorial may now say which of seven languages it is written in, and its
sentences are read with a voice for that language, or not at all. The app's own
text, and a tutorial that has not said, stay exactly as this paragraph
describes. The per-artefact field below is built for tutorials (phases 1–5,
11.9.2026) and awaits its live check, `TODO-provera.md` item 150; repertoire
comments and other text a user writes are still out of scope.

**Reading a user's own text in the language they wrote it in.** The owner's
rule, given 8.9.2026 and recorded verbatim because it decides the shape: *the
only other language in this app is a place the user made — writing a repertoire,
a tutorial, a comment. If those are read through TTS they must not be read
through `en-*`, but through the service for that language. Serbian is never
needed by default.*

The **default** half of that is a fault and was fixed the same day: the voice
picker still asked for `['sr', 'hr', 'bs', 'sh', 'me']` after the app went
English-only, so an ordinary English machine reported `noVoice` and every
read-aloud button in the app was silent. It now asks for `en`.

The **per-artefact** half is not built, and this is the decision not to build it
before release. A tutorial sentence a trainer wrote in Serbian is read today by
whatever single voice the reader chose in Settings — which is the right voice
for that trainer and the wrong one for the English interface around it. Making
it per-string needs one of two things, and both are features rather than fixes:
a language field on the artefact (a schema change, an editor control, and a
migration for everything already written), or language detection per sentence
(a guess, and a wrong guess is a sentence read in the wrong phonetics with no
way for the reader to correct it).

What the release ships instead is honest and reachable: the Settings voice list
shows every installed voice, marks the ones meant for the interface, and lets
any of them be chosen. A trainer writing in Serbian picks a Serbian voice and
their material reads correctly. Written down here so the trade is a decision
rather than an oversight, and so that whoever builds it starts from the
artefact-field version — `SpeechService` already takes a language per call site
in everything but name.

**Monetisation beyond what exists.** Tiers, entitlements, quotas and the app's
billing service are built; the six open items in `docs/CENA-I-PRETPLATA.md` §7
are business decisions, not code, and they are better made against a month of
real measurements than against a guess.

**Superseded on 8.9.2026 — the app goes English-only.** The owner's decision:
the market is global and the Serbian audience too small to carry the format. It
does not add an i18n layer; the literals in `lib/` are replaced in place, which
is why the paragraph below is kept rather than deleted — the count in it is the
size of the sweep. `docs/GLOSSARY-EN.md` is the contract, the two anchors in
`docs/gates/` are the vocabulary, and `gate_english_ui` is what grades it. The
manual and the site are therefore written in **English**, not Serbian.

**„Trainer" stands, confirmed 8.9.2026.** Raised because „Coach" was used in
passing when the register rule was decided; kept because every identifier in
the schema says trainer, and a UI word that disagrees with the schema costs a
guess in every bug report. Settled, and not to be reopened by a later batch.

### The audience declaration — decided 8.9.2026

**The app ships as a General Audience product, 13+. It is not declared as
directed to children and does not enter Designed for Families.** The owner's
decision, with their reasons recorded because the declaration has to be
defensible later, not just made:

1. The product is a training and analysis tool for players and trainers —
   tutorials, mate in three, pawn endgames, PGN and Stockfish analysis. It is
   not a toy for pre-schoolers.
2. No unintentional appeal to children: no cartoon characters, mascots, jolly
   animations or childish slogans that would invite a reviewer to reclassify it.
3. The live room is a tool for trainers and clubs. The trainer or club organises
   the lessons and owns the relationship with the people they teach; the
   platform is the technical intermediary.
4. 13+ removes the obligation of verifiable parental consent, the restrictions
   on ordinary analytics, and the months-long store review that Designed for
   Families brings.
5. The Serbian parental-consent form is replaced by a standard general-audience
   clause in the English Terms of Service: the service is 13+, and parents or
   trainers who use it with minors take responsibility for supervision.

`AGE_OF_CONSENT` stays parameterised. It is good practice and, as below, it is
also still load-bearing.

### What the declaration requires of the code, which today contradicts it

Not legal advice — a lawyer signs the texts. These are facts about this
repository and the standard triggers, and they are the difference between a
declaration that survives review and one that does not.

**There is no minimum age anywhere in this codebase.** An eight-year-old can
create an account today. `chess_backend/services/ageService.js` defaults
`AGE_OF_CONSENT` to 16 — that is a *consent threshold*, not a floor — and
`routes/account.js` computes `minor = age < ageOfConsent()` and then
**accommodates** them: `parentConsentService` moves the relationship to
`awaiting_parent` and a parent confirms through a page this backend serves.

That machinery was built to let a child in. A 13+ declaration says the opposite,
and the two cannot both be true on the same screen. **COPPA triggers on actual
knowledge**, and an app that asks for a birth year has it — so „we declared
13+" does not answer for an account whose stored `birth_year` says eleven.
Making the declaration true means the age gate **refuses** under-13 sign-ups
rather than forking them into a parent flow. That is a small change to
`age_gate_screen.dart` and one guard on account creation, and it is a product
decision with legal weight, so it is not made here without being asked for.

**13+ does not clear the European Union.** The GDPR's own age for consenting to
an information-society service is 16, and member states may lower it as far as
13 — which is exactly why `AGE_OF_CONSENT` is configuration and defaults to 16.
So a fourteen-year-old in Germany still needs parental authorisation, whatever
the store listing says. The parental-consent machinery therefore gets
**re-pointed, not deleted**: it stops being „may this child be here at all" and
becomes „this 13-to-15-year-old is in a country that asks for a parent". The
code needs no new concept for that; it needs one changed question.

**The privacy policy, decided 8.9.2026.** `docs/politika-privatnosti.md` is
**untouched** and stays Serbian: it is a document with a valid signature for the
domestic frame, and editing it would spend that signature. The English version
for the global listing is a **new** file, `docs/privacy-policy-en.md`, shaped in
Phase 4 with the rest of the documentation. A lawyer's review of it for the
markets being entered is recorded as an **external release gate** — the last
thing before publishing, not a blocker on any code or any batch.

**`docs/saglasnost-roditelja.md` is retired, not deleted.** It carries a
lawyer's approval for Serbia with a date on it, and a superseded approved text
is evidence about what was shown to whom and when.

**The register of the English copy is part of the declaration.** An interface
that addresses „dete" in every second sentence reads as child-directed whatever
the listing says. The translation is in flight now, which makes this the moment
to set it: the copy speaks to a *player* and a *trainer*, and mentions a child
where the feature genuinely is about one — the parent report, the assignment a
student receives.

**Translating the app** — *replaced on 8.9.2026 by the English-only decision
above: the literals were replaced in place, and there is still no i18n layer.
The paragraph is kept as the reasoning; its last two sentences about a Serbian
manual no longer hold.* There is no localisation layer at all — no
`flutter_localizations`, no `.arb`, and roughly 1700 string literals carrying
Serbian diacritics in `lib/` alone, which undercounts the ones that happen to
have none. Adding i18n is a mechanical change across every screen plus a
translation pass plus a review, and it would consume this whole plan. It is
also not needed for the market this release is aimed at: the legal texts were
approved for Serbia, and the users are Serbian children and their trainers.
**The manual is written in Serbian for that reason too** — a manual in a
language the app does not speak helps nobody. When translation happens it
starts with the i18n layer, not with a document.

**Reorganising the app by function**, one home for everything the app produces,
and merging the analysis board with the room. This is the right instinct and the
wrong moment: it is a redesign, it would consume everything left, and the part
of it that actually hurts — two dialogs for one act, and screens whose names do
not say what they are — is Phase 1, and the part of it that a user actually
feels is answered by Phase 4. That is the owner's own argument and it is the
right one: **a manual that says which door a job is behind buys most of what
rearranging the doors would buy, for a fraction of the risk.** Written up here
so the instinct is not lost.

## Where the numbers stood when this was written

* App: **1744 tests, 1 skipped**, measured on `master` on 8.9.2026 with nothing
  else running. `flutter analyze`: 29 issues, all `info`, zero warnings.
* Backend: **958**, last measured 7.9.2026 with `.env` moved aside. Not
  re-measured for this document.
* Verification: 1037 items, 418 recorded. The 592 unrecorded are corrected in
  Phase 5 — most were walked before this recording system existed.
* Open on the board and unrelated to this plan: three design questions from the
  7.9.2026 reports — orientation as a property of a chain of beats, whether a
  beat may hold more than one task type, and a comment before *and* after a
  move. None is a fault; all three are recorded and none is in scope.
