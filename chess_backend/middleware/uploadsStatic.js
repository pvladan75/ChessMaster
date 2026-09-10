// uploadsStatic.js — what of `uploads/` may be fetched by URL.
//
// `uploads/` has been served as static files since the room could record, and
// what lands there is fetched by the app from `/uploads/<name>`. A trainer's
// recorded narration is different: it is read by the renderer from disk and
// never played from a URL, so there is no reason for it to be reachable by one.
//
// **Judged on the path as the file server will read it**, not as it was typed.
// `/uploads/%6Earration/x.wav`, `/uploads/NARRATION/x.wav` on a
// case-insensitive disk and `/uploads/a/../narration/x.wav` all name the same
// file to `express.static`; a check on the raw string would let each of them
// through. So the path is decoded, normalised and lower-cased, and then its
// first segment is asked.
const path = require('path');
const express = require('express');

/// Folders under `uploads/` that are never served.
const PRIVATE_UPLOADS = ['narration'];

function isPrivateUpload(requestPath) {
  let decoded;
  try {
    decoded = decodeURIComponent(requestPath);
  } catch {
    return true; // a path that does not decode is not one to guess about
  }
  const normalised = path.posix.normalize(decoded.replace(/\\/g, '/')).toLowerCase();
  const first = normalised.split('/').filter(Boolean)[0];
  return PRIVATE_UPLOADS.includes(first);
}

/// Mounts `uploads/` on [app] at `/uploads`, minus [PRIVATE_UPLOADS].
function serveUploads(app, dir) {
  app.use('/uploads', (req, res, next) => {
    if (isPrivateUpload(req.path)) return res.status(404).end();
    return next();
  }, express.static(dir));
}

module.exports = { PRIVATE_UPLOADS, isPrivateUpload, serveUploads };
