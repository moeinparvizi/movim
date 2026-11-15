const fs = require('node:fs');
const path = require('node:path');
const MarkdownIt = require('markdown-it');
const { createHash } = require('node:crypto');
const release = require('../installer/manifest.cjs');

const out = path.join(__dirname, 'dist');
const docsDir = path.resolve(__dirname, '../docs');
const escape = value => String(value).replace(/[&<>"']/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character]);
const stamp = `<p class="release-stamp">movim v${release.version} · ${release.commit ? release.commit.slice(0, 7) : 'local build'}</p>`;
const logo = '<span class="logo-symbol" aria-hidden="true">m<span>_</span></span>movim<span class="logo-dot">.</span>';
const slug = text => text.toLowerCase().normalize('NFKC').replace(/[^\p{L}\p{N}]+/gu, '-').replace(/^-|-$/g, '') || 'section';
const assets = Object.fromEntries(['style.css', 'site.js', 'search.js', 'favicon.svg'].map(file => [file, createHash('sha256').update(fs.readFileSync(path.join(__dirname, file))).digest('hex').slice(0, 12)]));
const searchVersion = createHash('sha256').update(fs.readdirSync(docsDir).filter(file => file.endsWith('.md')).sort().map(file => fs.readFileSync(path.join(docsDir, file), 'utf8')).join('\n')).digest('hex').slice(0, 12);
const cacheAssets = html => html.replace(/\b(href|src)="((?:\.\.\/)?)((?:style\.css|site\.js|search\.js|favicon\.svg))"/g, (match, attribute, prefix, file) => `${attribute}="${prefix}${file}?v=${assets[file]}"`).replace(/<body\b/, `<body data-search-version="${searchVersion}"`);
fs.rmSync(out, { recursive: true, force: true });
for (const dir of ['docs', 'docs-en']) fs.mkdirSync(path.join(out, dir), { recursive: true });
for (const file of ['style.css', 'site.js', 'search.js', 'favicon.svg']) fs.copyFileSync(path.join(__dirname, file), path.join(out, file));
fs.cpSync(path.join(__dirname, 'fonts'), path.join(out, 'fonts'), { recursive: true });
fs.writeFileSync(path.join(out, 'version.json'), JSON.stringify({ version: release.version, commit: release.commit }));
fs.writeFileSync(path.join(out, '.nojekyll'), '');

const md = new MarkdownIt({ html: false, linkify: true });
const defaultLink = md.renderer.rules.link_open || ((tokens, index, options, env, self) => self.renderToken(tokens, index, options));
md.renderer.rules.link_open = (tokens, index, options, env, self) => {
  const href = tokens[index].attrGet('href');
  if (href && /^[^:/?#]+\.md(?:[#?].*)?$/i.test(href)) tokens[index].attrSet('href', href.replace(/\.md(?=([#?]|$))/i, '.html'));
  return defaultLink(tokens, index, options, env, self);
};
md.renderer.rules.heading_open = (tokens, index, options, env, self) => {
  const title = tokens[index + 1].children.filter(token => token.type === 'text' || token.type === 'code_inline').map(token => token.content).join('');
  const base = slug(title);
  const occurrence = env.slugs.get(base) || 0;
  env.slugs.set(base, occurrence + 1);
  const id = base + (occurrence ? `-${occurrence + 1}` : '');
  tokens[index].attrSet('id', id);
  if (['h2', 'h3'].includes(tokens[index].tag)) env.headings.push({ title, id, level: tokens[index].tag });
  return self.renderToken(tokens, index, options);
};
md.renderer.rules.heading_close = (tokens, index, options, env, self) => {
  const id = tokens[index - 2].attrGet('id');
  const anchor = tokens[index].tag === 'h1' ? '' : `<a class="heading-anchor" href="#${escape(id)}" aria-label="${env.fa ? 'پیوند این بخش' : 'Link to this section'}">#</a>`;
  return anchor + self.renderToken(tokens, index, options);
};
md.renderer.rules.fence = (tokens, index, options, env) => {
  const token = tokens[index];
  const language = token.info.trim().split(/\s+/)[0] || 'text';
  return `<div class="code-block"><div class="code-block-header"><span>${escape(language)}</span><button type="button" class="copy-code">${env.fa ? 'کپی' : 'Copy'}</button></div><pre><code class="language-${escape(language)}">${escape(token.content)}</code></pre></div>`;
};
md.renderer.rules.table_open = (tokens, index, options, env) => `<div class="table-scroll" tabindex="0" role="region" aria-label="${env.fa ? 'جدول؛ برای دیدن ستون‌ها به طرفین حرکت کنید' : 'Table; scroll sideways to see all columns'}"><table>\n`;
md.renderer.rules.table_close = () => '</table></div>\n';

const sources = fs.readdirSync(docsDir).filter(file => file.endsWith('.md'));
const order = file => file === 'README.md' ? '00' : file;
sources.sort((first, second) => order(first).localeCompare(order(second), 'en'));
const pages = sources.map(file => {
  const source = fs.readFileSync(path.join(docsDir, file), 'utf8').replace(/^\uFEFF/, '');
  const title = (source.match(/^#\s+(.+)$/m) || [null, file])[1].replace(/[`*_]/g, '');
  const shortTitle = title.replace(/^فصل\s+[۰-۹\d]+\s*[—–-]\s*/, '');
  return { file, title, shortTitle, source, html: file.replace(/\.md$/, '.html') };
});
fs.writeFileSync(path.join(out, 'docs/search.json'), JSON.stringify(pages.map(({ title, html, source }) => ({ title, html, text: source }))));

function searchDialog(fa) {
  return `<dialog class="search-dialog" id="search-dialog" aria-labelledby="search-title"><form method="dialog"><span aria-hidden="true">&gt;_</span><label class="sr-only" id="search-title" for="doc-search">${fa ? 'جست‌وجوی مستندات' : 'Search documentation'}</label><input id="doc-search" type="search" autocomplete="off" placeholder="${fa ? 'مثلاً دیباگ، تم یا Space ff…' : 'Search the Persian handbook…'}"><button type="button" data-close-search aria-label="${fa ? 'بستن جست‌وجو' : 'Close search'}">Esc</button></form><p class="search-info" id="search-info" role="status"></p><ul class="search-results" id="search-results" aria-label="${fa ? 'نتایج جست‌وجو' : 'Search results'}"></ul><div class="search-footer"><span><kbd>↑</kbd> <kbd>↓</kbd> <span data-en="navigate">حرکت</span> &nbsp; <kbd>Enter</kbd> <span data-en="open">باز کردن</span></span><span data-en="Search the Persian handbook">جست‌وجو در متن تمام فصل‌ها</span></div></dialog>`;
}

function sidebar(fa, current, headings) {
  if (!fa) return `<nav aria-label="Guide sections">${headings.filter(heading => heading.level === 'h2').map(heading => `<a href="#${escape(heading.id)}">${escape(heading.title)}</a>`).join('')}</nav>`;
  return `<nav aria-label="فهرست مستندات">${pages.map((page, index) => {
    const group = index === 0 ? '<p class="sidebar-group">از اینجا شروع کن</p>' : index === 1 ? '<p class="sidebar-group">راهنمای اصلی / ۰۱—۲۰</p>' : index === 21 ? '<p class="sidebar-group">مرجع‌های کاربردی</p>' : '';
    const number = page.file.match(/^(\d+)/)?.[1] || (index === 0 ? '⌂' : '+');
    return `${group}<a href="${encodeURIComponent(page.html)}"${page.file === current ? ' aria-current="page"' : ''}><span class="sidebar-number" aria-hidden="true">${number}</span>${escape(page.shortTitle)}</a>`;
  }).join('')}</nav>`;
}

function documentPage(page, fa) {
  const env = { fa, headings: [], slugs: new Map() };
  const body = md.render(page.source, env);
  const language = fa ? 'fa' : 'en';
  const homeLabel = fa ? 'خانه' : 'Home';
  const nav = sidebar(fa, page.file, env.headings);
  const toc = env.headings.map(heading => `<a href="#${escape(heading.id)}"${heading.level === 'h3' ? ' class="toc-sub"' : ''}>${escape(heading.title)}</a>`).join('');
  const current = pages.findIndex(item => item.file === page.file);
  const neighbor = (item, next) => item ? `<a href="${encodeURIComponent(item.html)}" class="${next ? 'next' : 'previous'}"><span>${next ? 'فصل بعد ←' : '→ فصل قبل'}</span><b>${escape(item.shortTitle)}</b></a>` : '';
  const pagination = fa ? `<nav class="docs-pagination" aria-label="ادامهٔ مطالعه">${neighbor(pages[current - 1], false)}${neighbor(pages[current + 1], true)}</nav>` : '';
  const minutes = Math.max(1, Math.ceil(page.source.split(/\s+/).length / 180));
  return `<!doctype html><html lang="${language}" dir="${fa ? 'rtl' : 'ltr'}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="theme-color" content="#0b0e11"><meta name="description" content="${escape(page.title)} — movim ${fa ? 'راهنمای کامل فارسی' : 'documentation'}"><title>${escape(page.title)} · movim</title><link rel="icon" href="../favicon.svg"><link rel="stylesheet" href="../style.css"></head>
<body class="docs-page" data-search-root="${fa ? './' : '../docs/'}"><a class="skip-link" href="#main">${fa ? 'رفتن به محتوا' : 'Skip to content'}</a><header class="topbar docs-top"><div class="wrap header-inner"><a class="logo" href="../index.html">${logo}</a><span class="mono">/ docs</span><div class="docs-actions"><button class="search-trigger" type="button" data-open-search aria-label="${fa ? 'جست‌وجوی مستندات' : 'Search docs'}"><span aria-hidden="true">⌕</span><span>${fa ? 'جست‌وجو' : 'Search'}</span><kbd dir="ltr">Ctrl K</kbd></button><a class="language-toggle" href="${fa ? '../docs-en/README.html' : '../docs/README.html'}" lang="${fa ? 'en' : 'fa'}">${fa ? 'English' : 'فارسی'}</a><a class="download-nav" href="../index.html#download">${fa ? 'دریافت movim ↓' : 'Get movim ↓'}</a></div></div></header>
<div class="docs-layout wrap"><aside class="docs-sidebar"><p class="eyebrow">MOVIM / ${fa ? 'راهنمای کامل' : 'HANDBOOK'}</p><button class="search-trigger sidebar-search" data-open-search type="button"><span>${fa ? 'در مستندات جست‌وجو کن' : 'Search documentation'}</span><kbd>/</kbd></button><div class="desktop-nav">${nav}</div><details class="docs-mobile-nav"><summary>${fa ? 'فهرست تمام فصل‌ها' : 'Guide sections'}</summary>${nav}</details></aside>
<main class="docs-content" id="main"><div class="docs-breadcrumb"><a href="../index.html">${homeLabel}</a><span>/</span><a href="README.html">${fa ? 'مستندات' : 'Docs'}</a><span>/</span><span>${escape(page.shortTitle || page.title)}</span></div><div class="doc-meta">${stamp}<span>${fa ? `${minutes.toLocaleString('fa')} دقیقه مطالعه · فارسی` : `${minutes} min read · English guide`}</span></div><article class="markdown">${body}</article>${pagination}<footer class="docs-footer"><span>${fa ? 'مستندات همراه نسخهٔ اصلی به‌روز می‌شوند.' : 'Documentation ships with the configuration.'}</span><a href="https://github.com/moeinparvizi/movim">GitHub ↗</a></footer></main><aside class="docs-toc" aria-label="${fa ? 'در این صفحه' : 'On this page'}"><p>${fa ? 'در این صفحه' : 'On this page'}</p><nav>${toc}</nav></aside></div>${searchDialog(fa)}<script src="../search.js" defer></script><script src="../site.js" defer></script></body></html>`;
}

for (const page of pages) fs.writeFileSync(path.join(out, 'docs', page.html), cacheAssets(documentPage(page, true)));
fs.writeFileSync(path.join(out, 'docs/index.html'), '<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=README.html"><title>مستندات movim</title></head><body><a href="README.html">راهنمای کامل فارسی movim</a></body></html>');
const englishSource = fs.readFileSync(path.join(__dirname, 'docs-en/README.md'), 'utf8').replace(/^\uFEFF/, '');
fs.writeFileSync(path.join(out, 'docs-en/README.html'), cacheAssets(documentPage({ source: englishSource, title: 'movim documentation', file: 'English', shortTitle: 'English guide' }, false)));
let home = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8').replace('<!-- release-stamp -->', stamp).replace('<!-- version -->', release.version).replace('<!-- doc-count -->', pages.length).replace('<!-- search-dialog -->', searchDialog(true));
home = home.replace('<script src="site.js"', '<script src="search.js" defer></script><script src="site.js"');
fs.writeFileSync(path.join(out, 'index.html'), cacheAssets(home));
console.log(`Built ${pages.length} Persian documentation pages, full-text search, English guide and movim v${release.version}.`);
