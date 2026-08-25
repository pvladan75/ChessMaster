// account.js — what the app has to know about its own user before it can
// decide what to show them.
//
// One route answers it (`GET /me/standing`) and one changes it
// (`POST /me/age`). They are separate from `/auth` on purpose: this is not
// about proving who somebody is, it is about what is still missing before the
// account can be used, and the answer changes while a session is running.
//
// **The gate is after the login, not inside the registration.** Registering is
// not the only way to get an account here — Google sign-in creates one without
// ever passing through `/register`, and every account that already exists never
// passed through it either. A question asked only at registration is a question
// most users never see, which is this codebase's recurring failure wearing a
// friendly face: the rule looks implemented, and quietly applies to nobody.

const express = require('express');
const router = express.Router();
const logger = require('./../services/logger');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const {
  ageOfConsent,
  statedAge,
  parseStatedYear,
} = require('../services/ageService');
const {
  parseParentEmail,
  openRequest,
} = require('../services/parentConsentService');
const mailService = require('../services/mailService');
const { notify } = require('../services/notifications');

/// What is known, and what is still missing.
///
/// Deliberately says `ageKnown: false` rather than guessing. Today that is the
/// answer for every account — nothing has ever asked — and a client that turned
/// "unknown" into "adult" would be building exactly the hole this is here to
/// close.
router.get('/me/standing', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT birth_year, parent_email, parent_consent_at, parent_consent_version
         FROM users WHERE id = $1`,
      [req.user.id],
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Nalog ne postoji.' });
    }

    const row = result.rows[0];
    const age = statedAge(row.birth_year);
    const minor = age !== null && age < ageOfConsent();

    res.json({
      ageKnown: age !== null,
      birthYear: row.birth_year ?? null,
      age,
      minor,
      ageOfConsent: ageOfConsent(),
      // The account-level consent: may this child be here at all. Reported even
      // while the flow that fills it does not exist yet, because "not given" is
      // the honest answer and the app has to be able to say so.
      parentConsent: {
        required: minor,
        given: row.parent_consent_at !== null,
        at: row.parent_consent_at ?? null,
        version: row.parent_consent_version ?? null,
        parentEmailOnFile: Boolean(row.parent_email),
      },
    });
  } catch (err) {
    logger.error('[NALOG] Stanje naloga nije moglo da se pročita:', err);
    res.status(500).json({ error: 'Stanje naloga nije moglo da se pročita.' });
  }
});

/// States the year, which is all that is asked for.
///
/// A year rather than a date: it answers the only question put to it, and it is
/// one field less about a child. It is a **statement, not proof** — anybody can
/// type anything — so nothing that actually protects a child is allowed to rest
/// on it. What it decides is which flow somebody goes through.
///
/// It may be corrected: somebody who mistypes 1997 as 2017 must not be locked
/// out of their own account by a field they cannot reach. Every statement is
/// stamped, so the record shows when it changed rather than only what it says
/// now.
router.post('/me/age', authenticateToken, async (req, res) => {
  const { year, error } = parseStatedYear(req.body?.birthYear);
  if (error) return res.status(400).json({ error });

  try {
    const result = await pool.query(
      `UPDATE users
          SET birth_year = $1, birth_year_stated_at = CURRENT_TIMESTAMP
        WHERE id = $2
        RETURNING birth_year`,
      [year, req.user.id],
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Nalog ne postoji.' });
    }

    // Read back from the row, not echoed from the request — the same reason the
    // guest switch does it: a value that reports itself is a value that can be
    // right on the screen and wrong in the database.
    const age = statedAge(result.rows[0].birth_year);
    const minor = age !== null && age < ageOfConsent();
    logger.info(`[NALOG] Korisnik ${req.user.id} je uneo godinu rođenja (maloletan: ${minor})`);

    // Decided 25.8.2026: **tell, do not change.** Every relationship this
    // account already has keeps its status and its microphone. The age is read
    // when an edge is made, not backwards over the ones that exist — and a
    // mechanism that silently rewrote other people's rights on the strength of
    // a number a child just typed would be worse than the hole it closes.
    //
    // Silence is not an option either: a trainer who is never told carries on
    // recording a child whose age has just been stated. So the trainer is told,
    // and the microphone becomes their decision rather than nobody's.
    if (minor) {
      await notifyTrainersOfStatedAge(req.user.id, req.user.name || 'Učenik');
    }

    res.json({ ageKnown: age !== null, birthYear: result.rows[0].birth_year, age, minor });
  } catch (err) {
    logger.error('[NALOG] Godina rođenja nije mogla da se upiše:', err);
    res.status(500).json({ error: 'Godina rođenja nije mogla da se sačuva.' });
  }
});

/// Tells everybody already teaching this account that it belongs to a child.
///
/// Failure here does not fail the age: the year is written and that is the part
/// that matters, while an unsent notification is a message to resend. It is
/// logged loudly rather than swallowed, because a trainer who is never told is
/// the entire risk this notification exists to cover.
async function notifyTrainersOfStatedAge(studentId, studentName) {
  try {
    const trainers = await pool.query(
      `SELECT trainer_id FROM trainer_students
        WHERE student_id = $1 AND status = 'accepted'`,
      [studentId],
    );
    for (const row of trainers.rows) {
      await notify(pool, {
        recipientId: row.trainer_id,
        senderId: studentId,
        title: 'Učenik je uneo godinu rođenja',
        message: `${studentName} je uneo/la godinu po kojoj je maloletan/na. `
          + 'Postojeća veza i mikrofon ostaju kako jesu — mikrofon je od sada '
          + 'vaša odluka, u spisku učenika.',
        kind: 'student_stated_minor_age',
      });
    }
  } catch (err) {
    logger.error('[NALOG] Treneri nisu obavešteni o unetoj godini:', err);
  }
}

/// The parent's address, stated by the child.
///
/// It is asked for here rather than taken from the trainer because it is the
/// child's account: the trainer types an address they were told, and a consent
/// letter sent to the wrong address is the one failure in this flow that looks
/// exactly like success.
///
/// Stating it also **sends whatever is already waiting**. Without that, a
/// relationship that stopped at `awaiting_parent` because no address was on
/// file would sit there forever with the address now filled in and nobody
/// asked — a step that skipped silently, which is this codebase's oldest bug.
router.post('/me/parent-email', authenticateToken, async (req, res) => {
  const { email, error } = parseParentEmail(req.body?.parentEmail);
  if (error) return res.status(400).json({ error });

  try {
    const updated = await pool.query(
      'UPDATE users SET parent_email = $1 WHERE id = $2 RETURNING parent_email',
      [email, req.user.id],
    );
    if (updated.rowCount === 0) {
      return res.status(404).json({ error: 'Nalog ne postoji.' });
    }

    const waiting = await pool.query(
      `SELECT ts.id, ts.trainer_id, t.name AS trainer_name, s.name AS student_name
         FROM trainer_students ts
         JOIN users t ON t.id = ts.trainer_id
         JOIN users s ON s.id = ts.student_id
        WHERE ts.student_id = $1 AND ts.status = 'awaiting_parent'`,
      [req.user.id],
    );

    let sent = 0;
    const failed = [];
    for (const row of waiting.rows) {
      try {
        const request = await openRequest(pool, {
          relationshipId: row.id,
          studentId: req.user.id,
          trainerId: row.trainer_id,
          parentEmail: email,
        });
        await mailService.sendParentConsentRequest(email, {
          childName: row.student_name,
          trainerName: row.trainer_name,
          link: request.link,
        });
        sent += 1;
      } catch (mailErr) {
        // The request row stands either way, so this is a letter to send again
        // rather than a state to rebuild. Counted and reported, never hidden.
        failed.push(row.trainer_name);
        logger.error('[SAGLASNOST] Poruka roditelju nije poslata:', mailErr);
      }
    }

    logger.info(
      `[NALOG] Korisnik ${req.user.id} je uneo email roditelja `
      + `(poslato zahteva: ${sent}, neuspelo: ${failed.length})`,
    );

    res.json({
      parentEmailOnFile: true,
      requestsSent: sent,
      requestsFailed: failed.length,
      message: waiting.rowCount === 0
        ? 'Adresa roditelja je sačuvana.'
        : sent > 0 && failed.length === 0
          ? 'Adresa je sačuvana i roditelju je poslato pitanje za saglasnost.'
          : 'Adresa je sačuvana, ali pitanje za saglasnost nije poslato. '
            + 'Pokušajte ponovo za koji minut.',
    });
  } catch (err) {
    logger.error('[NALOG] Email roditelja nije mogao da se upiše:', err);
    res.status(500).json({ error: 'Adresa roditelja nije mogla da se sačuva.' });
  }
});

module.exports = router;
