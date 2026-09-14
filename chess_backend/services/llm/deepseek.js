// deepseek.js — one call to DeepSeek's chat endpoint, for the words of a tutorial.
//
// docs/PLAN-SKELET.md, phase 3, decision D3: `deepseek-flash` with
// `reasoning_effort: low` is the model of every validated harness run
// (tools/game_annotate/run_api.py, arm H), and the request here is that run's
// request: one user message, a JSON object asked for, temperature 1, and a
// 64,000-token ceiling — a reasoning model counts its thinking against it, and
// 16,000 cut both DeepSeek models off mid-thought with no answer written.
//
// **Every failure is a reason, never a stack.** The route turns each into a
// sentence and a status a client can act on; the key is never in either.

class LlmUnavailable extends Error {
  constructor(message, { reason, status = 503 } = {}) {
    super(message);
    this.name = 'LlmUnavailable';
    this.reason = reason;
    this.status = status;
  }
}

const DEFAULT_URL = 'https://api.deepseek.com/chat/completions';

function createDeepSeek({
  apiKey = process.env.DEEPSEEK_API_KEY,
  model = process.env.TUTORIAL_WORDS_MODEL || 'deepseek-flash',
  reasoningEffort = process.env.TUTORIAL_WORDS_REASONING_EFFORT || 'low',
  url = process.env.DEEPSEEK_URL || DEFAULT_URL,
  // Under the app's 120 s request and nginx's 300 s: a model that has not
  // answered by then is answered for, rather than left running for nobody.
  timeoutMs = 100 * 1000,
  maxTokens = 64000,
  fetchImpl = globalThis.fetch,
} = {}) {
  function configured() {
    return Boolean(apiKey && apiKey.trim());
  }

  async function post(payload) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      return await fetchImpl(url, {
        method: 'POST',
        signal: controller.signal,
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify(payload),
      });
    } catch (err) {
      if (err && err.name === 'AbortError') {
        throw new LlmUnavailable('The model did not answer in time.', { reason: 'timeout' });
      }
      throw new LlmUnavailable('The model could not be reached.', { reason: 'network' });
    } finally {
      clearTimeout(timer);
    }
  }

  /// The model's answer text, its token counts and why it stopped.
  async function complete(prompt) {
    if (!configured()) {
      throw new LlmUnavailable('Writing tutorials is not configured on this server.',
        { reason: 'not-configured' });
    }
    const payload = {
      model,
      messages: [{ role: 'user', content: prompt }],
      response_format: { type: 'json_object' },
      max_tokens: maxTokens,
      temperature: 1.0,
    };
    if (reasoningEffort) payload.reasoning_effort = reasoningEffort;

    let res = await post(payload);
    if (res.status === 400) {
      // The one refusal worth surviving: a model that cannot be asked for JSON
      // by `response_format`. The answer is still read as JSON below.
      const detail = await res.text().catch(() => '');
      if (/response_format/i.test(detail)) {
        delete payload.response_format;
        res = await post(payload);
      } else {
        throw new LlmUnavailable('The model refused the request.', { reason: 'refused' });
      }
    }
    if (res.status === 401 || res.status === 403) {
      throw new LlmUnavailable('The model provider rejected this server\'s key.',
        { reason: 'unauthorized' });
    }
    if (res.status === 402) {
      throw new LlmUnavailable('The model provider account has no balance.',
        { reason: 'no-balance' });
    }
    if (res.status === 429) {
      throw new LlmUnavailable('The model provider is limiting requests. Try again in a minute.',
        { reason: 'rate-limited' });
    }
    if (!res.ok) {
      throw new LlmUnavailable(`The model provider answered ${res.status}.`, { reason: 'provider' });
    }

    let data;
    try {
      data = await res.json();
    } catch (_) {
      throw new LlmUnavailable('The model provider sent something that is not JSON.',
        { reason: 'provider' });
    }
    const choice = data?.choices?.[0];
    const usage = data?.usage || {};
    return {
      content: typeof choice?.message?.content === 'string' ? choice.message.content : '',
      finish: choice?.finish_reason ?? null,
      usage: {
        prompt: usage.prompt_tokens ?? 0,
        answer: usage.completion_tokens ?? 0,
        thoughts: usage.completion_tokens_details?.reasoning_tokens ?? 0,
        total: usage.total_tokens ?? 0,
      },
      model,
    };
  }

  return { configured, complete };
}

module.exports = { createDeepSeek, LlmUnavailable, DEFAULT_URL };
