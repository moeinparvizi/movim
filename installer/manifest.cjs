const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const version = fs.readFileSync(path.join(root, 'lua/config/version.lua'), 'utf8').match(/return ['"](\d+\.\d+\.\d+)['"]/)[1];
function files(dir) { return fs.readdirSync(path.join(root,dir), { withFileTypes:true }).flatMap(e => e.isDirectory() ? files(dir + '/' + e.name) : [dir + '/' + e.name]); }
const names = ['init.lua','lazy-lock.json','README.md','LICENSE','CHANGELOG.md','site/docs-en/README.md', ...['lua','colors','keymap','docs','fonts'].flatMap(files)].sort();
const hashes = Object.fromEntries(names.map(name => [name, crypto.createHash('sha256').update(fs.readFileSync(path.join(root,name))).digest('hex')]));
let commit = null;
const git = process.platform === 'win32' && fs.existsSync('C:/Program Files/Git/cmd/git.exe') ? 'C:/Program Files/Git/cmd/git.exe' : 'git';
try { commit = execFileSync(git,['rev-parse','HEAD'], { cwd:root, encoding:'utf8',stdio:['ignore','pipe','ignore'] }).trim(); } catch (_) {}
const manifest = { version, commit, files: hashes };
if (require.main === module) fs.writeFileSync(path.join(root,'release.json'), JSON.stringify(manifest,null,2) + '\n');
module.exports = manifest;
