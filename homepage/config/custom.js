// Make entire service tiles clickable by delegating clicks to their header link.
// This keeps native anchor behavior if you click the icon/title, and adds
// navigation when you click elsewhere in the tile.
(function () {
  function findHeaderLink(el) {
    // Search up a few levels for any http(s) link within the same tile
    let node = el;
    for (let i = 0; i < 6 && node && node !== document.body; i += 1, node = node.parentElement) {
      // Prioritize direct child anchor first
      const direct = node.querySelector(':scope > a[href^="http"], :scope a[href^="http"]');
      if (direct) return direct;
    }
    return null;
  }

  function isInteractive(el) {
    const tag = (el.tagName || '').toLowerCase();
    if (['a', 'button', 'input', 'textarea', 'select', 'label', 'svg', 'path'].includes(tag)) return true;
    if (el.closest('a,button,input,textarea,select,label')) return true;
    return false;
  }

  document.addEventListener('click', function (e) {
    // Only left-click without modifiers
    if (e.defaultPrevented || e.button !== 0) return;
    if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    if (window.getSelection && String(window.getSelection())) return;

    // Respect native anchor clicks
    const clickedLink = e.target.closest('a[href]');
    if (clickedLink) return;

    // Don’t hijack obvious interactive controls inside widgets
    if (isInteractive(e.target)) return;

    const link = findHeaderLink(e.target);
    if (link && link.href && /^https?:\/\//.test(link.href)) {
      e.preventDefault();
      // open in same tab to match default behavior
      window.location.href = link.href;
    }
  }, true);
})();

