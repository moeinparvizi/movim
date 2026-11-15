const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const dir = path.resolve(process.argv[2]);
const manifest = JSON.parse(fs.readFileSync(path.join(dir,'release.json'),'utf8'));
const expected = require('./manifest.cjs');
if (manifest.version !== expected.version) throw Error('Package version mismatch');
for (const [name,hash] of Object.entries(expected.files)) {
  const actual = crypto.createHash('sha256').update(fs.readFileSync(path.join(dir,name))).digest('hex');
  if (actual !== hash || manifest.files[name] !== hash) throw Error('Package content mismatch: ' + name);
}
console.log('PASS all ' + Object.keys(manifest.files).length + ' packaged files match source v' + manifest.version);
