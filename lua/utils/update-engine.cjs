// Runs out of process. Only files named by the checked release manifest are updated.
const fs = require('node:fs');
const path = require('node:path');
const https = require('node:https');
const zlib = require('node:zlib');
const { createHash } = require('node:crypto');
const { spawnSync } = require('node:child_process');
const api = 'https://api.github.com/repos/moeinparvizi/movim/releases/latest';
const digest = data => createHash('sha256').update(data).digest('hex');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const exists = file => fs.existsSync(file);
const atomic = (file, data) => {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file + '.tmp', data, { flush: true });
  fs.renameSync(file + '.tmp', file);
};
const json = (file, data) => atomic(file, JSON.stringify(data, null, 2) + '\n');
function safeName(name) {
  if (typeof name !== 'string' || !name || name.includes('\\') || name.includes(':') || name.includes('\0') ||
      name.split('/').some(s => !s || s === '.' || s === '..' || /[. ]$/.test(s) || /^(con|prn|aux|nul|com[0-9]|lpt[0-9])(\.|$)/i.test(s))) throw Error('Unsafe release path: ' + name);
  return name;
}
function target(root, name) {
  safeName(name);
  let current = root;
  for (const part of name.split('/')) {
    current = path.join(current, part);
    if (exists(current) && fs.lstatSync(current).isSymbolicLink()) throw Error('Symlink in update path: ' + name);
  }
  return current;
}
function newer(a, b) {
  const parse = v => { if (!/^v?\d+\.\d+\.\d+$/.test(v)) throw Error('Invalid release version'); return v.replace(/^v/, '').split('.').map(Number); };
  const x = parse(a), y = parse(b);
  for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return y[i] > x[i];
  return false;
}
function download(url, limit = 40 * 1024 * 1024, redirects = 0) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    if (u.protocol !== 'https:' || !['api.github.com', 'github.com', 'release-assets.githubusercontent.com', 'objects.githubusercontent.com'].includes(u.hostname) || redirects > 5) return reject(Error('Untrusted release URL'));
    const req = https.get(u, { headers: { 'User-Agent': 'movim-updater', Accept: 'application/vnd.github+json' } }, res => {
      if ([301, 302, 303, 307, 308].includes(res.statusCode)) {
        res.resume(); download(new URL(res.headers.location, u).href, limit, redirects + 1).then(resolve, reject); return;
      }
      if (res.statusCode !== 200) { res.resume(); reject(Error('Download failed: HTTP ' + res.statusCode)); return; }
      let size = 0; const chunks = [];
      res.on('data', chunk => { size += chunk.length; if (size > limit) res.destroy(Error('Release download too large')); else chunks.push(chunk); });
      res.on('error', reject); res.on('end', () => resolve(Buffer.concat(chunks)));
    });
    const timer = setTimeout(() => req.destroy(Error('Download timed out')), 120000);
    req.on('close', () => clearTimeout(timer)); req.on('error', reject);
  });
}
function unzip(bytes) {
  let end = -1;
  for (let i = bytes.length - 22; i >= Math.max(0, bytes.length - 65557); i--) {
    if (bytes.readUInt32LE(i) === 0x06054b50 && i + 22 + bytes.readUInt16LE(i + 20) === bytes.length) { end = i; break; }
  }
  if (end < 0) throw Error('Invalid release ZIP');
  let offset = bytes.readUInt32LE(end + 16), total = 0;
  const files = new Map(), seen = new Set();
  for (let i = 0; i < bytes.readUInt16LE(end + 10); i++) {
    if (bytes.readUInt32LE(offset) !== 0x02014b50) throw Error('Invalid ZIP directory');
    const method = bytes.readUInt16LE(offset + 10), size = bytes.readUInt32LE(offset + 24);
    const packed = bytes.readUInt32LE(offset + 20), length = bytes.readUInt16LE(offset + 28);
    const name = bytes.subarray(offset + 46, offset + 46 + length).toString('utf8');
    const local = bytes.readUInt32LE(offset + 42), mode = bytes.readUInt32LE(offset + 38) >>> 16;
    offset += 46 + length + bytes.readUInt16LE(offset + 30) + bytes.readUInt16LE(offset + 32);
    safeName(name.replace(/\/$/, ''));
    if ((mode & 0o170000) === 0o120000) throw Error('Symlink in release archive');
    const key = name.toLowerCase();
    if (seen.has(key)) throw Error('Duplicate release path');
    seen.add(key);
    if (name.endsWith('/')) continue;
    if (bytes.readUInt32LE(local) !== 0x04034b50 || ![0, 8].includes(method) || size > 16 * 1024 * 1024) throw Error('Unsupported ZIP entry');
    const start = local + 30 + bytes.readUInt16LE(local + 26) + bytes.readUInt16LE(local + 28);
    const data = method === 0 ? bytes.subarray(start, start + packed) : zlib.inflateRawSync(bytes.subarray(start, start + packed), { maxOutputLength: 16 * 1024 * 1024 });
    total += data.length;
    if (data.length !== size || total > 100 * 1024 * 1024) throw Error('Invalid ZIP size');
    files.set(name, data);
  }
  return files;
}
function manifest(value, ai = false) {
  if (!value || !/^\d+\.\d+\.\d+$/.test(value.version) || !value.files || typeof value.files !== 'object' || Array.isArray(value.files)) throw Error('Invalid release manifest');
  const entries = Object.entries(value.files);
  if (!entries.length || entries.length > 2000) throw Error('Invalid manifest size');
  const seen = new Set();
  for (const [name, hash] of entries) {
    safeName(name);
    const allowed = ai ? /^(README\.md|runtime\/package(-lock)?\.json|lua\/.+)$/ : /^(init\.lua|lazy-lock\.json|README\.md|LICENSE|CHANGELOG\.md|site\/docs-en\/README\.md|(lua|colors|keymap|docs|fonts)\/.+)$/;
    if (!allowed.test(name) || !/^[a-f0-9]{64}$/.test(hash) || seen.has(name.toLowerCase())) throw Error('Invalid manifest entry: ' + name);
    seen.add(name.toLowerCase());
  }
  if (!ai && !value.files['init.lua']) throw Error('Incomplete base manifest');
  return value;
}
function packageFiles(files, expectedVersion, ai) {
  const prefix = 'movim-macOS/config/';
  const base = manifest(JSON.parse(files.get(prefix + 'release.json')));
  if (base.version !== expectedVersion) throw Error('Release version mismatch');
  const result = new Map();
  function add(m, dir, manifestName) {
    for (const [name, hash] of Object.entries(m.files)) {
      const data = files.get(prefix + dir + name);
      if (!data || digest(data) !== hash) throw Error('Release hash mismatch: ' + dir + name);
      result.set(dir + name, data);
    }
    result.set(manifestName, files.get(prefix + manifestName));
  }
  add(base, '', 'release.json');
  if (ai) {
    const extra = manifest(JSON.parse(files.get(prefix + 'ai/ai-release.json')), true);
    if (extra.version !== base.version || extra.commit !== base.commit) throw Error('AI and base releases differ');
    add(extra, 'ai/', 'ai/ai-release.json');
  }
  return result;
}
function oldFiles(root) {
  const base = manifest(read(path.join(root, 'release.json')));
  const result = { ...base.files };
  if (exists(path.join(root, 'ai/ai-release.json'))) {
    const ai = manifest(read(path.join(root, 'ai/ai-release.json')), true);
    for (const [name, hash] of Object.entries(ai.files)) result['ai/' + name] = hash;
  }
  return result;
}
function installerCheck(root, source, aiSource) {
  root = fs.realpathSync(root);
  if (exists(path.join(root, '.git'))) throw Error('Use Git to update this source checkout.');
  const base = manifest(read(source)), incoming = { ...base.files };
  if (aiSource) for (const [name, hash] of Object.entries(manifest(read(aiSource), true).files)) incoming['ai/' + name] = hash;
  const old = oldFiles(root), dir = area(root);
  if (exists(path.join(dir, 'pending.json')) || exists(path.join(dir, 'transaction.json'))) throw Error('Open movim to complete or recover the pending update before running the installer.');
  for (const [name, hash] of Object.entries(old)) {
    const file = target(root, name);
    if (exists(file)) {
      const actual = digest(fs.readFileSync(file));
      if (actual !== hash && actual !== incoming[name]) throw Error('Local changes preserved: ' + name + '. Move your preferences to user.lua or merge this file before upgrading.');
    }
  }
  for (const [name, hash] of Object.entries(incoming)) {
    const file = target(root, name);
    if (!old[name] && exists(file) && digest(fs.readFileSync(file)) !== hash) throw Error('Personal file conflicts with new release: ' + name);
  }
  const backup = target(dir, 'backups/installer-' + Date.now());
  for (const name of [...new Set([...Object.keys(old), ...Object.keys(incoming)]) , 'release.json', ...(aiSource ? ['ai/ai-release.json'] : [])]) {
    const file = target(root, name);
    if (exists(file)) atomic(target(backup, name), fs.readFileSync(file));
  }
  return { status: 'checked', backup };
}
function preflight(root, files) {
  const old = oldFiles(root), conflicts = [];
  for (const name of new Set([...Object.keys(old), ...files.keys()])) {
    const file = target(root, name);
    if (!exists(file) || name === 'release.json' || name === 'ai/ai-release.json') continue;
    const hash = digest(fs.readFileSync(file));
    if (hash !== old[name] && (!files.has(name) || hash !== digest(files.get(name)))) conflicts.push(name);
  }
  if (conflicts.length) throw Error('Local changes preserved. Update stopped; move custom settings to user.lua or merge these files first: ' + conflicts.join(', '));
  return old;
}
function area(root) {
  const dir = target(root, '.movim-update');
  fs.mkdirSync(dir, { recursive: true }); return dir;
}
function lock(dir, work) {
  const file = path.join(dir, 'lock');
  try { fs.writeFileSync(file, String(process.pid), { flag: 'wx' }); }
  catch (error) {
    if (error.code !== 'EEXIST') throw error;
    const pid = Number(fs.readFileSync(file, 'utf8'));
    try { process.kill(pid, 0); throw Error('Another update is running'); }
    catch (failure) { if (failure.code !== 'ESRCH') throw failure; }
    fs.unlinkSync(file); return lock(dir, work);
  }
  return Promise.resolve().then(work).finally(() => fs.unlinkSync(file));
}
async function stageFiles(root, dir, files, version) {
  preflight(root, files);
  const stage = path.join(dir, 'stage-' + Date.now()); fs.mkdirSync(stage);
  try {
    for (const [name, data] of files) atomic(target(stage, name), data);
    let runtime = false;
    if (files.has('ai/runtime/package-lock.json') &&
        (!exists(path.join(root, 'ai/runtime/node_modules')) || digest(files.get('ai/runtime/package-lock.json')) !== digest(fs.readFileSync(path.join(root, 'ai/runtime/package-lock.json'))))) {
      const npm = path.join(path.dirname(process.execPath), 'node_modules/npm/bin/npm-cli.js');
      if (!exists(npm)) throw Error('npm is required to prepare the new AI runtime. Install Node.js with npm.');
      const install = spawnSync(process.execPath, [npm, 'ci', '--ignore-scripts', '--no-audit', '--no-fund'], { cwd: path.join(stage, 'ai/runtime'), encoding: 'utf8', timeout: 300000, windowsHide: true });
      if (install.error || install.status !== 0) throw Error('AI runtime preparation failed; installed version is unchanged. ' + (install.error?.message || install.stderr || '').slice(-1200));
      fs.mkdirSync(path.join(stage, 'ai/runtime/node_modules'), { recursive: true });
      runtime = true;
    }
    json(path.join(dir, 'pending.json'), { stage: path.basename(stage), version, runtime });
    return { status: 'ready', version };
  } catch (error) { fs.rmSync(stage, { recursive: true, force: true }); throw error; }
}
async function prepare(root, release, fetch = download) {
  root = fs.realpathSync(root);
  if (exists(path.join(root, '.git'))) throw Error('This is a source checkout. Update it with Git instead.');
  const dir = area(root);
  return lock(dir, async () => {
    if (exists(path.join(dir, 'transaction.json'))) throw Error('Restart movim to recover the previous update first.');
    const current = manifest(read(path.join(root, 'release.json'))).version;
    if (!release) release = JSON.parse(await fetch(api, 2 * 1024 * 1024));
    if (release.draft || release.prerelease || !newer(current, release.tag_name)) return { status: 'current', version: current };
    const ai = exists(path.join(root, 'ai/ai-release.json'));
    const name = ai ? 'movim-AI-macOS.zip' : 'movim-macOS.zip';
    const asset = n => release.assets?.find(a => a.name === n)?.browser_download_url;
    if (!asset(name) || !asset('SHA256SUMS')) throw Error('Release assets are incomplete');
    const sums = (await fetch(asset('SHA256SUMS'), 65536)).toString('utf8');
    const expected = sums.split(/\r?\n/).map(line => line.trim().split(/\s+\*?/)).find(parts => parts[1] === name)?.[0];
    if (!/^[a-f0-9]{64}$/.test(expected || '')) throw Error('Release checksum missing');
    const archive = await fetch(asset(name));
    if (digest(archive) !== expected) throw Error('Download checksum mismatch');
    const version = release.tag_name.replace(/^v/, '');
    const files = packageFiles(unzip(archive), version, ai);
    return stageFiles(root, dir, files, version);
  });
}
async function fromPackage(root, source) {
  root = fs.realpathSync(root); source = fs.realpathSync(source);
  if (exists(path.join(root, '.git'))) throw Error('Use Git to update this source checkout.');
  const dir = area(root), base = manifest(read(path.join(source, 'release.json'))), files = new Map();
  for (const name of [...Object.keys(base.files), 'release.json']) files.set('movim-macOS/config/' + name, fs.readFileSync(target(source, name)));
  const aiFile = path.join(source, 'ai/ai-release.json');
  if (exists(aiFile)) {
    const ai = manifest(read(aiFile), true);
    for (const name of [...Object.keys(ai.files), 'ai-release.json']) files.set('movim-macOS/config/ai/' + name, fs.readFileSync(target(source, 'ai/' + name)));
  }
  if (exists(path.join(root, 'ai/ai-release.json')) !== exists(aiFile)) throw Error('Choose the installer matching your movim edition.');
  await lock(dir, () => stageFiles(root, dir, packageFiles(files, base.version, exists(aiFile)), base.version));
  return apply(root);
}
function rollback(root, dir, journal) {
  for (const entry of [...journal.entries].reverse()) {
    const dest = target(root, entry.name), saved = target(path.join(dir, journal.backup), entry.name);
    if (entry.existed) { if (exists(saved)) atomic(dest, fs.readFileSync(saved)); }
    else if (exists(dest)) fs.unlinkSync(dest);
  }
  if (journal.runtime) {
    const dest = target(root, 'ai/runtime/node_modules'), saved = target(path.join(dir, journal.backup), 'node_modules');
    const staged = target(dir, safeName(journal.stage) + '/ai/runtime/node_modules');
    if (exists(dest) && !exists(staged) && (exists(saved) || !journal.hadRuntime)) {
      fs.mkdirSync(path.dirname(staged), { recursive: true }); fs.renameSync(dest, staged);
    }
    if (exists(saved)) { fs.rmSync(dest, { recursive: true, force: true }); fs.renameSync(saved, dest); }
    else if (!journal.hadRuntime) fs.rmSync(dest, { recursive: true, force: true });
  }
  if (exists(path.join(dir, 'sync.json'))) fs.unlinkSync(path.join(dir, 'sync.json'));
  fs.unlinkSync(path.join(dir, 'transaction.json'));
}
async function apply(root, hooks = {}) {
  root = fs.realpathSync(root); const dir = area(root);
  return lock(dir, () => {
    const transaction = path.join(dir, 'transaction.json');
    if (exists(transaction)) { rollback(root, dir, read(transaction)); return { status: 'recovered' }; }
    const pending = path.join(dir, 'pending.json');
    if (!exists(pending)) return { status: 'none' };
    const info = read(pending);
    if (!/^stage-\d+$/.test(info.stage)) throw Error('Invalid update stage');
    const stage = target(dir, info.stage), staged = new Map();
    const base = manifest(read(path.join(stage, 'release.json')));
    const installed = manifest(read(path.join(root, 'release.json'))).version;
    if (newer(base.version, installed)) throw Error('A newer version is already installed; staged downgrade refused.');
    for (const name of [...Object.keys(base.files), 'release.json']) staged.set(name, fs.readFileSync(target(stage, name)));
    const aiFile = path.join(stage, 'ai/ai-release.json');
    if (exists(aiFile)) {
      const ai = manifest(read(aiFile), true);
      for (const name of [...Object.keys(ai.files), 'ai-release.json']) staged.set('ai/' + name, fs.readFileSync(target(stage, 'ai/' + name)));
    }
    // Verify the disk stage again, including edits made after downloading.
    const archiveMap = new Map([...staged].map(([name, data]) => ['movim-macOS/config/' + name, data]));
    packageFiles(archiveMap, info.version, exists(aiFile));
    const old = preflight(root, staged);
    const backup = 'backups/' + Date.now();
    const journal = { backup, stage: info.stage, entries: [], runtime: info.runtime, hadRuntime: exists(target(root, 'ai/runtime/node_modules')) };
    fs.mkdirSync(target(dir, backup), { recursive: true });
    // Back up every affected file before publishing a write-ahead journal.
    for (const name of new Set([...Object.keys(old), ...staged.keys()])) {
      const dest = target(root, name), existed = exists(dest);
      if (existed) atomic(target(path.join(dir, backup), name), fs.readFileSync(dest));
      journal.entries.push({ name, existed });
    }
    json(transaction, journal);
    try {
      if (info.runtime) {
        const dest = target(root, 'ai/runtime/node_modules');
        if (exists(dest)) fs.renameSync(dest, target(path.join(dir, backup), 'node_modules'));
        fs.renameSync(target(stage, 'ai/runtime/node_modules'), dest);
      }
      for (const entry of journal.entries) {
        if (staged.has(entry.name)) atomic(target(root, entry.name), staged.get(entry.name));
        else if (exists(target(root, entry.name))) fs.unlinkSync(target(root, entry.name));
        if (hooks.afterWrite) hooks.afterWrite(entry.name);
      }
      // Marker survives a restart or failed plugin sync; removed only after success.
      if (old['lazy-lock.json'] !== digest(staged.get('lazy-lock.json'))) json(path.join(dir, 'sync.json'), { version: info.version });
      fs.unlinkSync(pending);
      fs.unlinkSync(transaction);
      // Commit is complete; failure to remove a temporary stage must not roll back.
      try { fs.rmSync(stage, { recursive: true, force: true }); } catch (_) {}
      return { status: 'installed', version: info.version, backup: path.join(dir, backup) };
    } catch (error) { rollback(root, dir, journal); throw error; }
  });
}
module.exports = { prepare, apply, fromPackage, installerCheck, unzip, packageFiles, preflight, newer, download, digest };
if (require.main === module) {
  const [mode, root, source, aiSource] = process.argv.slice(2);
  Promise.resolve().then(() => mode === 'prepare' ? prepare(root) : mode === 'apply' ? apply(root) : mode === 'local' ? fromPackage(root, source) : mode === 'check' ? installerCheck(root, source, aiSource) : Promise.reject(Error('Unknown updater mode')))
    .then(result => console.log(JSON.stringify(result))).catch(error => {
      if (mode === 'check') { try { atomic(path.join(area(root), 'install-error.txt'), error.message); } catch (_) {} }
      console.error(error.message); process.exitCode = 1;
    });
}
