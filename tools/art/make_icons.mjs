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
  battle_cry: ["warrior", (i, c) => { tri(i, [14, 24], [14, 40], [30, 32], W); for (const r of [12, 20, 28]) ring(i, 22, 32, r, 3, c, Math.PI * 1.75, Math.PI * 2); for (const r of [12, 20, 28]) ring(i, 22, 32, r, 3, c, 0, Math.PI * 0.25); }],
  whirlwind: ["warrior", (i, c) => { ring(i, 32, 32, 20, 5, W, 0, Math.PI * 1.4); ring(i, 32, 32, 11, 4, c, Math.PI, Math.PI * 2); tri(i, [52, 30], [44, 22], [42, 34], W); }],
  taunt: ["warrior", (i, c) => { line(i, 32, 12, 32, 38, 7, W); disk(i, 32, 48, 4, W); ring(i, 32, 32, 24, 3, c); }],
  shield_wall: ["warrior", (i, c) => { for (const x of [14, 28, 42]) { tri(i, [x - 6, 18], [x + 6, 18], [x, 46], x === 28 ? W : c); } line(i, 8, 50, 56, 50, 3, c); }],
  mass_taunt: ["warrior", (i, c) => { for (const x of [18, 32, 46]) { line(i, x, 14, x, 36, 6, x === 32 ? W : c); disk(i, x, 44, 3, x === 32 ? W : c); } ring(i, 32, 32, 26, 3, c); }],
  retaliation: ["warrior", (i, c) => { tri(i, [16, 14], [48, 14], [32, 52], c); arrow(i, 22, 32, 44, 32, 5, W, 10); }],
  frenzy: ["warrior", (i, c) => { tri(i, [32, 8], [16, 36], [48, 36], [255, 122, 42, 255]); tri(i, [32, 22], [22, 44], [42, 44], [255, 210, 80, 255]); line(i, 14, 52, 50, 52, 4, c); }],
  execute: ["warrior", (i, c) => { line(i, 16, 12, 48, 52, 8, W); line(i, 48, 12, 16, 52, 6, c); disk(i, 32, 32, 6, [200, 40, 50, 255]); }],
  renew: ["cleric", (i, c) => { ring(i, 32, 32, 18, 4, c, 0, Math.PI * 1.6); tri(i, [50, 30], [44, 20], [56, 22], c); line(i, 32, 22, 32, 42, 5, W); line(i, 22, 32, 42, 32, 5, W); }],
  holy_nova: ["cleric", (i, c) => { ring(i, 32, 32, 22, 4, c); ring(i, 32, 32, 14, 3, W); disk(i, 32, 32, 6, W); }],
  purify: ["cleric", (i, c) => { for (const [x, y] of [[20, 20], [44, 22], [24, 44], [42, 42]]) burst(i, x, y, 7, 4, 2, c); disk(i, 32, 32, 8, W); }],
  resurrection: ["cleric", (i, c) => { arrow(i, 32, 52, 32, 14, 6, W, 12); line(i, 16, 52, 48, 52, 4, c); burst(i, 32, 18, 14, 8, 2, c); }],
  healing_circle: ["cleric", (i, c) => { ring(i, 32, 34, 22, 4, c); ring(i, 32, 34, 12, 3, W); line(i, 32, 24, 32, 44, 5, W); line(i, 22, 34, 42, 34, 5, W); }],
  divine_hymn: ["cleric", (i, c) => { for (const [x, h] of [[16, 14], [26, 28], [36, 34], [46, 22]]) { line(i, x, 50, x, 50 - h, 5, W); disk(i, x, 50 - h, 5, c); } }],
  crusader_strike: ["cleric", (i, c) => { line(i, 32, 12, 32, 52, 6, W); line(i, 18, 24, 46, 24, 6, c); ring(i, 32, 32, 25, 2, c); }],
  consecration: ["cleric", (i, c) => { ring(i, 32, 36, 24, 3, c); ring(i, 32, 36, 14, 3, W); line(i, 32, 12, 32, 38, 5, W); line(i, 24, 20, 40, 20, 5, W); }],
  frost_nova: ["mage", (i, c) => { for (let a = 0; a < 6; a++) { const x = Math.cos(a * Math.PI / 3), y = Math.sin(a * Math.PI / 3); line(i, 32, 32, 32 + x * 22, 32 + y * 22, 3, [159, 227, 255, 255]); } disk(i, 32, 32, 6, W); ring(i, 32, 32, 24, 2, c); }],
  mana_barrier: ["mage", (i, c) => { ring(i, 32, 32, 20, 6, c); ring(i, 32, 32, 13, 2, W); disk(i, 32, 32, 4, W); }],
  fireball: ["mage", (i, c) => { for (const [x, y, w] of [[14, 50, 3], [18, 46, 5], [22, 42, 6]]) disk(i, x, y, w / 2, [255, 122, 42, 255]); disk(i, 38, 26, 13, [255, 122, 42, 255]); disk(i, 38, 26, 7, [255, 216, 74, 255]); }],
  frostbolt: ["mage", (i, c) => { line(i, 12, 50, 34, 28, 4, c); tri(i, [50, 14], [32, 26], [38, 32], [159, 227, 255, 255]); disk(i, 36, 28, 5, W); }],
  flame_pillar: ["mage", (i, c) => { for (const [x, h] of [[22, 26], [32, 38], [42, 28]]) { tri(i, [x - 7, 52], [x + 7, 52], [x, 52 - h], [255, 122, 42, 255]); } tri(i, [28, 52], [36, 52], [32, 30], [255, 210, 80, 255]); }],
  meteor: ["mage", (i, c) => { disk(i, 40, 34, 12, [255, 122, 42, 255]); disk(i, 40, 34, 6, [255, 210, 80, 255]); for (const [x, y] of [[12, 12], [20, 20], [26, 26]]) line(i, x, y, x + 8, y + 8, 4, c); }],
  blizzard: ["mage", (i, c) => { for (let a = 0; a < 3; a++) { const t = a * Math.PI / 3; line(i, 32 - Math.cos(t) * 22, 32 - Math.sin(t) * 22, 32 + Math.cos(t) * 22, 32 + Math.sin(t) * 22, 4, [159, 227, 255, 255]); } disk(i, 32, 32, 5, W); }],
  ice_block: ["mage", (i, c) => { tri(i, [16, 50], [48, 50], [48, 18], [159, 227, 255, 255]); tri(i, [16, 50], [16, 22], [48, 18], [210, 240, 255, 255]); line(i, 16, 50, 48, 50, 4, c); }],
  arcane_missiles: ["mage", (i, c) => { for (const [x, y] of [[20, 44], [30, 32], [40, 20]]) { disk(i, x, y, 5, c); line(i, x - 8, y + 8, x, y, 3, W); } }],
  arcane_lance: ["mage", (i, c) => { line(i, 10, 52, 54, 12, 5, c); line(i, 10, 52, 54, 12, 2, W); disk(i, 54, 12, 5, W); ring(i, 20, 42, 8, 2, c); }],
  net: ["archer", (i, c) => { for (let k = 14; k <= 50; k += 9) { line(i, k, 14, k, 50, 2, W); line(i, 14, k, 50, k, 2, W); } ring(i, 32, 32, 25, 3, c); }],
  arrow_rain: ["archer", (i, c) => { for (const x of [18, 32, 46]) arrow(i, x, 10, x - 6, 44, 3, W, 8); line(i, 10, 54, 54, 54, 3, c); }],
  explosive_trap: ["archer", (i, c) => { ring(i, 32, 40, 14, 4, W, Math.PI, Math.PI * 2); line(i, 18, 40, 46, 40, 4, W); burst(i, 32, 24, 14, 8, 3, [255, 122, 42, 255]); }],
  aimed_shot: ["archer", (i, c) => { ring(i, 32, 32, 20, 3, c); line(i, 32, 8, 32, 22, 3, W); line(i, 32, 42, 32, 56, 3, W); line(i, 8, 32, 22, 32, 3, W); line(i, 42, 32, 56, 32, 3, W); disk(i, 32, 32, 4, [255, 74, 90, 255]); }],
  burst: ["archer", (i, c) => { for (const y of [20, 32, 44]) arrow(i, 12, y, 52, y, 4, y === 32 ? W : c, 8); }],
  multishot: ["archer", (i, c) => { for (const [x, y] of [[50, 10], [52, 22], [52, 34], [50, 46], [46, 54]]) arrow(i, 12, 32, x, y, 3, W, 7); disk(i, 12, 32, 4, c); }],
  companion: ["archer", (i, c) => { disk(i, 30, 36, 12, c); tri(i, [20, 28], [24, 12], [30, 26], c); tri(i, [34, 26], [40, 12], [42, 28], c); disk(i, 26, 34, 2, [26, 27, 34, 255]); disk(i, 36, 34, 2, [26, 27, 34, 255]); tri(i, [28, 42], [32, 48], [36, 42], W); }],
  mark: ["archer", (i, c) => { ring(i, 32, 32, 18, 4, [255, 74, 90, 255]); ring(i, 32, 32, 8, 3, W); for (const [a, b, d, e] of [[32, 6, 32, 16], [32, 48, 32, 58], [6, 32, 16, 32], [48, 32, 58, 32]]) line(i, a, b, d, e, 3, c); }],
  stealth: ["assassin", (i, c) => { disk(i, 32, 22, 9, [60, 62, 74, 255]); tri(i, [18, 52], [46, 52], [32, 28], [60, 62, 74, 255]); ring(i, 32, 32, 24, 2, c, Math.PI * 0.1, Math.PI * 0.9); disk(i, 28, 22, 2, W); disk(i, 36, 22, 2, W); }],
  blade_fan: ["assassin", (i, c) => { for (let a = 0; a < 5; a++) { const t = Math.PI * (1.1 + a * 0.2); line(i, 32, 46, 32 + Math.cos(t) * 26, 46 + Math.sin(t) * 26, 4, a === 2 ? W : c); } }],
  poison: ["assassin", (i, c) => { tri(i, [44, 12], [22, 40], [28, 44], W); disk(i, 22, 50, 6, [111, 208, 74, 255]); tri(i, [22, 38], [17, 49], [27, 49], [111, 208, 74, 255]); }],
  throw_knife: ["assassin", (i, c) => { line(i, 14, 50, 40, 24, 4, W); tri(i, [52, 12], [38, 22], [44, 28], c); line(i, 12, 52, 20, 44, 6, [90, 60, 40, 255]); for (const [x, y] of [[10, 34], [14, 40], [8, 44]]) line(i, x, y, x + 8, y, 2, c); }],
  rend: ["assassin", (i, c) => { for (const x of [18, 30, 42]) { line(i, x, 12, x + 14, 52, 5, x === 30 ? W : c); } disk(i, 24, 52, 3, [200, 40, 50, 255]); disk(i, 38, 56, 2, [200, 40, 50, 255]); }],
  flurry: ["assassin", (i, c) => { for (let a = 0; a < 4; a++) { const y = 14 + a * 11; line(i, 12 + a * 3, y + 10, 50 + a * 2, y - 4, 4, a % 2 ? W : c); } }],
  vanish: ["assassin", (i, c) => { disk(i, 32, 22, 9, [60, 62, 74, 255]); tri(i, [18, 52], [46, 52], [32, 28], [60, 62, 74, 255]); for (const x of [14, 22]) line(i, x, 14, x + 6, 50, 2, c); for (const x of [46, 54]) line(i, x, 14, x - 4, 50, 2, c); }],
  shadow_strike: ["assassin", (i, c) => { line(i, 12, 52, 36, 28, 5, [60, 62, 74, 255]); arrow(i, 36, 28, 54, 10, 4, W, 9); disk(i, 14, 50, 5, c); }],
  toxic_cloud: ["assassin", (i, c) => { for (const [x, y, r] of [[22, 38, 11], [34, 30, 13], [44, 40, 10], [32, 44, 9]]) disk(i, x, y, r, [111, 208, 74, 255]); for (const [x, y] of [[26, 34], [38, 30], [34, 44]]) disk(i, x, y, 3, [60, 120, 40, 255]); }],
  contagion: ["assassin", (i, c) => { disk(i, 20, 32, 8, [111, 208, 74, 255]); disk(i, 44, 20, 6, [111, 208, 74, 255]); disk(i, 44, 44, 6, [111, 208, 74, 255]); line(i, 26, 30, 40, 22, 3, c); line(i, 26, 34, 40, 42, 3, c); }],
  passive_warrior: ["warrior", (i, c) => { tri(i, [16, 14], [48, 14], [32, 52], c); tri(i, [22, 19], [42, 19], [32, 42], [26, 27, 34, 255]); line(i, 32, 22, 32, 38, 3, W); }],
  passive_cleric: ["cleric", (i, c) => { ring(i, 32, 32, 18, 4, c); line(i, 32, 18, 32, 46, 4, W); line(i, 22, 28, 42, 28, 4, W); }],
  passive_mage: ["mage", (i, c) => { tri(i, [32, 10], [20, 32], [44, 32], c); tri(i, [32, 54], [20, 32], [44, 32], c); disk(i, 32, 32, 5, W); }],
  passive_archer: ["archer", (i, c) => { ring(i, 32, 32, 16, 4, c); disk(i, 32, 32, 6, W); }],
  passive_assassin: ["assassin", (i, c) => { ring(i, 32, 32, 18, 4, c, Math.PI * 0.6, Math.PI * 2.0); disk(i, 38, 28, 4, W); }],
  dodge: ["common",(i, c) => { for (const x of [20, 34]) { line(i, x, 18, x + 12, 32, 5, x === 20 ? c : W); line(i, x + 12, 32, x, 46, 5, x === 20 ? c : W); } }],
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
  bleed: ["#c0283a", (i) => { tri(i, [32, 12], [22, 36], [42, 36], K); disk(i, 32, 40, 10, K); }],
  haste: ["#ffe05a", (i) => { tri(i, [18, 16], [18, 48], [38, 32], K); tri(i, [34, 16], [34, 48], [54, 32], K); }],
  vulnerable: ["#ff6b8a", (i) => { ring(i, 32, 32, 16, 4, K); line(i, 20, 20, 44, 44, 4, K); line(i, 44, 20, 20, 44, 4, K); }],
  attack_slow: ["#8fa8ff", (i) => { line(i, 18, 48, 42, 20, 6, K); tri(i, [38, 10], [54, 18], [44, 28], K); line(i, 14, 24, 28, 24, 4, K); }],
  weaken: ["#b08a6a", (i) => { tri(i, [32, 50], [14, 18], [50, 18], K); line(i, 32, 22, 32, 38, 4, [200, 200, 200, 255]); }],
  armor_break: ["#a8b0bc", (i) => { tri(i, [16, 16], [48, 16], [32, 52], K); line(i, 30, 14, 36, 28, 4, [168, 176, 188, 255]); line(i, 36, 28, 28, 38, 4, [168, 176, 188, 255]); line(i, 28, 38, 34, 50, 4, [168, 176, 188, 255]); }],
  ice_block: ["#bfeaff", (i) => { for (let a = 0; a < 3; a++) { const c = Math.cos(a * Math.PI / 3), s = Math.sin(a * Math.PI / 3); line(i, 32 - c * 20, 32 - s * 20, 32 + c * 20, 32 + s * 20, 5, K); } }],
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
// Menu icons (Plan 7): gold symbols with a dark outline on a transparent ground.
const GOLD = hex("#e3b45a"), OUTLINE = [23, 19, 15, 255];
const UI = {
  ui_gear(i, c, w) { // settings: a cog
    for (let k = 0; k < 8; k++) { const a = k / 8 * Math.PI * 2; line(i, 32 + Math.cos(a) * 14, 32 + Math.sin(a) * 14, 32 + Math.cos(a) * 25, 32 + Math.sin(a) * 25, 9 + w, c); }
    ring(i, 32, 32, 15, 10 + w, c);
  },
  ui_star(i, c, w) { // credits: a five-pointed star
    const pts = [];
    for (let k = 0; k < 10; k++) { const a = -Math.PI / 2 + k * Math.PI / 5, r = k % 2 ? 11 : 26; pts.push([32 + Math.cos(a) * r, 33 + Math.sin(a) * r]); }
    for (let k = 0; k < 10; k += 2) tri(i, pts[k].map(Math.round), pts[(k + 1) % 10].map(Math.round), pts[(k + 9) % 10].map(Math.round), c);
    disk(i, 32, 33, 11 + w / 2, c);
    if (w) for (let k = 0; k < 10; k++) line(i, ...pts[k], ...pts[(k + 1) % 10], w, c);
  },
  ui_exit(i, c, w) { // quit: a door and an arrow leaving it
    line(i, 14, 12, 14, 52, 6 + w, c); line(i, 14, 12, 34, 12, 6 + w, c); line(i, 14, 52, 34, 52, 6 + w, c);
    line(i, 34, 12, 34, 20, 6 + w, c); line(i, 34, 44, 34, 52, 6 + w, c);
    arrow(i, 26, 32, 54, 32, 6 + w, c, 12 + w);
  },
};
fs.mkdirSync(`${outDir}/ui`, { recursive: true });
for (const [name, draw] of Object.entries(UI)) {
  const img = canvas();
  draw(img, OUTLINE, 4);
  draw(img, GOLD, 0);
  png.write(`${outDir}/ui/${name}.png`, img);
}
// The Play button (Plan 7): a square slab in an ember gradient (blood red to orange), a
// gold rim with a dark inner line and a lighter top half, for a StyleBoxTexture whose
// rims never stretch. Normal, hover (brighter) and pressed.
function pill(file, from, to, light) {
  const W = 256, H = 80;
  const img = png.create(W, H);
  const a = hex(from), b = hex(to), rim = hex("#e3b45a"), dark = [40, 8, 4];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const t = x / (W - 1);
    let c = [0, 1, 2].map((i) => a[i] + (b[i] - a[i]) * t);
    const top = 1 - y / H; // light from above
    c = c.map((v) => Math.min(255, v * (0.78 + 0.42 * top) + (y < H * 0.45 ? light : 0)));
    const d = Math.min(x, y, W - 1 - x, H - 1 - y);
    if (d < 2) c = [rim[0], rim[1], rim[2]];
    else if (d < 3) c = dark;
    else if (d < 4) c = c.map((v) => Math.min(255, v + 40)); // a bright bevel inside the rim
    png.set(img, x, y, [...c.map(Math.round), 255]);
  }
  png.write(file, img);
}
pill(`${outDir}/ui/play_normal.png`, "#7a1414", "#d4471c", 6);
pill(`${outDir}/ui/play_hover.png`, "#a01c1c", "#f0662a", 18);
pill(`${outDir}/ui/play_pressed.png`, "#5c0f0f", "#a8361a", 0);
// The play triangle drawn on the button, white with a dark outline.
{
  const img = canvas();
  tri(img, [16, 8], [16, 56], [56, 32], OUTLINE);
  tri(img, [20, 15], [20, 49], [49, 32], [255, 255, 255, 255]);
  png.write(`${outDir}/ui/ui_play.png`, img);
}
console.log(`wrote ${Object.keys(ICONS).length} icons and ${Object.keys(STATUS).length} status icons`);
