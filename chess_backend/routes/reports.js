// reports.js
// The page a parent opens.
//
// Unauthenticated by necessity — a parent has no account — so the signed token
// in the link is the whole credential. It is bound to one report id and expires,
// and the responses are marked no-store / noindex so the page does not linger in
// caches or search engines.

const express = require('express');
const router = express.Router();
const logger = require('../services/logger');
const { pool } = require('../db');
const { authenticateReportToken } = require('../middleware/auth');
const reports = require('../services/reportService');

function sendPlainError(res, status, message) {
  res
    .status(status)
    .type('html')
    .send(
      `<!doctype html><html lang="sr"><head><meta charset="utf-8">` +
        `<meta name="viewport" content="width=device-width, initial-scale=1">` +
        `<meta name="robots" content="noindex, nofollow"><title>Izveštaj</title></head>` +
        `<body style="font-family:system-ui,sans-serif;max-width:520px;margin:15vh auto;padding:0 20px;` +
        `color:#1a1f1c;line-height:1.6"><h1 style="font-size:20px">${reports.esc(message)}</h1>` +
        `<p style="color:#6b7870">Zatražite od trenera nov link.</p></body></html>`
    );
}

// GET /reports/:id?token=...
router.get('/:id', authenticateReportToken, async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id)) {
    return sendPlainError(res, 400, 'Link nije ispravan.');
  }

  try {
    const result = await pool.query(
      'SELECT id, note, snapshot, created_at, expires_at FROM student_reports WHERE id = $1',
      [id]
    );
    if (result.rows.length === 0) {
      return sendPlainError(res, 404, 'Izveštaj više nije dostupan.');
    }

    const report = result.rows[0];

    // The token carries its own expiry, but the row's is checked too: a report
    // deliberately expired on the server must not stay readable just because
    // someone still holds a valid-looking token.
    if (new Date(report.expires_at).getTime() < Date.now()) {
      return sendPlainError(res, 410, 'Ovaj izveštaj je istekao.');
    }

    res.set({
      'Cache-Control': 'no-store, private',
      'X-Robots-Tag': 'noindex, nofollow',
      'Referrer-Policy': 'no-referrer',
      // The page is fully self-contained, so nothing external may load or run.
      'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; img-src data:",
    });
    res.type('html').send(reports.renderHtml(report));
  } catch (err) {
    logger.error('Error rendering parent report:', err);
    sendPlainError(res, 500, 'Izveštaj trenutno nije moguće prikazati.');
  }
});

module.exports = router;
