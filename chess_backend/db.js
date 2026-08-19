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
    logger.info('Verified database table: trainer_students (with consent columns)');
    
    // Add account_type column to users table if missing
    await client.query(`
      ALTER TABLE users 
      ADD COLUMN IF NOT EXISTS account_type VARCHAR(50) DEFAULT 'free';
    `);
    logger.info('Verified database table: users (with account_type)');

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

    // Create endgame_puzzles table
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
      CREATE INDEX IF NOT EXISTS idx_endgame_puzzles_difficulty ON endgame_puzzles(difficulty);
    `);
    logger.info('Verified database table & indexes: endgame_puzzles');
    logger.info('Verified database table: user_puzzle_ratings');

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
    logger.info('Verified database table & indexes: assignment_items (puzzle and lesson items)');

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
