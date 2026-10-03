# Brief: PLAN-EKRANI phases 11 and 12 — My Assignments with a homework's items, and the homework review

One brief, two workers: each takes **one** section below, on its own branch,
with its own gate. Read `docs/PLAN-EKRANI.md` §3 (rules R1–R8) and your phase
under §5, and look at your screens' pictures in `docs/skice/ekrani/`
(`compare_myasg.png` and `compare_homework.png`; `compare_review.png`): the
AFTER half is what the owner chose.

Run `flutter pub get` in `chess_app/` before anything else, and before
`dart format`. `pub get` and `analyze` rewrite the generated plugin registrant
files under `linux/`, `macos/` and `windows/`; revert them, they are not yours.

If you believe a test in the gate is wrong, **stop and say so in the report** —
do not work around it. A workaround that satisfies a test without satisfying
the rule is worth less than a stopped batch.

## Common rules

The same as `docs/briefs/BRIEF-EKRANI-FAZE-5-9-10.md`, „Common rules": the
gate green, every other test green, `flutter analyze` at the same 10 infos;
an existing test that names the old screen rewritten openly, never deleted;
every `Key` the existing tests use kept; `site/` grepped for every label you
change (`manual_labels_test`); `dart format`; the gate, then every file that
pumps your screens, then the full suite (the base's count is in the
repository's `CLAUDE.md`, „Commands"), with a test you did not touch that
fails under load run alone before it is believed; a render with
`chess_app/test/support/render_look.dart` at 1536 × 792, 900 × 700 and
360 × 640, looked at; one commit; the report with **what the brief or the
gate got wrong** first, and anything you know is untested.

## Phase 11 — My Assignments and a homework's items

Screens: `chess_app/lib/features/assignments/screens/my_assignments_screen.dart`,
`chess_app/lib/features/homework/screens/homework_assignment_screen.dart`.
Gate: `chess_app/test/assignments_layout_test.dart` (5 cases).

- **My Assignments**: the progress card as one row of figures (or as it is,
  if it has no figures to show); `Open (n)` / `Done (n)` / `All (n)` filters
  counted from the list itself (one set counted, one set shown — open is not
  completed, done is completed), opening on `All` or `Open` (say which); the
  assignments on `AdaptiveCardGrid` (`chess_app/lib/widgets/adaptive_card_grid.dart`),
  each card's `Review and comments` beside the card's figures. Opening an
  assignment, a homework and the review stays as it is
  (`homework_student_test`, `progress_report_figures_test`).
- **A homework's items**: one numbered list of reading width (about 820,
  centred), one line a step — its state icon, its number, its title and line
  under it, its state word (the key `homework-child-state-<id>` stays on it)
  and its action beside it; the step that can be done now has the one
  `FilledButton`, `Continue`, and a finished step's `Review` is a
  `TextButton`. A trainer's `Unlock for student` stays on a locked row, as a
  `TextButton`. Tapping a row opens it as today. `homework_assignment_own_test`,
  `exercise_game_own_test`, `homework_game_review_test` hold the flows.

## Phase 12 — the homework review

Screen: `chess_app/lib/features/assignments/screens/assignment_review_screen.dart`.
Gate: `chess_app/test/assignment_review_layout_test.dart` (3 cases).

On a window (pattern B): the items as a list on the left (a small board, the
title, the verdict chip, how many comments), the chosen item on the right —
a large `BoardThumbnail` (at least 320), its task, what was played, the
solution and the time, its comments and the reply field (`Comment` / `Ask`
as today), `Open in Analysis` where it is offered today; the first item
chosen on opening; the assignment's discussion under the list. A game item
keeps its moves, its verdict and the trainer's `Mark as met` / `Mark as not
met` in the pane. Both the trainer's and the student's view (their wording
differs and keeps differing). On a phone the list, and a tap shows the item
(under it, or on a page of its own — say which). Every request is the same as
today; the existing tests of this screen (`homework_game_review_test`,
`homework_game_in_analysis_test`, `exercise_play_moves_test`,
`tutorial_video_assignment_test`) hold them.
