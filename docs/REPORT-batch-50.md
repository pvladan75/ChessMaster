# Batch 50 — the worker's own report, and how it graded

Kept as evidence of what an outside agent said about its own work, next to what
the machines said about the same diff. Phase 7b of
[PLAN-INTERAKTIVNA-LEKCIJA.md](PLAN-INTERAKTIVNA-LEKCIJA.md); brief and task are
`brief-interaktivna-lekcija-7-2026-09.md` and `TASK-interaktivna-lekcija-7.md`,
with one corrections round. Merged as `3cf036a`.

**Two rounds, and the report below is round 2's.** Round 1's is not kept: this
one opens by naming what that one got wrong, which is a better record than both.

* **Round 1 failed on four things, and the largest was the brief's fault.** It
  put „Napravi korak od ove pozicije" in `lib/screens/ai_studio_screen.dart`
  because the brief's table and §4.3 both named that file — which is the AI
  Studio, puzzles and solution trees, not the authoring surface §6 means. The
  worker followed the brief literally and **said so in its report**, which is
  exactly the behaviour a brief this method depends on.
* **The preview reached a server.** `AssignmentApiService(authToken: '')` is the
  real service with no token: it posts, is refused, and marks steps seen on the
  way. It satisfied the gate's `isNotNull` — the letter of the rule rather than
  its substance — so the gate now presses the board inside a preview and asserts
  nothing goes out. Round 2's replacement is better than the brief asked for: an
  honest „Ovo je pregled zadatka. Potez nije poslat na proveru." rather than a
  fabricated wrong verdict.
* **Round 1's numbers were partly invented** — „exactly 29" when analyze read 32
  with three new rules, „1341 passing" when it was 1340 and 1334 + 6 is 1340.
  Round 2's report opens by naming that, which is why it is the one kept.
* **Round 2's own gate run was misleading and not its fault:** it was graded with
  no allowances at all, so `strings` and `worktree` failed on exactly the changes
  the corrections file demanded. Re-run under the batch's own allowances, every
  gate passes.
* **Three fixes here are the lead's**: the strengthened gate, `dart format` over
  three files round 2 did not format, and the toolbar placement — the new action
  was inserted at index 0, and that screen keeps only `actions.take(2)` on the
  bar in a narrow layout, so it silently pushed „Analiziraj celu partiju" into
  the overflow menu on every phone. No gate can see that, and neither report
  mentioned it.

---

# Report: Batch 50 - Interaktivna lekcija (Round 2)

## 1. Test Counts
- **Before**: In Round 1, the test suite reported 1341 passing. However, as noted in the corrections, this was smoothed: the suite had 1340 passing because the 1 new test did not exist at the time. I measured this run accurately.
- **After**: I ran the entire suite. `test/lesson_editor_test.dart` passes all **7 tests**. The full test suite completed with **1341 tests passing** and **1 skipped**.

## 2. Static Analysis
- **Before**: `flutter analyze` reported 32 issues (including deprecated `groupValue`, `onChanged`, and `value` on Flutter widgets).
- **After**: `flutter analyze` reports exactly **29 infos**, all of which are `curly_braces_in_flow_control_structures`. There are no errors, no warnings, and no new infos. The list of analyzer issues matches the baseline perfectly.

## 3. Implementation Details for Corrections
1. **Button Moved**: Moved the `Napravi korak od ove pozicije` button from `ai_studio_screen.dart` to `analysis_studio_screen.dart`. Removed the code from `ai_studio_screen.dart` via git restore. Added the button to the `_toolbarActions` in `analysis_studio_screen.dart`. Replaced `_puzzleBoardController.getFen()` and `_puzzleMoveTree!.exportToPgn()` with `_currentNode.fen` and `PgnExporterService.exportToPgn(_rootNode)` which accurately leverages the screen's `_rootNode` analysis tree so `[%cal]` and `[%csl]` data travels with the exported PGN.
2. **Preview API Faked**: Implemented a local subclass of `AssignmentApiService` named `PreviewAssignmentApiService` located next to the panel (`lib/features/lessons/widgets/preview_assignment_api_service.dart`). It provides overrides for `markLessonStep`, `answerLessonStep`, and `revealLessonStep`. Returning a mock non-sending `StepAnswerResult(correct: false, reason: '...')` safely overrides network evaluation. The test asserting `a move played in the preview reaches no server at all` now passes and no `AppFeedback` error messages are spawned.
3. **Analyzer Infos Resolved**: Replaced `Radio<bool>` implementation with Flutter's built-in `RadioGroup<int>` wrapper logic to handle `choicesList` selections. Replaced the `DropdownButtonFormField` `value` property with the accepted `initialValue` property, effectively fixing the 3 new analyzer infos.
4. **Saving Feedback**: Added an `AppFeedback.show` SnackBar success message for `Sačuvaj korak` in the `_save()` block within `lesson_step_editor_panel.dart` when the server API update succeeds (`err == null`).

## 4. Mutations and Real-transport Test
- **Mutation (Preview Guard)**: Reverting the API to `AssignmentApiService(authToken: '')` explicitly fails `lesson_editor_test.dart` with a `Odgovor nije poslat — proveri vezu.` error widget match, proving that the preview uses the dummy service and touches no network.
- No new API real-transport definitions were added in this correction round, therefore no real-transport modifications were tested outside of the original implementation scope.
