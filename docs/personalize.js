/* Local personalization: create SVG nodes, never interpolate names as HTML. */
(function () {
  'use strict';
  const key = 'codex-welcome-name';
  function validate(value) {
    const name = String(value ?? '').normalize('NFC').trim();
    if (!name || Array.from(name).length > 20 || /[\u0000-\u001f\u007f-\u009f\u202a-\u202e\u2066-\u2069]/u.test(name)) {
      throw new Error('请输入 1–20 个字符，不含换行或控制字符。');
    }
    return name;
  }
  function saved() { try { return localStorage.getItem(key); } catch (_) { return null; } }
  function save(value) { const name = validate(value); try { localStorage.setItem(key, name); } catch (_) {} return name; }
  function svg(tag, attributes = {}) {
    const node = document.createElementNS('http://www.w3.org/2000/svg', tag);
    for (const [key, value] of Object.entries(attributes)) node.setAttribute(key, value);
    return node;
  }
  function apply(writing, value) {
    const name = validate(value || 'JimmSun');
    writing.setAttribute('aria-label', 'welcome ' + name);
    document.title = 'Codex Welcome · ' + name;
    if (name === 'JimmSun') return {name, letters: [], mode: 'handwriting'};
    writing.querySelectorAll('path[mask^="url(#glyph-4-"], mask[id^="glyph-4-"]').forEach(node => node.remove());
    const group = svg('g', {id: 'personal-name', fill: 'url(#ink)'});
    const characters = Array.from(name), atlas = window.CWGlyphs || {};
    const handwriting = characters.every(char => Object.hasOwn(atlas, char));
    const canvas = document.createElement('canvas'), context = canvas.getContext('2d');
    const family = 'system-ui, -apple-system, "Segoe UI", "Microsoft YaHei", sans-serif';
    context.font = '200px ' + family;
    const advances = characters.map(char => handwriting ? atlas[char].advance : context.measureText(char).width);
    const letters = [];
    let x = 0;
    characters.forEach((char, index) => {
      const cell = svg('g', {transform: `translate(${x},0)`});
      const id = 'custom-glyph-' + index, mask = svg('mask', {id, maskUnits: 'userSpaceOnUse', x: -400, y: -600, width: 1200, height: 1000});
      const ink = svg('g', {fill: 'none', stroke: 'white', 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': handwriting ? atlas[char].width : 500});
      const strokes = handwriting ? atlas[char].strokes : (char.trim() ? [`M -2,-85 H ${advances[index]+2}`] : []);
      strokes.forEach((d, stroke) => {
        const pathID = `custom-ink-${index}-${stroke}`;
        ink.appendChild(svg('path', {id: pathID, d}));
        letters.push({id: pathID});
      });
      mask.appendChild(ink); cell.appendChild(mask);
      const shape = svg(handwriting ? 'path' : 'text', {mask: `url(#${id})`});
      if (handwriting) shape.setAttribute('d', atlas[char].outline);
      else {
        shape.setAttribute('font-family', family); shape.setAttribute('font-size', '200');
        shape.textContent = char;
      }
      cell.appendChild(shape); group.appendChild(cell); x += advances[index];
    });
    writing.appendChild(group);
    const bounds = group.getBBox(), scale = Math.min(1, 1480 / Math.max(1, bounds.width));
    group.setAttribute('transform', `translate(${960-(bounds.x+bounds.width/2)*scale},760) scale(${scale})`);
    return {name, letters, mode: handwriting ? 'handwriting' : 'smooth-reveal'};
  }
  window.CWPersonalization = {validate, saved, save, apply};
})();
