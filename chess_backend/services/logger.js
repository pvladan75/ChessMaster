const pino = require('pino');

const isProduction = process.env.NODE_ENV === 'production';

/// Whether this process is a test file that `node --test` started.
///
/// A pino transport is a worker thread (`thread-stream`), and in CI — Linux,
/// Node 22, no `.env` to say `production` — that worker kept a finished test
/// process alive: `test/support/whatHoldsMe.js` reported a `MessagePort` and
/// `thread-stream/lib/worker.js` still open twenty seconds after the last test
/// of a file had passed (19.9.2026). `node --test` waits for its child, so four
/// CI runs froze until the six-hour job limit. Only files that actually *log*
/// were held, which is why it was the ones that run `initDB`. On the Windows
/// workstation the same worker lets go, so nothing here ever showed it.
/// Pretty printing is for a person watching a terminal; a test run has none,
/// and plain pino writes straight to stdout with no thread to wait for.
const underTest = Boolean(process.env.NODE_TEST_CONTEXT);

/// Fields a log line must never carry in the clear. Most addresses on this
/// server belong to minors or to their parents, and a copied journal is a list
/// of them. Added 16.9.2026 after the audit found addresses logged on every
/// registration, verification and Google sign-in (`docs/audit/server.md`, 11);
/// the call sites log user ids now, and this is what stops a future
/// `logger.info({ user })` from bringing an address back.
const REDACT_PATHS = [
  'email', 'parent_email', 'parentEmail',
  '*.email', '*.parent_email', '*.parentEmail',
];

/// An address reduced to what is useful in a local log: its first letter and
/// its domain.
function maskEmail(email) {
  const text = String(email ?? '');
  const at = text.indexOf('@');
  if (at < 1) return '[address]';
  return `${text[0]}***${text.slice(at)}`;
}

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  redact: { paths: REDACT_PATHS, censor: '[redacted]' },
  ...(isProduction || underTest
    ? {}
    : {
        transport: {
          target: 'pino-pretty',
          options: {
            colorize: true,
            translateTime: 'yyyy-mm-dd HH:MM:ss',
            ignore: 'pid,hostname',
          },
        },
      }),
});

logger.REDACT_PATHS = REDACT_PATHS;
logger.maskEmail = maskEmail;

module.exports = logger;
