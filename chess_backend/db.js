require('dotenv').config();
const { Pool } = require('pg');
const logger = require('./services/logger');

const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_DATABASE,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false
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
    await client.query(`
      CREATE TABLE IF NOT EXISTS saved_lessons (
        id SERIAL PRIMARY KEY,
        trainer_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        tags VARCHAR(255)[],
        fen VARCHAR(255) NOT NULL,
        pgn TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Create trainer_students table
    await client.query(`
      CREATE TABLE IF NOT EXISTS trainer_students (
        id SERIAL PRIMARY KEY,
        trainer_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        student_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        UNIQUE(trainer_id, student_id)
      );
    `);
    logger.info('Verified database table: trainer_students');
    
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
    logger.info('Verified database table: user_notifications');

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
  initializeDatabase: initDB
};
