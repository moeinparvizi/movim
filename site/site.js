(() => {
  const home = document.body.classList.contains('home-page');
  const translations = [...document.querySelectorAll('[data-en]')].map(node => ({ node, fa: node.innerHTML, en: node.dataset.en }));
  let language = document.documentElement.lang;
  if (home) {
    try { if (['fa', 'en'].includes(localStorage.getItem('movim-language'))) language = localStorage.getItem('movim-language'); } catch (_) {}
  }
  const fa = () => language === 'fa';
  const toggle = document.querySelector('button.language-toggle');
  let releaseData = null;
  let releaseFailed = false;
  const releaseStatus = document.getElementById('release-status');
  const releasePage = 'https://github.com/moeinparvizi/movim/releases';

  function renderRelease() {
    if (!releaseStatus) return;
    if (releaseFailed) { releaseStatus.textContent = fa() ? 'بررسی نسخه ممکن نشد؛ لینک‌های دریافت آخرین نسخه فعال‌اند.' : 'Release check unavailable; latest download links remain active.'; return; }
    if (!releaseData) { releaseStatus.textContent = fa() ? 'در حال بررسی آخرین نسخه…' : 'Checking the latest release…'; return; }
    const names = { windows: /^movim-setup\.exe$/i, macos: /^movim-macos\.zip$/i, linux: /^movim-linux\.tar\.gz$/i };
    document.querySelectorAll('[data-asset]').forEach(link => {
      const asset = (releaseData.assets || []).find(item => names[link.dataset.asset].test(item.name) && /^https:\/\/github\.com\//.test(item.browser_download_url || ''));
      link.href = asset ? asset.browser_download_url : releasePage;
      link.textContent = asset ? (fa() ? 'دریافت فایل ↓' : 'Download ↓') : (fa() ? 'بسته هنوز منتشر نشده ↗' : 'Asset not available yet ↗');
    });
    releaseStatus.textContent = (fa() ? 'آخرین نسخهٔ منتشرشده: ' : 'Latest release: ') + (releaseData.tag_name || '');
  }

  function renderLanguage() {
    if (!home) return;
    document.documentElement.lang = language;
    document.documentElement.dir = fa() ? 'rtl' : 'ltr';
    translations.forEach(item => { item.node.innerHTML = fa() ? item.fa : item.en; });
    toggle.textContent = fa() ? 'EN' : 'فارسی';
    toggle.setAttribute('aria-label', fa() ? 'Switch to English' : 'تغییر زبان به فارسی');
    document.title = fa() ? 'movim — محیط تو. قواعد تو.' : 'movim — your editor. your rules.';
    document.querySelector('[data-nav-label]')?.setAttribute('aria-label', fa() ? 'ناوبری اصلی' : 'Main navigation');
    document.querySelector('[data-editor-label]')?.setAttribute('aria-label', fa() ? 'پیش‌نمایش تعاملی محیط movim' : 'Interactive preview of movim');
    document.querySelectorAll('[data-docs-link]').forEach(link => { link.href = fa() ? 'docs/README.html' : 'docs-en/README.html'; });
    document.querySelectorAll('[data-install-link]').forEach(link => { link.href = fa() ? 'docs/19-platform-install.html' : 'docs-en/README.html#installation'; });
    document.querySelectorAll('[data-guide-fa]').forEach(link => { link.href = fa() ? link.dataset.guideFa : link.dataset.guideEn; });
    document.querySelectorAll('[data-asset]').forEach(link => { link.textContent = fa() ? 'دریافت فایل ↓' : 'Download ↓'; });
    document.querySelectorAll('[data-open-search]').forEach(button => button.setAttribute('aria-label', fa() ? 'جست‌وجوی مستندات' : 'Search documentation'));
    document.querySelector('[data-copy-label]')?.setAttribute('aria-label', fa() ? 'کپی دستور' : 'Copy command');
    renderRelease();
  }
  toggle?.addEventListener('click', () => {
    language = fa() ? 'en' : 'fa';
    try { localStorage.setItem('movim-language', language); } catch (_) {}
    renderLanguage();
  });
  renderLanguage();
  document.querySelectorAll('a.language-toggle').forEach(link => link.addEventListener('click', () => { try { localStorage.setItem('movim-language', link.lang); } catch (_) {} }));
  document.querySelectorAll('.docs-page a[href="../index.html"], .docs-page a[href="../index.html#download"]').forEach(link => link.addEventListener('click', () => { try { localStorage.setItem('movim-language', language); } catch (_) {} }));

  if (releaseStatus) {
    const options = { headers: { Accept: 'application/vnd.github+json' } };
    if (typeof AbortSignal?.timeout === 'function') options.signal = AbortSignal.timeout(8000);
    fetch('https://api.github.com/repos/moeinparvizi/movim/releases/latest', options)
      .then(response => { if (!response.ok) throw new Error('Release unavailable'); return response.json(); })
      .then(release => { releaseData = release; renderRelease(); })
      .catch(() => { releaseFailed = true; renderRelease(); });
  }

  const tabs = [...document.querySelectorAll('[data-preview]')];
  function selectPreview(tab) {
    tabs.forEach(item => {
      const selected = item === tab;
      item.classList.toggle('active', selected);
      item.setAttribute('aria-selected', String(selected));
      item.tabIndex = selected ? 0 : -1;
      document.getElementById(item.getAttribute('aria-controls')).hidden = !selected;
    });
  }
  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => selectPreview(tab));
    tab.addEventListener('keydown', event => {
      const movement = { ArrowRight: 1, ArrowLeft: -1, Home: -index, End: tabs.length - 1 - index }[event.key];
      if (movement === undefined) return;
      event.preventDefault();
      const next = tabs[(index + movement + tabs.length) % tabs.length];
      selectPreview(next);
      next.focus();
    });
  });

  document.querySelectorAll('[data-copy], .copy-code').forEach(button => button.addEventListener('click', async () => {
    const text = button.dataset.copy || button.closest('.code-block').querySelector('code').textContent;
    const original = button.textContent;
    try {
      await navigator.clipboard.writeText(text);
      button.textContent = fa() ? 'کپی شد ✓' : 'Copied ✓';
    } catch (_) {
      button.textContent = fa() ? 'متن را انتخاب کن' : 'Select the text';
    }
    setTimeout(() => { button.textContent = original; }, 1800);
  }));

  const dialog = document.getElementById('search-dialog');
  const input = document.getElementById('doc-search');
  const results = document.getElementById('search-results');
  const info = document.getElementById('search-info');
  let pages = null;
  let loading = null;
  let searchFailed = false;
  const searchRoot = document.body.dataset.searchRoot || 'docs/';
  if (!home && !fa()) translations.forEach(item => { item.node.innerHTML = item.en; });
  function renderSearch() {
    results.replaceChildren();
    if (searchFailed) { info.textContent = fa() ? 'جست‌وجو بارگیری نشد. فهرست فصل‌ها همچنان در دسترس است؛ دوباره امتحان کن.' : 'Search could not load. The chapter index is still available; try again.'; return; }
    if (!pages) { info.textContent = fa() ? 'در حال بارگیری فهرست…' : 'Loading documentation…'; return; }
    const matches = window.movimSearch.searchPages(pages, input.value);
    info.textContent = input.value.trim() ? (matches.length ? (fa() ? `${matches.length.toLocaleString('fa')} نتیجه` : `${matches.length} results`) : (fa() ? 'نتیجه‌ای پیدا نشد. عبارت دیگری امتحان کن.' : 'No results. Try another search.')) : (fa() ? 'شروع مطالعه؛ یا در متن تمام فصل‌ها جست‌وجو کن.' : 'The complete Persian handbook. Search any chapter.');
    matches.forEach(page => {
      const item = document.createElement('li');
      const link = document.createElement('a');
      link.href = searchRoot + page.html;
      const title = document.createElement('strong');
      title.textContent = page.title;
      const excerpt = document.createElement('p');
      excerpt.textContent = page.excerpt;
      const file = document.createElement('small');
      file.textContent = page.html.replace('.html', '.md');
      link.append(title, excerpt, file);
      item.append(link);
      results.append(item);
    });
  }
  async function openSearch() {
    if (!dialog) return;
    dialog.dir = fa() ? 'rtl' : 'ltr';
    input.placeholder = fa() ? 'مثلاً دیباگ، تم یا Space ff…' : 'Search the Persian handbook…';
    document.getElementById('search-title').textContent = fa() ? 'جست‌وجوی مستندات' : 'Search documentation';
    dialog.querySelector('[data-close-search]').setAttribute('aria-label', fa() ? 'بستن جست‌وجو' : 'Close search');
    results.setAttribute('aria-label', fa() ? 'نتایج جست‌وجو' : 'Search results');
    if (!dialog.open) dialog.showModal();
    input.focus();
    renderSearch();
    if (!loading && !pages) {
      searchFailed = false;
      loading = fetch(searchRoot + 'search.json').then(response => { if (!response.ok) throw new Error('Search unavailable'); return response.json(); }).then(data => { pages = data; }).catch(() => { searchFailed = true; }).finally(() => { loading = null; renderSearch(); });
    }
    await loading;
  }
  document.querySelectorAll('[data-open-search]').forEach(button => button.addEventListener('click', openSearch));
  input?.addEventListener('input', renderSearch);
  dialog?.querySelector('[data-close-search]').addEventListener('click', () => dialog.close());
  dialog?.querySelector('form').addEventListener('submit', event => {
    event.preventDefault();
    results.querySelector('a')?.click();
  });
  dialog?.addEventListener('click', event => {
    if (event.target !== dialog) return;
    const bounds = dialog.getBoundingClientRect();
    if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) dialog.close();
  });
  results?.addEventListener('click', event => { if (event.target.closest('a')) dialog.close(); });
  document.addEventListener('keydown', event => {
    const typing = event.target.closest('input,textarea,select,[contenteditable="true"]');
    if (((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') || (event.key === '/' && !typing && !event.ctrlKey && !event.metaKey && !event.altKey)) { event.preventDefault(); openSearch(); }
    if (!dialog?.open || !['ArrowDown', 'ArrowUp'].includes(event.key)) return;
    event.preventDefault();
    const links = [...results.querySelectorAll('a')];
    if (!links.length) return;
    const current = links.indexOf(document.activeElement);
    const next = current < 0 ? (event.key === 'ArrowDown' ? 0 : links.length - 1) : (current + (event.key === 'ArrowDown' ? 1 : -1) + links.length) % links.length;
    links[next].focus();
  });

  const tocLinks = [...document.querySelectorAll('.docs-toc a')];
  if (tocLinks.length && typeof IntersectionObserver === 'function') {
    const observer = new IntersectionObserver(entries => {
      const visible = entries.filter(entry => entry.isIntersecting).sort((first, second) => first.boundingClientRect.top - second.boundingClientRect.top)[0];
      if (!visible) return;
      tocLinks.forEach(link => link.setAttribute('aria-current', String(decodeURIComponent(link.hash.slice(1)) === visible.target.id)));
    }, { rootMargin: '-90px 0px -65% 0px' });
    document.querySelectorAll('.markdown h2, .markdown h3').forEach(heading => observer.observe(heading));
  }
})();
