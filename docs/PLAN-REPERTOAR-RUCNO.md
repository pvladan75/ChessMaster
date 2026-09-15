# A repertoire is built on the board, move by move

Owner's request, 15.9.2026, with decisions taken the same day.

## The principle

A move the student did not enter themselves — filled in automatically by the
app or by the opening book — is a move they never went through, thought about
or internalised. A repertoire works only when it is built actively on the
board, move by move. **The opening book is a reference beside the board; every
entry in the tree comes from a move played on the board.**

This sentence is written into the build screen and into the user manual
(`site/mislisha/manual/repertoire.html`), not only into this plan.

**One exception, for orientation** (owner, 15.9.2026, the same evening): when
the student plays their move, the single most played master reply is entered
with it. Without it a student can build a careful answer to an obscure sideline
and never meet the move most games actually continue with. It is the only
opponent move the app ever enters; every other one is played by hand.

It is **stored**, as an ordinary entered move, at the moment the student's move
is kept — not recomputed from the book at every read. So it is a card like any
other and can be deleted like any other, and rebuilding the book never shifts
the tree under somebody's work. The board goes on to the position after it, so
building reads as a game: your move, the main reply, your move. Another reply
is prepared by going back to your move and playing it.

## What changes, as the owner asked

1. **The book is simply there.** No „Open book (1 query)", no query counter.
   The book is a file on this server (`PLAN-OTVARANJA-LOKALNO.md`), so
   `GET /repertoire/book` fills a position it has never stored from the local
   book and answers at once.
2. **Every move played on the board is accepted, for both sides.** No
   „Take X" / „Discard". A move that is not wanted is deleted.
3. **Speech says what to do, not the moves.** The sentence that read a whole
   main line aloud goes with „Suggest main line" (point 7); nothing spoken on
   this screen reads a line of moves.
4. **The opponent's moves are played on the board**, including moves the book
   does not know.
5. **„Back to Nf3" goes.** It returned to the position the board was already
   showing; the strip under the board is the way back.
6. **„Review unconfirmed" goes from under the board** — and, by decision 2
   below, from everywhere.
7. **„Suggest main line" and breadth go.** The opponent moves a student
   prepares against are the book's top reply and the ones they entered. More
   than one reply in a position is prepared by going back to it and playing
   another.
8. **Advice in view:** „For your side, prefer one move per position; for the
   opponent, one or more."

## Decisions (owner, 15.9.2026)

1. **No existing repertoire is kept.** The only repertoires on the server are
   the owner's, built as trials, so there is nothing to migrate. (A migration
   that kept answered opponent moves was written, dry-run and deleted the same
   evening: its first number was 619 positions left unreachable for one
   colour, which is what data built under three earlier models looks like.)
2. **Unconfirmed (drafted) moves: gone**, with the review banner, „Confirm",
   the draft review and the draft replacement.
3. **„Next" (take the book's replies): removed.**
4. **„Do not prepare this" (the cut) and its restore: removed.** Deleting an
   entered move does the same.
5. **Skip / Next position: kept** — they jump to positions after an entered
   opponent move that still have no reply.
6. **„Unanswered %": plain counts** of decided and open positions.

## The model after the change

- **The student's moves**: `repertoire_moves`, as before, `source = 'chosen'`
  only.
- **The opponent's moves**: `repertoire_extra_replies` — until now „prepare
  this one too", now the whole opponent side. The top reply is written there
  by `POST /node/move` when a move of the student's is kept and the book has a
  reply after it; nothing reads `opening_replies` to decide what the tree
  contains.
- **`opening_replies` and the book** are read only to show statistics and the
  share beside a card. A move with no book row has share 0 and is followed the
  same as any other.
- **The walk** (`frontier`, `walkLines`, `tree`, orphan detection, progress)
  follows entered replies. One helper replaces `coveredReplies`, so the queue,
  the picture and the drill cannot disagree.
- **The drill's opponent** plays entered replies that lead to a decided
  position, weighted by book games, evenly where the book has none.
- **Open** = a position after an entered opponent move with no move of the
  student's. A student's move with no reply entered after it is the end of that
  line, not an open question; the `unopened` kind goes.
- **Order of the queue**: shallower first, then the order the walk met them.
  Reach is no longer a product of book shares.

## Phases

**P0 — The owner empties the repertoires, in the app, before using the new
build.** Delete each repertoire on the list, then „Delete moves from database"
in the list's app bar, once for White and once for Black. That door
(`services/repertoireErase.js`) empties moves, cuts, extra replies, attempts,
reviews and evaluations; comments only if asked. No script, and nothing run by
anybody but the owner.

**P1 — Server.** The helper for entered replies; the walks, orphan detection,
progress and `pickReply` on it; frontier summary as plain counts; the book
route filling from the local book; delete breadth (`PUT /breadth`, `requireBreadth`
readers), the spine (`POST /spine`, `repertoireSpine.js`), unconfirmed
(`/unconfirmed*`, `repertoireUnconfirmed.js`), `/alternative`, `/node/confirm`,
`/line/confirm`, `/node/skip`. Orphan detection learns to answer for removing
an opponent move. `repertoires.breadth` stays as an unread column, dropped
separately. Tests with `.env` moved aside.

**P2 — Build screen.** Points 1–8 and the principle. Own move: kept at once
(the server enters the top reply with it), the board goes on to the position
after that reply, the judge answers in the background and its verdict is
written on the attempt. Opponent move: entered, board goes to the position
after it. Tree: delete on either side; no breadth, no cut toggle.

**P3 — The other screens.** List (no unconfirmed badge, no breadth), drill (no
draft review door), walkthrough (`unopened`, `cut`), coverage (counts), tree
panel legend; `breadth_dialog.dart` and `unconfirmed_banner.dart` deleted.

**P4 — Words.** The manual page rewritten around the principle, `docs/
STANJE-RADA.md`, `TODO-provera.md` item for the live pass, counts in
`CLAUDE.md`.

## What was proved by mutation

Twelve changes to P2's guards were run against `repertoire_build_test.dart`,
`repertoire_build_layout_test.dart` and `repertoire_tree_reaches_board_test.dart`.
Nine were caught, one did not compile, and **two survived** — both are tests
now, and both were watched failing on the mutation that found them.

- **A book answer for the position you have left lands on the one you are
  standing on.** `_loadBook` holds `_boardFen != fen`, and nothing asked for it:
  a lookup held open while a move is played used to have no test at all. The new
  one holds the root's lookup in a `Completer`, plays Nc6, and asks that the
  chips still say Nf3 and never d6. It steps frames rather than settling,
  because a held lookup keeps a spinner turning and a turning spinner never
  settles.
- **Deleting an opponent move left what only it reached in the database.** The
  prune after `removeOpponentMove` was unreachable from the build screen's own
  fake, which has no `removeOpponentMove` and so always answered „not done"; the
  layout test's fake has one, and that is where the two new tests live — one
  that the keys are pruned, one that a refused removal prunes nothing.

The mutation that did not compile („a kept move kept again", written as
`if (false)`) took the null check that the next line needs with it, so the suite
failed to load and the harness reported a catch that was a compile error. Rerun
as `already != null && false`, which keeps the promotion, it is caught by „a
move already kept is not kept again".

## Risks worth naming

- **Opening the new build on the old data** shows repertoires with no opponent
  moves and stray drafts. Do P0 first.
- **The rejected-attempt rows stop being written.** They came from „Discard";
  with every move accepted there is no discard. The drill's „mistakes" still
  read attempts judged `mistake`.
- **An opponent move the book does not know** has share 0. Anything that
  divides by a share must not.
