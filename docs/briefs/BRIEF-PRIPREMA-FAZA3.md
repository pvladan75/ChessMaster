# Brief — Preparation, phase 3: recording here, and squares in the timeline

`docs/PLAN-PRIPREMA.md` — read §2's paragraphs on a recording made in
Preparation and its two readers, §4's **D11** and **D13**, and phases 1–3 under
§6. Phases 1 and 2 are on `master`: `lib/features/preparation/` is the screen
with its doors for material, and the app cannot reach it yet. This phase moves
the recording of a lesson onto it. The sketch is `docs/skice/priprema.html`:
`?v=C&w=1536&h=792&s=rec` is the bar while a take runs.

**Work only in this worktree**:
`D:\Projekti\chess_master\.claude\worktrees\priprema-faza-3` (branch
`priprema-faza-3`). Every command runs from its `chess_app/`. Touch nothing in
`D:\Projekti\chess_master` itself, commit nothing, push nothing. `pub get` has
been run here.

Baseline on `master` at `0f918e7d`, measured 27.9.2026 with nothing else
running: **4295 passed, 1 skipped**; `flutter analyze` the **22** known infos
(all `curly_braces_in_flow_control_structures`).

If you believe a test in the gate is wrong, **stop and say so in the report** —
do not work around it. A workaround that satisfies a test without satisfying
the rule is worth less than a stopped batch. „The gate is wrong" and „here is
my fix" are graded separately. **And when a test's own timing or helper is
what stands in your way, say that — do not change what the screen does for a
person in order to fit it.** Both earlier phases' workers did once, and both
changes were reverted on grading.

## What is already in this worktree, and is the lead's

Uncommitted, and **not yours to edit** except to report a fault:

| file | what it is |
|---|---|
| `chess_backend/test/fixtures/lesson_timeline.json` | the one fixture both readers are held to |
| `chess_backend/test/lesson_timeline_film.test.js` | the film's half, and the judge's |
| `lib/models/recording_models.dart` | `replayFrameAt` reads `squares`, and reads the marks from the **latest event, whatever its kind** |
| `lib/screens/replay_player_screen.dart` | the player draws the squares |
| `test/lesson_timeline_readers_test.dart`, `test/replay_squares_test.dart` | 5 cases, green |
| `lib/features/preparation/screens/preparation_screen.dart` | **three seams added to the constructor, unused**: `lessonRecordingApi`, `pcmSourceFactory`, `lessonTakeDir` |
| `test/preparation_recording_test.dart` | **the gate**, 30 cases |

No server source changes in this phase, and you make none: the judge already
keeps whatever an event's `data` holds, and the film already draws `squares`
from any event. The backend is not yours to run.

## The gate

`test/preparation_recording_test.dart`, 30 cases. Its head comment is the
frozen contract: the seams, every key, every sentence, what the bar holds while
a take runs, what each event carries. Today all 30 are red, each because
`prep-record` is not on the screen.

**This gate has been compiled and watched going red; it has not been watched
going green.** Where a case cannot pass — a finder that matches two things, a
width that the real widgets cannot meet, arithmetic of mine that is off — that
is a fault of the gate and the report's first section.

The pass condition:

```
flutter test test/preparation_recording_test.dart test/preparation_material_test.dart test/preparation_screen_test.dart test/preparation_layout_test.dart test/lesson_timeline_readers_test.dart test/replay_squares_test.dart test/replay_frame_test.dart test/lesson_recording_ui_test.dart
```

all green, **and** the full suite at **4295 + 5 + 30 = 4330 passed, 1
skipped** plus the cases you add yourself (say how many, by file), no existing
test deleted, skipped or weakened, **and** `flutter analyze` with the same 22
infos and nothing new, no `// ignore` added.

## What is built

The behaviour being moved is the room's:
`lib/screens/chess_game_screen.dart`, from „Recording a lesson in Preparation"
(`:3555`) to `_buildLessonRecordingStrip`, the four callers of `_markLesson`
(`:856`, `:1824`, `:2050`, `:2127`) and the `PopScope` at `:3042`. Read it
first. **Do not import that file and do not change it** — the room keeps its
recording until phase 4 deletes it, and `test/lesson_recording_ui_test.dart`
stays green untouched.

What is reused as it is, and a second copy of any of it is a finding:
`LessonTake`, `WavFileSink`, `RecordPcmSource`, `narrationClockOf`,
`narrationFallbackMaxMs` (`lib/features/tutorial_studio/services/`),
`LessonRecordingApi` (`lib/services/lesson_recording_api.dart`),
`AppFeedback`.

### 1. The take

The order is the room's and it is the point: **the server is asked first**
(`permit()`), a refusal is said and the microphone is never opened; then the
file, then the microphone. A microphone the app may not use is said and leaves
no file. Stop — by the trainer or by the cap — asks for a title; „Discard"
there drops the take; an empty title sends nothing. The upload keeps the file
on the device until the server says 201, and a failure offers „Try again".
Leaving the screen is refused while a take runs, with the room's sentence.

Put the take's handling in a class of its own under
`lib/features/preparation/services/` if that keeps the screen readable — the
screen is 1500 lines already. The dialogs' keys and sentences are the room's,
word for word (the gate's head lists them).

### 2. The bar (D11)

Idle: „Record" (`prep-record`) joins the bar at every width — a word on the
wide bar, an icon with the tooltip „Record" on the narrow one.

While a take runs, **the bar says it; nothing is drawn under the bar**, so the
board is the size it was. `prep-recording` holds a mark that is a shape and
not only a colour (a dot recording, bars paused — the owner is colourblind),
the clock, and „N s left" in the take's last minute. Then „Pause"/„Resume",
„Stop and save", „Discard" with the room's keys and tooltips.

- Wide bar: „Library" and „Board" stay; „Save as…", „Record" and ⋮ are not
  drawn.
- Narrow bar: ⋮ stays, holding the four items that put something on the board
  and none that keep.
- A tutorial on the board is still walked: from the bar on the wide bar and on
  a phone held on its side; on a phone held upright, where 360 px do not hold
  both, „Previous part" and „Next part" are items of ⋮ under the same keys
  (`prep-part-prev`, `prep-part-next`) **while a take runs**, and in the bar as
  today when none does.
- The clock is drawn whole at every width. „N s left" is what gives way where
  there is no room.

**Measure the natural widths before deciding** what is a word and what is an
icon at 900 wide — with a tutorial on the board and a take running, the bar
holds the recording's state, the stepper, „Library", „Board" and three
controls. Say in the report what you measured.

### 3. The timeline

Three kinds, stamped through `LessonTake.mark` and nothing else. **Every event
carries the marks of the board it leaves behind**, so that what the player
replays is what the trainer saw:

| kind | when | `data` |
|---|---|---|
| `init` | „Record" is pressed; and every board put on the screen afterwards — the Library, the four items of „Board", a tutorial's part | `fen`, `pgn`, and the position's `arrows` / `squares` where it has any |
| `move` | a move is played | `fen`, `from`, `to`, and the marks the move already holds where it has any |
| `move` | the cursor lands on a move already in the tree — the strip, the keyboard, a tap in the tree, a deleted variation that took the cursor with it | `fen`, and the marks of the move it lands on |
| `arrow_drawn` | the marks on the board in front of the trainer change — drawn, removed, „Undo", „Clear" | `arrows` and `squares`, whole, **both always** |

An arrow is `{from, to, color}`, a square `{square, color}`. The first tap of
an arrow changes nothing and writes nothing. `fen` is the node's own, never
the board controller's.

**One function answers for all of it.** The screen has one place that puts a
board on the screen (`_setNewRoot`) and few that move the cursor; the stamp
belongs where those are, not at each door — a door added in a later phase must
not be able to forget it. If you find a way onto the board that the table
above does not name, stamp it by the same rule and say so in the report.

## What is not built

- The room is not touched; nothing is deleted anywhere.
- No door to this screen from the app (phase 4).
- No speech to text, no transcript, no tutorial from a recording (phases 7–8).
- No server change.

## The report

1. **What the brief or the gate got wrong**, first, with the case's name and
   what you measured. If nothing: say so.
2. The pass condition's three commands, their last lines, as run by you.
3. Cases you added, by file and name.
4. What you measured in the bar at 900 wide and at 360.
5. Every way onto the board you found, and where its stamp is written.
6. Anything you saw that is outside this phase — reported, not fixed.
