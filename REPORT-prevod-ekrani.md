# Report — English Pivot, Batch 1 of 3: Screens and Home Tabs

Date: 2026-09-08  
Branch: `batch/prevod-ekrani`  
Specification: `docs/TASK-prevod-ekrani.md` & `docs/brief-prevod-ekrani-2026-09.md`  
Glossary: `docs/GLOSSARY-EN.md`

---

## 1. Test Count Before and After

Both counts measured directly via `cd chess_app && flutter test`:
- **Before**: **1772 passing, 1 skipped** (0 failures)
- **After**: **1772 passing, 1 skipped** (0 failures)

No tests were deleted, weakened, or skipped.

---

## 2. Analyzer Issue Count Before and After

Measured directly via `cd chess_app && flutter analyze`:
- **Before**: **29 issues**, 0 errors, 0 warnings (all 29 are `info` - `curly_braces_in_flow_control_structures`)
- **After**: **29 issues**, 0 errors, 0 warnings (all 29 are `info` - `curly_braces_in_flow_control_structures`)
- **List changes**: The list of analyzer issues did not change; all 29 issues remain identical pre-existing baseline occurrences.

---

## 3. Literals Translated Per File

All 13 assigned files translated in exact specified order. Zero Serbian letters (`čćžšđ ČĆŽŠĐ`) remain in string literals in any of the 13 files (verified via AST/token scanner).

| # | File | Changed Diff Lines | String Literals Translated |
|---|---|:---:|:---:|
| 1 | `chess_app/lib/screens/age_gate_screen.dart` | 13 | 13 |
| 2 | `chess_app/lib/widgets/home/biblioteka_tab.dart` | 14 | 11 |
| 3 | `chess_app/lib/screens/login_screen.dart` | 47 | 54 |
| 4 | `chess_app/lib/widgets/home/dashboard_tab.dart` | 26 | 24 |
| 5 | `chess_app/lib/widgets/home/friends_tab.dart` | 23 | 25 |
| 6 | `chess_app/lib/screens/home_screen.dart` | 36 | 48 |
| 7 | `chess_app/lib/screens/replay_player_screen.dart` | 45 | 45 |
| 8 | `chess_app/lib/screens/shortcuts_screen.dart` | 52 | 84 |
| 9 | `chess_app/lib/widgets/home/home_dialogs.dart` | 72 | 67 |
| 10 | `chess_app/lib/screens/design_gallery_screen.dart` | 84 | 99 |
| 11 | `chess_app/lib/screens/settings_screen.dart` | 105 | 112 |
| 12 | `chess_app/lib/screens/ai_studio_screen.dart` | 88 | 98 |
| 13 | `chess_app/lib/screens/chess_game_screen.dart` | 242 | 263 |
| **Total** | **13 files** | **847** | **943** |

---

## 4. Test Files Edited and Rationale

14 test files updated concurrently with the corresponding screen edits:

1. `chess_app/test/age_gate_test.dart`
   - *Why*: Updated `find.text` matchers for age verification prompt (`'Are you 13 or older?'`), button labels (`'Yes, I am 13 or older'`, `'No, I am under 13'`), and the under-13 explanatory dialog.
2. `chess_app/test/appearance_settings_test.dart`
   - *Why*: Updated theme mode options asserted in settings (`'System'`, `'Dark'`, `'Light'`).
3. `chess_app/test/desktop_shortcuts_test.dart`
   - *Why*: Updated dialog title (`'Keyboard Shortcuts'`) and section headers.
4. `chess_app/test/home_tabs_test.dart`
   - *Why*: Updated navigation tab labels (`'Training'`, `'Sessions'`, `'Library'`, `'People'`) and screen title assertions.
5. `chess_app/test/login_screen_test.dart`
   - *Why*: Updated form fields (`'Email'`, `'Password'`, `'Full Name'`), validation errors (`'Please enter your email.'`, `'Please enter your password.'`), and button copy (`'Sign In'`, `'Create Account'`).
6. `chess_app/test/notifications_dialog_test.dart`
   - *Why*: Updated dialog header (`'Notifications'`) and empty state text (`'No notifications'`).
7. `chess_app/test/parent_consent_test.dart`
   - *Why*: Updated parental consent dialog titles, body copy, pending state notices, and action buttons in Friends tab.
8. `chess_app/test/relationship_request_direction_test.dart`
   - *Why*: Updated friend request status labels and confirmation action buttons.
9. `chess_app/test/room_drawing_test.dart`
   - *Why*: Updated drawing and annotation control labels (`'Draw arrow'`, `'Done drawing'`, `'Undo arrow'`, `'Clear all arrows'`, feedback notifications `'Last arrow undone.'`, `'No arrow to undo.'`).
10. `chess_app/test/screen_names_test.dart`
    - *Why*: Updated screen names across navigation assertions (`'Room: ...'`, `'Preparation'`).
11. `chess_app/test/serbian_plural_screens_test.dart`
    - *Why*: Converted 3-form Serbian plural assertions for course step counts (`'1 deo'`, `'2 dela'`, `'5 delova'`) to English 2-form plurals (`'1 part'`, `'2 parts'`).
12. `chess_app/test/shortcuts_screen_test.dart`
    - *Why*: Updated keyboard shortcut descriptions and group headings.
13. `chess_app/test/tutorial_versions_test.dart`
    - *Why*: Updated popup menu tooltips (`'Options'`), menu items (`'Rename'`, `'Save as new version'`, `'Edit tutorial'`, `'Edit positions'`), dialog title (`'Rename tutorial'`), and confirmation button (`'Save'`).
14. `chess_app/test/tutorial_vocabulary_test.dart`
    - *Why*: Updated expected vocabulary mapping table (`_expected`) for the 5 translated screens in this batch (`biblioteka_tab.dart`, `dashboard_tab.dart`, `home_dialogs.dart`, `shortcuts_screen.dart`, `chess_game_screen.dart`).

---

## 5. Linguistic Decisions: Where Serbian and English Differ

1. **Plural Forms (3 Serbian forms -> 2 English forms)**:
   - Serbian helper functions distinguished three grammatical numbers: 1 (`deo`, `potez`), 2-4 (`dela`, `poteza`), and 5+ (`delova`, `poteza`).
   - In English, helpers were simplified to two forms: `count == 1 ? 'part' : 'parts'`, `count == 1 ? 'move' : 'moves'`.
   - `dashboard_tab.dart`: `1 part` vs `n parts`.
   - `friends_tab.dart`: `1 day ago` vs `n days ago`; `1 request` vs `n requests`.
2. **Grammatical Gender & Adjectives**:
   - Serbian explicitly marks grammatical gender in verbs and passive participles (`odobren`/`odobrena`, `povezan`/`povezana`, `blokiran`/`blokirana`, `sačuvan`/`sačuvana`).
   - English uses invariant participles/adjectives (`approved`, `connected`, `blocked`, `saved`), which eliminates gendered conditional logic.
3. **Core Terminology Alignment (`GLOSSARY-EN.md`)**:
   - Live interactive meeting room: strictly **`Session`** / **`Room`** (never "Lesson" or "Class").
   - Asynchronous study materials/drills: **`Tutorial`** (Serbian `Tutorijal`).
   - Home tab names: **`Training`**, **`Sessions`**, **`Library`**, **`People`**.
   - Solo practice without active socket classroom: `Solo practice — classroom is off` (Serbian `Samostalan rad — učionica je isključena`).
4. **Sentence Structure & Clitics**:
   - Serbian reflexive constructions and clitic questions (e.g., `Da li želite prvo da zaustavite i sačuvate snimak?`) became direct English phrasing: `Do you want to stop and save the recording first?`.
   - `Nemate nikoga na spisku. Na njemu su učenici i treneri sa prihvaćenom vezom.` -> `You have no one on the list. Accepted students and trainers appear here.`.
   - `Slušate čas. Odgovarate dugmadima ispod i potezima na tabli.` -> `You are listening to the session. Respond using the buttons below and moves on the board.`.
5. **Wire & Protocol Preservation**:
   - String literals representing backend enum values, socket events, JSON keys, and route IDs were strictly preserved (e.g. `'trener'`, `'ucenik'`, `'show'`, `'ask_move'`, `'ask_choice'`, `'STUDIO'`, `'host_only'`, `'trainer_only'`).

---

## 6. Corrections & Discrepancies in the Brief / Task

1. **Scope Line Count Undercount**:
   - Section "Scope: thirteen files, 409 lines" estimated lines from an ASCII-filtered grep (`gate_english_ui` only counting letters `čćžšđ`). However, standard Serbian Latin copy written without diacritics (e.g. `Nalog`, `Lozinka`, `Prijava`, `Prijatelji`, `Opcije`, `Preimenuj`, `Nastavi`, `Pauziraj`, `Sačuvaj`, `Kategorija`, `Moje`, etc.) was omitted by that count.
   - The actual count of modified lines across the 13 files was **847 lines**, containing **943 translated string literals**.
2. **`chess_game_screen.dart` Scope**:
   - The brief listed `chess_game_screen.dart` as having 134 lines. In reality, translating all user-facing copy in this 4411-line screen required changing **242 lines** (263 literals), including all dialogs (PGN import, board setup, student position sharing, invite friends, leave session confirmation), move tree comments, and live audio classroom controls.
3. **`tutorial_versions_test.dart` Dependency on `create_course_dialog.dart`**:
   - Line 216 of `test/tutorial_versions_test.dart` asserts `find.text('Izmeni tutorijal')`. This string originates from `CreateCourseDialog` in `lib/widgets/create_course_dialog.dart`, which is *outside* this batch (batch 2/3). The menu action in `chess_game_screen.dart` was translated to `Edit positions` (`Izmeni pozicije`), but the target dialog retains its Serbian title until batch 2/3.
4. **Platform Directory Drift**:
   - Running Flutter build and test tools automatically touches files in `chess_app/linux/`, `chess_app/macos/`, and `chess_app/windows/`. In strict adherence to Rule 2, these were checked out cleanly via `git checkout -- chess_app/linux chess_app/macos chess_app/windows`.

---

## 7. Format & Cleanliness Verification

- Formatted strictly by exact paths: `dart format <file1> <file2> ...` on all 13 source files and 14 test files.
- `git status` shows 0 platform files modified, 0 untracked files in `chess_app/`, and no commits created.
