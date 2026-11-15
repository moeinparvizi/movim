const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const assert = require('node:assert/strict');
const expected = require('./manifest.cjs');
const directory = path.resolve(process.argv[2]);
const actual = JSON.parse(fs.readFileSync(path.join(directory, 'ai-release.json')));
assert.equal(actual.version, expected.version);
assert.equal(actual.pi, expected.pi);
for (const [name, hash] of Object.entries(expected.files)) {
  assert.equal(createHash('sha256').update(fs.readFileSync(path.join(directory, name))).digest('hex'), hash, name);
  assert.equal(actual.files[name], hash, name);
}
if (fs.existsSync(path.join(directory, 'runtime/node_modules'))) {
  assert.equal(JSON.parse(fs.readFileSync(path.join(directory, 'runtime/node_modules/@mariozechner/pi-coding-agent/package.json'))).version, expected.pi);
}
console.log(`PASS AI edition v${actual.version}: ${Object.keys(expected.files).length} files and pinned Pi ${actual.pi}`);
