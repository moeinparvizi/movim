const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const scratch = fs.mkdtempSync(path.join(root, '.workspace-test-'));
const nvim = process.argv[2] || 'nvim';
try {
  fs.mkdirSync(path.join(scratch, 'A/src'), { recursive: true });
  fs.mkdirSync(path.join(scratch, 'B'), { recursive: true });
  fs.mkdirSync(path.join(scratch, 'C'), { recursive: true });
  fs.mkdirSync(path.join(scratch, 'D'), { recursive: true });
  fs.mkdirSync(path.join(scratch, 'legacy'), { recursive: true });
  fs.writeFileSync(path.join(scratch, 'A/one.txt'), 'disk\nsecond\n');
  fs.writeFileSync(path.join(scratch, 'A/two.txt'), 'two\n');
  fs.writeFileSync(path.join(scratch, 'A/cold.txt'), 'hidden clean buffer\n');
  fs.writeFileSync(path.join(scratch, 'B/other.txt'), 'other\n');
  fs.writeFileSync(path.join(scratch, 'C/exit.txt'), 'disk exit\n');
  fs.writeFileSync(path.join(scratch, 'D/old.txt'), 'old project\n');
  fs.writeFileSync(path.join(scratch, 'legacy/old.vim'), 'let g:workspace_should_not_run = 1\ncd ' + path.join(scratch, 'D').replaceAll('\\', '/') + '\nbadd +1 old.txt\n');
  for (const phase of ['write', 'read', 'auto', 'portable', 'migration', 'conflict', 'corrupt', 'exit-write', 'exit-read', 'legacy', 'headless']) {
    if (phase === 'portable') fs.cpSync(path.join(scratch, 'A'), path.join(scratch, 'E'), { recursive: true });
    if (phase === 'conflict') fs.writeFileSync(path.join(scratch, 'A/one.txt'), 'external disk change\n');
    const result = spawnSync(nvim, ['--headless', '-u', 'NONE', '-l', 'tests/workspace.lua'], {
      cwd: root, env: { ...process.env, MOVIM_WORKSPACE_TEST_DIR: scratch, MOVIM_WORKSPACE_TEST_PHASE: phase },
      encoding: 'utf8', timeout: 30000,
    });
    process.stdout.write((result.stdout || '') + (result.stderr || ''));
    if (result.error) throw result.error;
    if (result.status !== 0) throw Error('Workspace phase failed: ' + phase);
  }
  if (process.argv.includes('--ui')) {
    // UI integration uses the same project-local files as recovery tests.
    // Start it with clean fixtures rather than the deliberately corrupt state.
    for (const project of ['A', 'B', 'C', 'D']) {
      fs.rmSync(path.join(scratch, project, '.movim'), { recursive: true, force: true });
    }
    const workspace = path.dirname(root);
    const env = { ...process.env, MOVIM_WORKSPACE_TEST_DIR: scratch, NVIM_APPNAME: 'nvim',
      XDG_DATA_HOME: path.join(workspace, '.isolated/data'), XDG_STATE_HOME: path.join(scratch, 'editor-state'),
      XDG_CACHE_HOME: path.join(scratch, 'editor-cache'),
      PATH: [path.dirname(process.execPath), path.join(workspace, '.tools/bin'), process.env.PATH].join(path.delimiter) };
    const command = "lua vim.schedule(function() local ok, err = pcall(dofile, 'tests/workspace-ui.lua'); if not ok then print(err); vim.cmd('cquit 1') end end)";
    const result = spawnSync(nvim, ['--headless', '-u', path.join(root, 'init.lua'), '-c', command], {
      cwd: root, env, encoding: 'utf8', timeout: 70000,
    });
    process.stdout.write((result.stdout || '') + (result.stderr || ''));
    if (result.error) throw result.error;
    if (result.status !== 0) throw Error('Workspace UI integration failed: status=' + result.status + ', signal=' + result.signal);
    if (!((result.stdout || '') + (result.stderr || '')).includes('PASS workspace UI integration with real')) throw Error('Editor exited before UI checks completed');
    const mouse = spawnSync(nvim, ['--headless', '-u', 'NONE', '-l', 'tests/mouse.lua'], {
      cwd: root, env: { ...env, MOVIM_WORKSPACE_TEST_DIR: scratch }, encoding: 'utf8', timeout: 15000,
    });
    process.stdout.write((mouse.stdout || '') + (mouse.stderr || ''));
    if (mouse.error) throw mouse.error;
    if (mouse.status !== 0) throw Error('Rendered mouse integration failed');
  }
  console.log('PASS workspace recovery across eleven fresh Neovim processes');
} finally {
  if (path.dirname(scratch) !== root || !path.basename(scratch).startsWith('.workspace-test-')) throw Error('Unsafe test cleanup');
  fs.rmSync(scratch, { recursive: true, force: true, maxRetries: 10, retryDelay: 150 });
}
