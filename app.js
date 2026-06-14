/* CopyStack - getcopystack.xyz */
(() => {
  'use strict';
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---------- nav frosted on scroll ---------- */
  const nav = document.getElementById('nav');
  const onScroll = () => nav.classList.toggle('scrolled', window.scrollY > 12);
  onScroll();
  window.addEventListener('scroll', onScroll, { passive: true });

  /* ---------- staggered reveal-on-scroll ---------- */
  const reveals = [...document.querySelectorAll('.reveal')];
  // give grouped children a stagger index
  document.querySelectorAll('.steps, .feat-grid, .shots, .hero-meta, .hero-cta').forEach(group => {
    [...group.children].forEach((c, i) => {
      if (c.classList.contains('reveal')) c.dataset.d = Math.min(i + 1, 4);
    });
  });
  if (reduce || !('IntersectionObserver' in window)) {
    reveals.forEach(r => r.classList.add('in'));
  } else {
    const io = new IntersectionObserver((entries) => {
      entries.forEach(e => {
        if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
      });
    }, { threshold: 0.14, rootMargin: '0px 0px -8% 0px' });
    reveals.forEach(r => io.observe(r));
  }

  /* ---------- icons for the live demo rows ---------- */
  const IC = {
    text: '<svg viewBox="0 0 24 24"><path d="M6 8h12M6 12h12M6 16h7" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>',
    link: '<svg viewBox="0 0 24 24"><path d="M9 15l6-6M10.5 6.5l1.2-1.2a3.5 3.5 0 0 1 5 5l-1.2 1.2M13.5 17.5l-1.2 1.2a3.5 3.5 0 0 1-5-5l1.2-1.2" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>',
    play: '<svg viewBox="0 0 24 24"><path d="M9 8l7 4-7 4z" fill="currentColor"/></svg>',
    doc:  '<svg viewBox="0 0 24 24"><path d="M7 3h7l4 4v14H7z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/><path d="M14 3v4h4" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/></svg>',
    img:  '<svg viewBox="0 0 24 24"><rect x="4" y="5" width="16" height="14" rx="2" fill="none" stroke="currentColor" stroke-width="2"/><circle cx="9" cy="10" r="1.5" fill="currentColor"/><path d="M5 17l4-4 3 3 3-3 4 4" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/></svg>'
  };

  /* the deck the demo cycles through (top of list = next to paste) */
  const DECK = [
    { kind: 'text',  title: 'Q3 spend categories' },
    { kind: 'link',  title: 'figma.com' },
    { kind: 'video', title: 'Demo.mov', ext: 'MOV' },
    { kind: 'file',  title: 'report.pdf', ext: 'PDF' },
    { kind: 'image', title: 'Image' }
  ];

  const list = document.getElementById('demo-list');
  const countEl = document.getElementById('demo-count');
  const keycaps = document.getElementById('keycaps');
  const kcRows = keycaps ? [...keycaps.querySelectorAll('.kf-step')] : [];
  let model = [];        // current rows, index 0 = top/next
  let timer = null;
  let phase = 0;

  function rowEl(item, isNext, pos) {
    const li = document.createElement('li');
    li.className = 'row' + (isNext ? ' next' : '');
    let icon;
    if (item.kind === 'image') icon = `<span class="row-ic thumb"></span>`;
    else if (item.kind === 'video') icon = `<span class="row-ic thumb vid">${IC.play}</span>`;
    else icon = `<span class="row-ic">${IC[item.kind === 'file' ? 'doc' : item.kind]}</span>`;
    let tag = '';
    if (isNext) tag = `<span class="row-tag next">Next</span>`;
    else if (item.ext) tag = `<span class="row-tag ext">${item.ext}</span>`;
    li.innerHTML =
      `<span class="row-badge">${pos}</span>${icon}` +
      `<span class="row-title">${item.title}</span>${tag}`;
    return li;
  }

  function render() {
    list.innerHTML = '';
    model.forEach((item, i) => list.appendChild(rowEl(item, i === 0, i + 1)));
    if (countEl) countEl.textContent = model.length;
  }

  // highlight the action key the demo is currently performing (⌘C copy / ⌘V paste)
  function setAct(act) {
    kcRows.forEach(r => {
      const on = r.dataset.act === act;
      r.classList.toggle('active', on);
      if (on) { r.classList.remove('fire'); void r.offsetWidth; r.classList.add('fire'); }
    });
  }

  // seed full deck immediately so first paint looks complete
  model = DECK.slice();
  render();
  setAct('open'); // start on the activation shortcut, then the loop shows collect/paste

  function step() {
    // a calm loop that demonstrates both actions: paste the next item (⌘V),
    // then later copy a fresh one onto the stack (⌘C).
    if (phase < 1 && model.length > 3) {
      setAct('paste');
      const top = list.firstElementChild;
      if (top) {
        top.classList.add('leaving');
        setTimeout(() => { model.shift(); render(); }, 300);
      }
      phase++;
    } else {
      setAct('copy');
      const pool = DECK.filter(d => !model.some(m => m.title === d.title));
      const next = pool.length ? pool[0] : DECK[(model.length) % DECK.length];
      setTimeout(() => {
        model.unshift(next);
        if (model.length > 5) model.pop();
        render();
      }, 300);
      if (model.length >= 5) phase = 0;
    }
  }

  function start() {
    if (reduce || timer) return;
    timer = setInterval(step, 2100);
  }
  function stop() { clearInterval(timer); timer = null; }

  // run only while hero is visible
  const stage = document.querySelector('.hero-stage');
  if (stage && 'IntersectionObserver' in window) {
    new IntersectionObserver((es) => {
      es.forEach(e => e.isIntersecting ? start() : stop());
    }, { threshold: 0.3 }).observe(stage);
  } else { start(); }

  /* replay button */
  const replay = document.getElementById('replay');
  if (replay) replay.addEventListener('click', () => {
    stop(); phase = 0; model = DECK.slice(); render(); setAct('paste');
    document.getElementById('top').scrollIntoView({ behavior: reduce ? 'auto' : 'smooth' });
    start();
  });
})();
