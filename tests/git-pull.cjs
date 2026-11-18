const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const source = path.resolve(__dirname, '..');
const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'movim-git-pull-'));
const workspace = path.join(scratch, 'workspace');
function run(cwd, ...args) {
  const r = spawnSync('git', args, { cwd, encoding: 'utf8', env: { ...process.env, GIT_TERMINAL_PROMPT: '0' } });
  if (r.status !== 0) throw Error(`git ${args.join(' ')}: ${r.stderr}`);
}
function configure(cwd) { run(cwd, 'config', 'user.name', 'Test'); run(cwd, 'config', 'user.email', 'test@example.invalid'); }
try {
  fs.mkdirSync(workspace);
  for (const [name, target] of [['conflict', 'a'], ['clean', 'deep/one/two/three/b']]) {
    const bare = path.join(scratch, name + '.git');
    const seed = path.join(scratch, name + '-seed');
    const local = path.join(workspace, target);
    run(scratch, 'init', '--bare', bare);
    run(scratch, 'clone', bare, seed);
    configure(seed);
    fs.writeFileSync(path.join(seed, 'file.txt'), 'base\n');
    run(seed, 'add', 'file.txt'); run(seed, 'commit', '-m', 'base'); run(seed, 'push', '-u', 'origin', 'HEAD');
    fs.mkdirSync(path.dirname(local), { recursive: true });
    run(scratch, 'clone', bare, local); configure(local);
    if (name === 'conflict') {
      fs.writeFileSync(path.join(local, 'file.txt'), 'local\n');
      run(local, 'commit', '-am', 'local');
    }
    fs.writeFileSync(path.join(seed, 'file.txt'), 'remote\n');
    run(seed, 'commit', '-am', 'remote'); run(seed, 'push');
  }
  const r = spawnSync(process.argv[2] || 'nvim', ['--headless', '-u', 'NONE', '-l', 'tests/git-pull.lua'], {
    cwd: source, env: { ...process.env, MOVIM_GIT_TEST_WORKSPACE: workspace }, encoding: 'utf8', timeout: 60000,
  });
  process.stdout.write((r.stdout || '') + (r.stderr || ''));
  if (r.error) throw r.error;
  if (r.status !== 0) throw Error('Git pull integration failed');
  if (fs.readFileSync(path.join(workspace, 'deep/one/two/three/b/file.txt'), 'utf8').replaceAll('\r\n', '\n') !== 'remote\n') throw Error('Nested repository did not update');
  const conflict = fs.readFileSync(path.join(workspace, 'a/file.txt'), 'utf8');
  if (!conflict.includes('<<<<<<<') || !conflict.includes('local') || !conflict.includes('remote')) throw Error('Conflict not preserved');
  console.log('PASS real nested pulls and conflict preservation');
} finally {
  if (path.dirname(scratch) !== os.tmpdir() || !path.basename(scratch).startsWith('movim-git-pull-')) throw Error('Unsafe cleanup');
  fs.rmSync(scratch, { recursive: true, force: true, maxRetries: 10, retryDelay: 150 });
}
