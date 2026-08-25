require('dotenv').config();
const fs = require('fs');
const { Pool } = require('pg');
const logger = require('./services/logger');

/// Decides how the connection is secured, from the environment alone.
///
/// Three states, in order of preference:
///
///   DB_CA_PATH set  — the managed cluster's CA is on disk, so the certificate
///                     chain *and* the hostname are verified. This is what
///                     DigitalOcean calls `verify-full`, and the only setting
///                     under which encryption actually proves who answered.
///   DB_SSL=true     — encrypted but unverified, the historical behaviour. Kept
///                     as a fallback so an environment without the CA file
///                     still starts; over the public internet it is open to an
///                     active man in the middle.
///   neither         — plaintext, for a local PostgreSQL that has no TLS.
///
/// Exported for the tests: this is a security setting where "probably right"
/// is not good enough, and it is the kind of thing an .env edit breaks quietly.
function buildSslConfig(env = process.env) {
  if (env.DB_CA_PATH) {
    // Deliberately unguarded: a CA path that does not resolve must stop the
    // process, not silently downgrade the connection to unverified.
    return { ca: fs.readFileSync(env.DB_CA_PATH, 'utf8'), rejectUnauthorized: true };
  }
  if (env.DB_SSL === 'true') {
    return { rejectUnauthorized: false };
  }
  return false;
}

const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_DATABASE,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
  ssl: buildSslConfig()
});

async function initDB() {
  const client = await pool.connect();
  try {
    logger.info('Successfully connected to DigitalOcean PostgreSQL database.');

    // Create users table
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        name VARCHAR(255) NOT NULL,
        role VARCHAR(50) NOT NULL DEFAULT 'korisnik'
      );
      ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
      ALTER TABLE users DROP CONSTRAINT IF EXISTS user_role_check;
      ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('korisnik', 'host', 'admin', 'user', 'trener', 'ucenik'));
      ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
      ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_code VARCHAR(6);
      UPDATE users SET is_verified = TRUE WHERE is_verified IS FALSE AND verification_code IS NULL;
    `);
    logger.info('Verified database table & role migration: users (is_verified & verification_code)');

    // Create rooms table
    await client.query(`
      CREATE TABLE IF NOT EXISTS rooms (
        id SERIAL PRIMARY KEY,
        room_code VARCHAR(6) UNIQUE NOT NULL,
        creator_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        current_fen VARCHAR(255) DEFAULT 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'archived')),
        board_control VARCHAR(50) DEFAULT 'host_only',
        allow_student_engine BOOLEAN DEFAULT FALSE
      );
    `);
    
    // Add column if table already exists
    await client.query(`
      ALTER TABLE rooms 
      ADD COLUMN IF NOT EXISTS board_control VARCHAR(50) DEFAULT 'host_only';
    `);
    await client.query(`
      ALTER TABLE rooms 
      ADD COLUMN IF NOT EXISTS allow_student_engine BOOLEAN DEFAULT FALSE;
    `);
    // Whether somebody who is not signed in may watch. FALSE by default, and
    // that default is the point: until now a room admitted anybody who had the
    // code, including a guest, and the room nobody thought about is exactly the
    // one a stranger walks into.
    await client.query(`
      ALTER TABLE rooms 
      ADD COLUMN IF NOT EXISTS allow_guests BOOLEAN DEFAULT FALSE;
    `);
    // Create puzzles table
    await client.query(`
      CREATE TABLE IF NOT EXISTS puzzles (
        id SERIAL PRIMARY KEY,
        puzzle_id VARCHAR(100) UNIQUE NOT NULL,
        source VARCHAR(100) NOT NULL,
        fen VARCHAR(255) NOT NULL,
        side_to_move VARCHAR(10) NOT NULL,
        eval VARCHAR(20) NOT NULL,
        eval_value NUMERIC(6, 2) DEFAULT 0,
        type VARCHAR(50) NOT NULL,
        mate_depth INTEGER DEFAULT NULL,
        winning_move_uci VARCHAR(10) NOT NULL,
        winning_move_san VARCHAR(20) NOT NULL,
        solutions JSONB DEFAULT '{}'::jsonb
      );
      CREATE INDEX IF NOT EXISTS idx_puzzles_type_depth ON puzzles(type, mate_depth);
    `);
    await client.query(`
      ALTER TABLE puzzles 
      ADD COLUMN IF NOT EXISTS solutions JSONB DEFAULT '{}'::jsonb;
    `);
    logger.info('Verified database table: puzzles (with solutions column)');

    // Create saved_lessons table
    // user_id is the lesson's owner; trainer_id is the trainer who shared it with
    // their students. routes/lessons.js writes both, and limitsService counts by
    // either, so a fresh database must have both columns.
    await client.query(`
      CREATE TABLE IF NOT EXISTS saved_lessons (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        trainer_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        tags VARCHAR(255)[],
        fen VARCHAR(255) NOT NULL,
        pgn TEXT,
        position_list JSONB,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Bring pre-existing databases up to the same shape.
    await client.query(`
      ALTER TABLE saved_lessons
      ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(id) ON DELETE CASCADE;
    `);
    await client.query(`
      ALTER TABLE saved_lessons
      ADD COLUMN IF NOT EXISTS position_list JSONB;
    `);
    logger.info('Verified database table: saved_lessons (with user_id & position_list)');

    // Create saved_analyses table (Analysis Studio: save/load a variation tree,
    // readable from any device the user logs into).
    await client.query(`
      CREATE TABLE IF NOT EXISTS saved_analyses (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        starting_fen VARCHAR(255) NOT NULL,
        tree_json JSONB NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    logger.info('Verified database table: saved_analyses');

    // Create trainer_students table
    await client.query(`
      CREATE TABLE IF NOT EXISTS trainer_students (
        id SERIAL PRIMARY KEY,
        trainer_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        student_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        UNIQUE(trainer_id, student_id)
      );
    `);
    // A teaching relationship now needs both sides to agree.
    //
    // `status` defaults to 'accepted' deliberately: that grandfathers the rows
    // written before consent existed, so no migration script is needed. Every
    // new row is inserted with an explicit 'pending' instead.
    //
    // `initiated_by` is what makes one column serve both directions — a trainer
    // may enrol a student and a student may ask a trainer, and whoever did not
    // start it is the one who has to answer.
    //
    // The parent_* columns are added now although the consent flow is not built
    // yet: an empty column costs nothing today, and the same column added later
    // over live children's records costs a migration.
    await client.query(`
      ALTER TABLE trainer_students
        ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'accepted',
        ADD COLUMN IF NOT EXISTS initiated_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
        ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        ADD COLUMN IF NOT EXISTS responded_at TIMESTAMPTZ,
        ADD COLUMN IF NOT EXISTS parent_email VARCHAR(255),
        ADD COLUMN IF NOT EXISTS parent_consent_at TIMESTAMPTZ,
        ADD COLUMN IF NOT EXISTS parent_consent_ip VARCHAR(64),
        ADD COLUMN IF NOT EXISTS parent_consent_version VARCHAR(40);
      ALTER TABLE trainer_students DROP CONSTRAINT IF EXISTS trainer_students_status_check;
      ALTER TABLE trainer_students ADD CONSTRAINT trainer_students_status_check
        CHECK (status IN ('pending', 'awaiting_parent', 'accepted'));
    `);

    // Whether this student may **speak** in this trainer's room, or only listen
    // and answer on the board.
    //
    // It sits on the relationship rather than on the account because that is
    // where it is true: the same child can be listening-only with a trainer they
    // met last week and talking with the one they have had for two years.
    //
    // `'talk'` is the default so that every relationship that already exists
    // keeps working exactly as it did — the same grandfathering `status` uses
    // above. New rows do **not** take the default: `requestRelationship` writes
    // the value it means, and for a student known to be a minor that is
    // `'listen'`. A default that silently muted forty existing students would
    // be its own kind of failure.
    await client.query(`
      ALTER TABLE trainer_students
        ADD COLUMN IF NOT EXISTS voice_level VARCHAR(10) NOT NULL DEFAULT 'talk';
      ALTER TABLE trainer_students DROP CONSTRAINT IF EXISTS trainer_students_voice_check;
      ALTER TABLE trainer_students ADD CONSTRAINT trainer_students_voice_check
        CHECK (voice_level IN ('listen', 'talk'));
    `);
    logger.info('Verified database table: trainer_students (with voice_level)');
    logger.info('Verified database table: trainer_students (with consent columns)');
    
    // Add account_type column to users table if missing
    await client.query(`
      ALTER TABLE users 
      ADD COLUMN IF NOT EXISTS account_type VARCHAR(50) DEFAULT 'free';
    `);
    logger.info('Verified database table: users (with account_type)');

    // The year the user says they were born, and when they said it.
    //
    // A year, not a date: it answers the only question asked of it — which side
    // of the age of consent somebody is on — and it is one field less about a
    // child. Within the year of a birthday it is ambiguous by one, and
    // `ageService.statedAge` resolves that towards the *younger* reading.
    //
    // NULL is the honest state and today it is every row: nothing has ever
    // asked. It must not read as "adult" anywhere, which is why the check lives
    // in one service rather than in each caller.
    await client.query(`
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS birth_year INTEGER,
        ADD COLUMN IF NOT EXISTS birth_year_stated_at TIMESTAMPTZ;
      ALTER TABLE users DROP CONSTRAINT IF EXISTS users_birth_year_check;
      ALTER TABLE users ADD CONSTRAINT users_birth_year_check
        CHECK (birth_year IS NULL OR (birth_year > 1900 AND birth_year < 2200));
    `);
    logger.info('Verified database table: users (with birth_year)');

    // The consent that sits on the **account**: may this child use the
    // interactive part of the app at all. It is not the same question as the
    // one already on `trainer_students`, which asks whether *this* trainer may
    // teach them, see their homework and record them — the first answers "may
    // the child be here", the second "may it be him".
    //
    // `parent_consent_version` records **which text** was agreed to. The wording
    // was confirmed by a lawyer on 25.8.2026 for Serbia only, so it will change
    // when the country list does, and a consent record that cannot say what was
    // consented to is not a record.
    await client.query(`
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS parent_email VARCHAR(255),
        ADD COLUMN IF NOT EXISTS parent_consent_at TIMESTAMPTZ,
        ADD COLUMN IF NOT EXISTS parent_consent_ip VARCHAR(64),
        ADD COLUMN IF NOT EXISTS parent_consent_version VARCHAR(40);
    `);
    logger.info('Verified database table: users (with parent consent columns)');

    // Whether the parent agreed to the **recording** — item 3 of the approved
    // form, and the only one of the three that is optional: a child may attend
    // lessons with it refused.
    //
    // Three states, not two. NULL means nobody has been asked, and it must not
    // read as "no" any more than it reads as "yes": every relationship that
    // exists today is NULL, and treating that as a refusal would turn recording
    // off for forty running courses on the strength of a column that was empty
    // an hour ago.
    await client.query(`
      ALTER TABLE trainer_students
        ADD COLUMN IF NOT EXISTS parent_allows_recording BOOLEAN;
    `);

    // The request a parent is actually answering: one row per ask, addressed to
    // one email, reachable by one link.
    //
    // The token is stored **hashed**. Nothing ever needs the original back — the
    // parent has it in their mail — so keeping it would only mean that a leaked
    // backup is a pile of working links into children's records.
    //
    // `text_version` is copied onto the request rather than read at answer time:
    // the parent agrees to the text they were shown, and the text will change
    // when the country list does.
    await client.query(`
      CREATE TABLE IF NOT EXISTS parent_consent_requests (
        id SERIAL PRIMARY KEY,
        relationship_id INTEGER NOT NULL REFERENCES trainer_students(id) ON DELETE CASCADE,
        student_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        trainer_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        parent_email VARCHAR(255) NOT NULL,
        token_hash VARCHAR(64) NOT NULL UNIQUE,
        text_version VARCHAR(40) NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
        expires_at TIMESTAMPTZ NOT NULL,
        answered_at TIMESTAMPTZ,
        granted BOOLEAN
      );
      CREATE INDEX IF NOT EXISTS parent_consent_requests_relationship
        ON parent_consent_requests (relationship_id);
    `);
    logger.info('Verified database table: parent_consent_requests');

    // Add created_at column to rooms table if missing
    await client.query(`
      ALTER TABLE rooms 
      ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
    `);

    // Create session_recordings table
    await client.query(`
      CREATE TABLE IF NOT EXISTS session_recordings (
        id SERIAL PRIMARY KEY,
        room_id VARCHAR(50) NOT NULL,
        host_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        audio_url TEXT,
        video_url VARCHAR(500),
        timeline_json JSONB NOT NULL,
        participants INTEGER[] DEFAULT '{}',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      ALTER TABLE session_recordings 
      ADD COLUMN IF NOT EXISTS video_url VARCHAR(500);
      ALTER TABLE session_recordings 
      ADD COLUMN IF NOT EXISTS participants INTEGER[] DEFAULT '{}';
    `);
    logger.info('Verified database table: session_recordings');

    // Create friends table
    await client.query(`
      CREATE TABLE IF NOT EXISTS friends (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        friend_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (user_id, friend_id)
      );
    `);
    logger.info('Verified database table: friends');

    // Create user_notifications table
    await client.query(`
      CREATE TABLE IF NOT EXISTS user_notifications (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        sender_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        room_code VARCHAR(10) NOT NULL,
        title VARCHAR(255) NOT NULL,
        message TEXT NOT NULL,
        is_read BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    // Notifications started out as room invitations only, so room_code was
    // mandatory. They now also carry a request to become someone's student,
    // which has no room — hence the drop, and `kind` so the client knows which
    // buttons to draw. `ref_id` points at the row the notification is about.
    await client.query(`
      ALTER TABLE user_notifications ALTER COLUMN room_code DROP NOT NULL;
      ALTER TABLE user_notifications
        ADD COLUMN IF NOT EXISTS kind VARCHAR(30) NOT NULL DEFAULT 'room',
        ADD COLUMN IF NOT EXISTS ref_id INTEGER;
    `);
    logger.info('Verified database table: user_notifications (with kind & ref_id)');

    // Create scheduled_sessions table
    await client.query(`
      CREATE TABLE IF NOT EXISTS scheduled_sessions (
        id SERIAL PRIMARY KEY,
        host_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        room_code VARCHAR(10) NOT NULL,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        scheduled_at TIMESTAMP NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    logger.info('Verified database table: scheduled_sessions');

    // Create scheduled_session_invites table
    await client.query(`
      CREATE TABLE IF NOT EXISTS scheduled_session_invites (
        id SERIAL PRIMARY KEY,
        session_id INTEGER REFERENCES scheduled_sessions(id) ON DELETE CASCADE,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(session_id, user_id)
      );
    `);
    logger.info('Verified database table: scheduled_session_invites');


    // Create user_puzzle_ratings table
    await client.query(`
      CREATE TABLE IF NOT EXISTS user_puzzle_ratings (
        user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        overall_rating INT DEFAULT 1500,
        rating_deviation INT DEFAULT 350,
        theme_ratings JSONB DEFAULT '{}'::jsonb,
        puzzles_solved INT DEFAULT 0,
        puzzles_failed INT DEFAULT 0,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Create endgame_puzzles table.
    //
    // The original table held a position and nothing else - no solution, no
    // endgame type - because the generator it was written for produced nothing
    // else. The miner in puzzles/endgame_miner.py does, so the columns below
    // carry what an exercise actually needs.
    //
    // `winning_moves` is the part that matters most: every move that holds the
    // result, not just the engine's favourite. Measured over the mined set, 68%
    // of positions have more than one, and a trainer that accepts only the
    // first tells a child playing an equally winning move that it is wrong.
    //
    // `piece_count` and `pawn_count` are denormalised out of the FEN because
    // every consumer filters on one or the other and for different reasons:
    // the play-it-out drill needs <= 5 pieces because that is as far as the
    // tablebases reach, while a pawn-ending lesson wants many pawns, since the
    // pawn structure is the subject. Deriving them per query would mean parsing
    // FENs in SQL.
    await client.query(`
      CREATE TABLE IF NOT EXISTS endgame_puzzles (
        id SERIAL PRIMARY KEY,
        puzzle_id VARCHAR(100),
        fen TEXT NOT NULL,
        evaluation VARCHAR(100),
        difficulty VARCHAR(50) DEFAULT 'medium',
        piece_tags VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    // Added rather than folded into CREATE TABLE, so a database that already
    // holds the old shape is migrated instead of left behind.
    await client.query(`
      ALTER TABLE endgame_puzzles
        ADD COLUMN IF NOT EXISTS endgame_type VARCHAR(40),
        ADD COLUMN IF NOT EXISTS mode VARCHAR(8),
        ADD COLUMN IF NOT EXISTS side_to_move CHAR(1),
        ADD COLUMN IF NOT EXISTS winning_moves VARCHAR(8)[] NOT NULL DEFAULT '{}',
        ADD COLUMN IF NOT EXISTS solution VARCHAR(8)[] NOT NULL DEFAULT '{}',
        ADD COLUMN IF NOT EXISTS solution_san VARCHAR(12)[] NOT NULL DEFAULT '{}',
        ADD COLUMN IF NOT EXISTS difficulty_score SMALLINT,
        ADD COLUMN IF NOT EXISTS piece_count SMALLINT,
        ADD COLUMN IF NOT EXISTS pawn_count SMALLINT,
        ADD COLUMN IF NOT EXISTS source VARCHAR(16),
        ADD COLUMN IF NOT EXISTS wdl SMALLINT,
        ADD COLUMN IF NOT EXISTS dtz INTEGER,
        ADD COLUMN IF NOT EXISTS game_white VARCHAR(120),
        ADD COLUMN IF NOT EXISTS game_black VARCHAR(120),
        ADD COLUMN IF NOT EXISTS game_date VARCHAR(12),
        -- The Syzygy table the position belongs to, normalised so the same
        -- ending has one name whichever side is stronger: KRPvKR, not both
        -- that and KRvKRP. Finer than endgame_type, which carries the seven
        -- hand-picked mined categories and keeps that meaning.
        ADD COLUMN IF NOT EXISTS material VARCHAR(16),
        -- The rating of the player who got it wrong, where the position came
        -- from a real mistake. An honest difficulty signal, and reproducible,
        -- which the mined difficulty score turned out not to be.
        ADD COLUMN IF NOT EXISTS blunder_elo SMALLINT,
        -- What was played instead. Not a solution, but the thing that makes
        -- the position a story rather than a diagram: somebody stood here
        -- and chose this.
        ADD COLUMN IF NOT EXISTS played_move VARCHAR(12),
        -- Whether the two bishops stand on different colours. The material key
        -- cannot say - KBPvKBP covers both - and they are different endings, so
        -- it is read from the position at import. NULL where the question does
        -- not arise, which is most of the collection, so a filter can tell "no"
        -- from "not applicable".
        ADD COLUMN IF NOT EXISTS opposite_bishops BOOLEAN,
        -- Which base the position was mined out of, by file name, the same way
        -- blunder_games records it. Over-the-board and the master bases are one
        -- pool for teaching; the online base is kept apart, because difficulty
        -- comes from the rating of whoever erred and an online rating is not an
        -- over-the-board rating. NULL for everything the miner found rather
        -- than took from a game, which is not online either.
        ADD COLUMN IF NOT EXISTS source_db VARCHAR(80);
    `);
    // Without this the importer's ON CONFLICT DO NOTHING matches nothing and
    // silently does nothing - every re-run appended the whole file again. The
    // partial index skips the rows the old importer left with a null id.
    await client.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_endgame_puzzles_puzzle_id
        ON endgame_puzzles(puzzle_id) WHERE puzzle_id IS NOT NULL;
      CREATE INDEX IF NOT EXISTS idx_endgame_puzzles_difficulty
        ON endgame_puzzles(difficulty);
      CREATE INDEX IF NOT EXISTS idx_endgame_puzzles_pick
        ON endgame_puzzles(endgame_type, mode, piece_count);
      -- What the picker asks for: a handful of material keys, one mode, maybe
      -- a rating band.
      CREATE INDEX IF NOT EXISTS idx_endgame_puzzles_material
        ON endgame_puzzles(material, mode);
    `);
    logger.info('Verified database table & indexes: endgame_puzzles');
    logger.info('Verified database table: user_puzzle_ratings');

    // Games, not positions. endgame_puzzles holds one board and one question;
    // this holds a game from where it first went wrong to the end of it, with
    // every mistake in between - which is a different exercise, walked rather
    // than solved, and needs the moves in order.
    //
    // blunders is JSONB rather than a child table because nothing ever queries
    // inside it: the walk reads the list whole, in order, and the only thing
    // worth filtering on is how many there are, which is its own column.
    await client.query(`
      CREATE TABLE IF NOT EXISTS blunder_games (
        id SERIAL PRIMARY KEY,
        game_id VARCHAR(64) UNIQUE NOT NULL,
        source_db VARCHAR(80),
        white VARCHAR(120),
        black VARCHAR(120),
        white_elo SMALLINT,
        black_elo SMALLINT,
        played_on VARCHAR(12),
        event VARCHAR(160),
        result VARCHAR(8),
        start_fen TEXT NOT NULL,
        moves TEXT[] NOT NULL DEFAULT '{}',
        blunders JSONB NOT NULL DEFAULT '[]',
        blunder_count SMALLINT NOT NULL DEFAULT 0,
        min_elo SMALLINT,
        materials VARCHAR(16)[] NOT NULL DEFAULT '{}',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_blunder_games_pick
        ON blunder_games(blunder_count, min_elo);
      CREATE INDEX IF NOT EXISTS idx_blunder_games_materials
        ON blunder_games USING GIN(materials);
    `);
    logger.info('Verified database table & indexes: blunder_games');

    // Create lichess_puzzles table.
    //
    // Kept separate from `puzzles` on purpose: the two have genuinely different
    // solution models. A row here stores the position *before* the opponent's
    // mistake, and `moves` is a UCI line whose first element is that mistake —
    // the puzzle starts after it, and the user's moves are the odd indices.
    // The existing `puzzles` table instead carries a solution tree verified by a
    // live engine. Merging them would force every consumer to branch anyway.
    //
    // Indexes match how the adaptive selector queries: a B-tree for the rating
    // band and a GIN index for theme containment.
    await client.query(`
      CREATE TABLE IF NOT EXISTS lichess_puzzles (
        puzzle_id VARCHAR(16) PRIMARY KEY,
        fen TEXT NOT NULL,
        moves TEXT NOT NULL,
        rating INTEGER NOT NULL,
        rating_deviation INTEGER,
        popularity INTEGER,
        nb_plays INTEGER,
        themes VARCHAR(40)[] NOT NULL DEFAULT '{}',
        game_url TEXT,
        opening_tags VARCHAR(120)[]
      );
      CREATE INDEX IF NOT EXISTS idx_lichess_puzzles_rating ON lichess_puzzles(rating);
      CREATE INDEX IF NOT EXISTS idx_lichess_puzzles_themes ON lichess_puzzles USING GIN(themes);
    `);
    logger.info('Verified database table & indexes: lichess_puzzles');

    // Create custom_puzzles table — positions a trainer brought in themselves,
    // by scanning their own book or typing a position from a lesson.
    //
    // `owner_id` is not bookkeeping, it is the rule. A position lifted out of a
    // book belongs to the trainer who owns that book: the selection and
    // arrangement of a published collection is the author's work even though a
    // single position is a fact, so these rows never join the shared puzzle
    // pool and are never served to anyone but their owner and the owner's
    // students. There is deliberately no endpoint that shares them further.
    //
    // `puzzle_id` is a public token rather than the serial id, so it can sit in
    // assignment_items.puzzle_id alongside Lichess ids without the two ranges
    // ever colliding.
    //
    // `needs_review` carries the scanner's own doubt forward. A position whose
    // printed solution would not play, or whose side to move nothing decided,
    // is still worth keeping — it is just not worth assigning to a child before
    // someone has looked at it.
    await client.query(`
      CREATE TABLE IF NOT EXISTS custom_puzzles (
        id SERIAL PRIMARY KEY,
        puzzle_id VARCHAR(64) UNIQUE NOT NULL,
        owner_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        fen TEXT NOT NULL,
        side_to_move CHAR(1) NOT NULL CHECK (side_to_move IN ('w', 'b')),
        solution_san VARCHAR(20),
        -- What the student is asked to do. A board with no task is not an
        -- exercise: until this existed a trainer could assign a position and the
        -- child saw pieces and nothing else. Derived where the position can say
        -- so itself (a verified mate in one), written by the trainer otherwise.
        instruction TEXT,
        themes VARCHAR(40)[] NOT NULL DEFAULT '{}',
        source_title VARCHAR(255),
        source_page INTEGER,
        source_label VARCHAR(16),
        needs_review BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_custom_puzzles_owner
        ON custom_puzzles(owner_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_custom_puzzles_themes
        ON custom_puzzles USING GIN(themes);
    `);
    await client.query(`
      ALTER TABLE custom_puzzles ADD COLUMN IF NOT EXISTS instruction TEXT;
    `);
    logger.info('Verified database table & indexes: custom_puzzles');

    // Create user_puzzle_attempts table.
    //
    // Two jobs: it keeps the selector from serving the same puzzle twice in a
    // row, and it is the per-attempt history a trainer's progress view will read
    // later. The aggregate in user_puzzle_ratings cannot answer "which motifs is
    // this student actually failing", because it only keeps the current number.
    await client.query(`
      CREATE TABLE IF NOT EXISTS user_puzzle_attempts (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        puzzle_id VARCHAR(64) NOT NULL,
        source VARCHAR(20) NOT NULL DEFAULT 'lichess',
        solved BOOLEAN NOT NULL,
        puzzle_rating INTEGER,
        rating_before INTEGER,
        rating_after INTEGER,
        themes VARCHAR(40)[] DEFAULT '{}',
        ms_taken INTEGER,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_attempts_user_created
        ON user_puzzle_attempts(user_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_attempts_user_puzzle
        ON user_puzzle_attempts(user_id, puzzle_id);
    `);
    logger.info('Verified database table & indexes: user_puzzle_attempts');

    // Create assignments table.
    //
    // A trainer assigns work to one student with a deadline. The puzzles are
    // resolved and stored at creation time rather than as a query re-run later:
    // a trainer needs to know exactly what they set, and "20 puzzles about pins"
    // evaluated twice would be two different sets.
    await client.query(`
      CREATE TABLE IF NOT EXISTS assignments (
        id SERIAL PRIMARY KEY,
        trainer_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        student_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        instructions TEXT,
        kind VARCHAR(20) NOT NULL DEFAULT 'puzzles' CHECK (kind IN ('puzzles', 'lesson')),
        lesson_id INTEGER REFERENCES saved_lessons(id) ON DELETE SET NULL,
        themes VARCHAR(40)[] DEFAULT '{}',
        min_rating INTEGER,
        max_rating INTEGER,
        due_at TIMESTAMPTZ,
        completed_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_assignments_student ON assignments(student_id, due_at);
      CREATE INDEX IF NOT EXISTS idx_assignments_trainer ON assignments(trainer_id, created_at DESC);
    `);
    logger.info('Verified database table & indexes: assignments');

    // Create assignment_items table — the assigned puzzles and their results.
    //
    // One row per puzzle carries both what was set and how it went, so progress
    // is a count over this table rather than a join against every attempt the
    // student has ever made.
    await client.query(`
      CREATE TABLE IF NOT EXISTS assignment_items (
        id SERIAL PRIMARY KEY,
        assignment_id INTEGER NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
        puzzle_id VARCHAR(64) NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        puzzle_rating INTEGER,
        solved BOOLEAN,
        ms_taken INTEGER,
        attempted_at TIMESTAMPTZ,
        UNIQUE (assignment_id, puzzle_id)
      );
      CREATE INDEX IF NOT EXISTS idx_assignment_items_assignment
        ON assignment_items(assignment_id, position);
      CREATE INDEX IF NOT EXISTS idx_assignment_items_pending
        ON assignment_items(puzzle_id) WHERE attempted_at IS NULL;
    `);

    // A lesson assignment's items are its steps, which have no puzzle id.
    // `position` already identifies the item within the assignment, so it serves
    // as the step index; the partial unique index keeps steps distinct without a
    // second column that would mean the same thing.
    await client.query(`
      ALTER TABLE assignment_items ALTER COLUMN puzzle_id DROP NOT NULL;
      CREATE UNIQUE INDEX IF NOT EXISTS idx_assignment_items_step
        ON assignment_items(assignment_id, position) WHERE puzzle_id IS NULL;
    `);

    // What the student tried, not only whether it was accepted.
    //
    // `solved` alone cannot be un-lost: a wrong answer that is one square off
    // and a wrong answer that ignores the position entirely look identical
    // afterwards, and the move is exactly what tells the trainer *why* it
    // failed.
    //
    // The two paths mean slightly different things by it, and both are honest.
    // A position the trainer set is answered once, so this is *the* move, and
    // the server computes it while judging. A Lichess puzzle refuses a wrong
    // move and lets the student try again, so it is the **first wrong** one —
    // what they thought before they found it.
    //
    // NULL therefore covers three cases, and the screen must not flatten them:
    // rows answered before this column existed, lesson steps (read rather than
    // solved), and a puzzle solved without a single wrong move.
    await client.query(`
      ALTER TABLE assignment_items
        ADD COLUMN IF NOT EXISTS played_san VARCHAR(20);
    `);
    logger.info('Verified database table & indexes: assignment_items (puzzle and lesson items)');

    // Create assignment_notes table — what the two of them say to each other
    // about one piece of homework.
    //
    // One table rather than four columns. The alternative was a trainer's note
    // on the assignment, a student's note on the assignment, a trainer's note
    // per position and a student's note per position — four places holding the
    // same kind of thing, and every reader joining all four.
    //
    // `item_id` NULL means the note is about the whole assignment; otherwise it
    // is about that one position. The author is read from the account, so who
    // said it is never written down twice and can never disagree with itself.
    //
    // Both cascades are deliberate. A withdrawn assignment takes its
    // conversation with it, and a deleted account takes the child's words with
    // it — this is text a child wrote, and it should not outlive them here.
    await client.query(`
      CREATE TABLE IF NOT EXISTS assignment_notes (
        id SERIAL PRIMARY KEY,
        assignment_id INTEGER NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
        item_id INTEGER REFERENCES assignment_items(id) ON DELETE CASCADE,
        author_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        body TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_assignment_notes_assignment
        ON assignment_notes(assignment_id, created_at);
    `);
    logger.info('Verified database table & indexes: assignment_notes (per assignment and per position)');

    // Create review_items table — the spaced-repetition schedule.
    //
    // Keyed on (user_id, lesson_id, position) rather than on the assignment: a
    // student's memory of one position is a property of the student, not of the
    // homework that happened to introduce it. Re-assigning the same lesson must
    // resume the existing schedule instead of resetting it to day one.
    await client.query(`
      CREATE TABLE IF NOT EXISTS review_items (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        lesson_id INTEGER NOT NULL REFERENCES saved_lessons(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        ease_factor NUMERIC(4, 2) NOT NULL DEFAULT 2.50,
        interval_days INTEGER NOT NULL DEFAULT 0,
        repetitions INTEGER NOT NULL DEFAULT 0,
        lapses INTEGER NOT NULL DEFAULT 0,
        due_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_reviewed_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (user_id, lesson_id, position)
      );
      CREATE INDEX IF NOT EXISTS idx_review_items_due
        ON review_items(user_id, due_at);
    `);
    logger.info('Verified database table & indexes: review_items');

    // Create student_reports table.
    //
    // The computed numbers are frozen into `snapshot` at generation time rather
    // than recalculated when the link is opened. A report is a statement about a
    // period — a parent who opens the same link next week must see the same
    // figures the trainer sent, not silently different ones.
    await client.query(`
      CREATE TABLE IF NOT EXISTS student_reports (
        id SERIAL PRIMARY KEY,
        trainer_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        student_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        period_days INTEGER NOT NULL,
        note TEXT,
        snapshot JSONB NOT NULL,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        expires_at TIMESTAMPTZ NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_student_reports_trainer
        ON student_reports(trainer_id, created_at DESC);
    `);
    logger.info('Verified database table & indexes: student_reports');

    // Create subscriptions table.
    // provider_ref is the payment provider's own identifier for the purchase
    // (a Play purchase token today, a Paddle subscription id later). The unique
    // constraint on (provider, provider_ref) is what makes purchase sync
    // idempotent — Google's Pub/Sub push redelivers on any non-200 response.
    // Timestamps are TIMESTAMPTZ because providers report period ends in
    // RFC 3339 with an offset, and dropping the zone silently shifts expiry.
    await client.query(`
      CREATE TABLE IF NOT EXISTS subscriptions (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        provider VARCHAR(30) NOT NULL,
        provider_ref VARCHAR(512) NOT NULL,
        product_id VARCHAR(100) NOT NULL,
        tier VARCHAR(50) NOT NULL,
        status VARCHAR(30) NOT NULL,
        current_period_end TIMESTAMPTZ,
        auto_renewing BOOLEAN DEFAULT TRUE,
        raw_payload JSONB,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (provider, provider_ref)
      );
      CREATE INDEX IF NOT EXISTS idx_subscriptions_user_status
        ON subscriptions(user_id, status);
    `);
    logger.info('Verified database table: subscriptions');

    // Create usage_counters table — monthly buckets for metered features.
    // period_start is the first day of the month in UTC; a row is created on
    // first use and never needs resetting, since the next month is a new key.
    await client.query(`
      CREATE TABLE IF NOT EXISTS usage_counters (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        metric VARCHAR(50) NOT NULL,
        period_start DATE NOT NULL,
        used INTEGER NOT NULL DEFAULT 0,
        updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (user_id, metric, period_start)
      );
    `);
    logger.info('Verified database table: usage_counters');


    // Create the repertoire tables — what a student has decided to play.
    //
    // Keyed on the **position**, not on a line of moves, and that is the whole
    // design in one word. A repertoire built from the Smith-Morra and one built
    // from 1.e4 c5 meet in the same positions; keyed by line they would be two
    // copies to keep in step, and the same position could carry two different
    // answers depending on which door the student came through. Keyed by
    // position, the deeper work simply *is* part of the shallower repertoire
    // the moment it is reached, and transpositions cost nothing.
    //
    // `fen_key` is the first four FEN fields — placement, side to move,
    // castling, en passant — so the same position reached at different move
    // numbers matches. The move counters are what would otherwise make two
    // identical boards look like two positions.
    //
    // `repertoires` is therefore a **name for a starting point**, not a
    // container: the moves belong to (user, colour).
    await client.query(`
      CREATE TABLE IF NOT EXISTS repertoires (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name VARCHAR(120) NOT NULL,
        color CHAR(1) NOT NULL CHECK (color IN ('w', 'b')),
        root_fen TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (user_id, name)
      );
      CREATE INDEX IF NOT EXISTS idx_repertoires_user
        ON repertoires(user_id, created_at DESC);
    `);
    logger.info('Verified database table & indexes: repertoires');

    // One row per move the student decided to play in a position.
    //
    // `role` is the second decision: one **primary** move per position, the
    // rest alternates. Three equal answers are fine for exploring and useless
    // for drilling — everything is correct, so nothing is ever learned to the
    // point of not having to think. The partial unique index below is that
    // rule, held by the database rather than by whoever writes the next query.
    await client.query(`
      CREATE TABLE IF NOT EXISTS repertoire_moves (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        color CHAR(1) NOT NULL CHECK (color IN ('w', 'b')),
        fen_key TEXT NOT NULL,
        uci VARCHAR(6) NOT NULL,
        san VARCHAR(12) NOT NULL,
        role VARCHAR(10) NOT NULL DEFAULT 'primary'
          CHECK (role IN ('primary', 'alternate')),
        verdict VARCHAR(12),
        added_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (user_id, color, fen_key, uci)
      );
      CREATE INDEX IF NOT EXISTS idx_repertoire_moves_node
        ON repertoire_moves(user_id, color, fen_key);
      CREATE UNIQUE INDEX IF NOT EXISTS idx_repertoire_moves_primary
        ON repertoire_moves(user_id, color, fen_key)
        WHERE role = 'primary';
    `);
    logger.info('Verified database table & indexes: repertoire_moves');

    // Every first attempt, including the ones that were thrown away.
    //
    // This is the most valuable thing the build mode produces, and it is the
    // part that would be easy to leave out: a repertoire records what the
    // student decided, but only this records *what they reached for first* and
    // what the judge said about it. Those positions are where the instinct is
    // wrong, and they are what the drill should ask about first. Without it,
    // "learning from your own mistakes" is an anecdote rather than a schedule.
    //
    // `looked_up` marks a position answered by opening the book instead of
    // thinking — the same reason the endgame trainer counts its hints.
    await client.query(`
      CREATE TABLE IF NOT EXISTS repertoire_attempts (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        color CHAR(1) NOT NULL CHECK (color IN ('w', 'b')),
        fen_key TEXT NOT NULL,
        uci VARCHAR(6) NOT NULL,
        san VARCHAR(12),
        verdict VARCHAR(12),
        kept BOOLEAN NOT NULL DEFAULT FALSE,
        looked_up BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_repertoire_attempts_node
        ON repertoire_attempts(user_id, color, fen_key, created_at DESC);
    `);
    logger.info('Verified database table & indexes: repertoire_attempts');


    // The drill's schedule over repertoire positions.
    //
    // A second table rather than a widened `review_items`, and the reason is
    // the same one that keeps `puzzles` and `lichess_puzzles` apart: the
    // algorithm is what must not be duplicated, and it is not - both go through
    // `schedule()` in spacedRepetitionService. The *storage* genuinely differs.
    // A lesson item is (lesson, step index) and is read by joining the lesson;
    // a repertoire item is (colour, position) and joins nothing. Widening the
    // homework table to carry both would have meant a nullable lesson_id, a
    // branch in every query that reads it, and a migration over a feature that
    // is already verified live - for no gain to the student.
    await client.query(`
      CREATE TABLE IF NOT EXISTS repertoire_reviews (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        color CHAR(1) NOT NULL CHECK (color IN ('w', 'b')),
        fen_key TEXT NOT NULL,
        ease_factor NUMERIC(4, 2) NOT NULL DEFAULT 2.50,
        interval_days INTEGER NOT NULL DEFAULT 0,
        repetitions INTEGER NOT NULL DEFAULT 0,
        lapses INTEGER NOT NULL DEFAULT 0,
        due_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_reviewed_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (user_id, color, fen_key)
      );
      CREATE INDEX IF NOT EXISTS idx_repertoire_reviews_due
        ON repertoire_reviews(user_id, color, due_at);
    `);
    logger.info('Verified database table & indexes: repertoire_reviews');

    // What the opponent actually plays in a position, kept from the lookup the
    // build mode already paid for.
    //
    // Not a convenience - it is what lets the drill run without spending a
    // single Lichess request. The rows are about a position and a rating band,
    // never about a person, so one student's building makes the next student's
    // drill free too.
    //
    // More moves are kept than the build mode covers. The uncovered ones are
    // the point: a drill that only ever plays the four prepared answers teaches
    // a repertoire that has never been surprised, and being surprised is the
    // whole reason to know what falls outside.
    await client.query(`
      CREATE TABLE IF NOT EXISTS opening_replies (
        id SERIAL PRIMARY KEY,
        fen_key TEXT NOT NULL,
        min_rating INTEGER NOT NULL DEFAULT 0,
        uci VARCHAR(6) NOT NULL,
        san VARCHAR(12) NOT NULL,
        games INTEGER NOT NULL DEFAULT 0,
        share NUMERIC(6, 5) NOT NULL DEFAULT 0,
        covered BOOLEAN NOT NULL DEFAULT FALSE,
        fetched_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (fen_key, min_rating, uci)
      );
      CREATE INDEX IF NOT EXISTS idx_opening_replies_node
        ON opening_replies(fen_key, min_rating);
    `);
    logger.info('Verified database table & indexes: opening_replies');


    // Groups of students, so a trainer with forty of them does not go hunting
    // down a list to invite the same eight people every Tuesday.
    //
    // A group belongs to a trainer and holds nothing but names; who may
    // actually be in it is decided elsewhere, by the accepted relationship —
    // membership here is a convenience, never a right.
    await client.query(`
      CREATE TABLE IF NOT EXISTS student_groups (
        id SERIAL PRIMARY KEY,
        trainer_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name VARCHAR(120) NOT NULL,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (trainer_id, name)
      );
      CREATE TABLE IF NOT EXISTS student_group_members (
        group_id INTEGER NOT NULL REFERENCES student_groups(id) ON DELETE CASCADE,
        student_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        added_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (group_id, student_id)
      );
      CREATE INDEX IF NOT EXISTS idx_student_groups_trainer
        ON student_groups(trainer_id);
    `);
    logger.info('Verified database tables: student_groups, student_group_members');

    // The room's guest list: whole groups, single people, or both.
    //
    // Empty means what it has always meant — every accepted student of the
    // creator may come. The moment one row exists the room narrows to it, which
    // is the point of inviting a group: *these* eight, and nobody else.
    //
    // Exactly one of user_id and group_id is set. A row that is both, or
    // neither, is a row nobody can read the same way twice.
    await client.query(`
      CREATE TABLE IF NOT EXISTS room_guests (
        id SERIAL PRIMARY KEY,
        room_code VARCHAR(6) NOT NULL REFERENCES rooms(room_code) ON DELETE CASCADE,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        group_id INTEGER REFERENCES student_groups(id) ON DELETE CASCADE,
        added_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT room_guests_one_target
          CHECK ((user_id IS NULL) <> (group_id IS NULL))
      );
      CREATE UNIQUE INDEX IF NOT EXISTS idx_room_guests_user
        ON room_guests(room_code, user_id) WHERE user_id IS NOT NULL;
      CREATE UNIQUE INDEX IF NOT EXISTS idx_room_guests_group
        ON room_guests(room_code, group_id) WHERE group_id IS NOT NULL;
    `);
    logger.info('Verified database table & indexes: room_guests');

  } catch (err) {
    logger.error('Database migration/connection error:', err);
    throw err;
  } finally {
    client.release();
  }
}

module.exports = {
  pool,
  initDB,
  initializeDatabase: initDB,
  buildSslConfig
};
