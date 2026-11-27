// Fresh temporary installations; no network, editor state or real user files.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const engine = require('../lua/utils/update-engine.cjs');
const root = path.resolve(__dirname, '..');
const scratch = fs.mkdtempSync(path.join(root, '.update-test-'));
const write = (file, value) => { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, value); };
const json = value => Buffer.from(JSON.stringify(value));
function config(version, extra = {}) {
  const values = { 'init.lua': Buffer.from('-- version ' + version), 'lazy-lock.json': Buffer.from('{}\n'), 'lua/config/version.lua': Buffer.from(`return '${version}'`), ...extra };
  const manifest = { version, commit: 'test', files: Object.fromEntries(Object.entries(values).map(([n, b]) => [n, engine.digest(b)])) };
  return { ...values, 'release.json': json(manifest) };
}
function install(name, values) {
  const dir = path.join(scratch, name);
  for (const [n, b] of Object.entries(values)) write(path.join(dir, n), b);
  write(path.join(dir, 'user.lua'), '-- my preferences');
  write(path.join(dir, 'personal/note.txt'), 'personal');
  return dir;
}
function zip(values) {
  const local = [], central = []; let offset = 0;
  for (const [name, bytes] of Object.entries(values)) {
    const n = Buffer.from(name), l = Buffer.alloc(30), c = Buffer.alloc(46);
    l.writeUInt32LE(0x04034b50); l.writeUInt32LE(bytes.length, 18); l.writeUInt32LE(bytes.length, 22); l.writeUInt16LE(n.length, 26);
    c.writeUInt32LE(0x02014b50); c.writeUInt32LE(bytes.length, 20); c.writeUInt32LE(bytes.length, 24); c.writeUInt16LE(n.length, 28); c.writeUInt32LE(offset, 42);
    local.push(l, n, bytes); central.push(c, n); offset += l.length + n.length + bytes.length;
  }
  const directory = Buffer.concat(central), end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50); end.writeUInt16LE(Object.keys(values).length, 10); end.writeUInt32LE(directory.length, 12); end.writeUInt32LE(offset, 16);
  return Buffer.concat([...local, directory, end]);
}
function release(values, ai = false, badHash = false) {
  const archive = zip(Object.fromEntries(Object.entries(values).map(([n, b]) => ['movim-macOS/config/' + n, b])));
  const name = ai ? 'movim-AI-macOS.zip' : 'movim-macOS.zip';
  const info = { tag_name: 'v1.1.11', assets: [name, 'SHA256SUMS'].map(n => ({ name: n, browser_download_url: 'https://github.com/' + n })) };
  const fetch = async url => url.endsWith('SHA256SUMS') ? Buffer.from((badHash ? '0'.repeat(64) : engine.digest(archive)) + '  ' + name + '\n') : archive;
  return { info, fetch, archive };
}
const before = config('1.1.10', { 'lua/obsolete.lua': Buffer.from('-- old') });
const after = config('1.1.11', { 'lua/new.lua': Buffer.from('-- new') });
const fixture = release(after);
async function prepare(dir, sample = fixture) { return engine.prepare(dir, sample.info, sample.fetch); }
function ai(values) {
  const entries = { 'README.md': Buffer.from('AI'), 'runtime/package.json': json({ name: 'movim-update-test', version: '1.0.0' }), 'runtime/package-lock.json': json({ name: 'movim-update-test', version: '1.0.0', lockfileVersion: 3, packages: { '': { name: 'movim-update-test', version: '1.0.0' } } }), 'lua/movim_ai/init.lua': Buffer.from('return {}') };
  const m = { version: JSON.parse(values['release.json']).version, commit: 'test', files: Object.fromEntries(Object.entries(entries).map(([n, b]) => [n, engine.digest(b)])) };
  return { ...values, ...Object.fromEntries(Object.entries(entries).map(([n, b]) => ['ai/' + n, b])), 'ai/ai-release.json': json(m) };
}
(async () => {
  const immediate = install('immediate', before);
  const limited = async url => {
    if (url.startsWith('https://api.github.com/')) throw Error('Download failed: HTTP 403');
    assert(url.startsWith('https://github.com/moeinparvizi/movim/releases/latest/download/'));
    return fixture.fetch(url);
  };
  assert.equal((await engine.prepare(immediate, null, limited, true)).status, 'installed');
  assert.deepEqual(fs.readFileSync(path.join(immediate, 'release.json')), after['release.json']);
  assert(!fs.existsSync(path.join(immediate, '.movim-update/pending.json')));
  assert.equal((await engine.prepare(immediate, null, limited, true)).status, 'current');
  console.log('PASS one-command installation and rate-limited GitHub API fallback');
  const shared = 'lua/parsers/windows-x64/angular.so';
  const parser = fs.readFileSync(path.join(root, shared));
  const parserRoot = install('loaded-parser', config('1.1.10', { [shared]: parser }));
  await prepare(parserRoot, release(config('1.1.11', { [shared]: parser })));
  const originalParser = fs.statSync(path.join(parserRoot, shared), { bigint: true });
  const replaced = [];
  if (process.platform === 'win32' && process.argv[2]) {
    const child = spawnSync(process.argv[2], ['--headless','-u','NONE','-l','tests/update-loaded-parser.lua'], {
      cwd:root, encoding:'utf8', timeout:30000, env:{...process.env, MOVIM_PARSER_FIXTURE:parserRoot,
        MOVIM_PARSER_ENGINE:require.resolve('../lua/utils/update-engine.cjs'), MOVIM_TEST_NODE:process.execPath}
    });
    assert.equal(child.status,0,child.error?.message || child.stderr || child.stdout);
  } else {
    await engine.apply(parserRoot, {afterWrite: name => replaced.push(name)});
  }
  assert(!replaced.includes(shared));
  assert.equal(fs.statSync(path.join(parserRoot, shared), {bigint:true}).ino, originalParser.ino);
  console.log('PASS unchanged native parser is never replaced during installation');
  const dir = install('regular', before);
  write(path.join(dir, 'init.lua.tmp'), 'personal temporary file');
  const state = path.join(scratch, 'state/workspace.json'); write(state, '{"draft":"unsaved"}');
  assert.equal((await prepare(dir)).status, 'ready');
  assert.deepEqual(fs.readFileSync(path.join(dir, 'init.lua')), before['init.lua'], 'download must not change running config');
  const result = await engine.apply(dir);
  assert.equal(result.status, 'installed');
  for (const [n, b] of Object.entries(after)) assert.deepEqual(fs.readFileSync(path.join(dir, n)), b);
  assert.equal(fs.existsSync(path.join(dir, 'lua/obsolete.lua')), false);
  assert.equal(fs.readFileSync(path.join(dir, 'user.lua'), 'utf8'), '-- my preferences');
  assert.equal(fs.readFileSync(path.join(dir, 'personal/note.txt'), 'utf8'), 'personal');
  assert.equal(fs.readFileSync(path.join(dir, 'init.lua.tmp'), 'utf8'), 'personal temporary file');
  assert.equal(fs.readFileSync(state, 'utf8'), '{"draft":"unsaved"}');
  assert.deepEqual(fs.readFileSync(path.join(result.backup, 'init.lua')), before['init.lua']);
  assert.equal((await prepare(dir)).status, 'current');
  assert.equal((await engine.apply(dir)).status, 'none');
  console.log('PASS staged update, versions, obsolete files, backups, personal files and workspace preservation');

  const modified = install('modified', before); write(path.join(modified, 'init.lua'), '-- custom');
  await assert.rejects(prepare(modified), /Local changes preserved/);
  assert.equal(fs.readFileSync(path.join(modified, 'init.lua'), 'utf8'), '-- custom');
  const late = install('late-edit', before); await prepare(late); write(path.join(late, 'lua/obsolete.lua'), '-- custom after download');
  await assert.rejects(engine.apply(late), /Local changes preserved/);
  assert.deepEqual(fs.readFileSync(path.join(late, 'init.lua')), before['init.lua']);
  console.log('PASS pre-download and post-download local edit protection');

  const failed = install('failed', before); await prepare(failed);
  await assert.rejects(engine.apply(failed, { afterWrite: () => { throw Error('simulated write failure'); } }), /simulated/);
  for (const [n, b] of Object.entries(before)) assert.deepEqual(fs.readFileSync(path.join(failed, n)), b);
  assert.equal(fs.existsSync(path.join(failed, 'lua/new.lua')), false);
  assert.equal((await engine.apply(failed)).status, 'installed');
  console.log('PASS failed write rolls back and can retry');

  const killed = install('interrupted', before); await prepare(killed);
  const child = spawnSync(process.execPath, ['-e', `require(${JSON.stringify(require.resolve('../lua/utils/update-engine.cjs'))}).apply(${JSON.stringify(killed)}, {afterWrite:()=>process.exit(23)})`]);
  assert.equal(child.status, 23);
  assert.equal((await engine.apply(killed)).status, 'recovered');
  for (const [n, b] of Object.entries(before)) assert.deepEqual(fs.readFileSync(path.join(killed, n)), b);
  assert.equal((await engine.apply(killed)).status, 'installed');
  console.log('PASS recovery after real process interruption');

  const brokenJournal = install('bad-journal', before);
  write(path.join(brokenJournal, '.movim-update/transaction.json'), JSON.stringify({ backup: '../personal', stage: 'stage-123', entries: [{ name: 'user.lua', existed: false }] }));
  await assert.rejects(engine.apply(brokenJournal), /Invalid recovery journal/);
  assert.equal(fs.readFileSync(path.join(brokenJournal, 'user.lua'), 'utf8'), '-- my preferences');
  console.log('PASS corrupt recovery journal cannot remove personal files');

  const corrupt = install('corrupt', before);
  await assert.rejects(prepare(corrupt, release(after, false, true)), /checksum mismatch/);
  const invalid = { ...after, 'init.lua': Buffer.from('tampered') };
  await assert.rejects(prepare(corrupt, release(invalid)), /hash mismatch/);
  await assert.rejects(engine.prepare(corrupt, fixture.info, async () => { throw Error('offline'); }), /offline/);
  await prepare(corrupt);
  const pending = JSON.parse(fs.readFileSync(path.join(corrupt, '.movim-update/pending.json')));
  write(path.join(corrupt, '.movim-update', pending.stage, 'init.lua'), 'changed stage');
  await assert.rejects(engine.apply(corrupt), /hash mismatch/);
  console.log('PASS network, checksum, per-file hash and stage tampering failures leave old version intact');

  assert.throws(() => engine.unzip(zip({ '../escape': Buffer.from('x') })), /Unsafe/);
  assert.throws(() => engine.unzip(zip({ 'A': Buffer.from('x'), 'a': Buffer.from('y') })), /Duplicate/);
  await assert.rejects(engine.download('http://github.com/test'), /Untrusted/);
  await assert.rejects(engine.download('https://example.com/test'), /Untrusted/);
  const source = install('source', before); fs.mkdirSync(path.join(source, '.git'));
  await assert.rejects(prepare(source), /source checkout/);
  const locked = install('locked', before); write(path.join(locked, '.movim-update/lock'), String(process.pid));
  await assert.rejects(prepare(locked), /Another update/);
  console.log('PASS traversal, duplicate entries, untrusted URLs, source checkout and concurrent updater guards');

  const aiRoot = install('ai', ai(before)); write(path.join(aiRoot, 'ai/runtime/node_modules/keep.txt'), 'runtime stays');
  const aiFixture = release(ai(after), true);
  await prepare(aiRoot, aiFixture); assert.equal((await engine.apply(aiRoot)).status, 'installed');
  assert.equal(fs.readFileSync(path.join(aiRoot, 'ai/runtime/node_modules/keep.txt'), 'utf8'), 'runtime stays');
  assert.equal(JSON.parse(fs.readFileSync(path.join(aiRoot, 'ai/ai-release.json'))).version, '1.1.11');
  console.log('PASS AI edition updates together and keeps unchanged Pi runtime');

  const unifiedRoot = install('unified-migration', before);
  await prepare(unifiedRoot, release(ai(after)));
  assert.equal((await engine.apply(unifiedRoot)).status, 'installed');
  assert.equal(JSON.parse(fs.readFileSync(path.join(unifiedRoot, 'ai/ai-release.json'))).version, '1.1.11');
  assert.equal(fs.readFileSync(path.join(unifiedRoot, 'user.lua'), 'utf8'), '-- my preferences');
  console.log('PASS standard installation gains AI and preserves personal settings');

  const runtimeRoot = install('ai-runtime', ai(before));
  write(path.join(runtimeRoot, 'ai/runtime/node_modules/old.txt'), 'old Pi dependency');
  const changedRuntime = ai(after);
  changedRuntime['ai/runtime/package-lock.json'] = json({ name: 'movim-update-test', version: '1.0.0', lockfileVersion: 3, requires: true, packages: { '': { name: 'movim-update-test', version: '1.0.0' } } });
  const changedManifest = JSON.parse(changedRuntime['ai/ai-release.json']);
  changedManifest.files['runtime/package-lock.json'] = engine.digest(changedRuntime['ai/runtime/package-lock.json']);
  changedRuntime['ai/ai-release.json'] = json(changedManifest);
  await prepare(runtimeRoot, release(changedRuntime, true));
  assert.equal(fs.readFileSync(path.join(runtimeRoot, 'ai/runtime/node_modules/old.txt'), 'utf8'), 'old Pi dependency');
  await assert.rejects(engine.apply(runtimeRoot, { afterWrite: () => { throw Error('AI write failure'); } }), /AI write failure/);
  assert.equal(fs.readFileSync(path.join(runtimeRoot, 'ai/runtime/node_modules/old.txt'), 'utf8'), 'old Pi dependency');
  // Rollback also returns the prepared runtime to staging for an offline retry.
  assert.equal((await engine.apply(runtimeRoot)).status, 'installed');
  assert.equal(fs.existsSync(path.join(runtimeRoot, 'ai/runtime/node_modules/old.txt')), false);
  console.log('PASS changed AI runtime is prepared before mutation and restored on failed apply');

  const sourcePackage = install('package-source', after), targetPackage = install('package-target', before);
  assert.equal((await engine.fromPackage(targetPackage, sourcePackage)).status, 'installed');
  assert.equal(fs.readFileSync(path.join(targetPackage, 'user.lua'), 'utf8'), '-- my preferences');
  const installerRoot = install('installer', before);
  const checked = engine.installerCheck(installerRoot, path.join(sourcePackage, 'release.json'));
  assert.deepEqual(fs.readFileSync(path.join(checked.backup, 'init.lua')), before['init.lua']);
  write(path.join(installerRoot, 'init.lua'), '-- personal edit');
  assert.throws(() => engine.installerCheck(installerRoot, path.join(sourcePackage, 'release.json')), /Local changes preserved/);
  console.log('PASS Unix package upgrade and Windows installer preflight preserve personal settings');

  const pluginRoot = install('plugins', before);
  const pluginAfter = config('1.1.11', { 'lazy-lock.json': Buffer.from('{"test":{}}\n') });
  await prepare(pluginRoot, release(pluginAfter)); await engine.apply(pluginRoot);
  assert.equal(JSON.parse(fs.readFileSync(path.join(pluginRoot, '.movim-update/sync.json'))).version, '1.1.11');
  console.log('PASS changed release lockfile queues plugin synchronization');

  const nvim = process.argv[2];
  if (nvim) {
    const code = fs.readFileSync(path.join(root, 'lua/utils/update-engine.cjs'));
    const uiRoot = install('editor-bootstrap', config('1.1.10', { 'lua/utils/update-engine.cjs': code }));
    await prepare(uiRoot, release(config('1.1.11', { 'lua/utils/update-engine.cjs': code })));
    const run = spawnSync(nvim, ['--headless', '-u', 'NONE', '-l', 'tests/updates.lua'], {
      cwd: root, encoding: 'utf8', timeout: 30000,
      env: { ...process.env, MOVIM_UPDATE_TEST_ROOT: uiRoot, PATH: path.dirname(process.execPath) + path.delimiter + process.env.PATH },
    });
    process.stdout.write((run.stdout || '') + (run.stderr || ''));
    if (run.error) throw run.error;
    assert.equal(run.status, 0, 'Neovim updater integration failed');
  }

  // Read an actual distributed ZIP as well as synthetic edge cases.
  const archive = path.join(root, '../movim-macOS.zip');
  if (fs.existsSync(archive)) {
    const entries = engine.unzip(fs.readFileSync(archive));
    const version = JSON.parse(entries.get('movim-macOS/config/release.json')).version;
    assert(engine.packageFiles(entries, version, false).size > 50);
    console.log('PASS actual macOS distribution archive and all file hashes');
  }
})().catch(error => { console.error(error); process.exitCode = 1; }).finally(() => {
  if (path.dirname(scratch) !== root || !path.basename(scratch).startsWith('.update-test-')) throw Error('Unsafe cleanup');
  fs.rmSync(scratch, { recursive: true, force: true });
});
