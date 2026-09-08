# Translation Report: Tutorial Studio & Assignments (`docs/TASK-prevod-tutorijal.md`)

This report documents the translation of user-facing Serbian copy to English across the 21 target files in `chess_app/lib/`, following the instructions in `docs/TASK-prevod-tutorijal.md` and the guidelines in `.agents/agents/flutter_translator.md`.

---

## 1. Test Count Before and After

Both counts were measured directly in this environment with `flutter test`:

- **Before this batch**: 1774 passed, 1 skipped (0 failures).
- **After this batch**: 1774 passed, 1 skipped (0 failures).

The 1 skipped test is `@Tags(['golden'])` (`test/design_gallery_golden_test.dart`), which is intentionally configured to run only when visual regression artifacts are updated.

---

## 2. Analyzer Count Before and After

Measured with `flutter analyze`:

- **Before this batch**: 29 issues found (all `info`, all `curly_braces_in_flow_control_structures`, 0 warnings, 0 errors).
- **After this batch**: 29 issues found (all `info`, all `curly_braces_in_flow_control_structures`, 0 warnings, 0 errors).
- **List check**: The exact set of 29 pre-existing analyzer baseline info issues did not change. No new lints, warnings, or errors were introduced.

---

## 3. String Literals Translated per File

Across the 21 files specified by the task brief, 476 user-facing string literals were translated in-place:

1. `chess_app/lib/features/tutorial_studio/widgets/tutorial_flow_panel.dart`: 4
2. `chess_app/lib/features/tutorial_studio/widgets/tutorial_pgn_panel.dart`: 6
3. `chess_app/lib/features/tutorial_studio/services/tutorial_draft_service.dart`: 3
4. `chess_app/lib/features/assignments/widgets/assignment_detail_gate.dart`: 4
5. `chess_app/lib/features/tutorial_studio/widgets/tutorial_sections_panel.dart`: 16
6. `chess_app/lib/features/assignments/widgets/assign_lesson_dialog.dart`: 17
7. `chess_app/lib/features/assignments/widgets/create_assignment_dialog.dart`: 17
8. `chess_app/lib/features/assignments/screens/custom_assignment_overview_screen.dart`: 13
9. `chess_app/lib/features/assignments/screens/lesson_viewer_screen.dart`: 17
10. `chess_app/lib/features/assignments/screens/my_assignments_screen.dart`: 17
11. `chess_app/lib/features/assignments/services/assignment_api_service.dart`: 24
12. `chess_app/lib/features/assignments/widgets/parent_report_dialog.dart`: 19
13. `chess_app/lib/features/assignments/widgets/trainer_student_archive_view.dart`: 15
14. `chess_app/lib/features/lessons/services/lesson_api_service.dart`: 18
15. `chess_app/lib/features/assignments/screens/custom_puzzle_solver_screen.dart`: 19
16. `chess_app/lib/features/assignments/models/assignment.dart`: 37
17. `chess_app/lib/features/assignments/screens/assignment_review_screen.dart`: 38
18. `chess_app/lib/features/assignments/screens/student_progress_screen.dart`: 34
19. `chess_app/lib/features/lessons/widgets/lesson_step_editor_panel.dart`: 39
20. `chess_app/lib/features/tutorial_studio/widgets/tutorial_library_card.dart`: 36
21. `chess_app/lib/features/tutorial_studio/screens/tutorial_studio_screen.dart`: 83

**Total string literals translated**: 476
**Serbian characters (`čćžšđ ČĆŽŠĐ`) remaining in string literals across the 21 files**: 0

---

## 4. Test Files Edited and Why

The following 37 test files were updated solely to keep their widget and unit assertions aligned with the translated English copy:

1. `test/screen_names_test.dart`: Updated the allowed screen name string from `'Studio za tutorijal'` to `'Tutorial Studio'`.
2. `test/tutorial_library_actions_test.dart`: Updated expected screen title `'Studio za tutorijal'` to `'Tutorial Studio'`.
3. `test/tutorial_studio_refusals_test.dart`: Updated save button `'Sačuvaj tutorijal'` -> `'Save tutorial'`, kind labels `'Traži potez na tabli'` -> `'Ask for move on board'`, leak banner `'Dete bi videlo odgovor'` -> `'The student would see the answer'`, dialog action `'Ukloni liniju i postavi pitanje'` -> `'Remove line and ask question'`, and cancel action.
4. `test/tutorial_tok_test.dart`: Updated tab headers `'Tok'` -> `'Flow'` and `'Stablo'` -> `'Tree'`.
5. `test/tutorial_tok_edit_test.dart`: Updated `'Sačuvaj tutorijal'` -> `'Save tutorial'`, kind selector `'Traži odgovor iz liste'` -> `'Ask for answer from list'`, and `'Dodaj odgovor'` -> `'Add answer'`.
6. `test/tutorial_delovi_test.dart`: Updated continuation dialog options `'Odakle počinje?'` -> `'Where does it start?'`, `'Odavde'` -> `'From here'`, `'Nova tabla'` -> `'New board'`, cancel text `'Otkaži'` -> `'Cancel'`, and refusal message `'Poslednji deo ne može biti obrisan.'` -> `'The last part cannot be deleted.'`.
7. `test/tutorial_orientation_test.dart`: Updated `'Sačuvaj tutorijal'` -> `'Save tutorial'`, `'Odavde'` -> `'From here'`, and `'Nova tabla'` -> `'New board'`.
8. `test/tutorial_tri_akcije_test.dart`: Updated `'Sačuvaj tutorijal'` -> `'Save tutorial'`, `'Odavde'` -> `'From here'`, `'Nova tabla'` -> `'New board'`, and rename dialog save button `'Sačuvaj'` -> `'Save'`.
9. `test/tutorial_authoring_test.dart`: Updated `'Sačuvaj tutorijal'` -> `'Save tutorial'`, `'From here'`, `'Ask for move on board'`, `'Correct move: ...'`, `'Ask for answer from list'`, and `'Add answer'`.
10. `test/tutorial_delete_move_test.dart`: Updated `'Sačuvaj tutorijal'` -> `'Save tutorial'`, delete move dialog title `'Obriši potez?'` -> `'Delete move?'`, actions `'Odustani'` -> `'Cancel'` and `'Obriši'` -> `'Delete'`, and tab `'Stablo'` -> `'Tree'`.
11. `test/tutorial_comment_only_part_test.dart`: Updated `'Sačuvaj tutorijal'` -> `'Save tutorial'`.
12. `test/tutorial_studio_test.dart`: Updated position setup tooltip `'Unos pozicije'` -> `'Position setup'` and stored draft prompt action `'Nastavi'` -> `'Continue'`.
13. `test/tutorial_pgn_fen_test.dart`: Updated `'Sačuvaj tutorijal'` -> `'Save tutorial'`, PGN position mismatch dialog titles and actions (`'Text starts from a different position'`, `'Use that position'`, `'Keep existing'`, `'Cancel'`, `'Not applied'`, `'Text does not start from here'`, `'Use starting position'`, `'has no starting position'`).
14. `test/tutorial_pgn_caret_test.dart`: Updated `'Sačuvaj tutorijal'` -> `'Save tutorial'` and comment dialog actions (`'Sačuvaj'` -> `'Save'`, `'Odustani'` -> `'Cancel'`).
15. `test/tutorial_pgn_tab_test.dart`: Updated `'Sačuvaj tutorijal'` -> `'Save tutorial'`.
16. `test/tutorial_reopen_test.dart`: Updated `'Sačuvaj tutorijal'` -> `'Save tutorial'`.
17. `test/tutorial_oznake_test.dart`: Updated `'Sačuvaj tutorijal'` -> `'Save tutorial'`.
18. `test/tutorial_raspored_test.dart`: Updated `'Sačuvaj tutorijal'` -> `'Save tutorial'`.
19. `test/tutorial_section_titles_test.dart`: Updated `'Nova tabla'` -> `'New board'` and `'Sačuvaj tutorijal'` -> `'Save tutorial'`.
20. `test/tutorial_studio_fields_test.dart`: Updated `'Traži odgovor iz liste'` -> `'Ask for answer from list'` and `'Dodaj odgovor'` -> `'Add answer'`.
21. `test/tutorial_entry_test.dart`: Updated stored draft dialog buttons (`'Odustajem'` -> `'Cancel'`, `'Nov'` -> `'New'`, `'Nastavi'` -> `'Continue'`).
22. `test/mobile_layout_test.dart`: Updated prefilled assignment title assertion from `'Drill: vezivanje'` to `'Drill: pin'` to reflect translated Lichess theme label mapping.
23. `test/assignment_model_test.dart`: Updated test fixture and helper assertions for assignment status/type strings.
24. `test/assignment_overview_test.dart`: Updated UI labels for tabs, dates, and status filters.
25. `test/features/assignments/trainer_student_archive_view_test.dart`: Updated empty state and table column header strings.
26. `test/lesson_answer_stays_hidden_test.dart`: Updated lesson step kind labels and step editor buttons.
27. `test/lesson_board_playable_test.dart`: Updated viewer navigation and instruction label checks.
28. `test/lesson_editor_test.dart`: Updated editor panel buttons and kind selector labels.
29. `test/lesson_narration_test.dart`: Updated speech/narration text assertions.
30. `test/lesson_step_asks_test.dart`: Updated question step kinds and verification text.
31. `test/lesson_step_order_extra_test.dart`: Updated step order and movement control labels.
32. `test/lesson_step_order_test.dart`: Updated step list actions and reordering buttons.
33. `test/lesson_viewer_branches_test.dart`: Updated branch navigation button labels.
34. `test/navigation_flow_test.dart`: Updated screen route names and bottom navigation tab titles.
35. `test/tutorial_branching_test.dart`: Updated branch selection and tree interaction texts.
36. `test/tutorial_ulaz_test.dart`: Updated entry flow strings and card action tooltips.
37. `test/tutorial_vocabulary_test.dart`: Updated vocabulary test assertions to match the newly adopted English terms.

---

## 5. Tutorial vs Session Decisions

The distinction between "Tutorial" and "Session" was evaluated at every point of use:

- **Tutorial**:
  - Used strictly for authoring and managing structured, self-paced interactive learning units created in the Tutorial Studio (formerly "Studio za tutorijal").
  - Examples:
    - Screen title: `Tutorial Studio` (not `Tutorial Session` or `Analysis Studio`).
    - Save action: `Save tutorial`.
    - Library actions: `Send tutorial`, `Delete tutorial`.
    - Draft management: `TutorialDraftService`, `You have an unfinished tutorial`.
    - Content pieces: `Part 1`, `The last part cannot be deleted.`
- **Session**:
  - Used for live, interactive, or operational user contexts (e.g. an active student practice run, a solver run, or an engine analysis sitting).
  - Examples:
    - Interactive viewer screen: treated as viewing/solving a lesson or assignment session.
    - Puzzle solver: `Puzzle session` / `Assignment` rather than a tutorial authoring session.
    - PGN export header: preserved `'Analysis Studio Session'` in `screen_names_test.dart` because it is an external PGN metadata header read by standard chess software.

---

## 6. Nuances Between Serbian and English Phrasing

Several Serbian phrases required careful idiomatic English translations rather than literal word-for-word substitutions:

1. **"Dete" vs "Student"**:
   - In Serbian Latin, the original copy frequently used "dete" ("Dete bi videlo odgovor", "Poslato detetu").
   - Except for `parent_report_dialog.dart` (where the recipient is a parent receiving a report specifically about their child), all user-facing strings were translated using "student" to support a general learning audience.
2. **Grammatical Plural Forms (`1 deo`, `2 dela`, `5 delova`)**:
   - Serbian differentiates between singular, paucal (2-4), and plural (5+) forms.
   - In English, helper methods like `_partsWord` and `_movesWord` were simplified to return `"part"` / `"parts"` and `"move"` / `"moves"` based on `count == 1`.
3. **Board Continuity and Questions**:
   - Serbian phrases `"Odavde"` and `"Nova tabla"` became concise modal actions `"From here"` and `"New board"`.
   - The question `"Odakle počinje?"` was translated to `"Where does it start?"`.
4. **Question Kinds**:
   - Serbian descriptive phrases `"Traži potez na tabli"` and `"Traži odgovor iz liste"` were translated to `"Ask for move on board"` and `"Ask for answer from list"` in selectors, and `"Find the move"` / `"Choose the answer"` on button action triggers.
5. **Rename Helper Text**:
   - `"Prazno — zove se po onome što piše u njemu."` was translated cleanly as `"Empty — named after what is written in it."`.

---

## 7. Observations & Feedback on Task Specifications

1. **Test Dependencies on Translated Strings**:
   - Several tests outside the 21 target files had hardcoded expectations matching Serbian strings (e.g. `test/mobile_layout_test.dart` expecting `'Drill: vezivanje'`, which came from `themeLabel('pin')` translated in `assignment.dart`). All such tests were updated so the entire suite passes cleanly.
2. **`screen_names_test.dart` Allowlist**:
   - The test enforcing that the word "studio" only names one user-facing screen had an allowlist containing `"'Studio za tutorijal'"`. Updating this entry to `"'Tutorial Studio'"` was required so that the screen name rule remains active and enforced for English copy.
3. **Models Outside the Target Scope**:
   - `models/tutorial_draft.dart` was not in the 21 files list, so its fallback `generatedSectionTitle(index)` remains `'Deo ${index + 1}'`. The screen and its UI presentation handle this correctly, and 0 Serbian characters exist in the 21 specified files.
