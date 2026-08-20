// notifications.test.js
// Pins the one place a notification is written, and that writing one tells
// somebody.
//
// The row alone is not the whole job: the client reads /notifications at startup
// and on a socket event, never on a timer, so a row raised while the app is open
// is invisible until the next launch unless the recipient is nudged.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const realtime = require('../services/realtime');
const { notify } = require('../services/notifications');

function stubPool(results = [[]]) {
  const calls = [];
  let index = 0;
  return {
    calls,
    async query(text, params) {
      calls.push({ text, params });
      const rows = results[Math.min(index, results.length - 1)];
      index++;
      return { rows, rowCount: rows.length };
    },
  };
}

function stubIo() {
  const sent = [];
  return {
    sent,
    to: (socketId) => ({
      emit: (event, payload) => sent.push({ socketId, event, payload }),
    }),
  };
}

const recipient = { id: 12, name: 'pavle', email: 'a@b.c', role: 'korisnik' };

test('a notification is written and its recipient is nudged', async () => {
  const io = stubIo();
  realtime.init(io);
  realtime.setOnline(recipient, 'socket-9');

  const pool = stubPool();
  const written = await notify(pool, {
    recipientId: recipient.id,
    senderId: 3,
    title: 'Novi zadatak',
    message: 'Trener vam je zadao: Matovi u dva',
    kind: 'assignment_new',
    refId: 77,
  });

  assert.equal(written, true);
  assert.match(pool.calls[0].text, /INSERT INTO user_notifications/);
  assert.deepEqual(pool.calls[0].params, [
    12, 3, null, 'Novi zadatak', 'Trener vam je zadao: Matovi u dva', 'assignment_new', 77,
  ]);
  assert.deepEqual(io.sent, [
    { socketId: 'socket-9', event: 'notifications_changed', payload: { kind: 'assignment_new' } },
  ]);

  realtime.goOffline(recipient.id);
});

test('a recipient who is away still gets the row', async () => {
  const io = stubIo();
  realtime.init(io);

  const pool = stubPool();
  assert.equal(await notify(pool, { recipientId: 999, title: 't', message: 'm' }), true);
  assert.equal(pool.calls.length, 1);
  assert.deepEqual(io.sent, [], 'nobody to nudge');
});

test('a failed write is reported, and nobody is nudged about nothing', async () => {
  const io = stubIo();
  realtime.init(io);
  realtime.setOnline(recipient, 'socket-9');

  const pool = {
    async query() {
      throw new Error('database went away');
    },
  };

  assert.equal(await notify(pool, { recipientId: recipient.id, title: 't', message: 'm' }), false);
  assert.deepEqual(io.sent, [], 'no nudge towards a row that was never written');

  realtime.goOffline(recipient.id);
});

test('an unspecified kind stays the plain room notification', async () => {
  // The client switches on `kind`. Two of the five old copies left it to the
  // column default, and this keeps that default meaning what it meant.
  realtime.init(stubIo());
  const pool = stubPool();
  await notify(pool, { recipientId: 1, title: 't', message: 'm' });

  assert.equal(pool.calls[0].params[5], 'room');
  assert.equal(pool.calls[0].params[6], null, 'nothing to point at');
});

test('nothing else writes a notification behind its back', () => {
  // There were five hand-written copies of this INSERT and they had already
  // drifted — some set `kind` and `ref_id`, some did not — so half of them
  // reached the client as an unrecognised kind. What is pinned here is that a
  // sixth does not appear: a notification written elsewhere would also skip the
  // nudge, and go unseen until the app was restarted.
  const dirs = ['routes', 'services'].map((d) => path.join(__dirname, '..', d));
  const files = dirs.flatMap((dir) =>
    fs.readdirSync(dir).filter((f) => f.endsWith('.js')).map((f) => path.join(dir, f))
  );

  const offenders = files.filter(
    (file) =>
      path.basename(file) !== 'notifications.js' &&
      /INSERT\s+INTO\s+user_notifications/i.test(fs.readFileSync(file, 'utf8'))
  );

  assert.deepEqual(
    offenders.map((f) => path.basename(f)),
    [],
    'these write a notification without going through notify()'
  );
});
