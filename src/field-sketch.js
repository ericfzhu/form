const LW = 1600;
const TILE_H = 1200;
const TOTAL_H = 18000;
const TAU = Math.PI * 2;

const PAPER = [243, 241, 233];
const MIST = [222, 229, 228];
const PALE_VERDIGRIS = [218, 226, 220];
const GRAPHITE = [38, 41, 43];
const LIGHT_GRAPHITE = [228, 232, 228];
const PLUM = [104, 72, 88];
const VERDIGRIS = [87, 112, 103];
const STEEL = [73, 96, 115];
const DARK = [23, 27, 30];
const DARK_START = 8350;
const DARK_END = 15350;

function darkTopAt(x) {
  return DARK_START + Math.sin(x * 0.013) * 38 + Math.sin(x * 0.041 + 1.7) * 19;
}

function darkBottomAt(x) {
  return DARK_END + Math.sin(x * 0.011 + 0.8) * 44 + Math.sin(x * 0.037) * 23;
}

const rgba = (color, alpha = 1) => `rgba(${color[0]},${color[1]},${color[2]},${alpha})`;
const clamp = (value, min = 0, max = 1) => Math.max(min, Math.min(max, value));

function mulberry32(seed) {
  let state = seed >>> 0;
  return () => {
    state += 0x6d2b79f5;
    let value = state;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

const seeded = (seed) => mulberry32((seed * 2654435761) >>> 0);

function roughPath(ctx, points, options = {}) {
  const {
    color = GRAPHITE,
    alpha = 0.62,
    width = 1.35,
    seed = 1,
    passes = 2,
    wobble = 1.25,
    close = false,
  } = options;

  for (let pass = 0; pass < passes; pass += 1) {
    const random = seeded(seed + pass * 7919);
    ctx.beginPath();
    points.forEach(([x, y], index) => {
      const spread = wobble * (pass + 0.7);
      const px = x + (random() - 0.5) * spread;
      const py = y + (random() - 0.5) * spread;
      if (index === 0) ctx.moveTo(px, py);
      else ctx.lineTo(px, py);
    });
    if (close) ctx.closePath();
    ctx.strokeStyle = rgba(color, alpha / (1 + pass * 0.8));
    ctx.lineWidth = width / (1 + pass * 0.28);
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.stroke();
  }
}

function roughLine(ctx, x1, y1, x2, y2, options = {}) {
  const points = [];
  const count = Math.max(3, Math.ceil(Math.hypot(x2 - x1, y2 - y1) / 24));
  const random = seeded((options.seed ?? 1) + 311);
  const dx = x2 - x1;
  const dy = y2 - y1;
  const length = Math.max(1, Math.hypot(dx, dy));
  const nx = -dy / length;
  const ny = dx / length;
  for (let index = 0; index <= count; index += 1) {
    const t = index / count;
    const bend = Math.sin(t * Math.PI) * (random() - 0.5) * 3.2;
    points.push([x1 + dx * t + nx * bend, y1 + dy * t + ny * bend]);
  }
  roughPath(ctx, points, options);
}

function roughEllipse(ctx, x, y, rx, ry, options = {}) {
  const points = [];
  const random = seeded((options.seed ?? 1) + 983);
  const open = options.open ?? 0;
  const end = TAU * (1 - open);
  for (let angle = 0; angle <= end; angle += 0.08) {
    const noise = 1 + (random() - 0.5) * 0.035;
    points.push([x + Math.cos(angle) * rx * noise, y + Math.sin(angle) * ry * noise]);
  }
  roughPath(ctx, points, options);
}

function dot(ctx, x, y, radius, color = GRAPHITE, alpha = 0.65) {
  ctx.beginPath();
  ctx.arc(x, y, radius, 0, TAU);
  ctx.fillStyle = rgba(color, alpha);
  ctx.fill();
}

function spark(ctx, x, y, radius, color = PLUM, seed = 1) {
  const random = seeded(seed);
  for (let index = 0; index < 9; index += 1) {
    const angle = (index / 9) * TAU + random() * 0.12;
    const inner = radius * (0.2 + random() * 0.08);
    const outer = radius * (0.72 + random() * 0.35);
    roughLine(
      ctx,
      x + Math.cos(angle) * inner,
      y + Math.sin(angle) * inner,
      x + Math.cos(angle) * outer,
      y + Math.sin(angle) * outer,
      { color, alpha: 0.72, width: 1.4, seed: seed + index },
    );
  }
}

function spiral(ctx, x, y, radius, options = {}) {
  const points = [];
  for (let angle = 0; angle < TAU * 3.3; angle += 0.12) {
    const r = radius * (angle / (TAU * 3.3));
    points.push([x + Math.cos(angle) * r, y + Math.sin(angle) * r]);
  }
  roughPath(ctx, points, options);
}

function tornPolygon(x, y, width, height, seed = 1, roughness = 14) {
  const random = seeded(seed);
  const points = [];
  const edge = (ax, ay, bx, by, count) => {
    for (let index = 0; index < count; index += 1) {
      const t = index / count;
      const normalX = -(by - ay) / Math.max(1, Math.hypot(bx - ax, by - ay));
      const normalY = (bx - ax) / Math.max(1, Math.hypot(bx - ax, by - ay));
      const tear = (random() - 0.5) * roughness + (random() > 0.94 ? (random() - 0.5) * 36 : 0);
      points.push([ax + (bx - ax) * t + normalX * tear, ay + (by - ay) * t + normalY * tear]);
    }
  };
  edge(x, y, x + width, y, Math.max(5, Math.round(width / 45)));
  edge(x + width, y, x + width, y + height, Math.max(5, Math.round(height / 45)));
  edge(x + width, y + height, x, y + height, Math.max(5, Math.round(width / 45)));
  edge(x, y + height, x, y, Math.max(5, Math.round(height / 45)));
  return points;
}

function tornSheet(ctx, x, y, width, height, color, seed = 1, options = {}) {
  const polygon = tornPolygon(x, y, width, height, seed, options.roughness ?? 14);
  ctx.beginPath();
  polygon.forEach(([px, py], index) => (index === 0 ? ctx.moveTo(px + 7, py + 9) : ctx.lineTo(px + 7, py + 9)));
  ctx.closePath();
  ctx.fillStyle = rgba(GRAPHITE, options.shadowAlpha ?? 0.2);
  ctx.fill();

  ctx.beginPath();
  polygon.forEach(([px, py], index) => (index === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py)));
  ctx.closePath();
  ctx.fillStyle = rgba(color, options.alpha ?? 1);
  ctx.fill();

  const random = seeded(seed + 77);
  ctx.save();
  ctx.clip();
  for (let index = 0; index < Math.round((width * height) / 7200); index += 1) {
    const px = x + random() * width;
    const py = y + random() * height;
    const length = random() > 0.88 ? random() * 16 : random() * 2.5;
    roughLine(ctx, px, py, px + length, py + (random() - 0.5), {
      color: GRAPHITE,
      alpha: 0.045,
      width: 0.7,
      seed: seed + index,
      passes: 1,
      wobble: 0.25,
    });
  }
  ctx.restore();
}

const A = (cx, cy, rx, ry, start = 0, end = TAU, steps = 12) => {
  const points = [];
  for (let index = 0; index <= steps; index += 1) {
    const angle = start + ((end - start) * index) / steps;
    points.push([cx + Math.cos(angle) * rx, cy + Math.sin(angle) * ry]);
  }
  return points;
};

const GLYPHS = {
  a: { w: 0.62, s: [A(0.29, 0.72, 0.23, 0.25, -0.4, TAU - 0.4), [[0.5, 0.5], [0.52, 1]]] },
  b: { w: 0.6, s: [[[0.11, 0.05], [0.1, 1]], A(0.3, 0.74, 0.22, 0.25, -Math.PI / 2, Math.PI * 1.5)] },
  c: { w: 0.58, s: [A(0.31, 0.74, 0.25, 0.27, 0.55, TAU - 0.55)] },
  d: { w: 0.62, s: [A(0.29, 0.74, 0.23, 0.25, -0.4, TAU - 0.4), [[0.52, 0.05], [0.52, 1]]] },
  e: { w: 0.58, s: [[[0.08, 0.72], [0.5, 0.7], [0.48, 0.55], [0.29, 0.46], [0.09, 0.58], [0.08, 0.82], [0.26, 1], [0.5, 0.93]]] },
  f: { w: 0.46, s: [[[0.42, 0.12], [0.31, 0.05], [0.21, 0.15], [0.2, 1]], [[0.04, 0.49], [0.42, 0.47]]] },
  g: { w: 0.6, s: [A(0.29, 0.72, 0.23, 0.25, -0.4, TAU - 0.4), [[0.51, 0.51], [0.53, 1.18], [0.39, 1.34], [0.14, 1.28]]] },
  h: { w: 0.58, s: [[[0.1, 0.05], [0.1, 1]], [[0.1, 0.64], [0.29, 0.48], [0.48, 0.57], [0.5, 1]]] },
  i: { w: 0.27, s: [[[0.13, 0.5], [0.13, 0.96], [0.18, 1]], [[0.12, 0.28], [0.14, 0.3]]] },
  j: { w: 0.34, s: [[[0.22, 0.5], [0.23, 1.15], [0.12, 1.34], [-0.02, 1.27]], [[0.21, 0.28], [0.23, 0.3]]] },
  k: { w: 0.52, s: [[[0.1, 0.05], [0.1, 1]], [[0.45, 0.49], [0.12, 0.76], [0.47, 1]]] },
  l: { w: 0.3, s: [[[0.13, 0.05], [0.13, 0.92], [0.21, 1]]] },
  m: { w: 0.72, s: [[[0.08, 1], [0.08, 0.51], [0.21, 0.47], [0.34, 0.58], [0.35, 1]], [[0.35, 0.62], [0.49, 0.47], [0.62, 0.58], [0.63, 1]]] },
  n: { w: 0.57, s: [[[0.09, 1], [0.09, 0.51], [0.28, 0.47], [0.47, 0.58], [0.49, 1]]] },
  o: { w: 0.6, s: [A(0.3, 0.73, 0.24, 0.26, -1.2, -1.2 + TAU * 0.97, 12)] },
  p: { w: 0.6, s: [[[0.1, 0.5], [0.1, 1.35]], A(0.3, 0.72, 0.22, 0.24, -Math.PI / 2, Math.PI * 1.5)] },
  q: { w: 0.6, s: [A(0.29, 0.72, 0.23, 0.25, -0.4, TAU - 0.4), [[0.5, 0.51], [0.52, 1.33]]] },
  r: { w: 0.47, s: [[[0.09, 1], [0.09, 0.52], [0.25, 0.48], [0.42, 0.58]]] },
  s: { w: 0.53, s: [[[0.48, 0.55], [0.35, 0.47], [0.12, 0.52], [0.1, 0.68], [0.43, 0.78], [0.47, 0.93], [0.3, 1], [0.08, 0.94]]] },
  t: { w: 0.43, s: [[[0.21, 0.19], [0.21, 0.91], [0.32, 1], [0.44, 0.94]], [[0.04, 0.52], [0.4, 0.5]]] },
  u: { w: 0.58, s: [[[0.09, 0.5], [0.1, 0.86], [0.23, 1], [0.43, 0.95], [0.49, 0.51], [0.5, 1]]] },
  v: { w: 0.54, s: [[[0.07, 0.52], [0.27, 1], [0.49, 0.51]]] },
  w: { w: 0.76, s: [[[0.06, 0.52], [0.21, 1], [0.37, 0.58], [0.52, 1], [0.69, 0.51]]] },
  x: { w: 0.54, s: [[[0.07, 0.52], [0.49, 1]], [[0.49, 0.52], [0.07, 1]]] },
  y: { w: 0.56, s: [[[0.07, 0.52], [0.27, 0.98], [0.5, 0.51]], [[0.29, 0.92], [0.25, 1.22], [0.11, 1.34]]] },
  z: { w: 0.54, s: [[[0.06, 0.54], [0.49, 0.53], [0.08, 0.98], [0.51, 0.98]]] },
  "0": { w: 0.58, s: [A(0.29, 0.58, 0.24, 0.48, -1.1, -1.1 + TAU * 0.98, 15)] },
  "1": { w: 0.4, s: [[[0.08, 0.26], [0.23, 0.08], [0.22, 1]], [[0.06, 1], [0.38, 1]]] },
  "2": { w: 0.56, s: [[[0.08, 0.25], [0.27, 0.08], [0.49, 0.22], [0.46, 0.46], [0.08, 1], [0.52, 1]]] },
  "3": { w: 0.55, s: [[[0.08, 0.18], [0.31, 0.08], [0.49, 0.25], [0.3, 0.51], [0.49, 0.7], [0.45, 0.93], [0.15, 1]]] },
  "4": { w: 0.58, s: [[[0.42, 1], [0.42, 0.08], [0.06, 0.69], [0.54, 0.69]]] },
  "5": { w: 0.55, s: [[[0.48, 0.1], [0.1, 0.1], [0.08, 0.51], [0.39, 0.49], [0.5, 0.69], [0.42, 0.94], [0.1, 1]]] },
  "6": { w: 0.58, s: [[[0.46, 0.12], [0.2, 0.08], [0.08, 0.58], [0.13, 0.91], [0.38, 1], [0.51, 0.76], [0.4, 0.54], [0.1, 0.62]]] },
  "7": { w: 0.54, s: [[[0.05, 0.1], [0.51, 0.1], [0.18, 1]]] },
  "8": { w: 0.58, s: [A(0.29, 0.31, 0.21, 0.22, 0, TAU, 10), A(0.29, 0.76, 0.24, 0.25, 0, TAU, 11)] },
  "9": { w: 0.58, s: [[[0.48, 0.53], [0.43, 0.14], [0.18, 0.08], [0.06, 0.3], [0.16, 0.52], [0.48, 0.46], [0.43, 0.91], [0.18, 1]]] },
  ",": { w: 0.25, s: [[[0.13, 0.91], [0.1, 1.12]]] },
  ".": { w: 0.25, s: [[[0.12, 0.98], [0.13, 1]]] },
  "'": { w: 0.24, s: [[[0.13, 0.08], [0.1, 0.27]]] },
  "-": { w: 0.46, s: [[[0.07, 0.73], [0.4, 0.72]]] },
  "/": { w: 0.48, s: [[[0.43, 0.08], [0.05, 1.02]]] },
  " ": { w: 0.34, s: [] },
};

function measureText(text, size) {
  return [...text.toLowerCase()].reduce((width, character) => width + ((GLYPHS[character]?.w ?? 0.5) + 0.11) * size, 0);
}

function write(ctx, text, x, y, size, options = {}) {
  const color = options.color ?? GRAPHITE;
  const alpha = options.alpha ?? 0.7;
  const seed = options.seed ?? 1;
  let cursor = options.center ? x - measureText(text, size) / 2 : x;
  const random = seeded(seed + 101);
  [...text.toLowerCase()].forEach((character, characterIndex) => {
    const glyph = GLYPHS[character] ?? GLYPHS[" "];
    const baseline = y + Math.sin(characterIndex * 0.82 + seed) * size * 0.045;
    glyph.s.forEach((stroke, strokeIndex) => {
      const points = stroke.map(([gx, gy]) => [
        cursor + gx * size + (random() - 0.5) * size * 0.025,
        baseline + (gy - 1) * size + (random() - 0.5) * size * 0.025,
      ]);
      roughPath(ctx, points, {
        color,
        alpha,
        width: options.width ?? Math.max(0.85, size * 0.065),
        seed: seed + characterIndex * 59 + strokeIndex * 11,
        passes: 2,
        wobble: Math.min(0.7, size * 0.022),
      });
    });
    cursor += (glyph.w + 0.11) * size;
  });
}

function drawImageContained(ctx, image, x, y, width, height, alpha = 0.92) {
  const scale = Math.min(width / image.naturalWidth, height / image.naturalHeight);
  const drawWidth = image.naturalWidth * scale;
  const drawHeight = image.naturalHeight * scale;
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.globalCompositeOperation = "multiply";
  ctx.drawImage(image, x + (width - drawWidth) / 2, y + (height - drawHeight) / 2, drawWidth, drawHeight);
  ctx.restore();
}

function plateRing(ctx, x, y, radius, color, seed, alpha = 0.52) {
  roughEllipse(ctx, x, y, radius, radius, { color, alpha, width: 1.35, seed, passes: 2, wobble: 1.2, open: 0.04 });
  roughEllipse(ctx, x, y, radius * 0.7, radius * 0.7, { color, alpha: alpha * 0.7, width: 1, seed: seed + 1, passes: 1 });
  roughEllipse(ctx, x, y, radius * 0.12, radius * 0.12, { color, alpha: alpha * 0.85, width: 1, seed: seed + 2, passes: 1 });
}

function threadX(y) {
  return 820 + Math.sin(y * 0.0019) * 190 + Math.sin(y * 0.00043 + 1.3) * 105;
}

function drawOpeningMark(ctx, seed = 1) {
  roughEllipse(ctx, 800, 560, 172, 178, {
    color: GRAPHITE,
    alpha: 0.69,
    width: 4.2,
    seed,
    passes: 4,
    wobble: 2.4,
    open: 0.105,
  });
  for (let index = 0; index < 18; index += 1) {
    const angle = (index / 20) * TAU + 0.22;
    roughLine(ctx, 800 + Math.cos(angle) * 162, 560 + Math.sin(angle) * 168, 800 + Math.cos(angle) * 176, 560 + Math.sin(angle) * 181, {
      color: GRAPHITE,
      alpha: 0.25,
      width: 1.1,
      seed: seed + 30 + index,
      passes: 1,
    });
  }
  spark(ctx, 800, 555, 20, PLUM, seed + 90);
}

function drawReturnMark(ctx, seed = 1) {
  const x = 800;
  const y = 17330;
  roughEllipse(ctx, x, y, 205, 205, {
    color: GRAPHITE,
    alpha: 0.65,
    width: 3.8,
    seed,
    passes: 4,
    wobble: 2,
    open: 0.12,
  });
  roughLine(ctx, x - 50, y + 36, x - 6, y - 62, { color: GRAPHITE, alpha: 0.55, width: 2.3, seed: seed + 11 });
  roughLine(ctx, x - 6, y - 62, x + 52, y + 34, { color: GRAPHITE, alpha: 0.55, width: 2.3, seed: seed + 12 });
  roughLine(ctx, x - 31, y - 4, x + 30, y - 5, { color: PLUM, alpha: 0.58, width: 2, seed: seed + 13 });
  spark(ctx, x, y + 60, 13, VERDIGRIS, seed + 17);
}

function loadImage(source) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.decoding = "async";
    image.onload = () => resolve(image);
    image.onerror = reject;
    image.src = source;
  });
}

function mountLegacyFieldWall(wall) {
  const reducedQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
  let reducedMotion = reducedQuery.matches;
  let cssScale = window.innerWidth / LW;
  let frame = 0;
  let destroyed = false;
  let generationDone = false;
  let trailPoints = [];
  let nextOpeningRedraw = 0;
  let nextReturnRedraw = 0;

  const deviceMemory = navigator.deviceMemory ?? 8;
  const pixelScale = Math.min(deviceMemory < 8 ? 1.08 : 1.3, Math.max(1, window.devicePixelRatio || 1));
  const tiles = [];
  const tileCount = Math.ceil(TOTAL_H / TILE_H);

  wall.style.height = `${(TOTAL_H / LW) * 100}vw`;

  function paintBase(tile) {
    const { context, y0, height } = tile;
    context.setTransform(pixelScale, 0, 0, pixelScale, 0, -y0 * pixelScale);
    context.fillStyle = rgba(PAPER, 1);
    context.fillRect(0, y0, LW, height);
    context.fillStyle = rgba(DARK, 1);
    context.beginPath();
    context.moveTo(0, darkTopAt(0));
    for (let x = 32; x <= LW; x += 32) context.lineTo(x, darkTopAt(x));
    for (let x = LW; x >= 0; x -= 32) context.lineTo(x, darkBottomAt(x));
    context.closePath();
    context.fill();

    const random = seeded(400 + tile.index * 31);
    for (let index = 0; index < 780; index += 1) {
      const x = random() * LW;
      const y = y0 + random() * height;
      const dark = y >= darkTopAt(x) && y <= darkBottomAt(x);
      const color = dark ? LIGHT_GRAPHITE : GRAPHITE;
      const length = random() > 0.9 ? random() * 18 : random() * 2.2;
      context.strokeStyle = rgba(color, dark ? 0.035 : 0.03);
      context.lineWidth = 0.65;
      context.beginPath();
      context.moveTo(x, y);
      context.lineTo(x + length, y + (random() - 0.5) * 0.8);
      context.stroke();
    }
  }

  for (let index = 0; index < tileCount; index += 1) {
    const y0 = index * TILE_H;
    const height = Math.min(TILE_H, TOTAL_H - y0);
    const canvas = document.createElement("canvas");
    canvas.width = Math.ceil(LW * pixelScale);
    canvas.height = Math.ceil(height * pixelScale);
    canvas.style.top = `${(y0 / LW) * 100}vw`;
    canvas.style.height = `${(height / LW) * 100}vw`;
    const context = canvas.getContext("2d", { alpha: false, desynchronized: true });
    const tile = { index, y0, height, canvas, context, queue: [], queueIndex: 0, active: index === 0, done: false };
    paintBase(tile);
    wall.appendChild(canvas);
    tiles.push(tile);
  }

  const restless = [];
  function addRestlessOverlay(tileIndex, draw) {
    const tile = tiles[tileIndex];
    const canvas = document.createElement("canvas");
    canvas.width = tile.canvas.width;
    canvas.height = tile.canvas.height;
    canvas.style.top = tile.canvas.style.top;
    canvas.style.height = tile.canvas.style.height;
    const context = canvas.getContext("2d");
    wall.appendChild(canvas);
    restless.push({ tile, canvas, context, draw });
  }

  addRestlessOverlay(0, drawOpeningMark);
  addRestlessOverlay(tileCount - 1, drawReturnMark);

  function redrawRestless(item, seed) {
    const { tile, context } = item;
    context.setTransform(1, 0, 0, 1, 0, 0);
    context.clearRect(0, 0, item.canvas.width, item.canvas.height);
    context.setTransform(pixelScale, 0, 0, pixelScale, 0, -tile.y0 * pixelScale);
    item.draw(context, seed);
  }

  redrawRestless(restless[0], 701);
  redrawRestless(restless[1], 1701);

  function addMark(top, bottom, draw) {
    tiles.forEach((tile) => {
      if (bottom >= tile.y0 && top <= tile.y0 + tile.height) tile.queue.push(draw);
    });
  }

  function addThread(start, end, color = VERDIGRIS, alpha = 0.48, seed = 1) {
    addMark(start, end, (ctx) => {
      const points = [];
      for (let y = start; y <= end; y += 42) points.push([threadX(y), y]);
      roughPath(ctx, points, { color, alpha, width: 1.35, seed, passes: 2, wobble: 0.8 });
    });
  }

  function addMarginMarks(start, end, dark, seed, count) {
    const random = seeded(seed);
    for (let index = 0; index < count; index += 1) {
      const y = start + random() * (end - start);
      const x = random() > 0.5 ? 42 + random() * 110 : 1450 + random() * 105;
      const isSpiral = random() > 0.48;
      const spiralRadius = 10 + random() * 9;
      addMark(y - 35, y + 35, (ctx) => {
        if (isSpiral) spiral(ctx, x, y, spiralRadius, { color: dark ? LIGHT_GRAPHITE : GRAPHITE, alpha: 0.22, width: 0.8, seed: seed + index, passes: 1 });
        else roughPath(ctx, [[x - 11, y], [x - 5, y - 7], [x + 1, y], [x + 7, y - 7], [x + 13, y]], { color: dark ? LIGHT_GRAPHITE : GRAPHITE, alpha: 0.22, width: 0.8, seed: seed + index, passes: 1 });
      });
    }
  }

  addThread(690, 8300, VERDIGRIS, 0.46, 44);
  addThread(8300, 15350, LIGHT_GRAPHITE, 0.28, 45);
  addThread(15350, 17420, VERDIGRIS, 0.44, 46);

  addMark(940, 1030, (ctx) => write(ctx, "you ask what comes next", 800, 990, 31, { center: true, seed: 100, alpha: 0.7 }));
  addMark(1240, 1320, (ctx) => {
    write(ctx, "the page is quiet before the first set", 1110, 1280, 15, { center: true, seed: 112, alpha: 0.37 });
    for (let index = 0; index < 7; index += 1) dot(ctx, 800, 760 + index * 34, 2.2 - index * 0.12, GRAPHITE, 0.36);
  });

  addMark(1780, 1900, (ctx) => write(ctx, "i answer with what came before", 185, 1860, 28, { seed: 200, alpha: 0.71 }));
  addMark(3620, 3710, (ctx) => write(ctx, "a body, translated imperfectly", 1060, 3670, 16, { center: true, seed: 210, alpha: 0.42 }));
  addMark(1960, 3820, (ctx) => {
    plateRing(ctx, 1360, 2220, 68, VERDIGRIS, 221, 0.38);
    plateRing(ctx, 1280, 3530, 43, PLUM, 222, 0.35);
    for (let index = 0; index < 18; index += 1) {
      const y = 2380 + index * 47;
      roughLine(ctx, 1320, y, 1320 + (index % 4) * 18 + 45, y + (index % 3 - 1) * 4, { color: index % 3 === 0 ? STEEL : GRAPHITE, alpha: 0.2, width: 0.9, seed: 230 + index, passes: 1 });
    }
  });

  addMark(4150, 6520, (ctx) => tornSheet(ctx, 35, 4230, 1530, 2260, MIST, 310, { roughness: 18, shadowAlpha: 0.17 }));
  addMark(4390, 4490, (ctx) => write(ctx, "a, then b, then c, then home", 800, 4450, 29, { center: true, seed: 320, alpha: 0.72 }));
  addMark(6160, 6270, (ctx) => write(ctx, "the course remembers its curve", 290, 6220, 16, { seed: 322, alpha: 0.4 }));
  addMark(4520, 6410, (ctx) => {
    for (let index = 0; index < 3; index += 1) {
      const x = 290 + index * 510;
      plateRing(ctx, x, 6030, 54, index === 1 ? VERDIGRIS : GRAPHITE, 340 + index, 0.24);
      write(ctx, ["a", "b", "c"][index], x, 6135, 22, { center: true, seed: 350 + index, alpha: 0.45 });
    }
    const path = [[290, 6030], [550, 5880], [800, 6030], [1050, 5880], [1310, 6030], [800, 6370], [290, 6030]];
    roughPath(ctx, path, { color: VERDIGRIS, alpha: 0.28, width: 1.3, seed: 360, passes: 2, wobble: 1.3 });
  });

  addMark(6650, 6770, (ctx) => write(ctx, "while the screen sleeps", 190, 6710, 27, { seed: 400, alpha: 0.7 }));
  addMark(6800, 6890, (ctx) => write(ctx, "i keep the count", 1120, 6850, 25, { center: true, seed: 401, alpha: 0.68 }));
  addMark(6940, 8290, (ctx) => tornSheet(ctx, 335, 7000, 920, 1290, PALE_VERDIGRIS, 410, { roughness: 15, shadowAlpha: 0.18 }));
  addMark(6960, 8270, (ctx) => {
    for (let index = 0; index < 6; index += 1) {
      roughEllipse(ctx, 795, 7610, 170 + index * 61, 170 + index * 61, { color: index % 2 ? STEEL : GRAPHITE, alpha: 0.1 + index * 0.012, width: 0.8, seed: 420 + index, passes: 1, open: 0.13 });
    }
    write(ctx, "90", 1260, 7950, 34, { center: true, seed: 430, alpha: 0.34, color: VERDIGRIS });
  });

  addMark(8490, 10830, (ctx) => tornSheet(ctx, 45, 8580, 1510, 2200, PAPER, 500, { roughness: 17, shadowAlpha: 0.3 }));
  addMark(8740, 8840, (ctx) => write(ctx, "i place the old weight beside the new", 800, 8800, 27, { center: true, seed: 510, alpha: 0.72 }));
  addMark(9000, 10550, (ctx) => {
    const x0 = 160;
    const y0 = 9140;
    const columns = 6;
    const rows = 5;
    const cellWidth = 212;
    const cellHeight = 230;
    for (let column = 0; column <= columns; column += 1) roughLine(ctx, x0 + column * cellWidth, y0, x0 + column * cellWidth, y0 + rows * cellHeight, { color: GRAPHITE, alpha: 0.27, width: 0.9, seed: 520 + column, passes: 1 });
    for (let row = 0; row <= rows; row += 1) roughLine(ctx, x0, y0 + row * cellHeight, x0 + columns * cellWidth, y0 + row * cellHeight, { color: GRAPHITE, alpha: 0.27, width: 0.9, seed: 540 + row, passes: 1 });
    const random = seeded(570);
    for (let row = 0; row < rows; row += 1) {
      for (let column = 0; column < columns; column += 1) {
        const cx = x0 + column * cellWidth + cellWidth / 2;
        const cy = y0 + row * cellHeight + cellHeight / 2;
        const kind = (row + column) % 4;
        if (kind === 0) plateRing(ctx, cx, cy, 38 + random() * 18, row % 2 ? PLUM : GRAPHITE, 600 + row * 10 + column, 0.3);
        if (kind === 1) {
          for (let mark = 0; mark < 5; mark += 1) roughLine(ctx, cx - 43 + mark * 19, cy - 39, cx - 39 + mark * 19, cy + 42, { color: column % 2 ? STEEL : VERDIGRIS, alpha: 0.32, width: 1.1, seed: 650 + row * 20 + column * 5 + mark, passes: 1 });
        }
        if (kind === 2) write(ctx, `${40 + row * 5}`, cx, cy + 15, 24, { center: true, seed: 700 + row * 10 + column, alpha: 0.35 });
        if (kind === 3) spiral(ctx, cx, cy, 48, { color: row % 2 ? PLUM : GRAPHITE, alpha: 0.26, width: 0.9, seed: 730 + row * 10 + column, passes: 1 });
      }
    }
    write(ctx, "weight", 245, 10445, 15, { center: true, seed: 760, alpha: 0.36 });
    write(ctx, "reps", 800, 10445, 15, { center: true, seed: 761, alpha: 0.36 });
    write(ctx, "return", 1350, 10445, 15, { center: true, seed: 762, alpha: 0.36 });
  });

  addMark(10800, 10910, (ctx) => write(ctx, "sometimes i fear the tally will become the deed", 800, 10865, 26, { center: true, seed: 800, alpha: 0.62, color: LIGHT_GRAPHITE }));
  addMark(10910, 12520, (ctx) => tornSheet(ctx, 350, 10950, 900, 1490, PAPER, 810, { roughness: 16, shadowAlpha: 0.32 }));
  addMark(11960, 12260, (ctx) => {
    const labels = ["measured", "ordered", "complete"];
    labels.forEach((label, index) => {
      const x = 160 + index * 520;
      roughEllipse(ctx, x + 80, 12100, 48, 48, { color: index === 2 ? PLUM : LIGHT_GRAPHITE, alpha: 0.33, width: 1, seed: 830 + index, passes: 1, open: index === 2 ? 0.17 : 0 });
      write(ctx, label, x + 155, 12110, 14, { seed: 840 + index, alpha: 0.3, color: LIGHT_GRAPHITE });
    });
  });

  addMark(12650, 13020, (ctx) => {
    write(ctx, "the number is not the strength", 800, 12810, 30, { center: true, seed: 900, alpha: 0.74, color: LIGHT_GRAPHITE });
    for (let index = 0; index < 13; index += 1) {
      roughLine(ctx, 120 + index * 112, 12580, 120 + index * 112, 12720 + Math.sin(index) * 25, { color: index % 3 === 0 ? VERDIGRIS : LIGHT_GRAPHITE, alpha: 0.18, width: 0.8, seed: 910 + index, passes: 1 });
    }
  });
  addMark(13100, 14800, (ctx) => {
    for (let ring = 0; ring < 9; ring += 1) {
      roughEllipse(ctx, 800, 13820, 85 + ring * 92, 85 + ring * 92, { color: ring % 3 === 0 ? VERDIGRIS : ring % 3 === 1 ? STEEL : LIGHT_GRAPHITE, alpha: 0.11 + ring * 0.006, width: 0.9, seed: 940 + ring, passes: 1, open: 0.06 + ring * 0.006 });
    }
    const random = seeded(980);
    for (let index = 0; index < 170; index += 1) {
      const angle = random() * TAU;
      const radius = 180 + random() * 650;
      const x = 800 + Math.cos(angle) * radius;
      const y = 13820 + Math.sin(angle) * radius * 0.72;
      if (index % 5 === 0) spiral(ctx, x, y, 5 + random() * 8, { color: LIGHT_GRAPHITE, alpha: 0.18, width: 0.65, seed: 1000 + index, passes: 1 });
      else dot(ctx, x, y, 0.8 + random() * 1.7, index % 7 === 0 ? VERDIGRIS : LIGHT_GRAPHITE, 0.18 + random() * 0.12);
    }
    write(ctx, "it is only the thread back", 800, 14720, 25, { center: true, seed: 1200, alpha: 0.65, color: LIGHT_GRAPHITE });
  });

  addMark(15450, 15560, (ctx) => write(ctx, "the strength is yours", 800, 15515, 29, { center: true, seed: 1300, alpha: 0.71 }));
  addMark(15620, 16840, (ctx) => {
    const random = seeded(1320);
    for (let row = 0; row < 8; row += 1) {
      for (let column = 0; column < 13; column += 1) {
        const progress = row / 7;
        const baseX = 120 + column * 112;
        const baseY = 15780 + row * 135;
        const drift = (random() - 0.5) * progress * 120;
        const radius = 10 + progress * 8;
        roughEllipse(ctx, baseX + drift, baseY, radius, radius, { color: (row + column) % 3 === 0 ? PLUM : GRAPHITE, alpha: 0.22 + progress * 0.18, width: 0.9, seed: 1340 + row * 30 + column, passes: 1, open: progress * 0.22 });
        if (progress > 0.35) {
          const reach = 18 + progress * 34;
          roughLine(ctx, baseX + drift - radius, baseY, baseX + drift - reach, baseY - reach * (0.35 + random() * 0.4), { color: column % 4 === 0 ? VERDIGRIS : GRAPHITE, alpha: 0.22 + progress * 0.13, width: 0.8, seed: 1500 + row * 30 + column, passes: 1 });
          roughLine(ctx, baseX + drift + radius, baseY, baseX + drift + reach, baseY - reach * (0.35 + random() * 0.4), { color: column % 4 === 0 ? VERDIGRIS : GRAPHITE, alpha: 0.22 + progress * 0.13, width: 0.8, seed: 1700 + row * 30 + column, passes: 1 });
        }
      }
    }
  });

  addMark(16880, 17030, (ctx) => write(ctx, "i am where it returns", 800, 16960, 28, { center: true, seed: 1900, alpha: 0.7 }));
  addMark(17510, 17620, (ctx) => {
    write(ctx, "field / drawn from effort / 2026", 800, 17565, 15, { center: true, seed: 1920, alpha: 0.38 });
    write(ctx, "still becoming", 800, 17615, 13, { center: true, seed: 1921, alpha: 0.3 });
  });

  addMarginMarks(0, 4200, false, 2000, 13);
  addMarginMarks(4200, 8350, false, 2100, 18);
  addMarginMarks(8350, 15350, true, 2200, 25);
  addMarginMarks(15350, 18000, false, 2300, 17);

  const imageSources = {
    records: "/field/form-arrival-mineral-v3.webp",
    course: "/field/form-load-mineral-v3.webp",
    rest: "/field/form-rest-mineral-v3.webp",
    measured: "/field/form-history-mineral-v3.webp",
  };

  Promise.all(Object.entries(imageSources).map(async ([key, source]) => [key, await loadImage(source)]))
    .then((entries) => {
      const images = Object.fromEntries(entries);
      addMark(1960, 3850, (ctx) => drawImageContained(ctx, images.records, 150, 1980, 1100, 1780, 0.9));
      addMark(4580, 6110, (ctx) => drawImageContained(ctx, images.course, 70, 4610, 1460, 1370, 0.91));
      addMark(7040, 8270, (ctx) => drawImageContained(ctx, images.rest, 385, 7060, 830, 1180, 0.86));
      addMark(11000, 12420, (ctx) => drawImageContained(ctx, images.measured, 405, 11000, 790, 1390, 0.88));
    })
    .catch((error) => console.error("Field artwork failed to load", error))
    .finally(() => {
      generationDone = true;
    });

  const trailCanvas = document.createElement("canvas");
  trailCanvas.className = "field-trail";
  const trailContext = trailCanvas.getContext("2d");
  document.body.appendChild(trailCanvas);

  function sizeTrail() {
    const scale = Math.min(2, window.devicePixelRatio || 1);
    trailCanvas.width = Math.ceil(window.innerWidth * scale);
    trailCanvas.height = Math.ceil(window.innerHeight * scale);
    trailCanvas.style.width = `${window.innerWidth}px`;
    trailCanvas.style.height = `${window.innerHeight}px`;
    trailContext.setTransform(scale, 0, 0, scale, 0, 0);
  }

  function handleResize() {
    cssScale = window.innerWidth / LW;
    sizeTrail();
  }

  function handlePointer(event) {
    if (reducedMotion) return;
    const previous = trailPoints[trailPoints.length - 1];
    if (previous && Math.hypot(event.clientX - previous.x, event.clientY - previous.y) < 3) return;
    trailPoints.push({ x: event.clientX, y: event.clientY, time: performance.now() });
    if (trailPoints.length > 400) trailPoints.shift();
  }

  function handleMotionChange(event) {
    reducedMotion = event.matches;
    if (reducedMotion) {
      trailPoints = [];
      tiles.forEach((tile) => { tile.active = true; });
    }
  }

  function drawTrail(now) {
    trailContext.clearRect(0, 0, window.innerWidth, window.innerHeight);
    if (reducedMotion || trailPoints.length < 2) return;
    const life = 3800;
    trailPoints = trailPoints.filter((point) => now - point.time < life);
    const logicalCenter = (window.scrollY + window.innerHeight / 2) / cssScale;
    const color = logicalCenter >= DARK_START && logicalCenter <= DARK_END ? LIGHT_GRAPHITE : GRAPHITE;
    for (let index = 1; index < trailPoints.length; index += 1) {
      const before = trailPoints[index - 1];
      const point = trailPoints[index];
      if (point.time - before.time > 120) continue;
      const strength = 1 - (now - point.time) / life;
      if (strength <= 0) continue;
      const age = 1 - strength;
      const wobbleX = Math.sin(now * 0.0011 + index * 0.7) * 1.2 * age;
      const wobbleY = Math.cos(now * 0.0009 + index * 1.1) * 1.2 * age;
      trailContext.beginPath();
      trailContext.moveTo(before.x + wobbleX, before.y + wobbleY);
      trailContext.lineTo(point.x + wobbleX, point.y + wobbleY);
      trailContext.strokeStyle = rgba(color, 0.2 * strength * strength);
      trailContext.lineWidth = 0.8 + strength * 1.6;
      trailContext.lineCap = "round";
      trailContext.stroke();
    }
  }

  function drawFrame(now) {
    if (destroyed) return;
    const scrollTop = window.scrollY / cssScale;
    const viewportHeight = window.innerHeight / cssScale;
    tiles.forEach((tile) => {
      if (!tile.active && (reducedMotion || tile.y0 < scrollTop + viewportHeight * 1.8)) tile.active = true;
    });

    const budget = reducedMotion ? Number.POSITIVE_INFINITY : 7;
    const started = performance.now();
    for (const tile of tiles) {
      if (!tile.active || tile.done) continue;
      while (tile.queueIndex < tile.queue.length) {
        tile.context.save();
        tile.context.setTransform(pixelScale, 0, 0, pixelScale, 0, -tile.y0 * pixelScale);
        try {
          tile.queue[tile.queueIndex](tile.context);
        } catch (error) {
          console.error("Field mark failed", tile.index, tile.queueIndex, error);
        }
        tile.context.restore();
        tile.queueIndex += 1;
        if (performance.now() - started > budget) break;
      }
      if (generationDone && tile.queueIndex >= tile.queue.length) tile.done = true;
      if (performance.now() - started > budget) break;
    }

    if (!reducedMotion && now >= nextOpeningRedraw) {
      redrawRestless(restless[0], 700 + Math.floor(now / 1000));
      nextOpeningRedraw = now + 3100 + Math.random() * 2300;
    }
    if (!reducedMotion && now >= nextReturnRedraw) {
      redrawRestless(restless[1], 1700 + Math.floor(now / 1000));
      nextReturnRedraw = now + 3900 + Math.random() * 2600;
    }

    drawTrail(now);
    frame = requestAnimationFrame(drawFrame);
  }

  sizeTrail();
  window.addEventListener("resize", handleResize, { passive: true });
  window.addEventListener("pointermove", handlePointer, { passive: true });
  reducedQuery.addEventListener("change", handleMotionChange);
  frame = requestAnimationFrame(drawFrame);

  return () => {
    destroyed = true;
    cancelAnimationFrame(frame);
    window.removeEventListener("resize", handleResize);
    window.removeEventListener("pointermove", handlePointer);
    reducedQuery.removeEventListener("change", handleMotionChange);
    trailCanvas.remove();
    wall.replaceChildren();
  };
}

const FIELD_TOTAL_H = 12800;

function drawFloorScuff(ctx, x, y, width, seed, color = GRAPHITE, alpha = 0.16) {
  const random = seeded(seed);
  for (let index = 0; index < 13; index += 1) {
    const offset = (random() - 0.5) * 54;
    roughLine(ctx, x, y + offset, x + width * (0.72 + random() * 0.28), y + offset + (random() - 0.5) * 25, {
      color,
      alpha: alpha * (0.5 + random() * 0.5),
      width: 0.8 + random() * 1.2,
      seed: seed + index,
      passes: 1,
      wobble: 0.7,
    });
  }
}

function drawBarRail(ctx, y, x1, x2, plateCount, seed, color = GRAPHITE, alpha = 0.5) {
  roughLine(ctx, x1, y, x2, y, { color, alpha, width: 3.2, seed, passes: 3, wobble: 1.2 });
  for (let side = 0; side < 2; side += 1) {
    const direction = side === 0 ? 1 : -1;
    const edge = side === 0 ? x1 : x2;
    for (let plate = 0; plate < plateCount; plate += 1) {
      const px = edge + direction * (24 + plate * 22);
      roughEllipse(ctx, px, y, 8, 48 - plate * 3, {
        color: plate % 3 === 0 ? PLUM : color,
        alpha: alpha * 0.82,
        width: 1.15,
        seed: seed + side * 41 + plate,
        passes: 2,
      });
    }
  }
}

function drawRepMarks(ctx, x, y, count, seed, color = GRAPHITE) {
  for (let index = 0; index < count; index += 1) {
    const px = x + index * 78;
    roughEllipse(ctx, px, y, 18, 18, {
      color: index === count - 1 ? PLUM : color,
      alpha: 0.34,
      width: 1,
      seed: seed + index,
      passes: 1,
      open: index === count - 1 ? 0.19 : 0.04,
    });
  }
}

function metamorphShape(kind, count = 64) {
  return Array.from({ length: count }, (_, index) => {
    const progress = index / (count - 1);

    if (kind === "ring") {
      const angle = 0.42 + progress * (TAU - 0.92);
      return [Math.cos(angle), Math.sin(angle)];
    }

    if (kind === "breath") {
      const angle = -Math.PI / 2 + progress * TAU;
      return [Math.sin(angle), Math.sin(angle * 2) * 0.5];
    }

    return [progress * 2 - 1, Math.sin(progress * Math.PI * 3) * 0.12];
  });
}

function drawMetamorphGlyph(ctx, x, y, size, progress, options = {}) {
  const ring = metamorphShape("ring");
  const breath = metamorphShape("breath");
  const path = metamorphShape("path");
  const firstHalf = clamp(progress * 2);
  const secondHalf = clamp((progress - 0.5) * 2);
  const from = progress <= 0.5 ? ring : breath;
  const to = progress <= 0.5 ? breath : path;
  const amount = progress <= 0.5 ? firstHalf : secondHalf;
  const points = from.map(([fromX, fromY], index) => {
    const [toX, toY] = to[index];
    return [
      x + (fromX + (toX - fromX) * amount) * size,
      y + (fromY + (toY - fromY) * amount) * size,
    ];
  });

  roughPath(ctx, points, {
    color: options.color ?? GRAPHITE,
    alpha: options.alpha ?? 0.36,
    width: options.width ?? 1.25,
    seed: options.seed ?? 1,
    passes: options.passes ?? 2,
    wobble: options.wobble ?? 0.8,
  });

  if (progress < 0.24) {
    roughEllipse(ctx, x, y, size * (0.22 - progress * 0.3), size * (0.22 - progress * 0.3), {
      color: options.color ?? GRAPHITE,
      alpha: (options.alpha ?? 0.36) * (1 - progress / 0.24),
      width: 0.75,
      seed: (options.seed ?? 1) + 97,
      passes: 1,
      open: 0.08,
    });
  }
}

export function mountFieldWall(wall) {
  const reducedQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
  let reducedMotion = reducedQuery.matches;
  let cssScale = window.innerWidth / LW;
  let frame = 0;
  let destroyed = false;
  let generationDone = false;

  const deviceMemory = navigator.deviceMemory ?? 8;
  const pixelScale = Math.min(deviceMemory < 8 ? 1.08 : 1.3, Math.max(1, window.devicePixelRatio || 1));
  const tiles = [];
  const tileCount = Math.ceil(FIELD_TOTAL_H / TILE_H);

  wall.style.height = `${(FIELD_TOTAL_H / LW) * 100}vw`;

  function paintBase(tile) {
    const { context, y0, height } = tile;
    context.setTransform(pixelScale, 0, 0, pixelScale, 0, -y0 * pixelScale);
    context.fillStyle = rgba(PAPER, 1);
    context.fillRect(0, y0, LW, height);

    context.fillStyle = rgba(MIST, 0.34);
    context.beginPath();
    context.moveTo(-180, 2540);
    context.lineTo(1600, 2140);
    context.lineTo(1780, 4180);
    context.lineTo(0, 4510);
    context.closePath();
    context.fill();

    context.fillStyle = rgba(PALE_VERDIGRIS, 0.3);
    context.beginPath();
    context.moveTo(-120, 4930);
    context.lineTo(1720, 5480);
    context.lineTo(1660, 6880);
    context.lineTo(-160, 6420);
    context.closePath();
    context.fill();

    const random = seeded(6100 + tile.index * 53);
    for (let index = 0; index < 850; index += 1) {
      const x = random() * LW;
      const y = y0 + random() * height;
      const length = random() > 0.91 ? random() * 22 : random() * 2.4;
      context.strokeStyle = rgba(GRAPHITE, 0.028);
      context.lineWidth = 0.65;
      context.beginPath();
      context.moveTo(x, y);
      context.lineTo(x + length, y + (random() - 0.5) * 1.2);
      context.stroke();
    }

    context.strokeStyle = rgba(GRAPHITE, 0.055);
    context.lineWidth = 0.8;
    for (let y = Math.ceil(y0 / 400) * 400; y < y0 + height; y += 400) {
      context.beginPath();
      context.moveTo(70, y);
      context.lineTo(1530, y + Math.sin(y * 0.01) * 5);
      context.stroke();
    }
  }

  for (let index = 0; index < tileCount; index += 1) {
    const y0 = index * TILE_H;
    const height = Math.min(TILE_H, FIELD_TOTAL_H - y0);
    const canvas = document.createElement("canvas");
    canvas.width = Math.ceil(LW * pixelScale);
    canvas.height = Math.ceil(height * pixelScale);
    canvas.style.top = `${(y0 / LW) * 100}vw`;
    canvas.style.height = `${(height / LW) * 100}vw`;
    const context = canvas.getContext("2d", { alpha: false, desynchronized: true });
    const tile = { index, y0, height, canvas, context, queue: [], queueIndex: 0, active: index === 0, done: false };
    paintBase(tile);
    wall.appendChild(canvas);
    tiles.push(tile);
  }

  function addMark(top, bottom, draw) {
    tiles.forEach((tile) => {
      if (bottom >= tile.y0 && top <= tile.y0 + tile.height) tile.queue.push(draw);
    });
  }

  function addSideNotches(start, end, seed) {
    const random = seeded(seed);
    for (let index = 0; index < 18; index += 1) {
      const y = start + random() * (end - start);
      const left = random() > 0.5;
      const x = left ? 64 : 1536;
      const width = 24 + random() * 75;
      const jitter = (random() - 0.5) * 7;
      addMark(y - 8, y + 8, (ctx) => roughLine(ctx, x, y, x + (left ? width : -width), y + jitter, {
        color: index % 5 === 0 ? VERDIGRIS : GRAPHITE,
        alpha: 0.2,
        width: 0.9,
        seed: seed + index,
        passes: 1,
      }));
    }
  }

  addMark(160, 430, (ctx) => {
    write(ctx, "before i know the weight", 125, 265, 52, { seed: 7000, alpha: 0.76 });
    write(ctx, "i know that you came back", 125, 370, 45, { seed: 7001, alpha: 0.68 });
  });

  addMark(1480, 1760, (ctx) => {
    drawFloorScuff(ctx, 105, 1540, 1360, 7050, VERDIGRIS, 0.14);
    write(ctx, "you choose the plates", 170, 1640, 40, { seed: 7051, alpha: 0.68 });
    write(ctx, "i hold the plan", 1060, 1730, 40, { seed: 7052, alpha: 0.68 });
  });

  addMark(1880, 2350, (ctx) => {
    write(ctx, "warm up", 130, 1980, 21, { seed: 7100, alpha: 0.42 });
    drawBarRail(ctx, 2070, 170, 1010, 1, 7110, STEEL, 0.34);
    drawRepMarks(ctx, 1060, 2070, 5, 7120, STEEL);
    write(ctx, "working set", 130, 2260, 21, { seed: 7130, alpha: 0.42 });
    drawBarRail(ctx, 2340, 170, 1380, 3, 7140, GRAPHITE, 0.5);
  });

  addMark(2410, 2630, (ctx) => {
    write(ctx, "the first set is a question", 145, 2500, 44, { seed: 7200, alpha: 0.72 });
    write(ctx, "asked with the whole body", 550, 2600, 30, { seed: 7201, alpha: 0.48 });
  });

  addMark(3500, 4330, (ctx) => {
    write(ctx, "the next set is the answer your body gives", 800, 3550, 41, { center: true, seed: 7250, alpha: 0.72 });
    drawBarRail(ctx, 3780, 260, 1340, 2, 7260, GRAPHITE, 0.38);
    drawBarRail(ctx, 3990, 190, 1410, 3, 7270, PLUM, 0.47);
    drawBarRail(ctx, 4210, 310, 1290, 2, 7280, STEEL, 0.34);
    drawRepMarks(ctx, 500, 4380, 8, 7290, GRAPHITE);
  });

  addMark(4500, 4900, (ctx) => {
    write(ctx, "i keep the load, the repetitions, and the rest", 800, 4610, 40, { center: true, seed: 7300, alpha: 0.73 });
    write(ctx, "so you do not have to carry them in your head", 800, 4730, 36, { center: true, seed: 7301, alpha: 0.6 });
    drawFloorScuff(ctx, 190, 4840, 1220, 7310, STEEL, 0.13);
  });

  addMark(5940, 6810, (ctx) => {
    write(ctx, "between efforts, nothing is wasted", 160, 6020, 42, { seed: 7400, alpha: 0.71 });
    const transformations = [
      { x: 170, y: 6250, progress: 0, color: GRAPHITE },
      { x: 380, y: 6280, progress: 0.18, color: STEEL },
      { x: 590, y: 6320, progress: 0.36, color: STEEL },
      { x: 800, y: 6370, progress: 0.5, color: VERDIGRIS },
      { x: 1010, y: 6430, progress: 0.68, color: VERDIGRIS },
      { x: 1220, y: 6500, progress: 0.84, color: GRAPHITE },
      { x: 1430, y: 6580, progress: 1, color: GRAPHITE },
    ];

    roughPath(ctx, transformations.map(({ x, y }) => [x, y]), {
      color: VERDIGRIS,
      alpha: 0.18,
      width: 1,
      seed: 7410,
      passes: 1,
      wobble: 1.2,
    });

    transformations.forEach(({ x, y, progress, color }, index) => {
      drawMetamorphGlyph(ctx, x, y, 54, progress, {
        color,
        alpha: 0.36 + (index === 3 ? 0.1 : 0),
        width: 1.35,
        seed: 7420 + index * 17,
      });
    });

    write(ctx, "breath returns", 300, 6615, 27, { center: true, seed: 7540, alpha: 0.5 });
    write(ctx, "grip returns", 800, 6680, 27, { center: true, seed: 7541, alpha: 0.5 });
    write(ctx, "judgment can wait", 1280, 6750, 27, { center: true, seed: 7542, alpha: 0.5 });
  });

  addMark(6880, 7340, (ctx) => {
    write(ctx, "i set today beside the last time", 150, 7000, 44, { seed: 7500, alpha: 0.72 });
    write(ctx, "not to crown a winner", 310, 7130, 33, { seed: 7501, alpha: 0.52 });
    write(ctx, "but to make change visible", 790, 7260, 38, { seed: 7502, alpha: 0.63 });
  });

  addMark(8350, 9100, (ctx) => {
    for (let column = 0; column < 7; column += 1) {
      const x = 170 + column * 208;
      const plateCount = 1 + (column % 4);
      drawBarRail(ctx, 8520 + column * 72, x - 55, x + 110, plateCount, 7600 + column, column % 3 === 0 ? PLUM : GRAPHITE, 0.3);
      for (let mark = 0; mark < 4; mark += 1) {
        roughLine(ctx, x - 36 + mark * 22, 8890, x - 32 + mark * 22, 8970, { color: column % 2 ? STEEL : VERDIGRIS, alpha: 0.25, width: 1, seed: 7650 + column * 7 + mark, passes: 1 });
      }
    }
    drawFloorScuff(ctx, 90, 9090, 1420, 7680, GRAPHITE, 0.12);
  });

  addMark(9210, 9740, (ctx) => {
    write(ctx, "some days the bar moves cleanly", 180, 9300, 42, { seed: 7700, alpha: 0.7 });
    roughPath(ctx, [[260, 9450], [530, 9390], [810, 9410], [1110, 9320], [1390, 9350]], { color: STEEL, alpha: 0.38, width: 2.1, seed: 7710, passes: 2, wobble: 1.1 });
    write(ctx, "some days it does not move", 800, 9610, 40, { center: true, seed: 7720, alpha: 0.65 });
    roughLine(ctx, 220, 9700, 1390, 9700, { color: PLUM, alpha: 0.38, width: 3, seed: 7730, passes: 3 });
    write(ctx, "both belong here", 800, 9840, 34, { center: true, seed: 7740, alpha: 0.56 });
  });

  addMark(9980, 11080, (ctx) => {
    write(ctx, "more is not always next", 800, 10070, 47, { center: true, seed: 7800, alpha: 0.74 });
    const branches = [
      { x: 190, label: "repeat", color: STEEL },
      { x: 590, label: "reduce", color: PLUM },
      { x: 1010, label: "rest", color: VERDIGRIS },
      { x: 1410, label: "home", color: GRAPHITE },
    ];
    plateRing(ctx, 800, 10230, 44, GRAPHITE, 7810, 0.34);
    branches.forEach((branch, index) => {
      roughPath(ctx, [[800, 10270], [800 + (branch.x - 800) * 0.36, 10420], [branch.x, 10620]], { color: branch.color, alpha: 0.36, width: 1.4, seed: 7820 + index, passes: 2, wobble: 1.1 });
      plateRing(ctx, branch.x, 10620, 34, branch.color, 7840 + index, 0.34);
      write(ctx, branch.label, branch.x, 10745, 29, { center: true, seed: 7860 + index, alpha: 0.58 });
      roughPath(ctx, [[branch.x, 10660], [branch.x + (800 - branch.x) * 0.44, 10910], [800, 11040]], { color: branch.color, alpha: 0.22, width: 1, seed: 7880 + index, passes: 1 });
    });
  });

  addMark(11150, 11860, (ctx) => {
    write(ctx, "i remember what happened", 800, 11270, 44, { center: true, seed: 7900, alpha: 0.72 });
    write(ctx, "you decide what it means", 800, 11410, 44, { center: true, seed: 7901, alpha: 0.72 });
    drawRepMarks(ctx, 490, 11620, 9, 7910, GRAPHITE);
    write(ctx, "when you return", 800, 11820, 38, { center: true, seed: 7920, alpha: 0.58 });
  });

  addMark(11880, 12560, (ctx) => {
    write(ctx, "i return it to you", 800, 11970, 50, { center: true, seed: 8000, alpha: 0.76 });
    drawBarRail(ctx, 12200, 450, 1150, 2, 8010, GRAPHITE, 0.5);
    drawMetamorphGlyph(ctx, 800, 12200, 120, 0, { color: PLUM, alpha: 0.3, width: 2.2, seed: 8020, passes: 3, wobble: 1.1 });
    drawFloorScuff(ctx, 360, 12430, 880, 8030, VERDIGRIS, 0.15);
    write(ctx, "the record ends where the next set begins", 800, 12530, 23, { center: true, seed: 8040, alpha: 0.36 });
  });

  addSideNotches(0, FIELD_TOTAL_H, 8200);

  const imageSources = {
    arrival: "/field/form-arrival-mineral-v3.webp",
    hands: "/field/form-load-mineral-v3.webp",
    rest: "/field/form-rest-mineral-v3.webp",
    history: "/field/form-history-mineral-v3.webp",
  };

  Promise.all(Object.entries(imageSources).map(async ([key, source]) => [key, await loadImage(source)]))
    .then((entries) => {
      const images = Object.fromEntries(entries);
      addMark(430, 1510, (ctx) => drawImageContained(ctx, images.arrival, 70, 440, 1460, 1040, 0.93));
      addMark(2620, 3490, (ctx) => drawImageContained(ctx, images.hands, 390, 2650, 1160, 790, 0.9));
      addMark(4930, 5920, (ctx) => drawImageContained(ctx, images.rest, 95, 4950, 1410, 930, 0.9));
      addMark(7380, 8340, (ctx) => drawImageContained(ctx, images.history, 0, 7420, 1600, 850, 0.92));
    })
    .catch((error) => console.error("Field artwork failed to load", error))
    .finally(() => {
      generationDone = true;
    });

  function handleResize() {
    cssScale = window.innerWidth / LW;
  }

  function handleMotionChange(event) {
    reducedMotion = event.matches;
    if (reducedMotion) tiles.forEach((tile) => { tile.active = true; });
  }

  function drawFrame() {
    if (destroyed) return;
    const scrollTop = window.scrollY / cssScale;
    const viewportHeight = window.innerHeight / cssScale;
    tiles.forEach((tile) => {
      if (!tile.active && (reducedMotion || tile.y0 < scrollTop + viewportHeight * 1.8)) tile.active = true;
    });

    const budget = reducedMotion ? Number.POSITIVE_INFINITY : 7;
    const started = performance.now();
    for (const tile of tiles) {
      if (!tile.active || tile.done) continue;
      while (tile.queueIndex < tile.queue.length) {
        tile.context.save();
        tile.context.setTransform(pixelScale, 0, 0, pixelScale, 0, -tile.y0 * pixelScale);
        try {
          tile.queue[tile.queueIndex](tile.context);
        } catch (error) {
          console.error("Field mark failed", tile.index, tile.queueIndex, error);
        }
        tile.context.restore();
        tile.queueIndex += 1;
        if (performance.now() - started > budget) break;
      }
      if (generationDone && tile.queueIndex >= tile.queue.length) tile.done = true;
      if (performance.now() - started > budget) break;
    }

    frame = requestAnimationFrame(drawFrame);
  }

  window.addEventListener("resize", handleResize, { passive: true });
  reducedQuery.addEventListener("change", handleMotionChange);
  frame = requestAnimationFrame(drawFrame);

  return () => {
    destroyed = true;
    cancelAnimationFrame(frame);
    window.removeEventListener("resize", handleResize);
    reducedQuery.removeEventListener("change", handleMotionChange);
    wall.replaceChildren();
  };
}
