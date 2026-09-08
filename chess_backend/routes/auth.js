const logger = require('../services/logger');
const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');
const { pool } = require('../db');
const { JWT_SECRET, authenticateToken } = require('../middleware/auth');
const mailService = require('../services/mailService');
const { GOOGLE_PLACEHOLDER_HASH, isPasswordlessHash } = require('../services/googleAccount');
const { OUTCOME, verificationOutcome } = require('../services/emailVerification');

// Credential endpoints are the prime target for brute force and enumeration,
// so they get a tighter budget than the rest of the API.
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many attempts. Please try again in 15 minutes.' },
});

router.use(['/register', '/login', '/verify-email', '/auth/verify-email', '/google', '/auth/google'], authLimiter);

function generateVerificationCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// POST /register
router.post('/register', async (req, res) => {
  const { email, password, name } = req.body;

  if (!email || !password || !name) {
    return res.status(400).json({ error: 'All fields (email, password, name) are required.' });
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
          return res.status(500).json({ error: 'Failed to send verification code. Please contact support.' });
        }

        return res.status(200).json({
          requiresVerification: true,
          email,
          message: 'Email already exists but is not verified. A new verification code has been sent.'
        });
      }
      return res.status(400).json({ error: 'A user with this email address already exists.' });
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
      return res.status(500).json({ error: 'Failed to send verification code. Please contact support.' });
    }

    res.status(201).json({
      requiresVerification: true,
      email,
      message: 'Registration successful. Enter the verification code.'
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
    return res.status(400).json({ error: 'Email and verification code are required.' });
  }

  try {
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'User with this email was not found.' });
    }

    const user = result.rows[0];

    const outcome = verificationOutcome({
      isVerified: user.is_verified,
      storedCode: user.verification_code,
      providedCode: code,
    });

    // An already-verified account gets an answer, never a session. This branch
    // used to sign a token here without looking at the code at all, so anybody
    // who knew a registered address could take that account over. See
    // `services/emailVerification.js` for the whole reasoning.
    if (outcome === OUTCOME.ALREADY_VERIFIED) {
      logger.warn({ email }, 'Verification attempted on an already-verified account');
      return res.status(400).json({
        error: 'This account is already verified. Sign in with your password or Google.',
        alreadyVerified: true,
      });
    }

    if (outcome !== OUTCOME.OK) {
      return res.status(400).json({ error: 'Invalid verification code.' });
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

    // An account made through Google has no password at all, and bcrypt.compare
    // against its marker returns false for every input — so without this the
    // user is told they typed the wrong password, forever, and there is no
    // password that would work.
    //
    // This does confirm that an account exists for the address, which the reply
    // above deliberately does not. Accepted knowingly: the same fact already
    // leaks from /students/trainers/request, the endpoint is rate limited to 20
    // attempts per 15 minutes, and the alternative is an unreachable account.
    if (isPasswordlessHash(user.password_hash)) {
      return res.status(400).json({
        error: 'This account uses Google sign-in and has no password.',
        usesGoogle: true,
        email: user.email,
      });
    }

    const validPassword = await bcrypt.compare(password, user.password_hash);
    if (!validPassword) {
      return res.status(400).json({ error: 'Invalid email or password' });
    }

    if (user.is_verified === false) {
      return res.status(400).json({
        error: 'Email is not verified',
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
    throw new Error('Google ID token is required.');
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
    throw new Error(`Google could not verify identity (${e.message}).`);
  }

  // The audience must be this application, otherwise a token minted for any other
  // Google app would be accepted here.
  const expectedAudiences = (process.env.GOOGLE_CLIENT_IDS || process.env.GOOGLE_CLIENT_ID || '')
    .split(',')
    .map((id) => id.trim())
    .filter(Boolean);

  if (expectedAudiences.length === 0) {
    throw new Error('GOOGLE_CLIENT_IDS is not configured on the server.');
  }
  if (!expectedAudiences.includes(payload.aud)) {
    throw new Error('Google token was not issued for this application.');
  }

  const issuerOk = payload.iss === 'accounts.google.com' || payload.iss === 'https://accounts.google.com';
  if (!issuerOk) {
    throw new Error('Invalid Google token issuer.');
  }
  if (!payload.email) {
    throw new Error('Google token does not contain an email address.');
  }
  if (payload.email_verified !== true && payload.email_verified !== 'true') {
    throw new Error('Google email address is not verified.');
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
      return res.status(401).json({ error: 'Google sign-in failed: ' + verifyErr.message });
    }

    const email = verified.email;
    const name = verified.name;

    let userResult = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    let user;

    if (userResult.rows.length === 0) {
      const defaultPasswordHash = GOOGLE_PLACEHOLDER_HASH;
      const insertResult = await pool.query(
        'INSERT INTO users (email, password_hash, name, role, is_verified) VALUES ($1, $2, $3, $4, TRUE) RETURNING id, email, name, role',
        [email, defaultPasswordHash, name || 'User', 'korisnik']
      );
      user = insertResult.rows[0];
      logger.info('[GOOGLE_AUTH] Created new Google user:', user.email);
    } else {
      user = userResult.rows[0];

      // Signing in with Google adopts the account that already holds this
      // address, which is the behaviour that keeps one person from ending up
      // with two accounts — and here two accounts would silently split a
      // trainer's lessons from their student's.
      //
      // With one exception. If that account was **never verified**, nobody ever
      // proved they owned the address: anyone can register any address, and the
      // code that would prove it was never entered. Adopting such an account as
      // is would leave whoever created it holding a working password to the
      // account of the person who actually owns the address. So the password
      // goes, and the account becomes a Google account.
      if (!user.is_verified) {
        logger.warn(
          { email: user.email },
          '[GOOGLE_AUTH] Adopting an unverified account: password cleared, nobody had proven this address'
        );
        await pool.query(
          `UPDATE users
              SET is_verified = TRUE, verification_code = NULL, password_hash = $2
            WHERE id = $1`,
          [user.id, GOOGLE_PLACEHOLDER_HASH]
        );
      } else {
        await pool.query(
          'UPDATE users SET verification_code = NULL WHERE id = $1',
          [user.id]
        );
      }
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
    res.status(500).json({ error: 'Server error during Google sign-in: ' + (err.message || err.toString()) });
  }
});

// GET /session/check — is the server there, and does this token still mean
// anything?
//
// A remembered login is restored from the phone's own storage, so the app can
// greet someone by name while the backend is switched off or their token
// expired days ago. Both look exactly like being signed in, which is how a
// trainer ends up wondering why nothing saves.
//
// Deliberately does no database work: it answers reachability and token
// validity and nothing else, so it stays cheap enough to call on every start.
router.get('/session/check', authenticateToken, (req, res) => {
  res.json({
    ok: true,
    id: req.user.id,
    name: req.user.name,
    role: req.user.role,
  });
});

module.exports = router;
