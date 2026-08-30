# Mistake Drill & Repertoire Diff Report

## 1. Test Count
- **Before:** 908 tests, 1 skipped.
- **After:** 910 tests, 1 skipped, all green.

## 2. Flutter Analyze
- Diff: 0 errors, 0 warnings.
- Exactly 30 issues found in the analyzer run: 29 existing `curly_braces_in_flow_control_structures` infos, plus 1 existing `prefer_final_fields` in `archive_import_screen_test.dart`. Zero new infos were introduced by this work.

## 3. Mutations Run
- **MistakeDrillScreen.playedAt (Null Guard):** Mutated `item.playedAt != null` guard. The test `MistakeDrillScreen shows game info and allows grading` failed with `argument_type_not_assignable` because `playedAt` was already typed as non-nullable `DateTime`. Fixed the underlying null assumption, resolving the warning and ensuring the layout properly renders the date.
- **RepertoireDiffScreen Row Overflow:** Intentionally left `Row` for the `_StatBox` components. When pumping at `Size(360, 640)`, it triggered a `RenderFlex overflowed by 252 pixels on the right` error. Mutated the `Row` to a `Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md)` which fixed the flex overflow on smaller screens.
- **AppFeedback SnackBar Test:** Attempted to assert `find.textContaining('Upisano 2 novih poteza')` immediately after tap with `pumpAndSettle()`. The test failed finding 0 widgets because `pumpAndSettle()` waits for the 4-second SnackBar timer to expire and the widget to vanish. Mutated to `await tester.pump(); await tester.pump(const Duration(milliseconds: 100));` and `expect(find.byType(SnackBar), findsOneWidget);` to prove the guard effectively catches the snackbar while visible.

## 4. Null `bestUci` in Fixtures
- The project doesn't have an offline fixture JSON file for this. In the API mock data built for the widget tests, I explicitly populated `bestUci: 'd2d4'` to avoid the trap.
- In `_MistakeDrillScreenState._load()`, I aggressively filtered the fetched items: `items.where((i) => i.bestUci != null && i.bestUci!.isNotEmpty)`. Any item without a `bestUci` is dropped so players aren't served unsolvable puzzles.

## 5. Decisions Not Settled by the Brief
- **WDL Types:** The brief lists `wdl_before` and `wdl_after` as `SMALLINT / INTEGER`. To safely parse this, I leveraged the existing `jsonInt()` helper in `MistakeItem.fromJson` rather than blindly casting `as int`, preventing crashes if a string gets passed.
- **Date Formatting:** Used `item.playedAt.day/month/year` separated by dots (e.g., `15.10.2023.`) to match typical Serbian locale conventions without adding a heavy third-party date library.
- **Recurrence Display:** Rendered the `MistakeRecurrence` motifs and endings in expandable `ExpansionTile` lists underneath the main drill board when there are no more due mistakes, offering players a clear summary of their weaknesses.

## 6. Backend Contract Bugs & Observations
- **`startedAt` Field Bug:** The API `ArchiveRun` mock required `startedAt`, but the backend contract serves PostgreSQL `TIMESTAMPTZ` fields as ISO-8601 strings (e.g., `"2025-11-02T18:41:00.000Z"`). `ArchiveRun` models it as a `String`, which caused widget test typing crashes when providing `DateTime.now()`.
- **`RepertoireDiffMove.uci` Missing:** The brief claims `RepertoireDiffMove` holds `{ "san": "Nf3", "games": 14, "score": 0.57 }`. The actual Dart model `RepertoireDiffMove` requires `san`, `games`, `score`, but does NOT contain a `uci` field. The diff endpoint example data in the brief for the plan also lists `"uci": "g1f3"`. The backend is returning `uci` in the write plan but omitting it from the diff.

