# Speech from stitched clips: one voice, no network, one module first

Written 2.10.2026 from the owner's three messages of that day. The ask: the
app should not depend on whatever voice the device has installed, the
sentences with pieces and squares in them should not cost a server call just
to be spoken, and the first module to get it is **Mate in N** — the puzzle
mode of `lib/screens/ai_studio_screen.dart`. Everything else follows once that
one has been heard running.

Two things the owner said that shape the plan: the server's synthesiser is
**not** being removed — the tutorial film needs it and other places may — and
the sentences on the screens today are **not final**; each module's words are
settled when that module's turn comes, not in advance for all of them.

## 1. What is there

Measured 2.10.2026 on `master` at `6b5cd2f9`.

**The device voice.** `SpeechService` (`lib/services/speech_service.dart`)
wraps `flutter_tts` and takes a `String`. It is called from eight places in
five files: the tactics trainer's spoken feedback, `EndgameInfoPanel` (drawn
by the endgame trainer and the blunder walk), `SpeakableInfo` (drawn by the
repertoire build, drill and walkthrough screens) and the settings screen's
sample button. The settings are `app_speech_enabled`, `app_speech_rate` and
`app_speech_language`. `SpeakableInfo` is the one control: a speaker beside a
sentence, which turns speech on where it happens. Its rules are the right
ones and stay: it never composes the sentence, it cannot take down what it
describes, and the button is never a no-op.

**The server's synthesiser.** `services/tts/index.js` has `speak({ text,
voice })` with a cache keyed by text, voice and provider, under `tts-cache/`;
Azure answers in `riff-22050hz-16bit-mono-pcm`; `wav.js` reads a file by its
own header and knows what silence is (a peak under −40 dBFS over a 20 ms
block); the narration concatenates such files into a track. Every synthesised
character is booked to the trainer who asked (`onSynthesised`). None of this
changes.

**The pilot screen speaks nothing today.** Its sentences, as the code has
them: the title `⚪ White to move - Mate in 1` or `… - Find the winning
path`; `Incorrect move! Try another move.` as a snackbar, and a dialog titled
`Incorrect Move!`; `Puzzle Solved!` with `Well done! You played all the moves
correctly. New rating: …`; the drill endings `Checkmate` / `Stockfish
delivered checkmate. Try again.` and `Draw` / `The game is drawn: <ending>.
Try again.`; `Engine cannot calculate: <reason>`; and two snackbars about a
blunder or an inaccuracy with an evaluation number. The opponent's reply is
played on the board with no sentence at all.

**One place in the app speaks free text**: the walkthrough's `Your note: …`,
the student's own words. It is not in the pilot; its decision is in phase 4.

## 2. The model

Three ways a sentence reaches the ear, and a sentence knows which one it is.

**Stitched from shipped clips** — this plan. A `SpokenLine` is a list of
tokens from one vocabulary (`lib/core/speech/vocabulary.dart`): a **phrase**
(fixed words — „to move", „mate in", „Correct. Keep going."), a **piece**, a
**square**, a **number** from 0 to 99, or a **connective** („from", „to",
„takes", „check", „checkmate", „castles kingside", „castles queenside",
„promotes to"). Every token has one `text`. The line's `text` is the tokens'
texts joined, and that is what the screen draws; the voice plays the tokens'
clips. One list, two renderings — the walkthrough's rule, which keeps the
sentence spoken equal to the sentence shown by construction.

A move becomes tokens in one place, `MoveWords`, from the facts of the move
(piece, destination, capture, check, mate, castling, promotion, and the file
letter when two pieces of a kind can reach the square). Nothing else turns a
move into words.

**A clip is cut out of a carrier sentence, never rendered alone** — phase 0's
finding. A word rendered on its own is an utterance of its own and falls like
the end of a sentence; the owner heard thirteen such sentences and named the
fault as intonation, not pause. So every token that stands inside a sentence
is rendered inside a carrier of the same shape (a square in „Black plays
bishop e5.", a piece in „Black plays knight e5.", a number in „Mate in 3.")
and cut out at the midpoint between neighbouring words, using the word times
Azure's Speech SDK reports for the audio it writes. A phrase token („Correct.
Keep going.") is a sentence already and is rendered whole and trimmed to the
speech floor. The SDK is a dependency of `tools/speech_clips/` alone; the
server keeps its REST provider.

The clips live in `chess_app/assets/speech/`, one WAV per token, in the
server's own format (22050 Hz, 16-bit, mono), beside a `manifest.json` that
says, for each id, the carrier text, the word cut out of it, the voice and a
hash of both. They are rendered once by `tools/speech_clips/` with the
owner's key and are **committed**, since they are reproducible from the
manifest and the tool. About three hundred clips; the size is measured in
phase 1 and expected under 8 MB beside Stockfish's 114.

Playback: `ClipVoice` concatenates the PCM of the tokens, with 50 ms of
silence before a square and nothing between any other pair, writes one RIFF
header and plays the bytes through the `audioplayers` package the app already
has. No decoder, no network, no file written.

**Synthesised on the server** — the tutorial film's narration. Unchanged.

**A free sentence synthesised on request** — the door the owner asked to keep
open. `SpokenLine.synthesised(text)` is **named in the vocabulary file and not
built**: a line of that kind would go to a route over the same `speak()` and
cache, metered to the account, and be played from the answer. It is built the
day a module needs a sentence the clips cannot say, and that module's phase
says so. Nothing in phases 0–3 reaches for it.

What does not change for the reader: `app_speech_enabled` governs every kind;
the speaker control is the same `SpeakableInfo`; speech is off by default.

## 3. Decisions

D1, D2, D6 and D11–D12 were settled by the owner's ear on 2.10.2026 (phase
0); the rest are the lead's recommendations and can still be overruled.

**D1. A move is said short, the way players say it: „rook a8".** The owner
chose this over „rook from a1 to a8" after hearing both. A capture is „rook
takes a8"; „Check." or „Checkmate." follows where the move gives it. A pawn
says „pawn": „pawn e4", „pawn takes d5". Castling is „castles kingside" /
„castles queenside". A promotion is „pawn e8, promotes to queen". When two
pieces of a kind can reach the square the file letter is said between them,
„rook a a8", „knight b d7" (D11). The sentence names the side first: „White
plays rook a8."

**D2. One voice for the whole app: `en-US-AndrewNeural`**, chosen by the
owner from Ava, Andrew, Sonia and Christopher. English only — the interface
is English only, and a second language would be a second set of clips and a
second vocabulary.

**D3. What the pilot says, and when.** Approved as a table in phase 0 and
copied here. The draft:

| When | Spoken (and drawn) |
|---|---|
| A puzzle appears, or „Next position" | „White to move. Mate in two." / „Black to move. Find the winning path." |
| The opponent replies | „Black plays knight d7." / „Black plays queen takes e8." (D1) |
| The puzzle goes back to try the opponent's other defence | „Now suppose Black plays pawn d4." — said first, the move drawn when the sentence is over (added 3.10.2026) |
| A right move that does not end the puzzle | „Correct. Keep going." |
| A wrong move | „Incorrect. Try another move." |
| Mate delivered | „Checkmate. Puzzle solved." |
| The drill is lost | „Checkmate. Stockfish wins. Try again." |
| The drill is drawn | „Draw by stalemate. Try again." — one phrase per ending the app names |

Not spoken: the rating and its change, evaluation numbers, server notices,
anything in a snackbar about the connection. Numbers are read as whole
numbers („twenty-one" is one clip, not two).

**D4. The screen's line is the spoken line.** The title is drawn from
`SpokenLine.text` — „White to move. Mate in 2." — and the emoji that is in the
title today becomes an icon beside it, not a character in the text.

**D5. Numbers 0–99 are clips**, one each. Enough for „mate in", „move N" and
„N replies" in every module that follows; rendered once in the pilot because
the cost is a few hundred characters.

**D6. 50 ms of silence before a square, nothing anywhere else.** Measured on
the owner's ear: with words cut from carriers the seams need no pause at all,
except that the square after a piece, a letter or „takes" arrives too
abruptly without one; 50 ms was preferred to 0 and to 100.

**D7. The vocabulary's home is Dart.** The manifest is generated from it
(`dart run tool/speech_manifest.dart`), the Node tool renders from the
manifest, and a test holds the manifest to the vocabulary — a text edited in
Dart without a regeneration and a re-render is a red test, not a clip that
says the old word.

**D8. The rate slider is untouched** until the device engine goes (phase 4).
The clips are one rate; the slider keeps meaning what it means for the
modules still on the device voice.

**D9. The clip voice and the device voice share one queue.** `SpeechService`
has one `speaking` state and one `_lastSpoken`; a stitched line and a
`String` utterance cannot talk over each other. The service gets
`speakLine(SpokenLine)` beside `speak(String)`; `speak(String)` is deleted in
phase 4 with its engine.

**D10. A missing clip is loud, not silent.** `ClipVoice.load()` checks every
vocabulary token against the bundle at start; one missing sets
`SpeechState.failed` with the token's name, which Settings shows beside the
speech switch, the way an engine that answers nothing says so. The gate makes
this unreachable in a build; the check is for a broken bundle.

**D11. Ambiguity is said by the file letter**, as in SAN and as players say
it: „rook a a8". The rank („rook 1 a8") is said only where the file does not
settle it, which the move's facts decide in `MoveWords`. Eight letter clips
and eight rank clips, cut from carriers of that shape.

**D12. Every token has a carrier recipe in the tool, by kind.** A square is
cut from „Black plays bishop {sq}." and, a second time, from „Black plays
bishop takes {sq}." — 128 clips, because a square after „takes" is spoken
differently; a piece from „Black plays {piece} e5."; a letter from „White
plays rook {letter} a8."; a rank from „White plays rook {rank} a8."; a number
from „Mate in {n}."; „White plays" / „Black plays" / „takes" / „Check." /
„Checkmate." / „promotes to" from the frame sentences; a phrase is its own
sentence. The tool refuses a carrier whose reported word count is not the
carrier's — that is its guard against a cut in the wrong place.

## 4. Phases

### Phase 0 — the ear test and the table `[lead, owner]` — done 2.10.2026

Nothing in `lib/`. `tools/speech_clips/phase0.js` rendered the alphabet word
by word in three voices and the draft table stitched and whole; the owner
refused the stitched set — „intonation that changes irregularly between
words", not the pause, at 160 ms down to 0. `experiment_cut.js` then cut
every fragment out of a carrier sentence of the same shape at the word times
of Azure's SDK (the server's speech-to-text was tried first and heard „to e5"
as one word), and that passed: „almost perfect", with one correction, a
small pause before the final square. `experiment_short.js` tried the owner's
shorter wording, „rook a8", with the letter for ambiguity, in Ava, Andrew and
Christopher. Settled: the short wording (D1), Andrew (D2), 50 ms before a
square (D6), the letter (D11), carriers by kind (D12). Phase 0 cost about
five thousand Azure characters (3036 for the word-by-word set in three
voices, the rest for the carriers and whole sentences of the two experiments). The three scripts stay in the tool as the
record of what was heard.

### Phase 1 — the vocabulary, the manifest, the tool, the clips `[lead]` — built 2.10.2026

Built as written below, with three things the build taught. **277 tokens**,
272 distinct carriers, 5422 characters once, **7.2 MB** of clips in
`chess_app/assets/speech/`; the renderer run a second time rendered nothing.
The lock is `rendered.json` beside the manifest and holds the strings
themselves (carrier, words, voice), not a hash — a Dart test compares
strings, and a hash would have been a second way of saying the same thing.
Measured before the gate's numbers were written: a phrase has at most 20 ms
of silence at either edge; a cut clip has up to 200 ms at its head, which is
the midpoint of the pause before „Check." or „promotes to" and belongs in
the clip, and at most 19 ms at its tail. So the gate's third case is not
„under the floor at the edges" as first drafted — that would have failed
every clip — but **at most 45 ms of silence at a phrase's head, 250 at a cut
clip's, 60 at any tail, and speech somewhere**. Seven mutations, each red on
the right case (a text edited with a stale manifest; a carrier edited with no
re-render; a clip silenced, deleted, relabelled 24 kHz, given 300 ms of
leading silence; a stray clip). Cut tokens carry no punctuation in their
`text`; a phrase carries its own; the line's full stop is phase 2's. The
proof file assembled from the committed clips went to the owner.

`lib/core/speech/vocabulary.dart` (the tokens, their kinds and their texts),
`tool/speech_manifest.dart` (Dart → `assets/speech/manifest.json`),
`tools/speech_clips/render.js` (manifest → carriers through `sdk_render.js`
by the recipes of D12, each word cut at the midpoint between its neighbours,
phrases whole and trimmed to the floor `wav.js` defines, with a lock of
hashes so a second run renders nothing), the clips committed, `pubspec.yaml`
listing the folder, and `phase0.js` / the two experiments kept as they are.

Gate, `test/speech_clips_test.dart`, a pure test over the assets:

1. Every token in the vocabulary has a clip, and the manifest's hash of its
   carrier text and word equals the hash the Dart vocabulary computes.
2. Every clip is 22050 Hz, 16-bit, mono, read from its own header.
3. A phrase clip's first and last 20 ms block are under the speech floor; a
   cut clip has speech in its first and its last 60 ms (it was cut out of
   the middle of a sentence, so silence at either edge means a cut in the
   wrong place).
4. No clip is longer than three seconds, and no clip is empty.
5. The manifest names no id the vocabulary does not have.

The tool's pure parts (the cut at midpoints, the word-count guard, the lock)
get `tools/speech_clips/test/` under `node --test`, the way `tools/status` is
run by hand but testable; the SDK is behind a seam a test can fake.

Mutations the gate must catch: a carrier text changed in Dart with no
re-render (1); one phrase clip untrimmed (3); one clip rendered at 24 kHz
(2); a square cut one word early (3); a token deleted from the manifest (1).

### Phase 2 — the line, the stitcher, the pilot screen `[implementer]` — built 3.10.2026

Built by the implementer to the lead's pure gate (`spoken_line_test`, 19
cases) and its own screen gate (`speech_pilot_test`, 28 cases); twelve
mutations, each red on a named case. What the brief got wrong, graded and
kept: **the lead's stitch case could not pass** — it expected
`22050 × 1600 ÷ 1000` frames where the clips' frames are each floored, so the
sum of the parts was one frame short of the rounding of the sum; the worker
stopped on it as the brief asks, and the case now sums frames. The
opponent's reply in a Mate-in-N puzzle comes from the solution tree at
**three** sites, not from `_playOpponentMove`, which serves the drills — all
three speak. `MoveWords.factsOf(fenBefore, from, to)` reads the facts off
the position, ambiguity included (file first, rank only when the file does
not settle it, both when neither does). `SpokenLine.text` closes the run
before „Check." with its own full stop, as the carrier does: „White plays
rook e8. Check." `SpeakableInfo` takes an optional `line` and the pilot
screen an optional `speech`, both defaulting to what production used. A
double-speak already on master in `SpeakableInfo` (an `autoSpeak` panel
said its sentence twice when the speaker turned speech on) was fixed and
has its case. The drill's loss speaks the mating reply and then the
dialog's sentence, so „Checkmate." is heard twice in a row — the live pass
decides whether that stays ([265.3]). The basic mate drill speaks replies
and verdicts as well; the homework game (`engine_game`) stays silent.
`SpeechService.init` loads the clips only when handed a `ClipVoice`, which
`main.dart` does, so the existing speech tests never touch `rootBundle`.

**Added the same day, on the owner's picture of a puzzle with two defences:**
when the board goes back to try the other defence, the voice says „Now
suppose Black plays pawn d4." and the move is drawn **when the sentence is
over** (at once with speech off). Two cut tokens (`now_suppose_white_plays`,
`now_suppose_black_plays`, carriers of that shape; 277 → **279** clips,
7.4 MB), `MoveWords.supposeLine` (castling is said plainly, its sentence
carrying the side), and `SpeechService.speakLine`'s future now completes
when a **queued** line has been played, not when it was put in the slot —
the verdict „Correct. Keep going." is still playing when the supposition is
asked for, and a future that resolved at once would have drawn the move
under it. A question form was considered and refused: every square clip is
cut from a statement and falls, and a question's square rises. The gate's
fixture first folded into one defence — the screen treats two defences with
the same answer as one — so the two defences have two answers. Three
mutations, each red on its case. Live item [265.7].

`SpokenLine` and `MoveWords` in `lib/core/speech/`; `ClipVoice` (load,
stitch, play, stop) with the player behind a seam a test can fake;
`SpeechService.speakLine` on the one queue (D9); the pilot screen speaking the
table of D3 through `SpeakableInfo` on its task line, and stopping when the
screen is left.

Gate, `test/speech_pilot_test.dart` with a fake player that records the token
sequence and the bytes it was handed:

1. A puzzle appears: the tokens are `[white, toMove, mateIn, two]` and the
   title's text equals the line's text (D4). The next puzzle speaks again;
   the same puzzle redrawn does not (the dedupe).
2. The opponent's reply is spoken by D1: a plain move, a capture („takes"),
   a check, castling, a promotion, and an ambiguous move with its letter
   (D11) — one case each; the bytes carry 50 ms of silence before the square
   and none elsewhere (D6).
3. The verdicts: a right move that continues, a wrong move, mate delivered,
   the drill lost, the drill drawn by stalemate.
4. Speech off: no bytes. The speaker button turns it on and speaks the task.
5. `ClipVoice.stitch` (pure): the data length is the sum of the clips plus
   the pauses, the header's fields are right, two clips of different formats
   are refused.
6. One queue: a `String` utterance asked while a line plays waits for it.
7. Leaving the screen stops the player.
8. Coverage of the alphabet (pure): `MoveWords` over every legal move of the
   games in the test fixtures' PGNs, and over every piece × from × to pair,
   never throws and never names a token without a clip.
9. `SpeechState.failed` when a clip is missing from the bundle (D10), with
   the token's name in the reason.

Mutations: the pause before the square dropped (2, 5); the reply spoken as
UCI (2); „takes" dropped on a capture (2); the letter dropped on an
ambiguous move (2); White and Black swapped (1); `stop` forgotten on dispose
(7); the dedupe removed (1); a token's clip deleted from the fake bundle (9).

### Phase 3 — the live pass `[owner]`

Items `[265.1]`–`[265.6]` in `TODO-provera.md`: the task on arrival, the
reply as a move, the three verdicts, the speaker turning speech on, the
pause by ear on the phone's speaker and on Windows, and the bundle's size in
the APK against the number phase 1 measured.

### Phase 4a — the tactics trainer `[implementer]` — built 3.10.2026

The owner approved the table in chat on 3.10.2026 and, with it, **deleted the
Hint** („Hint nam uopšte ne treba. Ako ima Show solution dugme, to je
dovoljno."): the button, `_useHint`, `_hintSquare`, and `revealHint` /
`usedHint` in the tactics model; `hinted` stays on the wire, always false,
because it is a server contract. The table, as built:

| When | Spoken, and drawn |
|---|---|
| A puzzle appears | the setup move as a move, then „White to move. Find the best move." — the side fixed when the puzzle starts, so flipping the board no longer changes or re-speaks the task |
| A right move that continues | „Correct. Keep going." (was „Correct — continue.") |
| The opponent replies | the move |
| A wrong move in practice | „Incorrect. Try another move." (was „That is not it…") |
| A wrong move in a one-attempt homework | „Incorrect. The assignment allows one attempt." then „Not solved." |
| Solved | „Solved." / „Solved with help." — the latter still reachable: a solve after a mistake in practice |
| Show solution | each remaining move as a move, then „Solved with help.", which the screen draws — the lead's one grading change: **a drawn sentence is never left unsaid** |
| Not spoken | rating, rating chip, Back, Retry skipped, Back to assignments |

Five phrase tokens (284 clips, 7.6 MB); every sentence on the screen through
`speakLine`, and a case holds that the device voice is never asked anything
there. Gate `test/speech_tactics_test.dart`, 17 cases; seven mutations, each
red on named cases. `pumpAndSettle` does not wait out a `Future.delayed`, so
the gate waits the reply's and the solution's beats explicitly. The manual's
tactics sentence no longer names the Hint; the endgame trainer keeps its
own. Live items [265.8]–[265.9].

### Phase 4b — the endgame trainer and the blunder walk `[implementer]` — built 3.10.2026

The owner approved the table in chat on 3.10.2026 („Idemo tako, Hint izbaci
i u završnicama, skrati tekstove"): **the Hint is deleted here too** (the
button, the H key, `_hintSquare`, `revealHint` / `usedHint` in the endgame
model), and the long explanations are cut to the spoken sentences. Both
screens draw everything through `EndgameInfoPanel`, which now takes a task
line, a detail line, verdict lines and a drawn-only note, and carries a
`SpeakableInfo` on the task — the panel had no speaker before. The table, as
built:

| When | Spoken, and drawn |
|---|---|
| A position appears (trainer) | „White to move. Keep the win." / „Hold the draw.", then the story: „In the game, White played *move* and dropped the win." / „…and lost the draw." |
| A right move with more to find | „Correct. The win is kept. Other moves to find: 2." — one line, because the service holds one queued line and the server's reply must not find the slot taken |
| The last move that holds | „Correct. The draw is held. You found every move that holds." / „…That was the only move." |
| A wrong move | „That move drops the win. Try another." / „…loses the draw…"; judged by the engine: „The engine judges that this move…"; a repeat: „You already found that move. Look for another." |
| Back after a wrong move in the drill | „Restored to the position before that move. Try another." |
| Show solution | „The only move that keeps the win is *move*." / „These moves keep the win: *move*, *move*." — the one drawn text that is not the line's own: the clips have no word for a comma |
| Play to the end | „Play to the end. Keep the win." / „…Hold the draw."; the opponent's reply as a move; „Good. Keep going. Moves left to hold: 7."; the end: „Checkmate. Drill completed." / „Draw held. Drill completed."; a move that lets it go: the move, then „lets the win go. The position is now lost." / „…now a draw." / „loses the draw. The drill stops here." |
| Conclude draw | „Draw. Nothing left to hold." — or, not a dead position yet, „Moves left to hold: 8." |
| The tablebase does not answer | „The tablebase is not answering. Try again in a moment." (every site, the walk's refutation included) |
| The blunder walk, at a mistake | „White played *move* here and let the win go." / „…and lost the draw.", then „Play the move that holds the win." / „…the draw." |
| The walk's verdicts | „Correct. The game continues as played." / „Correct. That was the last mistake. Game over." — the latter reachable for the first time: the branch compared `movesLeft` with 0 and the cursor stands on the mistake itself, so it was dead on master; it is `<= 1` now, with a case. A wrong move: the move, then „also lets the win go. Try another move." / „does not hold the draw. Try another move."; „Watch the refutation of *move*." |
| The walk's end | „Game finished. Found 3 of 5." — the number inside a sentence is its own set of clips (`nmid_N`, cut from „Found N of 5."), because a number cut from the end of „Mate in N." falls |
| Drawn, never spoken | „Checking tablebases…", the server's own refusal, „Holding moves were: …" on the walk's reveal, the keep-for-later result, „*SAN* did not hold." when the client cannot read a move the server judged |

Fifty tokens and the hundred inside-numbers (434 clips, 13.2 MB). A move
inside a sentence is said by `MoveWords.bare`, which drops „Check" and
„Checkmate" — inside „In the game, White played rook d3 and dropped the win"
a check would be a sentence of its own in the middle — and `factsOfSan` turns
the notation a server hands over into facts. Two of the clip gate's bounds
moved on measurement: a cut head that ends on a colon keeps half of the pause
after it (80–159 ms), and „of" is 88 ms of voice, under the old floor for an
empty clip. Gate `test/speech_endgames_test.dart`, 44 cases; thirteen
mutations by the worker and two by the lead, each red on named cases. The one
grading change: the worker had repaired a doubled full stop in the panel
(„…The drill stops here..", a cut token that ends a sentence followed by the
stop that closes a run) and capitalised the first letter there; both rules
are `SpokenLine`'s now, so every screen gets them, and the panel's copy is
deleted. The manual's endgame sentence no longer names the Hint, and the Keyboard
Shortcuts page no longer lists H — the full run found that row, which no
grep of the label had. Live items [265.10]–[265.13].

### Phase 4c — the repertoire, build and drill `[implementer]` — built 3.10.2026

The owner approved the table in chat on 3.10.2026 („Idemo tako, napravi
to"). The walkthrough is not in it. The table, as built:

| When | Spoken, and drawn |
|---|---|
| Build: a position asks for your move | „What do you play with White?" / „…with Black?" — said when it becomes a different question |
| Build: standing on your move, choosing replies | „After bishop e5 which opponent moves do you prepare?" — no comma: the drawn text is the line's own |
| Build: your move saved | „Bishop e5 is in your repertoire. The most played reply is knight c6." / „…The book has no reply here. Play the opponent move you want to prepare." |
| Build: everything answered | „You have answered every position in this repertoire." — the drawn line under it is gone |
| Build: the server or the engine did not answer | „The move was not saved. The server did not respond." / „The opponent move was not saved…" / „…not removed…" / „The engine did not respond in time." / „Could not read your progress. Starting from the opening position." |
| Drill: a position asks | the same question clip as build; „Play the move you chose for this position." is gone |
| Drill: after Reveal | „Your move is bishop e5. Play it." |
| Drill: the verdict, one line, said when the panel is drawn | „Correct." / „Also yours. Your main move is *move*." / „Incorrect. Your move is *move*." / „You have not covered this position. Open build to decide what you play."; then the reply as a move („White plays knight f3."), or the reply and „You have not covered this reply."; then „Returns tomorrow." / „Returns in a few minutes." / „Returns in 3 days." / „…in a week." / „…in 3 weeks." / „…in a month." / „…in 3 months."; ahead of schedule, „Ahead of schedule. The rating is not recorded." at the end. An incorrect answer carries no reply, as the table listed none — the worker's reading, recorded here for the live pass |
| Drill: the line walks on | nothing new; the condensed „Correct — e4 · opponent c5 · returns tomorrow" is deleted and the next question speaks |
| Drill: nothing to do | „Nothing due." / „Nothing to drill yet." / „Nothing due in this branch." / „Nothing to drill in this branch." / „Nothing due after bishop e5." / „Nothing to drill after bishop e5 yet." — spoken on arrival now; before, only the speaker played them |
| Drawn, never spoken | build's principle line, comment, engine lines and book table; drill's rehearsal texts, the numbered line above the board, the explanation under „nothing due" |

Thirty-six tokens (470 clips, 15.3 MB; 5 new carriers, 127 characters). Two
measured facts shaped the carriers: Azure's SDK reports „3 days" as **one
word** and „3 weeks", „3 months", „3 more days" as separate ones, so „Returns
in" is cut from the weeks carrier and „days." from „Returns in 3 more days.";
and „is in your repertoire." ends a sentence inside its carrier and keeps
211 ms of the pause, so the cut-tail bound is 250 ms. The question mark is
the first sentence end that is not a full stop: the word counter (both
homes), `SpokenLine` and the clip gate take it. „Returns in 3 days" reuses
the inside-sentence numbers cut from „Found N of 5." — a number in a new
neighbourhood, for the owner's ear ([265.16]).

Gate `test/speech_repertoire_test.dart`, 38 cases; 24 mutations by the
worker (one survivor, D14, given its case and re-run red) and one by the
lead. The grading change is in `SpokenLine`, found by the worker and left to
the lead: a bare move followed by a sentence head drew as one sentence
(„Your move is knight c6 Returns in 3 days."), because a run closed only on
a phrase or a token that ends one. **A cut token that starts with a capital
starts a sentence**, so the run before it closes first — a rule for every
screen, proved on `spoken_line_test` by mutation. The manual quotes none of
the deleted sentences. Live items [265.14]–[265.17].

### Phase 4d — the repertoire walkthrough `[implementer]` — built 3.10.2026

The owner approved the table in chat on 3.10.2026 („Idemo sa fiksnom
rečenicom, kreni sa šetnjom" — the fixed sentence for a note, the first of
the two decisions left to this phase). **The rule of when a stop speaks is
unchanged**: a fork, a hole, a note and the return beat speak; an ordinary
move on the trunk is drawn and silent, which is the plan's budget. The
table, as built:

| Stop | Spoken where the stop speaks, and drawn |
|---|---|
| Your move | „Your move. Main line." / „Your move. The alternative." — silent |
| The opponent's reply | „Black plays knight f3. In 42 of 100 games." — silent; under one percent „In less than one of 100 games."; no share: the move alone |
| A hole | the same, then „You have no reply here." — spoken; `Prepare reply` stays, unspoken |
| A fork | „From here the opponent has 3 replies. Knight f3 in 42 of 100 games. Pawn d4 in 30 of 100 games. No reply. And one more reply." / „And 2 more replies." — spoken, one line, the first three in tour order |
| A note | „You left a note here." — spoken; the note's text drawn under the line, never spoken |
| The return beat | „We saw the line after knight f3. Now comes pawn d4." / „Now comes pawn d4." / „Back to the fork.", then the fork clause — always spoken |
| Drawn, never spoken | the reply chips, the strip's counter, the arrows, the note's text |

**One wording changed on measurement.** The owner approved „in 42 percent
of games"; Azure's SDK reports „42 percent" and „42 per cent" as **one
word**, which the cutter cannot split, and „42 of 100 games" as separate
words (a six-sentence probe, 3.10.2026), so a share is said „in 42 of 100
games", with `nmid_100` added because a share can be the whole hundred.
Eighteen tokens (488 clips, 15.9 MB; 14 carriers, 342 characters).

The builder (`walkthrough_speech.dart`) produces a `SpokenLine` from the
position **before** the move (`fenBeforeStop`, read from the tour's paths;
a fork's replies and the return beat from the fork's own position), and
**throws on a move it cannot say** — a sentence with the move left out would
be another sentence said as this one. Two reach-limits recorded by the
worker: the return beat's two short forms are not reachable through the
screen (the tour never makes a beat without a `done` move) and are held in
the pure cases; and two share-less replies in one fork run together, since
no token closes a bare move — rare, a reply with no share being one not in
a book. The screen stops the voice on `dispose` (the file's old reason, a
`stop()` before anything was said, is already guarded in the service) and
still calls no `stop()` on moving. Gate `test/speech_walkthrough_test.dart`,
17 cases, and the builder's 24 pure cases; 20 mutations, one survivor (the
1% boundary, no fixture between 1 and 2 percent) given its case and re-run
red. A pre-existing screen case had never drawn the fork it was written for
(five holes, which the tour folds); rewritten openly. Live items
[265.18]–[265.20].

**With this every module speaks from the clips.** What is left of phase 4
is its last step, put to the owner as its own question: delete
`flutter_tts`, `speak(String)`, `app_speech_language`, and decide the rate
slider.

### Phase 4 — the other modules, one table each `[briefed after phase 3]`

In the order of what already speaks: the tactics trainer (4a, built); the
endgame trainer and the blunder walk (4b, built); the repertoire build and
drill (4c, built); the walkthrough (4d, built). Each gets its own table in the shape of D3, approved before
it is built, because the owner has said the words on the screens are not
final and settling them is a walk through the app, module by module.

Two decisions belong to this phase and are not made now: the walkthrough's
„Your note: …" (the lead's recommendation is the fixed sentence „You left a
note here." with the note on the screen; the alternative is the open door of
§2, rendered when the note is saved, by its author's account, the way a
narration is); and the last step, where `flutter_tts` and `speak(String)` are
deleted, `app_speech_language` with them, and the rate slider either goes or
becomes a playback speed.

## 5. Not in this plan

- Any language but English (D2).
- The tutorial film's narration and its routes — unchanged.
- The route for a free sentence (§2's third kind) — named, not built.
- The puzzle screen's redesign, which is item 5 of the owner's list of
  2.10.2026. The pilot touches its title line only, and `SpokenLine.text` is
  what any redesign draws there.
- Speech for a student in the room, where there is no device voice today.

## 6. Counts to measure against

Baseline on `master` at `6b5cd2f9`, from `CLAUDE.md`: the app **5446**
(1 skipped), `flutter analyze` **22** infos, the backend **2050** without a
database and **2214** with it (measured 1.10.2026). Phases 0–2 add no server
source and change no server test: the tool requires `services/tts/azure.js`
from under `tools/`, as `tools/status` requires the backend's modules, and
`sources_compile.test.js` does not walk `tools/`. The app's count rises by
the two gate files; the APK rises by the clips, measured in phase 1 and
checked in phase 3.
