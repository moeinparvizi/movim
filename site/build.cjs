const fs = require('node:fs');
const path = require('node:path');
const MarkdownIt = require('markdown-it');

const root = path.resolve(__dirname, '..');
const release = require('../installer/manifest.cjs');
const stamp = `<p class="release-stamp">movim v${release.version} · ${release.commit ? release.commit.slice(0, 7) : 'local build'}</p>`;
const out = path.join(__dirname, 'dist');
const docsDir = path.join(root, 'docs');
fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(path.join(out, 'docs'), { recursive: true });
fs.mkdirSync(path.join(out, 'docs-en'), { recursive: true });
for (const file of ['style.css', 'site.js', 'favicon.svg']) fs.copyFileSync(path.join(__dirname, file), path.join(out, file));
fs.writeFileSync(path.join(out, 'index.html'), fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8').replace('<!-- release-stamp -->', stamp));
fs.writeFileSync(path.join(out, 'version.json'), JSON.stringify({version:release.version, commit:release.commit}));
fs.writeFileSync(path.join(out, '.nojekyll'), '');

const md = new MarkdownIt({ html: false, linkify: true, typographer: false });
const defaultLink = md.renderer.rules.link_open || ((tokens, i, opts, env, self) => self.renderToken(tokens, i, opts));
md.renderer.rules.link_open = (tokens, i, opts, env, self) => {
  const href = tokens[i].attrGet('href');
  if (href && /^[^:/?#]+\.md(?:[#?].*)?$/i.test(href)) tokens[i].attrSet('href', href.replace(/\.md(?=([#?]|$))/i, '.html'));
  return defaultLink(tokens, i, opts, env, self);
};
const files = fs.readdirSync(docsDir).filter(f => f.endsWith('.md')).sort((a, b) => a.localeCompare(b, 'en'));
const escape = s => s.replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const pages = files.map(file => {
  const source = fs.readFileSync(path.join(docsDir, file), 'utf8');
  const title = (source.match(/^#\s+(.+)$/m) || [null, file])[1].replace(/[`*_]/g, '');
  return { file, title, source, html: file.replace(/\.md$/, '.html') };
});
fs.writeFileSync(path.join(out, 'docs', 'search.json'), JSON.stringify(pages.map(({ title, html, source }) => ({ title, html, text: source }))));
const nav = pages.map(p => `<a href="${encodeURIComponent(p.html)}">${escape(p.title)}</a>`).join('\n');
for (const page of pages) {
  const html = `<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escape(page.title)} · movim</title><link rel="icon" href="../favicon.svg"><link rel="stylesheet" href="../style.css"></head><body class="docs-page"><header class="docs-top"><a class="logo" href="../index.html"><span class="logo-mark">m</span>movim<span class="logo-dot">.</span></a><div class="docs-actions"><a href="../docs-en/README.html" class="language-toggle" lang="en">English</a><a href="../index.html#download">دریافت movim ↗</a></div></header><div class="docs-layout"><aside class="docs-sidebar"><p class="eyebrow">MOVIM / راهنما</p><label class="search-label" for="doc-search">جست‌وجو در فصل‌ها</label><input id="doc-search" type="search" placeholder="مثلاً ترمینال یا Git"><nav id="doc-nav">${nav}</nav><p class="empty-search" hidden>فصلی پیدا نشد.</p></aside><main class="docs-content"><div class="docs-breadcrumb"><a href="../index.html">خانه</a> / مستندات</div><article class="markdown">${stamp}${md.render(page.source)}</article><footer class="docs-footer">ساخته شده برای تمرکز بیشتر · <a href="https://github.com/moeinparvizi/movim">GitHub ↗</a></footer></main></div><script src="../site.js" defer></script></body></html>`;
  fs.writeFileSync(path.join(out, 'docs', page.html), html);
}
const englishSource = fs.readFileSync(path.join(__dirname, 'docs-en', 'README.md'), 'utf8').replace(/^\uFEFF/, '');
const englishBody = md.render(englishSource).replace('<h2>Installation</h2>', '<h2 id="installation">Installation</h2>');
const englishHtml = `<!doctype html><html lang="en" dir="ltr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Documentation · movim</title><link rel="icon" href="../favicon.svg"><link rel="stylesheet" href="../style.css"></head><body class="docs-page"><header class="docs-top"><a class="logo" href="../index.html"><span class="logo-mark">m</span>movim<span class="logo-dot">.</span></a><div class="docs-actions"><a href="../index.html#download">Get movim ↗</a></div></header><div class="docs-layout docs-english"><aside class="docs-sidebar"><p class="eyebrow">MOVIM / DOCUMENTATION</p><p>English guide</p></aside><main class="docs-content"><div class="docs-breadcrumb"><a href="../index.html">Home</a> / Documentation</div><article class="markdown">${stamp}${englishBody}</article><footer class="docs-footer">Made for focus · <a href="https://github.com/moeinparvizi/movim">GitHub ↗</a></footer></main></div><script src="../site.js" defer></script></body></html>`;
fs.writeFileSync(path.join(out, 'docs-en', 'README.html'), englishHtml);
console.log(`Built site with ${pages.length} Persian documentation pages and an English guide.`);
