// nav.js — shared top navigation for PL LMS
// Include on every page with <script src="nav.js"></script> in <head>.

(function(){
  const css = `
    body { padding-top: 0 !important; }

    .lms-nav {
      background: var(--surface, #131F19);
      border-bottom: 1px solid var(--line, rgba(243,241,231,0.08));
      margin-bottom: 24px;
    }
    .lms-nav__inner {
      max-width: 720px;
      margin: 0 auto;
      padding: 0 16px;
      display: flex;
      align-items: center;
      gap: 20px;
      height: 56px;
    }
    .lms-nav__mark {
      display: inline-flex;
      align-items: center;
      text-decoration: none;
      color: var(--chalk, #F3F1E7);
      font-family: 'Anton', Impact, sans-serif;
      font-size: 20px;
      letter-spacing: 0.06em;
      line-height: 1;
      padding-right: 16px;
      border-right: 1px solid var(--line, rgba(243,241,231,0.08));
    }
    .lms-nav__mark-stack {
      display: flex;
      flex-direction: column;
      align-items: flex-start;
      gap: 4px;
    }
    .lms-nav__mark-bars {
      display: inline-flex;
      gap: 2px;
    }
    .lms-nav__mark-bars span {
      width: 9px;
      height: 3px;
      border-radius: 1px;
    }
    .lms-nav__mark-bars span:nth-child(1) { background: var(--turf, #21935C); }
    .lms-nav__mark-bars span:nth-child(2) { background: var(--amber, #DDA043); }
    .lms-nav__mark-bars span:nth-child(3) { background: var(--red, #C6392F); }

    .lms-nav__tabs {
      display: flex;
      align-items: center;
      gap: 2px;
      flex: 1;
      overflow-x: auto;
      scrollbar-width: none;
    }
    .lms-nav__tabs::-webkit-scrollbar { display: none; }
    .lms-nav__tab {
      position: relative;
      padding: 10px 12px;
      color: var(--chalk-dim, #93A099);
      font-family: 'Inter', system-ui, sans-serif;
      font-weight: 600;
      font-size: 13.5px;
      letter-spacing: 0.01em;
      text-decoration: none;
      white-space: nowrap;
      border-radius: 6px;
      transition: color .15s ease, background .15s ease;
    }
    .lms-nav__tab:hover {
      color: var(--chalk, #F3F1E7);
      background: rgba(255,255,255,0.03);
    }
    .lms-nav__tab[aria-current="page"] {
      color: var(--amber, #DDA043);
    }
    .lms-nav__tab[aria-current="page"]::after {
      content: "";
      position: absolute;
      left: 12px; right: 12px; bottom: -1px;
      height: 2px;
      background: var(--amber, #DDA043);
      border-radius: 2px 2px 0 0;
    }

    @media (max-width: 520px) {
      .lms-nav__inner { padding: 0 12px; gap: 12px; height: 52px; }
      .lms-nav__mark { padding-right: 10px; font-size: 18px; }
      .lms-nav__tab { padding: 10px 8px; font-size: 13px; }
    }
  `;

  const styleEl = document.createElement('style');
  styleEl.textContent = css;
  document.head.appendChild(styleEl);

  // Which page are we on?
  const path = window.location.pathname;
  let filename = path.substring(path.lastIndexOf('/') + 1);
  if (!filename || filename === '/') filename = 'index.html';

  const tabs = [
    { file: 'index.html',           label: 'Pick' },
    { file: 'leaderboard.html',     label: 'Leaderboard' },
    { file: 'stats.html',           label: 'Stats' },
    { file: 'whatsapp-export.html', label: 'WhatsApp' },
    { file: 'admin.html',           label: 'Admin' }
  ];

  const tabsHtml = tabs.map(t => {
    const current = t.file === filename ? ' aria-current="page"' : '';
    return `<a class="lms-nav__tab" href="${t.file}"${current}>${t.label}</a>`;
  }).join('');

  const navHtml = `
    <nav class="lms-nav" aria-label="Primary">
      <div class="lms-nav__inner">
        <a class="lms-nav__mark" href="index.html" aria-label="PL LMS — Home">
          <span class="lms-nav__mark-stack">
            <span>LMS</span>
            <span class="lms-nav__mark-bars"><span></span><span></span><span></span></span>
          </span>
        </a>
        <div class="lms-nav__tabs">${tabsHtml}</div>
      </div>
    </nav>
  `;

  function insertNav(){
    document.body.insertAdjacentHTML('afterbegin', navHtml);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', insertNav);
  } else {
    insertNav();
  }
})();