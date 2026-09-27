// stt/index.js — which service hears a recording, chosen by `STT_PROVIDER`.
//
// Shaped like the voices' switch (`services/tts/index.js`): one variable
// names the provider, and absent or unknown means the feature is **not
// offered at all** — the app asks before it draws „Transcribe". One provider
// today, Groq (D15 of docs/PLAN-PRIPREMA.md); Azure was measured and stays the
// voice only.
//
// Unset on the droplet by default, deliberately: speech to text sends a
// trainer's voice to an outside processor, and the privacy policy must name
// it before anybody but the owner uses it (D9).

const { createGroq, SttUnavailable } = require('./groq');

const PROVIDERS = { groq: createGroq };

/// The configured client, or null when speech to text is not offered.
/// [options] reach the provider's factory — a test's fake `fetchImpl`.
function speechToText(options = {}) {
  const name = String(process.env.STT_PROVIDER || '').trim().toLowerCase();
  const factory = PROVIDERS[name];
  if (!factory) return null;
  const client = factory(options);
  return client.configured() ? client : null;
}

module.exports = { speechToText, SttUnavailable, PROVIDERS };
