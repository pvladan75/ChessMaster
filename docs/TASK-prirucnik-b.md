# Task: the user's manual rewritten to the new map — batch `prirucnik-b`

You are rewriting the user's manual of Mislisha, a chess app for players,
trainers and their students, so that it describes the app **as it is being
reorganised**, not as it is today. **This file plus the three documents it
names are the only context you get** — do not rely on any conversation before
them. When the work is merged, this file is deleted.

Branch: `batch/prirucnik-b`. **Do not commit.** Leave the worktree dirty; the
lead reads the diff.

Run this only on a tree where all of these exist:

* `docs/PLAN-REORGANIZACIJA.md` — the plan; §5 „Variant B" and §6 „The
  screens" are the map you write against
* `docs/skice/reorganizacija.html` — wireframes of the same screens; read it
  as text, the labels in it are the ones you quote
* `docs/GLOSSARY-EN.md` — the words, including the new „The tabs" table
* `docs/gates/map_b_labels.txt` and `docs/gates/map_b_retired_labels.txt`
* `chess_app/test/manual_labels_test.dart` and
  `chess_app/test/manual_places_test.dart`
* `site/mislisha/manual/` with thirteen pages

If any is missing, **stop and say so.** Do not find the nearest plausible file
and use that.

## What the manual is for, and what changed

The app had four tabs — Training, Sessions, Library, People — and the manual
was written as the map of that. The owner has decided a reorganisation
(`docs/PLAN-REORGANIZACIJA.md`, Variant B, 17.9.2026): four new tabs,
**Home · Practise · Analyse · Teach**, one door from Analysis into teaching
material, one library of everything a user keeps, the trainer's panel beside
the sessions instead of beside the people, and new names for a dozen labels.
The manual is rewritten **now**, ahead of the code, because it is the
specification the code will be built to: every label you quote from the new
map is a label the app will have.

**You write HTML pages and nothing else.** You do not change the app, the
server, the tests, the plan, the wireframes or any other part of the site.

## The rules

1. **Every label you quote goes inside `<span class="ui">…</span>`, exactly,
   and only labels go there.** A quoted label must be either a string literal
   in `chess_app/lib` **or** a line of `docs/gates/map_b_labels.txt`. That
   file is the complete set of new words; if the map seems to need a label
   that is in neither place, do not invent it — describe the control in plain
   words without the span and list it in your report under „Missing labels".
2. **Never quote a label in `docs/gates/map_b_retired_labels.txt`.** Those are
   the words the reorganisation removes; they are still in the code today,
   which is why a test cannot catch them for you — read the list.
3. **A page is a task a reader wants to do, never a tour of a screen**: what
   you want → where it is → the steps → what to know. Keep the existing
   pages' skeleton, voice and length; change what the map changes and leave
   the rest alone. This is a rewrite of the *where*, not of the *how*: the
   steps inside a screen — the engine, the drill, the studio's parts and beats
   — are as they were.
4. **Say the platform when it matters.** Writing a tutorial is on Windows for
   now; the plan's phase 6 brings it to the phone later — do not describe
   that. Everything else is on both.
5. **No numbers that change**, the reader is „you", the glossary's words,
   never „child" or „kid" outside the parents' page, no images, no scripts, no
   new CSS, English only.
6. **Only what the plan says.** Where the plan and the wireframes are silent,
   the screen is as it is today. Do not describe a feature the plan does not
   name.

## The map, page by page

The tab each page must name is pinned by `chess_app/test/manual_places_test.dart`;
read its `_tabOf` table before you start.

| Page | What changes |
|---|---|
| `index.html` | The sentence naming the four tabs, and only that. The list of pages and their headings stay. |
| `getting-started.html` | The whole „four tabs" section is rewritten for **Home, Practise, Analyse, Teach**, from §5 „Variant B" and §6.1–6.3 of the plan: Home is built from what the data says (its blocks — Resume, Today, To review, Set for me, Join a session, Recordings — and that a block is drawn only when it has rows); Practise is the hub; Analyse is the board itself with Saved analyses, My games and Scan a book beside it; Teach holds Tutorials, Preparation, New session, Students and the Library. The top bar, Settings, keys and „if something is not where this page says" sections are as they were, except that Settings' row list is unchanged and `Ctrl+1` to `Ctrl+4` now go to the four new tabs. |
| `students-and-trainers.html` | Requests, the student and trainer lists and groups are on **Teach**, under „Students"; the card is called `Students and trainers`. Nothing about the People tab. |
| `write-a-tutorial.html` | The door is Teach → Tutorials → `New tutorial`; the studio itself is unchanged. |
| `send-a-tutorial.html` | A tutorial is sent from the **Library** on Teach — its row's `Send to student` — or from a student's progress page; the saved-tutorials dialog is gone. |
| `student-progress.html` | A student's progress is reached from Teach → Students → `Progress`; what needs a trainer today — sessions, homework to review, stalled homework — is on **Home** (Today, To review). The Review queue is the student's, on Home. |
| `live-session.html` | Start one from **Teach** → `New session` → `Start`; a student joins from **Home** → Join a session with `Enter room code (e.g. 123456)` and `Join`. Inside the room the left column is two parts, **Board** (`Set up position`, `Import PGN`, `Save position`, the FEN field) and **Library** (search, `All` / `Mine` / `From trainer`, the list). `Create tutorial (multiple positions)` is gone — a tutorial is written in the Tutorial Studio, and a row's `Edit tutorial` opens it there. Recordings are on Home and in the Library. |
| `preparation.html` | Preparation is on **Teach**, one door. Saved positions are in the **Library** (Teach), under the `Positions` chip, together with positions from a book — a book's positions carry their source; the scanner is reached from **Analyse** → `Scan a book`. |
| `analysis.html` | Analysis is the **Analyse** tab — the board is the tab. The „Keep it, or teach from it" section describes one control, `Use in a tutorial`, and its rows exactly as `chess_app/lib/features/analysis_studio/widgets/teach_menu.dart` names them (six rows; the three „New tutorial …" rows exist on Windows). `Saved analyses`, `My games` and `Scan a book` sit beside the board. |
| `repertoire.html`, `practice.html` | The hub is the **Practise** tab; the cards and drills are as they were. |
| `tutorial-video.html` | Export, download and the render's progress are the row actions of a tutorial in the **Library** on Teach (`Export video`, `Download video`, `Rendering — show progress`); the studio's own `Export video` is unchanged. |
| `for-students.html` | What a student does starts on **Home**: Set for me (assignments), Due for review, Join a session, Recordings. The tutorial itself and the reviews are as they were. |
| `for-parents.html` | **Do not touch.** |

## Method

1. Read the plan's §5 and §6, the wireframes, the glossary's tab table, and
   the two label files. Then read every page you will change, whole.
2. Rewrite page by page. For each label you quote, note where it comes from —
   `chess_app/lib/<file>:<line>` or „map_b_labels" — for the report.
3. When every page is done, run once:

       cd chess_app && flutter test test/manual_labels_test.dart test/manual_places_test.dart

   and fix what they name. Do not run the whole suite; your batch changes no
   Dart file.
4. **If you believe a test is wrong, stop and say so in the report** — do not
   work around it. A workaround that satisfies a test without satisfying the
   rule is worth less than a stopped batch. Putting a label in plain text to
   dodge the check is a workaround.

## Do not

- touch anything outside `site/mislisha/manual/`, except to create the report;
- change `for-parents.html`, `style.css`, the tests, the plan, the label
  files, or any Dart file;
- describe a feature you found in the code but not in the plan or the
  wireframes; describe what a screen „will" do beyond what the plan says.

## Your report — `REPORT-prirucnik-b.md`, at the repository root

1. **Per page**: its word count before and after; every quoted label with its
   source (`file:line` or „map_b_labels"); every sentence you removed because
   its control is retired.
2. **Missing labels**: controls the map needs that are in neither the code nor
   the label file.
3. **Questions**: anything the plan and the wireframes left open, and how you
   decided.
4. The two tests' result, pasted — the last lines of their output.

**Do not claim a number you did not compute in that run.** The lead grades the
pages against the plan, claim by claim.
