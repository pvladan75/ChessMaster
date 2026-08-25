require('dotenv').config();
const logger = require('../services/logger');
const jwt = require('jsonwebtoken');
const { pool } = require('../db');
const { tokenHolderStanding } = require('../services/accountGuard');

const JWT_SECRET = process.env.JWT_SECRET;

// Fail fast: a predictable fallback secret lets anyone mint valid tokens.
if (!JWT_SECRET || JWT_SECRET.trim() === '' || JWT_SECRET === 'your_jwt_secret_key_here') {
  logger.error(
    'FATAL: JWT_SECRET is not configured. Generate one with: ' +
    'node -e "console.log(require(\'crypto\').randomBytes(32).toString(\'hex\'))"'
  );
  process.exit(1);
}

if (JWT_SECRET.length < 32) {
  logger.warn(`JWT_SECRET is only ${JWT_SECRET.length} characters. Use at least 32 for adequate entropy.`);
}

function extractBearer(req) {
  const authHeader = req.headers['authorization'];
  return authHeader && authHeader.split(' ')[1];
}

/// Verifies the slip, and then that the account it names is still there.
///
/// The second half is not a formality. `jwt.verify` proves this server issued
/// the token and that it has not expired — nothing more. Until 25.8.2026 that
/// was the whole check, so a deleted account kept a working login for the rest
/// of its token's seven days, and after a `RESTART IDENTITY` the same slip
/// became a valid credential for whoever inherited the id.
async function authenticateToken(req, res, next) {
  const token = extractBearer(req);

  if (!token) {
    return res.status(401).json({ error: 'Access token is required' });
  }

  let user;
  try {
    user = jwt.verify(token, JWT_SECRET);
  } catch {
    return res.status(403).json({ error: 'Invalid or expired token' });
  }
  if (user.purpose) {
    // Scoped tokens (e.g. download links) must never authenticate the API surface.
    return res.status(403).json({ error: 'Invalid or expired token' });
  }

  const standing = await tokenHolderStanding(pool, user.id);
  if (!standing.ok) {
    if (standing.cause) {
      logger.error('[AUTH] Nalog nije mogao da se proveri:', standing.cause);
    } else {
      logger.warn(`[AUTH] Odbijen token: ${standing.reason} (id ${user.id})`);
    }
    return res.status(standing.status)
      .json({ error: standing.error, reason: standing.reason });
  }

  // The role comes from the row, not from the slip. A token carries the role
  // it was signed with, so revoking admin used to take effect a week later.
  req.user = { ...user, role: standing.role };
  next();
}

/// Attaches req.user when a valid token is present, but allows guest traffic through.
/// Used by endpoints the guest-first flow relies on.
/// The same two questions, on a road where "nobody" is a legal answer.
///
/// Anything short of a present account becomes a guest — including a database
/// that will not answer. That is the safe direction here and only here: this
/// middleware grants nothing by itself, and every route behind it checks its
/// own rights against the same database, which is failing too.
async function optionalAuth(req, res, next) {
  const token = extractBearer(req);
  if (!token) {
    req.user = null;
    return next();
  }

  let user;
  try {
    user = jwt.verify(token, JWT_SECRET);
  } catch {
    req.user = null;
    return next();
  }
  if (user.purpose) {
    req.user = null;
    return next();
  }

  const standing = await tokenHolderStanding(pool, user.id);
  if (!standing.ok && standing.cause) {
    logger.error('[AUTH] Nalog nije mogao da se proveri:', standing.cause);
  }
  req.user = standing.ok ? user : null;
  next();
}

function requireRole(role) {
  return (req, res, next) => {
    if (!req.user || req.user.role !== role) {
      return res.status(403).json({ error: `Access denied. Role '${role}' required.` });
    }
    next();
  };
}

/// Mints a short-lived token bound to a single file, so an MP4 download link can be
/// opened by the system browser (which cannot send an Authorization header).
function signDownloadToken(userId, filename) {
  return jwt.sign(
    { purpose: 'download', file: filename, id: userId },
    JWT_SECRET,
    { expiresIn: '30m' }
  );
}

/// Mints a token for one parent report.
///
/// The link goes to a parent who has no account, so the token *is* the
/// credential. It is therefore bound to a single report id and expires, which
/// caps how long a child's record stays reachable by anyone holding the link.
function signReportToken(reportId, days) {
  return jwt.sign(
    { purpose: 'report', report: reportId },
    JWT_SECRET,
    { expiresIn: `${days}d` }
  );
}

/// Verifies a report token supplied as ?token=... against the report being asked
/// for, so one report's link cannot be used to read another.
function authenticateReportToken(req, res, next) {
  const token = req.query.token;
  if (!token) {
    return res.status(401).json({ error: 'Link nije potpun.' });
  }

  jwt.verify(token, JWT_SECRET, (err, payload) => {
    if (err || payload.purpose !== 'report') {
      return res.status(403).json({ error: 'Link je istekao ili nije ispravan.' });
    }
    if (String(payload.report) !== String(req.params.id)) {
      return res.status(403).json({ error: 'Link ne odgovara traženom izveštaju.' });
    }
    req.reportToken = payload;
    next();
  });
}

/// Verifies a download token supplied as ?token=... and confirms it was issued
/// for exactly the file being requested.
function authenticateDownloadToken(req, res, next) {
  const token = req.query.token;
  if (!token) {
    return res.status(401).json({ error: 'Download token is required' });
  }

  jwt.verify(token, JWT_SECRET, (err, payload) => {
    if (err || payload.purpose !== 'download') {
      return res.status(403).json({ error: 'Invalid or expired download token' });
    }
    if (payload.file !== req.params.filename) {
      return res.status(403).json({ error: 'Download token does not match the requested file' });
    }
    req.downloadUser = payload;
    next();
  });
}

/// Verifies a Socket.IO handshake token. Returns the decoded user, or null for guests.
/// Throws only when a token was supplied but is invalid, so bad tokens are rejected
/// rather than silently downgraded to guest access.
function verifySocketToken(token) {
  if (!token || token.trim() === '') {
    return null;
  }
  const payload = jwt.verify(token, JWT_SECRET);
  if (payload.purpose) {
    throw new Error('Scoped token cannot be used for realtime access');
  }
  return payload;
}

/// The socket's version, asking both questions.
///
/// A socket is a longer-lived thing than a request, and it is the one that
/// registers presence and joins rooms with children in it — so it gets the same
/// check rather than a lighter one. `null` still means a guest, who is allowed
/// in read-only; a token for an account that is gone throws, and the connection
/// is refused.
async function authenticateSocket(token) {
  const payload = verifySocketToken(token);
  if (payload === null) return null;

  const standing = await tokenHolderStanding(pool, payload.id);
  if (!standing.ok) {
    throw new Error(standing.reason === 'unverifiable'
      ? 'Account could not be verified'
      : 'Account no longer exists');
  }
  return payload;
}

module.exports = {
  authenticateToken,
  optionalAuth,
  requireRole,
  signDownloadToken,
  authenticateDownloadToken,
  signReportToken,
  authenticateReportToken,
  verifySocketToken,
  authenticateSocket,
  JWT_SECRET,
};
