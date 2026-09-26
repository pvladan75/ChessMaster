# PLAN-FORENZIKA-PADA — what a crash leaves behind

Written 26.9.2026, the evening the installed app died at 21:25:47 in
`flutter_windows.dll` with nothing to read but a Windows minidump. The dump
named the function within the hour (`AccessibilityBridge::SetRoleFromFlutterUpdate`,
the engine fault of 20–22.9.2026, back on Flutter 3.47.5 with the same
disassembly and upstream flutter/flutter#190357 still open) and could not name
the screen, the last tap, or the semantics node the engine had refused. The
owner could not remember either. This plan is three phases, in order, each
with a gate, so that the next crash is read in minutes and names its own cause.

Out of scope, and kept beside this plan for the owner's decision: a shared
busy-aware button that ignores a second press while the first is on its way
(the owner's Export video story, and the room's „Start" of 22.9.2026 which got
that guard by hand). It is a separate plan because it changes 600 call sites'
behaviour, not what a crash leaves behind.

## The rules this plan follows

- **Do the thing, then say it.** Nothing in this plan may throw into the path
  it observes. A trail that cannot be written is silently not written; the app
  never waits on it.
- **A native crash kills the process before Dart runs.** Anything meant to
  survive one is written synchronously, at the moment it happens, not batched,
  not debounced, not awaited.
- **The refusal and the crash are two moments, possibly minutes apart.** The
  dump of 26.9 faulted on a read of an address that was no longer mapped: the
  update the engine still pointed into had been freed *and* its page given
  back. Every update between the refusal and that moment read stale memory
  silently. So the screen a crash lands on is where the heap shrank (the
  owner's „back to Home", twice), not where the refusal was — and the
  owner's own replay of that path, and the gate's spy driven over it fast and
  slow (26.9, in a scratch worktree, every step green), both say the same.
  The trail therefore has to hold a refusal for the rest of the process, not
  for the last 40 taps. **And the counterexample, the same evening**: on the
  owner's reproduction path (below) the engine printed its refusal three
  times and the process died **three seconds** later (22:29:50). Both are
  true: the distance is set by when the heap gives the freed page back, not
  by anything the app does, so neither „at once" nor „minutes later" may be
  assumed.
- **The engine's own words are the reference.** A release build prints its
  refusals to stderr, which the installed app throws away unless started
  with it redirected (the live pass below). The line is
  `[ERROR:flutter/shell/platform/common/accessibility_bridge.cc(65)] Failed
  to update ui::AXTree, error: 17626 will not be in the tree and is not the
  new root`, and 17626 is the framework's semantics node id — the same id
  the phase-2 builder sees. So the detector is proved live by one comparison:
  its ids and the engine's, from the same run.
- **One rule, one home.** The engine's rule („a node in an update that no
  parent in the resulting tree lists is refused") lives in one class the app
  runs and the gate imports. `test/move_tree_semantics_orphan_test.dart`
  carries a private copy today; phase 2 moves it.
- **The trail is the last account's data.** A tapped label can be a student's
  name. The trail goes with the account like the drafts, through
  `AccountLocalState.clear`.

## Phase 1 — the trail `[implementer]`

`lib/services/crash_trail.dart`, `CrashTrail.instance`. A ring of the last 40
entries, one line each, timestamped, written **synchronously** to
`<application support>/crash_logs/trail.log` on every entry. The directory is
asked of `path_provider` once, at start; entries that arrive before it is
known are buffered and written the moment it is.

What goes in:

1. **Navigation.** `CrashTrail.watched(router)` wraps the app's `GoRouter` and
   listens to its delegate: every change writes `route <uri>`. The same
   instance's `observer` (a `NavigatorObserver`) goes in the router's
   `observers`, so dialogs, sheets and raw `Navigator.push` write `push <name>`
   and `pop <name>`. A route's name is `settings.name` when set; a
   `MaterialPageRoute` without one is named by the return type of its builder
   (`builder.runtimeType` prints `(BuildContext) => TutorialStudioScreen`;
   the part after `=> ` is the name); anything else by its `runtimeType`.
2. **Taps.** A global pointer route (`GestureBinding.pointerRouter.addGlobalRoute`)
   sees every `PointerDownEvent`. It hit-tests the position and names what was
   under it: the first `RenderParagraph` on the hit path (a button's text), or
   failing that the nearest `RenderSemanticsAnnotations` ancestor with a
   tooltip or label (an icon button). Writes `tap "<text>"`, text cut at 60
   characters. Nothing found writes `tap ?`.
3. **Errors.** `CrashBreadcrumbService.recordError` also writes one trail line,
   `error <runtimeType>`, so the trail and the crash log can be read together.
4. **Sign-out.** `AccountLocalState.clear` deletes the file as one of its
   guarded steps.

Not in the trail: keystrokes, pointer moves, text typed.

### Gate — `test/crash_trail_test.dart` (written 26.9.2026)

Every case injects a temp directory through
`init(supportDirectory: …)` and reads the file with `readAsStringSync`
**immediately after the event and before any pump** — that is the claim under
test. `resetForTest()` clears the ring, the buffer, the directory and the tap
route, and leaves `watching` alone.

1. A `MaterialPageRoute(builder: (_) => const _Screen())` pushed on a
   `Navigator` with the observer writes `push _Screen`; popping it writes
   `pop _Screen`. A route with `settings.name` uses the name.
2. A `GoRouter` wrapped by `watched` writes `route /b` when `context.go('/b')`
   runs.
3. `tester.binding.handlePointerEvent(PointerDownEvent(position: …))` on an
   `ElevatedButton(child: Text('Export video'))` writes `tap "Export video"`;
   the same on an `IconButton(tooltip: 'Delete part')` writes `tap "Delete
   part"` — **not** the icon's glyph, which is a `RenderParagraph` too and sits
   first on the hit path. A label of 100 characters is cut at 60; a tap on
   nothing named writes `tap ?`. The read is on the next line, no `await`
   between.
4. Fifty entries leave exactly 40 lines, `entry 10` first and `entry 49` last.
5. Two entries recorded before `init` completes are on disk once it does.
6. **The last run's trail is kept apart**: a `trail.log` found at `init` is
   moved to `trail-previous.log` before anything is written. Added by the lead
   — without it the first route of the run the owner starts to read the crash
   overwrites the crash's trail.
7. `AccountLocalState.clear()` removes both files **and the ring in memory**:
   the next entry's file holds nothing from before the wipe.
8. A directory that is a file: nothing throws, nothing is written.
9. `recordError` writes `error _TestException` to the trail, before its own
   first `await`.
10. `appRouter` is `CrashTrail.instance.watching`; `app_router.dart` has the
    line `observers: [CrashTrail.instance.observer],`; `main.dart` has
    `unawaited(CrashTrail.instance.init());` and
    `CrashTrail.instance.startTaps();` (source guards, exact trimmed lines, so
    a comment cannot satisfy them).

Mutations the gate must catch: `writeAsStringSync` → `writeAsString` (3);
the ring cap deleted (4); the buffer dropped rather than flushed (5); the move
to `trail-previous.log` removed (6); the wipe step removed, or the ring not
cleared (7); the tooltip fallback removed (3, second case).

## Phase 2 — the orphan detector `[implementer]`

`lib/services/semantics_shadow.dart`:

- `SemanticsShadow`, the engine's rule in one pure class. `List<int>
  orphansOf(Map<int, List<int>> update)` merges the update into its tree,
  walks from node 0 over `childrenInTraversalOrder`, returns the update's ids
  nothing reached, and keeps only the reached nodes — exactly what
  `_orphansAcross` in `test/move_tree_semantics_orphan_test.dart` does today.
  That test imports it and deletes its copy; its case „the rule itself catches
  an orphan" becomes the class's own.
- **The engine commits in two steps, and the shadow follows both**
  (corrected by Fable late on 26.9.2026, from the bridge's source at this
  SDK's engine revision, after the first build of the detector wrote five
  lines the engine never wrote and none that it did). `ui::AXTree` cannot
  move a node in one update, so `AccessibilityBridge::CommitUpdates` first
  applies `CreateRemoveReparentedNodesUpdate` — every child a node in the
  update lists while the tree holds it under another parent is taken off
  that old parent, in an update of the old parents alone — and only then the
  update itself. `SemanticsShadow.judge(update)` does the same and returns
  the engine's own words, so a trail line can be compared with stderr word
  for word:
  1. `%d will not be in the tree and is not the new root` — in **step 1**,
     an old parent that sits inside a subtree the same step detaches (the
     refusal at line 65 of the bridge; node 13051 on 26.9.2026 at 23:00,
     three seconds before the crash); in **step 2**, a node the update
     carries that nothing in the resulting tree reaches (the September
     shapes). The line says which step, and for step 1 which child left the
     node and which moving subtree held it.
  2. `Node %d has duplicate child id %d` — one node lists the same child
     twice.
  3. `Node %d is not marked for destruction, would be reparented to %d` —
     a child claimed by two parents **within one update**, or put back by an
     old parent the update still carries. **Not** a move whose old parent is
     absent from the update: step 1 exists for exactly that, and calling it
     a refusal is what the first build did, five times in one run.
  A step-1 refusal leaves the bridge's pending list uncleared, which is the
  memory the crash then reads.
- `OrphanWatchingBuilder implements ui.SemanticsUpdateBuilder`: forwards every
  call to a real builder, records `id → children` and each node's label,
  value and tooltip, and in `build()` asks the shadow first. An orphan writes
  one line, `semantics orphan [ids] "label" "tooltip"`, **twice**:
  into the trail through `CrashTrail.instance`, and appended to `crash.log`
  through `CrashBreadcrumbService` with the route the trail last saw — the
  trail is a ring and the crash may come forty taps later (see the rules).
  Both synchronously, **before** the real `build()` returns the update the
  engine will refuse. **Two caps, one a kind**: 20 orphan lines and 10 of
  the other rules per process, because on 26.9.2026 five lines of a rule
  that was wrong spent a single cap of five before the refusal the engine
  actually made. The node's texts are kept in the shadow across updates,
  since a step-1 orphan is an old parent and may not be in the update that
  refuses it.
- `mixin OrphanWatch on SemanticsBinding` overrides
  `createSemanticsUpdateBuilder`; `class AppBinding = WidgetsFlutterBinding
  with OrphanWatch;` in `lib/app_binding.dart`, and `main()` calls
  `AppBinding.ensureInitialized()`.

The builder exists only while a client has semantics on, so the walk costs
nothing otherwise. With a client on it is one DFS over the tree per update.

### Gate — `test/semantics_shadow_test.dart` (written 26.9.2026)

1. The pure rule: the fixture from the orphan test (2 arrives while 1 lists
   nothing) reports `[2]`; a node that arrives in the same update as the
   parent that lists it reports nothing; a refused node is not kept — after
   `{1: [], 2: [3], 3: []}` is refused and `{1: [2]}` accepted, `{3: [6], 6:
   []}` reports `[3, 6]`, since nothing reaches 3 through a 2 the engine threw
   away.
2. The builder, driven through `ui.SemanticsUpdateBuilder`'s own
   `updateNode`: an orphan with a label, value and tooltip leaves one line,
   `semantics orphan [2] "Playback speed" "50%" "Speed"`.
3. The caps: twenty-one orphans leave twenty lines; eleven duplicate-child
   updates leave ten `refused` lines and every one of the twenty orphan
   lines after them is still written.
4. Under `AutomatedTestWidgetsFlutterBinding with OrphanWatch`, semantics on,
   Flutter's own `Slider` opened in a dialog leaves one `semantics orphan
   [ids]` line in the trail, and the same line in `crash.log` (read
   synchronously, like the trail — it is written by `CrashTrail.recordLasting`,
   which appends to the same `crash_logs/` directory with `writeAsStringSync`,
   because `CrashBreadcrumbService` resolves its directory asynchronously).
   **Corrected by the lead on 26.9.2026**: the plan said the line
   would carry the slider's value, and it cannot — measured, the node Flutter
   orphans there (id 7 in `move_tree_semantics_orphan_test`'s dialog case)
   has no label, value or tooltip; the value `50%` is on a sibling that
   arrives, correctly parented, in the next update. The line names ids; the
   trail's `push` and `tap` lines above it name the screen and the action.
5. The same with `AppSlider` leaves no line.
6. `main.dart` has `AppBinding.ensureInitialized();` and no longer
   `WidgetsFlutterBinding.ensureInitialized();`.
7. `move_tree_semantics_orphan_test` still passes with the shared class; its
   `_orphansAcross` is a loop over `SemanticsShadow.refusalsOf` and no longer
   a copy of the rule — so every screen it drives (Analysis, Preparation,
   Board view, the sliders) is held clean of **all three** rules. That is
   evidence of **silence, not of coverage**: those are September's screens,
   where nothing refuses, so it says rules 2 and 3 raise no false alarm
   there and nothing about whether they fire where the engine refuses. The
   two dialog cases of this gate assert the same silence.
8. Rules 2 and 3, pure: `{0: [1, 1], 1: []}` gives `Node 0 has duplicate
   child id 1`; with `{0: [1, 2], 1: [3], 2: [], 3: []}` kept, `{2: [3]}`
   gives **nothing** (superseded 26.9.2026, evening: step 1 moves it), and
   `{1: [3], 2: [3]}` gives `Node 3 is not marked for destruction, would be
   reparented to 2`; two parents claiming a new node in one update give
   rule 3 for the second. Through the builder, a rule-2 or rule-3 update
   leaves a `semantics refused <message>` line.
9. The remove step (`removing reparented nodes`): with `{0: [1, 2], 1: [5],
   5: [6], 6: [7], 2: [], 7: []}` kept, the update `{2: [5], 5: [6], 6: [],
   1: [7], 7: []}` (5 moves to 2, 7 moves from 6 to 1) refuses `[6]` in step
   `removing reparented` with `why[6] == 'lost 7 to 1, inside 5 moving to
   2'`; the moving node itself losing a child (`5: [7]` kept, `5: []` sent)
   refuses `[5]`; a move with nothing lost inside it passes both steps and
   the kept tree is the tree after the move; a refused removal keeps
   nothing of the update. Through the builder the line reads `semantics
   orphan [6] "Playback speed" "" "" while removing reparented: 6 lost 7 to
   1, inside 5 moving to 2`, and a node the update does not carry is named
   by the texts it was last sent with.

**Not added to the gate: the owner's reproduction path.** Fable drove it
under the September spy in every variant — settled and not, Android and
Windows, a Home with a rail under the mouse, one to three loads, semantics
switched on at four different moments — and every variant was green. A case
that is green on the code that crashes cannot fail (rule 1). Two fixture facts
for whoever tries again: the room pushed over a stub Home pops itself after
about 1.2 s (the stub server answers `join_refused`, and the delayed close
takes the top route, which is the dialog); and a stub Home has no node the
room's teardown could orphan, so the fixture probably needs a real Home under
the real router. The path is proved live instead (below).

Mutations: the DFS starting from the update's keys instead of 0 (1 goes
red); refused nodes kept in the tree (1, third case); the write moved after
the real `build()` (inert — the order is a rule the test cannot see, and the
comment says why); the label capture dropped (2); the cap removed (3).
Second round, 26.9.2026 evening, after the two-step correction, seven
mutants: step 1 skipped (9, both refusals, and both builder cases); the old
branch of rule 3 restored (**inert** — step 1 has already taken the child
off the old parent in the shadow's tree, so the branch can no longer fire;
recorded, not chased); one counter for both caps, and one counter with the
larger cap (3, which first survived until the case filled both caps);
texts of the update's own ids pruned before the line is made (2, and the
caps case); the moving subtree left out of `why` (9); a refused removal
kept as the tree (9, fourth case); step 2 walking from every node instead
of the root (9 and the Slider case).

### Phase 2b — the engine never sees what it would refuse `[lead — built 27.9.2026]`

Ordered by the owner on 26.9.2026 at night, once the detector had named the
crash on its first live run (node 27377 in the engine's stream and in the
detector's list of the same run; the trail: leaving the room, `pop
/room/:roomCode`, with about two hundred Library rows in its column). The
shape is not one widget's, it is **any route with a long list being popped**
with an accessibility client on, so a fix per shape would not have closed it.

**Two framework facts decided the design**, both measured with a spy in front
of the builder on 26.9.2026:

- a reparented node is re-attached, not re-sent, and its unchanged
  descendants are not sent either — so a moved subtree does not arrive whole,
  while the engine destroys it in step 1 and has to recreate it from the
  update in step 2;
- on a pop, every row is re-sent with its actions blocked, and that alone
  moves nothing — the outer move in the crash (`14115 moving to 1`) comes
  from the app's own tree above the route, which no fixture has.

So the builder ([`OrphanWatchingBuilder`](../chess_app/lib/services/semantics_shadow.dart))
keeps every node's last full data (`NodeArgs`, pruned to the tree and the
held-back nodes) and, on `build()`, sends the engine the shadow's [`Plan`]
instead of the framework's update:

1. **Inner moves get a commit of their own, first.** A child leaving an old
   parent that sits inside another moving subtree is exactly what the
   engine's step 1 cannot take. Those old parents alone, with those children
   dropped and nothing new, go to the view (`FlutterView.updateSemantics`,
   the same call the framework makes) **before** `build()` returns; the tree
   takes that while the outer subtree still stands.
2. **Every subtree the tree will not hold when the second commit arrives is
   supplied from the cache**: a moved one, a held-back one now listed, a
   child never sent.
3. **A node nothing reaches is held back** and sent from the cache the day a
   parent lists it; its data is kept for 60 updates, then forgotten.
4. **What the tree refuses outright and the app can repair, it repairs**: a
   child listed twice is listed once; a child two parents claim in one commit
   stays with the one that is not its old parent.
5. Where the cache cannot supply a node, the framework's update goes **as it
   came**, and a `semantics hold-back failed` line says so — never worse
   than before.

The raw update's refusal is still written to the trail and `crash.log` as
before, with `— held back` at the end, so a live run compares with the
engine's stream as [249.1] did: from now on the stream should be **empty**
where the log has the line.

#### Gate — `test/semantics_holdback_test.dart`

1. The plan, pure, on the crash's shape (`{0: [1, 2], 1: [5], 5: [6], 6:
   [7], 2: [], 7: []}` kept; `{2: [5], 5: [6], 6: [], 1: [7], 7: []}` sent):
   `part1 == {6: []}`, `part2` carries 2, 5, 6, 1 and 7, nothing held,
   planning leaves the tree as it was, and `commit` returns no refusal and
   the tree after the move. The moving node itself losing a child (`5: [7]`
   kept, `5: []` sent) gives `part1 == {5: []}`.
2. A subtree moving without its descendants (`{1: [], 2: [5]}` over `1: [5],
   5: [6]`) is supplied whole: `part2 == {1: [], 2: [5], 5: [6], 6: []}`,
   `supplied` 5 and 6.
3. A node nothing reaches (`{2: [3], 3: []}`) is held, `part2` empty, and
   sent from the cache with its child when `{1: [2]}` arrives.
4. A held node is forgotten after `SemanticsShadow.heldFor` updates, and
   after that cannot be supplied.
5. A child listed twice is listed once; two claimants become one, and the
   moved child is supplied again.
6. The builder, with a recording stand-in for the real builder and a spy on
   `sendEarly`: the inner move's commit reaches the view **before** `build()`
   returns and carries node 6 alone; the returned commit carries the rest;
   the trail line ends `— held back`; a moved subtree reaches the engine
   whole; an orphan is kept from the engine and sent once adopted; what the
   cache cannot supply goes as it came, with its line; custom actions ride
   with the commit the framework gets back.
7. The binding (`AutomatedTestWidgetsFlutterBinding with OrphanWatch`):
   Flutter's own `Slider` in a dialog leaves the line, `heldEver` is not
   empty, and no `hold-back` line — every commit the engine got was one it
   takes; `AppSlider` needs nothing held.

Mutations, nine, each caught by the case written for it: inner moves treated
as outer (1, 6); nothing supplied (2, 3, 5); held nodes sent anyway (3, 6,
7); the first commit sent after the second is built (6); no fallback (6);
duplicate children kept (5, and phase 2's cap case); held data never
forgotten (4); the model's `commit` skipping the first commit (1, 6); the
`— held back` suffix dropped (6, 7).

**What the gate cannot see**, said plainly: that the real engine takes the
two commits. The model of the engine is the shadow's, written from the
bridge's source at this SDK's revision, and it has been right about the two
refusals it was compared with; the live pass [249.2] is where the engine
itself says so. **First live run, 27.9.2026 00:10–00:12** (build ebb4e7da,
the redirect on): the owner left the room three times over its long Library
column, the path that crashed the app five times the evening before;
`crash.log` has two `— held back` lines (about two hundred old parents each,
`inside 70 moving to 1` and `inside 28323 moving to 1`), the engine's stream
has no `Failed to update` at all, no `hold-back failed` or `left a refusal`
line, and the app stayed up. The owner ticks [249.2] in the QA tool.

## Phase 3 — the dump reader `[lead]`

`tools/crashdump/read_dump.py`, Python, no dependencies. Given a `.dmp` (or
none: the newest `Mislisha.exe.*.dmp` in `%LOCALAPPDATA%\CrashDumps`) it
prints the exception, the faulting module and offset, the registers, and the
faulting thread's stack resolved to function names. Symbols come from the
Flutter SDK on `PATH` (`bin/cache/artifacts/engine/windows-x64-release/`,
which ships `flutter_windows.dll.pdb`); the tool checks the DLL's PE
timestamp against the module in the dump and refuses to resolve against the
wrong engine. Disassembly is `dumpbin` from the newest Build Tools
(`vswhere`), run once per engine and cached as a label map under `%TEMP%`.

`--self-test` builds a synthetic minidump in memory and checks the parser on
it; that is the gate, and `python tools/crashdump/read_dump.py --self-test`
exits 0. The run on the dump of 26.9.2026 is recorded in `docs/STANJE-RADA.md`
with the function it names.

## Order and the live pass

1, then 2 (it writes through 1's trail), then 3 (independent, may run
beside 1). **The gate proves the detector on fixtures, not on the screen
that crashes**: every widget-test variant of the owner's path was green under
the very rule the engine applied, so a green gate cannot say the detector
will fire there. What settles phase 2 is the live pass, and its first item
is the comparison with the engine. It comes before phase 2 is called done.

On a release build with phases 1–2 in it, started with the engine's stderr
kept:

```powershell
Start-Process -FilePath "$env:LOCALAPPDATA\Mislisha\Mislisha.exe" -RedirectStandardError "$env:TEMP\mislisha-stderr.txt" -RedirectStandardOutput "$env:TEMP\mislisha-stdout.txt"
```

With a UI Automation client on (Narrator, or the touch keyboard), the path
that crashed three times on 26.9.2026: Preparation → „Set up position" →
FEN → „Set FEN Position" → back to Home, repeated. Then:

1. **every id in the engine's `will not be in the tree` lines in
   `mislisha-stderr.txt` appears in a `semantics orphan [...]` line of the
   same run**, in the trail and in `crash.log`; an engine refusal the
   detector did not write is a hole in the rule, and a detector line the
   engine did not print is a false alarm — either is a finding;
2. `crash_logs/trail.log` (or `trail-previous.log`, if it crashed) names the
   screens and the taps.
