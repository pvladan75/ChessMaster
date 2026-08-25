// recording_stop.test.js
// What the server remembers after it stops a recording itself.
//
// Found in the log on 25.8.2026, on a real lesson:
//
//   21:30:05 WARN  [SNIMANJE] Zaustavljeno u sobi 104362: … roditelj nije
//                  dozvolio snimanje za: učenik 1.
//   21:30:05 INFO  [RECORDING STATUS] Room 104362 -> status: stopped
//   21:30:18 WARN  [SNIMANJE] Saglasnost nije mogla da se proveri za sobu
//                  104362 — server ne pamti ko je bio na času (restart usred
//                  časa?).
//
// There was no restart. The join handler had thrown the roster away, so
// thirteen seconds after naming the reason itself the server said it did not
// know one — and, worse, from that moment the upload check for that room held
// nothing at all: a client that ignored `recording_must_stop` and kept
// recording could have saved whatever it liked.
//
// So the state is three-valued now, the same shape `accountGuard` needed: *this
// was stopped for consent*, *nothing was stopped*, and *the server does not
// remember*. Only the middle one may pass unremarked.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const realtime = require('../services/realtime');

const ROOM = 'test-room-104362';
const TRAINER = 1;
const CHILD = 2;

function freshRoom(room = ROOM) {
  realtime.clearRecordedRoster(room);
  realtime.beginRecordingRoster(room, [TRAINER, CHILD]);
  return room;
}

test('a room nobody stopped has no consent stop on it', () => {
  const room = freshRoom('test-room-quiet');
  assert.equal(realtime.consentStop(room), null);
  assert.deepEqual(realtime.recordedRoster(room).sort(), [TRAINER, CHILD]);
  realtime.clearRecordedRoster(room);
});

test('stopping for consent keeps the roster, minus whoever it stopped for', () => {
  const room = freshRoom();
  realtime.stopRecordingForConsent(room, { reason: 'razlog', blocked: [CHILD] });

  // The part recorded before they walked in is still the trainer's, so the
  // roster survives — that is the difference from `clearRecordedRoster`, which
  // left the save with nothing to check against.
  assert.deepEqual(realtime.recordedRoster(room), [TRAINER]);
  realtime.clearRecordedRoster(room);
});

test('a stop for consent is not the same state as a forgotten room', () => {
  const room = freshRoom();
  realtime.stopRecordingForConsent(room, { reason: 'razlog', blocked: [CHILD] });

  const stop = realtime.consentStop(room);
  assert.equal(stop.reason, 'razlog');
  assert.deepEqual(stop.blocked, [CHILD]);

  // And the forgotten room, which is what a restart leaves behind.
  assert.equal(realtime.consentStop('test-room-never-seen'), null);
  assert.equal(realtime.recordedRoster('test-room-never-seen'), null);
  realtime.clearRecordedRoster(room);
});

test('a room that never says it stopped has not obeyed', () => {
  const room = freshRoom();
  realtime.stopRecordingForConsent(room, { reason: 'razlog', blocked: [CHILD] });

  assert.equal(realtime.consentStop(room).obeyed, false);
  realtime.clearRecordedRoster(room);
});

test('the room answering the stop is what makes it obeyed', () => {
  const room = freshRoom();
  realtime.stopRecordingForConsent(room, { reason: 'razlog', blocked: [CHILD] });
  assert.equal(realtime.noteRecordingStopped(room), true);

  assert.equal(realtime.consentStop(room).obeyed, true);
  realtime.clearRecordedRoster(room);
});

test('an answer that arrives far too late does not count as obeying', () => {
  const room = freshRoom();
  realtime.stopRecordingForConsent(room, { reason: 'razlog', blocked: [CHILD] });

  // A client that kept recording for a while and only then reported a stop is
  // not the honest client, which answers in the same second — 0s in the log
  // above.
  const realNow = Date.now;
  try {
    Date.now = () => realNow() + realtime.CONSENT_STOP_GRACE_MS + 1000;
    realtime.noteRecordingStopped(room);
  } finally {
    Date.now = realNow;
  }

  assert.equal(realtime.consentStop(room).obeyed, false);
  realtime.clearRecordedRoster(room);
});

test('a stop reported for a room nobody stopped changes nothing', () => {
  assert.equal(realtime.noteRecordingStopped('test-room-never-seen'), false);
  assert.equal(realtime.consentStop('test-room-never-seen'), null);
});

test('finishing a recording clears the stop with the roster', () => {
  const room = freshRoom();
  realtime.stopRecordingForConsent(room, { reason: 'razlog', blocked: [CHILD] });
  realtime.clearRecordedRoster(room);

  // Otherwise the next lesson in the same room would inherit a refusal that has
  // nothing to do with it.
  assert.equal(realtime.consentStop(room), null);
  assert.equal(realtime.recordedRoster(room), null);
});

// --- and that the two places which have to use all of this, do ---------------

function bodyOf(source, needle) {
  // Matched by braces, never by slicing a fixed number of characters: the guard
  // written that way in this repo read straight into the next function and went
  // on passing after the check it was watching had been deleted.
  const start = source.indexOf(needle);
  assert.notEqual(start, -1, `nije nađeno u izvoru: ${needle}`);
  const open = source.indexOf('{', start);
  let depth = 0;
  for (let i = open; i < source.length; i++) {
    if (source[i] === '{') depth++;
    else if (source[i] === '}') {
      depth--;
      if (depth === 0) return source.slice(start, i + 1);
    }
  }
  throw new Error(`nezatvorena zagrada posle: ${needle}`);
}

const root = path.join(__dirname, '..');
const recordingsRoute = fs.readFileSync(
  path.join(root, 'routes', 'recordings.js'), 'utf8');
const serverSource = fs.readFileSync(path.join(root, 'server.js'), 'utf8');

test('the save asks whether this room was stopped for consent', () => {
  const save = bodyOf(recordingsRoute, "router.post('/save'");
  assert.match(save, /realtime\.consentStop\(/,
    'upis ne pita da li je snimanje zaustavljeno zbog saglasnosti — '
    + 'prekid opet izgleda kao restart servera');
  assert.match(save, /obeyed/,
    'upis ne gleda da li je soba javila prekid, pa klijent koji ga ignoriše '
    + 'prolazi');
});

test('the save refuses the room that never said it stopped', () => {
  const save = bodyOf(recordingsRoute, "router.post('/save'");
  const fromCheck = save.slice(save.indexOf('consentStop('));
  const beforeRoster = fromCheck.slice(0, fromCheck.indexOf('const roster'));
  assert.match(beforeRoster, /403/,
    'prekid bez javljenog zaustavljanja mora da bude odbijen');
  assert.match(beforeRoster, /discardUpload\(\)/,
    'odbijen snimak mora i da se obriše — multer ga je već zapisao');
});

test('the join handler records the stop instead of forgetting the room', () => {
  assert.match(serverSource, /realtime\.stopRecordingForConsent\(/,
    'server ne beleži prekid zbog saglasnosti');
  // The regression itself: the roster used to be deleted right here.
  const around = serverSource.slice(
    serverSource.indexOf('[SNIMANJE] Zaustavljeno'),
    serverSource.indexOf('recording_must_stop'),
  );
  assert.doesNotMatch(around, /clearRecordedRoster/,
    'brisanje spiska pri prekidu je baš greška zbog koje ovaj fajl postoji');
});

test('the stop reported by the room reaches the record', () => {
  assert.match(serverSource, /realtime\.noteRecordingStopped\(/,
    'niko ne beleži da je soba javila prekid, pa nijedan upis ne može da prođe');
});

test('the answer the server composes is read by the app, not only written', () => {
  // The other half of the same failure, and the one this repository is named
  // for: `consentUnverified` and its sentence were composed on every save and
  // parsed by nobody. A warning nobody reads is a warning nobody acts on.
  //
  // Comments come out first, and the match is the *read* rather than the word:
  // the first version of this test passed against a client that had stopped
  // reading the field, because the name still stood in a comment and in the key
  // it was stored under. A guard is only worth what its mutation says it is.
  const client = fs.readFileSync(
    path.join(root, '..', 'chess_app', 'lib', 'services',
      'local_recording_service.dart'), 'utf8')
    .replace(/^\s*\/\/.*$/gm, '');
  assert.match(client, /data\['consentStopped'\]/,
    'aplikacija ne čita da li je snimanje prekinuto zbog saglasnosti');
  assert.match(client, /data\['consentUnverified'\]/,
    'aplikacija ne čita da saglasnost nije mogla da se proveri');
  assert.match(client, /notices\.add\(/,
    'aplikacija čita poruku servera i nigde je ne prosleđuje dalje');
});
