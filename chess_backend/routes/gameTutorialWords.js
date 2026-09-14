// gameTutorialWords.js — POST /lessons/from-game/words
//
// docs/PLAN-SKELET.md, phase 3: the words of a tutorial the app has built from
// a game. The app sends the skeleton as data (`services/tutorialWords.js` says
// what and why); this route writes the prompt, asks the model, and answers with
// the model's words once they are the shape asked for. Assembling the tutorial
// and judging whether the words are true stay in the app, beside the facts.
//
// The guards run in the order that spends least on a request that will fail:
// sign-in, a limiter, the entitlement, then the request itself — a malformed
// skeleton is refused before a credit is reserved — then whether a model is
// configured, and only then one unit of the monthly quota.
//
// **Synchronous**, not a job: the harness measured 24–69 s for the words, the
// model call times out at 100 s, the app's request at 120 s, nginx at 300 s.

const express = require('express');
const rateLimit = require('express-rate-limit');
const logger = require('../services/logger');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const {
  requireEntitlement, requireQuota, refundQuota,
} = require('../middleware/entitlements');
const { ENT, METRIC, recordUsage } = require('../services/entitlementService');
const { createDeepSeek, LlmUnavailable } = require('../services/llm/deepseek');
const {
  validateWordsRequest, buildPrompt, checkAnswer,
} = require('../services/tutorialWords');

const router = express.Router();

/// A model that answers in the wrong shape is asked once more; a second wrong
/// answer is reported, not tried again at the user's expense.
const ATTEMPTS = 2;

// A tutorial takes a trainer minutes of engine time before it is ever sent, so
// even an eager one sends a few an hour. This only bites a client in a loop.
const wordsLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many tutorials requested. Please wait a while.' },
});

/// The request checked and the prompt proved buildable, before anything is
/// reserved.
function validateBody(req, res, next) {
  try {
    req.wordsRequest = validateWordsRequest(req.body);
    buildPrompt(req.wordsRequest);
    next();
  } catch (err) {
    if (err instanceof RangeError) {
      return res.status(400).json({ error: err.message });
    }
    logger.error(`[WORDS] Neočekivana greška pri proveri zahteva: ${err.message}`);
    return res.status(500).json({ error: 'Failed to read the tutorial request.' });
  }
}

function requireProvider(provider) {
  return (req, res, next) => {
    if (provider.configured()) return next();
    return res.status(503).json({
      error: 'Writing tutorials is not configured on this server.',
      reason: 'not-configured',
    });
  };
}

function createWordsHandler({
  provider,
  record = (userId, metric, amount) => recordUsage(pool, userId, metric, amount),
  refund = refundQuota,
}) {
  // One tutorial at a time per account: a second press while the first is
  // being written would spend a second credit on the same game.
  const writing = new Set();

  return async (req, res) => {
    const userId = req.user.id;
    if (writing.has(userId)) {
      await refund(req);
      return res.status(429).json({
        error: 'The words for another tutorial are still being written.',
        reason: 'already-writing',
      });
    }
    writing.add(userId);
    const problems = [];
    try {
      const prompt = buildPrompt(req.wordsRequest);
      for (let attempt = 1; attempt <= ATTEMPTS; attempt += 1) {
        const reply = await provider.complete(prompt);
        await record(userId, METRIC.AI_TUTORIAL_TOKENS, reply.usage.total);
        const checked = checkAnswer(reply.content, req.wordsRequest);
        if (checked.ok) {
          return res.json({
            answer: checked.answer,
            attempts: attempt,
            tokens: reply.usage,
            model: reply.model,
          });
        }
        for (const p of checked.problems) problems.push(`attempt ${attempt}: ${p}`);
        logger.info(`[WORDS] Odgovor nije u traženom obliku (pokušaj ${attempt}): ${checked.problems.join('; ')}`);
      }
      await refund(req);
      return res.status(422).json({
        error: 'The model did not answer in the shape asked for, twice. '
          + 'It does not count against your allowance.',
        reason: 'bad-answer',
        problems,
      });
    } catch (err) {
      await refund(req);
      if (err instanceof LlmUnavailable) {
        logger.error(`[WORDS] ${err.reason}: ${err.message}`);
        return res.status(err.status).json({ error: err.message, reason: err.reason });
      }
      logger.error(`[WORDS] Neočekivana greška: ${err.message}`);
      return res.status(500).json({ error: 'Failed to write the tutorial\'s words.' });
    } finally {
      writing.delete(userId);
    }
  };
}

const provider = createDeepSeek();

router.post(
  '/words',
  authenticateToken,
  wordsLimiter,
  requireEntitlement(ENT.AI_TUTORIALS),
  validateBody,
  requireProvider(provider),
  requireQuota(METRIC.AI_TUTORIALS),
  createWordsHandler({ provider }),
);

module.exports = router;
module.exports.validateBody = validateBody;
module.exports.requireProvider = requireProvider;
module.exports.createWordsHandler = createWordsHandler;
module.exports.ATTEMPTS = ATTEMPTS;
