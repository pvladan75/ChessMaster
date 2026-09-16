// accountLimiter.js
// A rate limit counted per signed-in account rather than per address.
//
// The limiters elsewhere count by IP, which is right in front of a login — there
// is no account yet — and wrong behind one: a school's students share one
// address, and one account in a loop is exactly as expensive from any address.
// Added 16.9.2026 for three routes the audit found open to a loop
// (`docs/audit/server.md`, 10, 16 and 19): scanning a PDF, mailing a parent,
// and drawing preview frames. Mounted **after** `authenticateToken`, and before
// anything that reads a body — a limit checked after multer has written 25 MB
// has already paid for the request it refuses.

const rateLimit = require('express-rate-limit');

function accountLimiter({ windowMs, max, message }) {
  return rateLimit({
    windowMs,
    max,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) => `account:${req.user.id}`,
    message: { error: message },
  });
}

module.exports = { accountLimiter };
