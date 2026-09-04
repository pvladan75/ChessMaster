# PLAN-UPOZNAJ-REPERTOAR.md

A guided read-through of a repertoire: „Upoznaj repertoar". Proposed 4.9.2026,
after the owner's observation that a built repertoire becomes a picture nobody
can hold in their head.

Written as a proposal, not as agreed work. Read the decisions in §2 first —
each one changes what the rest of the plan costs, and two of them contradict
how the app behaves today.

## 1. Why this exists

The owner's words, and the whole brief:

> Nakon što korisnik izgradi ili proširi repertoar, graf stabla postaje
> vizuelno prenatrpan i težak za mentalno praćenje. (…) Kada gleda u stablo,
> teško je povezati celinu: „Šta ja zapravo igram u kojoj situaciji i šta me
> sve čeka?"

Two different complaints live in that sentence and they have different cures:

* **Spatial.** The picture does not distinguish a decision of mine, a covered
  reply of theirs, and a hole. Cure: draw them differently. Cheap, and it helps
  the moment it ships.
* **Temporal.** Even a well-drawn tree is not a story, and an opening is
  learned as a story — this line, then what happens if they deviate. Cure: walk
  it. Expensive, and it is the actual feature.

The plan does the spatial half first **because it is also the measurement**: if
a legible tree turns out to answer „šta ja igram", the tour is a smaller
feature than it looks. The reverse order cannot tell us that.

## 2. The four decisions this rests on

Each of these is a real fork. They are here rather than buried in a phase
because the answers change the work.

### 2.1 The tour walks *decisions*, not the book's width — **and today's walk cannot do that**

`walkLines` follows the opponent's replies that fall inside the repertoire's
`breadth` (`main` = the single most played, `standard` = the stored 80% cut,
`broad` = 95%). Everything downstream is that walk: the tree, the queue, the
coverage map, the drill.

Measured against the owner's live database on 4.9.2026, on repertoire „Druga"
(gate `b4`, breadth `main`):

| breadth | nodes reached | draft positions reached |
|---|---|---|
| `main` | 4 | 0 of 21 |
| `standard` | 79 | 21 of 21 |
| `broad` | 130 | 21 of 21 |

All twenty-one sit under `b4 Bb6…`, the opponent's **second** most played
reply. At `main` the walk follows one reply per position, so the reader's own
work is not in their own tree — which is also the true cause of two separate
live findings (the spine that „ne napravi ništa", and the draft review that
said there were none).

A tour built on that walk would be a tour of part of the repertoire, silently.

**Proposal:** a reply is followed when it is inside the breadth **or when the
position it leads to holds moves of the student's own**. The rule already
exists in `withinBreadth` for `repertoire_extra_replies` — „a move the student
pressed *prepare this too* on is followed at every breadth" — and this is the
same argument with more force: a move they actually decided. It can only ever
add positions they created themselves, so the tree cannot grow beyond their own
work.

This is a **contract change to the core walk** and it touches the queue and the
drill, not only the picture. It is phase 1, alone, with its own live check.

**Done, 4.9.2026 — and it was bigger than this section thought.** `e5bdb4c`
made the rule, and `8625273` found that three more walks bypassed it: the two
that decide what deleting a move would strand (`reachable`,
`orphansOfRemoving` — „unreachable" is what the sweep deletes) and the drill's
`pickReply`, which narrowed by breadth **before** asking whether a reply led
into a position the student had decided. Since four call sites are a habit and
not a rule, `test/repertoire_breadth_rescue.test.js` now reads the sources and
fails if a fifth forgets. The owner's own words for the rule, which is the
version to keep: *širina sužava ono što knjiga predlaže da se sprema, a ne ono
što je već spremljeno.*

Still unchecked live on „Druga" — that check is what closes this phase.

### 2.2 The tour is read-only, and therefore free

No Lichess request, no writes, nothing to lose. It reads `GET /repertoire/tree`
— one request, already free — and nothing else. That is what lets it be offered
to a child without a token and what keeps it out of the consent and allowance
machinery entirely.

The one temptation to refuse: „you have no answer here, play one now". Building
belongs on the build screen, which already has the judge, the book and the
engine. The tour **names** the hole and offers a door to that screen; it does
not grow a second builder.

### 2.3 It is its own screen, not a mode of the build screen

The build screen is already the busiest in the app: board, queue, book, judge,
engine, tree, notes, comments, nine controls. A tour is the opposite kind of
thing — calm, one sentence at a time — and adding it as a mode would put a
second personality inside the screen the simplicity plan exists to quiet down.

Reached from the repertoire card („Upoznaj"), beside „Vežbaj".

### 2.4 The order is DFS, trunk-first, weighted by reach

Which is what the owner asked for, and it is already computable from data the
tree endpoint returns: every node carries `share` (how often the opponent plays
the reply that leads here) and its parent. Sort children by `share` descending,
depth-first, and the tour is the main line to its end, then back up to the
last fork and out along the next most played. No new endpoint.

**One question phase 1 opened, and it needs the owner's answer before phase 3.**
Now that a reply into the student's own work is followed at every breadth, the
tree contains branches reached through a *rarely played* reply that nevertheless
hold most of their work. On „Druga" that is exactly where all twenty-one drafts
live: under the opponent's **second** reply. Sorted purely by `share`, that
branch is visited last — so a tour of „my repertoire" would spend its opening
minutes on book lines the reader never built, and reach their own work when
they have stopped watching.

Three orders, and this is a pedagogy question rather than a technical one:

1. **By share, strictly.** The book's story. Honest about what you will *meet*.
2. **By share, but a branch holding your own decisions is never ranked below an
   empty one.** The repertoire's story: „here is what you play", holes named as
   they come. My recommendation.
3. **Your work first, holes last.** Reads as a report rather than a walk, and
   loses the „what happens if they deviate" thread that makes an opening
   learnable.

The difference is one comparator and it is a pure function either way, so this
can be decided late — but not after phase 4, because the sentence the tour
opens with depends on which story it is telling.

### 2.5 The tour can only speak about the replies the walk followed

Found while reading the tree endpoint for phase 3, and it decides what §4's
„hole" sentence is allowed to say.

`GET /repertoire/tree` returns one node per reply **the walk followed**. A
position of the student's own with no move under it comes back as
`state: 'open'` — that is a hole, it is drawn, and the tour can name it with
its share. Good.

What is *not* in that answer is the tail: the opponent's replies the breadth
left outside, which the build screen already names („van toga još 3 poteza").
Those are also „šta me čeka", and the tour is the screen where a reader would
most expect to hear it.

Two honest options, and the difference is one line of JSON:

* **Say only what is drawn.** The tour speaks about followed replies and never
  claims the list is complete. No server change. This is the phase 3/4 default.
* **Carry the tail.** Add `tailMoves` and `tailShare` per position to the tree
  answer — the numbers already exist in `coveredReplies`, and the build screen
  computes the same pair per wave. Then a fork stop can end with „i još 3
  poteza, 9% partija, bez odgovora."

**Proposed:** ship the first, and only add the second if the live check on
phase 4 shows readers asking „is that all?". A per-branch summary is available
today without any change at all — the coverage endpoint already returns
`coveredWithin` / `openWithin` / `prunedWithin` per branch, which is the honest
„this branch is N% prepared" line and needs no new field anywhere.

## 3. What is reused, and what is genuinely new

**Reused unchanged — this is most of the feature:**

| Piece | What it already does |
|---|---|
| `GET /repertoire/tree` (`repertoireLine.tree`) | one node per ply, each with `state` (`open`/`unopened`/`cut`/`decided`), `share`, eval |
| `repertoireTreeToNodes` | that answer as an `AnalysisNode` tree |
| `AnalysisNodeCursor` | `MoveCursor` over exactly that tree |
| `MoveNavigationControls` + `MoveKeyboardShortcuts` | the strip and the arrow keys, both already contract-bound |
| `showBranchChoice` | „Odavde ide više linija — kojom?" — the fork sheet, and `MoveBranch.detail` already carries a second line for „37% partija" |
| `SpeakableInfo` / `SpeechService` / `speakable()` | the panel that shows a sentence and reads it, and the SAN-to-speech table behind it |
| `ChessBoardWithOverlay` | arrows, with the three switches and their guard test |
| `repertoire_notes` / `repertoire_comments` | what the student wrote about a position |
| `serbianCount`, `numberedLine` | plurals and the numbered line |

**New, and small:**

* `walkthroughOrder(AnalysisNode root)` → `List<AnalysisNode>` — pure, sorted by
  `share`, depth-first. One function, one test file, no widgets.
* `stopKindOf(AnalysisNode)` → `mine` / `theirs` / `hole` / `cut`. Pure.
* `WalkthroughScreen` — board, the strip, one panel, the tree beside it on wide.
* Node styling in `VisualMoveTreeWidget` (§5).

**New, and not small:** the walk contract in §2.1, and the narration rule in §4.

## 4. Narration, so it does not become noise

The failure mode is not silence, it is a voice that reads every ply. Four rules,
three of which the existing machinery already enforces:

1. **One sentence per stop, and it is the sentence on screen.** `SpeakableInfo`
   never composes — the screen passes what it already shows. Keeping that means
   the tour cannot develop a second, drifting narration track, and a reader who
   turns speech off loses nothing but the sound.
2. **Speak at decision points, not at plies.** This is the new rule and it is
   the whole anti-fatigue design. A stop earns a sentence when it is a fork, a
   hole, or a position carrying the student's own note. An ordinary move on the
   trunk gets its move announced and nothing more; a run of them gets silence
   and the board moving.
3. **Never interrupt.** `SpeechService` already holds one queued slot and never
   cuts a sentence off; the reader stops it by moving. Nothing in the tour may
   call `stop()` on its own.
4. **Registers, not one template.** Three shapes, chosen by `stopKindOf`:
   * trunk: „5. d3" — the move, said by `speakable()`, nothing else;
   * fork: „Ovde protivnik ima dva odgovora: 5…d6 u 37% i 5…a6 u 21%.";
   * hole: „Na 6…O-O, 14% partija, nemate odgovor."

   A note the student wrote is appended when there is one, because that is the
   sentence they most want back.

The measurable target, and it belongs in the brief: **a twelve-move trunk must
produce at most four spoken sentences.** If it produces twelve, the design
failed regardless of how good they are.

## 5. Drawing the three states apart — and the constraint that decides it

The owner is colourblind. Every live sign-off he has given proves luminance and
shape; none of them proves hue. So the three states are **not** three colours:

* **my decision** — filled node, ★ as today for the primary, outline for an
  alternate;
* **their covered reply** — outlined node, the share in the label („37%");
* **a hole** — outlined node, `?`, and the share, which is the whole point:
  a 14% hole and a 1% hole are not the same news;
* **cut** — `✂`, as today.

The legend under the tree already names ★, ?, … and ✂; the work is making the
*node* carry what the legend promises, at a glance, without reading the label.
Shape and fill first, weight second, hue never load-bearing.

## 6. Phases

Sizes are honest. The lead keeps anything touching a contract, a walk, or the
schedule; the rest can be a worker batch.

**Phase 1 — lead. The walk shows the student their own work. ✅ 4.9.2026**
§2.1, server-side. Shipped in `e5bdb4c` and `8625273`, backend 873 → 877, with
a source-reading guard so a fifth walk cannot forget. **Open: the live check on
„Druga".** It fixed three known findings by itself, as expected.

**Phase 2 — worker. The tree draws its four states. ← next, and now unblocked.**
§5. Pure presentation inside `VisualMoveTreeWidget` and the legend. It is the
half that may make phase 3 smaller, so **ship and watch it before writing phase
3's brief.**

Two things the brief must say, both learned the hard way and neither obvious:

* **Golden tests do not run by default.** `dart_test.yaml` skips that group
  unconditionally, and `--tags golden` alone still skips it — the run exits 0
  saying „All tests skipped". A batch graded on goldens without
  `--run-skipped` is a batch graded on nothing. See CLAUDE.md.
* **Hue is never the difference.** The owner is colourblind and every live
  sign-off he has given proves luminance and shape. A brief that says „make the
  covered ones blue" produces a picture he cannot grade, and he will still say
  yes to it, because the shapes will be fine. Fill, outline, glyph, weight —
  in that order, hue last and never load-bearing. See §5.

**Phase 3 — lead. The order and the stops.**
`walkthroughOrder` and `stopKindOf`, pure functions with their own tests, plus
the panel contract (`Stop` → the sentence). No screen yet. The output of this
phase is testable in full without a widget, which is deliberate: it is the part
that is hard to get right and easy to test.

**Phase 4 — worker. The screen.**
`WalkthroughScreen`, assembled from §3's reused parts and phase 3's functions.
A brief with the widget list and the strings, over a design where the hard
thinking is already done and machine-checkable.

**Phase 5 — lead. Narration.**
§4's registers wired to `SpeakableInfo`, with the four-sentences-in-twelve-moves
budget as a test, and then watched running. Speech is last on purpose: a tour
that is wrong is worse when it talks.

## 7. How this sits with PLAN-JEDNOSTAVNOST

It does not replace it and it must not overtake it.

* That plan's **phase 4 (the vocabulary sweep) rewrites the strings on exactly
  the screens this feature touches**. Starting this feature before that sweep
  meant writing new labels that the sweep would then rewrite, and the string
  gate would have noticed — loudly, and correctly.

**That condition is now met.** The sweep merged 4.9.2026 (`8ce6a6e`, 47 rows)
and its live check came back clean on all eleven items of `TODO-provera`
section 96. The frozen glossary is therefore the vocabulary this feature writes
in from its first label — „glavna linija", „nepotvrđeni potezi", „koliko
odgovora spremamo", „rupe u repertoaru", „ne spremam" — and „Upoznaj repertoar"
has to be read against that list before it is used as a name.

So the order now is: **phase 2 of this plan is the next thing to start**, and
nothing in PLAN-JEDNOSTAVNOST blocks it. What is still open there is phase 5's
remaining live checks (sections 92–95), which are the owner's to run and do not
gate this work.

On „bez preopterećivanja korisnika novim modalima": the tour adds exactly one
destination and no modal. It reuses the strip, the keys and the fork sheet, so
a reader who has used the drill already knows how to drive it. The one new
control is „Upoznaj" on the repertoire card.

## 8. Deliberately not in this plan

* **No writing from the tour.** Not even „confirm this draft". §2.2.
* **No engine.** A tour that pauses to evaluate is a different feature, and the
  eval is already on the node from the tree endpoint if it is wanted in the
  label.
* **No progress tracking** — no „you have read 60% of your repertoire". It is a
  reading, not a schedule, and the drill is the thing that already knows what
  you know.
* **No second ordering.** One order, the one in §2.4. „Show me the holes first"
  is a filter over the same order if it is ever wanted, not a second tour.
