(function (scope) {
  const normalize = text => text.toLocaleLowerCase('fa').replace(/[يى]/g, 'ی').replace(/ك/g, 'ک').replace(/[\u200c\u200d]/g, '').replace(/[\u064b-\u065f]/g, '');
  function searchPages(pages, query) {
    const terms = normalize(query.trim()).split(/\s+/).filter(Boolean);
    return pages.map(page => {
      const title = normalize(page.title);
      const plainText = page.text.replace(/\[([^\]]+)\]\([^)]+\)/g, '$1').replace(/[`*#|]/g, '').replace(/^>\s?/gm, '').replace(/-{3,}/g, '').replace(/\s+/g, ' ').trim();
      const content = normalize(plainText);
      if (!terms.every(term => (title + ' ' + content).includes(term))) return null;
      const score = terms.reduce((total, term) => total + (title.includes(term) ? 10 : 1), 0);
      const start = terms.length ? Math.max(0, content.indexOf(terms[0]) - 45) : 0;
      const excerpt = plainText.slice(start, start + 170).trim();
      return { ...page, score, excerpt: (start ? '… ' : '') + excerpt + '…' };
    }).filter(Boolean).sort((first, second) => second.score - first.score).slice(0, terms.length ? 16 : 6);
  }
  if (typeof module === 'object' && module.exports) module.exports = { normalize, searchPages };
  else scope.movimSearch = { normalize, searchPages };
})(typeof window === 'object' ? window : this);
