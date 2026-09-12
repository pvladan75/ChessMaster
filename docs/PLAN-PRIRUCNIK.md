# The user's manual

Phase 4 of `docs/PLAN-ZAVRSNICA.md`. Written 11.9.2026. Nothing in it is built
yet.

## The request

The owner, 8.9.2026, and the reason this is a phase rather than a chore at the
end: *„Najveći problem je nepostojanje dokumentacije koja bi pomogla korisniku da
se snađe u moru funkcija. Dobra dokumentacija može da nadomesti i malo klimavu
organizaciju."* The app's organisation is not being rebuilt, so the manual is
not a description of the structure — it **is** the structure a user gets: what
they want to do, and which door it is behind.

## The decisions

The owner, 11.9.2026:

- **On the site**, under `chesstrainers.app/mislisha/manual/`, in the site's own
  style, **and linked from the app**: a „User manual" row in Settings and a line
  on the F1 shortcuts page. One copy, reachable from the app and from the store
  listing.
- **Words only, no screenshots**, until the app is frozen for release. The app
  changes daily; a screenshot goes stale without a word, while a renamed label is
  caught by the test below.
- **The worker writes part of it.** The quota is not a constraint.

Already decided on 8.9.2026: **English**, in the words of `docs/GLOSSARY-EN.md`.

## What exists

- **`site/`** — hand-written HTML on one `style.css`, deployed by
  `deploy/site-setup.sh`, which copies subfolders and refuses a page with a
  `{{PLACEHOLDER}}` left in it. nginx serves `/x` from `x.html` and `/x/` from
  `x/index.html`.
- **`site/mislisha.html`** — the product page, written 26.8.2026 when the app
  was a live-lesson tool. It knows nothing of tutorials, the studio, video,
  repertoire or practice. It is rewritten in this phase as „what the app is
  for".
- **`site/mislisha/privacy-policy.html`** — an English policy from 26.8.2026,
  written before the 13+ decision. It is a legal text and **not** part of the
  worker's batch; see „Out of this plan".
- **`docs/UPUTSTVO-STUDIO.md`** — the trainer's guide to the studio, in Serbian,
  kept current through three plans. The manual's studio chapter is written from
  it and from the code, and does not replace it.
- **`url_launcher`** is already a dependency, and Settings already opens links
  with it.

## The chapters

Task-shaped: a heading is something a reader wants to do, never the name of a
screen. Each page answers, in this order: **what you want → where it is → the
steps → what to know** (limits, platform, what can go wrong).

| # | Page | Title | Reader | Written by |
|---|---|---|---|---|
| 0 | `index.html` | Mislisha user manual | all | lead |
| 1 | `getting-started.html` | Find your way around | all | worker |
| 2 | `students-and-trainers.html` | Connect with your students or your trainer | trainer, student | worker |
| 3 | `write-a-tutorial.html` | Write a tutorial | trainer | **lead — the sample** |
| 4 | `send-a-tutorial.html` | Send a tutorial to a student | trainer | worker |
| 5 | `student-progress.html` | See what a student did | trainer | worker |
| 6 | `live-session.html` | Run a live session | trainer, student | worker |
| 7 | `preparation.html` | Prepare material: your library and positions from a book | trainer | worker |
| 8 | `analysis.html` | Analyse a position or a game | all | worker |
| 9 | `repertoire.html` | Build an opening repertoire | all | worker |
| 10 | `tutorial-video.html` | Turn a tutorial into a video | trainer | worker |
| 11 | `practice.html` | Practise on your own | player | worker |
| 12 | `for-students.html` | Work with your trainer | student | worker |
| 13 | `for-parents.html` | For parents | parent | lead |

The parents' page is the lead's because it is the one place the manual is about
a minor, consent and a report, and it has to agree word for word with what the
consent flow and the age gate actually do (`CLAUDE.md`, „Consent").

## The rules the pages are written under

1. **A label is quoted exactly as it stands on screen, inside
   `<span class="ui">…</span>`, and only there.** The test below checks every
   one against the app's source. A label that is not in the app is a failed
   build, not a style note.
2. **Say the platform when it matters.** The Tutorial Studio exists only on
   Windows; on a phone a tutorial is edited in the older, frozen step editor.
   A reader on the wrong device must learn that from the first paragraph.
3. **Only what a user can reach.** A feature that exists in the code but has no
   door on screen is not in the manual — it is a bug report, and the batch
   reports it instead of describing it.
4. **No numbers that change**: prices, quotas, tiers, limits in seconds. Say
   what happens („the export dialog says if a tutorial is too long to render"),
   not the number.
5. **The reader is „you" — a player, a trainer, a student.** „Child" appears
   only on the parents' page, by the glossary's rule.
6. **No images.** Structure carries the reading: short sections, numbered steps,
   the label in `span.ui`.
7. **One page skeleton** — the manual's header (back to the contents), `h1`, a
   lead paragraph saying what the page helps you do, sections, the site's footer.
8. **A page is short enough to read in one go** — about a thousand words. Two
   tasks that share a door can share a page; one task never spans two.

## The test that holds the manual to the app

`chess_app/test/manual_labels_test.dart`, written by the lead and landed
**before** the worker's batch, because the batch's prose is only checkable
through it. Three rounds of worker reports on this project have had accurate
numbers and invented sections; a manual is nothing but sections.

- Every `<span class="ui">X</span>` in `site/mislisha/manual/*.html` must be a
  string literal in `chess_app/lib`, either exactly or with its `${…}` parts
  removed — so „Resume session" matches `'Resume session ${code}'`.
- The contents page links to every page, and every page links back to it.
- No `{{`, no `<img>`, no letter of the Serbian alphabet.
- The app's link to the manual names the page that exists.

It is proved by mutation before it is trusted: an invented label goes red, and
renaming the literal a label quotes goes red.

## What happened — 11.9.2026

**The pages are written, all thirteen, and the lead wrote every one of them.**
The worker's batch ran as planned and passed all twelve gates in one round; its
pages were then discarded, and the reason is worth the space.

**The labels were right and the sentences around them were invented.** The
label test did its job: not one page quoted a button the app does not have. It
cannot ask whether a sentence is true, and the sentences were written with the
same confidence either way — the app „runs in mobile web browsers" (there is no
web build), board themes „tournament wood, modern slate, green vinyl" (invented
names), shortcuts <kbd>?</kbd> and <kbd>F</kbd> (not bound), „under 16 … enters
a protected safety mode" (under 13 is refused outright), and a scanner that
„captures a photo of the printed page using your webcam" — the scanner reads a
PDF's typeset diagrams and never an image.

**The citations were decorative.** The brief asked for `file:line` beside every
claim, precisely so grading would be cheap. The lines it gave do not hold:
`age_gate_screen.dart:176` is an error message, not the „Birth year" label;
`analysis_studio_screen.dart:1300` is a comment about FEN.

**What it was worth.** The batch's page list, section order and the length of a
page were sound, and the rewrite kept them. What cost nothing to keep was the
structure; what could not be kept was every sentence of content.

**The rule this suggests for the next batch of this kind**: a worker can be
asked for what a gate can check — labels, files, the existence of a door — and
not for prose about behaviour, unless somebody is going to read every sentence
against the code anyway. At that point writing it is the cheaper half.

## The split

**The lead, before the batch:** this plan; the test; `index.html` and a
stylesheet addition for `span.ui` if one is needed; chapter 3 as the sample
that sets the voice; the app's link to the manual; and `'Trening'`, the Serbian
title the Training hub still draws when it is opened as its own screen — it has
no Serbian letter, so the language gate cannot see it.

**The worker, one batch:** chapters 1, 2 and 4–12, and their lines on the
contents page. Each chapter's brief names the task, the files to start reading
from, and what the page must cover. The batch writes only under
`site/mislisha/manual/` and runs the label test.

**The lead, after:** every page graded claim by claim against the code, not
against the batch's report; chapter 13; `site/mislisha.html` rewritten as what
the app is for; `docs/TODO-provera.md` gets an item for the owner to read the
manual and walk three tasks with it open.

## Out of this plan

- **The English privacy policy.** `site/mislisha/privacy-policy.html` predates
  the 13+ decision, and it is a legal text: it is brought in line by the lead as
  its own change, and a lawyer's review stays the external release gate
  (`PLAN-ZAVRSNICA.md`, „The privacy policy").
- **Screenshots**, until the app is frozen.
- **A manual inside the app.** The app links to the site.
- **Serbian.** `docs/UPUTSTVO-STUDIO.md` stays as the Serbian studio guide.

## Counts to measure against

App **2083** with 1 skipped, backend **1234** with `.env` moved aside, analyze
29 infos — measured 11.9.2026 before any of this.
