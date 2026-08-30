// gameArchiveImport.js — filling `user_games`, and being able to say what got lost.
//
// Section 0 of docs/PLAN-MOJE-PARTIJE.md, the half that moves data.
// `gameArchive.js` decides what one game becomes; this decides where a few
// thousand of them come from, what is already known, and what the run is
// allowed to report when it finishes.
//
// Three things shape everything below.
//
// **A whole archive is one request, not thousands.** Lichess streams a player's
// entire history down a single response — four thousand games is about four
// minutes of it. So the rate limit that matters here is not requests per second
// but the fact that this address is shared by every user of the app, which is
// why even the one request goes through the same pacer as the explorer.
//
// **Four minutes is not a request.** The route starts a run and answers with
// its id; the work continues after the response, and the client asks how it is
// going. A run that dies with the process leaves a row saying 'running'
// forever, so a stale one is reaped rather than left to block the next attempt.
//
// **A game must never disappear quietly.** Every game read is stored, already
// known, or skipped for a named reason; the tally refuses to close otherwise
// and the database refuses to accept a finished run whose numbers do not add
// up. That is this codebase's recurring bug answered twice on purpose.

const {
  createPacer, MIN_REQUEST_GAP_MS, RATE_LIMIT_COOLDOWN_MS,
} = require('./lichessPacing');
const { normaliseGame, createTally } = require('./gameArchive');
const logger = require('./logger');

const DEFAULT_URL = process.env.LICHESS_GAMES_URL
  || 'https://lichess.org/api/games/user';

/// Lichess answers a request with no recognisable User-Agent with a fake 404
/// rather than an error — found by testing against the live API, and the same
/// reason the Flutter client sends one.
const USER_AGENT = 'chess-coach game archive';

/// A ceiling on one run, so a loop or a bad `since` cannot pull forever. Well
/// above the largest archive anyone here has: the ten-year one that sized this
/// plan is a little over four thousand games.
const MAX_GAMES_PER_RUN = 20000;

/// Rows per INSERT. One statement per game would be four thousand round trips
/// to a managed database on the other side of a network.
const BATCH_SIZE = 200;

/// A run still marked 'running' after this long did not finish — the process
/// was restarted under it. Left alone it would block every later import for
/// that user, which is a worse failure than the one it records.
const STALE_RUN_MS = 30 * 60 * 1000;

class ArchiveImportUnavailable extends Error {
  constructor(message, { reason = 'network', status = 502 } = {}) {
    super(message);
    this.name = 'ArchiveImportUnavailable';
    this.reason = reason;
    this.status = status;
  }
}

/// Cuts a PGN stream into games as the bytes arrive.
///
/// The one thing it must not do is lose the game that straddles a chunk
/// boundary, so it emits only what it has seen the *start of the next game*
/// after: the tail stays buffered until either a following `[Event` proves it
/// complete or [end] says there is no more. Feeding the same archive one byte
/// at a time and all at once has to produce the same games, and a test asserts
/// exactly that.
function createGameSplitter(onGame) {
  let buffer = '';
  let emitted = 0;

  const flush = (final) => {
    const parts = buffer.split(/\n\s*\n(?=\[Event )/);
    // The last part is only known to be whole once the stream ends.
    const complete = final ? parts : parts.slice(0, -1);
    buffer = final ? '' : parts[parts.length - 1];
    for (const part of complete) {
      const game = part.trim();
      if (!game) continue;
      emitted += 1;
      onGame(game);
    }
  };

  return {
    feed(chunk) {
      buffer += chunk;
      // Splitting on every chunk would be quadratic over a 9 MB archive; the
      // boundary can only exist once a `[Event` has arrived.
      if (buffer.includes('[Event ')) flush(false);
    },
    end() { flush(true); },
    get count() { return emitted; },
  };
}

const INSERT_COLUMNS = [
  'user_id', 'source', 'external_id', 'subject', 'subject_is_owner',
  'played_at', 'subject_color', 'result', 'subject_score', 'subject_elo',
  'opponent', 'opponent_elo', 'speed', 'time_control', 'rated', 'eco',
  'opening', 'termination', 'start_fen', 'moves', 'clocks', 'ply_count',
  'min_men', 'tb_entry_ply',
];

function rowValues(userId, row) {
  return [
    userId, row.source, row.external_id, row.subject, row.subject_is_owner,
    row.played_at, row.subject_color, row.result, row.subject_score,
    row.subject_elo, row.opponent, row.opponent_elo, row.speed,
    row.time_control, row.rated, row.eco, row.opening, row.termination,
    row.start_fen, row.moves, row.clocks, row.ply_count, row.min_men,
    row.tb_entry_ply,
  ];
}

function createArchiveImporter({
  pool,
  fetchImpl = (...args) => fetch(...args),
  baseUrl = DEFAULT_URL,
  token = process.env.LICHESS_API_TOKEN || '',
  maxGames = MAX_GAMES_PER_RUN,
  batchSize = BATCH_SIZE,
  staleRunMs = STALE_RUN_MS,
  streamTimeoutMs = 20 * 60 * 1000,
  minGapMs = MIN_REQUEST_GAP_MS,
  cooldownMs = RATE_LIMIT_COOLDOWN_MS,
  now = () => Date.now(),
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
} = {}) {
  if (!pool) throw new TypeError('createArchiveImporter requires a pool');
  const pacer = createPacer({ minGapMs, cooldownMs, now, sleep });

  /// A run that outlived its process is failed rather than left running, so the
  /// next attempt is not blocked by a job nobody is doing.
  async function reapStale(userId) {
    await pool.query(
      `UPDATE user_game_imports
          SET status = 'failed',
              error = 'Uvoz je prekinut pre nego što se završio.',
              finished_at = NOW()
        WHERE user_id = $1 AND status = 'running'
          AND started_at < NOW() - ($2::int * INTERVAL '1 millisecond')`,
      [userId, staleRunMs],
    );
  }

  /// Where an incremental import resumes from: the newest game already stored
  /// for this subject. Null on the first run, which pulls everything.
  async function lastPlayedAt(userId, subject, source) {
    const { rows } = await pool.query(
      `SELECT MAX(played_at) AS newest FROM user_games
        WHERE user_id = $1 AND subject = $2 AND source = $3`,
      [userId, subject, source],
    );
    return rows[0]?.newest || null;
  }

  async function writeBatch(userId, entries) {
    if (entries.length === 0) return { stored: 0, duplicate: 0 };
    const params = [];
    const tuples = entries.map(({ row }) => {
      const values = rowValues(userId, row);
      const start = params.length;
      params.push(...values);
      return `(${values.map((_, i) => `$${start + i + 1}`).join(', ')})`;
    });
    const result = await pool.query(
      `INSERT INTO user_games (${INSERT_COLUMNS.join(', ')})
       VALUES ${tuples.join(', ')}
       ON CONFLICT (user_id, source, external_id, subject) DO NOTHING
       RETURNING id, external_id`,
      params,
    );

    // Matched by external_id rather than by position. A multi-row INSERT does
    // return rows in the order it inserted them, but only the ones it actually
    // inserted — so lining the two lists up by index is right until the first
    // duplicate, and then quietly attaches one game's opening to another's.
    const idFor = new Map(result.rows.map((r) => [r.external_id, r.id]));
    const stored = entries.filter(({ row }) => idFor.has(row.external_id));
    await writeNodes(userId, stored, idFor);

    // Everything the insert did not return was already there — and its nodes
    // were written when it was. This is the only place duplicates are counted,
    // and counting them anywhere else would mean guessing at what the database
    // did.
    return { stored: result.rowCount, duplicate: entries.length - result.rowCount };
  }

  /// The early decisions of the games that were just stored, for section 1.
  ///
  /// Written in the same pass rather than by a later job: a report over an
  /// archive whose nodes were never filled would come back empty, which reads
  /// exactly like a player with no weaknesses.
  async function writeNodes(userId, stored, idFor) {
    const params = [];
    const tuples = [];
    for (const { row, nodes } of stored) {
      const gameId = idFor.get(row.external_id);
      for (const node of nodes || []) {
        const values = [
          userId, gameId, row.subject, row.subject_color, row.subject_score,
          node.ply, node.fen_key, node.san,
        ];
        const start = params.length;
        params.push(...values);
        tuples.push(`(${values.map((_, i) => `$${start + i + 1}`).join(', ')})`);
      }
    }
    if (tuples.length === 0) return;
    await pool.query(
      `INSERT INTO opening_nodes
         (user_id, game_id, subject, subject_color, subject_score, ply, fen_key, san)
       VALUES ${tuples.join(', ')}
       ON CONFLICT (game_id, ply) DO NOTHING`,
      params,
    );
  }

  async function saveProgress(importId, tally, { status, error } = {}) {
    const snapshot = tally.snapshot();
    await pool.query(
      `UPDATE user_game_imports
          SET games_read = $2, games_stored = $3, games_duplicate = $4,
              games_skipped = $5, skipped_by_reason = $6::jsonb,
              status = COALESCE($7, status),
              error = COALESCE($8, error),
              finished_at = CASE WHEN $7 IN ('done', 'failed') THEN NOW() ELSE finished_at END
        WHERE id = $1`,
      [
        importId, snapshot.read, snapshot.stored, snapshot.duplicate,
        snapshot.skipped, JSON.stringify(snapshot.skipped_by_reason),
        status || null, error || null,
      ],
    );
  }

  /// Opens the archive stream. Only ever one request, so the pacer here is
  /// about the address this server shares, not about pacing the download.
  async function openLichessStream(subject, since) {
    const params = new URLSearchParams({
      moves: 'true',
      tags: 'true',
      clocks: 'true',
      opening: 'true',
      evals: 'false',
      literate: 'false',
    });
    if (since) params.set('since', String(new Date(since).getTime()));

    const blockedFor = pacer.blockedForMs();
    if (blockedFor > 0) {
      throw new ArchiveImportUnavailable(
        `Lichess trenutno ne prima upite. Probajte za ${Math.ceil(blockedFor / 1000)} s.`,
        { reason: 'rate-limited', status: 503 },
      );
    }

    const headers = {
      Accept: 'application/x-chess-pgn',
      'User-Agent': USER_AGENT,
    };
    // The token is not required — this endpoint serves any account to anyone —
    // but it raises how fast the stream is allowed to arrive.
    if (token) headers.Authorization = `Bearer ${token}`;

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), streamTimeoutMs);
    let res;
    try {
      res = await pacer.spaced(() => fetchImpl(
        `${baseUrl}/${encodeURIComponent(subject)}?${params}`,
        { headers, signal: controller.signal },
      ));
    } catch (err) {
      clearTimeout(timer);
      throw new ArchiveImportUnavailable(
        'Nema veze sa Lichess-om.', { reason: 'network', status: 502 },
      );
    }

    if (res.status === 404) {
      clearTimeout(timer);
      throw new ArchiveImportUnavailable(
        `Lichess ne zna za nalog "${subject}".`,
        { reason: 'not-found', status: 404 },
      );
    }
    if (res.status === 429) {
      pacer.block();
      clearTimeout(timer);
      throw new ArchiveImportUnavailable(
        'Lichess je odbio zahtev zbog ograničenja. Probajte kasnije.',
        { reason: 'rate-limited', status: 503 },
      );
    }
    if (!res.ok) {
      clearTimeout(timer);
      throw new ArchiveImportUnavailable(
        `Lichess je odgovorio ${res.status}.`, { reason: 'network', status: 502 },
      );
    }
    return { res, done: () => clearTimeout(timer) };
  }

  /// Reads the stream (or the pasted text), and writes what it finds.
  ///
  /// The tally is closed *before* the run is marked done, so a run that lost
  /// games throws here and is recorded as failed — rather than being written as
  /// a success the database then refuses.
  async function run({
    importId, userId, subject, source, subjectIsOwner, since, pgnText, pgnStream,
  }) {
    const tally = createTally();
    let pending = [];
    let stopped = false;

    /// Writes whole batches, and the remainder only when told to. The tally is
    /// moved by what the database actually did with each row, never by what was
    /// handed to it.
    const drain = async (force) => {
      while (pending.length >= batchSize || (force && pending.length > 0)) {
        const batch = pending.splice(0, batchSize);
        const written = await writeBatch(userId, batch);
        for (let i = 0; i < written.stored; i += 1) tally.stored();
        for (let i = 0; i < written.duplicate; i += 1) tally.duplicate();
        await saveProgress(importId, tally);
      }
    };

    const take = (pgn) => {
      if (stopped) return;
      tally.read();
      if (tally.snapshot().read > maxGames) {
        stopped = true;
        throw new ArchiveImportUnavailable(
          `Arhiva je veća od ${maxGames} partija; uvoz je zaustavljen.`,
          { reason: 'too-large', status: 413 },
        );
      }
      const outcome = normaliseGame(pgn, { subject, source, subjectIsOwner });
      if (!outcome.ok) {
        tally.skipped(outcome.reason);
        return;
      }
      pending.push({ row: outcome.row, nodes: outcome.nodes });
    };

    try {
      const splitter = createGameSplitter(take);

      /// One reader for every source. An uploaded file, a Lichess response and
      /// a pasted string differ only in where the chunks come from, and the
      /// splitter has already been proven not to care where a chunk ends.
      const consume = async (chunks) => {
        const decoder = new TextDecoder();
        for await (const chunk of chunks) {
          splitter.feed(
            typeof chunk === 'string' ? chunk : decoder.decode(chunk, { stream: true }),
          );
          await drain(false);
        }
        // Whatever the decoder was holding for a multi-byte character split
        // across the last two chunks.
        splitter.feed(decoder.decode());
        splitter.end();
      };

      if (source === 'pgn') {
        await consume(pgnStream || [String(pgnText || '')]);
      } else {
        const { res, done } = await openLichessStream(subject, since);
        try {
          await consume(res.body);
        } finally {
          done();
        }
      }

      await drain(true);

      // Throws if anything went missing between reading and writing.
      tally.assertBalanced();
      await saveProgress(importId, tally, { status: 'done' });
      logger.info(
        `[ARHIVA] Uvoz ${importId} gotov: ${JSON.stringify(tally.snapshot())}`,
      );
      return tally.snapshot();
    } catch (err) {
      const message = err instanceof ArchiveImportUnavailable
        ? err.message
        : `Uvoz nije uspeo: ${err.message}`;
      logger.error(`[ARHIVA] Uvoz ${importId} pao: ${err.message}`);
      await saveProgress(importId, tally, { status: 'failed', error: message })
        .catch((saveErr) => logger.error(
          `[ARHIVA] Uvoz ${importId} nije mogao ni da upiše svoj neuspeh: ${saveErr.message}`,
        ));
      throw err;
    }
  }

  /// Starts a run and returns its id immediately. `finished` is the work, for a
  /// test or a caller that wants to wait; the route does not.
  async function start({
    userId, subject, source = 'lichess', subjectIsOwner = true,
    since = undefined, pgnText = undefined, pgnStream = undefined,
    incremental = true,
  }) {
    if (!Number.isInteger(userId)) throw new TypeError('userId is required');
    const handle = String(subject || '').trim();
    if (!handle) {
      throw new ArchiveImportUnavailable(
        'Nedostaje korisničko ime.', { reason: 'bad-request', status: 400 },
      );
    }
    if (!['lichess', 'pgn'].includes(source)) {
      throw new ArchiveImportUnavailable(
        `Nepoznat izvor: ${source}.`, { reason: 'bad-request', status: 400 },
      );
    }

    await reapStale(userId);
    const running = await pool.query(
      `SELECT id FROM user_game_imports WHERE user_id = $1 AND status = 'running' LIMIT 1`,
      [userId],
    );
    if (running.rowCount > 0) {
      // Two runs over one archive would double every counter and spend the
      // shared allowance twice for the same games.
      throw new ArchiveImportUnavailable(
        'Uvoz je već u toku.', { reason: 'already-running', status: 409 },
      );
    }

    const resumeFrom = source === 'lichess' && incremental && since === undefined
      ? await lastPlayedAt(userId, handle, source)
      : since || null;

    const created = await pool.query(
      `INSERT INTO user_game_imports (user_id, source, subject, since_at, status)
       VALUES ($1, $2, $3, $4, 'running') RETURNING id, started_at`,
      [userId, source, handle, resumeFrom],
    );
    const importId = created.rows[0].id;

    const finished = run({
      importId, userId, subject: handle, source, subjectIsOwner,
      since: resumeFrom, pgnText, pgnStream,
    });

    return { importId, since: resumeFrom, finished };
  }

  async function getRun(userId, importId) {
    const { rows } = await pool.query(
      `SELECT * FROM user_game_imports WHERE id = $1 AND user_id = $2`,
      [importId, userId],
    );
    return rows[0] || null;
  }

  async function listRuns(userId, limit = 10) {
    const { rows } = await pool.query(
      `SELECT * FROM user_game_imports WHERE user_id = $1
        ORDER BY started_at DESC LIMIT $2`,
      [userId, limit],
    );
    return rows;
  }

  /// What the archive screen shows before anything has been analysed.
  async function archiveStats(userId) {
    const { rows } = await pool.query(
      `SELECT COUNT(*)::int AS games,
              COUNT(*) FILTER (WHERE clocks IS NOT NULL)::int AS with_clocks,
              COUNT(*) FILTER (WHERE min_men <= 7)::int AS reached_tablebase,
              COUNT(DISTINCT subject)::int AS subjects,
              MIN(played_at) AS oldest,
              MAX(played_at) AS newest,
              COALESCE(SUM(ply_count), 0)::int AS plies
         FROM user_games WHERE user_id = $1`,
      [userId],
    );
    return rows[0];
  }

  return {
    start, getRun, listRuns, archiveStats,
    // Exposed for tests and for the endgame audit, which needs the same reaping.
    reapStale, lastPlayedAt,
  };
}

module.exports = {
  createArchiveImporter,
  createGameSplitter,
  ArchiveImportUnavailable,
  MAX_GAMES_PER_RUN,
  BATCH_SIZE,
  STALE_RUN_MS,
};
