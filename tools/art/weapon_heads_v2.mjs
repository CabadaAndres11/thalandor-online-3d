// Weapon blades and heads (Plan 6.3.3), after the paladin and hammer references: 25 % bigger
// than 0.9.2, thick blades with a diamond section in three textured tones (dark core, body,
// bright edge), gold trims that follow the shape, and a silhouette of its own per family.
// Same frame as gear_weapons_v2.mjs: grips run along +Z through (x -0.5, y -4.5); the
// blade's width is in y, its thickness in x.
import { GLOW } from "./vox.mjs";
import { ellipsoid, capsule, cylinder, roundBox } from "./sculpt.mjs";
import { C, PALETTE } from "./gear_style.mjs";

export const CX = -0.5, CY = -4.5;
const SC = 1.25; // heads and blades grow by a quarter; grips stay
const r = (v) => Math.round(v);

// Steel tones of these weapons (indices 110+, outside the shared v1 palette).
export const W = { ST_CORE: 110, ST_BODY: 111, ST_EDGE: 112, DK_CORE: 113, DK_BODY: 114, ST_CORE_T: 115, ST_BODY_T: 116, ST_EDGE_T: 117, DK_BODY_T: 118 };
export const WPALETTE = {
  ...PALETTE,
  [W.ST_CORE]: "#3f4757", [W.ST_BODY]: "#7a8698", [W.ST_EDGE]: "#e6edf5",
  [W.DK_CORE]: "#1f2330", [W.DK_BODY]: "#424a5e",
  [W.ST_CORE_T]: "#363d4b", [W.ST_BODY_T]: "#6f7b8d", [W.ST_EDGE_T]: "#cfd8e3", [W.DK_BODY_T]: "#394052",
};
// Each tone mixed with a near shade so no face is flat (texture() in gear_weapons_v2.mjs).
export const WTEX = {
  [W.ST_CORE]: [W.ST_CORE, W.ST_CORE_T, W.ST_CORE], [W.ST_BODY]: [W.ST_BODY, W.ST_BODY_T, W.ST_BODY],
  [W.ST_EDGE]: [W.ST_EDGE, W.ST_EDGE_T, W.ST_EDGE], [W.DK_BODY]: [W.DK_BODY, W.DK_BODY_T, W.DK_BODY],
};

// Materials per tier: tier 1 iron and bronze, tier 2 steel and gold with a red gem, tier 3
// dark steel, bright gold, glowing runes and gems.
export function wmats2(t) {
  return t === 1
    ? { core: C.IRON_D, body: C.IRON, edge: C.IRON_L, blade: C.IRON, dark: C.IRON_D, guard: C.IRON_D, grip: C.LEATHER, wood: C.WOOD, wood_d: C.WOOD_D, gold: C.BRONZE, trim: null, gem: C.IRON_L, rune: null, crystal: C.CRYSTAL }
    : t === 2
      ? { core: W.ST_CORE, body: W.ST_BODY, edge: W.ST_EDGE, blade: W.ST_BODY, dark: W.ST_CORE, guard: C.GOLD, grip: C.LEATHER_D, wood: C.WOOD_D, wood_d: C.EBONY, gold: C.GOLD, trim: C.GOLD, gem: C.GEM, rune: null, crystal: C.CRYSTAL }
      : { core: W.DK_CORE, body: W.DK_BODY, edge: W.ST_EDGE, blade: W.DK_BODY, dark: W.DK_CORE, guard: C.GOLD_L, grip: C.RED_D, wood: C.EBONY, wood_d: C.GOLD_D, gold: C.GOLD_L, trim: C.GOLD_L, gem: C.GEM, rune: GLOW, crystal: GLOW };
}
export const BLADE_TONES = (t) => { const m = wmats2(t); return { core: m.core, body: m.body, edge: m.edge }; };

// The x cells of a blade at a relative distance d (0 middle .. 1 edge) from its spine: four
// thick along the spine, two out to the edge (a diamond section).
const thick = (d) => (d < 0.34 ? [-2, -1, 0, 1] : [-1, 0]);
const toneAt = (d, half, m) => (d * half >= half - 1.01 ? m.edge : d < 0.34 ? m.core : m.body);

// A blade along +Z from z0, len long, half-width hw at its widest; width(u) (u 0..1 along
// it) shapes the outline; the point tapers over the last `tip` share. Runes on tier 3,
// a gold trim along both sides of the spine near the guard from tier 2.
export function bladeV3(s, z0, len, hw, m, width = () => 1, tip = 0.18) {
  const z1 = z0 + len;
  for (let z = z0; z <= z1; z++) {
    const u = (z - z0) / len;
    const k = u > 1 - tip ? Math.max(0.06, (1 - u) / tip) : 1;
    const half = Math.max(0.6, hw * width(u) * k);
    for (let y = Math.ceil(CY - half); y <= Math.floor(CY + half); y++) {
      const d = Math.min(1, Math.abs(y - CY) / half);
      for (const x of thick(d)) s.put(x, y, z, toneAt(d, half, m));
    }
  }
  if (m.rune) for (let z = z0 + 5; z < z1 - hw * 2; z += 6) for (const x of [-2, 1]) s.put(x, r(CY), z, m.rune);
  if (m.trim) for (let z = z0; z <= z0 + Math.round(len * 0.12); z++) for (const x of [-2, 1]) s.put(x, r(CY - 1), z, m.trim).put(x, r(CY + 1), z, m.trim);
  return s;
}

// A broad cross-guard: a bar `hw` wide (y) with knobs, gilded from tier 2 with a gem in the
// middle; tier 3 sweeps its ends up into wings.
export function guardV3(s, z, hw, m, t) {
  roundBox(s, [-3, r(CY - hw), z], [2, r(CY + hw), z + 2], 0.9, m.guard);
  for (const y of [r(CY - hw), r(CY + hw)]) ellipsoid(s, [CX, y, z + 1], [2.2, 1.8, 1.8], t >= 2 ? m.gold : m.dark);
  if (t >= 2) { ellipsoid(s, [-2.6, CY, z + 1], [0.9, 1.6, 1.4], m.gem); s.put(-3, r(CY) - 1, z + 2, C.WHITE); }
  if (t >= 3) for (const dir of [-1, 1]) capsule(s, [CX, CY + dir * hw, z + 1], [CX, CY + dir * (hw + 3), z + 7], 1.4, 0.5, m.gold);
}

// A fan-shaped axe bit on one side (dir -1: toward -y) of the haft, from z0, `h` tall, reaching
// `reach` out: it flares wider toward the edge (beard below, horn above), its edge bows out,
// thick at the cheek and thin at the edge, with a gold rim following it from tier 2.
export function axeBit(s, z0, h, reach, dir, m) {
  for (let rr = 2; rr <= reach + 3; rr++) {
    const f = Math.min(1, (rr - 2) / Math.max(1, reach - 2));
    const lo = z0 + 3 - 9 * f * f, hi = z0 + h - 3 + 6 * f * f; // flares down (beard) and up (horn) toward the edge
    for (let z = Math.floor(lo); z <= Math.ceil(hi); z++) {
      const u = (z - lo) / Math.max(1, hi - lo);
      const out = reach + 3.5 * Math.sin(Math.PI * Math.min(1, Math.max(0, u))); // the edge bows out
      if (rr > out) continue;
      const y = r(CY + dir * rr);
      const edge = rr >= out - 1.2;
      const xs = rr < reach * 0.45 ? [-2, -1, 0, 1] : [-1, 0];
      const idx = edge ? m.edge : rr < reach * 0.45 ? m.core : m.body;
      for (const x of xs) s.put(x, y, z, idx);
      if (m.trim && !edge && rr >= out - 3 && rr < out - 1.2) for (const x of xs) s.put(x, y, z, m.trim);
    }
  }
  if (m.rune) for (const x of [-2, 1]) s.put(x, r(CY + dir * reach * 0.3), r(z0 + h / 2), m.rune);
}

// --- Family builders (blades and heads; grips reuse gear_weapons_v2's hilt and haft) ----
export function headsV3({ hilt, haft }) {
  return {
    sword(s, m, t) {
      hilt(s, m);
      guardV3(s, 4, SC * (7 + 2 * t), m, t);
      // Flares by the guard, runs straight, ends in a diamond point.
      bladeV3(s, 7, r(SC * 2 * (14 + 2 * t)), SC * 3, m, (u) => (u < 0.15 ? 1.35 - u * 2.3 : u > 0.6 ? 1.1 : 1), 0.22);
    },
    short_sword(s, m, t) {
      hilt(s, m, 3, m.guard);
      guardV3(s, 4, SC * 5, m, t >= 3 ? 2 : t);
      // A broad leaf: narrow at the guard, widest two thirds up.
      bladeV3(s, 7, r(SC * 2 * (9 + t)), SC * 3.4, m, (u) => 0.5 + 0.7 * Math.sin(Math.PI * Math.min(1, u * 0.85)), 0.3);
    },
    dagger(s, m, t) {
      hilt(s, m, 3, m.guard);
      guardV3(s, 4, SC * (4 + (t >= 2 ? 1 : 0)), m, 1);
      // A triangle, broad at the guard, narrowing straight to the point, with a dark fuller.
      bladeV3(s, 7, r(SC * 2 * (6 + t)), SC * 3.2, m, (u) => 1.2 - 1.05 * u, 0.1);
    },
    greatsword(s, m, t) {
      cylinder(s, [CX, CY, -12], [CX, CY, 3], 1.5, m.grip);
      ellipsoid(s, [CX, CY, -14], [2.8, 2.8, 2.2], m.gold);
      if (t >= 2) ellipsoid(s, [-2.5, CY, -14], [0.8, 1.2, 1.2], m.gem);
      guardV3(s, 4, SC * (11 + 2 * t), m, t);
      if (t >= 2) for (const dir of [-1, 1]) capsule(s, [CX, CY + dir * SC * (11 + 2 * t), 6], [CX, CY + dir * SC * (9 + 2 * t), 11], 1.3, 0.6, m.guard); // swept quillons
      const len = r(SC * 2 * (22 + 2 * t));
      // A ricasso (narrow, gold-wrapped from tier 2), then a broad blade to a long point.
      bladeV3(s, 7, len, SC * (4 + (t >= 3 ? 1 : 0)), m, (u) => (u < 0.1 ? 0.55 : u < 0.14 ? 1.25 : 1.1), 0.16);
      if (m.trim) for (let z = 7; z < 7 + len * 0.1; z++) for (const x of [-2, 1]) s.put(x, r(CY), z, m.trim);
    },
    axe(s, m, t) {
      hilt(s, m, 4, m.wood_d);
      const z = r(SC * (2 * (8 + t))) + 6;
      haft(s, -4, z + r(SC * (12 + 2 * t)), m);
      axeBit(s, z, r(SC * 11), r(SC * (5 + 2 * t)), -1, m);
      capsule(s, [CX, CY + 2, z + 5], [CX, CY + SC * 6, z + 4], 1.6, 0.4, m.dark); // back spike
      cylinder(s, [CX, CY, z], [CX, CY, z + r(SC * 9)], 2.2, m.dark); // the socket
      if (m.trim) for (const zz of [z, z + r(SC * 9)]) cylinder(s, [CX, CY, zz], [CX, CY, zz], 2.6, m.trim);
    },
    great_axe(s, m, t) {
      haft(s, -16, r(SC * 2 * (18 + t)) + 10, m);
      cylinder(s, [CX, CY, -8], [CX, CY, 3], 1.5, m.grip);
      const z = r(SC * 2 * (12 + t)) + 6;
      for (const dir of [1, -1]) axeBit(s, z, r(SC * 14), r(SC * (7 + 2 * t)), dir, m); // a double crescent
      roundBox(s, [-3, r(CY) - 2, z + 1], [2, r(CY) + 2, z + r(SC * 12)], 0.8, m.dark);
      capsule(s, [CX, CY, z + r(SC * 12)], [CX, CY, z + r(SC * 12) + 8 + 2 * t], 2, 0.4, m.edge); // the crown spike
      if (m.trim) roundBox(s, [-3, r(CY) - 1, z + 4], [2, r(CY) + 1, z + 9], 0.5, m.trim);
      if (t >= 2) ellipsoid(s, [-3, CY, z + 6], [0.9, 1.3, 1.3], m.gem);
    },
    mace(s, m, t) {
      hilt(s, m, 4, m.gold);
      haft(s, -4, r(SC * 22), m);
      const z0 = r(SC * 22) + 1, h = r(SC * (8 + 2 * t));
      ellipsoid(s, [CX, CY, z0 + h / 2], [SC * 3.2, SC * 3.2, h / 2 + 0.5], m.core);
      // Six flanges standing out round the core, each a pointed plate with a bright rim.
      const out = SC * (5.5 + t);
      for (let k = 0; k < 6; k++) {
        const a = (k / 6) * Math.PI * 2, ca = Math.cos(a), sa = Math.sin(a);
        for (let rr = 1; rr <= out; rr += 0.5) {
          const span = (h / 2 + 1) * (1 - (rr / out) * 0.55);
          for (let z = Math.ceil(z0 + h / 2 - span); z <= Math.floor(z0 + h / 2 + span); z++) {
            const edge = rr > out - 1.1 || Math.abs(z - (z0 + h / 2)) > span - 1;
            for (const w of [-0.5, 0.5]) s.put(r(CX + ca * rr - sa * w), r(CY + sa * rr + ca * w), z, edge ? m.edge : m.body);
          }
        }
      }
      capsule(s, [CX, CY, z0 + h], [CX, CY, z0 + h + 5 + 2 * t], 1.8, 0.4, m.edge); // top spike
      if (m.trim) for (const zz of [z0 - 1, z0]) cylinder(s, [CX, CY, zz], [CX, CY, zz], 2.6, m.trim);
      if (m.rune) cylinder(s, [CX, CY, z0 + r(h / 2)], [CX, CY, z0 + r(h / 2)], SC * 3.3, m.rune);
    },
    warhammer(s, m, t) {
      haft(s, -16, r(SC * 2 * (16 + t)) + 8, m);
      cylinder(s, [CX, CY, -8], [CX, CY, 3], 1.5, m.grip);
      const z = r(SC * 2 * (13 + t)) + 6, hh = r(SC * 9), face = r(SC * (8 + 2 * t));
      // A block on the +y side with a framed striking face, a beak on the -y side.
      roundBox(s, [-4, r(CY), z], [3, r(CY) + face, z + hh], 1, m.body);
      roundBox(s, [-4, r(CY) + face - 1, z], [3, r(CY) + face, z + hh], 0.6, m.edge); // the face
      roundBox(s, [-3, r(CY) + face, z + 1], [2, r(CY) + face, z + hh - 1], 0, m.core); // its sunken middle
      if (m.trim) {
        roundBox(s, [-4, r(CY) + 1, z], [3, r(CY) + 2, z + hh], 0.4, m.trim); // gold bands framing the block
        roundBox(s, [-4, r(CY) + face - 3, z], [3, r(CY) + face - 2, z + hh], 0.4, m.trim);
      }
      ellipsoid(s, [-4.5, CY + face / 2, z + hh / 2], [1, 2, 2], t >= 2 ? m.gem : m.dark); // the centre gem
      if (t >= 2) s.put(-5, r(CY + face / 2) - 1, r(z + hh / 2) + 1, C.WHITE);
      capsule(s, [CX, CY - 1, z + hh / 2], [CX, CY - SC * (7 + t), z + hh / 2 - 2], 2.4, 0.4, m.core); // the beak
      capsule(s, [CX, CY, z + hh], [CX, CY, z + hh + 6 + 2 * t], 1.8, 0.4, m.edge); // top spike
      if (m.rune) for (const x of [-4, 3]) s.put(x, r(CY + face / 2), r(z + hh / 2), m.rune);
    },
    halberd(s, m, t) {
      haft(s, -24, r(SC * 2 * (24 + t)) + 8, m);
      cylinder(s, [CX, CY, -4], [CX, CY, 3], 1.5, m.grip);
      const z = r(SC * 2 * (16 + t)) + 6;
      axeBit(s, z, r(SC * 12), r(SC * (5 + 2 * t)), -1, m);
      // A curved hook behind and a long spear point on top.
      for (let k = 0; k <= 6; k++) s.put(-1, r(CY + 2 + k), r(z + 5 + (k * k) / 6), m.core).put(0, r(CY + 2 + k), r(z + 5 + (k * k) / 6), m.core);
      bladeV3(s, z + r(SC * 12) + 1, r(SC * (14 + 2 * t)), SC * 2.2, m, (u) => (u < 0.25 ? 0.6 + u * 1.6 : 1), 0.4);
      if (m.trim) cylinder(s, [CX, CY, z - 3], [CX, CY, z - 1], 2.4, m.trim);
    },
    scepter(s, m, t) {
      cylinder(s, [CX, CY, -6], [CX, CY, 28], 1.3, m.gold);
      cylinder(s, [CX, CY, -3], [CX, CY, 3], 1.5, m.grip);
      const z = 29;
      ellipsoid(s, [CX, CY, z + 1], [SC * 3, SC * 3, 2], m.gold);
      ellipsoid(s, [CX, CY, z + 6], [SC * 2.4, SC * 2.4, SC * 2.8], m.gem); // the gem in its cage
      s.put(-3, r(CY) - 1, z + 7, C.WHITE);
      const ribs = t >= 2 ? 6 : 4;
      for (let k = 0; k < ribs; k++) { // a gold cage of ribs closing over the gem
        const a = (k / ribs) * Math.PI * 2, R = SC * 4.4;
        capsule(s, [CX + Math.cos(a) * 2, CY + Math.sin(a) * 2, z + 1], [CX + Math.cos(a) * R, CY + Math.sin(a) * R, z + 6], 0.8, 0.6, m.gold);
        capsule(s, [CX + Math.cos(a) * R, CY + Math.sin(a) * R, z + 6], [CX, CY, z + 13], 0.6, 0.5, m.gold);
      }
      if (t >= 2) for (let k = 0; k < 8; k++) { // rays round the cage
        const a = (k / 8) * Math.PI * 2 + 0.4;
        capsule(s, [CX, CY, z + 2], [CX + Math.cos(a) * SC * 8, CY + Math.sin(a) * SC * 8, z + 3], 0.9, 0.3, m.gold);
      }
      capsule(s, [CX, CY, z + 13], [CX, CY, z + 16 + t], 1, 0.4, m.gold); // a finial
      if (m.rune) cylinder(s, [CX, CY, z + 13], [CX, CY, z + 14], 1, m.rune);
    },
  };
}
