// v2 weapons (Plan 6.3): the same 17 families and three boss uniques as make_gear.mjs,
// twice the voxels (same length in metres), with bevelled edges, fullers, wrapped grips,
// studs and gems; tier 3 bigger and gilded with runes. Drawn in the v2 fist frame
// (hand_v2: x -3..2, y -8..0, z -2..3): grips run along +Z through the fist's centre
// (x -0.5, y -4.5); the staff and the bow stand upright through it; off-hands in the left.
import { Shape, SHADE, TINT_SECONDARY, GLOW } from "./vox.mjs";
import { ellipsoid, capsule, cylinder, roundBox, carve, tone } from "./sculpt.mjs";
import { handV2 } from "./human_v2.mjs";
import { C, PALETTE, wmats } from "./gear_style.mjs";

const S = TINT_SECONDARY;
const HAND = handV2();
const CX = -0.5, CY = -4.5, CZ = 0.5;
const outsideHand = (s) => carve(s, (t) => { for (const [x, y, z] of HAND.cells.values()) t.put(x, y, z, 0); });
const recolor = (s, pred, idx) => { if (idx == null) return s; for (const v of s.cells.values()) if (pred(v[0], v[1], v[2], v[3])) v[3] = idx; return s; };
// Metals and woods get a light texture of their own tones.
const TEX = {
  [C.IRON]: [C.IRON, C.IRON_D, C.IRON_L], [C.STEEL]: [C.STEEL, C.STEEL_D, C.STEEL_L], [C.DARK_L]: [C.DARK_L, C.DARK, C.DARK_L],
  [C.WOOD]: [C.WOOD, C.WOOD_D, C.WOOD], [C.WOOD_D]: [C.WOOD_D, C.EBONY, C.WOOD], [C.EBONY]: [C.EBONY, C.EBONY_D, C.EBONY],
  [C.GOLD]: [C.GOLD, C.GOLD_D, C.GOLD_L], [C.BRONZE]: [C.BRONZE, C.BRONZE_D, C.BRONZE], [C.LEATHER]: [C.LEATHER, C.LEATHER_D, C.LEATHER_L],
  [C.LEATHER_D]: [C.LEATHER_D, C.BLACK_LEATHER, C.LEATHER],
};
function texture(s, seed) {
  for (const base of Object.keys(TEX).map(Number)) tone(s, base, TEX[base], seed + base, [0.8, 0.12, 0.08]);
  return s;
}

// A straight blade along +Z from z0, `len` long, half-width hw (in y), flat (x -1..0):
// bevelled edges in the edge tone, a darker fuller, a tapering point; runes on tier 3.
function blade(s, z0, len, hw, m, t) {
  const z1 = z0 + len;
  for (let z = z0; z <= z1; z++) {
    const k = Math.min(1, (z1 - z + 1) / (hw * 2.2));
    const half = Math.max(0.5, hw * k);
    for (let y = Math.ceil(CY - half); y <= Math.floor(CY + half); y++) {
      const d = Math.abs(y - CY);
      const idx = d >= half - 1 ? m.edge : d < 1 && z < z1 - hw * 2 ? m.dark : m.blade;
      s.put(-1, y, z, idx).put(0, y, z, idx);
    }
  }
  if (m.rune) for (let z = z0 + 4; z < z1 - hw * 2; z += 6) s.put(-1, Math.round(CY), z, m.rune).put(0, Math.round(CY), z, m.rune);
  if (t >= 2) for (let z = z0; z <= z0 + 3; z++) for (const x of [-1, 0]) s.put(x, Math.round(CY + hw - 1), z, m.gold); // ricasso
  return s;
}
// A grip through the fist with leather wraps, a pommel behind it.
function hilt(s, m, back = 3, pommel = m.gold) {
  cylinder(s, [CX, CY, -back], [CX, CY, 3], 1.4, m.grip);
  recolor(s, (x, y, z, i) => i === m.grip && (z & 1) === 0, C.LEATHER_D);
  ellipsoid(s, [CX, CY, -back - 2], [1.9, 1.9, 1.6], pommel);
}
// A shaft (haft) from z0 to z1 along +Z.
const haft = (s, z0, z1, m, r = 1.3) => cylinder(s, [CX, CY, z0], [CX, CY, z1], r, m.wood);
// A cross-guard reaching hw in y, 2 voxels thick in z.
function guard(s, z, hw, m, t) {
  roundBox(s, [-2, Math.round(CY - hw), z], [1, Math.round(CY + hw), z + 1], 0.8, m.guard);
  if (t >= 2) for (const y of [Math.round(CY - hw), Math.round(CY + hw)]) ellipsoid(s, [CX, y, z + 0.5], [1.6, 1.4, 1.4], m.gold); // gilded quillon ends
  if (t >= 2) s.put(-1, -5, z + 2, m.gem).put(0, -4, z + 2, m.gem);
}

const WEAPON = {
  sword(s, m, t) { hilt(s, m); guard(s, 4, 7 + 2 * t, m, t); blade(s, 6, 2 * (14 + 2 * t), 3, m, t); },
  short_sword(s, m, t) { hilt(s, m, 3, m.guard); guard(s, 4, 5, m, t); blade(s, 6, 2 * (9 + t), 2, m, t); },
  dagger(s, m, t) {
    hilt(s, m, 3, m.guard);
    guard(s, 4, 4 + (t >= 2 ? 1 : 0), m, 1);
    blade(s, 6, 2 * (6 + t), 2.2, m, t);
  },
  axe(s, m, t) {
    hilt(s, m, 4, m.wood_d);
    const z = 2 * (8 + t) + 6;
    haft(s, -4, z + 10 + 2 * t, m);
    for (let k = 0; k <= 9; k++) { // the bit, flaring down to a curved edge
      const reach = 4 + 2 * t + Math.round(Math.sin((k / 9) * Math.PI) * 2);
      for (let y = Math.round(CY) - reach; y <= Math.round(CY) + 1; y++) for (const x of [-1, 0]) s.put(x, y, z + k, y <= Math.round(CY) - reach + 1 ? m.edge : m.blade);
    }
    roundBox(s, [-1, Math.round(CY) + 2, z + 2], [0, Math.round(CY) + 6, z + 6], 0.6, m.dark); // back spike
    if (t >= 2) cylinder(s, [CX, CY, z - 1], [CX, CY, z], 1.9, m.gold);
    if (m.rune) s.put(-1, Math.round(CY) - 3, z + 4, m.rune).put(0, Math.round(CY) - 3, z + 4, m.rune);
  },
  mace(s, m, t) {
    hilt(s, m, 4, m.gold);
    haft(s, -4, 22, m);
    const z0 = 23, z1 = 30 + 2 * t;
    ellipsoid(s, [CX, CY, (z0 + z1) / 2], [3.6, 3.6, (z1 - z0) / 2 + 0.5], m.dark);
    for (const [dx, dy] of [[4, 0], [-4, 0], [0, 4], [0, -4]]) {
      roundBox(s, [Math.round(CX + dx) - (dx ? 1 : 0), Math.round(CY + dy) - (dy ? 1 : 0), z0], [Math.round(CX + dx) + (dx ? 1 : 0), Math.round(CY + dy) + (dy ? 1 : 0), z1], 0.6, m.blade);
    }
    recolor(s, (x, y, z, i) => z === z1 && i === m.blade, m.edge);
    cylinder(s, [CX, CY, z1 + 1], [CX, CY, z1 + 4], 1, m.gold);
    if (m.rune) cylinder(s, [CX, CY, z0 + 2], [CX, CY, z0 + 3], 3.8, m.rune);
  },
  scepter(s, m, t) {
    cylinder(s, [CX, CY, -6], [CX, CY, 22], 1.3, m.gold);
    cylinder(s, [CX, CY, -3], [CX, CY, 3], 1.5, m.grip);
    const z = 24;
    ellipsoid(s, [CX, CY, z + 2], [3.4, 3.4, 2.6], m.gold);
    ellipsoid(s, [CX, CY, z + 6], [1.8, 1.8, 2], m.gem);
    s.put(-1, -3, z + 7, C.WHITE);
    const rays = t >= 2 ? 8 : 4;
    for (let k = 0; k < rays; k++) {
      const a = (k / rays) * Math.PI * 2;
      capsule(s, [CX, CY, z + 2], [CX + Math.cos(a) * 7, CY + Math.sin(a) * 7, z + 3], 0.9, 0.4, m.gold);
    }
    if (m.rune) cylinder(s, [CX, CY, z + 9], [CX, CY, z + 10], 1, m.rune);
  },
  wand(s, m, t) {
    cylinder(s, [CX, CY, -3], [CX, CY, 2 * (7 + t) + 6], 1.1, m.wood);
    cylinder(s, [CX, CY, -3], [CX, CY, 3], 1.4, m.grip);
    if (t >= 2) cylinder(s, [CX, CY, 8], [CX, CY, 9], 1.6, m.gold);
    const tip = 2 * (7 + t) + 6;
    ellipsoid(s, [CX, CY, tip + 2], [1.8, 1.8, 2.4], t >= 2 ? m.crystal : C.CRYSTAL);
    s.put(-1, -4, tip + 5, GLOW).put(0, -4, tip + 5, GLOW);
  },
  greatsword(s, m, t) {
    cylinder(s, [CX, CY, -12], [CX, CY, 3], 1.5, m.grip);
    recolor(s, (x, y, z, i) => i === m.grip && (z & 1) === 0, C.LEATHER_D);
    ellipsoid(s, [CX, CY, -14], [2.2, 2.2, 1.8], m.gold);
    guard(s, 4, 11 + 2 * t, m, t);
    if (t >= 2) for (const dir of [-1, 1]) capsule(s, [CX, CY + dir * (11 + 2 * t), 5], [CX, CY + dir * (11 + 2 * t), 9], 1.1, 0.6, m.guard); // swept quillons
    blade(s, 6, 2 * (22 + 2 * t), 4 + (t >= 3 ? 1 : 0), m, t);
  },
  great_axe(s, m, t) {
    haft(s, -16, 2 * (18 + t) + 6, m);
    cylinder(s, [CX, CY, -8], [CX, CY, 3], 1.5, m.grip);
    const z = 2 * (12 + t) + 6;
    for (const dir of [1, -1]) for (let k = 0; k <= 11; k++) {
      const reach = 6 + 2 * t + Math.round(Math.sin((k / 11) * Math.PI) * 3);
      for (let r = 2; r <= reach; r++) for (const x of [-1, 0]) s.put(x, Math.round(CY + dir * r), z + k, r >= reach - 1 ? m.edge : m.blade);
    }
    roundBox(s, [-2, Math.round(CY) - 2, z + 2], [1, Math.round(CY) + 2, z + 9], 0.8, m.dark);
    if (t >= 2) roundBox(s, [-2, Math.round(CY) - 1, z + 4], [1, Math.round(CY) + 1, z + 7], 0.5, m.gold);
    if (m.rune) for (const dir of [1, -1]) s.put(-1, Math.round(CY + dir * 6), z + 5, m.rune).put(0, Math.round(CY + dir * 6), z + 5, m.rune);
  },
  warhammer(s, m, t) {
    haft(s, -16, 2 * (16 + t) + 6, m);
    cylinder(s, [CX, CY, -8], [CX, CY, 3], 1.5, m.grip);
    const z = 2 * (13 + t) + 6;
    roundBox(s, [Math.round(CX - 9 - 2 * t), Math.round(CY) - 5, z], [Math.round(CX + 9 + 2 * t), Math.round(CY) + 5, z + 8], 1.2, m.dark);
    for (const x of [Math.round(CX - 9 - 2 * t), Math.round(CX + 9 + 2 * t)]) recolor(s, (xx, y, zz, i) => xx === x && i === m.dark, m.blade); // striking faces
    recolor(s, (x, y, zz, i) => zz === z + 8 && i === m.dark, m.edge);
    if (t >= 2) roundBox(s, [-3, Math.round(CY) - 3, z + 1], [2, Math.round(CY) + 3, z + 7], 0.6, m.gold);
    if (m.rune) roundBox(s, [-2, Math.round(CY) - 2, z + 2], [1, Math.round(CY) + 2, z + 6], 0.4, m.rune);
    capsule(s, [CX, CY, z + 9], [CX, CY, z + 13 + 2 * t], 1.6, 0.4, m.blade); // top spike
  },
  halberd(s, m, t) {
    haft(s, -24, 2 * (24 + t) + 6, m);
    cylinder(s, [CX, CY, -4], [CX, CY, 3], 1.5, m.grip);
    const z = 2 * (16 + t) + 6;
    for (let k = 0; k <= 11; k++) {
      const reach = 6 + 2 * t + Math.round(Math.sin((k / 11) * Math.PI) * 2);
      for (let r = 2; r <= reach; r++) for (const x of [-1, 0]) s.put(x, Math.round(CY - r), z + k, r >= reach - 1 ? m.edge : m.blade);
    }
    capsule(s, [CX, CY + 2, z + 4], [CX, CY + 7, z + 7], 1.2, 0.4, m.dark); // back hook
    capsule(s, [CX, CY, z + 16 + 2 * t], [CX, CY, z + 28 + 2 * t], 2.2, 0.3, m.blade); // spear point
    if (t >= 2) cylinder(s, [CX, CY, z - 4], [CX, CY, z - 2], 2, m.gold);
    if (m.rune) s.put(-1, Math.round(CY) - 4, z + 5, m.rune).put(0, Math.round(CY) - 4, z + 5, m.rune);
  },
  // An upright staff through the fist, a crystal in gold claws on top, growing with the tier.
  staff(s, m, t) {
    cylinder(s, [CX, -36, CZ], [CX, 50, CZ], 1.3, m.wood);
    for (let y = -30; y <= 46; y += 10) cylinder(s, [CX, y, CZ], [CX, y, CZ], 1.8, m.wood_d);
    cylinder(s, [CX, 50, CZ], [CX, 52, CZ], 2.6, m.gold);
    for (const [dx, dz] of [[2.4, 2.4], [-2.4, 2.4], [2.4, -2.4], [-2.4, -2.4]]) capsule(s, [CX + dx, 52, CZ + dz], [CX + dx * 0.7, 58 + 2 * t, CZ + dz * 0.7], 0.8, 0.5, m.gold);
    ellipsoid(s, [CX, 58 + t, CZ], [2.2 + 0.4 * t, 4 + t, 2.2 + 0.4 * t], m.crystal);
    if (t >= 3) for (const dx of [-6, 5]) ellipsoid(s, [dx, 58, CZ], [1.2, 1.2, 1.2], GLOW);
  },
  bow(s, m, t) {
    capsule(s, [CX, -13, CZ], [CX, 4, CZ], 1.6, 1.6, m.wood);
    cylinder(s, [CX, -8, CZ], [CX, -1, CZ], 1.8, m.grip);
    const tip = 24 + 2 * (t - 1);
    const limb = [[4, 0.5], [12, 0], [18, -1.5], [tip - 2, -3.5], [tip, -5.5]];
    for (const sign of [1, -1]) for (let i = 0; i < limb.length - 1; i++) {
      const fy = (y) => (sign > 0 ? y : -9 - y);
      capsule(s, [CX, fy(limb[i][0]), limb[i][1]], [CX, fy(limb[i + 1][0]), limb[i + 1][1]], 1.4 - i * 0.2, 1.2 - i * 0.2, m.wood);
    }
    if (t >= 2) for (const y of [9, -18]) cylinder(s, [CX, y, 0], [CX, y + 1, 0], 1.7, m.gold);
    if (m.rune) for (const y of [15, -24]) s.put(-1, y, -1, m.rune);
    for (let y = -9 - tip; y <= tip; y++) s.put(-1, y, -6, C.STRING);
  },
  crossbow(s, m, t) {
    roundBox(s, [-2, -8, -8], [1, -2, 20], 1, m.wood);
    roundBox(s, [-2, -1, -4], [1, -1, 18], 0, m.wood_d);
    const w = 15 + 2 * t;
    capsule(s, [-w, -2.5, 19], [w - 1, -2.5, 19], 1.4, 1.4, t >= 2 ? m.blade : m.wood);
    for (const x of [-w, w - 1]) capsule(s, [x, -2.5, 19], [x, -2.5, 13], 1.1, 0.9, m.wood);
    for (let x = -w; x <= w - 1; x++) s.put(x, -2, 13, C.STRING);
    cylinder(s, [CX, 0, -2], [CX, 0, 24], 0.6, m.blade);
    s.put(-1, 0, 25, m.edge).put(0, 0, 25, m.edge).put(-1, 0, 26, m.edge);
    roundBox(s, [-1, -10, -3], [0, -9, 1], 0, C.LEATHER_D);
    if (m.rune) s.put(-1, -5, 10, m.rune).put(0, -5, 10, m.rune);
  },
  // Off-hands in the left fist: a kite shield on the outer side (+X), facing out.
  shield(s, m, t) {
    const h = 14 + 2 * t, w = 10 + 2 * t, cy = CY + 2, cz = CZ;
    for (let y = -h; y <= h; y++) {
      const half = y < 0 ? w * (1 + y / (h * 1.1)) : w * (1 - (y / h) ** 4 * 0.2); // narrows to a point below
      for (let z = Math.ceil(-half); z <= Math.floor(half); z++) {
        const rim = Math.abs(z) >= half - 1.2 || y >= h - 1 || y <= -h + 1;
        const bulge = Math.round(1.5 * (1 - (z / w) ** 2) * (1 - (y / h) ** 2));
        for (let x = 4; x <= 5 + bulge; x++) s.put(x, Math.round(cy + y), Math.round(cz + z), rim ? m.dark : t === 1 ? m.wood : m.blade);
      }
    }
    ellipsoid(s, [8, cy, cz], [1.6, 3.4, 3.4], t >= 2 ? m.gold : m.dark); // boss
    if (t >= 2) for (let k = -h + 4; k <= h - 4; k++) s.put(7, Math.round(cy + k), Math.round(cz), m.gold).put(7, Math.round(cy), Math.round(cz + k * w / h), m.gold);
    if (m.rune) ellipsoid(s, [9, cy, cz], [0.8, 1.6, 1.6], m.rune);
    roundBox(s, [3, Math.round(CY) - 2, -2], [3, Math.round(CY) + 2, 3], 0, C.LEATHER_D); // strap
  },
  orb(s, m, t) { // a glowing sphere floating above the open left hand, ringed by gold
    const cy = CY + 16, r = 4 + 2 * Math.min(t, 2);
    ellipsoid(s, [CX, cy, CZ], [r, r, r], m.crystal);
    recolor(s, (x, y, z, i) => i === m.crystal && (x + y + z) % 3 === 0, C.CRYSTAL_D);
    s.put(-2, Math.round(cy + r * 0.5), Math.round(CZ + r * 0.6), GLOW);
    if (t >= 2) for (let a = 0; a < 48; a++) {
      const ang = (a / 48) * Math.PI * 2;
      s.put(Math.round(CX + Math.cos(ang) * (r + 2)), Math.round(cy), Math.round(CZ + Math.sin(ang) * (r + 2)), m.gold);
    }
    if (t >= 3) for (let a = 0; a < 48; a++) {
      const ang = (a / 48) * Math.PI * 2;
      s.put(Math.round(CX + Math.cos(ang) * (r + 2)), Math.round(cy + Math.sin(ang) * (r + 2)), Math.round(CZ), GLOW);
    }
  },
  tome(s, m, t) { // a thick book held flat in the left fist, its cover in the secondary colour
    roundBox(s, [-3, 1, -3], [8, 4, 14], 0, C.PAPER);
    recolor(s, (x, y, z) => x === -3, C.PAPER_D);
    for (const y of [0, 5]) roundBox(s, [-4, y, -4], [9, y, 15], 0.5, S);
    roundBox(s, [-4, 0, -4], [-4, 5, 15], 0, SHADE(S)); // spine
    if (t >= 2) {
      for (const [x, z] of [[-4, -4], [8, -4], [-4, 14], [8, 14]]) roundBox(s, [x, 5, z], [x + 1, 6, z + 1], 0, m.gold);
      ellipsoid(s, [2.5, 6, 5.5], [1.6, 0.6, 1.6], m.gem);
    }
    if (t >= 3) for (const z of [-2, 13]) roundBox(s, [-1, 6, z], [6, 6, z], 0, GLOW);
  },
};
const OFFHAND = ["shield", "orb", "tome"];

// --- Boss uniques, each with its own glow -----------------------------------------------
const UNIQUES = {
  // The Acolyte's black-sun scepter: a blackened rod, a broken sun of gold rays around a dark
  // core that burns gold.
  unique_acolyte: { glow: "#ffcf6a", build(s) {
    cylinder(s, [CX, CY, -6], [CX, CY, 26], 1.3, C.DARK);
    cylinder(s, [CX, CY, -3], [CX, CY, 3], 1.5, C.RED_D);
    for (const z of [10, 18]) cylinder(s, [CX, CY, z], [CX, CY, z], 2.2, C.GOLD);
    const z = 30;
    ellipsoid(s, [CX, CY, z], [4.4, 4.4, 3.4], C.DARK_D);
    ellipsoid(s, [CX, CY, z + 1], [2.8, 2.8, 2.8], GLOW);
    for (let k = 0; k < 5; k++) {
      if (k === 1) continue; // the sun is broken
      const a = (k / 5) * Math.PI * 2 - Math.PI / 2;
      capsule(s, [CX, CY, z], [CX + Math.cos(a) * 10, CY + Math.sin(a) * 10, z + 1], 1.2, 0.4, C.GOLD);
    }
    capsule(s, [CX, CY, z + 3], [CX, CY, z + 8], 1.2, 0.5, C.GOLD_L);
  } },
  // Vaelthar's staff: a pale twisting shaft, a halo of gold around a violet eye, tendrils.
  unique_vaelthar: { glow: "#c07bff", build(s) {
    for (let y = -34; y <= 52; y++) {
      const ox = Math.round(Math.sin(y / 5) * 1.2);
      for (const dx of [-1, 0]) for (const dz of [0, 1]) s.put(dx + ox, y, dz, (y & 7) === 0 ? C.GOLD_D : C.WHITE);
    }
    const cy = 64;
    for (let a = 0; a < 96; a++) {
      const ang = (a / 96) * Math.PI * 2;
      for (const r of [11, 12]) s.put(Math.round(CX + Math.cos(ang) * r), Math.round(cy + Math.sin(ang) * r), 1, C.GOLD);
    }
    ellipsoid(s, [CX, cy, 1], [3.4, 3.4, 2], GLOW);
    ellipsoid(s, [CX, cy, 3], [1.2, 1.6, 0.8], C.EBONY); // the eye
    for (const x of [-4, 0, 4]) capsule(s, [x, 52, 2], [x * 1.4, 44, 6], 0.9, 0.4, C.CRYSTAL_D);
  } },
  // Nhazar's greatsword: a dark blade split by red runes, chains round the hilt, a fanged
  // mouth at the guard.
  unique_nhazar: { glow: "#ff3355", build(s) {
    const m = { blade: C.DARK, edge: C.DARK_L, dark: C.DARK_D, gold: C.GOLD, rune: GLOW };
    cylinder(s, [CX, CY, -12], [CX, CY, 3], 1.5, C.BLACK_LEATHER);
    for (let z = -12; z <= 3; z += 3) cylinder(s, [CX, CY, z], [CX, CY, z], 2.2, C.IRON_D); // chains
    ellipsoid(s, [CX, CY, -14], [2.2, 2.2, 1.8], C.GOLD);
    roundBox(s, [-2, Math.round(CY) - 11, 4], [1, Math.round(CY) + 13, 6], 1, C.DARK_D);
    roundBox(s, [-2, Math.round(CY) - 2, 6], [1, Math.round(CY) + 3, 6], 0, C.RED); // the mouth
    for (const y of [-6, -4, -2]) s.put(-1, y, 7, C.WHITE).put(0, y + 1, 7, C.WHITE); // fangs
    blade(s, 8, 56, 5, m, 1);
    for (let z = 12; z < 58; z += 4) s.put(-1, Math.round(CY) + ((z >> 2) & 1), z, GLOW).put(0, Math.round(CY) + ((z >> 2) & 1), z, GLOW);
  } },
};

export function gearWeaponsV2() {
  const out = {};
  for (const t of [1, 2, 3]) {
    const m = wmats(t);
    for (const [type, build] of Object.entries(WEAPON)) {
      const left = OFFHAND.includes(type) || type === "bow";
      const s = new Shape();
      build(s, m, t);
      out[`w_${type}_t${t}`] = { shape: outsideHand(texture(s, t * 31)), part: left ? "hand_left" : "hand_right", palette: PALETTE };
      if (type === "dagger" || type === "short_sword") {
        const l = new Shape();
        build(l, m, t);
        out[`w_${type}_t${t}_left`] = { shape: outsideHand(texture(l, t * 31)), part: "hand_left", palette: PALETTE };
      }
    }
  }
  for (const [id, u] of Object.entries(UNIQUES)) {
    const s = new Shape();
    u.build(s);
    out[`w_${id}`] = { shape: outsideHand(texture(s, 77)), part: "hand_right", palette: { ...PALETTE, [GLOW]: u.glow } };
  }
  return out;
}
