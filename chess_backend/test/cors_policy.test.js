// cors_policy.test.js
// Which browser origins this server answers, and why one of them is itself.
//
// Found live on 25.8.2026, by a parent's consent page that opened perfectly and
// then refused to record consent: `{"error":"Origin not allowed"}` where the
// answer should have been. The page is served by this server and posts back to
// it, so its form carried `Origin: <this server>` — which was not on the
// allowlist, because the allowlist was written when the only browser origins
// that could exist were somebody else's.
//
// **What hid it:** a browser sends no `Origin` on ordinary navigation and does
// send one on a form POST. So opening the page proved nothing about pressing
// the button, and the two halves of the same page disagreed.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  corsVerdict,
  isSameOrigin,
  parseAllowedOrigins,
} = require('../services/corsPolicy');

const LIST = ['http://localhost:8080', 'https://app.example.com'];

test('a request with no Origin is a native client, and passes', () => {
  // Android and Windows send none. This is almost all of this server's traffic.
  for (const none of [undefined, null, '']) {
    assert.equal(corsVerdict(none, 'api.example.com', LIST), 'no-origin');
  }
});

test('a listed browser origin passes and is told so', () => {
  assert.equal(corsVerdict('http://localhost:8080', 'localhost:3000', LIST),
    'allowed');
});

test('our own page is not a stranger', () => {
  // The bug, in one line. The consent page is served from this host and posts
  // to this host; the allowlist was never meant to judge that case.
  assert.equal(
    corsVerdict('http://192.168.0.19:3000', '192.168.0.19:3000', LIST),
    'same-origin',
  );
  assert.equal(
    corsVerdict('https://api.chesstrainers.app', 'api.chesstrainers.app', LIST),
    'same-origin',
  );
});

test('same-origin holds with an empty allowlist, which is the shipped state', () => {
  // `ALLOWED_ORIGINS` is empty on a fresh install: the app is native and the
  // only browser page this server has is its own. The consent flow must work
  // there without anybody editing .env.
  assert.equal(
    corsVerdict('http://192.168.0.19:3000', '192.168.0.19:3000', []),
    'same-origin',
  );
});

test('somebody else\'s page is still blocked', () => {
  // The whole point of the gate, and it must survive the fix above.
  assert.equal(corsVerdict('https://zlonamerni.rs', 'api.example.com', LIST),
    'blocked');
  assert.equal(corsVerdict('http://192.168.0.19:3000', 'api.example.com', LIST),
    'blocked');
});

test('a near miss is a miss', () => {
  // Host is compared whole. A suffix match would let
  // `api.example.com.evil.rs` through, which is the classic way this check is
  // got wrong.
  for (const origin of [
    'https://api.example.com.evil.rs',
    'https://evil.rs/api.example.com',
    'https://xapi.example.com',
  ]) {
    assert.equal(isSameOrigin(origin, 'api.example.com'), false, origin);
  }
});

test('the port is part of the host', () => {
  // Two servers on one machine are two origins.
  assert.equal(isSameOrigin('http://192.168.0.19:3000', '192.168.0.19:3000'), true);
  assert.equal(isSameOrigin('http://192.168.0.19:3000', '192.168.0.19:4000'), false);
  assert.equal(isSameOrigin('http://192.168.0.19', '192.168.0.19:3000'), false);
});

test('an Origin that is not a URL is not our own', () => {
  // `new URL` throwing is an answer, and the answer is no.
  for (const bad of ['null', 'nije-url', '://', ' ', 'file://']) {
    assert.equal(isSameOrigin(bad, 'api.example.com'), false, bad);
  }
});

test('a missing Host cannot match anything', () => {
  assert.equal(isSameOrigin('https://api.example.com', undefined), false);
  assert.equal(isSameOrigin('https://api.example.com', ''), false);
});

test('the allowlist is parsed the way it is written in .env', () => {
  assert.deepEqual(
    parseAllowedOrigins(' http://a.rs , https://b.rs ,, '),
    ['http://a.rs', 'https://b.rs'],
  );
  assert.deepEqual(parseAllowedOrigins(''), []);
  assert.deepEqual(parseAllowedOrigins(undefined), []);
});
