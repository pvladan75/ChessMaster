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
  skipNode,
  unskipNode,
  skippedKeys,
  addExtraReply,
  removeExtraReply,
  importedMoves,
  forgetImportedMoves,
  deleteRepertoire,
  confirmNode,
  confirmLine,
} = require('../services/repertoireService');

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

test('a cut branch is stored by position, and cutting twice is not an error',
  async () => {
    // Pressing it again is the same sentence said twice, not a fault to read
    // about — and by position rather than by line, so a branch stays cut
    // however the game transposes into it.
    const pool = stubPool([[{ id: 3, fen_key: fenKey(SMITH_MORRA) }]]);
    await skipNode(pool, 5, { color: 'b', fen: SMITH_MORRA });

    assert.equal(pool.ran('INSERT INTO repertoire_skips'), 1);
    assert.equal(pool.ran('ON CONFLICT'), 1);
    assert.deepEqual(pool.calls[0].params, [5, 'b', fenKey(SMITH_MORRA)]);
  });

test('a cut branch can be put back', async () => {
  // Cutting has to be as cheap to undo as to do. A prune nobody can reverse is
  // not a decision, it is a risk, and people do not take it.
  const pool = stubPool([[]]);
  const back = await unskipNode(pool, 5, { color: 'b', fen: SMITH_MORRA });

  assert.equal(pool.ran('DELETE FROM repertoire_skips'), 1);
  assert.equal(back.skipped, false);
});

test('the cut branches are read in one query, as a set', async () => {
  // One query for the whole walk. Asking per node would make the frontier
  // quadratic in the thing it measures.
  const pool = stubPool([[{ fen_key: 'a' }, { fen_key: 'b' }]]);
  const cut = await skippedKeys(pool, 5, 'b');

  assert.equal(pool.calls.length, 1);
  assert.ok(cut.has('a') && cut.has('b'));
});

test('a cut needs a colour and a real position', async () => {
  const pool = stubPool([[]]);
  await assert.rejects(() => skipNode(pool, 5, { color: 'x', fen: SMITH_MORRA }),
    RangeError);
  await assert.rejects(() => skipNode(pool, 5, { color: 'b', fen: 'ovo nije fen' }),
    RangeError);
  assert.equal(pool.calls.length, 0, 'loš zahtev je stigao do baze');
});

test('an opponent move past the cut can be added to the preparation',
  async () => {
    // The wave covers 80% of what is played and names the remainder. That is a
    // good default and a bad wall: the tail was countable and unreachable.
    const pool = stubPool([[{ id: 4, fen_key: fenKey(SMITH_MORRA), uci: 'g1f3' }]]);
    await addExtraReply(pool, 5, {
      color: 'b', fen: SMITH_MORRA, uci: 'g1f3', san: 'Nf3',
    });

    assert.equal(pool.ran('INSERT INTO repertoire_extra_replies'), 1);
    // Per student. `opening_replies.covered` is shared by everybody, and
    // flipping it for one child would rewrite the walk every other child
    // follows.
    assert.deepEqual(pool.calls[0].params,
      [5, 'b', fenKey(SMITH_MORRA), 'g1f3', 'Nf3']);
  });

test('adding the same move twice is not an error', async () => {
  const pool = stubPool([[{ id: 4 }]]);
  await addExtraReply(pool, 5, { color: 'b', fen: SMITH_MORRA, uci: 'g1f3' });
  assert.equal(pool.ran('ON CONFLICT'), 1);
});

test('a move can be taken back out of the preparation', async () => {
  const pool = stubPool([[]]);
  const out = await removeExtraReply(pool, 5, {
    color: 'b', fen: SMITH_MORRA, uci: 'g1f3',
  });

  assert.equal(pool.ran('DELETE FROM repertoire_extra_replies'), 1);
  assert.equal(out.prepared, false);
});

test('preparing a move needs a colour, a position and a move', async () => {
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

test('confirming turns a generated move into a decision, never back',
  async () => {
    // The act that makes generating moves safe to offer at all. Until somebody
    // says "yes, this one", a generated move is scaffolding — drawn, walked
    // through, and never asked about by the drill.
    const pool = stubPool([[]]);
    await confirmNode(pool, 5, { color: 'b', fen: SMITH_MORRA });

    const sql = pool.calls[0].text;
    assert.match(sql, /SET source = 'chosen'/);
    // Only drafts. Confirming must be unable to touch a decision, in either
    // direction.
    assert.match(sql, /AND source = 'auto'/);
  });

test('confirming one move names it, and confirming a position does not',
  async () => {
    const one = stubPool([[]]);
    await confirmNode(one, 5, { color: 'b', fen: SMITH_MORRA, uci: 'b8c6' });
    assert.equal(one.calls[0].params[3], 'b8c6');

    const all = stubPool([[]]);
    await confirmNode(all, 5, { color: 'b', fen: SMITH_MORRA });
    assert.equal(all.calls[0].params[3], null);
  });

test('a line is confirmed in one statement', async () => {
  // A line half confirmed is a line the student would have to walk twice, and
  // a loop of updates is exactly where a dropped connection leaves one.
  const pool = stubPool([[]]);
  const out = await confirmLine(pool, 5, {
    color: 'b',
    fens: [SMITH_MORRA, SMITH_MORRA],
  });

  assert.equal(pool.calls.length, 1);
  assert.match(pool.calls[0].text, /fen_key = ANY\(\$3\)/);
  assert.equal(out.positions, 2);
});

test('an empty line is a bad request rather than a silent no-op', async () => {
  const pool = stubPool([[]]);
  await assert.rejects(
    () => confirmLine(pool, 5, { color: 'b', fens: [] }), RangeError);
  assert.equal(pool.calls.length, 0);
});
