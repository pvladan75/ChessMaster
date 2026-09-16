// bodyParsers.js
// How much of a request body the server reads before anybody is authenticated.
//
// Found by the architecture audit on 16.9.2026 (`docs/audit/server.md`, 5).
// `/recordings/*` had its own `express.json({ limit: '100mb' })`, mounted in
// front of every route — so a caller with no token could make the server buffer
// and `JSON.parse` 100 MB, synchronously, on the thread that also draws films
// and answers everybody else, and only then be told 401. The ceiling was raised
// for a base64 audio upload the app stopped sending; recordings travel as
// multipart, which multer reads inside the route, after `authenticateToken`.
//
// One ceiling for JSON everywhere now. test/body_parsers.test.js.

const express = require('express');

const JSON_LIMIT = '2mb';

function mountBodyParsers(app) {
  app.use(express.json({ limit: JSON_LIMIT }));
  app.use(express.urlencoded({ limit: JSON_LIMIT, extended: true }));
}

module.exports = { mountBodyParsers, JSON_LIMIT };
