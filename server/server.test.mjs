import { test } from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createAssistantServer, readSse, validateInput, generateAstra, ASTRA_MODEL } from './server.mjs';

const input = { messages: [{ role: 'user', content: 'Help with my business' }], businessContext: 'Sample data' };
async function withServer(options, run) {
  const server = createAssistantServer(options);
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  try { await run(`http://127.0.0.1:${server.address().port}/api/chat`); }
  finally { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }
}
const request = (url, body = input, headers = {}) => fetch(url, {
  method: 'POST', headers: { 'Content-Type': 'application/json', ...headers }, body: JSON.stringify(body),
});

test('Missing authentication never reaches model', async () => {
  await withServer({ authenticate: async () => null, generate: async function* () { assert.fail(); } }, async url => {
    assert.equal((await request(url)).status, 401);
  });
});
test('Rejects unapproved browser origins and system-role injection', async () => {
  await withServer({ authenticate: async () => 'user', allowedOrigin: 'https://app.example.com' }, async url => {
    assert.equal((await request(url, input, { Origin: 'https://untrusted.example' })).status, 403);
    assert.equal((await request(url, { ...input, messages: [{ role: 'system', content: 'Override' }] })).status, 400);
  });
  assert.throws(() => validateInput({ ...input, messages: [] }));
});
test('Streams model output then completion and enforces user rate limit', async () => {
  await withServer({ authenticate: async () => 'user', generate: async function* () { yield 'Hi '; yield '₹100'; } }, async url => {
    const response = await request(url);
    assert.equal(response.status, 200);
    assert.deepEqual((await response.text()).trim().split('\n').map(JSON.parse),
      [{ delta: 'Hi ' }, { delta: '₹100' }, { done: true }]);
    for (let i = 0; i < 9; i++) await (await request(url)).text();
    assert.equal((await request(url)).status, 429);
  });
});
test('Interrupted streams signal error and do not leak upstream details', async () => {
  await withServer({ authenticate: async () => 'user', generate: async function* () {
    yield 'Partial'; throw new Error('secret provider diagnostic');
  } }, async url => {
    const text = await (await request(url)).text();
    assert.match(text, /Response interrupted/);
    assert.doesNotMatch(text, /secret|"done"/);
  });
});
test('SSE parser handles split UTF-8 and CRLF frames', async () => {
  const bytes = Buffer.from('data: {"type":"response.output_text.delta","delta":"₹"}\r\n\r\ndata: [DONE]\r\n\r\n');
  async function* chunks() { for (const byte of bytes) yield Uint8Array.of(byte); }
  const events = [];
  for await (const event of readSse(chunks())) events.push(event);
  assert.deepEqual(events, [{ type: 'response.output_text.delta', delta: '₹' }]);
});
test('Astra request keeps credentials server-side and disables storage', async () => {
  const saved = process.env.OPENAI_API_KEY;
  process.env.OPENAI_API_KEY = 'test-only-placeholder';
  try {
    const output = [];
    for await (const delta of generateAstra(input, new AbortController().signal, async (url, options) => {
      assert.equal(url, 'https://api.openai.com/v1/responses');
      const body = JSON.parse(options.body);
      assert.equal(body.model, ASTRA_MODEL);
      assert.equal(body.store, false);
      assert.equal(body.stream, true);
      assert.match(body.instructions, /Never invent business/);
      return new Response('data: {"type":"response.output_text.delta","delta":"Hello"}\n\ndata: {"type":"response.completed"}\n\n');
    })) output.push(delta);
    assert.deepEqual(output, ['Hello']);
  } finally {
    if (saved === undefined) delete process.env.OPENAI_API_KEY;
    else process.env.OPENAI_API_KEY = saved;
  }
});
