// reviewWords.js — POST /review-words
//
// docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, §3a and phase 3: the words „Review entire
// game" writes into the PGN and into the puzzles it keeps, when the reader
// ticks „Comment key moments with AI". One request per review, on the
// tutorial's path (`gameTutorialWords.js`): the app sends the moments as data
// (`services/reviewWords.js`), this route writes the prompt, asks the model,
// and answers with the slots once they are the shape asked for. Whether the
// words are true is judged in the app, beside the facts.
//
// The guards run in the order that spends least on a request that will fail:
// sign-in, a limiter, the entitlement, the request itself, whether a model is
// configured, and only then one unit of the monthly quota.
//
// **Counted as the tutorial is**, never borrowed from it: `ai_review_words`,
// one per review the model wrote for, and `ai_review_tokens`, every attempt's
// tokens, refused ones included — the provider bills the attempt. The log line
// of every call names the provider, the model and the tokens, for the cost
// tracking the owner has agreed and not yet built.

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
  validateReviewWordsRequest, buildReviewPrompt, checkReviewAnswer,
} = require('../services/reviewWords');
const { requireProvider } = require('./gameTutorialWords');

const router = express.Router();

/// A model that answers in the wrong shape is asked once more; a second wrong
/// answer is reported, not tried again at the user's expense.
const ATTEMPTS = 2;

// A review takes minutes of engine time before its words are asked for; this
// only bites a client in a loop.
const reviewWordsLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many reviews asked for words. Please wait a while.' },
});

function validateBody(req, res, next) {
  try {
    req.reviewWordsRequest = validateReviewWordsRequest(req.body);
    buildReviewPrompt(req.reviewWordsRequest);
    next();
  } catch (err) {
    if (err instanceof RangeError) {
      return res.status(400).json({ error: err.message });
    }
    logger.error(`[REVIEW-WORDS] Neočekivana greška pri proveri zahteva: ${err.message}`);
    return res.status(500).json({ error: 'Failed to read the review request.' });
  }
}

function createReviewWordsHandler({
  provider,
  providerName = 'deepseek',
  record = (userId, metric, amount) => recordUsage(pool, userId, metric, amount),
  refund = refundQuota,
}) {
  // One review's words at a time per account: a second request while the
  // first is being written would spend a second credit.
  const writing = new Set();

  return async (req, res) => {
    const userId = req.user.id;
    if (writing.has(userId)) {
      await refund(req);
      return res.status(429).json({
        error: 'The words for another review are still being written.',
        reason: 'already-writing',
      });
    }
    writing.add(userId);
    const problems = [];
    try {
      const prompt = buildReviewPrompt(req.reviewWordsRequest);
      for (let attempt = 1; attempt <= ATTEMPTS; attempt += 1) {
        const reply = await provider.complete(prompt);
        await record(userId, METRIC.AI_REVIEW_TOKENS, reply.usage.total);
        logger.info(`[REVIEW-WORDS] ${providerName} ${reply.model}: pokušaj ${attempt}, `
          + `tokena ${reply.usage.total} (upit ${reply.usage.prompt}, odgovor ${reply.usage.answer})`);
        const checked = checkReviewAnswer(reply.content, req.reviewWordsRequest);
        if (checked.ok) {
          return res.json({
            slots: checked.slots,
            attempts: attempt,
            tokens: reply.usage,
            model: reply.model,
          });
        }
        for (const p of checked.problems) problems.push(`attempt ${attempt}: ${p}`);
        logger.info(`[REVIEW-WORDS] Odgovor nije u traženom obliku (pokušaj ${attempt}): ${checked.problems.join('; ')}`);
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
        logger.error(`[REVIEW-WORDS] ${err.reason}: ${err.message}`);
        return res.status(err.status).json({ error: err.message, reason: err.reason });
      }
      logger.error(`[REVIEW-WORDS] Neočekivana greška: ${err.message}`);
      return res.status(500).json({ error: 'Failed to write the review\'s words.' });
    } finally {
      writing.delete(userId);
    }
  };
}

const provider = createDeepSeek();

router.post(
  '/',
  authenticateToken,
  reviewWordsLimiter,
  requireEntitlement(ENT.AI_REVIEW_WORDS),
  validateBody,
  requireProvider(provider),
  requireQuota(METRIC.AI_REVIEW_WORDS),
  createReviewWordsHandler({ provider }),
);

module.exports = router;
module.exports.validateBody = validateBody;
module.exports.createReviewWordsHandler = createReviewWordsHandler;
module.exports.ATTEMPTS = ATTEMPTS;
