// lessonTranslation.js — POST /lessons/:id/translate { language }
//
// Phase 9 of docs/PLAN-PRIPREMA.md: a tutorial's copy in another language.
// D8: **a translation is a copy** — the source is never rewritten — and only
// the seven languages whose moves can be said are offered. D6: the copy has no
// voice of its own and no film; a translated tutorial is spoken by a
// synthesised voice.
//
// Only prose goes to the model, and it comes back judged (services/
// tutorialTranslation.js). What was refused is asked for once more, with the
// reasons; a second refusal is the trainer's answer — a sentence and the
// items' faults — and **no copy is written, not half of one**: the copy is one
// INSERT, made only after every item passed and the merge was proved to have
// changed nothing but words.
//
// Counted and not limited (Q3, as speech to text is): `ai_translations`, one
// per copy made, and `ai_translation_tokens`, every attempt's tokens, refused
// ones included — the provider bills the attempt.

const express = require('express');
const rateLimit = require('express-rate-limit');
const logger = require('../services/logger');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { METRIC, recordUsage } = require('../services/entitlementService');
const { createDeepSeek, LlmUnavailable } = require('../services/llm/deepseek');
const { buildLessonSteps } = require('../services/lessonSteps');
const { isTutorialLanguage, TUTORIAL_LANGUAGES } = require('../services/tutorialLanguage');
const { LANGUAGE_NAMES, translateTutorial } = require('../services/tutorialTranslation');

const router = express.Router();

// A translation takes a minute of a model's time; this only bites a client in
// a loop.
const translateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many translations asked for. Please wait a while.' },
});

function createTranslateHandler({
  db = pool,
  provider,
  providerName = 'deepseek',
  record = (userId, metric, amount) => recordUsage(db, userId, metric, amount),
}) {
  // One translation at a time per account: a second press while the first is
  // with the model would pay twice and make two copies.
  const translating = new Set();

  return async (req, res) => {
    const id = Number.parseInt(req.params.id, 10);
    if (!Number.isInteger(id) || String(id) !== String(req.params.id)) {
      return res.status(400).json({ error: 'Unknown tutorial.' });
    }
    const code = req.body && req.body.language;
    if (!isTutorialLanguage(code)) {
      return res.status(400).json({
        error: `A tutorial can be translated into ${TUTORIAL_LANGUAGES.join(', ')}.`,
      });
    }
    if (!provider.configured()) {
      return res.status(503).json({
        error: 'Translating tutorials is not configured on this server.',
        reason: 'not-configured',
      });
    }
    const userId = req.user.id;
    if (translating.has(userId)) {
      return res.status(429).json({
        error: 'Another tutorial is being translated. Wait for it to finish.',
        reason: 'already-translating',
      });
    }
    translating.add(userId);
    try {
      const found = await db.query(
        `SELECT title, description, tags, fen, pgn, position_list, language
           FROM saved_lessons
          WHERE id = $1 AND (user_id = $2 OR trainer_id = $2)`,
        [id, userId],
      );
      if (found.rowCount === 0) {
        return res.status(404).json({ error: 'Tutorial not found or you do not have permission to translate it.' });
      }
      const source = found.rows[0];
      const steps = Array.isArray(source.position_list) ? source.position_list : [];
      if (steps.length === 0) {
        return res.status(400).json({ error: 'Only a tutorial with parts can be translated.' });
      }
      if (source.language === code) {
        return res.status(400).json({ error: `This tutorial is already in ${LANGUAGE_NAMES[code]}.` });
      }

      const tutorial = { title: source.title, description: source.description, steps };
      const outcome = await translateTutorial({
        provider,
        tutorial,
        code,
        onReply: async (reply, { attempt, items }) => {
          await record(userId, METRIC.AI_TRANSLATION_TOKENS, reply.usage.total);
          logger.info(`[TRANSLATE] ${providerName} ${reply.model}: pokušaj ${attempt}, `
            + `${items} stavki, tokena ${reply.usage.total}`);
        },
      });
      if (!outcome.ok) {
        return res.status(422).json({
          error: 'The translation could not be used, so no copy was made. '
            + 'It can be asked for again.',
          reason: 'bad-translation',
          problems: Object.entries(outcome.faults).map(([key, f]) => `${key}: ${f.reason}`),
        });
      }

      const { merged } = outcome;
      const built = buildLessonSteps(merged.steps);
      if (!built.ok) {
        // The source's own steps, with words changed and nothing else: a
        // refusal here is a fault of the merge, not of the translation.
        logger.error(`[TRANSLATE] The merged steps of tutorial ${id} were refused: ${built.error}`);
        return res.status(500).json({ error: 'Server error while writing the translation.' });
      }

      const result = await db.query(
        `INSERT INTO saved_lessons (user_id, trainer_id, title, description, tags, fen, pgn, position_list, language)
         VALUES ($1, $1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
        [userId, merged.title, merged.description || null, source.tags || null, source.fen,
          source.pgn || null, JSON.stringify(built.entries), code],
      );
      await record(userId, METRIC.AI_TRANSLATIONS, 1);
      return res.status(201).json(result.rows[0]);
    } catch (err) {
      if (err instanceof LlmUnavailable) {
        logger.error(`[TRANSLATE] ${err.reason}: ${err.message}`);
        return res.status(err.status).json({ error: err.message, reason: err.reason });
      }
      logger.error(`[TRANSLATE] Neočekivana greška: ${err.message}`);
      return res.status(500).json({ error: 'Server error while translating the tutorial.' });
    } finally {
      translating.delete(userId);
    }
  };
}

const provider = createDeepSeek();

router.post(
  '/:id/translate',
  authenticateToken,
  translateLimiter,
  createTranslateHandler({ provider }),
);

module.exports = router;
module.exports.createTranslateHandler = createTranslateHandler;
