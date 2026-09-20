# Brief — lists, phase 1: Choose a game gets a search box

`docs/PLAN-LISTE.md`, phase 1. **App only.** Do not touch `chess_backend/`,
`db.js`, `.env`, `deploy/`, or anything in `docs/` other than reading it. Do
not start a server.

**Two rules about your own processes**: do not search the disk from `/` (or
`C:\`) — package sources are under the paths in
`chess_app/.dart_tool/package_config.json`; and **stop anything you start in
the background before you report**.

**If you believe a test in the gate is wrong, stop and say so in the report —
do not work around it.** A workaround that satisfies a test without satisfying
the rule is worth less than a stopped phase.

## Where this starts

`chess_app/lib/widgets/game_selector_dialog.dart` is 57 lines and has not
changed since it was written. It is opened from two places — a pasted or
loaded PGN holding more than one game — and the owner's collection has **4126**
of them:

| Caller | File |
|---|---|
| The board screen, pasted text and a picked `.pgn` file | `screens/chess_game_screen.dart:2564` (`_showGameSelectorDialog`) |
| Board Setup, which **awaits** the dialog | `features/analysis_studio/widgets/board_setup_dialog.dart:214` (`_loadPgnContent`) |

Today it is an `AlertDialog` whose content is `SizedBox(width: 400, height:
300)` around a `ListView.builder`. About five rows are visible out of 4126,
there is no search, and the subtitle is a raw `pgnBody.substring(0, 60)` that
cuts mid-token.

**Measured on master, 20.9.2026, and worth knowing before you start:** that
`SizedBox` asks for a width of 400 and is given **912** in a 1400 px window.
`AlertDialog` lays title, content and actions out under an `IntrinsicWidth`,
which takes the widest intrinsic — here the title string — and forces every
child to it. So the width today is not fixed, it is *accidental*: it follows
the title text and the font. The **height is genuinely fixed at 300**, and
that is the number that means "five rows out of 4126".

`features/library/widgets/board_preview_dialog.dart` already carries this
warning in a comment and already does the right thing — it reads its size from
`MediaQuery`. Copy that instinct.

**There is no existing test for this dialog.** Nothing in `chess_app/test`
mentions `GameSelectorDialog` or "Choose a game", so this phase amends no
finder anywhere. That is unusual for this plan and it is why phase 1 goes
first.

## The gate

`docs/gates/game_selector_search_test.dart`. **Copy it byte-identical** into
`chess_app/test/game_selector_search_test.dart`. Do not edit it. It was run
against master by the lead on 20.9.2026: **6 red, 3 green.**

The three green cases are there to hold still what this change could break —
the unfiltered title, the pop-then-callback order, and a 360 dp phone. They
are not decoration; the second one is load-bearing (see below).

## What to build

Keep the **constructor exactly as it is** — `games` and `onGameSelected`. Both
callers must compile untouched, and you must not edit either of them.

1. **A search field**, exactly one `TextField` in the dialog.

2. **What it matches**, case-insensitively, and nothing else:
   - `headers['White']`
   - `headers['Black']`
   - `pgnBody`

   **Not** the other headers. The gate has a game whose `Event` is "Zagreb
   Open" and whose players and moves contain no "zagreb"; a search that walks
   the whole header map finds it and fails that case. The reason is not
   pedantry: if the header map is searched, typing a date or a result silently
   reorders the list.

3. **The title counts.** Unfiltered it says the total as it does today —
   `Choose a game from the collection (4126)`. While a query narrows it, it
   says how many of how many: the gate asks for the text `2 of 4126` to be on
   screen. **Derive both numbers from the lists at build time.** Do not cache a
   count in a field; re-derive it (CLAUDE.md, numbers rule 17).

4. **An empty result says so.** The gate asks for text containing `No game
   matches` and for no row to be drawn. Write the sentence in English, in the
   app's ordinary register.

5. **Size from `MediaQuery`, not from a constant and not from the title.** Not
   gated, for the reason in "Where this starts" — a threshold on today's
   accidental width could not be written honestly. What *is* gated is the
   height: in a 1400 × 900 window the list must be taller than 480 (master
   gives 300), and at 360 × 640 nothing may overflow. Clamp both dimensions so
   a very large window does not give a dialog the width of the screen.

6. **The subtitle stops cutting mid-token.** `pgnBody.substring(0, 60)` cuts
   inside a move. Trim to a whitespace boundary, normalise runs of whitespace,
   and append the ellipsis only when something was actually dropped. Keep it a
   private helper in this file — it has one caller, and a second home for it
   would be a second rule (CLAUDE.md, rule 12).

## What not to change

- **Do not reorder the pop and the callback.** Today the row's `onTap` calls
  `Navigator.pop(context)` and *then* `onGameSelected(game)`.
  `board_setup_dialog._loadPgnContent` awaits this dialog and writes the chosen
  game into its text box; a callback that fires before the pop, or a pop that
  never happens, hangs that caller. The gate holds this.
- **Do not build the data table.** Columns, sorting and paging are phase 7 of
  the plan and are worth less than the search box. A phase that grows past its
  brief cannot be graded against it.
- **Do not add a filter row** (Svi / Pobede / Porazi). That is the Gemini
  document's idea and it is not in this phase.
- **Do not touch the two callers**, `AlertDialog` elsewhere, or any other
  dialog.

## How it is graded

- The gate file in `chess_app/test/` **byte-identical** to
  `docs/gates/game_selector_search_test.dart`. This is checked, not trusted.
- Nothing outside `chess_app/lib/widgets/game_selector_dialog.dart` and
  `chess_app/test/game_selector_search_test.dart`. If you believe another file
  must change, stop and say so.
- No new `// ignore`.
- `dart format` run on every Dart file you touched.
- `flutter analyze`: the **same 26 infos**, no new one. Paste the summary line
  and the list.
- `flutter test` green, and the count reported. It should rise by the 9 cases
  in the gate plus any of your own.
- **Run the gate once against your own change with the search *matching on the
  header map* instead of the two names**, and report that the "players and the
  moves, and nothing else" case goes red. If it stays green, your filter is not
  reading what you think it is and the report must say so.

## Your own processes — answer this explicitly

Phase 0's worker started `flutter test` in the background and returned without
it, twice. The instruction it read past was a sentence exactly like the one at
the top of this brief, so here it is as a question your report must answer:

> **State that no process you started is still running, and say how you
> confirmed it.**

Run `flutter test` in the **foreground** and wait for it. It takes about ten
minutes on this machine — `game_tutorial_run_test` alone is most of that. Do
not run anything else while it runs, and do not report before it has finished.

## In your report

Say, in this order: the numbers above; the sentence about your own processes;
any case in the gate you think is wrong; and **what this brief got wrong** — anything it asserts about the code
that turned out not to hold. Write that section even if it is empty.
