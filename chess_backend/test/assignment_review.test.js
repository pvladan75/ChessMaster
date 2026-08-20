// assignment_review.test.js
// Covers the review of finished homework — who may see the answer, what each
// kind of item turns into, and the notes the two sides leave each other.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildReview,
  mayRevealSolution,
  shapeItem,
  stepsByPosition,
  lineToSan,
} = require('../services/assignmentReview');
const { addNote, deleteNote } = require('../services/assignmentNotes');

/// Captures queries and replays canned rows, one result per call in order.
function stubPool(results = [[]]) {
  const calls = [];
  let index = 0;
  return {
    calls,
    async query(text, params) {
      calls.push({ text, params });
      const rows = results[Math.min(index, results.length - 1)];
      index++;
      return { rows, rowCount: rows.length };
    },
  };
}

function customRow(overrides = {}) {
  return {
    id: 11,
    position: 0,
    puzzle_id: 'cust_1',
    puzzle_rating: null,
    solved: false,
    ms_taken: 4200,
    played_san: 'Qh7+',
    attempted_at: '2026-08-20T09:00:00Z',
    custom_fen: '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1',
    instruction: 'Beli matira u jednom potezu',
    solution_san: 'Ra8#',
    custom_themes: ['mate'],
    source_title: 'Mat u 333',
    source_label: '122',
    lichess_fen: null,
    lichess_moves: null,
    lichess_themes: null,
    lichess_rating: null,
    ...overrides,
  };
}

test('a student sees the answer only after they have answered', () => {
  assert.equal(mayRevealSolution({ attempted: false, isTrainer: false }), false);
  assert.equal(mayRevealSolution({ attempted: true, isTrainer: false }), true);
});

test('a trainer may see the answer to a position nobody has attempted', () => {
  // It is their own material and they chose it; pretending otherwise would
  // stop them checking what they set.
  assert.equal(mayRevealSolution({ attempted: false, isTrainer: true }), true);
});

test('an unanswered position hides its solution but says that it has one', () => {
  const item = shapeItem(
    customRow({ attempted_at: null, solved: null, played_san: null }),
    { isTrainer: false }
  );

  // Hiding the fact that a solution exists would look like a position with no
  // answer, which is a different and worse thing.
  assert.equal(item.solutionSan, null);
  assert.equal(item.solutionHidden, true);
  assert.equal(item.attempted, false);
});

test('an answered position releases the solution beside the move played', () => {
  const item = shapeItem(customRow(), { isTrainer: false });

  assert.equal(item.kind, 'custom');
  assert.equal(item.solutionSan, 'Ra8#');
  assert.equal(item.playedSan, 'Qh7+');
  assert.equal(item.solved, false);
  assert.equal(item.title, 'Mat u 333 #122');
});

test('a move nobody recorded stays unknown rather than becoming empty', () => {
  const item = shapeItem(customRow({ played_san: null }), { isTrainer: true });

  // The Lichess path reports only whether the puzzle was solved, and rows
  // answered before the column existed have nothing. "Not known" is the truth;
  // an empty string would read as "played nothing".
  assert.equal(item.playedSan, null);
});

test('a lesson step is read, not solved, and never reports as wrong', () => {
  const item = shapeItem(
    {
      id: 3,
      position: 1,
      puzzle_id: null,
      solved: null,
      ms_taken: null,
      played_san: null,
      attempted_at: '2026-08-20T09:00:00Z',
    },
    { isTrainer: true, step: { title: 'Vezivanje', fen: 'fen', instruction: 'Pogledaj' } }
  );

  assert.equal(item.kind, 'step');
  assert.equal(item.solved, null, 'a step that was read is not a wrong answer');
  assert.equal(item.title, 'Vezivanje');
  assert.equal(item.instruction, 'Pogledaj');
});

test('a Lichess item carries its line, once it may be shown', () => {
  const row = customRow({
    puzzle_id: '00abc',
    custom_fen: null,
    instruction: null,
    solution_san: null,
    custom_themes: null,
    source_title: null,
    source_label: null,
    lichess_fen: 'lichess-fen',
    lichess_moves: 'e2e4 e7e5',
    lichess_themes: ['fork'],
    lichess_rating: 1500,
  });

  assert.equal(shapeItem(row, { isTrainer: false }).solutionMoves, 'e2e4 e7e5');
  assert.equal(
    shapeItem({ ...row, attempted_at: null }, { isTrainer: false }).solutionMoves,
    null
  );
});

test('an item whose puzzle is gone still shows the attempt', () => {
  const item = shapeItem(
    {
      id: 5,
      position: 0,
      puzzle_id: 'cust_deleted',
      solved: true,
      ms_taken: 900,
      played_san: 'Ra8#',
      attempted_at: '2026-08-20T09:00:00Z',
      custom_fen: null,
      lichess_fen: null,
    },
    { isTrainer: true }
  );

  // The board is gone; what the child did is not, and dropping the row would
  // quietly change the count of what was done.
  assert.equal(item.kind, 'unknown');
  assert.equal(item.solved, true);
  assert.equal(item.fen, null);
});

test('steps survive being stored as text as well as as a list', () => {
  const asList = stepsByPosition([{ title: 'A' }, { title: 'B' }]);
  const asText = stepsByPosition('[{"title":"A"},{"title":"B"}]');

  assert.equal(asList.get(1).title, 'B');
  assert.equal(asText.get(1).title, 'B');
  assert.equal(stepsByPosition('not json').size, 0);
  assert.equal(stepsByPosition(null).size, 0);
});

test('someone who is neither side gets nothing back', async () => {
  const pool = stubPool([[]]);
  const review = await buildReview(pool, 7, 999);

  // Null for both "no such assignment" and "not yours", so ids cannot be probed.
  assert.equal(review, null);
  assert.equal(pool.calls.length, 1, 'nothing else is read after the refusal');
});

test('the review names whose words each note is', async () => {
  const pool = stubPool([
    [{ id: 7, trainer_id: 5, student_id: 9, kind: 'custom', title: 'Mat u 333' }],
    [customRow()],
    [
      { id: 1, item_id: null, author_id: 5, body: 'Bravo', created_at: null, author_name: 'Trener' },
      { id: 2, item_id: 11, author_id: 9, body: 'Ovu nisam razumeo', created_at: null, author_name: 'Učenik' },
    ],
  ]);

  const review = await buildReview(pool, 7, 9);

  assert.equal(review.viewer.isStudent, true);
  assert.equal(review.viewer.isTrainer, false);
  assert.equal(review.notes[0].mine, false);
  assert.equal(review.notes[1].mine, true);
  assert.equal(review.notes[1].itemId, 11);
  assert.equal(review.items.length, 1);
});

test('a note about a position in someone else\'s homework is refused', async () => {
  const pool = stubPool([
    [{ id: 7, trainer_id: 5, student_id: 9 }],
    [], // the item does not belong to this assignment
  ]);

  const result = await addNote(pool, {
    assignmentId: 7,
    itemId: 4242,
    authorId: 5,
    body: 'ovo je promašeno',
  });

  assert.equal(result.ok, false);
  assert.equal(result.status, 400);
  assert.match(result.error, /nije deo ovog zadatka/);
});

test('an empty note is refused before anything is read', async () => {
  const pool = stubPool([[]]);
  const result = await addNote(pool, { assignmentId: 7, authorId: 5, body: '   ' });

  assert.equal(result.ok, false);
  assert.equal(result.status, 400);
  assert.equal(pool.calls.length, 0);
});

test('an outsider cannot leave a note, and cannot tell why not', async () => {
  const pool = stubPool([[]]);
  const result = await addNote(pool, { assignmentId: 7, authorId: 999, body: 'zdravo' });

  assert.equal(result.status, 404);
  assert.match(result.error, /nije pronađen/);
});

test('a note on the whole assignment carries no position', async () => {
  const pool = stubPool([
    [{ id: 7, trainer_id: 5, student_id: 9 }],
    [{ id: 1, item_id: null, author_id: 5, body: 'Uradi do petka', created_at: null }],
  ]);

  const result = await addNote(pool, { assignmentId: 7, authorId: 5, body: 'Uradi do petka' });

  assert.equal(result.ok, true);
  assert.equal(result.note.itemId, null);
  assert.equal(result.note.mine, true);
  // No item lookup happens when there is no item to look up.
  assert.equal(pool.calls.length, 2);
});

test('only the author can take a note back', async () => {
  const pool = stubPool([[]]);
  const result = await deleteNote(pool, { assignmentId: 7, noteId: 1, authorId: 9 });

  assert.equal(result.ok, false);
  assert.equal(result.status, 404);
  // The author id is part of the statement rather than checked first: one
  // statement cannot be raced, and someone else's note simply matches nothing.
  assert.match(pool.calls[0].text, /author_id = \$3/);
});

// Seen live: a trainer looking at what their student missed was shown
// "e7b7 b8b7 g7g8q" — precise, and readable by nobody.
test('a Lichess line is translated into notation a person reads', () => {
  const start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  assert.equal(lineToSan(start, 'e2e4 e7e5 g1f3'), 'e4 e5 Nf3');
});

test('a promotion keeps its piece', () => {
  assert.equal(lineToSan('8/6P1/8/8/8/8/8/K6k w - - 0 1', 'g7g8q'), 'g8=Q');
});

test('a line that will not replay is shown as it was stored', () => {
  const start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  // The position and the line disagree about something real. Returning the raw
  // line shows that; an empty field would hide it.
  assert.equal(lineToSan(start, 'e2e5'), 'e2e5');
  assert.equal(lineToSan(start, 'e2e4 h7h5 e4e5 g8g6'), 'e2e4 h7h5 e4e5 g8g6');
});

test('a broken position does not take the line down with it', () => {
  assert.equal(lineToSan('not a fen', 'e2e4'), 'e2e4');
  assert.equal(lineToSan(null, 'e2e4'), 'e2e4');
});

test('no line at all stays absent', () => {
  assert.equal(lineToSan('8/8/8/8/8/8/8/K6k w - - 0 1', ''), null);
  assert.equal(lineToSan('8/8/8/8/8/8/8/K6k w - - 0 1', null), null);
});


test('a note names the other side, so they can be told about it', async () => {
  // Whichever side wrote it: a trainer's comment reaches the student, and a
  // student's question reaches the trainer. Worked out where the access check
  // already read both, so the route does not ask the database a second time.
  const asTrainer = stubPool([
    [{ id: 7, trainer_id: 5, student_id: 9, title: 'Matovi u dva' }],
    [{ id: 1, item_id: null, author_id: 5, body: 'bravo', created_at: 'now' }],
  ]);
  const fromTrainer = await addNote(asTrainer, { assignmentId: 7, authorId: 5, body: 'bravo' });

  assert.equal(fromTrainer.ok, true);
  assert.equal(fromTrainer.recipientId, 9, 'the student');
  assert.equal(fromTrainer.assignmentTitle, 'Matovi u dva');

  const asStudent = stubPool([
    [{ id: 7, trainer_id: 5, student_id: 9, title: 'Matovi u dva' }],
    [{ id: 2, item_id: null, author_id: 9, body: 'ne razumem', created_at: 'now' }],
  ]);
  const fromStudent = await addNote(asStudent, { assignmentId: 7, authorId: 9, body: 'ne razumem' });

  assert.equal(fromStudent.recipientId, 5, 'the trainer');
});


test('a lesson saved as a single position still shows its board', async () => {
  // Seen live on 20.8.2026: the trainer opened "Pregled i komentari" on a
  // one-position lesson and got "Pozicija 1" over an empty square reading
  // "tabla nije dostupna". Nothing had failed — this screen was the one of four
  // readers that looked only at `position_list`, which such a lesson does not
  // have.
  const FEN = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';
  const pool = stubPool([
    [{ id: 7, trainer_id: 5, student_id: 9, kind: 'lesson', lesson_id: 3, title: 'poyicija 1' }],
    [{ id: 11, position: 0, puzzle_id: null, attempted_at: null, solved: null }],
    [{ title: 'pozicija 1', fen: FEN, pgn: null, position_list: null }],
    [],
  ]);

  const review = await buildReview(pool, 7, 5);

  assert.equal(review.items.length, 1);
  assert.equal(review.items[0].kind, 'step');
  assert.equal(review.items[0].fen, FEN, 'the board the child was shown');
  assert.equal(review.items[0].title, 'pozicija 1');

  // And the lesson is read with the columns that carry it.
  assert.match(pool.calls[2].text, /SELECT title, fen, pgn, position_list/);
});

test('a lesson with real steps still reads them, not its own board', async () => {
  const FEN = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';
  const STEP_FEN = '8/8/8/8/8/5k2/6q1/7K b - - 0 1';
  const pool = stubPool([
    [{ id: 7, trainer_id: 5, student_id: 9, kind: 'lesson', lesson_id: 3, title: 'lekcija' }],
    [{ id: 11, position: 1, puzzle_id: null, attempted_at: null, solved: null }],
    [{
      title: 'lekcija',
      fen: FEN,
      pgn: null,
      position_list: [{ title: 'prvi', fen: FEN }, { title: 'drugi', fen: STEP_FEN }],
    }],
    [],
  ]);

  const review = await buildReview(pool, 7, 5);

  assert.equal(review.items[0].fen, STEP_FEN, 'the step at that position');
  assert.equal(review.items[0].title, 'drugi');
});
