// v2 cult enemies (Plan 6.4.1): the same designs as make_pieces.mjs (cultist, acolyte,
// inquisitor, Vaelthar, Nhazar), sculpted over the v2 body parts in their pivot frames with
// the detail of the user's reference sheets (docs/Adjuntos/Referencias enemigos): textured
// black cloth with folds, old-gold trims and suns, burning eyes, masks with expressions,
// chains with links. Same ids, parts and tags as the v1 table.
//
// v2 frames (voxels from each part's pivot): head x -8..7, y 0..16, z -7..8 (face +z);
// torso x -12..11, y -8..29 (waist 0, shoulders ~22), z -7..7, the ground at y -53;
// upper arm x -3..2, y -21..3; forearm y -19..2; hand y -8..0 (fingers down, palm +z).
import { Shape, GLOW, HIDDEN } from "./vox.mjs";
import { ellipsoid, capsule, cylinder, roundBox, carve, tone, shadeByFacing, shellAround, noise3 } from "./sculpt.mjs";
import { headV2, torsoV2, upperArmV2, forearmV2, handV2 } from "./human_v2.mjs";

// --- Palette ------------------------------------------------------------------------------
export const K = {
  ROBE: 60, ROBE_D: 61, ROBE_L: 62, ROBE_T: 63, GOLD: 64, GOLD_D: 65, GOLD_L: 66, PANEL: 67, ROPE: 68, ROPE_D: 69,
  VOID: 70, RED: 71, RED_D: 72, RED_L: 73, TENT: 74, TENT_D: 75, TENT_L: 76, SUCKER: 77, HAIR: 78, HAIR_D: 79, HAIR_L: 80,
  FACE: 81, FACE_D: 82, CURL: 83, CURL_D: 84, CURL_L: 85, STONE: 86, STONE_D: 87, STONE_L: 88, CLAW: 89, CLAW_D: 90,
  PENDANT: 91, PENDANT_D: 92, PLATE: 93, PLATE_D: 94, PLATE_L: 95, BLOOD: 96,
};
const { ROBE, ROBE_D, ROBE_L, ROBE_T, GOLD, GOLD_D, GOLD_L, PANEL, ROPE, ROPE_D, VOID, RED, RED_D, RED_L, TENT, TENT_D, TENT_L,
  SUCKER, HAIR, HAIR_D, HAIR_L, FACE, FACE_D, CURL, CURL_D, CURL_L, STONE, STONE_D, STONE_L, CLAW, CLAW_D, PENDANT, PENDANT_D,
  PLATE, PLATE_D, PLATE_L, BLOOD } = K;
export const CULT_PALETTE = {
  [ROBE]: "#1d1c21", [ROBE_D]: "#111014", [ROBE_L]: "#2e2c34", [ROBE_T]: "#18171c",
  [GOLD]: "#b8995a", [GOLD_D]: "#7d6634", [GOLD_L]: "#e2c47e", [PANEL]: "#141318",
  [ROPE]: "#6b5a3e", [ROPE_D]: "#47392a", [VOID]: "#050407",
  [RED]: "#701a1e", [RED_D]: "#450b10", [RED_L]: "#8f2a2c",
  [TENT]: "#5c1824", [TENT_D]: "#3a0d17", [TENT_L]: "#82303c", [SUCKER]: "#cfaaa2",
  [HAIR]: "#77717d", [HAIR_D]: "#4f4a55", [HAIR_L]: "#a39eab",
  [FACE]: "#c4b2a0", [FACE_D]: "#9c8a79",
  [CURL]: "#1b181a", [CURL_D]: "#0d0b0d", [CURL_L]: "#302a2d",
  [STONE]: "#a59d96", [STONE_D]: "#6e6762", [STONE_L]: "#cac3bc",
  [CLAW]: "#19171b", [CLAW_D]: "#0b0a0c", [PENDANT]: "#7f8c74", [PENDANT_D]: "#56604d",
  [PLATE]: "#2a2930", [PLATE_D]: "#18171c", [PLATE_L]: "#3c3a44", [BLOOD]: "#9e1b22",
  [GLOW]: "#ffb84a", [HIDDEN]: "#000000",
};

// Textures and form: every material mixes its tones and darkens facing down, lightens on top.
const MATS = {
  [ROBE]: { tones: [ROBE, ROBE_T, ROBE], light: ROBE_L, shade: ROBE_D },
  [GOLD]: { tones: [GOLD, GOLD_D, GOLD_L], light: GOLD_L, shade: GOLD_D },
  [RED]: { tones: [RED, RED_D, RED], light: RED_L, shade: RED_D },
  [TENT]: { tones: [TENT, TENT_D, TENT_L], light: TENT_L, shade: TENT_D },
  [HAIR]: { tones: [HAIR, HAIR_D, HAIR_L], light: HAIR_L, shade: HAIR_D },
  [CURL]: { tones: [CURL, CURL_D, CURL_L], light: CURL_L, shade: CURL_D },
  [PLATE]: { tones: [PLATE, PLATE_D, PLATE_L], light: PLATE_L, shade: PLATE_D },
  [ROPE]: { tones: [ROPE, ROPE_D, ROPE], light: ROPE, shade: ROPE_D },
};
function paint(s, seed = 1) {
  const idxs = [], map = {};
  for (const [m, d] of Object.entries(MATS).map(([k, v]) => [Number(k), v])) {
    tone(s, m, d.tones, seed + m, m === GOLD ? [0.7, 0.18, 0.12] : [0.7, 0.2, 0.1]);
    for (const i of d.tones) { idxs.push(i); map[i] = { light: d.light, shade: d.shade }; }
  }
  return shadeByFacing(s, idxs, map);
}

const HEAD = headV2(), TORSO = torsoV2(), ARM = upperArmV2(), FORE = forearmV2(), HAND = handV2();
const r = Math.round;
const merge = (...shapes) => { const out = new Shape(); for (const s of shapes) for (const [x, y, z, i] of s.cells.values()) out.put(x, y, z, i); return out; };
const without = (s, ...parts) => carve(s, (t) => { for (const p of parts) for (const [x, y, z] of p.cells.values()) t.put(x, y, z, 0); });
const recolor = (s, pred, idx) => { for (const v of s.cells.values()) if (pred(v[0], v[1], v[2], v[3])) v[3] = idx; return s; };
// A shape moved by (dx, dy, dz) (to carve one part out of a piece drawn in another frame).
const moved = (s, dx, dy, dz) => { const o = new Shape(); for (const [x, y, z, i] of s.cells.values()) o.put(x + dx, y + dy, z + dz, i); return o; };
const TORSO_IN_HEAD = moved(TORSO, 0, -28, 0); // the torso seen from the head's frame
const CX = -0.5; // the body's middle in x

// A hollow ring (elliptic, thickness th) at height y: rx, rz to the outside, centre (cx, cz).
function ring(s, y, rx, rz, th, idx, cx = CX, cz = 0, pick = () => idx) {
  for (let x = Math.floor(cx - rx - 1); x <= Math.ceil(cx + rx + 1); x++) for (let z = Math.floor(cz - rz - 1); z <= Math.ceil(cz + rz + 1); z++) {
    const d = ((x - cx) / rx) ** 2 + ((z - cz) / rz) ** 2;
    if (d <= 1 && d >= ((rx - th) / rx) ** 2) s.put(x, y, z, pick(x, z));
  }
}
// The outermost z of shape s at (x, y) (its front), or null.
function front(s, x, y) { let b = null; for (const [cx, cy, cz] of s.cells.values()) if (cx === x && cy === y && (b === null || cz > b)) b = cz; return b; }
function back(s, x, y) { let b = null; for (const [cx, cy, cz] of s.cells.values()) if (cx === x && cy === y && (b === null || cz < b)) b = cz; return b; }

// A flat sun in old gold on the plane z (or -z for dir -1): a dark disk, a ring, `rays` rays.
function sun(s, cx, cy, z, R, rays, opts = {}) {
  const { wavy = false, eye = false, depth = 1, dir = 1, long = 2.4, short = 1.7 } = opts;
  for (let x = Math.floor(cx - R * 1.6); x <= Math.ceil(cx + R * 1.6); x++) for (let y = Math.floor(cy - R * 1.6); y <= Math.ceil(cy + R * 1.6); y++) {
    const d = Math.hypot(x - cx, y - cy);
    if (d <= R * 0.62) s.put(x, y, z, VOID);
    else if (d <= R) { for (let k = 0; k < depth; k++) s.put(x, y, z + dir * k, d > R - 1 ? GOLD_D : GOLD); }
  }
  if (eye) for (const [dx, dy] of [[0, 0], [-1, 0], [0, -1], [-1, -1]]) s.put(r(cx + dx + 0.5), r(cy + dy + 0.5), z + dir, GLOW);
  for (let k = 0; k < rays; k++) {
    const a = (k * 2 * Math.PI) / rays + Math.PI / 2, len = R * (k % 2 === 0 ? long : short);
    for (let t = R; t <= len; t += 0.3) {
      const wig = wavy ? Math.sin(t * 0.7 + k) * 1.4 : 0;
      const px = cx + Math.cos(a) * t - Math.sin(a) * wig, py = cy + Math.sin(a) * t + Math.cos(a) * wig;
      const w = t < R + (len - R) * 0.5 ? 1 : 0;
      for (let u = -w; u <= w; u++) s.put(r(px - Math.sin(a) * u * 0.6), r(py + Math.cos(a) * u * 0.6), z, t > len - 1.5 ? GOLD_L : GOLD);
    }
  }
}

// --- Hoods ---------------------------------------------------------------------------------
// A cult hood: thick around the head and rounded on top, the face a black void, widening into
// a mantle over the shoulders with deep folds. `peak` raises the crown into a point.
function hood(peak = 0) {
  const s = shellAround(HEAD, 3, ROBE, (x, y) => y >= -2);
  ellipsoid(s, [CX, 15 + peak * 0.3, -0.5], [9.5, 6 + peak, 9], ROBE); // the crown
  if (peak) capsule(s, [CX, 18, -1], [CX, 22 + peak, -3], 4, 1, ROBE);
  for (let y = -12; y <= -1; y++) { // the mantle, flaring over the shoulders
    const k = (-y) / 12;
    ring(s, y, 11 + k * 7, 9 + k * 3, 3, ROBE);
  }
  carve(s, (t) => { // open in front of the face, deep and dark
    for (let x = -6; x <= 5; x++) for (let y = 0; y <= 13; y++) for (let z = 5; z <= 14; z++) if (((x + 0.5) / 6.5) ** 2 + ((y - 6.5) / 8) ** 2 <= 1) t.put(x, y, z, 0);
  });
  for (let x = -6; x <= 5; x++) for (let y = 0; y <= 13; y++) if (((x + 0.5) / 6.5) ** 2 + ((y - 6.5) / 8) ** 2 <= 1) s.put(x, y, (front(HEAD, x, y) ?? 6) + 1, VOID);
  recolor(s, (x, y, z, i) => i === ROBE && Math.sin(Math.atan2(z, x + 0.5) * 7 + y * 0.15) > 0.7, ROBE_D); // folds
  return without(s, HEAD, TORSO_IN_HEAD);
}

function cultHood() {
  const s = hood();
  sun(s, CX, 6.5, 12, 4.6, 8, { wavy: true, depth: 2, long: 3.4, short: 2.8 }); // the black sun over the face
  return paint(s, 3);
}

function acolyteHood() {
  const s = hood(4);
  sun(s, CX, 6.5, 12, 5, 12, { eye: true, depth: 2, long: 3.2, short: 2.3 });
  halo(s, CX, 14, -13, 26, false); // the great spiked halo behind the head
  return paint(s, 5);
}

function inquisitorHood() {
  const s = hood(2);
  for (const x of [-4, 2]) for (const dx of [0, 1]) s.put(x + dx, 9, (front(HEAD, x + dx, 9) ?? 6) + 2, GLOW); // burning eyes
  // The sunburst crown round the hood, open below: a gold ring with rays, a tall spike on top.
  const cy = 9, z = 11, R = 15;
  for (let x = -20; x <= 19; x++) for (let y = -10; y <= 40; y++) {
    const d = Math.hypot(x - CX, y - cy);
    if (Math.abs(d - R) <= 1 && y > cy - 8) s.put(x, y, z, GOLD).put(x, y, z - 1, GOLD_D);
  }
  for (let k = 0; k < 12; k++) {
    const a = (k * Math.PI) / 6 + Math.PI / 2;
    if (Math.sin(a) < -0.45) continue; // none under the chin
    const len = k === 0 ? 19 : k % 2 === 0 ? 9 : 6;
    for (let t = R + 1; t <= R + len; t += 0.3) {
      const w = t < R + len * 0.45 ? 1 : 0;
      for (let u = -w; u <= w; u++) s.put(r(CX + Math.cos(a) * t - Math.sin(a) * u), r(cy + Math.sin(a) * t + Math.cos(a) * u), z, t > R + len - 1.5 ? GOLD_L : GOLD);
    }
  }
  return paint(s, 7);
}

// A spiked gold halo behind a head (in the xy plane at z): ring R, 16 spikes, the four
// points crossed like stars when `cross`, spokes to the mount.
function halo(s, cx, cy, z, R, cross) {
  for (let x = Math.floor(cx - R - 16); x <= Math.ceil(cx + R + 16); x++) for (let y = Math.floor(cy - R - 16); y <= Math.ceil(cy + R + 16); y++) {
    const d = Math.hypot(x - cx, y - cy);
    if (Math.abs(d - R) <= 1.2) s.put(x, y, z, Math.abs(d - R) < 0.5 ? GOLD_L : GOLD).put(x, y, z - 1, GOLD_D);
  }
  for (let k = 0; k < 16; k++) {
    const a = (k * Math.PI) / 8, big = cross && k % 4 === 0;
    const len = big ? 16 : k % 2 === 0 ? 10 : 6;
    for (let t = R + 1; t <= R + len; t += 0.3) {
      const w = t < R + len * 0.4 ? 1 : 0;
      for (let u = -w; u <= w; u++) s.put(r(cx + Math.cos(a) * t - Math.sin(a) * u), r(cy + Math.sin(a) * t + Math.cos(a) * u), z, t > R + len - 2 ? GOLD_L : GOLD);
    }
    if (big) { const t = R + len - 5; for (let u = -4; u <= 4; u++) s.put(r(cx + Math.cos(a) * t - Math.sin(a) * u), r(cy + Math.sin(a) * t + Math.cos(a) * u), z, GOLD); }
  }
  for (let k = 0; k < 8; k++) {
    const a = (k * Math.PI) / 4 + Math.PI / 8;
    for (let t = 9; t <= R - 1; t += 0.4) s.put(r(cx + Math.cos(a) * t), r(cy + Math.sin(a) * t), z + 1, GOLD_D);
  }
}

// --- Robes -----------------------------------------------------------------------------------
// The skirt of a robe from the waist (y 2) to the hem at `bottom`, hollow (the legs move
// inside), flaring to (rx, rz) at the hem, folds in deep shade; `pick` colours a cell.
function skirt(s, bottom, rx1, rz1, pick = () => ROBE) {
  for (let y = bottom; y <= 2; y++) {
    const k = (2 - y) / (2 - bottom);
    const rx = 13 + (rx1 - 13) * k ** 0.8, rz = 9 + (rz1 - 9) * k ** 0.8;
    ring(s, y, rx, rz, 2.2, ROBE, CX, 0.3 * k, (x, z) => {
      const a = Math.atan2(z, x - CX);
      const fold = Math.sin(a * 11 + k * 1.5) > 0.6 && k > 0.12;
      return fold ? ROBE_D : pick(x, y, z, a, k);
    });
  }
}
const chest = (lo = -2, hi = 27) => shellAround(TORSO, 2, ROBE, (x, y) => y >= lo && y <= hi);
// A worn gold hem: the lowest rows gold, broken here and there.
function hem(s, bottom, rows = 3, ragged = false) {
  for (const v of [...s.cells.values()]) {
    if (v[1] > bottom + rows - 1) continue;
    const h = (v[0] * 7 + v[2] * 3 + v[1]) % 5;
    if (ragged && v[1] === bottom && h === 0) { s.cells.delete(`${v[0]},${v[1]},${v[2]}`); continue; }
    v[3] = h === 0 ? ROBE : v[1] === bottom ? GOLD_D : GOLD;
  }
}
// A band down the front (or back) of a robe from y0 to y1, `half` wide, gold-edged with a dark
// panel, ending in a point at the bottom; `marks` adds the cult's signs along it.
function panel(s, y0, y1, half, dir = 1, marks = true) {
  for (let y = y0; y <= y1; y++) {
    const narrow = Math.max(0, 4 - (y - y0));
    for (let x = r(CX - half + narrow); x <= r(CX + half - narrow); x++) {
      const z = dir > 0 ? front(s, x, y) : back(s, x, y);
      if (z === null) continue;
      const edge = x <= r(CX - half + narrow) + 1 || x >= r(CX + half - narrow) - 1 || y <= y0 + 1;
      s.put(x, y, z + dir, edge ? GOLD : PANEL);
    }
  }
  if (!marks) return;
  const at = (x, y, idx) => { const z = dir > 0 ? front(s, x, y) : back(s, x, y); if (z !== null) s.put(x, y, z + dir, idx); };
  const sy = r(y0 + (y1 - y0) * 0.72);
  for (let x = -6; x <= 5; x++) for (let y = sy - 6; y <= sy + 6; y++) { // a sun
    const d = Math.hypot(x - CX, y - sy);
    if (d <= 2) at(x, y, VOID); else if (d <= 3.3) at(x, y, GOLD);
    else if (d <= 5.6 && Math.abs(Math.sin(Math.atan2(y - sy, x - CX) * 4)) < 0.3) at(x, y, GOLD_D);
  }
  for (const yy of [r(y0 + (y1 - y0) * 0.45), r(y0 + (y1 - y0) * 0.3)]) { // a cross-mark and a diamond
    for (let k = -2; k <= 2; k++) { at(-1, yy + k, GOLD_D); at(0, yy + k, GOLD_D); }
    for (const x of [-3, -2, 1, 2]) at(x, yy + 1, GOLD_D);
  }
  for (const [x, y] of [[-1, y0 + 6], [0, y0 + 6], [-1, y0 + 7], [0, y0 + 5]]) at(x, y, GOLD);
}
// A rope (or leather) belt round the waist, its tie hanging at the back.
function belt(s, idx = ROPE, y0 = 0, h = 3) {
  for (let y = y0; y < y0 + h; y++) ring(s, y, 14.5, 10.5, 2, idx);
  if (idx === ROPE) for (let y = y0 - 14; y < y0; y++) for (const x of [-1, 0]) s.put(x + (y % 3 === 0 ? 1 : 0), y, -12, y < y0 - 12 ? ROPE_D : ROPE);
}
// A gold chain hanging in a U across the chest, a medallion with the sun at its bottom.
function chain(s, glowEye = true) {
  for (let i = 0; i <= 20; i++) {
    const t = i / 20, x = -10 + 19 * t, dy = Math.sin(t * Math.PI) * 10;
    const y = r(25 - dy), z = (front(TORSO, r(x), y) ?? 7) + 3;
    s.put(r(x), y, z, i % 2 ? GOLD_D : GOLD).put(r(x), y - 1, z, i % 2 ? GOLD : GOLD_D);
  }
  const my = 12, mz = (front(TORSO, 0, my) ?? 7) + 4;
  for (let x = -7; x <= 6; x++) for (let y = my - 7; y <= my + 7; y++) {
    const d = Math.hypot(x - CX, y - my);
    if (d <= 2.2) s.put(x, y, mz + 1, VOID);
    else if (d <= 4) s.put(x, y, mz, GOLD);
    else if (d <= 6.5 && Math.abs(Math.sin(Math.atan2(y - my, x - CX) * 4)) < 0.28) s.put(x, y, mz, GOLD_D);
  }
  if (glowEye) s.put(-1, my, mz + 2, GLOW).put(0, my, mz + 2, GLOW);
}
// Stepped mantles over the shoulders: each layer a shell round the shoulders, gold-edged.
function mantles(s, layers) {
  layers.forEach(([y0, y1, grow], i) => {
    const m = shellAround(TORSO, 2 + grow, ROBE, (x, y) => y >= y0 && y <= y1);
    for (const v of m.cells.values()) if (v[1] === y0 || v[1] === y0 + 1) v[3] = i === 0 ? GOLD : GOLD_D;
    for (const v of m.cells.values()) if (!s.cells.has(`${v[0]},${v[1]},${v[2]}`) || v[1] <= y0 + 1) s.put(...v);
  });
}

const BOTTOM = -50; // the hem, just above the ground (y -53)

function cultRobe() {
  const s = chest();
  skirt(s, BOTTOM, 18, 13);
  hem(s, BOTTOM);
  panel(s, BOTTOM + 3, 22, 4.5);
  belt(s);
  for (let y = 18; y <= 26; y++) for (const x of [-4, 3]) s.put(x, y, (front(TORSO, x, y) ?? 7) + 3, y === 18 ? PENDANT_D : PENDANT); // a horseshoe pendant
  for (let x = -3; x <= 2; x++) s.put(x, 17, (front(TORSO, x, 17) ?? 7) + 3, PENDANT_D);
  return paint(without(s, TORSO), 11);
}

function acolyteRobe() {
  const s = chest();
  skirt(s, BOTTOM, 23, 17);
  hem(s, BOTTOM, 4, true);
  mantles(s, [[18, 28, 1], [12, 22, 3]]);
  panel(s, BOTTOM + 8, 20, 5);
  panel(s, BOTTOM + 5, 24, 5, -1);
  belt(s);
  chain(s);
  return paint(without(s, TORSO), 13);
}

function vaeltharRobe() {
  const s = chest();
  // The outer robe opens at the front over a blood-red underrobe, the opening widening down.
  skirt(s, BOTTOM, 25, 18, (x, y, z, a, k) => {
    const gap = 3 + k * 9;
    if (z > 0 && Math.abs(x - CX) < gap) return y % 4 === 0 ? RED_D : RED;
    if (z > 0 && Math.abs(x - CX) < gap + 1.5) return GOLD;
    return ROBE;
  });
  // Ragged tongues of cloth below the hem, black over red.
  for (const v of [...s.cells.values()].filter((c) => c[1] === BOTTOM)) {
    const h = (v[0] * 7 + v[2] * 5) % 7;
    const red = v[3] === RED || v[3] === RED_D;
    for (let d = 1; d <= Math.min(h - 2, 2); d++) s.put(v[0], BOTTOM - d, v[2], red ? RED_D : ROBE_D); // never past y -52
  }
  mantles(s, [[19, 29, 1], [13, 23, 3], [7, 17, 5]]);
  for (let y = 27; y <= 31; y++) ring(s, y, 7, 6, 1.6, ROBE); // the high collar
  panel(s, BOTTOM + 10, 18, 4.5);
  panel(s, BOTTOM + 6, 24, 5.5, -1);
  belt(s, ROPE);
  chain(s);
  return paint(without(s, TORSO), 17);
}

// --- Sleeves and cuffs (arm and forearm frames) ---------------------------------------------
// A wide sleeve round the upper arm, a gold seam near the shoulder; `cut` opens it at the
// elbow into a mouth with a torn gold hem (Vaelthar, whose forearms are gone).
function sleeve(cut = false, seed = 21) {
  const s = new Shape();
  for (let y = -21; y <= 3; y++) {
    const k = (3 - y) / 24;
    ring(s, y, 5 + k * (cut ? 4 : 1.5), 4.6 + k * (cut ? 4 : 1.5), cut ? 2 : 6, ROBE, -0.5, -0.5);
  }
  ellipsoid(s, [-0.5, 2, -0.5], [6, 4, 5.6], ROBE); // over the shoulder
  for (const v of s.cells.values()) if (v[1] === -3) v[3] = GOLD_D;
  if (cut) {
    for (const v of [...s.cells.values()].filter((c) => c[1] <= -19)) {
      const h = (v[0] * 5 + v[2] * 3) % 4;
      if (v[1] === -21 && h === 0) s.cells.delete(`${v[0]},${v[1]},${v[2]}`);
      else v[3] = v[1] === -21 ? GOLD : h === 1 ? ROBE : GOLD_D;
    }
  }
  recolor(s, (x, y, z, i) => i === ROBE && Math.sin(Math.atan2(z + 0.5, x + 0.5) * 5 + y * 0.2) > 0.75, ROBE_D);
  return paint(without(s, ARM), seed);
}
// A bell cuff opening wide round the wrist with a worn gold hem; `drape` hangs a long fold
// of cloth behind it.
function cuff(drape = false, seed = 23) {
  const s = new Shape();
  for (let y = -22; y <= -6; y++) {
    const k = (-6 - y) / 16;
    ring(s, y, 4.6 + k * 4.5, 4.4 + k * 4.5, 1.8, ROBE, -0.5, -0.5 + k);
  }
  for (const v of s.cells.values()) {
    if (v[1] <= -21) v[3] = (v[0] * 5 + v[2] * 3) % 4 === 0 ? ROBE : v[1] === -22 ? GOLD_D : GOLD;
  }
  if (drape) for (let y = -36; y <= -12; y++) {
    const w = Math.max(1, 5 - Math.floor((-12 - y) / 6));
    for (let x = -0.5 - w; x <= -0.5 + w; x++) s.put(r(x), y, -7 - Math.floor((-12 - y) / 8), y <= -35 ? GOLD : ROBE);
  }
  return paint(without(s, FORE), seed);
}

// --- The inquisitor's armour --------------------------------------------------------------
// Heavy stepped pauldron: three layered plates over the shoulder, gold-edged, a dome and
// rivets (outer +1 for the left arm).
function pauldron(outer) {
  const s = new Shape();
  [[2, 6], [-3, 7.5], [-8, 8.2]].forEach(([y, R], i) => {
    for (let yy = y - 2; yy <= y + 3; yy++) for (let x = -12; x <= 12; x++) for (let z = -12; z <= 12; z++) {
      const d = Math.hypot(x + 0.5 - outer * 1.5, z + 0.5);
      if (d > R || d < R - 2.2) continue;
      if (outer * (x + 0.5) < -2.5) continue; // only over the outside and top of the shoulder
      s.put(x, yy, z, yy === y - 2 ? GOLD : PLATE);
    }
    void i;
  });
  ellipsoid(s, [-0.5 + outer * 1.5, 4, -0.5], [6.4, 4, 6], PLATE);
  for (const z of [-3, 2]) s.put(r(-0.5 + outer * 8), -4, z, GOLD_L);
  return paint(without(s, ARM), 31 + outer);
}
function vambrace() {
  const s = new Shape();
  for (let y = -17; y <= -4; y++) ring(s, y, 4.6, 4.4, 1.6, y === -17 || y === -10 ? GOLD : PLATE, -0.5, -0.5);
  for (let y = -15; y <= -6; y += 3) s.put(-1, y, 4, GOLD_D).put(0, y, 4, GOLD_D);
  return paint(without(s, FORE), 35);
}
function inquisitorBelt() {
  const s = new Shape();
  belt(s, PLATE, -1, 5);
  for (let x = -5; x <= 4; x++) for (let y = -2; y <= 6; y++) { // the square sun buckle
    const edge = x === -5 || x === 4 || y === -2 || y === 6;
    s.put(x, y, 12, edge ? GOLD : (Math.abs(x + 0.5) < 2 && Math.abs(y - 2) < 2 ? VOID : GOLD_D));
  }
  s.put(-1, 2, 13, GOLD_L).put(0, 2, 13, GOLD_L);
  // A banner from the belt to below the knees, the sun and a sword on it.
  for (let y = -40; y <= -3; y++) {
    const narrow = Math.max(0, 4 - (y + 40));
    for (let x = -5 + narrow; x <= 4 - narrow; x++) {
      const z = 13 + Math.floor((-3 - y) / 9);
      const edge = x <= -4 + narrow || x >= 3 - narrow || y <= -39;
      s.put(x, y, z, edge ? GOLD : PANEL);
    }
  }
  for (let y = -28; y <= -12; y++) s.put(-1, y, 17, GOLD_D).put(0, y, 17, GOLD_D); // the sword sign
  for (const x of [-3, -2, 1, 2]) s.put(x, -15, 16, GOLD_D);
  for (let x = -3; x <= 2; x++) for (let y = -10; y <= -6; y++) if (Math.hypot(x + 0.5, y + 8) <= 2.6) s.put(x, y, 15, GOLD);
  // A short cape over the back of the shoulders.
  const cape = shellAround(TORSO, 2, ROBE, (x, y, z) => z < -2 && y >= 6 && y <= 27);
  for (const v of cape.cells.values()) s.put(...v);
  return paint(without(s, TORSO), 37);
}
// The ceremonial sword (fist frame, grip along +Z through (-0.5, -4.5), point down at rest):
// a long dark blade edged in gold, a fuller with marks, a cross-guard with a sun stud, a
// wrapped grip and a ring pommel.
function inquisitorSword() {
  const s = new Shape(), CY = -4.5;
  cylinder(s, [CX, CY, -4], [CX, CY, 3], 1.5, ROPE_D);
  for (let z = -4; z <= 3; z += 2) cylinder(s, [CX, CY, z], [CX, CY, z], 1.8, ROPE);
  for (let a = 0; a < 24; a++) { const t = (a / 24) * Math.PI * 2; s.put(r(CX + Math.cos(t) * 2.6), r(CY + Math.sin(t) * 2.6), -7, GOLD); } // ring pommel
  roundBox(s, [-2, r(CY) - 9, 4], [1, r(CY) + 9, 6], 0.8, GOLD); // the guard
  sun(s, CX, CY, 7, 2.2, 8, { long: 2.2, short: 1.6 });
  for (let z = 7; z <= 64; z++) {
    const half = z > 56 ? Math.max(0.6, 3.6 * (64 - z) / 8) : 3.6;
    for (let y = Math.ceil(CY - half); y <= Math.floor(CY + half); y++) {
      const edge = y === Math.ceil(CY - half) || y === Math.floor(CY + half);
      const mid = Math.abs(y - CY) < 1 && z < 54;
      for (const x of [-1, 0]) s.put(x, y, z, edge ? GOLD : mid ? (z % 9 === 0 ? GOLD : PANEL) : VOID);
    }
  }
  return without(paint(s, 41), HAND);
}

// --- Acolyte claws (hand frame) -----------------------------------------------------------------
function claws(inner) {
  const s = new Shape();
  for (const [i, x0] of [-2.6, -1, 0.4, 1.8].entries()) { // four long fingers splayed and curling forward
    const len = i === 1 || i === 2 ? 13 : 11;
    for (let t = 0; t <= len; t += 0.5) {
      const x = x0 + (i - 1.5) * t * 0.22, y = -8 - t, z = 1.5 + (t * t) / 18;
      const rr = t < len - 3 ? 0.9 : 0.5;
      ellipsoid(s, [x, y, z], [rr, 0.6, rr], t >= len - 1.5 ? GOLD : CLAW);
    }
  }
  for (let t = 0; t <= 6; t += 0.5) ellipsoid(s, [-0.5 + inner * (2.8 + t * 0.3), -5 - t * 0.6, 2 + t * 0.4], [0.9, 0.6, 0.9], t >= 5 ? GOLD : CLAW); // thumb
  shellAround(HAND, 1, CLAW, (x, y, z) => z >= 2 && y >= -8).cells.forEach((v) => s.put(...v)); // knuckle plates
  return without(paint(s, 43), HAND);
}

// --- Vaelthar ----------------------------------------------------------------------------------
// A long ash-grey mane round a pale face: a red stripe down the brow, burning gold eyes, a
// black veil from below the eyes in a point down the chest; curtains to the shoulders and a
// mass down the back; a great halo crossed like stars.
function vaelMane() {
  const s = shellAround(HEAD, 2, HAIR, (x, y, z) => y >= 2 && !(z >= 4 && y <= 14 && x >= -6 && x <= 5));
  for (const side of [-1, 1]) { // side curtains falling to the shoulders, thicker as they fall
    for (let y = -26; y <= 14; y++) for (let z = -7; z <= 5; z++) {
      const tip = -18 - ((side * 7 + z * 5) & 7);
      if (y < tip) continue;
      const w = 2 + Math.floor(Math.max(0, 6 - y) / 8);
      for (let k = 0; k < w; k++) s.put(side > 0 ? 8 + k : -9 - k, y, z, HAIR);
    }
  }
  for (let y = 14; y >= -52; y--) { // the back, flaring out and away
    const drop = 14 - y, w = Math.floor(drop / 7), bz = -8 - Math.floor(drop / 6);
    for (let x = -9 - w; x <= 8 + w; x++) {
      if (y < -40 - ((x * 7) & 11)) continue;
      s.put(x, y, bz, HAIR).put(x, y, bz + 1, HAIR_D);
    }
  }
  for (const x of [-9, -8, 7, 8]) for (let y = -30 - (x & 3) * 2; y <= 6; y++) s.put(x, y, 9 + (y < 0 ? 1 : 0), HAIR); // locks down the chest
  recolor(s, (x, y, z, i) => i === HAIR && ((x * 3 + (y >> 2)) % 5 === 0), HAIR_L); // strands
  recolor(s, (x, y, z, i) => i === HAIR && ((x + (y >> 3)) & 1) === 1, HAIR_D);
  // The face: pale skin, the red stripe, the eyes; the veil below.
  for (let x = -6; x <= 5; x++) for (let y = 0; y <= 14; y++) {
    const z = front(HEAD, x, y);
    if (z === null) continue;
    let idx = y >= 7 ? FACE : VOID;
    if (y >= 7 && Math.abs(x + 0.5) < 1.5) idx = BLOOD;
    if (y === 9 && (x === -4 || x === -3 || x === 2 || x === 3)) idx = GLOW;
    if (y === 7) idx = FACE_D;
    s.put(x, y, z + 1, idx);
  }
  for (let y = -16; y <= 0; y++) { // the veil down the chest, a point
    const half = Math.max(0, 6 - (-y) * 0.4);
    for (let x = r(CX - half); x <= r(CX + half); x++) s.put(x, y, 10 + (y < -6 ? 1 : 0), y === 0 ? VOID : ROBE_D);
  }
  halo(s, CX, 16, -15, 27, true);
  return paint(without(s, HEAD, TORSO_IN_HEAD), 51);
}
// Thick tentacles from the shoulder inside the sleeve, pouring out of its mouth at the elbow
// in S-curves, curling at the tips: dark underside, pale suckers on the inner side.
function tentacles(outer) {
  const s = new Shape();
  const arms = [[0.2, 58, 18, 0, 2, 0], [1.2, 50, 15, 1.6, 0, 2], [-1.0, 54, 16, 3.0, 0, -2], [2.4, 40, 12, 4.2, -1, 1]];
  arms.forEach(([ang, drop, reach, ph, ox, oz], j) => {
    for (let k = 0; k <= 160; k++) {
      const u = k / 160, a = ang + Math.sin(u * 6 + ph) * 0.35 * u;
      let out = reach * u ** 0.8 + Math.sin(u * 9 + ph) * 3 * u, y = -14 - drop * u ** 1.1;
      if (u > 0.8) { const c = (u - 0.8) / 0.2; out += Math.sin(c * Math.PI) * 8; y += c * c * 18; }
      const x = -0.5 + outer * (ox + Math.cos(a) * out), z = -0.5 + oz + Math.sin(a) * out;
      const R = (j === 3 ? 2.4 : 3.6) * (1 - u * 0.78);
      ellipsoid(s, [x, y, z], [R, R, R], TENT);
      if (k % 7 === 0 && R > 1.2) s.put(r(x - outer * R), r(y), r(z), SUCKER);
    }
  });
  return paint(without(s, ARM), 53 + outer);
}

// --- Nhazar ----------------------------------------------------------------------------------------
// His head: a vast mass of black curls, far bigger than the body, full of pale stone masks
// that scream, wail, rage and grin; gold crosses stand out of it, a broken ring behind.
function nhazarHead() {
  const s = new Shape();
  const R = 72, cx = CX, cz = 0, cy = R * 0.95;
  for (let x = Math.floor(cx - R - 7); x <= Math.ceil(cx + R + 7); x++) for (let y = Math.floor(cy - R - 7); y <= Math.ceil(cy + R + 7); y++) {
    for (let z = Math.floor(cz - R - 7); z <= Math.ceil(cz + R + 7); z++) {
      const d = Math.hypot(x - cx, y - cy, z - cz) || 1;
      const nx = (x - cx) / d, ny = (y - cy) / d, nz = (z - cz) / d;
      const bump = Math.sin(nx * 11 + ny * 3) * 4.4 + Math.sin(ny * 13 - nz * 5) * 3.8 + Math.sin(nz * 10 + nx * 4) * 4 + Math.sin(nx * 31 + nz * 23) * 1.6;
      const rr = R + bump;
      if (d > rr || d < rr - 1.6) continue; // a shell: the inside is never seen
      const curl = Math.sin(x * 0.65 + y * 0.35) + Math.sin(z * 0.55 - y * 0.45);
      s.put(x, y, z, curl > 0.9 ? CURL_L : curl < -1.1 ? CURL_D : CURL);
    }
  }
  const FACES = { // S stone, L light, D shade, h hole, N nose, G glowing
    scream: ["  SSSSS  ", " SLLLLLS ", "SDDSLSDDS", "SSSSLSSSS", "ShhSNShhS", "ShhSNShhS", "SSSDNDSSS", "SDhhhhhDS", "SShhhhhSS", " SShhhSS ", "  SDDDS  "],
    sorrow: ["  SSSSS  ", " SSSLSSS ", "SSSDLDSSS", "SDDSLSDDS", "SShSNShSS", "ShhSNShhS", "SSSDNDSSS", "SSShhhSSS", "SSShhhSSS", " SShhhSS ", "  SSDSS  "],
    rage: ["  SSSSS  ", " SSSLSSS ", "SDDSLSDDS", "SSDDLDDSS", "ShGSNSGhS", "SShSNShSS", "SSDDNDDSS", "ShLhLhLhS", "ShhhhhhhS", " SLhLhLS ", "  SDDDS  "],
    grin: ["  SSSSS  ", " SSLLLSS ", "SSDSLSDSS", "SSSSLSSSS", "ShhSNShhS", "SShSNShSS", "hSSDNDSSh", "ShSSSSShS", "SShhhhhSS", " SSShSSS ", "  SSSSS  "],
  };
  const KINDS = ["scream", "sorrow", "rage", "scream", "grin", "sorrow"];
  const COLOR = { S: STONE, L: STONE_L, D: STONE_D, h: CURL_D, N: STONE_L, G: GLOW };
  for (let k = 0; k < 34; k++) { // the masks, spread over the mass (fewer underneath), each 3x the v1 grid
    const ph = Math.acos(1 - 1.7 * ((k + 0.5) / 34)), th = k * 2.39996;
    const nx = Math.sin(ph) * Math.cos(th), ny = Math.cos(ph), nz = Math.sin(ph) * Math.sin(th);
    const axis = Math.abs(nz) >= Math.abs(nx) ? "z" : "x", sgn = axis === "z" ? Math.sign(nz) || 1 : Math.sign(nx) || 1;
    const px = cx + nx * (R - 1), py = cy + ny * (R - 1), pz = cz + nz * (R - 1);
    const face = FACES[KINDS[k % KINDS.length]];
    for (let row = 0; row < 33; row++) for (let col = 0; col < 27; col++) {
      const ch = face[Math.floor(row / 3)][Math.floor(col / 3)];
      if (ch === " ") continue;
      const u = col - 13, v = 16 - row;
      const X = r(axis === "x" ? px : px + u * sgn), Y = r(py + v), Z = r(axis === "z" ? pz : pz - u * sgn);
      const out = (d) => [axis === "x" ? X + sgn * d : X, Y, axis === "z" ? Z + sgn * d : Z];
      for (let d = -3; d <= 0; d++) s.put(...out(d), d < 0 ? STONE_D : COLOR[ch]);
      if (ch === "N") s.put(...out(1), STONE_L);
      if (ch === "h" || ch === "G") { s.put(...out(0), ch === "G" ? GLOW : CURL_D); s.put(...out(-1), ch === "G" ? GLOW : CURL_D); }
    }
  }
  // Behind the shell, one layer of hidden voxels: the inner surface, never seen, is not drawn.
  const inner = [];
  for (const [x, y, z, i] of s.cells.values()) {
    if (i === GOLD || i === GOLD_D || i === GOLD_L) continue; // only the curls and the masks' backs
    const d = Math.hypot(x - cx, y - cy, z - cz);
    for (const [dx, dy, dz] of [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]]) {
      const nx = x + dx, ny = y + dy, nz = z + dz;
      if (!s.cells.has(`${nx},${ny},${nz}`) && Math.hypot(nx - cx, ny - cy, nz - cz) < d - 0.2) inner.push([nx, ny, nz]);
    }
  }
  for (const [x, y, z] of inner) s.put(x, y, z, HIDDEN);
  for (let k = 0; k < 9; k++) { // gold crosses standing out of the crown
    const nx = Math.sin((k - 4) * 0.2), ny = Math.cos((k - 4) * 0.2);
    const bx = r(cx + nx * (R + 2)), by = r(cy + ny * (R + 2)), bz = r(cz + (k % 2 ? -18 : 14));
    roundBox(s, [bx, by, bz], [bx + 2, by + 22, bz + 1], 0, GOLD);
    roundBox(s, [bx - 6, by + 15, bz], [bx + 8, by + 17, bz + 1], 0, GOLD);
    roundBox(s, [bx, by + 21, bz], [bx + 2, by + 22, bz + 1], 0, GOLD_L);
  }
  for (let k = 0; k < 240; k++) { // the broken ring behind
    if (k % 60 > 42) continue;
    const a = (k / 240) * Math.PI * 2;
    const x = r(cx + Math.cos(a) * (R + 14)), y = r(cy + Math.sin(a) * (R + 14)), z = r(cz - R + 12);
    for (let d = 0; d < 3; d++) s.put(x, y, z + d, k % 5 ? GOLD : GOLD_D);
  }
  paint(without(s, HEAD), 61);
  return without(s, HEAD);
}
function nhazarCollar() {
  const s = new Shape();
  for (let y = 26; y <= 33; y++) ring(s, y, 8 + (y - 26) * 0.3, 7 + (y - 26) * 0.3, 1.8, y >= 32 ? GOLD : ROBE);
  for (let y = 27; y <= 31; y++) for (let x = -5; x <= 4; x++) s.put(x, y, -1, VOID); // the dark inside
  return paint(without(s, TORSO), 63);
}
// Gold-weighted chains hanging from the outside of the cuff: links, then a weight like a small
// censer with a glowing slit.
function nhazarChains(outer) {
  const s = new Shape();
  for (const [dz, len] of [[2, 24], [-3, 16]]) {
    const x = r(-0.5 + outer * 9), z = r(-0.5 + dz);
    for (let k = 0; k < len; k++) { // alternate links: one in xy, one in zy
      const y = -20 - k * 2;
      if (k % 2) { s.put(x, y, z - 1, GOLD).put(x, y, z + 1, GOLD).put(x, y - 1, z, GOLD_D).put(x, y + 1, z, GOLD_D); }
      else { s.put(x - 1, y, z, GOLD).put(x + 1, y, z, GOLD).put(x, y - 1, z, GOLD_D).put(x, y + 1, z, GOLD_D); }
    }
    const wy = -20 - len * 2 - 4;
    roundBox(s, [x - 2, wy - 4, z - 2], [x + 2, wy + 2, z + 2], 0.8, GOLD);
    for (let y = wy - 2; y <= wy; y++) s.put(x, y, z + 3, GLOW);
    s.put(x, wy - 5, z, GOLD_D).put(x, wy + 3, z, GOLD_D);
  }
  return paint(without(s, FORE), 65 + outer);
}

// --- Table -------------------------------------------------------------------------------------
export function monstersV2() {
  const p = (shape, part) => ({ shape, part, palette: CULT_PALETTE });
  return {
    cult_hood: p(cultHood(), "head"),
    cult_robe: p(cultRobe(), "torso"),
    cult_sleeve_left: p(sleeve(false, 21), "arm_left"),
    cult_sleeve_right: p(sleeve(false, 22), "arm_right"),
    cult_cuff_left: p(cuff(false, 23), "forearm_left"),
    cult_cuff_right: p(cuff(false, 24), "forearm_right"),
    acolyte_hood: p(acolyteHood(), "head"),
    acolyte_robe: p(acolyteRobe(), "torso"),
    acolyte_sleeve_left: p(sleeve(false, 25), "arm_left"),
    acolyte_sleeve_right: p(sleeve(false, 26), "arm_right"),
    acolyte_cuff_left: p(cuff(true, 27), "forearm_left"),
    acolyte_cuff_right: p(cuff(true, 28), "forearm_right"),
    acolyte_claws_left: p(claws(1), "hand_left"),
    acolyte_claws_right: p(claws(-1), "hand_right"),
    inquisitor_hood: p(inquisitorHood(), "head"),
    inquisitor_belt: p(inquisitorBelt(), "torso"),
    inquisitor_pauldron_left: p(pauldron(1), "arm_left"),
    inquisitor_pauldron_right: p(pauldron(-1), "arm_right"),
    inquisitor_vambrace_left: p(vambrace(), "forearm_left"),
    inquisitor_vambrace_right: p(vambrace(), "forearm_right"),
    weapon_inquisitor_sword: p(inquisitorSword(), "hand_right"),
    vaelthar_mane: p(vaelMane(), "head"),
    vaelthar_robe: p(vaeltharRobe(), "torso"),
    vaelthar_sleeve_left: p(sleeve(true, 29), "arm_left"),
    vaelthar_sleeve_right: p(sleeve(true, 30), "arm_right"),
    vaelthar_tentacles_left: p(tentacles(1), "arm_left"),
    vaelthar_tentacles_right: p(tentacles(-1), "arm_right"),
    nhazar_head: p(nhazarHead(), "head"),
    nhazar_collar: p(nhazarCollar(), "torso"),
    nhazar_chains_left: p(nhazarChains(1), "forearm_left"),
    nhazar_chains_right: p(nhazarChains(-1), "forearm_right"),
  };
}
void noise3;
