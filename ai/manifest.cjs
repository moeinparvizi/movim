const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const release = require('../installer/manifest.cjs');
const root = __dirname;
function walk(dir) { return fs.readdirSync(path.join(root, dir), { withFileTypes: true }).flatMap(e => e.isDirectory() ? walk(dir + '/' + e.name) : [dir + '/' + e.name]); }
const names = ['README.md', 'runtime/package.json', 'runtime/package-lock.json', ...walk('lua')].sort();
const result = { edition: 'movim-ai', version: release.version, commit: release.commit, pi: '0.73.1',
  files: Object.fromEntries(names.map(name => [name, createHash('sha256').update(fs.readFileSync(path.join(root, name))).digest('hex')])) };
if (require.main === module) {
  fs.mkdirSync(path.join(root, 'dist'), { recursive: true });
  fs.writeFileSync(path.join(root, 'dist/ai-release.json'), JSON.stringify(result, null, 2) + '\n');
}
module.exports = result;
