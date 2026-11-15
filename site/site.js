(() => {
  const translations = [...document.querySelectorAll('[data-fa]')];
  translations.forEach(node => { node.dataset.en = node.innerHTML; });
  let language = 'en';
  try { if (localStorage.getItem('movim-language') === 'fa') language = 'fa'; } catch (_) {}
  const toggle = document.querySelector('button.language-toggle');
  let releaseData = null;
  let releaseFailed = false;
  const releaseStatus = document.getElementById('release-status');
  const releasePage = 'https://github.com/moeinparvizi/movim/releases';
  function renderRelease() {
    if (!releaseStatus) return;
    const fa = language === 'fa';
    if (releaseFailed) { releaseStatus.textContent = fa ? 'بررسی خودکار نسخه ممکن نشد؛ لینک‌های دریافت آخرین نسخه همچنان در دسترس‌اند.' : 'Could not check the latest release; download links remain available.'; return; }
    if (!releaseData) { releaseStatus.textContent = fa ? 'در حال بررسی آخرین نسخه…' : 'Checking the latest release…'; return; }
    let available = 0;
    const names = { windows: /^movim-setup\.exe$/i, macos: /^movim-macos\.zip$/i, linux: /^movim-linux\.tar\.gz$/i };
    document.querySelectorAll('[data-asset]').forEach(link => {
      const asset = (releaseData.assets || []).find(item => names[link.dataset.asset].test(item.name) && /^https:\/\/github\.com\//.test(item.browser_download_url || ''));
      link.href = asset ? asset.browser_download_url : releasePage;
      link.textContent = asset ? (fa ? 'دریافت فایل ↓' : 'Download ↓') : (fa ? 'بسته هنوز منتشر نشده ↗' : 'Asset not yet available ↗');
      if (asset) available++;
    });
    const label = releaseData.isNew ? (fa ? 'نسخهٔ جدید منتشر شده است: ' : 'A new release is available: ') : (fa ? 'آخرین نسخه: ' : 'Latest release: ');
    releaseStatus.textContent = label + (releaseData.tag_name || '') + (available ? '' : (fa ? ' · بسته‌ای برای دریافت موجود نیست.' : ' · No downloads available.'));
  }
  function renderLanguage() {
    if (!toggle) return;
    const fa = language === 'fa';
    document.documentElement.lang = language;
    document.documentElement.dir = fa ? 'rtl' : 'ltr';
    translations.forEach(node => { if (node.isConnected) node.innerHTML = fa ? node.dataset.fa : node.dataset.en; });
    toggle.textContent = fa ? 'English' : 'فارسی';
    document.querySelector('[data-nav-label]')?.setAttribute('aria-label', fa ? 'ناوبری اصلی' : 'Main navigation');
    document.querySelector('[data-editor-label]')?.setAttribute('aria-label', fa ? 'نمایشی از محیط توسعه movim' : 'Preview of the movim development environment');
    toggle.setAttribute('aria-label', fa ? 'Switch to English' : 'تغییر زبان به فارسی');
    document.querySelectorAll('[data-docs-link]').forEach(link => { link.href = 'docs-en/README.html'; });
    document.querySelectorAll('[data-install-link]').forEach(link => { link.href = 'docs-en/README.html#installation'; });
    renderRelease();
  }
  if (toggle) {
    toggle.addEventListener('click', () => { language = language === 'fa' ? 'en' : 'fa'; try { localStorage.setItem('movim-language', language); } catch (_) {} renderLanguage(); });
    renderLanguage();
  }
  document.querySelectorAll('a.language-toggle').forEach(link => link.addEventListener('click', () => { try { localStorage.setItem('movim-language', link.lang === 'fa' ? 'fa' : 'en'); } catch (_) {} }));
  if (releaseStatus) {
    fetch('https://api.github.com/repos/moeinparvizi/movim/releases/latest', { headers: { Accept: 'application/vnd.github+json' }, signal: AbortSignal.timeout(8000) })
      .then(response => { if (!response.ok) throw new Error('No public release'); return response.json(); })
      .then(release => { let previous = null; try { previous = localStorage.getItem('movim-last-release'); localStorage.setItem('movim-last-release', release.tag_name || ''); } catch (_) {} release.isNew = !!previous && previous !== release.tag_name; releaseData = release; renderRelease(); })
      .catch(() => { releaseFailed = true; renderRelease(); });
  }

  const search = document.getElementById('doc-search');
  if (search) {
    const links = [...document.querySelectorAll('#doc-nav a')];
    const current = decodeURIComponent(location.pathname.split('/').pop());
    for (const link of links) if (decodeURIComponent(link.getAttribute('href')) === current) link.classList.add('active');
    let pages = [];
    fetch('search.json').then(response => response.ok ? response.json() : []).then(data => { pages = data; filter(); }).catch(() => {});
    const normalize = text => text.toLocaleLowerCase('fa').replace(/[يى]/g, 'ی').replace(/ك/g, 'ک');
    function filter() {
      const query = normalize(search.value.trim());
      let visible = 0;
      for (const link of links) {
        const file = decodeURIComponent(link.getAttribute('href'));
        const page = pages.find(item => item.html === file);
        const text = page ? `${page.title} ${page.text}` : link.textContent;
        link.hidden = !!query && !normalize(text).includes(query);
        if (!link.hidden) visible++;
      }
      document.querySelector('.empty-search').hidden = visible !== 0;
    }
    search.addEventListener('input', filter);
  }
})();
