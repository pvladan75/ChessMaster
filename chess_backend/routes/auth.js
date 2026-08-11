const logger = require('../services/logger');
const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');
const { pool } = require('../db');
const { JWT_SECRET } = require('../middleware/auth');
const mailService = require('../services/mailService');

// Credential endpoints are the prime target for brute force and enumeration,
// so they get a tighter budget than the rest of the API.
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Previše pokušaja. Pokušajte ponovo za 15 minuta.' },
});

router.use(['/register', '/login', '/verify-email', '/auth/verify-email', '/google', '/auth/google'], authLimiter);

function generateVerificationCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

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
        const verificationCode = generateVerificationCode();
        await pool.query('UPDATE users SET verification_code = $1 WHERE email = $2', [verificationCode, email]);

        try {
          await mailService.sendVerificationCode(email, verificationCode, existing.name);
        } catch (mailErr) {
          logger.error(`Failed to send verification code to ${email}: ${mailErr.message}`);
          return res.status(500).json({ error: 'Nije moguće poslati verifikacioni kod. Kontaktirajte podršku.' });
        }

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
    const verificationCode = generateVerificationCode();

    const insertResult = await pool.query(
      'INSERT INTO users (email, password_hash, name, role, is_verified, verification_code) VALUES ($1, $2, $3, $4, FALSE, $5) RETURNING id, email, name, role, is_verified',
      [email, passwordHash, name, assignedRole, verificationCode]
    );

    try {
      await mailService.sendVerificationCode(email, verificationCode, name);
    } catch (mailErr) {
      // Roll the registration back so the address stays free for a retry.
      await pool.query('DELETE FROM users WHERE id = $1', [insertResult.rows[0].id]);
      logger.error(`Failed to send verification code to ${email}: ${mailErr.message}`);
      return res.status(500).json({ error: 'Nije moguće poslati verifikacioni kod. Kontaktirajte podršku.' });
    }

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

/// Verifies a Google ID token and returns its verified claims.
/// Throws when the token is absent, unverifiable, issued to another app, or unverified.
async function verifyGoogleIdToken(idToken) {
  if (!idToken || idToken.trim() === '') {
    throw new Error('Google ID token je obavezan.');
  }

  const verifyUrl = `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`;
  let payload;
  try {
    const response = await fetch(verifyUrl);
    if (!response.ok) {
      throw new Error(`tokeninfo responded ${response.status}`);
    }
    payload = await response.json();
  } catch (e) {
    throw new Error(`Google nije potvrdio identitet (${e.message}).`);
  }

  // The audience must be this application, otherwise a token minted for any other
  // Google app would be accepted here.
  const expectedAudiences = (process.env.GOOGLE_CLIENT_IDS || process.env.GOOGLE_CLIENT_ID || '')
    .split(',')
    .map((id) => id.trim())
    .filter(Boolean);

  if (expectedAudiences.length === 0) {
    throw new Error('GOOGLE_CLIENT_IDS nije konfigurisan na serveru.');
  }
  if (!expectedAudiences.includes(payload.aud)) {
    throw new Error('Google token nije izdat za ovu aplikaciju.');
  }

  const issuerOk = payload.iss === 'accounts.google.com' || payload.iss === 'https://accounts.google.com';
  if (!issuerOk) {
    throw new Error('Neispravan izdavalac Google tokena.');
  }
  if (!payload.email) {
    throw new Error('Google token ne sadrži email adresu.');
  }
  if (payload.email_verified !== true && payload.email_verified !== 'true') {
    throw new Error('Google email adresa nije verifikovana.');
  }

  return { email: payload.email, name: payload.name };
}

// POST /google and /auth/google
router.post(['/google', '/auth/google'], async (req, res) => {
  try {
    // The request body is never trusted for identity — only the verified token is.
    // Previously a missing or invalid idToken fell back to req.body.email, which let
    // anyone mint a session for any account by posting that account's address.
    let verified;
    try {
      verified = await verifyGoogleIdToken(req.body.idToken);
    } catch (verifyErr) {
      logger.warn(`[GOOGLE_AUTH] Rejected sign-in: ${verifyErr.message}`);
      return res.status(401).json({ error: 'Google prijava nije uspela: ' + verifyErr.message });
    }

    const email = verified.email;
    const name = verified.name;

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
