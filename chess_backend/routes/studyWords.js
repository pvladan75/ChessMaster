// studyWords.js — POST /study-words and POST /study-words/comment
//
// docs/PLAN-STUDIJA-POZICIJE.md, §3 and D5: every sentence a model writes about
// a board. The app sends what it has worked out as data
// (`services/studyWords.js`); this route writes the prompt, asks the model, and
// answers with the slots once they are the shape asked for. Whether the words
// are true is judged in the app, beside the facts.
//
// **Two doors, one path.** A study — the position, its main line, the traps
// and the tempting moves — is `POST /`, with an entitlement and a counter of
// its own (`ai_studies`, D4). One move or one position is the same request
// with one item, `POST /comment`: what „Generate AI comment" and the
// repertoire's „AI on position" asked Gemini until 28.9.2026, counted where
// those were (`ai_comments`), so a free account keeps the ten it had.
//
// The guards run in the order that spends least on a request that will fail:
// sign-in, a limiter, the entitlement, the request itself, whether a model is
// configured, and only then one unit of the monthly quota.

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
  validateStudyWordsRequest, buildStudyPrompt, checkStudyAnswer,
} = require('../services/studyWords');

const router = express.Router();

/// A model that answers in the wrong shape is asked once more; a second wrong
/// answer is reported, not tried again at the user's expense.
const ATTEMPTS = 2;

/// The kinds a single comment may be about.
const COMMENT_KINDS = Object.freeze(['move', 'position']);

// A study takes the engine most of a minute before its words are asked for;
// this only bites a client in a loop.
const studyLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many studies asked for words. Please wait a while.' },
});

// One comment is one tap; ten a minute is a reader, more is a loop.
const commentLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many AI requests. Please wait a moment.' },
});

function refuse(res, err, what) {
  if (err instanceof RangeError) {
    return res.status(400).json({ error: err.message });
  }
  logger.error(`[STUDY-WORDS] Neočekivana greška pri proveri zahteva: ${err.message}`);
  return res.status(500).json({ error: `Failed to read the ${what} request.` });
}

/// The request checked and the prompt proved buildable, before anything is
/// reserved.
function validateBody(req, res, next) {
  try {
    req.studyWordsRequest = validateStudyWordsRequest(req.body);
    buildStudyPrompt(req.studyWordsRequest);
    return next();
  } catch (err) {
    return refuse(res, err, 'study');
  }
}

/// The same, for one comment: one item, a move or a position.
function validateComment(req, res, next) {
  try {
    const request = validateStudyWordsRequest(req.body);
    if (request.items.length !== 1) {
      throw new RangeError('A comment is about one item.');
    }
    if (!COMMENT_KINDS.includes(request.items[0].kind)) {
      throw new RangeError(`A comment is about ${COMMENT_KINDS.join(' or ')}.`);
    }
    buildStudyPrompt(request);
    req.studyWordsRequest = request;
    return next();
  } catch (err) {
    return refuse(res, err, 'comment');
  }
}

function requireProvider(provider) {
  return (req, res, next) => {
    if (provider.configured()) return next();
    return res.status(503).json({
      error: 'Writing with the model is not configured on this server.',
      reason: 'not-configured',
    });
  };
}

function createStudyWordsHandler({
  provider,
  tokens,
  providerName = 'deepseek',
  record = (userId, metric, amount) => recordUsage(pool, userId, metric, amount),
  refund = refundQuota,
}) {
  if (!tokens) throw new TypeError('createStudyWordsHandler needs the metric its tokens are counted under');
  // One at a time per account: a second request while the first is being
  // written would spend a second credit.
  const writing = new Set();

  return async (req, res) => {
    const userId = req.user.id;
    if (writing.has(userId)) {
      await refund(req);
      return res.status(429).json({
        error: 'The words for another position are still being written.',
        reason: 'already-writing',
      });
    }
    writing.add(userId);
    const problems = [];
    try {
      const prompt = buildStudyPrompt(req.studyWordsRequest);
      for (let attempt = 1; attempt <= ATTEMPTS; attempt += 1) {
        const reply = await provider.complete(prompt);
        await record(userId, tokens, reply.usage.total);
        logger.info(`[STUDY-WORDS] ${providerName} ${reply.model}: pokušaj ${attempt}, `
          + `tokena ${reply.usage.total} (upit ${reply.usage.prompt}, odgovor ${reply.usage.answer})`);
        const checked = checkStudyAnswer(reply.content, req.studyWordsRequest);
        if (checked.ok) {
          return res.json({
            slots: checked.slots,
            dropped: checked.dropped,
            attempts: attempt,
            tokens: reply.usage,
            model: reply.model,
          });
        }
        for (const p of checked.problems) problems.push(`attempt ${attempt}: ${p}`);
        logger.info(`[STUDY-WORDS] Odgovor nije u traženom obliku (pokušaj ${attempt}): ${checked.problems.join('; ')}`);
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
        logger.error(`[STUDY-WORDS] ${err.reason}: ${err.message}`);
        return res.status(err.status).json({ error: err.message, reason: err.reason });
      }
      logger.error(`[STUDY-WORDS] Neočekivana greška: ${err.message}`);
      return res.status(500).json({ error: 'Failed to write the words.' });
    } finally {
      writing.delete(userId);
    }
  };
}

/// The model a study is written by: `STUDY_WORDS_MODEL` and
/// `STUDY_WORDS_REASONING_EFFORT`, and unset the model and the effort every
/// other route was validated with.
const provider = createDeepSeek({
  model: process.env.STUDY_WORDS_MODEL || 'deepseek-flash',
  reasoningEffort: process.env.STUDY_WORDS_REASONING_EFFORT || 'low',
});

router.post(
  '/',
  authenticateToken,
  studyLimiter,
  requireEntitlement(ENT.AI_STUDIES),
  validateBody,
  requireProvider(provider),
  requireQuota(METRIC.AI_STUDIES),
  createStudyWordsHandler({ provider, tokens: METRIC.AI_STUDY_TOKENS }),
);

router.post(
  '/comment',
  authenticateToken,
  commentLimiter,
  validateComment,
  requireProvider(provider),
  requireQuota(METRIC.AI_COMMENTS),
  createStudyWordsHandler({ provider, tokens: METRIC.AI_COMMENT_TOKENS }),
);

module.exports = router;
module.exports.validateBody = validateBody;
module.exports.validateComment = validateComment;
module.exports.requireProvider = requireProvider;
module.exports.createStudyWordsHandler = createStudyWordsHandler;
module.exports.ATTEMPTS = ATTEMPTS;
module.exports.COMMENT_KINDS = COMMENT_KINDS;
