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
        role VARCHAR(50) NOT NULL CHECK (role IN ('trener', 'ucenik'))
      );
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
        board_control VARCHAR(50) DEFAULT 'trainer_only' CHECK (board_control IN ('trainer_only', 'student_white', 'student_black', 'student_both'))
      );
    `);
    
    // Add column if table already exists
    await client.query(`
      ALTER TABLE rooms 
      ADD COLUMN IF NOT EXISTS board_control VARCHAR(50) DEFAULT 'trainer_only' 
      CHECK (board_control IN ('trainer_only', 'student_white', 'student_black', 'student_both'));
    `);
    console.log('Verified database table: rooms (with board_control)');

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
    
    // Add columns if table already exists
    await client.query(`
      ALTER TABLE saved_lessons 
      ADD COLUMN IF NOT EXISTS description TEXT,
      ADD COLUMN IF NOT EXISTS tags VARCHAR(255)[];
    `);
    console.log('Verified database table: saved_lessons (with description and tags)');

  } catch (err) {
    console.error('Database migration/connection error:', err);
    throw err;
  } finally {
    client.release();
  }
}

module.exports = {
  pool,
  initDB
};
