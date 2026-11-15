const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
execFileSync(process.execPath, [path.join(__dirname, 'build.cjs')], { stdio: 'inherit' });
const source = path.resolve(__dirname, '../docs');
const out = path.join(__dirname, 'dist');
const files = fs.readdirSync(source).filter(name => name.endsWith('.md'));
const index = JSON.parse(fs.readFileSync(path.join(out, 'docs/search.json'), 'utf8'));
assert.equal(index.length, files.length, 'all documentation must be searchable');
for (const file of files) assert.ok(fs.existsSync(path.join(out, 'docs', file.replace(/\.md$/, '.html'))), `missing ${file}`);
const home = fs.readFileSync(path.join(out, 'index.html'), 'utf8');
assert.match(home, /<html lang="en" dir="ltr">/);
assert.match(home, /class="language-toggle"/);
assert.ok(fs.existsSync(path.join(out, 'docs-en/README.html')), 'missing English guide');
const english = fs.readFileSync(path.join(out, 'docs-en/README.html'), 'utf8');
assert.match(english, /id="installation"/);
assert.doesNotMatch(english, /href="\.\.\/docs\//, "English guide must not link to Persian chapters");
const script = fs.readFileSync(path.join(out, "site.js"), "utf8");
assert.doesNotMatch(script, /fa \? 'docs\//, "home documentation links must stay in English");
for (const match of english.matchAll(/href="([^"#?]+\.html)(?:[#?][^"]*)?"/g)) {
  if (!/^(?:[a-z]+:|\/\/)/i.test(match[1])) assert.ok(fs.existsSync(path.resolve(out, 'docs-en', decodeURIComponent(match[1]))), `English guide: broken link ${match[1]}`);
}
for (const id of ['windows', 'macos', 'linux']) assert.match(home, new RegExp(`data-asset="${id}"`));
for (const page of index) {
  const html = fs.readFileSync(path.join(out, 'docs', page.html), 'utf8');
  for (const match of html.matchAll(/href="([^"#?]+\.html)(?:[#?][^"]*)?"/g)) {
    if (/^(?:[a-z]+:|\/\/)/i.test(match[1])) continue;
    const target = path.resolve(out, 'docs', decodeURIComponent(match[1]));
    assert.ok(fs.existsSync(target), `${page.html}: broken link ${match[1]}`);
  }
}
console.log(`PASS ${files.length} documentation pages, internal HTML links and download cards`);

const release = require("../installer/manifest.cjs");
const builtVersion = JSON.parse(fs.readFileSync(path.join(out,"version.json"),"utf8"));
assert.equal(builtVersion.version, release.version);
assert.equal(builtVersion.commit, release.commit);
for (const file of ["index.html", "docs-en/README.html", ...files.map(f => "docs/" + f.replace(/\.md$/, ".html"))]) {
  assert.ok(fs.readFileSync(path.join(out,file),"utf8").includes("movim v" + release.version), "missing shared version: " + file);
}
console.log("PASS shared website and documentation version " + release.version);
