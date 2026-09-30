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

/// Anything shaped like an address, wherever it stands inside a text.
const ADDRESS = /[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+/g;

/// A copy of [value] with every address in every string masked. The value the
/// caller still holds is never changed.
function maskAddresses(value, depth = 0) {
  if (typeof value === 'string') return value.replace(ADDRESS, (address) => maskEmail(address));
  if (value === null || typeof value !== 'object') return value;
  if (ArrayBuffer.isView(value) || typeof value.toJSON === 'function') return value;
  if (depth >= 8) return '[nested too deep]';
  if (Array.isArray(value)) return value.map((item) => maskAddresses(item, depth + 1));
  const copy = {};
  for (const [key, item] of Object.entries(value)) copy[key] = maskAddresses(item, depth + 1);
  return copy;
}

/// An error as pino's own serializer writes it — type, message, stack, causes
/// and every field of its own — with the addresses in it masked and a row
/// Postgres dumped into `detail` left out.
///
/// Until 30.9.2026 most error lines here handed the error to pino as a second
/// argument, which pino drops, so no error's own fields ever reached a log.
/// Now they do, and some carry what `REDACT_PATHS` keeps out, in places a path
/// cannot name: nodemailer puts a refused recipient in `rejected` and in its
/// message, and Postgres writes the offending key into `detail`
/// (`Key (email)=(…) already exists`) or, for a NOT NULL or CHECK violation,
/// the whole failing row — address, password hash and name.
function errSerializer(err) {
  const out = pino.stdSerializers.err(err);
  // Not an error: pino hands the value back as it came, so mask a copy.
  if (out === err) return maskAddresses(err);
  // An error: `out` is pino's own fresh copy, so its fields are replaced on it.
  if (typeof out.detail === 'string' && out.detail.startsWith('Failing row contains')) {
    out.detail = '[the failing row is not logged]';
  }
  for (const key of Object.keys(out)) out[key] = maskAddresses(out[key]);
  return out;
}

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  redact: { paths: REDACT_PATHS, censor: '[redacted]' },
  serializers: { err: errSerializer },
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
logger.errSerializer = errSerializer;

module.exports = logger;
