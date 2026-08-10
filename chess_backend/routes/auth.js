const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { pool } = require('../db');
const { JWT_SECRET } = require('../middleware/auth');

// POST /register
router.post('/register', async (req, res) => {
  const { email, password, name } = req.body;

  if (!email || !password || !name) {
    return res.status(400).json({ error: 'Sva polja (email, lozinka, ime) su obavezna.' });
  }

  const assignedRole = 'korisnik';

  try {
    const userCheck = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (userCheck.rows.length > 0) {
      return res.status(400).json({ error: 'Korisnik sa ovom email adresom već postoji.' });
    }

    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    const result = await pool.query(
      'INSERT INTO users (email, password_hash, name, role) VALUES ($1, $2, $3, $4) RETURNING id, email, name, role',
      [email, passwordHash, name, assignedRole]
    );

    const user = result.rows[0];

    const token = jwt.sign(
      { id: user.id, email: user.email, name: user.name, role: user.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(201).json({ token, user });
  } catch (err) {
    console.error('Registration error:', err);
    res.status(500).json({ error: 'Server error during registration' });
  }
});

// POST /login
router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  try {
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'Invalid email or password' });
    }

    const user = result.rows[0];

    const validPassword = await bcrypt.compare(password, user.password_hash);
    if (!validPassword) {
      return res.status(400).json({ error: 'Invalid email or password' });
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, name: user.name, role: user.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role
      }
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Server error during login' });
  }
});

// POST /google and /auth/google
router.post(['/google', '/auth/google'], async (req, res) => {
  try {
    console.log('[GOOGLE_AUTH] Incoming login request:', req.body);
    const { idToken, accessToken, email: reqEmail, name: reqName } = req.body;

    let email = reqEmail;
    let name = reqName;

    if (idToken) {
      try {
        const verifyUrl = `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`;
        const response = await fetch(verifyUrl);
        if (response.ok) {
          const payload = await response.json();
          if (payload.email) email = payload.email;
          if (payload.name) name = payload.name;
        }
      } catch (e) {
        console.log('[GOOGLE_AUTH] Google ID token verification fallback:', e.message);
      }
    }

    if (!email) {
      console.warn('[GOOGLE_AUTH] No email resolved from token or request body.');
      return res.status(400).json({ error: 'Nije moguće verifikovati Google nalog (nedostaje email).' });
    }

    let userResult = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    let user;

    if (userResult.rows.length === 0) {
      const defaultPasswordHash = 'google_oauth_placeholder_hash';
      const insertResult = await pool.query(
        'INSERT INTO users (email, password_hash, name, role) VALUES ($1, $2, $3, $4) RETURNING id, email, name, role',
        [email, defaultPasswordHash, name || 'Korisnik', 'korisnik']
      );
      user = insertResult.rows[0];
      console.log('[GOOGLE_AUTH] Created new Google user:', user.email);
    } else {
      user = userResult.rows[0];
      console.log('[GOOGLE_AUTH] Found existing Google user:', user.email);
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, name: user.name, role: user.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role
      }
    });
  } catch (err) {
    console.error('[GOOGLE_AUTH_ERROR]', err);
    res.status(500).json({ error: 'Greška na serveru prilikom Google prijave: ' + (err.message || err.toString()) });
  }
});

module.exports = router;
