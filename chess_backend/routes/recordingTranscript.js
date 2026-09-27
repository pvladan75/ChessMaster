// recordingTranscript.js — speech to text on a recording made in Preparation.
// Phase 7 of docs/PLAN-PRIPREMA.md. Mounted by routes/recordings.js:
//
//   GET  /recordings/:id/transcript   what the app draws: whether „Transcribe"
//                                     is offered, in which languages, and the
//                                     transcript if there is one
//   POST /recordings/:id/transcript   { language } — hear it (again)
//   PUT  /recordings/:id/transcript   { texts } — the trainer's correction
//
// All three are the host's, on their own Preparation recording; anybody else
// reads not found (`recordingTranscripts.js`).
//
// **A vendor that fails is a sentence, and the recording is as it was.**
// Nothing is written until a transcript has been heard and judged; the sound
// is only ever read (`stt/compress.js`).

const fs = require('fs');
const logger = require('../services/logger');
const { recordUsage, sttSecondsMetric } = require('../services/entitlementService');
const { recordProviderRequest, PROVIDER } = require('../services/providerUsage');
const lessonRecording = require('../services/lessonRecording');
const store = require('../services/recordingTranscripts');
const { speechToText, SttUnavailable } = require('../services/stt');
const { compressForSpeech } = require('../services/stt/compress');
const {
  TRANSCRIPT_LANGUAGES, VENDOR_LANGUAGE, applyCorrection, isTranscriptLanguage,
  judgeSentences, sentencesFrom,
} = require('../services/transcript');

const NOT_FOUND = { error: 'Recording not found.' };
const NOT_HERE = 'Only a lesson recorded in Preparation can be transcribed.';

/// The provider-day name a provider's requests are counted under.
const PROVIDER_DAY = { groq: PROVIDER.GROQ_STT };

function createTranscriptHandlers({
  pool,
  // Asked at each request, not at load: the switch is the environment's.
  stt = () => speechToText(),
  compress = compressForSpeech,
  soundOf = (row) => lessonRecording.lessonAudioPath(row.audio_file),
  record = (userId, metric, amount) => recordUsage(pool, userId, metric, amount),
  countRequest = (provider) => recordProviderRequest(pool, provider),
}) {
  // One hearing of a recording at a time: a second tap while the first is
  // with the vendor would pay twice and race the two answers into one row.
  const hearing = new Set();

  async function read(req, res) {
    try {
      const row = await store.hostRecording(pool, req.params.id, req.user.id);
      if (!row) return res.status(404).json(NOT_FOUND);
      const client = stt();
      const transcript = store.wireOf(await store.readTranscript(pool, row.id));
      return res.json({
        available: Boolean(client) && store.transcribable(row),
        languages: client ? TRANSCRIPT_LANGUAGES : [],
        transcript,
      });
    } catch (err) {
      logger.error('[TRANSCRIPT] Read failed:', err);
      return res.status(500).json({ error: 'Server error while reading the transcript.' });
    }
  }

  async function transcribe(req, res) {
    const language = req.body && req.body.language;
    if (!isTranscriptLanguage(language)) {
      return res.status(400).json({
        error: `A transcript's language must be one of ${TRANSCRIPT_LANGUAGES.join(', ')}.`,
      });
    }
    let row;
    try {
      row = await store.hostRecording(pool, req.params.id, req.user.id);
    } catch (err) {
      logger.error('[TRANSCRIPT] Lookup failed:', err);
      return res.status(500).json({ error: 'Server error while transcribing the recording.' });
    }
    if (!row) return res.status(404).json(NOT_FOUND);
    if (!store.transcribable(row)) return res.status(400).json({ error: NOT_HERE });
    const client = stt();
    if (!client) {
      return res.status(503).json({ error: 'Speech to text is not configured on this server.' });
    }
    const file = soundOf(row);
    if (!file || !fs.existsSync(file)) {
      return res.status(404).json({ error: 'The recording\'s sound is missing.' });
    }
    if (hearing.has(row.id)) {
      return res.status(409).json({ error: 'This recording is already being transcribed.' });
    }
    hearing.add(row.id);
    try {
      let sound;
      try {
        sound = await compress(file);
      } catch (err) {
        logger.error(`[TRANSCRIPT] Compression failed for recording ${row.id}: ${err.message}`);
        return res.status(500).json({ error: 'The recording could not be prepared for transcription.' });
      }

      let answer;
      try {
        answer = await client.transcribe({ sound, language: VENDOR_LANGUAGE[language] });
      } catch (err) {
        if (err instanceof SttUnavailable) {
          logger.error(`[TRANSCRIPT] ${client.name} ${err.reason}: ${err.message}`);
          return res.status(err.status).json({ error: err.message, reason: err.reason });
        }
        throw err;
      } finally {
        // Counted however the attempt ended: the vendor bills an hour of
        // sound it was sent, and an answer refused below was still paid for.
        // Fire and forget — a meter never fails the request it counts.
        record(req.user.id, sttSecondsMetric(client.name), Math.ceil(row.duration_ms / 1000));
        if (PROVIDER_DAY[client.name]) countRequest(PROVIDER_DAY[client.name]);
      }

      const judged = judgeSentences(sentencesFrom(answer, { language }), row.duration_ms);
      if (!judged.ok) {
        logger.error(`[TRANSCRIPT] Refused ${client.name}'s answer for recording ${row.id}: ${judged.error}`);
        return res.status(422).json({
          error: `The transcript that came back cannot be used: ${judged.error}`,
          reason: 'bad-answer',
        });
      }
      const saved = await store.saveTranscript(pool, {
        recordingId: row.id,
        language,
        vendor: client.name,
        model: answer.model,
        durationMs: row.duration_ms,
        sentences: judged.sentences,
        words: answer.words,
      });
      return res.status(201).json({ transcript: store.wireOf(saved) });
    } catch (err) {
      logger.error('[TRANSCRIPT] Transcription failed:', err);
      return res.status(500).json({ error: 'Server error while transcribing the recording.' });
    } finally {
      hearing.delete(row.id);
    }
  }

  async function correct(req, res) {
    try {
      const row = await store.hostRecording(pool, req.params.id, req.user.id);
      if (!row) return res.status(404).json(NOT_FOUND);
      const stored = await store.readTranscript(pool, row.id);
      if (!stored) return res.status(404).json({ error: 'This recording has no transcript yet.' });
      const corrected = applyCorrection(stored.sentences, req.body && req.body.texts);
      if (!corrected.ok) return res.status(400).json({ error: corrected.error });
      const saved = await store.saveSentences(pool, row.id, corrected.sentences);
      if (!saved) return res.status(404).json({ error: 'This recording has no transcript yet.' });
      return res.json({ transcript: store.wireOf(saved) });
    } catch (err) {
      logger.error('[TRANSCRIPT] Correction failed:', err);
      return res.status(500).json({ error: 'Server error while saving the correction.' });
    }
  }

  return { read, transcribe, correct };
}

module.exports = { createTranscriptHandlers, PROVIDER_DAY };
