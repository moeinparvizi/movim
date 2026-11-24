const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const scratch = fs.mkdtempSync(path.join(root, '.editor-tools-test-'));
const workspace = path.dirname(root);
try {
  const env = { ...process.env, MOVIM_TOOLS_TEST_DIR: scratch, NVIM_APPNAME: 'nvim',
    XDG_DATA_HOME: path.join(workspace, '.isolated/data'), XDG_STATE_HOME: path.join(scratch, 'state'),
    XDG_CACHE_HOME: path.join(scratch, 'cache'),
    PATH: [path.dirname(process.execPath), path.join(workspace, '.tools/bin'), process.env.PATH].join(path.delimiter) };
  for (const name of process.argv.slice(3).length ? process.argv.slice(3) : ['structure', 'format', 'clipboard', 'templates', 'ui']) {
    const log = path.join(scratch, name + '.log');
    const fd = fs.openSync(log, 'w');
    let result;
    try {
      const args = name === 'ui' ? ['--headless', '-u', 'NONE', '-l', 'tests/tool-ui.lua'] : ['--headless', '-u', path.join(root, 'init.lua'), '-c',
        "lua vim.schedule(function() local ok, err = pcall(dofile, 'tests/tool-" + name + ".lua'); if not ok then print(err); vim.cmd('cquit 1') end end)"];
      result = spawnSync(process.argv[2] || 'nvim', args,
      { cwd: root, env, timeout: 45000, stdio: ['ignore', fd, fd] });
    } finally { fs.closeSync(fd); }
    const output = fs.readFileSync(log, 'utf8');
    process.stdout.write(output + '\n');
    if (result.error) throw result.error;
    if (result.status !== 0 || !output.includes('PASS ' + name + ' complete')) throw Error(name + ' integration failed');
  }
} finally {
  if (path.dirname(scratch) !== root || !path.basename(scratch).startsWith('.editor-tools-test-')) throw Error('Unsafe test cleanup');
  fs.rmSync(scratch, { recursive: true, force: true, maxRetries: 10, retryDelay: 150 });
}
