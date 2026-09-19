// A test process that is still alive long after its tests should be done says
// what is holding it. Preloaded in CI through NODE_OPTIONS (see
// .github/workflows/ci_cd.yml), so it runs in every child `node --test` starts.
//
// Why it exists: on 19.9.2026 `exercise_authoring.test.js` passed every test
// in CI and then did not exit, run after run, while the same file — same
// environment variables, no `.env`, a real PostgreSQL — exits in a second on
// the workstation. A hang that cannot be reproduced can only be diagnosed
// where it happens, and a hung process reports nothing unless it was told to.
//
// The timer is unref'd: it can describe a process that will not exit, and can
// never be the reason one does not. A whole test file here takes a few
// seconds, so anything still running at twenty is already the fault.
const AFTER_MS = Number(process.env.WHAT_HOLDS_ME_AFTER_MS || 20000);

function describe(handle) {
  const name = handle && handle.constructor ? handle.constructor.name : typeof handle;
  if (name === 'Socket' || name === 'TLSSocket') {
    return `${name} ${handle.localAddress}:${handle.localPort} -> ` +
      `${handle.remoteAddress}:${handle.remotePort} destroyed=${handle.destroyed} ` +
      `connecting=${handle.connecting} readable=${handle.readable} writable=${handle.writable}`;
  }
  if (name === 'Server') return `Server listening=${handle.listening} ${JSON.stringify(handle.address && handle.address())}`;
  if (name === 'Timeout') return `Timeout ${handle._idleTimeout}ms repeat=${handle._repeat} ref=${handle.hasRef()}`;
  if (name === 'ChildProcess') return `ChildProcess pid=${handle.pid} ${handle.spawnfile}`;
  if (name === 'MessagePort' || name === 'Worker') return name;
  return name;
}

// Only in a child that `node --test` started for one file. The runner itself
// lives as long as the whole suite, and its pipes to the children are not news.
if (process.env.NODE_TEST_CONTEXT) setTimeout(() => {
  const handles = process._getActiveHandles().map(describe);
  const requests = process._getActiveRequests().map((r) => (r && r.constructor ? r.constructor.name : typeof r));
  process.stderr.write(
    `[whatHoldsMe] pid ${process.pid} still alive after ${AFTER_MS} ms: ${process.argv.slice(1).join(' ')}\n` +
    `[whatHoldsMe]   resources: ${JSON.stringify(process.getActiveResourcesInfo())}\n` +
    handles.map((h) => `[whatHoldsMe]   handle: ${h}\n`).join('') +
    requests.map((r) => `[whatHoldsMe]   request: ${r}\n`).join('')
  );
}, AFTER_MS).unref();
