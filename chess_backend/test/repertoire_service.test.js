const test = require('node:test');
const assert = require('node:assert/strict');

const {
  fenKey,
  createRepertoire,
  listRepertoires,
  nodeMoves,
  addMove,
  promoteMove,
  removeMove,
  recordAttempt,
  weakNodes,
  addExtraReply,
  removeExtraReply,
  sweepDanglingReplies,
  importedMoves,
  forgetImportedMoves,
  deleteRepertoire,
  storedBook,
} = require('../services/repertoireService');
const { Chess } = require('chess.js');

const SMITH_MORRA =
  'rnbqkbnr/pp1ppppp/8/8/4P3/2N5/PP3PPP/R1BQKBNR b KQkq - 0 4';

/// Captures queries and replays canned results, one per call in order.
///
/// `connect` hands back the same recorder, so a transaction's statements land
/// in the same list as everything else and a test can read the order they went
/// in — which is the only thing worth checking about a transaction here.
function stubPool(results = [[]]) {
  const calls = [];
  let index = 0;
  const query = async (text, params) => {
    calls.push({ text: text.replace(/\s+/g, ' ').trim(), params });
    const rows = results[Math.min(index, results.length - 1)];
    index += 1;
    return { rows, rowCount: rows.length };
  };
  let released = 0;
  return {
    calls,
    releases: () => released,
    query,
    connect: async () => ({ query, release: () => { released += 1; } }),
    ran: (fragment) => calls.filter((c) => c.text.includes(fragment)).length,
  };
}

test('a position is keyed without its move counters', () => {
  // The same board reached at move 4 and at move 12 is one position to a
  // repertoire. Keeping the counters is what would quietly make it two.
  assert.equal(
    fenKey(SMITH_MORRA),
    'rnbqkbnr/pp1ppppp/8/8/4P3/2N5/PP3PPP/R1BQKBNR b KQkq -',
  );
  assert.equal(
    fenKey('rnbqkbnr/pp1ppppp/8/8/4P3/2N5/PP3PPP/R1BQKBNR b KQkq - 6 12'),
    fenKey(SMITH_MORRA),
  );
});

test('a broken position and a missing colour are refused, not stored', async () => {
  const pool = stubPool();
  assert.throws(() => fenKey('nije fen'), RangeError);
  assert.throws(() => fenKey(''), RangeError);

  await assert.rejects(
    () => addMove(pool, 1, { color: 'x', fen: SMITH_MORRA, uci: 'g8f6', san: 'Nf6' }),
    RangeError,
  );
  await assert.rejects(
    () => createRepertoire(pool, 1, { name: '  ', color: 'b', rootFen: SMITH_MORRA }),
    RangeError,
  );
  await assert.rejects(
    () => createRepertoire(pool, 1, { name: 'Smit-Mora', color: 'b', rootFen: 'x' }),
    RangeError,
  );
  assert.equal(pool.calls.length, 0, 'ništa se ne šalje bazi dok ulaz nije dobar');
});

test('the first move kept in a position is the primary, the next is not',
  async () => {
    // No primary yet.
    const first = stubPool([[], [{ uci: 'g8f6', san: 'Nf6', role: 'primary' }]]);
    await addMove(first, 7, {
      color: 'b', fen: SMITH_MORRA, uci: 'g8f6', san: 'Nf6', verdict: 'theory',
    });
    assert.equal(first.calls[1].params[5], 'primary');

    // One already there.
    const second = stubPool([[{ x: 1 }], [{ uci: 'b8c6', san: 'Nc6', role: 'alternate' }]]);
    await addMove(second, 7, {
      color: 'b', fen: SMITH_MORRA, uci: 'b8c6', san: 'Nc6', verdict: 'playable',
    });
    assert.equal(second.calls[1].params[5], 'alternate');
  });

test('keeping the same move twice refreshes the verdict and leaves the role',
  async () => {
    const pool = stubPool([[{ x: 1 }], [{ uci: 'g8f6', role: 'primary' }]]);
    await addMove(pool, 7, {
      color: 'b', fen: SMITH_MORRA, uci: 'g8f6', san: 'Nf6', verdict: 'playable',
    });
    const insert = pool.calls[1].text;
    assert.match(insert, /ON CONFLICT/);
    assert.match(insert, /DO UPDATE SET verdict/);
    // The update clause may touch the verdict and the source and nothing
    // else. `role` appears after it only inside RETURNING, and never with an
    // `=` after it, which is what this looks for.
    assert.doesNotMatch(insert, /DO UPDATE SET[\s\S]*role\s*=/,
      'ponovno suđenje ne sme da promeni ono što je korisnik izabrao');
    // And a generated move can be promoted to a decision by being played, but
    // never the other way round.
    assert.match(insert, /source = CASE WHEN EXCLUDED\.source = 'chosen'/);
    // Whether the row is new, which is what decides whether the book's top
    // reply comes with it. `xmax = 0` is true only for a row this statement
    // inserted rather than updated.
    assert.match(insert, /\(xmax = 0\) AS inserted/);
  });

test('a move is written as the student\'s own and nothing else', async () => {
  const pool = stubPool([[], [{ uci: 'g8f6', role: 'primary' }]]);
  await assert.rejects(
    () => addMove(pool, 7, {
      color: 'b', fen: SMITH_MORRA, uci: 'g8f6', san: 'Nf6', source: 'auto',
    }),
    RangeError,
  );
  assert.equal(pool.calls.length, 0);
});

test('promoting demotes the old primary first, in one transaction', async () => {
  const pool = stubPool([[], [], [{ uci: 'b8c6', san: 'Nc6', role: 'primary' }]]);

  await promoteMove(pool, 7, { color: 'b', fen: SMITH_MORRA, uci: 'b8c6' });

  const texts = pool.calls.map((c) => c.text);
  assert.match(texts[0], /BEGIN/);
  assert.match(texts[1], /SET role = 'alternate'/);
  assert.match(texts[2], /SET role = 'primary'/);
  assert.match(texts[3], /COMMIT/);
  assert.equal(pool.releases(), 1, 'veza se vraća u bazen');
});

test('promoting a move that is not there leaves the old primary alone',
  async () => {
    // Otherwise the demotion would stand on its own and the position would be
    // left with moves and no primary — a node the drill cannot ask about.
    const pool = stubPool([[], [], []]);

    await assert.rejects(
      () => promoteMove(pool, 7, { color: 'b', fen: SMITH_MORRA, uci: 'a7a6' }),
      RangeError,
    );

    assert.equal(pool.ran('ROLLBACK'), 1);
    assert.equal(pool.ran('COMMIT'), 0);
    assert.equal(pool.releases(), 1);
  });

test('removing the primary promotes the oldest alternate', async () => {
  const pool = stubPool([[], [{ role: 'primary' }], [{ uci: 'b8c6', san: 'Nc6' }]]);

  const result = await removeMove(pool, 7, {
    color: 'b', fen: SMITH_MORRA, uci: 'g8f6',
  });

  assert.equal(result.removed, true);
  assert.deepEqual(result.promoted, { uci: 'b8c6', san: 'Nc6' });
  assert.equal(pool.ran('ORDER BY added_at ASC'), 1);
  assert.equal(pool.ran('COMMIT'), 1);
});

test('removing an alternate promotes nobody', async () => {
  const pool = stubPool([[], [{ role: 'alternate' }]]);

  const result = await removeMove(pool, 7, {
    color: 'b', fen: SMITH_MORRA, uci: 'b8c6',
  });

  assert.equal(result.removed, true);
  assert.equal(result.promoted, null);
  assert.equal(pool.ran("SET role = 'primary'"), 0);
});

test('removing a move that is not there changes nothing', async () => {
  const pool = stubPool([[], []]);

  const result = await removeMove(pool, 7, {
    color: 'b', fen: SMITH_MORRA, uci: 'h7h6',
  });

  assert.deepEqual(result, { removed: false, promoted: null });
  assert.equal(pool.ran('ROLLBACK'), 1);
});

/// A pool that holds the student's moves and answers the sweep's two queries
/// from them, so the test reads which positions the sweep kept.
function sweepPool(moves) {
  const calls = [];
  const query = async (text, params) => {
    const flat = text.replace(/\s+/g, ' ').trim();
    calls.push({ text: flat, params });
    if (flat.startsWith('SELECT fen_key, uci FROM repertoire_moves')) {
      return { rows: moves, rowCount: moves.length };
    }
    return { rows: [], rowCount: 3 };
  };
  return { calls, query };
}

test('the opponent moves left after no move of the student\'s are swept', async () => {
  // An opponent move stands only after a move of theirs. The live set is every
  // position a remaining move leads to, and everything else goes.
  const start = new Chess().fen();
  const pool = sweepPool([{ fen_key: fenKey(start), uci: 'e2e4' }]);
  const board = new Chess();
  board.move('e4');

  const gone = await sweepDanglingReplies(pool, 7, 'w');

  const del = pool.calls.find((c) => c.text.startsWith('DELETE FROM repertoire_extra_replies'));
  assert.ok(del, 'nothing was swept');
  assert.match(del.text, /NOT \(fen_key = ANY\(\$3::text\[\]\)\)/);
  assert.deepEqual(del.params, [7, 'w', [fenKey(board.fen())]]);
  assert.equal(gone, 3);
});

test('a move that will not replay keeps nothing alive after it', async () => {
  const pool = sweepPool([{ fen_key: fenKey(SMITH_MORRA), uci: 'a1a8' }]);
  await sweepDanglingReplies(pool, 7, 'b');

  const del = pool.calls.find((c) => c.text.startsWith('DELETE FROM repertoire_extra_replies'));
  assert.deepEqual(del.params[2], []);
});

test('removing a move sweeps the opponent moves after it, in the same transaction',
  async () => {
    const pool = stubPool([[], [{ role: 'alternate' }], [], [], []]);
    await removeMove(pool, 7, { color: 'b', fen: SMITH_MORRA, uci: 'b8c6' });

    const texts = pool.calls.map((c) => c.text);
    const sweep = texts.findIndex((t) => t.startsWith('DELETE FROM repertoire_extra_replies'));
    assert.ok(sweep > 0, 'the sweep did not run');
    assert.ok(sweep < texts.indexOf('COMMIT'), 'the sweep ran outside the transaction');
  });

test('the primary is read first, then the rest oldest first', async () => {
  const pool = stubPool([[
    { uci: 'g8f6', san: 'Nf6', role: 'primary', verdict: 'theory' },
    { uci: 'b8c6', san: 'Nc6', role: 'alternate', verdict: 'playable' },
  ]]);

  const moves = await nodeMoves(pool, 7, { color: 'b', fen: SMITH_MORRA });

  assert.deepEqual(moves.map((m) => m.uci), ['g8f6', 'b8c6']);
  assert.match(pool.calls[0].text, /ORDER BY \(role = 'primary'\) DESC/);
  assert.equal(pool.calls[0].params[2], fenKey(SMITH_MORRA));
});

test('a rejected attempt is written down too', async () => {
  // The whole reason the table exists: the moves the student did *not* keep are
  // where their instinct was wrong.
  const pool = stubPool([[{ id: 1, created_at: 'now' }]]);

  await recordAttempt(pool, 7, {
    color: 'b', fen: SMITH_MORRA, uci: 'd8a5', san: 'Qa5',
    verdict: 'mistake', kept: false, lookedUp: true,
  });

  const [, , , uci, san, verdict, kept, lookedUp] = pool.calls[0].params;
  assert.equal(uci, 'd8a5');
  assert.equal(san, 'Qa5');
  assert.equal(verdict, 'mistake');
  assert.equal(kept, false);
  assert.equal(lookedUp, true);
});

test('the weak positions are the ones that were missed or looked up', async () => {
  const pool = stubPool([[
    { fen_key: 'k1', mistakes: '3', lookups: '1', attempts: '5', last_at: 'x' },
  ]]);

  const nodes = await weakNodes(pool, 7, { color: 'b' });

  assert.deepEqual(nodes[0], {
    fenKey: 'k1', mistakes: 3, lookups: 1, attempts: 5, lastAt: 'x',
  });
  assert.match(pool.calls[0].text, /HAVING/);
});

test('a repertoire is a name for a starting point, and counts by colour',
  async () => {
    const pool = stubPool([[
      {
        id: 1, name: 'Smit-Mora, crni', color: 'b', root_fen: SMITH_MORRA,
        created_at: 'x', moves: '12',
      },
    ]]);

    const list = await listRepertoires(pool, 7);

    assert.equal(list[0].moves, 12);
    assert.equal(list[0].rootFen, SMITH_MORRA);
    // Counted per colour on purpose: the moves belong to (user, colour), and
    // two doors into the same graph honestly show the same number.
    assert.match(pool.calls[0].text, /m.user_id = r.user_id AND m.color = r.color/);
  });

test('an opponent move played on the board is entered for this student',
  async () => {
    const pool = stubPool([[{ id: 4, fen_key: fenKey(SMITH_MORRA), uci: 'g1f3' }]]);
    await addExtraReply(pool, 5, {
      color: 'b', fen: SMITH_MORRA, uci: 'g1f3', san: 'Nf3',
    });

    assert.equal(pool.ran('INSERT INTO repertoire_extra_replies'), 1);
    // Per student, and nothing about the book: `opening_replies` is shared by
    // everybody and is not asked whether the move is one it knows.
    assert.deepEqual(pool.calls[0].params,
      [5, 'b', fenKey(SMITH_MORRA), 'g1f3', 'Nf3']);
    assert.equal(pool.ran('opening_replies'), 0);
  });

test('adding the same move twice is not an error', async () => {
  const pool = stubPool([[{ id: 4 }]]);
  await addExtraReply(pool, 5, { color: 'b', fen: SMITH_MORRA, uci: 'g1f3' });
  assert.equal(pool.ran('ON CONFLICT'), 1);
});

test('an entered opponent move can be taken back out', async () => {
  const pool = stubPool([[]]);
  const out = await removeExtraReply(pool, 5, {
    color: 'b', fen: SMITH_MORRA, uci: 'g1f3',
  });

  assert.equal(pool.ran('DELETE FROM repertoire_extra_replies'), 1);
  assert.equal(out.prepared, false);
});

test('entering a move needs a colour, a position and a move', async () => {
  const pool = stubPool([[]]);
  await assert.rejects(
    () => addExtraReply(pool, 5, { color: 'x', fen: SMITH_MORRA, uci: 'g1f3' }),
    RangeError);
  await assert.rejects(
    () => addExtraReply(pool, 5, { color: 'b', fen: SMITH_MORRA }),
    RangeError);
  assert.equal(pool.calls.length, 0, 'loš zahtev je stigao do baze');
});

test('a move nobody was ever asked about is one the seed wrote', async () => {
  // Every move kept by hand writes a kept attempt at the moment it is kept.
  // A move without one was not chosen — it came from the archive seed, which
  // wrote through the same `addMove` into the same graph and left nothing else
  // to tell the two apart. That indistinguishability is why the seed is gone.
  const pool = stubPool([[{ moves: 1132, positions: 648 }]]);
  const found = await importedMoves(pool, 5, { color: 'b' });

  assert.equal(found.moves, 1132);
  assert.equal(found.positions, 648);
  assert.match(pool.calls[0].text, /FROM repertoire_attempts a/);
  assert.match(pool.calls[0].text, /a\.kept/);
});

test('removing them puts a primary back where one was taken away', async () => {
  // Not tidying. A position with any moves must have a primary or the drill has
  // nothing to ask for, and a bulk delete is the one path that can strip one
  // without `removeMove` promoting the next.
  const pool = stubPool([[]]);
  await forgetImportedMoves(pool, 5, { color: 'b' });

  assert.equal(pool.ran('DELETE FROM repertoire_moves'), 1);
  assert.equal(pool.ran("SET role = 'primary'"), 1);
  // Both halves in one transaction: a repertoire between them is one the drill
  // cannot read.
  assert.equal(pool.ran('BEGIN'), 1);
  assert.equal(pool.ran('COMMIT'), 1);
  assert.equal(pool.releases(), 1);
});

test('deleting a repertoire takes the door and never the moves', async () => {
  // The moves belong to (user, colour) and are shared by every repertoire that
  // reaches them. Deleting them here would empty one door's worth of work out
  // of every other door.
  const pool = stubPool([[]]);
  await deleteRepertoire(pool, 5, 3);

  assert.equal(pool.calls.length, 1);
  assert.match(pool.calls[0].text, /DELETE FROM repertoires WHERE id = \$1 AND user_id = \$2/);
  assert.deepEqual(pool.calls[0].params, [3, 5]);
});

test('a repertoire that is not named by a number is a bad request', async () => {
  const pool = stubPool([[]]);
  await assert.rejects(() => deleteRepertoire(pool, 5, 'sve'), RangeError);
  assert.equal(pool.calls.length, 0);
});

test('the stored book is one read of this server\'s own table', async () => {
  const pool = stubPool([[
    { uci: 'g1f3', san: 'Nf3', games: 500, share: '0.5', covered: true, prepared: false },
  ]]);
  const book = await storedBook(pool, 5, { color: 'b', fen: SMITH_MORRA });

  assert.equal(pool.calls.length, 1);
  assert.match(pool.calls[0].text, /FROM opening_replies/);
  assert.equal(book.opened, true);
  assert.equal(book.replies[0].games, 500);
  assert.equal(book.replies[0].covered, true);
  // Most played first, and a tie broken the same way every time: the first
  // row is the reply entered with the student's move, and two reads must not
  // name two different ones.
  assert.match(pool.calls[0].text, /ORDER BY r\.games DESC, r\.uci ASC/);
});

test('a position with nothing stored says so rather than an empty book', async () => {
  // Two different empties, and only one of them means "the opponent plays
  // nothing here". `repertoireBook.bookAt` fills the other one from the book.
  const pool = stubPool([[]]);
  const book = await storedBook(pool, 5, { color: 'b', fen: SMITH_MORRA });

  assert.equal(book.opened, false);
  assert.deepEqual(book.replies, []);
});

test('the book says which replies this student entered', async () => {
  const pool = stubPool([[]]);
  await storedBook(pool, 5, { color: 'b', fen: SMITH_MORRA });

  assert.match(pool.calls[0].text, /FROM repertoire_extra_replies e/);
  // Keyed by the reader, because an entered move is per student.
  assert.deepEqual(pool.calls[0].params.slice(2, 4), [5, 'b']);
  // The book's rows, and not a Lichess band's that share its band number.
  assert.match(pool.calls[0].text, /r\.source = \$5/);
  assert.deepEqual([pool.calls[0].params[1], pool.calls[0].params[4]], [0, 'book']);
});
