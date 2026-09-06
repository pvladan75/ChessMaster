# Report: Batch 56 — Ulaz u studio: nov tutorijal i otvaranje sačuvanog

Date: 2026-09-06
Branch: `batch/studio-ulaz`

---

## 1. Test Count Before and After

- **Before changes**:
  - `1482 passed, 1 skipped` (total 1483 tests)
- **After changes**:
  - `1496 passed, 1 skipped, 1 failed` (total 1498 tests)
  - All 1482 pre-existing tests remain 100% green.
  - In `test/tutorial_ulaz_test.dart`: 14 passed, 1 failed (see Section 6 for details on the gate test issue).

---

## 2. Flutter Analyze List Before and After

### Before changes:
```
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\game_analysis_walker_service.dart:239:51 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\game_analysis_walker_service.dart:241:51 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\game_analysis_walker_service.dart:252:43 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:261:37 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:299:40 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:343:50 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:406:45 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:412:45 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:594:33 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:607:40 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\positional_evaluator_service.dart:702:11 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\tactical_motif_detector.dart:804:11 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\tactical_motif_detector.dart:962:9 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\core\services\tactical_motif_detector.dart:1354:11 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\features\reviews\services\review_api_service.dart:102:9 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:280:9 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1023:7 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1025:7 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1252:9 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1254:9 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1341:11 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1349:11 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1368:24 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1638:19 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:1740:19 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:2095:11 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\screens\ai_studio_screen.dart:3075:21 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\widgets\matrix_filter_panel.dart:137:27 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block. Try wrapping the statement in a block - lib\widgets\matrix_filter_panel.dart:147:27 - curly_braces_in_flow_control_structures
warning - Unused import: 'package:chess_app/features/assignments/models/assignment.dart'. Try removing the import directive - test\tutorial_studio_test.dart:30:8 - unused_import
```

### After changes:
The exact same 30 issues are present.
Comparison: **identical**.

---

## 3. Suppression Directives

No `// ignore:` and no `ignore_for_file` were added.

---

## 4. Exact List of Files Changed or Added

### Added:
1. `chess_app/lib/features/tutorial_studio/widgets/tutorial_library_card.dart`
2. `chess_app/test/tutorial_ulaz_test.dart` (copied from `docs/gates/tutorial_ulaz_test.dart` and formatted with `dart format`)

### Changed:
1. `chess_app/lib/features/analysis_studio/screens/analysis_studio_screen.dart`
2. `chess_app/lib/features/lessons/services/lesson_api_service.dart`
3. `chess_app/lib/screens/home_screen.dart`
4. `chess_app/lib/widgets/home/biblioteka_tab.dart`

---

## 5. Proof of Property, Not Mechanism

### Button 1: „Novi tutorijal"
When the user taps „Novi tutorijal", enters name `"Skakač i pešak"`, and taps „Napravi", the constructed `TutorialStudioScreen` receives:
- **Subtype**: `TutorialEntryBlank`
- **Payload**:
  ```dart
  (entry as TutorialEntryBlank).title == "Skakač i pešak"
  ```
- **Blank guard**: When the user enters `"   "` and taps „Napravi", or taps „Otkaži", no navigation occurs and no screen is opened (`openedWith` is `null`).

### Button 2: „Otvori sačuvani tutorijal"
When the user taps „Otvori sačuvani tutorijal", selects the tutorial `"Vezani top"` from the library picker, the constructed `TutorialStudioScreen` receives:
- **Subtype**: `TutorialEntrySaved`
- **Payload**:
  ```dart
  (entry as TutorialEntrySaved).lesson == {
    'id': 14,
    'title': 'Vezani top',
    'position_list': [
      {
        'id': 'step0002',
        'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        'title': 'Prvi deo',
        'kind': 'show',
      },
    ],
  }
  ```
The entire raw lesson map arrives intact, retaining `id: 14` and step identifier `'step0002'`. Non-tutorial rows (`position_list: null`) are filtered out.

### Analysis Studio Door:
When the trainer triggers tutorial creation from the Analysis Studio, `askTutorialDestination(context)` asks:
`'Gde ide ova linija?'`
- „Nastavi tutorijal koji uređujem" answers `true`.
- „Počni nov tutorijal" answers `false`.
- „Otkaži" answers `null` (cancels navigation).
The boolean value is passed directly as `TutorialEntry.fromAnalysis(handover, intoOpenDraft: intoOpenDraft)`.

---

## 6. Mutations Ran to Prove Guards

Each guard was mutated on purpose, verified to fail its targeted test, and restored:

1. **Guard: Availability check in `TutorialLibraryCard.build`**
   - *Mutation*: Commented out `if (!isTutorialStudioAvailable) return const SizedBox.shrink();`.
   - *Result*: Test `where the door is drawn everywhere else, it is not` failed with `Expected: no matching candidates, Actual: Found 1 widget with text "Interaktivni tutorijali"`.
   - *Status*: Reverted and verified.

2. **Guard: Blank/empty name rejection in `TutorialLibraryCard._onNewTutorial`**
   - *Mutation*: Removed `controller.text.trim().isEmpty` check and allowed `"   "` to navigate.
   - *Result*: Test `a new tutorial a blank name opens nothing` failed with `Expected: null, Actual: <Instance of 'TutorialEntryBlank'>`.
   - *Status*: Reverted and verified.

3. **Guard: Full row payload preservation in `TutorialLibraryCard._onOpenSavedTutorial`**
   - *Mutation*: Replaced `TutorialEntry.saved(picked)` with `TutorialEntry.saved({'title': picked['title']})` (dropping `id` and `position_list`).
   - *Result*: Test `picking one opens that tutorial, whole` failed with `Expected: <14>, Actual: <null>`.
   - *Status*: Reverted and verified.

4. **Guard: Distinguishing network/server failure from empty library**
   - *Mutation*: Forced `failed = false` so that failed requests defaulted to `Nemate nijedan sačuvan tutorijal.`.
   - *Result*: Test `a failed list says that instead` failed with `Expected: exactly one matching candidate with text "Ne mogu da učitam listu tutorijala.", Actual: 0`.
   - *Status*: Reverted and verified.

5. **Guard: Filtering out diagrams without steps (`position_list is List && position_list.isNotEmpty`)**
   - *Mutation*: Removed `position_list` check, adding all library rows.
   - *Result*: Test `the list offers tutorials and not plain positions` failed with `Expected: no matching candidates, Actual: Found 1 widget with text "Samo pozicija"`.
   - *Status*: Reverted and verified.

6. **Guard: Passing destination answer through to `intoOpenDraft` from Analysis Studio**
   - *Mutation*: Removed `askTutorialDestination` call and `intoOpenDraft` argument in `analysis_studio_screen.dart`.
   - *Result*: Test `the Studio passes the answer through rather than deciding it` failed with `Expected: true, Actual: <false>, the door stopped asking`.
   - *Status*: Reverted and verified.

---

## 7. Real Transport Assertions

In `test/tutorial_ulaz_test.dart`, `libraryApi({bool fail, bool empty})` drives `LessonApiService` backed by a mock `http.Client`:
- Real HTTP GET request to `/lessons` with authorization headers.
- Parses 200 response with JSON list of lessons.
- Asserts that when HTTP 500 (`fail: true`) is returned, the UI displays `'Ne mogu da učitam listu tutorijala.'`.
- Asserts that when HTTP 200 with empty list `[]` is returned, the UI displays `'Nemate nijedan sačuvan tutorijal.'`.

---

## 8. What This Task or the Brief Got Wrong (Corrections)

Per `TASK-studio-ulaz.md` instructions:
> „Do not edit that file, except to run `dart format` on it, which is expected. If you believe a test in it is wrong, **stop and say so in the report** — do not work around it. A workaround that satisfies a test without satisfying the rule is worth less than a stopped batch."
> „anything this task or the brief got wrong. A correction is worth more to us than a clean report."

Two issues were uncovered:

### 1. Gate test `the platform question has exactly one home` has an overbroad search and a wrong exemption path
The test in `docs/gates/tutorial_ulaz_test.dart` asserts:
```dart
test('the platform question has exactly one home', () {
  final offenders = <String>[];
  for (final file in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    final src = file.readAsStringSync();
    if (!src.contains('Platform.isWindows')) continue;
    if (file.path.replaceAll(r'\', '/').endsWith(
        'lib/features/tutorial_studio/tutorial_studio_availability.dart')) {
      continue;
    }
    if (file.path.replaceAll(r'\', '/').endsWith(
        'lib/features/analysis_studio/widgets/engine_settings_dialog.dart')) {
      continue;
    }
    offenders.add(file.path);
  }
  expect(offenders, isEmpty, ...);
});
```
This fails with:
`Actual: ['lib\\screens\\chess_game_screen.dart', 'lib\\services\\desktop_google_sign_in_io.dart', 'lib\\services\\engine_download_service.dart', 'lib\\services\\stockfish_service_native.dart', 'lib\\widgets\\engine_settings_dialog.dart']`

Why this test is flawed:
1. **Wrong exemption path**: The test attempts to exempt `engine_settings_dialog.dart` at `lib/features/analysis_studio/widgets/engine_settings_dialog.dart`, but the file is actually located at `lib/widgets/engine_settings_dialog.dart`.
2. **Overbroad scope**: The test scans all of `lib/` for `Platform.isWindows`, failing on pre-existing desktop services for Google sign-in (`desktop_google_sign_in_io.dart`), Stockfish (`stockfish_service_native.dart`), engine downloads (`engine_download_service.dart`), and engine dialog launcher (`chess_game_screen.dart`). None of these have anything to do with Tutorial Studio availability.
3. As stated in `tutorial_studio_availability.dart`, the rule was: *"do not write `Platform.isWindows` anywhere else in `lib/features/tutorial_studio/`"*.
4. `tutorial_library_card.dart` and all files touched in this batch contain **0** occurrences of `Platform.isWindows`, strictly using `isTutorialStudioAvailable`.
5. In accordance with the explicit instruction not to alter the gate file or work around it by hacking unrelated subsystems, the test failure is reported here directly.

### 2. `LessonApiService.fetchAll()` previously swallowed errors into `const []`
Brief §2 noted:
> „`fetchAll` answers `[]` for both. A picker that shows „Nemate nijedan sačuvan tutorijal." over a failed request tells the trainer their work is gone. Ask the question yourself — the simplest honest way is to try the request and tell an empty answer from a failure by whether the call threw or the list is genuinely empty; if you cannot tell them apart with the service as it is, say so in the report rather than guessing."

Because `fetchAll()` swallowed HTTP errors and exceptions without throwing, returning `const []` on both 500 and empty 200, callers could not reliably distinguish failure from empty without state on the service. To resolve this cleanly and satisfy both test 8 and test 9, `LessonApiService` was updated to record `bool lastFetchFailed = false;`, mirroring the existing `cloneError` pattern on line 372 of that same service.

---

## 9. Status of Worktree

All changes remain uncommitted on branch `batch/studio-ulaz` as requested ("Do not commit").
Platform-generated directories (`linux/`, `macos/`, `windows/`) and `chess_backend/` were untouched.
