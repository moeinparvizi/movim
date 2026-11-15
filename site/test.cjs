const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { execFileSync } = require('node:child_process');
const { parseHTML } = require('linkedom');
const { searchPages, normalize } = require('./search.js');
const release = require('../installer/manifest.cjs');

execFileSync(process.execPath, [path.join(__dirname, 'build.cjs')], { stdio: 'inherit' });
const out = path.join(__dirname, 'dist');
const load = file => fs.readFileSync(path.join(out, file), 'utf8');
const index = JSON.parse(load('docs/search.json'));
const sources = fs.readdirSync(path.resolve(__dirname, '../docs')).filter(file => file.endsWith('.md'));
assert.equal(index.length, sources.length, 'every source must be searchable');
assert.equal(index[0].html, 'README.html', 'the complete index must come first');
assert.equal(index.filter(page => /^\d\d-/.test(page.html)).length, 20, 'preserve all twenty chapters');
const documents = ['index.html', 'docs-en/README.html', ...index.map(page => `docs/${page.html}`)];
const parsed = new Map(documents.map(file => [file, parseHTML(load(file)).document]));
for (const [file, document] of parsed) {
  assert.ok(document.querySelector('.release-stamp').textContent.includes(`movim v${release.version}`), `${file}: shared version`);
  const ids = [...document.querySelectorAll('[id]')].map(node => node.id);
  assert.equal(ids.length, new Set(ids).size, `${file}: duplicate id`);
  for (const link of document.querySelectorAll('a[href], script[src], link[href]')) {
    const href = link.getAttribute('href') || link.getAttribute('src');
    if (/^(?:[a-z]+:|\/\/)/i.test(href)) continue;
    const url = new URL(href, `https://example.test/movim/${file}`);
    assert.ok(url.pathname.startsWith('/movim/'), `${file}: escaped project subpath ${href}`);
    const target = decodeURIComponent(url.pathname.slice('/movim/'.length));
    assert.ok(fs.existsSync(path.join(out, target)), `${file}: missing ${href}`);
    if (url.hash && target.endsWith('.html')) {
      const targetDoc = parsed.get(target) || parseHTML(load(target)).document;
      assert.ok(targetDoc.getElementById(decodeURIComponent(url.hash.slice(1))), `${file}: missing anchor ${href}`);
    }
  }
}
for (const page of index) {
  const document = parsed.get(`docs/${page.html}`);
  assert.equal(document.documentElement.lang, 'fa');
  assert.equal(document.documentElement.dir, 'rtl');
  assert.match(document.querySelector('article h1').textContent, /[\u0600-\u06ff]/, `${page.html}: Persian article title`);
  assert.equal(document.querySelectorAll('.desktop-nav nav a').length, sources.length, `${page.html}: complete chapter navigation`);
  assert.ok(document.querySelector('.desktop-nav [aria-current="page"]'), `${page.html}: current chapter`);
  assert.ok(document.querySelector('.docs-mobile-nav'), `${page.html}: mobile navigation`);
}
const home = parsed.get('index.html');
assert.equal(home.documentElement.lang, 'fa');
assert.equal(home.documentElement.dir, 'rtl');
for (const link of home.querySelectorAll('[data-docs-link]')) assert.equal(link.getAttribute('href'), 'docs/README.html');
for (const link of home.querySelectorAll('[data-install-link]')) assert.equal(link.getAttribute('href'), 'docs/19-platform-install.html');
assert.equal(parsed.get('docs-en/README.html').querySelector('a[lang="fa"]').getAttribute('href'), '../docs/README.html');
assert.ok(parsed.get('docs-en/README.html').getElementById('installation'));
for (const platform of ['windows', 'macos', 'linux']) assert.ok(home.querySelector(`[data-asset="${platform}"]`));
for (const font of ['Vazirmatn.woff2', 'JetBrainsMono.woff2']) assert.equal(fs.readFileSync(path.join(out, 'fonts', font)).subarray(0, 4).toString(), 'wOF2');
assert.deepEqual(JSON.parse(load('version.json')), { version: release.version, commit: release.commit });
assert.equal(normalize('كی‌برد ي'), normalize('کیبرد ی'));
assert.equal(searchPages(index, 'گیت')[0].html, '07-git.html');
assert.ok(searchPages(index, 'ZWNJ').some(page => page.html === '13-persian.html'), 'search must include body content');
assert.ok(searchPages(index, 'سرور زبان').length, 'multiple query terms');
assert.equal(searchPages(index, 'nonexistent_49272971').length, 0);

async function runtime({ file = 'index.html', saved, offline = false, assets = true, storageBlocked = false, searchOffline = false } = {}) {
  const { window } = parseHTML(load(file));
  const { document } = window;
  const storage = new Map(saved ? [['movim-language', saved]] : []);
  const clipboard = [];
  const dialog = document.getElementById('search-dialog');
  dialog.showModal = () => { dialog.open = true; };
  dialog.close = () => { dialog.open = false; };
  let active = document.body;
  Object.defineProperty(document, 'activeElement', { get: () => active });
  for (const node of document.querySelectorAll('button,input,a')) node.focus = () => { active = node; };
  const fetch = async url => {
    if (url.endsWith('search.json')) { if (searchOffline) throw new Error('Search network unavailable'); return { ok: true, json: async () => index }; }
    if (offline) throw new Error('Release network unavailable');
    return { ok: true, json: async () => ({ tag_name: 'v9.8.7', assets: assets ? ['movim-Setup.exe', 'movim-macOS.zip', 'movim-linux.tar.gz'].map(name => ({ name, browser_download_url: `https://github.com/example/releases/download/v9.8.7/${name}` })) : [] }) };
  };
  const localStorage = {
    getItem: key => { if (storageBlocked) throw new Error('Storage blocked'); return storage.get(key) || null; },
    setItem: (key, value) => { if (storageBlocked) throw new Error('Storage blocked'); storage.set(key, value); }
  };
  window.movimSearch = { searchPages, normalize };
  vm.runInNewContext(load('site.js'), { window, document, localStorage, fetch, navigator: { clipboard: { writeText: async text => clipboard.push(text) } }, AbortSignal, setTimeout: () => 0, console });
  const settle = async () => { await new Promise(setImmediate); };
  await settle();
  const click = selector => document.querySelector(selector).dispatchEvent(new window.Event('click', { bubbles: true }));
  const key = (target, value, extra = {}) => {
    const event = new window.Event('keydown', { bubbles: true, cancelable: true });
    Object.assign(event, { key: value, ...extra });
    target.dispatchEvent(event);
  };
  return { document, window, storage, clipboard, settle, click, key, dialog };
}

(async () => {
  const fresh = await runtime();
  assert.equal(fresh.document.documentElement.lang, 'fa', 'first visit must be Persian');
  fresh.click('button.language-toggle');
  assert.equal(fresh.document.documentElement.lang, 'en');
  assert.equal(fresh.document.documentElement.dir, 'ltr');
  assert.equal(fresh.document.querySelector('[data-docs-link]').getAttribute('href'), 'docs-en/README.html');
  assert.equal(fresh.document.querySelector('[data-install-link]').getAttribute('href'), 'docs-en/README.html#installation');
  assert.equal(fresh.storage.get('movim-language'), 'en');
  for (const link of fresh.document.querySelectorAll('[data-guide-en]')) assert.equal(link.getAttribute('href'), link.dataset.guideEn);
  fresh.click('button.language-toggle');
  assert.equal(fresh.document.querySelector('[data-docs-link]').getAttribute('href'), 'docs/README.html');
  assert.match(fresh.document.querySelector('h1').textContent, /محیط تو/);
  fresh.click('#tab-terminal');
  assert.equal(fresh.document.getElementById('panel-terminal').hidden, false);
  assert.equal(fresh.document.getElementById('panel-code').hidden, true);
  fresh.key(fresh.document.getElementById('tab-terminal'), 'ArrowRight');
  assert.equal(fresh.document.getElementById('tab-git').getAttribute('aria-selected'), 'true');
  fresh.click('[data-copy]');
  await fresh.settle();
  assert.deepEqual(fresh.clipboard, ['movim ./your-next-idea']);
  fresh.key(fresh.document.body, 'k', { ctrlKey: true });
  await fresh.settle();
  assert.equal(fresh.dialog.open, true);
  const input = fresh.document.getElementById('doc-search');
  input.value = 'ZWNJ';
  input.dispatchEvent(new fresh.window.Event('input'));
  assert.ok(fresh.document.querySelector('#search-results a[href="docs/13-persian.html"]'), 'search results must lead to the detailed Persian chapter');
  let openedFirstResult = false;
  fresh.document.querySelector('#search-results a').click = () => { openedFirstResult = true; };
  fresh.dialog.querySelector('form').dispatchEvent(new fresh.window.Event('submit', { cancelable: true }));
  assert.equal(openedFirstResult, true, 'Enter in the search input must open the first result');
  fresh.click('[data-close-search]');
  assert.equal(fresh.dialog.open, false);
  input.value = 'nonexistent_49272971';
  input.dispatchEvent(new fresh.window.Event('input'));
  assert.match(fresh.document.getElementById('search-info').textContent, /پیدا نشد/);
  assert.equal(fresh.document.querySelectorAll('#search-results a').length, 0);
  for (const lang of ['fa', 'en']) {
    const remembered = await runtime({ saved: lang });
    assert.equal(remembered.document.documentElement.lang, lang);
  }
  const blocked = await runtime({ storageBlocked: true });
  blocked.click('button.language-toggle');
  assert.equal(blocked.document.documentElement.lang, 'en');
  const offline = await runtime({ offline: true });
  assert.match(offline.document.querySelector('[data-asset]').getAttribute('href'), /releases\/latest\/download/);
  assert.match(offline.document.getElementById('release-status').textContent, /فعال/);
  const missing = await runtime({ assets: false });
  assert.equal(missing.document.querySelector('[data-asset]').getAttribute('href'), 'https://github.com/moeinparvizi/movim/releases');
  const docs = await runtime({ file: 'docs/01-installation.html', saved: 'en' });
  assert.equal(docs.document.documentElement.lang, 'fa', 'a Persian URL must remain Persian regardless of the homepage preference');
  docs.click('a.language-toggle');
  assert.equal(docs.storage.get('movim-language'), 'en');
  const failedSearch = await runtime({ searchOffline: true });
  failedSearch.click('[data-open-search]');
  await failedSearch.settle();
  assert.match(failedSearch.document.getElementById('search-info').textContent, /دوباره امتحان/);
  assert.ok(failedSearch.document.querySelector('a[href="docs/README.html"]'), 'chapter index survives search failure');
  console.log(`PASS ${sources.length} full Persian pages, links and anchors, bilingual navigation, search, previews, copy, storage and offline release handling; shared version ${release.version}.`);
})().catch(error => { console.error(error); process.exitCode = 1; });
