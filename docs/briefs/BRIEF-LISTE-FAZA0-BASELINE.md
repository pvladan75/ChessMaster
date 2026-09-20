# Brief — lists, phase 0: the baseline

`docs/PLAN-LISTE.md`, phase 0. **Measure only. Change nothing.**

You are measuring the state of `master` before any phase of that plan touches
it, so that a drop in the count or a new lint line afterwards is visible
instead of arguable. Report numbers; do not fix anything you find.

## Do not

- Do not edit any file — not a test, not a source, not a doc.
- Do not run the backend suite. Every phase of this plan is `chess_app/` only,
  so the backend numbers cannot move and measuring them costs ten minutes.
- Do not start a server, and do not touch `.env`.
- Do not search the disk from `/` or `C:\`.
- Stop anything you start in the background before you report.

## Run these, in this order, with nothing else running

This matters and is not a formality. `game_tutorial_run_test` drives Stockfish
over ten games and needed **12 minutes on its own** on 18.9.2026. Beside a
second heavy process both it and `opening_book_service_test` blow the runner's
three-minute per-test timeout and are reported as failures although they pass
in isolation. So: one command at a time, nothing else going.

```
cd chess_app && flutter test
```

```
cd chess_app && flutter analyze
```

## Report exactly this

1. **`flutter test`** — the final summary line verbatim. Then: how many passed,
   how many skipped, how many failed. If anything failed, the name of each
   failing test and its error, plus a **second run of that file alone** so the
   report says whether it fails in isolation or only under load.
2. **`flutter analyze`** — the summary line verbatim, the exit code, and the
   **full list of issues**: severity, rule name, and file for each. Then a
   count per rule name and a count per file.
3. **Against what CLAUDE.md claims.** That file says 3383 tests with 1 skipped,
   and 26 `info` issues, all `curly_braces_in_flow_control_structures`, spread
   over `positional_evaluator_service.dart`,
   `game_analysis_walker_service.dart`, `review_api_service.dart`,
   `ai_studio_screen.dart` and `matrix_filter_panel.dart`. Say for each number
   whether you got it. **If a number differs, say so plainly and do not
   reconcile it** — a difference is the finding, not an error in your run.
4. **The one expected skip** is the golden screenshot group, skipped
   unconditionally in `dart_test.yaml`. Confirm that is the skip you saw. Do
   **not** run it.
5. How long each command took.

Numbers only. No recommendations, no fixes, no opinion about what should
change.
