# Preparation: its own screen, and a recording that becomes a tutorial

Written 27.9.2026 by the lead, on the owner's word. **Nothing is in code.**
The owner answered in the same conversation — „sa svim se slažem", and then
„slažem se sa sva tri" — so D1–D10 of §4 are his decisions, and D11 — the screen's shape, chosen from
sketches the same day — and D12 and D13 with them. What is still open
is in §8, each question beside the phase that needs its answer.

Paths: `APP` = `chess_app/lib/`, `BE` = `chess_backend/`, `T` =
`chess_app/test/`. Every line number was read on `master` at `295a2a91`.

## 1. The request

The owner, 27.9.2026, seven points about Teach → Preparation:

> 1) Dodati grafičko stablo poteza, kao i u drugim ekranima, i mogućnost
> označavanja polja (za sad imamo samo strelice)
>
> 2) Pitanje učitavanja pozicija ili celog stabla poteza iz Library i
> eventualne koristi za korisnika? … (isto ovo i za druge ekrane (recimo
> Analysis)
>
> 3) … ovde se može napraviti neka vrsta tutorijala sa naracijom korisnika.
> Tako napravljen tutorijal se može exportovati kao video i trebalo bi da može
> da se pošalje učeniku ili da se ubaci u domaći zadatak (trenutno ne može) …
>
> 4) Pitanje implementacije Speech to text servisa … sa mogućnošću korisnika
> da naknadno ispravi tekst … pa korišćenjem TTS-a da se isti tutorijal
> izgovori sa drugim sintetizovanim glasom.
>
> 5) Pitanje prevoda tutorijala … ovo omogućava korisniku sa slabim engleskim
> da napravi na svom jeziku i prebaci ga na engleski ili neki drugi jezik.
> Razmotriti mogućnost prevoda i tutorijala iz Tutorial Studia.
>
> 6) … Napraviti dizajn koji će da podržava ove funkcije, ali i koristiti
> dizajn drugih ekrana za elemente koji već postoje u drugim ekranima … Moja
> sugestija je da treba tabla da bude veća nego što je sada.
>
> 7) sve vreme treba imati na umu da ovaj ekran služi i za pravljenje drugih
> materijala (zadataka, analiza, pgn-ova...)

and, after the lead proposed that a recording be **converted** into an ordinary
tutorial, the three constraints this plan is built around:

> delovi (parts) ne pamte kada je povučena strelica ili označeno polje, već se
> stanje strelica i označenih polja menja sa potezom, pa bi to dovelo
> teoretski do stvaranja velikog broja delova sa istom pozicijom …

> isti tekst na različitim jezicima ili na istom jeziku biti izgovoren drugom
> brzinom nego što je to korisnik izgovorio, a takodje i cepkanje naracije na
> više manjih ako se povlače strelice ili označavaju polja

## 2. What exists, measured 27.9.2026

**Preparation is the live room's screen in a special mode.**
`APP/screens/chess_game_screen.dart` is 3871 lines; twenty of them name
`isStudio` or `roomCode == 'STUDIO'`. Two doors open it, both by
`AppRoutes.roomPath('STUDIO', role: 'host')`
(`APP/screens/home_screen.dart:1208`,
`APP/features/library/screens/library_screen.dart:771`). It opens a socket to
the server (`:989–998`) and joins no room on it (`:1014`), and its title reads
„Connecting..." until that socket is up. **Fourteen test files** pump the room
with `roomCode: 'STUDIO'`, 109 cases between them.

**What is on it today.**

| where | what |
|---|---|
| bar | „Start recording" (`prep-record-lesson`), ⋮ with „Export to Analysis" and „Settings"; while recording, a 48 px strip under the bar |
| left column, 300 | „Set up position", „Import PGN \| Export PGN", „Save position \| Save analysis", „Make exercise", a FEN field, then „Library" — the shared `LibraryList` with the chips All, Tutorials, Exercises, Positions |
| middle | evaluation bar, the board, the move strip, the engine's lines |
| right column, 300 | the move list in a **fixed 150 px box** (`MoveHistoryView`), „To main line", „Delete variation", the comment field, „Insert evaluation into comment", „Draw arrow" with five colours, „Undo arrow", „Clear all arrows", and a card „Solo practice — classroom is off" |

**The board is capped by a share of the window's height**
(`chess_game_screen.dart:2647`): the smaller of 62% of the height and 96% of
what two 300 px columns leave, times the board-size setting. With that setting
at its default:

| window | board today | what binds |
|---|---|---|
| 1920 × 1080 | 670 | the height share |
| 1200 × 800 | 496 | the height share |

The Tutorial Studio sizes its board from the room it is actually given — the
pane's height less 120, never more than the pane's width
(`APP/features/tutorial_studio/screens/tutorial_studio_screen.dart:983–990`).

**Two models of one tree.** The room and Preparation hold `MoveTree` /
`MoveNode` (`APP/move_tree.dart`, 795 lines, named in 25 files). Analysis, the
repertoire and the Tutorial Studio hold `AnalysisNode` (221 lines, named in 45
files). **The graphical tree draws `AnalysisNode` only**
(`AnalysisMoveTreeWidget`, drawn at `analysis_studio_screen.dart:1790`,
`repertoire_tree_panel.dart:215`, `tutorial_studio_screen.dart:700`). One
converter exists, and it goes through PGN: `readPreparedLine`
(`APP/features/analysis_studio/services/prepared_line.dart:43`), which is how
„Save analysis" and „Export PGN" leave Preparation today.

**Squares exist everywhere except here.** `SquareMark`, `[%csl]`, the board's
frame and the film's frame are built (`docs/PLAN-OZNAKE-NA-TABLI.md`).
`AnnotationMode.square` is switched on only in the Tutorial Studio
(`tutorial_studio_screen.dart:1195–1198`), through `BoardAnnotationBar`
(`APP/widgets/game_screen/board_annotation_bar.dart`: arrow, square, range,
colours, clear). Preparation's one button sets `AnnotationMode.arrow`.

**A recording made in Preparation** (phase 5b of `docs/PLAN-SESIJA.md`) is a
wav and a list of events stamped **by the audio's own clock**
(`APP/features/tutorial_studio/services/lesson_take.dart`). Three kinds, and
the server refuses any other (`BE/services/lessonRecording.js`,
`LESSON_EVENT_TYPES`):

| kind | written by | carries |
|---|---|---|
| `init` | the start, and every position loaded (`:1824`) | `fen`, `pgn` |
| `move` | a move on the board (`:2127`) | `fen`, `from`, `to` |
| `move` | a jump to a move in the list (`:2050`) | `fen` **only** |
| `arrow_drawn` | every change of the arrows (`:856`) | the whole list of arrows |

So **arrows are remembered twice** — in the timeline with their time, and on
their move in the tree, which the PGN writes as `[%cal]`. The tree as it stood
at „Stop" is **not** kept; the opening `init` has the tree as it stood at the
start.

**Its two readers do not read the same things.** The app's player
(`replayFrameAt`, `APP/models/recording_models.dart`) reads arrows. The film
(`applyEvent`, `BE/videoRenderer.js:533`) reads `arrows`, `squares` and `text`
from **any** event, and only `init` and `move` touch the position — so the
film already draws a change of marks that has no move behind it. A film is
drawn one picture a second, four when it has captions (`CAPTION_FPS`,
`videoRenderer.js:441`).

**What a recording can do**: be played, deleted, shared with one's own
students (`recording_shares`), and exported as a film
(`BE/routes/recordings.js:132–252`). In the Library its card has Play and
Delete (`library_screen.dart:300–315`). **It cannot be a homework item.**

**A tutorial gives each position one text and one set of marks.**
`filmBeatsOf` (`APP/features/tutorial_studio/services/tutorial_video.dart:76`)
makes one stop per node of a part's line; `tutorialVideoOf` (`:257`) turns each
into one event with the node's `comment`, `arrows` and `squares`. The owner's
first constraint is exact.

**A tutorial film is already timed by the voice.** With a synthesised voice
the server makes one clip per event and each beat lasts as long as its clip
(`BE/services/tutorialNarration.js`, `narrationPlan.js`: a breath of 0.6 s, a
wordless beat 2 s, a beat never over 60 s). With the trainer's own voice there
is **one marker per event** and the counts must match
(`recordingForFilm`, `BE/services/narrationUpload.js:279`), and the film's
signature must be the one the take was made over — position and sentence of
every stop; marks are deliberately outside it (`filmSignatureOf`,
`tutorial_video.dart:233`).

**The PGN reader loses a second comment without a word.**
`MoveTree.parsePgn` assigns the node's comment, arrows and squares at every
closing brace (`move_tree.dart:551–560`), so `12. Nf5 { one } { two }` is read
as „two". `parsePgnArrows` reads the first `[%cal]` of a comment. Nine files
know `[%cal]` or `[%csl]`.

**The server keeps a part as a position and a PGN** and has no PGN parser
(`BE/services/lessonSteps.js`; rule 13 of `CLAUDE.md`). `POST
/lessons/:id/clone` copies a tutorial with its parts and its language
(`BE/routes/lessons.js:395`). A tutorial may say it is in one of seven
languages (`BE/services/tutorialLanguage.js`).

**A tutorial reaches a student as its film**, alone or as a homework item, and
only once the film exists („Export the video first",
`tutorial_row_actions.dart:110`) — `docs/PLAN-TUTORIJAL-VIDEO.md`.

**From the Library onto the board** (`_putOnBoard`,
`chess_game_screen.dart:1496`): a tutorial becomes a stepper over its parts; a
position or a scan is loaded with whatever line it carries; an analysis and a
recording do nothing. Preparation therefore **writes analyses it cannot read
back**. Analysis itself opens on a position, a game or a whole tree
(`analysis_studio_screen.dart:74–86`).

**Translation exists outside the app only**: `tools/tutorial_translate/`
through `agy`, one item per title and per sentence, and a checker that compares
the chess notation of every item with its source token by token. The server
has a DeepSeek client (`BE/services/llm/deepseek.js`) that the tutorial from a
game and the review's words use.

**Speech to text exists nowhere.** No route, no provider, no key in
`.env.example`.

**Two vendors, as their own pages said on 27.9.2026** — read through a
summarising reader, so every figure is read again in phase 5 before it is
relied on:

| | Groq | Azure Speech |
|---|---|---|
| models | `whisper-large-v3`, `whisper-large-v3-turbo` | — |
| price per hour of audio | $0.111, $0.04 | not read |
| word and sentence times | yes (`verbose_json`, `timestamp_granularities`) | not read |
| file limit | 25 MB free, 100 MB paid | not read |
| Serbian | not listed by name; „multilingual" | `sr-RS`, **Cyrillic** |
| a vocabulary hint | `prompt`, 224 tokens | plain-text custom speech |
| already in this server | no | yes, as the voice (`BE/services/tts/azure.js`) |

A thirty-minute take is 57.6 MB as it is recorded (16 kHz, mono, 16-bit), so it
is compressed before it is sent wherever it goes.

## 3. The model on one page

```
  PREPARATION — its own screen                       from the LIBRARY
  one board · one tree · one „Save as…"              ───────────────────────────
     │                                               tutorial part  → with its line
     ├─ Save as… position · exercise ·               analysis       → with its tree
     │           analysis · PGN                      exercise,
     │                                               position, scan → the position alone
     └─ Record ──► RECORDING  (voice + timeline)
                     │   stays under Recordings: the master copy of the voice
                     │
                     ├─ Transcribe ──► sentences, each with its times;
                     │                 the text corrected by hand
                     │
                     └─ Make a tutorial ──► TUTORIAL, an ordinary one
                                              part   = a run between two jumps
                                              beat   = a sentence and the marks
                                                       that stand while it is said
                                              voice  = a copy of the recording,
                                                       one marker per beat
                                                │
                  ┌─────────────────────────────┼─────────────────────────────┐
                  ▼                             ▼                             ▼
          film, own voice             film, synthesised voice        Translate… ► a copy
          (the recording's times)     (each beat as long as          in another language,
                                       its clip)                     synthesised voice only
                  └──────── Send to student · homework item — as today ───────┘
```

**The rules by which a recording becomes beats.** Thresholds are phase 5's to
measure; the rules are the owner's decisions D5–D7.

- **R1. Text is cut at sentences and nowhere else.** A sentence is what speech
  to text returns between two sentence ends, with the time of its first and
  last word.
- **R2. The board's timeline is cut into stretches**: a time during which one
  position and one set of marks stood.
- **R3. A sentence belongs to the position standing when it ends** (D15,
  27.9.2026). A move played in mid-sentence does not cut the sentence. Until
  phase 5 measured it this read „the position that stood for most of it"; a
  trainer names a move and then plays it, so that rule put the sentence on
  the position before the move it names.
- **R4. On one position, a new beat begins when the marks at the end of a
  sentence differ from the marks at the end of the one before it**, or when the
  caption would pass its four lines. A beat's marks are the ones standing when
  its last sentence ended — so an arrow drawn in mid-sentence is on screen from
  the start of that sentence.
- **R5. A move nobody spoke over is still a beat**, wordless, because the line
  has to be seen. A position merely passed through on the way to a jump is not.
- **R6. A part ends where the board jumps** — where the next position is not
  one legal move from the one before. How the new part joins the film (new
  board, continues, returns) is what `partOpeningsOf` already answers.
- **R7. A move is derived from the two positions around it**, never read from
  the event: a jump stamps no squares, and a beat's position already answers
  for the move that made it.
- **R8. No clock is carried over.** With the trainer's own voice a beat's
  marker is where its first sentence begins. With any other voice a beat lasts
  as long as its clip, which is what `narrationPlan` has always done.

## 4. Decisions

### Answered by the owner, 27.9.2026

**D1. From the Library by what the entry is.** A tutorial part with its line;
a saved analysis with its whole tree; an exercise, a position and a scan as
the position alone — an exercise's line is its solution.

**D2. A recording becomes an ordinary tutorial.** Not a second kind of
tutorial in the list: every action on a tutorial would otherwise have to ask
which kind it is holding. The recording stays under Recordings.

**D3. Preparation is its own screen**, built from the parts the other screens
already use. The room's screen is for a live session and nothing else.

**D4. A position may hold several beats**, in the tutorial itself and
therefore in the Tutorial Studio too. Not several parts.

**D5. Text is cut at sentences; a mark or a move made in mid-sentence is
snapped to a sentence.** Accepted knowing an arrow may appear a few seconds
before it is mentioned.

**D6. No time is carried over from the recording** to a synthesised or a
translated voice.

**D7. A recording's film reaches a homework through the tutorial it becomes.**
No door of its own in the meantime; sharing a recording stays as it is.

**D8. A translation is a copy.** The source tutorial is never rewritten, and
only the seven languages whose moves can be said are offered.

**D9. Speech to text sends the recorded voice to an outside service**, and the
privacy policy has to say so before anybody but the owner uses it. The text is
the owner's and the lawyer's.

**D10. The order**: the screen (squares, tree, board), then speech to text,
then the conversion, then translation. Each is useful without the next.

**D11. The screen is variant C, with all five of the sketches' proposals** —
„Varijanta C, i da na svih pet predloga" (27.9.2026, after the fourteen
sketches of phase 0).

- **Nothing is behind a tab on a desktop window.** The board on the left; on
  the right the tree on top, and under it the comment and the engine's lines,
  side by side where the pane is at least 480 wide and one over the other where
  it is not. The Library is a drawer, opened from the bar.
- **Recording is said in the bar**: the clock, what is left, „Pause", „Stop
  and save", „Discard". „Library" and „Board ▾" stay in it, because a position
  loaded in mid-recording is part of the recording.
- **The evaluation bar stands beside the board.**
- **„Board ▾"** puts something on the board — „Set up position…",
  „Paste FEN…", „Import PGN…", „Starting position". **„Save as… ▾"** keeps
  what is on it — „Position", „Exercise…", „Analysis", „PGN", and „Open in
  Analysis".
- **The engine's lines are beside the comment**, not under the board.
- **On a phone** the board, the marking row and the move strip, then four
  tabs — Tree, Comment, Engine, Library — with the tree as notation; on its
  side, the strip and the marks beside the board.

**The board's size is the rule's, and the rule is the decision**: the height
the window has left after the bar and the two rows under the board, and never
more than the width the pane beside it leaves. What the sketch's arithmetic
gave, with a bar of 56, rows of 48 and gaps of 12:

| window | today | sketched |
|---|---|---|
| 1536 × 792 | 491 | 600 |
| 1200 × 800 | 496 | 608 |
| 900 × 700 | 269 | 440 |
| phone, 360 × 640 | 324 | 344 |
| phone on its side, 800 × 360 | not measured | 296 |

**These are a sketch's numbers, not the app's.** The real marking bar and the
real strip have their own heights, so phase 1 asserts the board **within 16 px
of the sketched size and never under today's**, and a worker who cannot reach
that says which row took the room rather than shrinking a row to fit.

**D12. Three things about the screen's controls** — „Slažem se sa sve tri
odluke" (27.9.2026), to what the lead had decided while writing phase 1's
brief.

- **An evaluation is never written into a comment on this screen.** The
  room's „Insert evaluation into comment" and the „[+0.30 / depth 24]" it
  stamps on an inserted engine line are not carried over: a comment here may
  become what a tutorial's voice reads out.
- **„To main line" and „Delete variation" are in the tree's menu**, as in
  Analysis, and not buttons of their own.
- **The marking bar is icons where labels do not fit**, their words in the
  tooltips: labelled from a width of 760, icons with the five colours from
  420, and under that one colour button that opens the five.

**D13. Material in and out, and the button that adds a beat** — „Slažem se sa
svih pet odluka i sa natpisom" (27.9.2026), to what the lead had decided while
drafting phase 2's gate.

- **„Position" keeps the board in front of the trainer and no line.** A line
  is kept by „Analysis".
- **The rows of the Library's drawer carry no actions.** Renaming, editing and
  deleting are the Library's.
- **„Open in Analysis" hands over a copy of the whole tree.**
- **A tutorial is walked from the bar** — „Part 1 of 2", back, forward, close
  — so it costs the board nothing.
- **A load replaces what is on the board without a question**, as today: a
  position loaded in mid-recording is part of the recording.
- **The button that adds a beat on a position reads „Add a sentence here"**
  (Q6 of §8, for phase 6).

**D15. The vendor, the sentence's position, and English** — „Idemo sa Groq, a
rečenica neka pripada poziciji na kraju, a slobodno napravi sintetički govor
za engleski", 27.9.2026, after phase 5's numbers:

- **Groq hears the recordings** (Q1). It is a new processor of a trainer's
  voice; the sentence in the privacy policy is the owner's and the lawyer's,
  before anybody but him uses it (D8 stands).
- **A sentence belongs to the position standing when it ends** (R3).
- **English is measured on the app's own voice**, because he teaches in
  Serbian and would not record a lesson in English.

**D16. The editor of several sentences on one position** — „Slažem se sa
svih pet preporuka", 27.9.2026, from the sketch `docs/skice/taktovi.html`:

- **A** — „Add a sentence here" is a button with words on the open card,
  under its text (the phone and Preparation likewise);
- **B** — a new sentence starts with the marks of the one before it;
- **C** — ✕ „Remove this sentence" only where the position has more than one,
  no question asked, and Undo brings it back;
- **D** — the phone's row of moves has a narrow „·2" chip for each later
  sentence;
- **E** — Preparation's comment box follows the open sentence, with ‹ › and
  the same button.

**D18. A voice copied from a recording is held to the positions of its
beats, not their words** — Q2, „Slažem se sa preporukom za Q2", 27.9.2026.
A take recorded *over* a tutorial is held to its sentences
(`filmSignatureOf`), because a rewritten sentence is a voice saying what the
screen no longer does. A tutorial made from a recording is the other way
round: its sentences were written *from* the voice, so a corrected spelling
does not make the voice wrong. Such a voice is signed with
`filmPositionsSignatureOf` — the position of every beat, in order — and
`saved_lessons.narration_follows` says which kind a tutorial's voice is. A
move replaced, a part moved, or a sentence added or removed still refuses it.

### The lead's, stated so they can be overruled

**T1. The new screen stands on `AnalysisNode`.** The graphical tree, its menu
and „Move variation earlier / later" then arrive as they are, and
„Save analysis" and „Export PGN" lose a round trip. What still takes the
room's model — „Make exercise" reads a `MoveTree` — is handed one read from the
screen's own PGN, and refused if a move did not replay (the rule of 6.9.2026).

**T2. Beats are kept in the part's PGN, as successive comments on one move**,
and in a saved tree's JSON as a list. The server stores a part's PGN as text,
so nothing changes there. A comment that holds only commands — a clock — is
not a beat.

**T3. A reader that knows nothing of beats sees the first**, and a writer that
knows nothing of beats writes the first and leaves the rest alone. (Until
phase 6 was prepared this said „the sentences joined, the marks of the last";
see there for why it changed.)

**T4. The voice is copied, never shared.** A tutorial's deletion removes its
own narration file; if that file were the recording's, deleting a tutorial
would delete the only copy of a voice.

**T5. The conversion runs in the app**, like the skeleton of a tutorial from a
game: the server has no PGN parser and does not get one. The server's part is
to attach the voice.

## 5. What goes, and what stays

**Goes**: Preparation inside the room — the twenty `isStudio` branches, the
socket it opens and joins no room on, „Connecting..." in its title; the fixed 150 px
move list; „Draw arrow" and the two buttons under it, for the marking bar the
Tutorial Studio has; the card „Solo practice — classroom is off"; the four
paired buttons of the left column, for one „Save as…"; „Set up position", the
FEN field and „Import PGN", for one „Board ▾"; the Library's column, for a
drawer; the 48 px recording strip under the bar, for the bar itself; the
evaluation bar over the board, for the one beside it; the engine's lines under
the board, for a place beside the comment (D11).

**Stays, untouched**: the room as a live session — its board, its voice, its
tree model and its socket; `LessonTake` and the audio's clock; a recording, its
player, its sharing and its own film; the rule that `uploads/` is never swept.
The room does **not** get squares or the graphical tree in this plan (§7).

**Stays, and gains**: the tutorial — several beats on a position; the Library
card of a recording — „Make a tutorial"; the tutorial's row — „Translate…".

## 6. Phases, each with its gate

Phases 1–4 are the screen. Phase 5 is a measurement and may run beside them.
Phase 6 stands alone. Phase 7 needs 5; phase 8 needs 6 and 7; phase 9 needs 6.

Every brief carries: *If you believe a test in the gate is wrong, stop and say
so in the report — do not work around it.* Every gate is proved by mutation
before it is believed, and every mutation is chained to its run with `&&`.

### Phase 0 — the counts, and the screen drawn before it is built [lead]

1. The baseline, measured in a worktree with nothing else running: the app
   suite, the `analyze` list against the 22 known infos, the backend with
   `.env` moved aside and with a throwaway cluster. `pub get` before anything
   formats.
2. **Two or three sketches of the screen, as PNG**, at the owner's window
   (1536 × 792 — his 1920 × 1080 at 125%), 1200 × 800, 900 × 700 (900 is the
   narrowest Windows window), and a phone at 360 × 640 and on its side. The
   owner chooses from pictures. Each sketch says where the board, the tree,
   the marking bar, the Library, „Save as…" and the recording are, and how
   large the board is at each size.

**Gate**: the counts are written in §9; the owner's choice is written in §4 as
D11, with the board's size at each window — those numbers become phase 1's
assertions.

**The sketches were drawn 27.9.2026 and sent to the owner** — fourteen PNGs
from one page, `docs/skice/priprema.html`, which computes the board by one rule
for every window (`?v=A|B|C|PU|PS&w=…&h=…&s=idle|rec|menu|lib`). The counts of
item 1 were measured the same day and are in §9.

| variant | beside the board |
|---|---|
| A | the Library in a column on the left where the board keeps its size, otherwise in a drawer; on the right one pane with the tabs Tree and Engine, the comment under them |
| B | one pane with the tabs Tree, Library and Engine, the comment under them |
| C | nothing behind a tab: the tree on top, the comment and the engine's lines under it, the Library in a drawer |

**The board is the same in all three**, because the rule is the same: the
height the window has left after the bar and the two rows under the board, and
never more than the width the pane beside it leaves.

| window | today | A, B and C |
|---|---|---|
| 1536 × 792 | 491 | 600 |
| 1200 × 800 | 496 | 608 |
| 900 × 700 | 269 | 440 |
| phone, 360 × 640 | 324 | 344 |
| phone on its side, 800 × 360 | not measured | 296 |

**What the sketches propose beyond §5**, each for the owner to accept or
refuse with the variant:

- **Recording is said in the bar, not in a strip under it** — the clock,
  „Pause", „Stop and save" and „Discard" take the bar's place — so the board
  does not change size when a recording starts.
- **The evaluation bar stands beside the board** (`VerticalEvalBarWidget`
  exists), so switching the engine on does not change the board's size either.
- **„Board ▾"** holds what puts something on the board — „Set up position…",
  „Paste FEN…", „Import PGN…", „Starting position" — beside **„Save as… ▾"**,
  which holds what keeps it.
- **The engine's lines leave the place under the board**: with the board at
  the height it now has there is no room under it.
- On a phone the tree is shown as notation under four tabs — Tree, Comment,
  Engine, Library — and the bar keeps „Record" and ⋮.

**The owner chose C and accepted all five, 27.9.2026** — D11 of §4. The lead
had recommended C: while a trainer is talking, nothing he needs is behind a
tab, and the Library, which is used in bursts, costs no width while it is
shut.

### Phase 1 — the screen's core [implementer] — built, graded and merged 27.9.2026

**Measured by the lead in the worktree, with nothing else running**: the app
suite **4266 passed, 1 skipped** — 4197, the layout rule's 12, the screen's
52 and the worker's 5 for an engine line played into a tree, as predicted
before the run; `flutter analyze` the same 22 infos. Thirteen mutations of the
screen, each red on its own case. Merged into `master` on the owner's word
(„merguj i pokreni radnika").

**The worker returned 61 of 62 and said why**, which is what the brief asks.
What grading changed:

- **A case of the gate could not pass, and that was the gate's fault.** The
  tree's card insists on 516 px — a header and a body of 420 at most — so at
  900 × 700 the engine's lines were pushed off the window. The card now has
  an optional `fills`, off for every caller it had, and takes the height it
  is given; the comment and the engine's lines each scroll in a box of their
  own (270 side by side, 300 one over the other).
- **The worker bent behaviour to a test's timer, and said so**: the engine's
  switch asked the engine nothing until the next move, because the question
  is debounced by 180 ms and a case that ended with the engine on left the
  timer behind. The fault was the gate's helper, which now waits past the
  debounce; the switch asks at once, as in Analysis.
- **No case could see what the engine was asked**, so that change had been
  green. The screen takes an `engine`, and two cases hold what it is asked
  on a switch, on a move and on a jump.
- The engine asked for one line whatever the reader's setting; it follows
  the setting now.

**A mutant that changes nothing is not a survivor**, again: the first
mutation of the landscape's evaluation bar replaced an empty box with a wider
one, and `LandscapeBoardLayout` gives that place its own width whatever is
drawn in it. The one that matters — no place at all while the engine is off
— fails all four landscape sizes.

**Flagged by the worker and not acted on**: the engine's glue is a third
copy of what Analysis and the room each hold privately
(`preparation_engine.dart`), and the phone's pinned tabs repeat the shape of
the studio's private ones.

**Rendered and looked at**, six pictures from the app's own code at the
owner's window, 1200 × 800, 900 × 700 and the phone both ways; sent to the
owner. Live items `[250.1]` onward are written when the screen can be
reached, in phase 4.

*As briefed:*

**Where it stands.** Branch `priprema-faza-1`, in a worktree. The lead wrote
the layout rule (`lib/features/preparation/services/preparation_layout.dart`,
12 cases, seven mutations each caught by its own case) and the gate
(`test/preparation_screen_test.dart`, 50 cases: 47 red on a screen that draws
nothing, each naming what is missing, and 3 green that were each made to
fail). The brief is `docs/briefs/BRIEF-PRIPREMA-FAZA1.md`.

**What the real rows under the board turned out to be**: the marking bar 56
and the move strip, dense, 48 — 104 with two gaps of 4, not the sketch's 112.
So the rule gives **608** at 1536 × 792, **616** at 1200 × 800 and **442** at
900 × 700, each within 16 of the sketch and over today's. The evaluation
bar's place is 22 + 8.

**The marking bar has three densities**, because the studio's labelled bar
with „Undo" beside it needs about 760 px and the board is 608: labelled from
760, icons with the five colours from 420, and under that one colour button
that opens the five. Both additions to `BoardAnnotationBar` are optional and
defaulted to what it does today.

**Decided by the lead in the brief and confirmed by the owner the same day**
(D12): no evaluation in a comment, „To main line" and „Delete variation" in
the tree's menu, icons on the marking bar where labels do not fit.


`APP/features/preparation/`, in the shape of D11: the board with the
evaluation bar beside it, under it the marking bar (arrow, square, range,
colours, undo, clear) and the move strip; on the right the tree in both of its
views, and under it the comment and the engine's lines. On a phone, the four
tabs. On `AnalysisNode`. No socket. Not yet reachable from the app — phase 4
opens it.

**Gate** `T/preparation_screen_test.dart`, at every size phase 0 names:

- the board is **a square** — width equals height, measured, on Windows and on
  Android (a board clipped is not a board that overflows);
- the board is within 16 px of D11's size at each window and never under
  today's, and nothing overflows;
- **the board is the same size with the engine on and with it off**;
- on a desktop window the tree, the comment and the engine's lines are all on
  screen at once — nothing is reached through a tab;
- a variation played shows in the tree, and the tree's menu has what Analysis's
  has;
- a square marked is on the node and in the exported PGN, and comes back from
  it;
- the screen works with a client that fails every request — it needs no
  server to move a piece;
- text that must be read is measured with `didExceedMaxLines`.

Source guard: the new folder names no socket (read by structure, not by text).

### Phase 2 — material in, material out [implementer] — built, graded and merged 27.9.2026

**Merged on the owner's word** („merguj, ostavi kartice kakve jesu, kreni
sa fazom 3"). The gate is `chess_app/test/preparation_material_test.dart`,
27 cases; the draft that stood in `docs/gates/` is deleted, the test being
its one home now. App **4295 passed, 1 skipped**, a full run on the branch
with nothing else running, twice; analyze the same 22. Fourteen deliberate
faults, each red on its own case. The worker returned 19 of 24; three of
the five were faults of the gate (`docs/LESSONS.md`, 27.9.2026, phase 2).

**Left as it is, on the owner's word**: the drawer's rows are the
Library's own cards, 132 px tall, so about three show at 1536 × 792.

**Seen and not built**: a phone held on its side has the narrow bar
(title and ⋮); the engine's glue is the third copy of that code in the
app; the phone's pinned tabs repeat the studio's private ones.

**Decided by the lead while writing it, and confirmed by the owner the same
day (D13):**

- **„Position" keeps the board in front of the trainer and no line.** The
  room's „Save position" keeps the *starting* position and the whole line
  under the name of a position; here a line is kept by „Analysis", and D1
  already loads a position alone.
- **The drawer's rows carry no actions.** Renaming, editing and deleting are
  the Library's; the drawer puts things on the board.
- **„Open in Analysis" hands over a copy of the whole tree**, where the
  room's „Export to Analysis" carries only the position.
- **A tutorial is walked from the bar** — „Part 1 of 2 · title", back,
  forward, close — and not from a row over the board, which would cost the
  board its size.
- **Kept as the room has it**: what is on the board is replaced without a
  question, because a position loaded in mid-recording is part of the
  recording and a question would interrupt the voice.


**In**: „Board ▾" — „Set up position…", „Paste FEN…", „Import PGN…",
„Starting position" — and the Library's drawer with D1 — the tutorial's stepper over its parts, an analysis with its tree, an
exercise or a position alone, the side asked first where nobody set it
(`settledFen`); the drawer shuts when a row has been put on the board.
**Out**: one „Save as… ▾" — position, exercise, analysis, PGN, „Open in
Analysis" — each through the door that exists (`promptSaveAnalysisDialog`,
`PgnExporterService`, the exercise sheet, „Save position").

**Gate** `T/preparation_material_test.dart`: one case per kind of entry,
asserting **what is on the board and in the tree** after the tap, not which
method was called; an exercise's solution is nowhere on the screen; every
„Save as…" asserts on the request sent (the client is faked, not the method);
a line that does not replay is refused with its count. The fixture carries
`%clk` comments and a variation, as the owner's own games do.

### Phase 3 — recording here, and squares in the timeline [lead: server and readers; implementer: the screen] — built, graded and **merged into `master` 27.9.2026**

**Where it stands.** Merged on the owner's word („merguj fazu 3",
27.9.2026) as `c446f0ec`; the brief is `docs/briefs/BRIEF-PRIPREMA-FAZA3.md`.
Every number below was measured again on the merged tree.

| measured 27.9.2026 on the merged tree, nothing else running | |
|---|---|
| app, full suite | **4336 passed, 1 skipped** (4295 + 5 readers and player + 35 the screen's gate + 1 the phone's tabs) |
| `flutter analyze` | the same 22 infos |
| backend without a database | **1778** (1772 + 6) |
| backend with a database | **1936**, measured on a throwaway cluster |
| deliberate faults | 30 of 30 caught: 4 server, 5 reader and player, 21 the screen |

**No server source changed**: the judge already keeps whatever an event's
`data` holds and the film already draws `squares` from any event. The server
is not restarted for this phase.

**What grading changed.** The worker returned 29 of 30 and named the thirtieth
as the gate's fault, rightly: the gate's microphone kept one stream for every
take, and a stream is listened to once. On grading: five cases added for ways
onto the board the gate had not walked („Undo", a move played again, a deleted
variation, a phone on its side, two taps on „Record"); **two taps on „Record"
started two takes** — the server is asked before the take exists — and the
screen now refuses the second from the tap until the take exists; and a
picture of the real screen read „Commen" on the phone's second tab, a fault of
phase 1, fixed with a case of its own in phase 1's gate.

**D14, the owner, 27.9.2026: „Slažem se sa sve tri odluke."** —

- **The marks are what the latest event said, whatever its kind.** That was
  the film's rule already; the player read arrows from `arrow_drawn`
  alone, so a step to a move that holds an arrow would have replayed bare
  where the film drew it. Every event the screen writes therefore carries
  the marks of the board it leaves behind.
- **While a take runs the bar gives up „Save as…" and ⋮**, as the sketch
  has it; on the narrow bar ⋮ stays and holds only what puts something on the
  board.
- **On the narrow bar (under 840 wide) a tutorial is walked from ⋮ while a
  take runs**: 360 px do not hold the stepper and the recording's controls
  together. With no take running it is walked from the bar, as in phase 2.

**Seen and not built**: a turn of the board is not an event, so a lesson
recorded from Black's side replays from White's — as in the room today, and the
server would refuse a fourth kind; the recording's state stands at the right
of the bar, where the sketch drew it at the left with the word „Recording".

*As planned:*

The take, its title, its upload and the rule that the screen cannot be left
while a voice is being recorded — moved, not rewritten. What the strip under
the bar said is said **in the bar** (D11), with „Library" and „Board ▾" still
in it. An event of a
change of marks carries `squares` beside `arrows`. The kinds stay three.

**Gate**: **one fixture file, two readers** —
`chess_backend/test/fixtures/lesson_timeline.json` is replayed by the app's
`replayFrameAt` and by the film's `applyEvent`, and the two must answer the
same position, arrows and squares at every millisecond the fixture names. The
server's judge keeps `squares` and still refuses a fourth kind. A recording
made before this phase still replays. **The board is the same size before
„Record" is pressed and after**; a position loaded from the drawer while a
recording runs is an `init` in its timeline.

### Phase 4 — the doors change, and the room loses Preparation [lead] — built and **merged into `master` 27.9.2026**

**Where it stands.** Merged on the owner's word („merguj fazu 4 i pushuj",
27.9.2026) as `d458a56c`, and pushed. No server source changed.

| measured 27.9.2026, nothing else running | |
|---|---|
| app, full suite, on the branch and again on the merged tree | **4335 passed, 1 skipped** — predicted before the run and compared by name |
| by name | 17 gone, 16 new: 12 deleted with what they tested, 11 added, 5 renamed |
| `flutter analyze` | the same 22 infos |
| backend | untouched; 1778 measured again on the merged tree, without a database |
| deliberate faults | 3 of 3 caught, each on its own case; the other seven cases of the gate were watched red on master |

**What was built.** `AppRoutes.preparation` (`/preparation`) builds
`PreparationScreen` for the signed-in account; Teach's card and the Library's
„New exercise" push it. The room lost every branch that asked for the code
`STUDIO`, its recording (the take, the strip, the pop guard, three constructor
seams) and the socket it opened without joining — 400 of its 3871 lines.
`leadsRoom`, `canDriveSharedBoard` and `mayTeachInRoom` lost `isStudio`.

**The tests, by what each was protecting.** Sixteen files pumped the room as
`STUDIO`, not the fourteen counted in §2.

| file | what it protects | what happened |
|---|---|---|
| twelve files (`room_drawing`, `room_library`, `room_prepared_line`, `room_save_position`, `room_drawer_button`, `library_grid_3b`, `library_master_detail`, `exercise_library_own`, `part_titles_shown`, `tutorial_versions`, `landscape_screens`, `move_tree_semantics_orphan`) | something the **live room keeps** — its column, its arrows, its doors, its ☰ | re-seated on whoever opened the room (`test/support/trainer_room.dart`), no assertion changed but one word: a trainer's button reads „Draw arrows" |
| `lesson_recording_ui_test` (8) | the room's recording | deleted with it; each case is named beside its successor at the head of `preparation_recording_test.dart` |
| `board_control_rules_test` (2), `room_teaching_tools_test` (1), `voice_on_request_test` (1) | what `isStudio` excused | deleted, with what they protected and where it is held now written in their place |
| `room_presence_title_test` (1), `landscape_screens_test` (4) | unchanged | renamed: they were named for Preparation |

**Found by the phase** (rule 14 — the feature that wakes a fault is the one
that makes it reachable): swept for the screen reader's rule, the new screen
sent a node no parent lists when „Square", „Undo" or „Clear marks" showed its
tooltip. `Tooltip` around a button hangs the popup from whatever node encloses
the bar, and the framework does not always send that node again. Each tooltip
in the marking bar now has a container of its own. The bar alone was clean in
every density and mode; only the screen showed it.

**Not done here, and said**: the live-check items that reach a room feature
through „Teach → Preparation" (`docs/TODO-provera.md`, „Sesija — Preparation"
and [187.6], [249.1], [249.2]) still name the old path. They are not reworded,
because the QA tool matches an item by its text; they are sorted in phase 10.

*As planned:*

The Teach card and the Library's button open the new screen. The `isStudio`
branches and the unused socket leave the room. The fourteen test files are
moved or rewritten **openly**, each with what it was protecting written above
it. The manual's page (`site/mislisha/manual/preparation.html`) and the
glossary follow.

**Gate**: `'STUDIO'` is grepped as a string literal in `lib/`, `test/` and
`site/`, and every hit that remains has a reason written beside it; the app
count is predicted before the run and compared by test name, not by total; the
room's own tests are green **untouched**. It is
`chess_app/test/preparation_doors_test.dart`, ten cases; one literal remains,
in that file, which enters a room by the old code to show it is an ordinary
room.

### Phase 5 — a measurement: speech to text on real recordings, and the rules on paper [lead, owner] — measured 27.9.2026

**Where it stands.** Measured on four of the owner's recordings in Serbian
(„Proba 1"–„proba 4": two with a headset and one with a laptop's microphone
on Windows, one on a phone) and on an English text spoken by the app's voice.
The scripts are `tools/stt_measure/` (`azure.js`, `groq.js`, `beats.js`,
`english.js`); what a vendor returned is kept under `tools/stt_measure/out/`,
which git ignores — a transcript is what somebody said. **Still owed**: the
price read from a bill, a recording with the better microphone, and the
owner's correction of one transcript, which is the only exact count of words
heard right in Serbian.

**Serbian, the same four recordings to both vendors.**

| | Azure fast transcription, `sr-RS` | Groq, `whisper-large-v3` |
|---|---|---|
| set up beforehand | nothing — the voice's key and region | a key |
| script | Cyrillic only; `sr-Latn-RS` is refused (400) | Latin; one segment of one recording in Cyrillic |
| squares, as written | „ц 4", „це 5", „ф с" | „E4", „C5", „f7" |
| a played move's square heard within 8 s of the move — a floor | 2 of 17, 6 of 11, 11 of 19, 7 of 19 | 4 of 17, 9 of 11, 14 of 19, 10 of 19 |
| a time on every word | yes | yes |
| times running backwards | never | once to three times a recording, by 20–260 ms |
| what comes back as a sentence | up to 30 s and 50 words | a few seconds, cut where he pauses |
| size sent, of 4.5–5.6 MB recorded | the recording as it is | 1.0–1.9 MB, as FLAC |
| the answer took | 3.3–5.5 s | 1.3–1.6 s |
| a list of words to expect | accepted, and changed nothing | not tried |

Azure's newer mode (`enhancedMode`) refuses Serbian by name and, left to
guess, answered in Russian, Serbian and Czech by turns. Azure's custom speech
is set up on its website and serves real-time and batch transcription, not the
fast one measured here; it was not tried.

Groq's cheaper model, `whisper-large-v3-turbo` ($0.04 an hour against $0.111,
as its page says), read „Proba 2" and „proba 4" as well as the larger one, in
0.9 s, with no Cyrillic segment. **Which of the two models** is for phase 7 to
settle on the corrected transcript.

**The sound.** Every recording made on Windows is quiet — its loudest sample
at −26, −24 and −20 dBFS — with the same near-silent background on two
different microphones; the phone's peaks at −2.5. Raising „Proba 1" by 22 dB
changed almost nothing in what Azure heard, so the level is not what costs
words. It is a fault of the capture on Windows all the same, and a student
would hear it. **Not investigated yet.**

**English, on the app's own voice** (`en-US-JennyNeural`, 184 words, 70 s, 23
squares): Azure `en-US`, Groq large and Groq turbo each returned **the same
182 words right of 184**. The two differences are „centre" written „center"
and „a5" heard as „f5" by all three — the voice reads „a" as the article. A
synthetic voice is steadier than a person, so this is the best either does on
chess English, not what it will do on a recording.

**R1–R8 applied**, with Groq's text, all four recordings together:

| R3 as | sentences that name a played move | on that move's position | before it | after it | beats | wordless |
|---|---|---|---|---|---|---|
| the position that stood for most of it | 34 | 16 | 17 | 1 | 96 | 31 |
| **the position standing when it ends** (D15) | 34 | **25** | 6 | 3 | 99 | 36 |
| … or within 1 s after its end | 34 | 19 | 6 | 9 | 98 | 37 |
| … within 2 s | 34 | 16 | 4 | 14 | 97 | 35 |
| … within 3 s | 34 | 19 | 1 | 14 | 95 | 32 |

Looking past the sentence's end makes it worse at every distance tried, so R3
has no threshold. Per recording, with R3 as decided: 1, 5, 2 and 2 parts —
„Proba 2", with its fifteen steps through the line, is the five; the longest
caption is 160 letters where four lines hold about 168; a position merely
passed through on the way to a jump stood for up to 2.4 s.

**What the numbers say about the rules.** About a third of the beats are
wordless with either rule: a trainer plays several moves inside one sentence,
and R5 shows each of them. With Azure's sentences it was two thirds, which is
a reason for the vendor as much as the words are. **R1 stands only on a
vendor that cuts where the speaker pauses.**

*As planned:*

No app code and no server code. A script under `tools/`.

**Needs from the owner**: three of his own recordings — one in Serbian, one in
English, one with many arrows and jumps — and the word that they may be sent to
both vendors for this measurement.

**Measured, per vendor**:

| what | why |
|---|---|
| chess words heard right, on a sample the owner reads | the text has to be worth correcting |
| which script Serbian comes back in | a tutorial is `sr-Latn` or `sr-Cyrl` |
| times per word, present and never running backwards | R3 stands on them |
| the size sent after compression, and the time the answer took | the 25 MB limit |
| the price of an hour, read from the bill | §2's table is a page, not a bill |

**Then R1–R8 applied by the script**, and counted: beats per position,
sentences that straddle a move, wordless beats, parts made by jumps, the
longest caption, and how long a position was passed through on the way to a
jump.

**Gate**: the tables are written into this file; the owner chooses the vendor
(Q1) and accepts or changes the thresholds. If the numbers say a rule is wrong,
the rule changes here, before phase 8 is briefed.

### Phase 6 — several beats on one position [implementer, the whole phase — on the owner's word of 27.9.2026, „pokreni izvođača"; the plan had deep-debug for the model] — built, graded and **merged into `master` 27.9.2026** (`docs/briefs/BRIEF-PRIPREMA-FAZA6.md`)

**Where it stands.** On the owner's word („Kreni sa pripremom faze 6"), while
phase 1 was being built: every reader, writer and copier was listed, the model
was decided, and three gates were drafted in `docs/gates/` —
`node_beats_test.dart` (the model, both PGN writers and the reader, the saved
tree, the copiers, 400 random trees through every door, a source guard),
`tutorial_beats_film_test.dart` (the film's walk, its events, its signature,
the map of the parts) and `film_beat_event.test.js` (the renderer).

**Compiled and run against `master` on 27.9.2026**, in a worktree:

- the two Dart gates fail to compile on the contract's own names and on
  nothing else (`NodeBeat`, `beats`, `lastBeat`, `addBeat`, `removeBeatAt`,
  `rootLike`, `TutorialBeat.at` / `of` / `say`, `currentAt`) — no name they
  take from `master` is wrong;
- a copy with one beat to a position, run on `master`: the one-beat PGN and
  the tree's signature are the gate's literals, the film's signature
  (`71d5d9d2…`) is now the third, and **all 400 random seeds pass every door**
  — the harness can pass, so a red on the branch is the beats;
- the source guard finds **five** hand-overs on `master` (`section_split.dart`
  twice, `step_tree.dart`'s `_convert`, `tutorial_draft_controller.dart`,
  `tutorial_tree.dart`) — the list the phase empties;
- the server's gate: 4 pass, 1 fails, the one it is for (`rewound` cleared by
  a `beat`).

**A sixth copier the table had missed**: `_joinOnto`
(`pgn_tutorial_export.dart`), which writes a tutorial out as one game and
glues a continuing part's sentence onto the join's comment and its marks onto
the join's with `.add` — the guard cannot see it, because it builds no node.
**The lead's rule, stated so it can be overruled**: the continuing part's
beats become further beats of the join, and a first beat with no words and
the marks of the beat before it — the copy a cut leaves — adds nothing. A
tutorial written out as a game then comes back in as the stops it had. Two
cases in `tutorial_beats_film_test.dart` hold it; the two export tests that
exist (`pgn_tutorial_export_test.dart`, „a joined part's own sentence lands on
the position it describes" and „a drawing that both parts carry is drawn
once") stay true under it. The editor's gate is not written yet: it waits
for the owner's answers to the sketch.

**The editor's gate is written, 27.9.2026**, after D16:
`docs/gates/sentence_editor_test.dart` (22 cases: the model's one home for a
new sentence, twelve in the Tutorial Studio, four on the phone, five in
Preparation) and `docs/gates/preparation_recording_beats.part.dart` (one case
for the timeline group of `preparation_recording_test.dart`). The contract is
at the head of the first. It asserts on what is **saved** — the studio's one
save request, read back through `readStepTree` — and on Preparation's tree,
not on what is drawn.

Proved as far as `master` allows: the gate fails to compile on `addBeat` and
`beats` only; a probe built from its own helpers opens the studio on a
desktop and on a phone, walks the phone's row, saves and reads back, and
steps Preparation to 3. Bb5, all green on `master`; the recording case, which
needs no new API, runs on `master` and goes red exactly at the missing
`prep-add-sentence`, after the move and the arrow were recorded. Two faults of
the lead's own were found that way: the phone's row is a lazy list, so a
helper that only looked read three chips of seven (both helpers now scroll
it); and a platform override reset in a teardown is checked before the
teardown runs (the phone's cases are a `TargetPlatformVariant` now).

**Three rules of the lead's in it, stated so they can be overruled**:

- **Preparation has no undo of its own**, so C's „Undo brings it back" is a
  message there: „Sentence removed." with an „Undo" action.
- **The move strip walks moves, as today**, and a step onto a position opens
  its first sentence; sentences are walked by their cards, ‹ › and „·2".
- **„A new sentence" has one home**, the model's
  `addBeat(after:, keepMarks: true)`; neither screen copies marks by hand.

Not held by the gate, and left to grading: the line that joins a later card
to its position's first, and the gate's own mutation round, which needs the
phase built.

**Built and graded 27.9.2026.** The implementer returned 4679 of 4793 and
named the rest as the gate's, rightly: `node_beats_test`'s random fixture
guarded only the *added* beats against being empty, so a position whose
**first** beat was empty with others after it asked for a round trip the
model's own rule forbids (an empty beat is not written) — 111 seeds; two
editor cases asked for the same (`['', …]` back); and a SnackBar's „Undo" was
tapped 50 ms into its slide, below the window. All three fixed in the gate,
each with a comment. Grading then:

- **nine mutations**, each red on the right case — the writer, the reader,
  the signature, `keepMarks`, the board drawing the first sentence,
  Preparation's stamp, the join both ways, and the bare-board check (which
  survived first and got its case in `preparation_material_test.dart`);
- **three faults found by walking the doors**, each with a case watched red:
  removing an earlier sentence of the open position opened the wrong one
  (the controller used „the one before the removed one" for every removal);
  in Preparation removing the open sentence, and its Undo, changed the board
  with no `arrow_drawn` in a running take; and `_boardIsBare` read the first
  sentence's marks only;
- the worker's one rewrite of an existing test —
  `tutorial_tok_test.dart`'s window raised from 1000 to 1200 px tall,
  because the open card is one row taller with „Add a sentence here" — was
  read and kept: the check it protects (every card reachable) holds.

Measured on the branch with nothing else running: **4796 passed, 1
skipped** (4335 + 456 in the gates + 2 of the worker's + 3 of grading), backend
**1784** without a database, analyze the same 22 infos. Live items
[250.10]–[250.13] in `docs/TODO-provera.md`.

**The model.** `NodeBeat` — a sentence, its arrows, its squares — lives beside
`ChessArrow` in `lib/move_tree.dart`. Both tree models hold `beats`, never
empty, and their `comment`, `arrows` and `squares` **read and write the first
beat**, so every screen that knows nothing of beats goes on working on the
first and cannot flatten the rest. An empty beat is not kept, except as the
only one a position has.

**The owner agreed to the model on 27.9.2026** („Slažem se sa modelom").

**T3 is changed by this, and says so**: a reader that knows nothing of beats
sees the **first**, not the sentences joined with the marks of the last. A
joined view has no honest answer to „which beat did this edit change".

**Written byte for byte as today where a position has one beat** — in the PGN,
in a saved tree's JSON (the first beat stays in `comment`, `arrows`,
`squares`; `beats` holds the rest and is absent when there are none), in the
tree's signature and in the film's. So a stored part is still written back as
the text it was read from, and every narration already recorded still follows
its tutorial.

**What was found, reading.**

| where | what it does today | what it has to do |
|---|---|---|
| `MoveTree.parsePgn` (`move_tree.dart:551`) | a second comment on a move **replaces** the first, arrows and all | each comment is a beat; one that holds only a clock is not |
| `treeSignature` (`step_tree.dart:129`) | reads `comment`, `arrows`, `squares` | reads every beat — **or an edit of the second sentence is invisible to it, and the next save writes the part back as the text it had stored** |
| `copyTree` (`step_tree.dart:114`) | through `toJson` / `fromJson` | right once the JSON carries beats |
| `_convert` (`step_tree.dart:63`) | copies the three fields from the room's node | copies every beat |
| `tutorialTreeOf` (`tutorial_tree.dart:75`) | copies the three fields into the family drawn in the Tree tab | copies every beat |
| `section_split.dart:50`, `:198`, `tutorial_draft_controller.dart:400` | a part opened on a fork's position takes that position's marks and not its words | takes the marks of its **last** beat, one beat, no words |
| both PGN writers (`move_tree.dart:287`, `pgn_exporter_service.dart:206`) | one comment to a move | one comment to a beat, the clock once |
| `exportWithSpans` and the studio's PGN tab | one comment span to a move | one to a beat |
| `beatsOf` (`tutorial_beat.dart:103`), drawn by the Flow panel, the phone's layout and the map | one stop to a position | one to a beat, with its place inside the position |
| `tutorialVideoOf` (`tutorial_video.dart:257`) | `init` or `move` for every stop | those for a position's first beat, `beat` for the rest |
| `partOpeningsOf` (`tutorial_video.dart:144`) | a part opens where `index == 0` | where `index == 0` **and** it is the position's first beat |
| `applyEvent` (`videoRenderer.js:533`) | clears „Back to the position after …" at every event | **keeps it through a `beat`** — the second sentence on a position the film went back to would stand over „Starting position" |
| `_joinOnto` (`pgn_tutorial_export.dart:119`) — found 27.9.2026 when the gates were compiled | glues a continuing part's sentence onto the join's comment and merges its marks | the part's beats become further beats of the join; a wordless first beat with the marks of the beat before it adds nothing |
| `tools/tutorial_translate/translate.py` | numbers a part's comments in order | nothing: a beat is a comment |
| `chess_backend/services/lessonSteps.js` | keeps a part's PGN as text | nothing |

Fourteen files build an `AnalysisNode` and six places build a `MoveNode`;
seven of them hand the new node another node's marks. *(Measured 27.9.2026:
the gate's source guard, run on `master`, walks 366 files and 33
constructions and names **five** construction sites — `section_split.dart`
twice, `_convert`, the draft controller, `tutorial_tree.dart`; how the
„seven" above was counted is not recorded. `_joinOnto` is
the copier the guard cannot see, and has cases of its own.)*

**The server changes after all**, by one rule in `applyEvent`. §2 said the
film already draws a change of marks with no move behind it; that is true of
the marks and not of the line under the board.

**Still to decide before the brief**: the editor. **Sketched and sent to the
owner 27.9.2026** — two PNGs from `docs/skice/taktovi.html` (`?f=desk`, the
Tutorial Studio at 1536 × 792; `?f=more`, the phone at 360 × 640 and
Preparation's comment box), with five questions and the lead's
recommendation on each:

- **A** — „Add a sentence here" on the open card, under its text, in words
  (or: an icon in the card's header, the words in its tooltip);
- **B** — a new sentence starts with the marks of the one before it (or:
  clean);
- **C** — ✕ „Remove this sentence" only where the position has more than
  one, no question, Undo brings it back;
- **D** — the phone's row of moves gets a narrow „·2" chip for every later
  sentence (or: one chip per move, sentences only in the Line tab);
- **E** — Preparation's comment box follows the open sentence too, with ‹ ›
  and the same button (or: it stays on the first and says how many more there
  are). **Not in the plan until now**: Preparation reads and writes
  `comment`, which is the first beat, so without E a sentence after the first
  is invisible there.

Drawn as sketched whatever the answers: one card per sentence, later ones
indented under the position's first card and joined to it by a line; „1 of
2" / „2 of 2" in words; the open sentence marked by a border, a ring and its
label, not by colour; „then plays" and the branch chips under the position's
last sentence; the board draws the open sentence's marks and a mark drawn
goes to it.


A node holds a list of beats, each a text and its marks. Both tree models, the
PGN reader and writer, the saved tree's JSON, the tutorial's import and export,
the film's walk, and the Flow panel.

- **The film**: `filmBeatsOf` gives one stop per beat. A beat after the first
  on a position becomes an event that changes the words and the marks and
  leaves the position and its last move alone.
- **The editor**: one card per beat in the Flow panel; on a card, a way to add
  a beat on the same position — „Add a sentence here" (D13) — and to take one
  away; marks drawn
  go to the beat that is open. On a phone too.

**Gate**:

- **Round trip**: every stored tutorial, and a generated set of random trees,
  reads and writes back **byte for byte** — through both models;
- **the signature of every tutorial that has one beat per position is
  unchanged**, so every narration already recorded still follows its tutorial;
- a PGN with two comments on a move keeps both — the case is red on `master`,
  where the second replaces the first;
- a screen that knows nothing of beats (Analysis, the room) opens such a PGN,
  changes one move and saves it, and the beats are still there;
- a rendered frame: the second beat of a position shows the same position and
  the same last move, other marks and other words;
- the own-voice film takes one marker per beat, and the counts match.

The random-tree property is the gate; hand fixtures are shapes
(`docs/LESSONS.md`, 27.9.2026).

### Phase 7 — speech to text, and the transcript on the recording [lead: schema and route; implementer: the panel]

**Where it stands, 27.9.2026.** The server half is built and measured on
branch `priprema-faza-7` (`7c9bff06`): backend **1829** without a database
(1784 + 45), **1988** with a throwaway cluster (which makes the 1942 before
it a measured number too). Sixteen mutations, each red on its own case —
two of them only after the lead's gate was fixed: a wait for the vendor with
no deadline hung the file (rule 9), and so hid the real-database case from
the host mutation. The app's gate is `docs/gates/replay_transcript_test.dart`
(24 cases, one of them a loop over three window sizes), its brief
`docs/briefs/BRIEF-PRIPREMA-FAZA7.md`.

**The app's half, built and graded the same day** (implementer, then the
lead): the model, one client over the three routes, the panel beside the
board from 840 wide, in the sideways column on a phone on its side, and in a
sheet above the controls upright; „Recordings transcribed" in Usage this
month. App **4828 passed, 1 skipped** (4796 + 26 of the gate + 6 of the
worker's), analyze the same 22 infos. Twelve mutations, each red on its case.

The worker stopped on two faults of the lead's gate, rightly: canned answers
with no charset (package:http encodes a string body as latin1, and the
fixtures' ć, č, š are not latin1), and `hitTestable()` on the board, which no
screen can satisfy — the marks' `CustomPaint` lies over it and takes every
hit. **Grading then found two faults the gate could not see, both by
rendering the real screen with a transcript longer than the gate's four
sentences**: the list asked for a fixed 420 px, so at 900 x 700 the panel
overflowed by 31 px (a release build clips „Transcribe again…" away) and at
1536 x 792 it showed half its sentences over empty space; and upright the
sheet lay over the control deck, which holds the only button that closes it.
The list now takes the column's height where it has one, the sheet is a layer
of the board's area (the board shrinks, whole, to 45%), the opener is an icon
in the controls' row, and the gate has three more checks, each watched red.

**D17. The owner's answers of 27.9.2026**, after the lead measured both
models against his own correction of „proba 4" (`proba4.groq.corrected.json`,
185 words, two sentences changed):

- **`whisper-large-v3`**, not turbo: 2 of 185 words wrong against 10, read
  through each model's word list. Each model's segment text is worse than its
  own words (6 against 2), so the server builds sentences from the words, as
  phase 5's script did.
- **Serbian in Latin only.** `sr-Cyrl` is not offered: the vendor writes
  Latin, and Latin does not turn into Cyrillic without loss. A Cyrillic
  tutorial comes from translation (phase 9).
- **Q3: whoever may record may transcribe**, counted and not limited:
  `stt_groq_seconds` per account, `groq_stt` per day. A limit is the pricing
  document's to set.
- **Opus, measured on his word**: „proba 4" sent once more as Ogg Opus at 32
  kbit/s came back with the same 2 words wrong, at 527 KB against FLAC's
  1.92 MB. So every recording is sent as Opus — 7 MB for the longest allowed
  (30 minutes), under Groq's 25 MB whatever the microphone. One recording.

**„Proba 5"** (27.9.2026, Windows, a better microphone): loudest sample
**−3.3 dBFS**, where the earlier Windows takes peaked at −20 to −26. The
quiet recordings were the microphones, not the capture — §5's open finding
is closed. Heard as Opus: 20 sentences, 5 of them ending up to 480 ms past
the next one's start, no Cyrillic; not corrected, so how well it was heard
is not known.

**The gate's rule on times, changed from the plan's words.** „A transcript
whose times run backwards or past the end of the audio is refused" would
refuse every recording: in all five, a sentence's end runs up to 480 ms past
the next one's start, a word's start steps back by up to 260 ms, and in
„proba 4" the last sentence ends 60 ms after the sound. What is refused is a
sentence that **starts** before the one it follows, one that ends before it
starts, and anything more than 1 s past the sound; an end within that second
is brought back to the sound. All six real answers pass, and give exactly
phase 5's sentences.

**The lead's, stated so they can be overruled**: no vocabulary hint is sent
(none was measured, and a list changes what is heard); Q4's rule is the
server's (`latinOf`, one way); Q5 — „Transcribe" holds its button and not the
player, because the answer takes seconds; hearing a recording again replaces
the transcript and its corrections, after the app asks; a sentence may be
emptied (the vendor invents words over silence); only the host reads the
transcript, a student it is shared with does not; the table is
`recording_transcripts`, created and never altered, so a server starting on
it adds one table and touches nothing else. **D9 stands**: `STT_PROVIDER`
stays empty on the droplet until the privacy policy names Groq.

*As planned:*

`BE/services/stt/` with a provider switch shaped like the voices',
`STT_PROVIDER` and its keys in `.env.example`. The sound is compressed in a
child process and the original is never touched. A recording's row gains its
transcript: sentences with their times, the language, the vendor, and the
words as they were heard. Only the host, only a recording made in Preparation.
Seconds of audio are counted against the account and the provider's day, from
a `finally`.

In the app, on the recording's player: „Transcribe" with a choice of
language, the sentences beside the board, a tap on one moves the player to it,
and its text can be corrected. Times cannot be edited.

**Gate**: the vendor's client is faked and the **request** is asserted — the
language, the vocabulary hint, the file that was sent; a transcript whose
times run backwards or past the end of the audio is refused; a vendor that
fails is a sentence, and the recording is as it was; a correction changes text
and never a time; the schema change is read for what `initDB` does at start
before the running server loads it.

### Phase 8 — a recording becomes a tutorial [lead: the core and the voice; implementer: the doors]

**Where it stands, 27.9.2026**, on branch `priprema-faza-8`:

- **The core, built and graded by the lead** —
  `APP/features/tutorial_studio/services/recording_tutorial.dart`,
  `recordingTutorialOf`. Its gate, `T/recording_to_tutorial_test.dart`,
  stands on phase 5's four real recordings (`T/fixtures/recording_tutorial/`:
  the timelines as recorded and the sentences the server builds from Groq's
  real answers, **each word replaced by a placeholder of the same length** —
  the repository is public and a transcript is what somebody said) with the
  phase-5 sketch's answer beside each, and on built cases at every rule's
  boundary. The sketch and the core agree on all four: 1, 5, 2 and 2 parts,
  99 beats, 36 wordless — phase 5's published numbers. Twenty mutations, each
  red on its own case; one more survived because it could not change an
  answer, and the loop it removed was deleted.
- **The read-back found a fault in the one reader**: `MoveTree.parsePgn` set
  every parenthesis apart, a comment's included, so a trainer's „(see move
  12)" came back from every save as „( see move 12 )". Only the movetext's
  are set apart now (`T/move_tree_comment_parens_test.dart`).
- **The voice, built by the lead** — `POST /lessons/:id/narration/from-recording`
  copies the host's own Preparation recording (T4) and judges the copy as an
  upload is judged; `saved_lessons.narration_follows` (one nullable column)
  says the voice is held to positions (D18); an upload over the tutorial sets
  it back; `GET /:id/narration` hands back `follows` and `signature`; the
  Library's recording rows say `fromPreparation`. The app's film of „proba 2"
  is written by the app's test to
  `BE/test/fixtures/recording_tutorial_film.json` and laid over the copy by
  `BE/test/recording_voice_copy.test.js`. Backend 1829 → **1841** without a
  database (measured), thirteen mutations each red.
- **The doors** — brief `docs/briefs/BRIEF-PRIPREMA-FAZA8.md`, gate
  `docs/gates/recording_tutorial_doors_test.dart` (16 cases).

**The lead's decisions while building it, stated so they can be overruled:**

- **Markers.** R8 says a beat begins where its first sentence does. Where a
  trainer plays moves *inside* one sentence (a third of all beats, phase 5),
  that sentence belongs to the last of them (R3) and starts before the
  wordless moves in front of it. There **the board wins**: each move is shown
  when it was played, and the sentence's beat waits for its own position —
  the caption is late by the length of the moves, the board is never early.
  The first beat is at 0; nothing starts at or past the sound's end.
- **A new board is always a new part**, even one legal move from the last
  (the sketch's rule): a position loaded from the Library is a new thing to
  look at, whatever it happens to be.
- **A part stands the way the board stood for most of it**, not the way it
  stood at its first instant: a trainer turns the board a moment after
  setting it up.
- **A sentence the trainer emptied stands on no beat**; braces become
  parentheses (they would close the PGN comment); line breaks and runs of
  spaces become one space, which is how the reader gives a comment back.
  Anything else the reader would read differently — `[%csl …]` or `[%clk …]`
  typed into a sentence — refuses the whole tutorial with a sentence rather
  than keeping it changed.
- **A recording with no transcript can still become a tutorial** — its moves,
  its marks and the voice, no words — after the app asks. This is what the
  door offers where the server has no speech to text (the droplet, until the
  privacy policy names Groq, D9).
- **The tutorial is made on the server at once**, then given the voice, then
  opened in the studio. A voice the server refuses leaves the tutorial made
  and says so (do the thing, then say it); the trainer can still export it
  with a synthesised voice.
- **The player's door is in the transcript panel**, not the bar: the host's
  bar is full at 360 wide.
- **A copied voice lives only on the server**; the export asks the server
  when the device has no take, and a take on the device still wins.

*As planned:*

The pure core, in the app: a timeline and a transcript in, a tutorial's draft
and one marker per beat out, by R1–R8 with phase 5's thresholds. Every part is
read back through `readStepTree` before anything is saved. The server attaches
the voice: a **copy** of the recording's sound becomes the tutorial's
narration, after it has checked that both belong to the account. The
tutorial's language is the transcript's.

„Make a tutorial" on the recording's card in the Library and in its player;
the result opens in the Tutorial Studio.

**Gate** `T/recording_to_tutorial_test.dart`, on fixtures that are phase 5's
real recordings with the sound taken out, and on built ones that stand on each
rule's boundary:

- every sentence of the transcript is in exactly one beat, whole;
- a sentence split evenly over a move goes to the later position, and one
  millisecond the other way goes to the earlier;
- an arrow drawn in mid-sentence is on the beat that sentence is in;
- three sentences over unchanged marks are one beat, and a fourth over a new
  arrow is a second beat **on the same position, in the same part**;
- a jump back opens a part that returns, and three quick presses of ← make
  one part, not three;
- a jump's move is derived and carries its squares;
- the film with the trainer's own voice and the film with a synthesised one
  both render, the second with no time in it that came from the recording;
- deleting the tutorial leaves the recording's sound on disk.

### Phase 9 — translation [lead: the route; implementer: the app]

`POST /lessons/:id/translate` makes a copy in the language asked for: the
title, the description, each part's title and each beat's text, through the
DeepSeek client, with the prompt the batch tool already has. **The notation
checker is shared**: one fixture file of source and translated items that the
tool's test and the server's test both read. The copy has no voice of its own
and no film. Counted against the account.

„Translate…" on the tutorial's row and in the studio, with the languages the
tutorial is not already in.

**Gate**: a translation that changes, drops or adds a move or a square is
refused; one that drops or invents an item is refused; a refused translation
leaves **no** copy behind, not half of one; the source tutorial is byte for
byte what it was; the faked model is asserted on the request it was sent.

### Phase 10 — the words [lead]

The manual's pages, `docs/GLOSSARY-EN.md` (a **Beat** is a sentence and what
is drawn while it is said; a position has one or more; **Transcript**),
`docs/PGN-TUTORIAL-FORMAT.md` and the batch tool for beats, the pricing
document, the note to the owner about the privacy policy (D9), the live items
from `[250.1]` in `docs/TODO-provera.md` under *Teach — Preparation*,
*Home — Reprodukcija snimka* and *Teach — Tutorial studio*, the handoff, the
counts in `CLAUDE.md`, and what each phase taught in `docs/LESSONS.md`.

### Phase 11 — the owner's live pass [owner]

On Windows and on the phone: the board's size, the tree and a square; an
analysis brought back from the Library; a recording made, transcribed,
corrected, made into a tutorial; its film in his own voice and in a
synthesised one; the same tutorial translated and spoken; the film sent to a
student and put in a homework.

## 7. Not in this plan

- **The room.** No squares, no graphical tree, no new layout for a live
  session.
- **Where in a sentence a mark appeared.** R4 puts it at the sentence's start.
  If the films look wrong, a mark can later carry its share of the sentence,
  which any voice can honour; it is not built first.
- **A door from a recording straight into a homework** (D7).
- **Editing a transcript's times**, or cutting the recording's sound.
- **A translated tutorial in the trainer's own voice.**
- **Changing the privacy policy's text** — it is the owner's and the lawyer's.
- **A second PGN parser on the server.**

## 8. Open, each with the phase that needs it

**Q1. Which vendor hears the recordings** — *answered 27.9.2026*: Groq (D15).
Azure stays the voice.

**Q2** — *answered 27.9.2026*: yes, as recommended (D18).

**Q2 as it was asked. Does correcting the transcript keep the trainer's own voice?** Today a
changed sentence makes a recorded take „no longer follow" its tutorial, which
is right where the voice was recorded *over* the text. Here the text was
written *from* the voice, and a corrected spelling does not make the voice
wrong. *Recommended*: a take that came from a recording is held to the
positions of its beats and not to their words. Needed by phase 8.

**Q3. What speech to text and translation cost an account** — which plan has
them, and how much of each. Needed by phases 7 and 9; the pricing document
holds the answer.

**Q4. Serbian in which script**, when the vendor returns the other one.
*Recommended*: the trainer's choice at „Transcribe", turned by rule where the
vendor disagrees. *Phase 5 measured*: Groq returns Latin, and now and then a
passage in Cyrillic; Cyrillic turns into Latin by rule without loss, the
other way does not („nj" is „њ" or „нј").

*(Phase 5 measured the wait: Groq answered in 0.9–1.6 s for recordings of two
to three minutes.)*

**Q5. How long a recording may wait for its transcript** — whether
„Transcribe" holds the screen or tells the trainer when it is done. After
phase 5 has timed it.

**Q6. What the trainer reads on the button that adds a beat.** *Answered
27.9.2026*: „Add a sentence here" (D13).

## 9. Counts to measure against

**Measured 27.9.2026** by the `verifier` agent, in a worktree of `master` at
`295a2a91`, with neither the app nor the server running on the machine
(Flutter 3.47.5, Dart 3.13.4, Node 25.9.0). Every number is what `CLAUDE.md`
quoted; the backend with a database is now measured, where it had been derived.

| | count | wall time |
|---|---|---|
| app, `flutter test` | 4197 passed, 1 skipped, none failed | 6 min 33 s |
| `flutter analyze` | 22 infos, all `curly_braces_in_flow_control_structures` — 8 in `positional_evaluator_service.dart`, 12 in `ai_studio_screen.dart`, 2 in `matrix_filter_panel.dart`; no error, no warning | 67 s |
| backend without a database, no `.env` | 1772 passed, none failed | 22 s |
| backend with a throwaway cluster | 1930 passed, none failed | 28 s |

No test failed under load and none had to be run alone.
