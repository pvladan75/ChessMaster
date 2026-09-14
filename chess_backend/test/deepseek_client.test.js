// One call to DeepSeek, with the network replaced: what is sent, what is read
// back, and each refusal as its reason.

const test = require('node:test');
const assert = require('node:assert/strict');

const { createDeepSeek, LlmUnavailable, DEFAULT_URL } = require('../services/llm/deepseek');

function reply(status, body) {
  return {
    status,
    ok: status >= 200 && status < 300,
    json: async () => body,
    text: async () => (typeof body === 'string' ? body : JSON.stringify(body)),
  };
}

const ANSWER = {
  choices: [{ message: { content: '{"title": "x"}' }, finish_reason: 'stop' }],
  usage: {
    prompt_tokens: 5000, completion_tokens: 3000, total_tokens: 8000,
    completion_tokens_details: { reasoning_tokens: 2000 },
  },
};

function client(responses, options = {}) {
  const sent = [];
  const queue = [...responses];
  const fetchImpl = async (url, init) => {
    sent.push({ url, init, body: JSON.parse(init.body) });
    const next = queue.shift();
    if (next instanceof Error) throw next;
    return next;
  };
  return { sent, llm: createDeepSeek({ apiKey: 'sk-test', fetchImpl, ...options }) };
}

test('the request is the validated harness run\'s request', async () => {
  const { sent, llm } = client([reply(200, ANSWER)]);
  await llm.complete('the prompt');
  assert.equal(sent.length, 1);
  assert.equal(sent[0].url, DEFAULT_URL);
  assert.equal(sent[0].init.headers.Authorization, 'Bearer sk-test');
  assert.deepEqual(sent[0].body, {
    model: 'deepseek-flash',
    messages: [{ role: 'user', content: 'the prompt' }],
    response_format: { type: 'json_object' },
    max_tokens: 64000,
    temperature: 1.0,
    reasoning_effort: 'low',
  });
});

test('the answer, why it stopped, and every token count are read back', async () => {
  const { llm } = client([reply(200, ANSWER)]);
  const got = await llm.complete('p');
  assert.equal(got.content, '{"title": "x"}');
  assert.equal(got.finish, 'stop');
  assert.deepEqual(got.usage, { prompt: 5000, answer: 3000, thoughts: 2000, total: 8000 });
});

test('a refusal of response_format is survived once, without it', async () => {
  const { sent, llm } = client([
    reply(400, { error: { message: 'response_format is not supported' } }),
    reply(200, ANSWER),
  ]);
  await llm.complete('p');
  assert.equal(sent.length, 2);
  assert.equal('response_format' in sent[1].body, false);
});

test('any other 400 is a refusal, not a retry', async () => {
  const { sent, llm } = client([reply(400, { error: { message: 'bad model' } })]);
  await assert.rejects(llm.complete('p'), (e) => e instanceof LlmUnavailable && e.reason === 'refused');
  assert.equal(sent.length, 1);
});

test('each failure is its own reason', async () => {
  const cases = [
    [reply(401, {}), 'unauthorized'],
    [reply(402, {}), 'no-balance'],
    [reply(429, {}), 'rate-limited'],
    [reply(500, {}), 'provider'],
    [Object.assign(new Error('aborted'), { name: 'AbortError' }), 'timeout'],
    [new Error('ECONNRESET'), 'network'],
  ];
  for (const [response, reason] of cases) {
    const { llm } = client([response]);
    await assert.rejects(llm.complete('p'), (e) => e instanceof LlmUnavailable && e.reason === reason, reason);
  }
});

test('no key is not-configured, and nothing is sent', async () => {
  const sent = [];
  const llm = createDeepSeek({ apiKey: '', fetchImpl: async (...a) => { sent.push(a); } });
  assert.equal(llm.configured(), false);
  await assert.rejects(llm.complete('p'), (e) => e.reason === 'not-configured');
  assert.equal(sent.length, 0);
});

test('the key is never in a message', async () => {
  const { llm } = client([reply(401, {})]);
  await assert.rejects(llm.complete('p'), (e) => !e.message.includes('sk-test'));
});
