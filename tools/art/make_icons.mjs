// Ability icons: 64×64 PNGs with a dark rounded tile, a border in the class color
// and a simple symbol. Placeholders until drawn icons exist.
//   node tools/art/make_icons.mjs <out dir>
// One icon per "icon" key used in data/abilities (plus "dodge"), and status icons in <out>/status.
import * as fs from "node:fs";
import * as png from "./png.mjs";

const S = 64;
const CLASS = {
  warrior: "#c9d0d8", cleric: "#ffe38a", mage: "#b98cff", archer: "#a6dc6e", assassin: "#ff5f6d", common: "#8fd3ff",
};
const hex = (h) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16), 255];

function canvas() {
  const img = png.create(S, S);
  return img;
}

function put(img, x, y, c) {
  if (x < 0 || y < 0 || x >= S || y >= S) return;
  png.set(img, Math.floor(x), Math.floor(y), c);
}

function tile(img, color) {
  const bg = [26, 27, 34, 255], bg2 = [40, 42, 52, 255], border = hex(color);
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    const r = 8, dx = Math.max(r - x, x - (S - 1 - r), 0), dy = Math.max(r - y, y - (S - 1 - r), 0);
    const d = Math.sqrt(dx * dx + dy * dy);
    if (d > r) continue;
    const edge = d > r - 3 || x < 3 || y < 3 || x > S - 4 || y > S - 4;
    const t = y / S;
    put(img, x, y, edge ? border : [bg[0] + (bg2[0] - bg[0]) * t, bg[1] + (bg2[1] - bg[1]) * t, bg[2] + (bg2[2] - bg[2]) * t, 255].map(Math.round));
  }
}

function disk(img, cx, cy, r, c) {
  for (let y = cy - r; y <= cy + r; y++) for (let x = cx - r; x <= cx + r; x++)
    if ((x - cx) ** 2 + (y - cy) ** 2 <= r * r) put(img, x, y, c);
}

function ring(img, cx, cy, r, w, c, from = 0, to = Math.PI * 2) {
  for (let y = cy - r - 1; y <= cy + r + 1; y++) for (let x = cx - r - 1; x <= cx + r + 1; x++) {
    const d = Math.hypot(x - cx, y - cy);
    let a = Math.atan2(y - cy, x - cx);
    if (a < 0) a += Math.PI * 2;
    if (Math.abs(d - r) <= w / 2 && a >= from && a <= to) put(img, x, y, c);
  }
}

function line(img, x0, y0, x1, y1, w, c) {
  const n = Math.ceil(Math.hypot(x1 - x0, y1 - y0) * 2);
  for (let i = 0; i <= n; i++) disk(img, Math.round(x0 + (x1 - x0) * i / n), Math.round(y0 + (y1 - y0) * i / n), w / 2, c);
}

function tri(img, a, b, c, col) {
  const minX = Math.min(a[0], b[0], c[0]), maxX = Math.max(a[0], b[0], c[0]);
  const minY = Math.min(a[1], b[1], c[1]), maxY = Math.max(a[1], b[1], c[1]);
  const area = (p, q, r) => (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0]);
  for (let y = minY; y <= maxY; y++) for (let x = minX; x <= maxX; x++) {
    const p = [x + 0.5, y + 0.5];
    const w0 = area(b, c, p), w1 = area(c, a, p), w2 = area(a, b, p);
    if ((w0 >= 0 && w1 >= 0 && w2 >= 0) || (w0 <= 0 && w1 <= 0 && w2 <= 0)) put(img, x, y, col);
  }
}

function arrow(img, x0, y0, x1, y1, w, c, head = 9) {
  line(img, x0, y0, x1, y1, w, c);
  const a = Math.atan2(y1 - y0, x1 - x0);
  const l = [x1 - head * Math.cos(a - 0.5), y1 - head * Math.sin(a - 0.5)];
  const r = [x1 - head * Math.cos(a + 0.5), y1 - head * Math.sin(a + 0.5)];
  tri(img, [x1, y1], l.map(Math.round), r.map(Math.round), c);
}

function burst(img, cx, cy, r, n, w, c) {
  for (let i = 0; i < n; i++) {
    const a = i / n * Math.PI * 2;
    line(img, cx + Math.cos(a) * r * 0.35, cy + Math.sin(a) * r * 0.35, cx + Math.cos(a) * r, cy + Math.sin(a) * r, w, c);
  }
}

const W = [238, 236, 230, 255];
const ICONS = {
  slash: ["warrior", (i, c) => { ring(i, 18, 46, 30, 5, W, Math.PI * 1.5, Math.PI * 2); line(i, 20, 44, 46, 18, 3, c); }],
  brutal: ["warrior", (i, c) => { line(i, 16, 48, 44, 20, 7, W); burst(i, 46, 18, 12, 8, 3, c); }],
  charge: ["warrior", (i, c) => { arrow(i, 14, 32, 50, 32, 6, W, 12); for (const y of [22, 42]) line(i, 10, y, 26, y, 3, c); }],
  smite: ["cleric", (i, c) => { disk(i, 32, 32, 9, W); burst(i, 32, 32, 22, 12, 3, c); }],
  heal: ["cleric", (i, c) => { line(i, 32, 14, 32, 50, 10, c); line(i, 14, 32, 50, 32, 10, c); line(i, 32, 18, 32, 46, 4, W); line(i, 18, 32, 46, 32, 4, W); }],
  shield: ["cleric", (i, c) => { tri(i, [16, 16], [48, 16], [32, 52], c); tri(i, [21, 20], [43, 20], [32, 44], [26, 27, 34, 255]); disk(i, 32, 28, 4, W); }],
  missile: ["mage", (i, c) => { line(i, 12, 50, 36, 26, 4, c); disk(i, 42, 22, 8, W); disk(i, 42, 22, 4, c); }],
  blast: ["mage", (i, c) => { burst(i, 32, 32, 24, 10, 4, c); disk(i, 32, 32, 8, W); }],
  blink: ["mage", (i, c) => { tri(i, [14, 32], [24, 20], [24, 44], c); tri(i, [50, 32], [40, 20], [40, 44], W); for (let x = 27; x <= 37; x += 5) disk(i, x, 32, 2, c); }],
  shot: ["archer", (i, c) => { arrow(i, 14, 50, 48, 16, 3, W, 10); line(i, 14, 50, 20, 44, 6, c); }],
  piercing: ["archer", (i, c) => { ring(i, 26, 32, 7, 3, c); ring(i, 40, 32, 7, 3, c); arrow(i, 10, 32, 54, 32, 3, W, 9); }],
  roll: ["archer", (i, c) => { ring(i, 32, 32, 16, 5, W, Math.PI * 0.2, Math.PI * 1.7); tri(i, [44, 18], [54, 22], [46, 30], W); line(i, 20, 46, 44, 46, 3, c); }],
  stab: ["assassin", (i, c) => { tri(i, [44, 16], [24, 44], [30, 48], W); line(i, 18, 40, 30, 52, 5, c); }],
  eviscerate: ["assassin", (i, c) => { for (const o of [-10, 0, 10]) line(i, 18 + o, 50, 40 + o, 14, 4, o === 0 ? W : c); }],
  shadowstep: ["assassin", (i, c) => { disk(i, 40, 24, 7, [60, 62, 74, 255]); tri(i, [32, 32], [48, 32], [44, 52], [60, 62, 74, 255]); arrow(i, 10, 44, 30, 30, 4, c, 9); }],
  dodge: ["common", (i, c) => { for (const x of [20, 34]) { line(i, x, 18, x + 12, 32, 5, x === 20 ? c : W); line(i, x + 12, 32, x, 46, 5, x === 20 ? c : W); } }],
};

// Status icons shown above heads: a round badge in the status color with a symbol.
const K = [24, 22, 28, 255];
const STATUS = {
  stun: ["#ffd84a", (i) => { for (let a = 0; a < 3; a++) { const x = 32 + Math.cos(a * 2.1) * 13, y = 32 + Math.sin(a * 2.1) * 13; tri(i, [x, y - 7], [x - 6, y + 5], [x + 6, y + 5], K); } }],
  root: ["#8a6a3a", (i) => { line(i, 32, 14, 32, 40, 6, K); line(i, 32, 38, 18, 50, 4, K); line(i, 32, 38, 46, 50, 4, K); line(i, 32, 40, 32, 52, 4, K); }],
  freeze: ["#9fe3ff", (i) => { for (let a = 0; a < 3; a++) { const c = Math.cos(a * Math.PI / 3), s = Math.sin(a * Math.PI / 3); line(i, 32 - c * 18, 32 - s * 18, 32 + c * 18, 32 + s * 18, 4, K); } }],
  slow: ["#6f8cff", (i) => { ring(i, 32, 32, 15, 4, K); line(i, 32, 32, 32, 21, 4, K); line(i, 32, 32, 40, 36, 4, K); }],
  poison: ["#6fd04a", (i) => { disk(i, 32, 36, 11, K); tri(i, [32, 14], [23, 32], [41, 32], K); }],
  burn: ["#ff7a2a", (i) => { tri(i, [32, 12], [18, 46], [46, 46], K); disk(i, 32, 44, 9, K); }],
  mark: ["#ff4a5a", (i) => { ring(i, 32, 32, 15, 4, K); ring(i, 32, 32, 6, 4, K); line(i, 32, 10, 32, 18, 3, K); line(i, 32, 46, 32, 54, 3, K); line(i, 10, 32, 18, 32, 3, K); line(i, 46, 32, 54, 32, 3, K); }],
  taunted: ["#ff8a3a", (i) => { line(i, 32, 14, 32, 38, 7, K); disk(i, 32, 48, 4, K); }],
  damage_buff: ["#ffb03a", (i) => { tri(i, [32, 12], [16, 34], [48, 34], K); line(i, 32, 30, 32, 52, 8, K); }],
  damage_reduction: ["#c9d0d8", (i) => { tri(i, [16, 16], [48, 16], [32, 52], K); }],
  evasion: ["#a6dc6e", (i) => { for (const x of [18, 32]) { line(i, x, 18, x + 12, 32, 5, K); line(i, x + 12, 32, x, 46, 5, K); } }],
  hot: ["#5fe08a", (i) => { line(i, 32, 16, 32, 48, 8, K); line(i, 16, 32, 48, 32, 8, K); }],
};

function badge(img, color) {
  const c = hex(color), rim = [Math.round(c[0] * 0.45), Math.round(c[1] * 0.45), Math.round(c[2] * 0.45), 255];
  disk(img, 32, 32, 30, rim);
  disk(img, 32, 32, 26, c);
}

const [outDir] = process.argv.slice(2);
if (!outDir) {
  console.error("usage: node make_icons.mjs <out dir>");
  process.exit(1);
}
for (const [name, [cls, draw]] of Object.entries(ICONS)) {
  const img = canvas();
  tile(img, CLASS[cls]);
  draw(img, hex(CLASS[cls]));
  png.write(`${outDir}/${name}.png`, img);
}
fs.mkdirSync(`${outDir}/status`, { recursive: true });
for (const [name, [color, draw]] of Object.entries(STATUS)) {
  const img = canvas();
  badge(img, color);
  draw(img);
  png.write(`${outDir}/status/${name}.png`, img);
}
console.log(`wrote ${Object.keys(ICONS).length} icons and ${Object.keys(STATUS).length} status icons`);
