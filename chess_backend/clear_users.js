// clear_users.js - Database User Cleanup Script
require('dotenv').config();
const { pool } = require('./db');

async function clearAllUsers() {
  console.log('Započinjem brisanje svih korisničkih naloga i povezanih podataka...');
  const client = await pool.connect();
  try {
    const result = await client.query('TRUNCATE users RESTART IDENTITY CASCADE;');
    console.log('Uspešno obrisani svi nalozi iz tabele `users` i kaskadno obrisane sve povezane lekcije, sesije i snimci!');
  } catch (err) {
    console.error('Greška pri brisanju naloga:', err);
  } finally {
    client.release();
    await pool.end();
  }
}

clearAllUsers();
