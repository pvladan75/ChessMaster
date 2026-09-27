// stt/groq.js — Groq's Whisper, which hears a trainer's recordings.
//
// Chosen by the owner on 27.9.2026 (D15 of docs/PLAN-PRIPREMA.md) after phase
// 5 sent four of his Serbian recordings to Groq and to Azure: Groq heard more
// of the moves, wrote Serbian in Latin, and cut sentences where he paused,
// which R1 of that plan stands on. `whisper-large-v3` rather than the cheaper
// turbo, on his corrected transcript of „proba 4": 2 of 185 words wrong
// against 10 (the owner's choice, 27.9.2026).
//
// **The sound leaves this server when this runs**, to a processor the privacy
// policy has to name before anybody but the owner uses it (D9). The key is
// never logged and never in a message.
//
// No prompt is sent. Groq takes a list of words to expect, and phase 5 never
// measured what one does to Whisper; a list that has not been measured is a
// change to what is heard that nobody has heard.

class SttUnavailable extends Error {
  constructor(message, { reason, status = 503 } = {}) {
    super(message);
    this.name = 'SttUnavailable';
    this.reason = reason;
    this.status = status;
  }
}

const DEFAULT_URL = 'https://api.groq.com/openai/v1/audio/transcriptions';
const DEFAULT_MODEL = 'whisper-large-v3';

const ms = (seconds) => Math.round(Number(seconds) * 1000);

/// Groq's answer as the transcript reads it: every time in whole
/// milliseconds, words and segments each with a start and an end.
function readAnswer(raw) {
  if (!raw || typeof raw !== 'object' || !Array.isArray(raw.words)) {
    throw new SttUnavailable('The speech service answered without the times of its words.',
      { reason: 'malformed', status: 502 });
  }
  return {
    durationMs: ms(raw.duration || 0),
    words: raw.words.map((w) => ({ text: String(w.word ?? ''), startMs: ms(w.start), endMs: ms(w.end) })),
    segments: (raw.segments || []).map((s) => ({
      text: String(s.text ?? ''), startMs: ms(s.start), endMs: ms(s.end),
    })),
  };
}

function createGroq({
  apiKey = process.env.GROQ_API_KEY,
  model = process.env.STT_GROQ_MODEL || DEFAULT_MODEL,
  url = process.env.GROQ_STT_URL || DEFAULT_URL,
  // A 30-minute take is heard in a few seconds (phase 5: 1.4 s for 2.5
  // minutes); this is for a service that never answers, under the app's wait.
  timeoutMs = 110 * 1000,
  fetchImpl = globalThis.fetch,
} = {}) {
  function configured() {
    return Boolean(apiKey && apiKey.trim());
  }

  /// [sound] is an Ogg Opus file (`compress.js`); [language] is Whisper's
  /// code (`sr`, `en`). Resolves to `readAnswer`'s shape plus the model.
  async function transcribe({ sound, language }) {
    if (!configured()) {
      throw new SttUnavailable('Speech to text is not configured on this server.',
        { reason: 'not-configured' });
    }
    const form = new FormData();
    form.append('file', new Blob([sound], { type: 'audio/ogg' }), 'sound.ogg');
    form.append('model', model);
    form.append('language', language);
    form.append('response_format', 'verbose_json');
    form.append('timestamp_granularities[]', 'word');
    form.append('timestamp_granularities[]', 'segment');
    form.append('temperature', '0');

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    let res;
    try {
      res = await fetchImpl(url, {
        method: 'POST',
        signal: controller.signal,
        headers: { Authorization: `Bearer ${apiKey}` },
        body: form,
      });
    } catch (err) {
      if (err && err.name === 'AbortError') {
        throw new SttUnavailable('The speech service did not answer in time.', { reason: 'timeout' });
      }
      throw new SttUnavailable('The speech service could not be reached.', { reason: 'network' });
    } finally {
      clearTimeout(timer);
    }

    if (res.status === 401 || res.status === 403) {
      throw new SttUnavailable('The speech service rejected this server\'s key.', { reason: 'key' });
    }
    if (res.status === 413) {
      throw new SttUnavailable('The recording is too large for the speech service.',
        { reason: 'too-large', status: 413 });
    }
    if (res.status === 429) {
      throw new SttUnavailable('The speech service is busy. Try again in a minute.', { reason: 'busy' });
    }
    if (!res.ok) {
      throw new SttUnavailable(`The speech service refused the recording (${res.status}).`,
        { reason: 'refused', status: 502 });
    }
    let raw;
    try {
      raw = await res.json();
    } catch (_) {
      throw new SttUnavailable('The speech service answered with something that is not JSON.',
        { reason: 'malformed', status: 502 });
    }
    return { ...readAnswer(raw), model };
  }

  return { name: 'groq', model, configured, transcribe };
}

module.exports = { createGroq, readAnswer, SttUnavailable, DEFAULT_MODEL };
