// destructiveScriptGuard.js
// A script that deletes data asks where it is pointed before it does anything.
//
// Found by the architecture audit on 16.9.2026 (`docs/audit/server.md`, 4).
// `clear_users.js` runs `TRUNCATE users RESTART IDENTITY CASCADE` and
// `import_new_puzzles.js` runs `DROP TABLE puzzles CASCADE` against whatever
// `.env` names — and on the development machine `.env` names the managed
// cluster the server uses. One `node clear_users.js` typed in the wrong
// terminal would have deleted every account, relationship, tutorial, homework
// record and consent record, and handed old ids to new accounts
// (`accountGuard.js` exists because of what that does to tokens). `server.js`
// even recommended running it.
//
// The rule: a local database is fine; anything else has to be named on the
// command line, **by its host**, so the person running the script has read where
// it is pointed. A flag that says only „yes" is a flag that gets pasted.

const LOCAL_HOSTS = new Set(['', 'localhost', '127.0.0.1', '::1']);

/// Decides whether a destructive script may run against the database in `env`.
///
/// `argv` is the script's arguments; `--target=<host>` equal to `DB_HOST`
/// confirms a non-local target.
function destructiveTargetVerdict(env, argv) {
  const host = String(env.DB_HOST ?? '').trim();
  if (LOCAL_HOSTS.has(host.toLowerCase())) {
    return { allowed: true, host: host || 'localhost' };
  }
  const confirmed = argv.some((arg) => arg === `--target=${host}`);
  if (confirmed) {
    return { allowed: true, host };
  }
  return {
    allowed: false,
    host,
    reason:
      `Refusing to run: this script deletes data, and DB_HOST is ${host}, which is not a local database. `
      + `If that is really the database you mean, run it again with --target=${host}`,
  };
}

/// Stops the process before a destructive script touches the database, unless
/// the target is local or confirmed by name. Prints the target either way.
function guardDestructiveScript(description, { env = process.env, argv = process.argv.slice(2) } = {}) {
  const verdict = destructiveTargetVerdict(env, argv);
  if (!verdict.allowed) {
    console.error(verdict.reason);
    process.exit(1);
  }
  console.log(`${description} — target database host: ${verdict.host}`);
  return verdict;
}

module.exports = { destructiveTargetVerdict, guardDestructiveScript };
