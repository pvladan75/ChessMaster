# Coming back to a position the viewer has already seen

Written 12.9.2026, from the owner's requirement after the first tutorial was
rendered and published („Master the Rook and King Checkmate", four parts, on
YouTube that day):

> Part 3 i Part 4 pokazuju dve varijante iz iste pozicije, tako sam i hteo da
> izgleda. Vraćanje na zajedničku poziciju treba da bude takvo da gledalac zna
> da sam se vratio na već viđenu poziciju.

So the film must say when the board has jumped **backwards**. It must not say
it when the board has not moved, which is the case the same rule has to tell
apart first.

## What the published tutorial actually does

Measured on the real thing, not supposed — each part's opening position against
everything the film had already drawn, compared the way `MoveTree.samePosition`
compares (placement, side, castling, en passant; a clock is not a position):

| part | opens on | what it is |
|---|---|---|
| 1 | a position never shown | a new diagram |
| 2 | the position after `2. Kf3` — where part 1 ended | a **continuation** |
| 3 | the position after `12. Rh7` — where part 2 ended | a **continuation** |
| 4 | the position after `12. Rh7` — shown, but not what is on screen | a **return** |

**Three answers, not two**, and that is the whole design. Parts 2 and 3 need no
announcement: nothing changes on screen, and a caption saying „back to…" over a
board that did not move is noise. Part 4 is the one place the picture jumps, and
the one place words are needed.

**The line that should carry it already exists and is currently wasted.** Under
the board the film writes „Last move: 12. Rh7", or „Starting position" when
there is no last move — and at *every* part boundary it says „Starting
position", which in this tutorial is wrong three times over: twice the part
continues, once it returns.

## The decision

1. **The line under the board answers three ways**: „Last move: …" as now,
   „Back to the position after 12. Rh7" on a return, and „Starting position"
   when the part opens on something new.
2. **Text, never a colour or a flash.** The owner is colourblind, and a cue
   that has to be seen as a hue is not a cue. It is also the only signal that
   survives the film being watched on a phone at 360 dp.
3. **The comparison is `MoveTree.samePosition`, which is already written** and
   already used by the child's viewer for the continuation half of this rule.
   Nothing here gets a second reading of „same position".
4. **A continuation stops clearing the last move.** `applyEvent` clears
   `lastMove` on every `init` — right for a jump, wrong for a continuation,
   where the previous part's last move *is* how this board was arrived at. The
   comment above it argues the general case and predates parts that join.
5. **A returning beat holds at least four seconds.** „Back to the position
   after 12. Rh7" is about 35 characters, and the film reads at 12 characters a
   second; the 2-second minimum for a wordless beat is not long enough to
   notice that the board went back. Only silent films are affected —
   `narrationPlan` re-times every beat to the voice.

Declined, deliberately: renaming „Starting position" to „New position" for a
later part. It is right for the recorded-lesson export, where `init` happens
once at the game's own start, and the churn buys nothing the return note does
not already buy.

## The phases

**P0, P1 and P3 are done, 12.9.2026 — 2171 in the app with 1 skipped, 1244 on
the backend with `.env` moved aside**, measured one after the other with
nothing else running; analyze at 29 infos and zero warnings. Eight mutations,
all caught. **P2 is not built.** The live check is `TODO-provera.md`, item 154.

**P0 — the rule, in the app, as a pure function. Done.** `partOpeningsOf` in
`features/tutorial_studio/services/tutorial_video.dart`, beside `filmBeatsOf`,
which is already „the one walk of a tutorial as a film". Answers `fresh`,
`continues` or `returns` per part-opening beat, and on a return names the move
that arrived at the position **the last time it was shown** — the occurrence the
viewer remembers. Tests first, proved by mutation.

**P1 — the film. Done.** The `init` event carries `join` and, on a return,
`afterMove`; `applyEvent` keeps the last move on a continuation and sets the
note on a return; `underBoardText` is split out as a value a test can read,
the way `ffmpegArgsFor` was, because text drawn on a canvas cannot be read back
out of a pixel.

**P2 — the child's screen. Not built.** Not built with P0 and P1, and the reason is
scope rather than difficulty: the requirement is about a film, and the viewer
already has the continuation half (`_nextStepContinuesHere`, which waits a beat
before a board it is about to rearrange). What it lacks is the third answer and
a line to draw it on. When it lands it must use `partOpeningsOf` rather than a
second copy of the rule, and it can only name a part rather than a move —
it parses one step's line at a time, so the move that arrived at an earlier
part's position is not in front of it.

**P3 — the docs. Done.** An entry in `STANJE-RADA.md` and an item in
`TODO-provera.md`, since nothing here is proved until somebody watches a film.

## What must not change

**`filmSignatureOf` does not learn about this.** A recorded narration carries the
signature of the beat list it was made over, and the signature is position plus
caption. A join is neither: it changes what is *written under* a beat, not which
beat it is nor how long it is spoken over. Adding it would invalidate every
narration recorded so far, for a caption the trainer's voice never reads.

**The server gains no PGN reader.** The rule is computed in the app, where the
tree is, and travels on the event — the same reason the event list itself is
built there.

**An absent `join` means `fresh`.** The recorded-lesson export sends an `init`
with no join at all, and it must keep drawing exactly what it draws today.

## The mistakes this could make

**A repetition inside one part is not a return.** Only a part's opening beat is
asked the question; a line that walks back through a position it has already
visited is one continuous line, and the board never jumped.

**A returning part whose position was only ever a part's own opening has no
move to name.** Then the note says „Back to a position already shown". Worth
having as its own sentence rather than an empty „after ": in this tutorial part
4 does have a move to name, and a fixture built only from that case would never
reach the fallback.

**`showMoveText` turns the whole line off.** A trainer who has hidden it also
hides the note; that is the same one line and not a second decision.
