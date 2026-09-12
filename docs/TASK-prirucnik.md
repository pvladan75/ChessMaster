# Task: the user's manual — chapters 1, 2 and 4–12

You are writing eleven pages of the user's manual for Mislisha, a chess app for
players, trainers and their students. The plan is `docs/PLAN-PRIRUCNIK.md`;
read it first, whole. The lead has written the contents page and one chapter,
`site/mislisha/manual/write-a-tutorial.html`, which **is the model for yours**:
its skeleton, its voice, its length, and how it quotes the app.

**You write HTML pages and nothing else.** You do not change the app, the
server, the tests, or any other part of the site.

## What the manual is for

The owner's words: users get lost „in a sea of features". The app is not being
reorganised, so the manual is the map. **A page is a task a reader wants to do,
never a tour of a screen**: where it is, the steps, and what to know.

## The rules — the same as the plan's, and the test enforces the first

1. **Every label you quote goes inside `<span class="ui">…</span>`, exactly as
   it stands in the app, and only labels go there.** `chess_app/test/
   manual_labels_test.dart` fails if a quoted label is not a string literal in
   `chess_app/lib`. Copy labels out of the Dart source; never write one from
   memory or from what a button „probably" says. Quote a dialog title or a
   message only if it is one literal; otherwise describe it in your own words
   without the span.
2. **Only what a user can reach.** If the code has a feature and you cannot find
   the button, menu or route a user reaches it by, **do not describe it** — list
   it in your report under „Unreachable".
3. **Say the platform when it matters.** Some screens exist only on Windows or
   only on a phone; check `isTutorialStudioAvailable`, `Platform.is…` and
   `defaultTargetPlatform` checks on the way to each screen you describe.
4. **No numbers that change**: no prices, quotas, tiers, time limits or sizes.
   Say what the app does when a limit is hit, not the limit.
5. **The reader is „you".** Use the words of `docs/GLOSSARY-EN.md`: Tutorial is
   what a trainer writes, Session is live, Trainer not coach, Student, Player.
   **Never „child" or „kid"** — the parents' page is the lead's.
6. **No images, no scripts, no new CSS.** Use what `site/style.css` has:
   `h2` sections, `ul`/`ol`, `.note` for one platform or warning box, `.lead`
   for the first paragraph, `kbd` for keys, `span.ui` for labels.
7. **About a thousand words a page.** Short sections, numbered steps where
   order matters.
8. **English only.** The test fails on any Serbian letter.

## Every page

Copy the skeleton of `write-a-tutorial.html`: the same `head` (with your own
`title` — „<Title> — Mislisha user manual" — and `description`), the header
link `<a href="/mislisha/manual/">← User manual</a>`, `h1`, `p.lead`, sections,
and the same footer. The test requires the link back to `/mislisha/manual/`.

Then add the page to `site/mislisha/manual/index.html`, as an `<li>` in the
same shape as the one there, under the heading named in the table below. Create
the headings „If you practise on your own" and „If you have a trainer" as new
`h2` + `ul.tasks` sections, in that order, after „If you teach". The test
requires every page to be linked as `href="/mislisha/manual/<name>"` — no
`.html` in the link.

Link between chapters where a task leads to another — „then send it to a
student" links to `send-a-tutorial` — but only to pages that exist once your
batch is done.

## The chapters

Start from `chess_app/lib/routing/app_routes.dart` and the four tabs in
`chess_app/lib/screens/home_screen.dart` (`kTabNames`), then follow each door to
its screen. The starting points below are where to begin reading, not the whole
list.

| Page | Title | Contents heading | Cover | Start reading at |
|---|---|---|---|---|
| `getting-started.html` | Find your way around | If you teach | Signing in and what a guest can do; the age question; the four tabs and what each is for; Settings (what is in it, briefly); notifications and invitations; the banner that brings you back to a session; F1 and the shortcuts. **Put this entry first in its list.** | `screens/home_screen.dart`, `screens/login_screen.dart`, `screens/age_gate_screen.dart`, `screens/settings_screen.dart`, `screens/shortcuts_screen.dart`, `widgets/home/home_dialogs.dart` |
| `students-and-trainers.html` | Connect with your students or your trainer | If you teach | Sending a request as a trainer or as a student; what „awaiting" states mean; accepting; ending a relationship; student groups. Mention that a parent may have to confirm for some students, without legal detail. | `widgets/home/friends_tab.dart`, `features/groups/`, `widgets/home/home_dialogs.dart` |
| `send-a-tutorial.html` | Send a tutorial to a student | If you teach | Every way a tutorial reaches a student (the saved-tutorials list, and anything else you find), what the student sees arrive, and what happens with a student who has not accepted. | `features/tutorial_studio/widgets/tutorial_library_card.dart`, `features/assignments/` |
| `student-progress.html` | See what a student did | If you teach | Progress and assignments per student, what the results mean, the report for a parent if a trainer can send one, and the review queue. | `features/assignments/screens/student_progress_screen.dart`, `features/assignments/widgets/parent_report_dialog.dart`, `features/reviews/` |
| `live-session.html` | Run a live session | If you teach | Starting a session, the room code, inviting and scheduling, what is in the room (board, voice, arrows, the lesson list), leaving and coming back, and watching a session again afterwards. Say plainly that a session is never recorded with sound. | `widgets/home/dashboard_tab.dart`, `screens/chess_game_screen.dart`, `widgets/home/home_dialogs.dart`, `screens/replay_player_screen.dart` |
| `preparation.html` | Prepare material: your library and positions from a book | If you teach | Preparation (the room alone), saved positions, labels, and positions scanned from a book PDF — what is and is not kept on the server. | `widgets/home/biblioteka_tab.dart`, `widgets/home/dashboard_tab.dart`, `features/library/`, `features/position_scanner/`, `widgets/save_position_dialog.dart` |
| `analysis.html` | Analyse a position or a game | If you practise on your own | Opening Analysis, the engine, the opening explorer, the variation tree, importing a PGN or a game, and handing a line to the Tutorial Studio. | `features/analysis_studio/`, `widgets/pgn_import_dialog.dart` |
| `repertoire.html` | Build an opening repertoire | If you practise on your own | Building a repertoire, drilling it, and anything the screens offer on top. | `features/repertoire/` |
| `tutorial-video.html` | Turn a tutorial into a video | If you teach | Export video: the voice or a recording of your own, captions, quality, the preview, waiting and downloading; recording your narration and what happens when the tutorial changes after it. | `features/tutorial_studio/services/tutorial_video_export.dart`, the narration recording screen under `features/tutorial_studio/`, `tutorial_library_card.dart` |
| `practice.html` | Practise on your own | If you practise on your own | Every card on the Training tab, one short section each, in the order the tab shows them. | `widgets/ai_studio/category_selection_hub.dart`, `features/training/`, `features/tactics_trainer/`, `features/puzzle_trainer/`, `features/endgame_trainer/`, `features/archive/` |
| `for-students.html` | Work with your trainer | If you have a trainer | Joining a session by code, assignments from your trainer, walking a tutorial (the play button, questions, forks), and reviews that come back. | `widgets/home/dashboard_tab.dart`, `features/assignments/screens/my_assignments_screen.dart`, `features/assignments/screens/lesson_viewer_screen.dart`, `features/reviews/` |

„Write a tutorial" is already written; link to it, do not rewrite it. „For
parents" is the lead's; do not write it.

## Method

1. Read the plan, the model chapter and the glossary.
2. For each chapter, read the code first and write second. Note, as you go, the
   file and line of every label you quote and of the code behind every claim
   you make about what happens — the report needs both.
3. When all eleven pages and the contents entries are written, run once:

       cd chess_app && flutter test test/manual_labels_test.dart

   and fix what it names. Do not run the whole suite; your batch changes no
   Dart file.
4. **If you believe a test in it is wrong, stop and say so in the report** — do
   not work around it. A workaround that satisfies a test without satisfying the
   rule is worth less than a stopped batch. Putting a label in plain text to
   dodge the check is a workaround.

## Do not

- touch anything outside `site/mislisha/manual/`, except to create the report;
- change `write-a-tutorial.html`, the test, `style.css`, or any Dart file;
- write the parents' page, a page for a feature you could not reach, or a page
  not in the table;
- describe what a feature „will" do, or what it should do.

## Your report — `REPORT-prirucnik.md`, at the repository root

1. **Per page**: its word count; every quoted label with the `file:line` of the
   literal; every claim about behaviour with the `file:line` that does it.
2. **Unreachable**: features in the code you found no door to.
3. **Questions**: anything you were unsure of and how you decided.
4. The test's result, pasted — the last lines of its output.

The lead grades the pages against the code, not against this report, claim by
claim. A wrong claim with a `file:line` beside it is found in a minute; one
without it costs an hour.
