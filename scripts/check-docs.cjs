const {execFileSync} = require('node:child_process');
const base = process.argv[2];
if (!base || /^0+$/.test(base)) process.exit(0);
const changed = execFileSync('git',['diff','--name-only',base,'HEAD'],{encoding:'utf8'}).trim().split('\n');
const behavior = changed.some(p => /^(lua\/|colors\/|keymap\/|init\.lua$|install\.sh$|installer\/.*(?:\.iss|\.sh|\.command|\.ps1)$)/i.test(p) && p !== 'lua/config/version.lua');
if (behavior && (!changed.some(p => /^docs\/.*\.md$/.test(p)) || !changed.includes('site/docs-en/README.md'))) {
  console.error('Behavior changes require both docs/*.md and site/docs-en/README.md updates.'); process.exit(1);
}
console.log('PASS documentation change guard');
