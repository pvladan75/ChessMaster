require('dotenv').config();
const { Pool } = require('pg');

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
    console.log('Successfully connected to DigitalOcean PostgreSQL database.');

    // Create users table
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        name VARCHAR(255) NOT NULL,
        role VARCHAR(50) NOT NULL DEFAULT 'user'
      );
      ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
      ALTER TABLE users DROP CONSTRAINT IF EXISTS user_role_check;
      ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('user', 'trener', 'ucenik', 'unassigned', 'admin'));
    `);
    console.log('Verified database table: users');

    // Create rooms table
    await client.query(`
      CREATE TABLE IF NOT EXISTS rooms (
        id SERIAL PRIMARY KEY,
        room_code VARCHAR(6) UNIQUE NOT NULL,
        creator_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        current_fen VARCHAR(255) DEFAULT 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'archived')),
        board_control VARCHAR(50) DEFAULT 'trainer_only' CHECK (board_control IN ('trainer_only', 'student_white', 'student_black', 'student_both')),
        allow_student_engine BOOLEAN DEFAULT FALSE
      );
    `);
    
    // Add column if table already exists
    await client.query(`
      ALTER TABLE rooms 
      ADD COLUMN IF NOT EXISTS board_control VARCHAR(50) DEFAULT 'trainer_only' 
      CHECK (board_control IN ('trainer_only', 'student_white', 'student_black', 'student_both'));
    `);
    await client.query(`
      ALTER TABLE rooms 
      ADD COLUMN IF NOT EXISTS allow_student_engine BOOLEAN DEFAULT FALSE;
    `);
    console.log('Verified database table: rooms (with board_control & allow_student_engine)');

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
    console.log('Verified database table: trainer_students');
    
    // Add account_type column to users table if missing
    await client.query(`
      ALTER TABLE users 
      ADD COLUMN IF NOT EXISTS account_type VARCHAR(50) DEFAULT 'free';
    `);
    console.log('Verified database table: users (with account_type)');

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
    console.log('Verified database table: session_recordings');

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
    console.log('Verified database table: friends');

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
    console.log('Verified database table: user_notifications');

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
    console.log('Verified database table: scheduled_sessions');

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
    console.log('Verified database table: scheduled_session_invites');

    // Create puzzles table matching Lichess CSV schema
    await client.query(`
      CREATE TABLE IF NOT EXISTS puzzles (
        puzzle_id VARCHAR(50) PRIMARY KEY,
        fen TEXT NOT NULL,
        moves TEXT NOT NULL,
        rating INT NOT NULL DEFAULT 1500,
        rating_deviation INT DEFAULT 100,
        popularity INT DEFAULT 100,
        nb_plays INT DEFAULT 0,
        themes TEXT[] DEFAULT '{}',
        game_url TEXT,
        opening_tags TEXT
      );
      CREATE INDEX IF NOT EXISTS idx_puzzles_rating ON puzzles(rating);
      CREATE INDEX IF NOT EXISTS idx_puzzles_themes ON puzzles USING GIN(themes);
    `);
    console.log('Verified database table & GIN/B-tree indexes: puzzles');

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
    console.log('Verified database table & indexes: endgame_puzzles');
    console.log('Verified database table: user_puzzle_ratings');

  } catch (err) {
    console.error('Database migration/connection error:', err);
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
