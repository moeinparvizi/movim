(() => {
  const releaseStatus = document.getElementById('release-status');
  if (releaseStatus) {
    const releasePage = 'https://github.com/moeinparvizi/movim/releases';
    fetch('https://api.github.com/repos/moeinparvizi/movim/releases/latest', { headers: { Accept: 'application/vnd.github+json' }, signal: AbortSignal.timeout(8000) })
      .then(response => { if (!response.ok) throw new Error('No public release'); return response.json(); })
      .then(release => {
        const assets = Array.isArray(release.assets) ? release.assets : [];
        const names = { windows: /^movim-setup\.exe$/i, macos: /^movim-macos\.zip$/i, linux: /^movim-linux\.tar\.gz$/i };
        let available = 0;
        document.querySelectorAll('[data-asset]').forEach(link => {
          const asset = assets.find(item => names[link.dataset.asset].test(item.name) && /^https:\/\/github\.com\//.test(item.browser_download_url || ''));
          if (asset) { link.href = asset.browser_download_url; link.textContent = 'دریافت فایل ↓'; available++; }
          else { link.href = releasePage; link.textContent = 'بسته هنوز منتشر نشده ↗'; }
        });
        const tag = typeof release.tag_name === 'string' ? release.tag_name : '';
        let previous = null;
        try { previous = localStorage.getItem('movim-last-release'); localStorage.setItem('movim-last-release', tag); } catch (_) {}
        releaseStatus.textContent = `${previous && previous !== tag ? 'نسخهٔ جدید منتشر شده است: ' : 'آخرین نسخه: '}${tag}${available ? '' : ' · بسته‌ای برای دریافت موجود نیست.'}`;
      })
      .catch(() => { releaseStatus.textContent = 'نسخهٔ منتشرشده قابل دریافت نیست یا اتصال برقرار نشد. صفحهٔ انتشارها را بررسی کن.'; });
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
