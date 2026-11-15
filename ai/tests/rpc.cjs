const http = require('node:http');
const { spawn } = require('node:child_process');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const calls = [];
const errors = [];
const server = http.createServer(async (request, response) => {
  try {
    let body = ''; for await (const chunk of request) body += chunk;
    const payload = JSON.parse(body);
    assert.ok(!payload.tools || payload.tools.length === 0, 'No tools may reach the provider');
    assert.equal(request.headers.authorization, 'Bearer synthetic-local-test-key');
    const raw = payload.messages.filter(message => message.role === 'user').at(-1).content;
    const text = typeof raw === 'string' ? raw : raw.filter(part => part.type === 'text').map(part => part.text).join('');
    const context = JSON.parse(text);
    assert.ok(context.fullBuffer.includes(context.selection));
    calls.push(context);
    response.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache' });
    const answer = JSON.stringify({ requestId: context.requestId, snapshotId: context.snapshotId,
      replacementText: 'replacement ' + context.selection, explanation: 'Synthetic local provider: selected text only.' });
    const event = data => response.write('data: ' + JSON.stringify(data) + '\n\n');
    event({ id: 'local-test', object: 'chat.completion.chunk', created: 1, model: 'test-model', choices: [{ index: 0, delta: { role: 'assistant' }, finish_reason: null }] });
    if (context.selection === 'CANCEL_ME') {
      event({ id: 'local-test', object: 'chat.completion.chunk', created: 1, model: 'test-model', choices: [{ index: 0, delta: { content: 'partial' }, finish_reason: null }] });
      await new Promise(resolve => setTimeout(resolve, 3000));
    }
    for (const part of answer.match(/.{1,7}/gu)) event({ id: 'local-test', object: 'chat.completion.chunk', created: 1, model: 'test-model', choices: [{ index: 0, delta: { content: part }, finish_reason: null }] });
    event({ id: 'local-test', object: 'chat.completion.chunk', created: 1, model: 'test-model', choices: [{ index: 0, delta: {}, finish_reason: 'stop' }] });
    response.end('data: [DONE]\n\n');
  } catch (error) { errors.push(error.message); response.writeHead(500); response.end('Local test failed'); }
});
server.listen(0, '127.0.0.1', () => {
  const executable = process.argv[2] || 'nvim';
  const child = spawn(executable, ['--headless', '-u', 'NONE', '-l', 'ai/tests/rpc.lua'], {
    cwd: root, stdio: 'inherit', env: { ...process.env, MOVIM_AI_TEST_NODE: process.execPath,
      MOVIM_AI_TEST_URL: `http://127.0.0.1:${server.address().port}/v1`, MOVIM_AI_TEST_KEY: 'synthetic-local-test-key' },
  });
  const timeout = setTimeout(() => { errors.push('Integration test timeout'); child.kill(); }, 300000);
  child.on('error', error => { errors.push(error.message); });
  child.on('close', code => {
    clearTimeout(timeout); server.closeAllConnections(); server.close();
    if (code !== 0 || errors.length || calls.length !== 3) {
      console.error({ code, errors, calls: calls.length }); process.exitCode = 1;
    } else console.log('PASS HTTP boundary: tool allowlist empty, full snapshots sent, independent request IDs');
  });
});
