const logger = require('../services/logger');
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
      const existing = userCheck.rows[0];
      if (!existing.is_verified) {
        // Generate new verification code for unverified existing registration
        const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
        await pool.query('UPDATE users SET verification_code = $1 WHERE email = $2', [verificationCode, email]);
        logger.info({ code: verificationCode, email }, 'Verification code re-generated');
        return res.status(200).json({
          requiresVerification: true,
          email,
          message: 'Email već postoji ali nije verifikovan. Nov verifikacioni kod je poslat.'
        });
      }
      return res.status(400).json({ error: 'Korisnik sa ovom email adresom već postoji.' });
    }

    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(password, saltRounds);
    const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();

    await pool.query(
      'INSERT INTO users (email, password_hash, name, role, is_verified, verification_code) VALUES ($1, $2, $3, $4, FALSE, $5) RETURNING id, email, name, role, is_verified',
      [email, passwordHash, name, assignedRole, verificationCode]
    );

    logger.info({ code: verificationCode, email }, 'Verification code generated');

    res.status(201).json({
      requiresVerification: true,
      email,
      message: 'Registracija uspešna. Unesite verifikacioni kod.'
    });
  } catch (err) {
    logger.error('Registration error:', err);
    res.status(500).json({ error: 'Server error during registration' });
  }
});

// POST /verify-email & /auth/verify-email
router.post(['/verify-email', '/auth/verify-email'], async (req, res) => {
  const { email, code } = req.body;

  if (!email || !code) {
    return res.status(400).json({ error: 'Email i verifikacioni kod su obavezni.' });
  }

  try {
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'Korisnik sa datim emailom nije pronađen.' });
    }

    const user = result.rows[0];

    if (user.is_verified) {
      const token = jwt.sign(
        { id: user.id, email: user.email, name: user.name, role: user.role },
        JWT_SECRET,
        { expiresIn: '7d' }
      );
      return res.json({
        token,
        user: { id: user.id, email: user.email, name: user.name, role: user.role }
      });
    }

    if (!user.verification_code || user.verification_code.toString().trim() !== code.toString().trim()) {
      return res.status(400).json({ error: 'Netačan verifikacioni kod.' });
    }

    const updateResult = await pool.query(
      'UPDATE users SET is_verified = TRUE, verification_code = NULL WHERE id = $1 RETURNING id, email, name, role',
      [user.id]
    );
    const verifiedUser = updateResult.rows[0];

    const token = jwt.sign(
      { id: verifiedUser.id, email: verifiedUser.email, name: verifiedUser.name, role: verifiedUser.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    logger.info({ email: verifiedUser.email }, 'User email successfully verified');

    res.json({
      token,
      user: {
        id: verifiedUser.id,
        email: verifiedUser.email,
        name: verifiedUser.name,
        role: verifiedUser.role
      }
    });
  } catch (err) {
    logger.error('Verification error:', err);
    res.status(500).json({ error: 'Server error during verification' });
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

    if (user.is_verified === false) {
      return res.status(400).json({
        error: 'Email nije verifikovan',
        requiresVerification: true,
        email: user.email
      });
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
    logger.error('Login error:', err);
    res.status(500).json({ error: 'Server error during login' });
  }
});

// POST /google and /auth/google
router.post(['/google', '/auth/google'], async (req, res) => {
  try {
    logger.info('[GOOGLE_AUTH] Incoming login request:', req.body);
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
        logger.info('[GOOGLE_AUTH] Google ID token verification fallback:', e.message);
      }
    }

    if (!email) {
      logger.warn('[GOOGLE_AUTH] No email resolved from token or request body.');
      return res.status(400).json({ error: 'Nije moguće verifikovati Google nalog (nedostaje email).' });
    }

    let userResult = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    let user;

    if (userResult.rows.length === 0) {
      const defaultPasswordHash = 'google_oauth_placeholder_hash';
      const insertResult = await pool.query(
        'INSERT INTO users (email, password_hash, name, role, is_verified) VALUES ($1, $2, $3, $4, TRUE) RETURNING id, email, name, role',
        [email, defaultPasswordHash, name || 'Korisnik', 'korisnik']
      );
      user = insertResult.rows[0];
      logger.info('[GOOGLE_AUTH] Created new Google user:', user.email);
    } else {
      user = userResult.rows[0];
      await pool.query('UPDATE users SET is_verified = TRUE WHERE id = $1', [user.id]);
      logger.info('[GOOGLE_AUTH] Found existing Google user:', user.email);
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
    logger.error('[GOOGLE_AUTH_ERROR]', err);
    res.status(500).json({ error: 'Greška na serveru prilikom Google prijave: ' + (err.message || err.toString()) });
  }
});

module.exports = router;
