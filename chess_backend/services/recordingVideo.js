// recordingVideo.js — a recorded lesson's video, for whoever may read it.
//
// Phase 5b.5 of docs/PLAN-SESIJA.md, and the owner's answer of 22.9.2026: a
// student downloads **the trainer's latest render**, while it exists. Exports
// age out on the retention timer (`retentionService.js`); then there is
// nothing to hand over and the app says so. Rendering stays the host's
// (`POST /recordings/:id/export-mp4`).
//
// The row's `video_url` is never handed out as it is: it carries a download
// token signed for the host when the film was rendered. A reader gets a link
// of their own, for that one file.

const fs = require('fs');
const path = require('path');
const { signDownloadToken } = require('../middleware/auth');

const EXPORT_LINK = /^\/recordings\/export-download\/([^?]+)/;

/// A link for [userId] to the latest render of [row], or null when there is
/// none on disk — never rendered, aged out, or a stored link that is not an
/// export at all.
function latestVideoFor(row, userId, exportsDir) {
  const match = EXPORT_LINK.exec((row && row.video_url) || '');
  if (!match) return null;
  let name;
  try {
    name = decodeURIComponent(match[1]);
  } catch {
    return null;
  }
  // A name, never a path: a stored link is data, not an instruction to open
  // whatever it names.
  if (name !== path.basename(name) || name.includes('..')) return null;
  if (!fs.existsSync(path.join(exportsDir, name))) return null;
  return `/recordings/export-download/${encodeURIComponent(name)}`
    + `?token=${encodeURIComponent(signDownloadToken(userId, name))}`;
}

module.exports = { latestVideoFor };
