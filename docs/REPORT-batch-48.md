# Batch 48 — the worker's own report, and how it graded

Kept as evidence of what an outside agent said about its own work, next to what
the machines said about the same diff. Phase 4b of
[PLAN-INTERAKTIVNA-LEKCIJA.md](PLAN-INTERAKTIVNA-LEKCIJA.md); brief and task are
`brief-interaktivna-lekcija-4b-2026-09.md` and
`TASK-interaktivna-lekcija-4b.md`. Merged as `d092ee0`.

**Read the section below as a claim, not as a result.** Everything in it was
re-measured before the merge, and the plan's phase 4 entry carries the grading
in full. In short:

* **Held up:** 1311 passing with 1 skipped, the 14 gate tests green when run
  alone, 29 `curly_braces` infos unchanged, `dart format` clean, `test/` and
  `chess_backend/` untouched, nothing committed.
* **Did not hold up:** the flaky failure in `opening_book_service_test.dart`
  did not reproduce in either of two full runs. The comment the report cites is
  real, and that test does carry a two-minute timeout for exactly that reason —
  so this was an honest excuse rather than an invented one, and still an
  unverified number in a report whose numbers are its entire purpose.
* **Not visible to the report or the gates:** a wrong `ask_move` answer left the
  wrong move on the board, and the `Size(360, 640)` check phase 4 asks for is
  not in the gate file. Both handled by the lead before the merge.
* **The gate was wrong, not the work:** `strings` failed this batch for wire
  literals its own brief specified. Third time. The allowance now names all
  three files.

The report's two errata are worth keeping for the shape of them: the first is
fair but trivial, and the second names a type (`CustomAttemptResult`) that does
not appear in the section it cites. A worker asked for corrections will produce
some, and they are graded like everything else.

---

# Report: interaktivna-lekcija-4b

## Tests
* `flutter test` before: 1297 passing, 1 skipped, 1 failing to load (`test/lesson_step_asks_test.dart`).
* `flutter test` after: 1311 passing, 1 skipped, 1 flaky failing. (Delta: +14, all 14 tests in `test/lesson_step_asks_test.dart` pass).
  *Note: The flaky failure is `OpeningBookService loads the bundled ECO dataset` in `test/opening_book_service_test.dart`, which is known to fail occasionally under machine load (as noted in the comments of that file).*

## Static Analysis
* `flutter analyze` count: 29 issues, all `info`, all `curly_braces_in_flow_control_structures`.
* Did the list change? No.

## Strings
Added user-facing strings to:
* `lib/features/assignments/screens/lesson_viewer_screen.dart`

## Proofs
* **The board is locked on a choice step**: Implemented by passing `isAllowedToMove: _step.kind != LessonStepKind.askChoice` directly into `ChessBoardWithOverlay` inside `LessonViewerScreen`. The test confirms this by extracting the widget and checking the property.
* **No options offered on ask_move**: Options are only rendered under the `if (_step.kind == LessonStepKind.askChoice)` block.
* **"Pokaži mi" after the second wrong answer**: The button only appears because its `actionLabel` and `onAction` are conditionally set when `_wrongAnswers >= 2`.
* **The answer never reaches the client**: The client calls `answerLessonStep` and relies entirely on the server's `StepAnswerResult` (which contains `correct` and `reason`).
* **A server that does not answer keeps the board**: Handled by checking if the API call returns `null`, and if so, setting `_sending = false` and calling `_board.loadFen(_lessonFen)` to put the board back exactly as it was, along with showing the expected `AppFeedback`.

## Errata / Brief feedback
* **`StepRevealResult` missing from brief text**: The brief mentions `StepRevealResult` in Section 6, but didn't explicitly show a Dart model schema in Section 3.3, just the JSON. I implemented `StepRevealResult` mirroring the response shape.
* **Typo in brief section 3.2**: `playedSan` was missing from the JSON schema for `CustomAttemptResult` in the brief, though it's already there in the dart code for it.
