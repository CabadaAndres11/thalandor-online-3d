// v2 armour (Plan 6.3): the same sets as make_gear.mjs (one per class, three tiers, the
// same headgear, emblems and extras), sculpted as shells over the v2 body parts with
// texture and form, and grander with each tier: tier 2 trims and rivets, tier 3 gilding,
// glowing runes, gems with a highlight voxel and bigger silhouettes (winged pauldrons,
// longer capes, taller crowns). Each piece is drawn in its body part's pivot frame.
import { Shape, SHADE, LIGHT, TEX_D, TEX_L, GLOW } from "./vox.mjs";
import { ellipsoid, capsule, cylinder, roundBox, carve, tone, shadeByFacing, shellAround, noise3 } from "./sculpt.mjs";
import { headV2, torsoV2, hipsV2, upperArmV2, forearmV2, handV2, thighV2, shinV2, frontZ } from "./human_v2.mjs";
import { P, S, C, CLASS_SETS, cmats, tierPalette, PALETTE } from "./gear_style.mjs";
import { headLizardV2 } from "./races_v2.mjs";
import { deepHood, onBrimTop } from "./hood_v2.mjs";

export const BODY = {
  head: headV2(), torso: torsoV2(), hips: hipsV2(), arm: upperArmV2(), fore: forearmV2(),
  hand: handV2(), thigh: thighV2(), shin: shinV2(),
};

// --- Helpers -------------------------------------------------------------------------
const merge = (...shapes) => {
  const out = new Shape();
  for (const s of shapes) if (s) for (const [x, y, z, i] of s.cells.values()) out.put(x, y, z, i);
  return out;
};
const without = (s, part) => carve(s, (t) => { for (const [x, y, z] of part.cells.values()) t.put(x, y, z, 0); });
const recolor = (s, pred, idx) => { if (idx == null) return s; for (const v of s.cells.values()) if (pred(v[0], v[1], v[2], v[3])) v[3] = idx; return s; };
// A shell of `layers` voxels over a body part where filter holds, in idx.
const shellOn = (part, layers, idx, filter = () => true) => without(shellAround(part, layers, idx, filter), part);
// Puts idx on the front surface of s at (x, y), `out` voxels proud of it.
function onFront(s, x, y, idx, out = 1) {
  if (idx == null) return;
  const z = frontZ(s, x, y);
  if (z !== null) s.put(x, y, z + out, idx);
}
// The back surface (smallest z) at (x, y).
function backZ(s, x, y) {
  let best = null;
  for (const [cx, cy, cz] of s.cells.values()) if (cx === x && cy === y && (best === null || cz < best)) best = cz;
  return best;
}
const tinted = (i) => i === P || i === S;

// Texture (two or three tones mixed per voxel) and form (shade facing down, light on top)
// for the material's base colour; trims and runes drawn afterwards keep their colour.
function finish(s, m, seed) {
  const metal = !tinted(m.b) && [C.IRON, C.STEEL, C.DARK, C.CHAIN, C.CHAIN_D, C.X_B].includes(m.b);
  const tones = tinted(m.b) ? [m.b, TEX_D(m.b), TEX_L(m.b)] : [m.b, m.d, m.l];
  tone(s, m.b, tones, seed, metal ? [0.82, 0.08, 0.1] : [0.72, 0.16, 0.12]);
  const map = {};
  for (const i of tones) map[i] = { shade: m.d, light: m.l };
  return shadeByFacing(s, tones, map);
}
// A gem: its colour with one bright highlight voxel on the upper left.
function gem(s, x, y, z, m, size = 1) {
  for (let dx = 0; dx <= size; dx++) for (let dy = 0; dy <= size; dy++) s.put(x + dx, y + dy, z, m.gem);
  if (m.gem === C.GEM) s.put(x, y + size, z + 1, C.WHITE);
}

// The torso shell offset into the head frame (head pivot is 28 above the waist pivot).
const TORSO_TO_HEAD = -28;
function mantle(m, from = 20, to = 27) {
  const s = shellOn(BODY.torso, 2, m.b, (x, y) => y >= from && y <= to);
  const out = new Shape();
  for (const [x, y, z, i] of s.cells.values()) out.put(x, y + TORSO_TO_HEAD, z, i);
  return out;
}
// The face opening of hoods: the eyes, nose, mouth and cheeks stay bare.
const onFace = (x, y, z) => z >= 1 && y <= 13 && y >= -1 && x >= -6 && x <= 5;

// --- Class headgear --------------------------------------------------------------------
const HEADS = {
  // A deep hood under a gold circlet with a sun on the brow; tier 3 a tall mitre.
  cleric(t, m) {
    const s = deepHood(BODY.head, BODY.torso, m.b, C.EBONY_D, { seed: 101 + t });
    finish(s, m, 101 + t);
    recolor(s, (x, y, z, i) => onBrimTop(x, y, z) && i !== C.EBONY_D, m.acc); // circlet
    gem(s, -1, 15, (frontZ(s, -1, 15) ?? 9) + 1, m);
    if (t >= 2) recolor(s, (x, y, z, i) => z >= 6 && (x === -9 || x === 8) && y >= 0 && y <= 13 && i !== C.EBONY_D, m.trim);
    if (t >= 3) {
      const mitre = new Shape();
      for (let k = 0; k <= 13; k++) {
        const r = 6.4 - k * 0.32;
        cylinder(mitre, [-0.5, 19 + k, -1.5], [-0.5, 19 + k, -1.5], r, k % 4 === 3 ? m.l : m.b);
      }
      without(mitre, BODY.head);
      finish(mitre, m, 107);
      for (let y = 21; y <= 30; y++) onFront(mitre, -1, y, m.acc, 0), onFront(mitre, 0, y, m.acc, 0); // a gold cross
      for (const x of [-3, -2, 1, 2]) onFront(mitre, x, 27, m.acc, 0);
      onFront(mitre, -1, 24, m.rune), onFront(mitre, 0, 24, m.rune);
      for (const [x, y, z, i] of mitre.cells.values()) s.put(x, y, z, i);
    }
    return { s, hides: ["hair", "hair_cap"] };
  },
  // A wizard's hat with a wide brim and a band; taller, starred and glowing with the tier.
  mage(t, m) {
    const s = new Shape();
    const brim = 9 + 2 * t;
    cylinder(s, [-0.5, 16, -1.5], [-0.5, 17, -1.5], brim, m.b);
    const levels = 10 + 4 * t;
    for (let k = 0; k <= levels; k++) {
      const r = 8 * (1 - k / (levels + 3));
      const bend = k > levels * 0.6 ? (k - levels * 0.6) ** 1.6 * 0.35 : 0;
      cylinder(s, [-0.5, 18 + k, -1.5 - bend], [-0.5, 18 + k, -1.5 - bend], Math.max(r, 0.8), m.b);
    }
    without(s, BODY.head);
    finish(s, m, 111 + t);
    recolor(s, (x, y, z) => y === 16 && Math.hypot(x + 0.5, z + 1.5) > brim - 1.2, m.l); // brim edge catches the light
    recolor(s, (x, y) => y >= 18 && y <= 20, m.trim); // band
    for (const [x, y] of [[-1, 19], [0, 19], [-1, 18], [0, 18]]) onFront(s, x, y, m.acc, 0); // buckle
    if (t >= 2) for (const [x, y] of [[-1, 26], [0, 26], [-2, 25], [1, 25], [-1, 24], [0, 24]]) onFront(s, x, y, m.acc, 0); // a star
    if (t >= 3) {
      for (const [x, y] of [[-3, 29], [2, 31], [-2, 34]]) onFront(s, x, y, m.rune, 0);
      for (const [x, y, z] of [...s.cells.values()]) if (y === 18 + levels) s.put(x, y + 1, z, m.rune); // glowing tip
    }
    return { s, hides: ["hair"] };
  },
  // A ranger's deep hood with a long point; tier 2 a leather brow band, tier 3 a feather and glow.
  archer(t, m) {
    const hood = m.hood ?? P;
    const hm = { ...m, b: hood, d: SHADE(hood) === SHADE(P) && hood === P ? SHADE(P) : m.d, l: hood === P ? LIGHT(P) : m.l };
    const s = deepHood(BODY.head, BODY.torso, hood, C.EBONY_D, { seed: 121 + t });
    for (let k = 0; k < 4 + 2 * t; k++) ellipsoid(s, [-0.5, 16 - k, -10 - k * 0.8], [2.6 - k * 0.12, 2.2, 1.8], hood); // the point
    without(s, BODY.head);
    finish(s, hm, 121 + t);
    if (t >= 2) { recolor(s, (x, y, z, i) => y === 14 && z >= 6 && i !== C.EBONY_D, C.LEATHER); onFront(s, -1, 14, m.acc), onFront(s, 0, 14, m.acc); }
    if (t >= 3) {
      for (let k = 0; k < 12; k++) s.put(10 + (k > 8 ? 1 : 0), 13 + k, -2 - (k >> 2), k > 8 ? C.WHITE : S); // a feather
      onFront(s, 4, 15, m.rune), onFront(s, -5, 15, m.rune);
    }
    return { s, hides: ["hair", "hair_cap"] };
  },
  // A deep hood and a mask over the lower face; tier 2 a band, tier 3 small horns and glowing trim.
  assassin(t, m) {
    const hood = deepHood(BODY.head, BODY.torso, m.b, C.EBONY_D, { seed: 131 + t });
    const mask = shellOn(BODY.head, 1, m.d, (x, y, z) => y >= -1 && y <= 6 && z >= -2);
    const s = merge(hood, mask);
    finish(s, m, 131 + t);
    recolor(s, (x, y, z, i) => y === 6 && z >= 1 && i === m.d, m.trim); // mask edge
    if (t >= 2) recolor(s, (x, y, z, i) => y === 15 && z >= 6 && i !== C.EBONY_D, m.trim);
    if (t >= 3) {
      for (const dir of [-1, 1]) capsule(s, [dir > 0 ? 5 : -6, 18, -2], [dir > 0 ? 9 : -10, 24, -4], 1.3, 0.5, m.acc); // horns
      for (const x of [-9, 8]) onFront(s, x, 9, m.rune);
      without(s, BODY.head);
    }
    return { s, hides: ["hair", "hair_cap"] };
  },
};

// Plate head (the Warrior): a kettle helm (t1), a great helm with a visor slit and a gold
// cross (t2), a horned great helm with a crest and glowing eyes (t3).
function plateHead(t, m) {
  const s = shellOn(BODY.head, 2, m.b, (x, y, z) => (t === 1 ? y >= 9 || (z <= 0 && y >= 3) : y >= 1));
  if (t === 1) {
    cylinder(s, [-0.5, 11, -1], [-0.5, 11, -1], 10.5, m.b); // brim
    without(s, BODY.head);
    carve(s, (c) => cylinder(c, [-0.5, 11, -1], [-0.5, 11, -1], 7.4, 0));
    finish(s, m, 141);
    return { s, hides: ["hair", "hair_cap"] };
  }
  finish(s, m, 140 + t);
  recolor(s, (x, y, z) => z >= 3 && (y === 8 || y === 9) && x >= -6 && x <= 5, C.DARK_D); // visor slit
  for (let y = 2; y <= 14; y++) onFront(s, -1, y, m.trim, 0), onFront(s, 0, y, m.trim, 0); // the cross
  for (let x = -4; x <= 3; x++) if (x !== -1 && x !== 0) onFront(s, x, 11, m.trim, 0);
  for (let y = 2; y <= 6; y += 2) for (const x of [-4, -3, 2, 3]) onFront(s, x, y, C.DARK_D, 0); // breaths
  if (t >= 3) {
    recolor(s, (x, y, z, i) => i === C.DARK_D && (y === 8 || y === 9) && Math.abs(x + 0.5) >= 1.5 && Math.abs(x + 0.5) <= 4.5, m.rune); // glowing eyes
    for (let k = 0; k <= 14; k++) { // a red crest from the brow over to the nape
      const z = 5 - k, y = 18 + Math.round(Math.sin((k / 14) * Math.PI) * 3);
      for (const x of [-1, 0]) for (let h = 0; h <= 2; h++) s.put(x, y + h, z, h === 2 ? C.RED : C.RED_D);
    }
    for (const dir of [-1, 1]) { // horns sweeping up and out
      const x0 = dir > 0 ? 8 : -9;
      for (let k = 0; k <= 8; k++) {
        const r = 2.2 - k * 0.2;
        ellipsoid(s, [x0 + dir * k * 0.7, 12 + k * 1.1, -1 - k * 0.3], [r, r, r], k > 6 ? C.GOLD_L : m.trim);
      }
    }
    without(s, BODY.head);
  }
  return { s, hides: ["hair", "hair_cap"] };
}

// --- Extras of tiers 2 and 3 -----------------------------------------------------------
// A cape hanging from the shoulders down the back (torso part): longer and wider with the
// tier, folds, clasps with gems; tier 3 a gilded hem and runes. `tattered` cuts its hem.
function cape(t, m, tattered = false) {
  const s = new Shape();
  const bottom = t >= 3 ? -40 : -24;
  for (let y = 24; y >= bottom; y--) {
    const half = 11 + Math.min(4, Math.floor((24 - y) / 12));
    for (let x = -half - 1; x <= half; x++) {
      if (tattered && y < bottom + 6 && noise3(x, y, 0, 7) < 0.35) continue;
      const bz = y >= 0 ? (backZ(BODY.torso, x, Math.min(y, 26)) ?? -7) : -8;
      const fold = Math.sin((x + 0.5) * 0.9) * 0.9;
      const z = Math.min(bz, -7) - 1 - (y < 6 ? Math.round(1 + fold) : 0);
      s.put(x, y, z, m.alt);
      s.put(x, y, z - 1, fold > 0.3 ? m.alt_d : m.alt);
    }
  }
  without(s, BODY.torso);
  for (const v of s.cells.values()) if (v[3] === m.alt && noise3(v[0], v[1], v[2], 9) < 0.15) v[3] = m.alt_d;
  for (const x of [-11, 10]) { // clasps at the shoulders
    roundBox(s, [x - 1, 22, -9], [x + 1, 25, -7], 0.6, m.trim);
    gem(s, x, 23, -6, m);
  }
  if (t >= 3) {
    recolor(s, (x, y) => y <= bottom + 1, m.trim);
    for (let y = bottom + 6; y < 18; y += 8) for (const x of [-1, 0]) s.put(x, y, (backZ(s, x, y) ?? -10) - 1, m.rune);
  }
  return s;
}

// A glowing halo ring behind the head (head part), with trim studs.
function halo(m) {
  const s = new Shape();
  const cy = 18, z = -11, R = 13;
  for (let a = 0; a < 160; a++) {
    const ang = (a / 160) * Math.PI * 2;
    for (const dr of [0, 0.9]) s.put(Math.round(Math.cos(ang) * (R + dr) - 0.5), Math.round(Math.sin(ang) * (R + dr)) + cy, z, GLOW);
  }
  for (let k = 0; k < 8; k++) {
    const ang = (k / 8) * Math.PI * 2;
    const x = Math.round(Math.cos(ang) * (R + 3) - 0.5), y = Math.round(Math.sin(ang) * (R + 3)) + cy;
    roundBox(s, [x - 1, y - 1, z], [x, y, z], 0.4, m.trim);
  }
  return s;
}

// A floating crown of glowing runes circling a hat (head part).
function runeCrown(y) {
  const s = new Shape();
  for (let a = 0; a < 12; a++) {
    const ang = (a / 12) * Math.PI * 2;
    const x = Math.round(Math.cos(ang) * 14 - 0.5), z = Math.round(Math.sin(ang) * 14 - 1.5);
    roundBox(s, [x, y + (a % 2) * 2, z], [x + 1, y + 2 + (a % 2) * 2, z], 0, GLOW);
  }
  return s;
}

// A crown of golden leaves with antlers and glowing buds (head part).
function leafCrown(m) {
  const s = shellOn(BODY.head, 1, m.trim, (x, y) => y === 15 || y === 16);
  for (let k = 0; k < 12; k++) {
    const ang = (k / 12) * Math.PI * 2;
    const x = Math.round(Math.cos(ang) * 7 - 0.5), z = Math.round(Math.sin(ang) * 7.5 - 1.5);
    capsule(s, [x, 17, z], [x * 1.1, 20 + (k % 2) * 2, z * 1.1], 0.9, 0.4, C.GOLD);
  }
  for (const dir of [-1, 1]) for (let k = 0; k < 9; k++) s.put((dir > 0 ? 8 : -9) + dir * (k >> 1), 15 + k, -3 - (k >> 2), k === 8 ? GLOW : C.GOLD); // antlers
  s.put(-1, 18, 7, GLOW).put(0, 18, 7, GLOW);
  return without(s, BODY.head);
}

// Crystal shards hovering over a shoulder (arm part), `outer` +1 left, -1 right.
function shards(outer) {
  const s = new Shape();
  const x = outer > 0 ? 10 : -11;
  for (const [dx, dy, h, r] of [[0, 8, 9, 1.6], [outer * 3, 14, 6, 1.2], [-outer * 2, 18, 4, 1]]) {
    capsule(s, [x + dx, dy, 0], [x + dx, dy + h, 0], r, 0.3, C.CRYSTAL);
    s.put(x + dx, dy + h + 1, 0, GLOW);
  }
  return s;
}

// Sunburst rays fanning out above a shoulder (arm part).
function rays(outer, m) {
  const s = new Shape();
  for (let k = 0; k < 5; k++) {
    const ang = (0.25 + k * 0.28) * Math.PI;
    const x0 = outer > 0 ? 6 : -7;
    const dx = Math.cos(ang) * outer, dy = Math.sin(ang);
    capsule(s, [x0, 4, -1], [x0 + dx * 12, 4 + dy * 12, -1], 1.1, 0.4, m.trim);
    s.put(Math.round(x0 + dx * 13), Math.round(4 + dy * 13), -1, GLOW);
  }
  return s;
}

function extras(cls, t, m) {
  const out = { chest: [], head: [], shoulders: [] };
  if (t < 2) return out;
  const cm = cls === "assassin" ? { ...m, alt: m.trim, alt_d: m.d } : m;
  if (cls !== "archer" || t >= 3) out.chest.push(["cape", "torso", cape(t, cm, cls === "assassin")]);
  if (t >= 3) {
    if (cls === "cleric") out.head.push(["halo", "head", halo(m)]);
    if (cls === "mage") out.head.push(["runes", "head", runeCrown(22)]);
    if (cls === "archer") out.head.push(["leaves", "head", leafCrown(m)]);
    if (cls === "mage") out.shoulders.push(["shards_l", "arm_left", shards(1)], ["shards_r", "arm_right", shards(-1)]);
    if (cls === "cleric") out.shoulders.push(["rays_l", "arm_left", rays(1, m)], ["rays_r", "arm_right", rays(-1, m)]);
  }
  return out;
}

// --- Chest emblems (on the chest piece's front) ------------------------------------------
const EMBLEMS = {
  warrior(s, t, m) { // a cross
    for (let y = 10; y <= 18; y++) for (const x of [-1, 0]) onFront(s, x, y, m.trim);
    for (let x = -4; x <= 3; x++) for (const y of [15, 16]) onFront(s, x, y, m.trim);
  },
  cleric(s, t, m) { // a gold sun
    for (let x = -3; x <= 2; x++) for (let y = 12; y <= 17; y++) if (Math.hypot(x + 0.5, y - 14.5) <= 2.8) onFront(s, x, y, m.acc);
    for (let k = 0; k < 8; k++) {
      const a = (k / 8) * Math.PI * 2;
      onFront(s, Math.round(Math.cos(a) * 5 - 0.5), Math.round(14.5 + Math.sin(a) * 5), m.acc);
    }
    if (t >= 3) for (const [x, y] of [[-1, 14], [0, 14], [-1, 15], [0, 15]]) onFront(s, x, y, GLOW, 2);
  },
  mage(s, t, m) { // an arcane star
    for (let k = 0; k < 10; k++) {
      const a = (k / 10) * Math.PI * 2 + Math.PI / 2;
      const r = k % 2 ? 2.2 : 5;
      onFront(s, Math.round(Math.cos(a) * r - 0.5), Math.round(15 + Math.sin(a) * r), m.trim);
    }
    for (const [x, y] of [[-1, 15], [0, 15], [-1, 14], [0, 14]]) onFront(s, x, y, t >= 3 ? GLOW : t >= 2 ? m.acc : m.trim);
  },
  archer(s, t, m) { // a leather baldric across the mail and a buckle
    for (let i = 0; i <= 20; i++) for (const d of [0, 1]) onFront(s, -11 + i, 22 - i + d, C.LEATHER);
    onFront(s, -1, 11, m.acc, 2), onFront(s, 0, 11, m.acc, 2);
  },
  assassin(s, t, m) { // crossed straps and a dagger sheath
    for (let i = 0; i <= 18; i++) for (const d of [0, 1]) onFront(s, -10 + i, 22 - i + d, m.trim), onFront(s, 9 - i, 22 - i + d, m.trim);
    for (let y = 2; y <= 9; y++) for (const x of [6, 7]) onFront(s, x, y, C.LEATHER_D);
  },
};

// --- Armour by slot --------------------------------------------------------------------
const ARMOR = {
  shoulder(kind, t, m, outer) {
    const big = t - 1;
    const xo = outer > 0 ? 1.5 : -2.5; // over the outside of the shoulder
    const s = new Shape();
    if (kind === "cloth" || kind === "leather") {
      ellipsoid(s, [xo, 1, -0.5], [4.6 + big, 3.4 + big * 0.6, 5 + big * 0.4], m.b); // a padded pad
      carve(s, (c) => roundBox(c, [-20, -20, -20], [20, -2, 20], 0, 0));
      without(s, BODY.arm);
      finish(s, m, 151 + t + outer);
      recolor(s, (x, y) => y === -2, m.trim);
      if (kind === "leather") for (const z of [-3, 2]) s.put(outer > 0 ? 5 + big : -6 - big, 0, z, m.acc);
      if (t >= 3) for (let z = -3; z <= 2; z += 2) for (let y = -6; y <= -3; y++) s.put(outer > 0 ? 5 + big : -6 - big, y, z, m.rune);
      return s;
    }
    // Mail and plate: a dome over lames down the outside; tier 2 gold rims; tier 3 spikes
    // (mail) or wings of stacked plates (plate).
    ellipsoid(s, [xo, 1 + big * 0.5, -0.5], [5 + big, 4 + big, 5.4 + big], m.b);
    carve(s, (c) => roundBox(c, [-20, -20, -20], [20, -1, 20], 0, 0));
    for (let k = 0; k < 2 + big; k++) {
      const y = -2 - k * 3;
      for (const [x, , z] of shellAround(BODY.arm, 1 + (k === 0 ? 1 : 0), 0, (xx, yy) => yy === y).cells.values()) {
        if (outer * (x + 0.5) > -1) s.put(x, y, z, m.b).put(x, y - 1, z, m.d);
      }
    }
    without(s, BODY.arm);
    finish(s, m, 161 + t + outer);
    if (t >= 2) recolor(s, (x, y, z) => y >= -1 && (z === Math.round(-6.5 - big) || z === Math.round(5.5 + big) || Math.abs(z + 0.5) >= 4.5 + big), m.trim);
    if (t >= 3) {
      const xs = outer > 0 ? 6 : -7;
      if (kind === "plate") { // wings: plates fanning up and outwards like feathers
        for (let k = 0; k < 5; k++) {
          const len = 10 - k;
          const ang = (0.42 + k * 0.1) * Math.PI;
          const ax = xs, ay = 4 + k, az = -5 + k * 2.2;
          const bx = ax + Math.cos(ang) * len * outer, by = ay + Math.sin(ang) * len;
          capsule(s, [ax, ay, az], [bx, by, az - 1], 1.6, 0.7, k % 2 ? m.trim : m.b);
          s.put(Math.round(bx), Math.round(by) + 1, Math.round(az - 1), k === 2 ? C.GOLD_L : m.trim);
        }
        without(s, BODY.arm);
      } else {
        for (const z of [-4, 3]) capsule(s, [xs, 4, z], [xs + outer * 2, 11, z], 1.2, 0.3, m.trim);
      }
      s.put(outer > 0 ? 7 + big : -8 - big, 0, -1, m.rune);
    }
    return s;
  },

  chest(kind, t, m) {
    const plate = kind === "plate";
    const s = shellOn(BODY.torso, plate ? 2 : 1, m.b, (x, y) => y >= 0 && y <= (plate ? 24 : 25));
    carve(s, (c) => { for (let y = 21; y <= 30; y++) for (let x = -3; x <= 2; x++) for (let z = 0; z <= 12; z++) if (Math.abs(x + 0.5) <= (y - 19) / 2) c.put(x, y, z, 0); }); // collar V
    finish(s, m, 171 + t);
    if (kind === "cloth") {
      for (let y = 0; y <= 19; y++) onFront(s, -1, y, m.trim, 0), onFront(s, 0, y, m.trim, 0);
      recolor(s, (x, y) => y === 5 || y === 6, m.acc); // sash
      if (t >= 2) for (let y = 2; y <= 18; y += 4) onFront(s, -2, y, m.acc, 0), onFront(s, 1, y, m.acc, 0);
      if (t >= 3) {
        const collar = shellOn(BODY.torso, 2, m.trim, (x, y, z) => y >= 22 && y <= 28 && z <= 0);
        for (const [x, y, z, i] of collar.cells.values()) s.put(x, y, z, i);
        for (const y of [4, 10, 16]) onFront(s, -1, y, m.rune), onFront(s, 0, y, m.rune);
      }
      return s;
    }
    if (kind === "leather") {
      for (let y = 2; y <= 19; y += 3) onFront(s, -1, y, m.trim), onFront(s, 0, y, m.trim); // laces
      recolor(s, (x, y) => y === 4 || y === 5, m.d); // belt
      onFront(s, -1, 4, m.acc), onFront(s, 0, 4, m.acc), onFront(s, -1, 5, m.acc), onFront(s, 0, 5, m.acc);
      if (t >= 2) recolor(s, (x, y) => y >= 23, m.trim);
      if (t >= 3) for (const [x, y] of [[-8, 14], [6, 14], [-8, 8], [6, 8]]) {
        for (const [dx, dy] of [[0, 0], [1, 0], [0, 1], [1, 1]]) onFront(s, x + dx, y + dy, m.acc, 0);
        onFront(s, x, y + 1, m.rune);
      }
      return s;
    }
    if (kind === "mail") {
      recolor(s, (x, y, z, i) => (x + y) % 2 === 0 && i !== m.d, m.l); // rings
      recolor(s, (x, y) => y === 6 || y === 7, C.LEATHER); // belt
      onFront(s, -1, 6, m.acc), onFront(s, 0, 6, m.acc);
      if (t >= 2) { // a surcoat panel down the front with a gem
        for (let y = 8; y <= 19; y++) for (let x = -5; x <= 4; x++) onFront(s, x, y, m.trim, 0);
        gem(s, -1, 13, (frontZ(s, -1, 13) ?? 8) + 1, m);
      }
      if (t >= 3) { for (let x = -5; x <= 4; x++) onFront(s, x, 19, m.acc, 0); onFront(s, -1, 16, m.rune), onFront(s, 0, 16, m.rune); }
      return s;
    }
    // Plate: a cuirass with a ridge and plackart lines; tier 2 a gold collar band; tier 3 a
    // glowing sun over the heart, rivets and a gorget.
    for (let y = 4; y <= 20; y++) onFront(s, -1, y, m.l, 0), onFront(s, 0, y, m.l, 0); // ridge
    recolor(s, (x, y) => y === 3 || y === 7, m.d); // plackart lines
    if (t >= 2) recolor(s, (x, y) => y >= 23, m.trim);
    if (t >= 3) {
      for (const [x, y] of [[-9, 21], [8, 21], [-9, 9], [8, 9]]) onFront(s, x, y, C.GOLD_L);
      const gorget = shellOn(BODY.torso, 2, m.b, (x, y) => y >= 25 && y <= 27);
      finish(gorget, m, 179);
      recolor(gorget, (x, y) => y === 27, m.trim);
      for (const [x, y, z, i] of gorget.cells.values()) s.put(x, y, z, i);
    }
    return s;
  },

  // The Mage's robe below the waist (hips part): to the shins, flaring, a hem in the trim
  // colour, a front panel and (tier 3) glowing runes along the hem.
  robe(t, m) {
    const s = new Shape();
    const top = 7, bottom = -36;
    for (let y = top; y >= bottom; y--) {
      const k = (top - y) / (top - bottom);
      const rx = 11.6 + k * 4.4, rz = 8.2 + k * 3.4;
      for (let x = -17; x <= 16; x++) for (let z = -13; z <= 13; z++) {
        const d = ((x + 0.5) / rx) ** 2 + ((z + 0.5) / rz) ** 2;
        if (d <= 1 && d >= ((rx - 1.7) / rx) ** 2) s.put(x, y, z, m.b);
      }
    }
    without(s, BODY.hips);
    finish(s, m, 181 + t);
    recolor(s, (x, y, z) => y < top - 2 && Math.sin(Math.atan2(z + 0.5, x + 0.5) * 9) > 0.6, m.d); // folds
    recolor(s, (x, y) => y <= bottom + 1, m.trim); // hem
    recolor(s, (x, y, z) => z >= 6 && Math.abs(x + 0.5) <= 1.5, m.trim); // front panel
    if (t >= 2) recolor(s, (x, y, z) => z >= 6 && Math.abs(x + 0.5) <= 1.5 && y % 6 === 0, m.acc);
    if (t >= 3) recolor(s, (x, y, z) => y === bottom + 3 && (x & 1) === 0 && z >= 0, m.rune);
    return s;
  },
  // The Mage's upper sleeve (arm part)...
  sleeve(t, m) {
    const s = shellOn(BODY.arm, 1, m.b, (x, y) => y >= -18);
    ellipsoid(s, [-0.5, 1, -0.5], [4.6, 2.6, 4.6], m.b); // over the shoulder
    without(s, BODY.arm);
    finish(s, m, 191 + t);
    if (t >= 2) recolor(s, (x, y) => y === -8, m.acc);
    return s;
  },
  // ...and the long bell cuff hanging past the wrist (forearm part).
  bell(t, m) {
    const s = new Shape();
    for (let y = 0; y >= -22; y--) {
      const r = 4 + (y < -10 ? 2.2 : y < -4 ? 1.1 : 0) + (y < -16 ? 0.8 : 0);
      for (let x = -8; x <= 7; x++) for (let z = -8; z <= 7; z++) {
        const d = Math.hypot(x + 0.5, z + 0.5);
        if (d <= r && d >= r - 1.4) s.put(x, y, z, m.b);
      }
    }
    without(s, BODY.fore);
    finish(s, m, 195 + t);
    recolor(s, (x, y) => y <= -20, m.trim);
    if (t >= 3) for (const [x, z] of [[-6, -1], [5, -1]]) s.put(x, -18, z, m.rune);
    return s;
  },

  // The chest piece over the hips: a skirt (cloth, mail) or tassets (plate).
  skirt(kind, t, m) {
    const long = (kind === "cloth" ? 3 + t : kind === "mail" ? 2 + t : t) * 2;
    const s = new Shape();
    for (let y = 7; y >= -4 - long; y--) {
      const rx = 11 + Math.max(0, -y) * 0.12, rz = 8 + Math.max(0, -y) * 0.1;
      for (let x = -14; x <= 13; x++) for (let z = -11; z <= 10; z++) {
        const d = ((x + 0.5) / rx) ** 2 + ((z + 0.5) / rz) ** 2;
        if (d <= 1 && d >= ((rx - 1.4) / rx) ** 2) s.put(x, y, z, m.b);
      }
    }
    carve(s, (c) => roundBox(c, [-2, -20, -14], [1, -5, 14], 0, 0)); // split for the legs
    without(s, BODY.hips);
    finish(s, m, 201 + t);
    recolor(s, (x, y) => y === -4 - long, m.trim);
    if (kind === "plate") recolor(s, (x, y) => y < 2 && (y + 20) % 4 === 0, m.d); // tasset lames
    if (t >= 3 && m.rune) for (const x of [-8, 7]) s.put(x, -2 - long, (frontZ(s, x, -2 - long) ?? 8) + 1, m.rune);
    return s;
  },

  glove(kind, t, m) {
    const s = shellOn(BODY.hand, 1, m.b);
    finish(s, m, 211 + t);
    if (kind === "plate" || kind === "mail") recolor(s, (x, y, z) => z >= 3 && (y === -1 || y === -4 || y === -7), m.d); // knuckle plates
    if (t >= 3 && m.rune) s.put(-4, -3, 2, m.rune).put(3, -3, 2, m.rune);
    return s;
  },

  cuff(kind, t, m) {
    const flare = kind === "plate" ? t : kind === "mail" ? 1 : 0;
    const top = -6 - 2 * t;
    const s = shellOn(BODY.fore, 1, m.b, (x, y) => y <= top && y >= -17);
    for (let y = -17; y >= -18; y--) cylinder(s, [-0.5, y, -0.5], [-0.5, y, -0.5], 4.2 + flare * 0.6, m.trim);
    without(s, BODY.fore);
    carve(s, (c) => cylinder(c, [-0.5, -18, -0.5], [-0.5, -17, -0.5], 2.6, 0));
    finish(s, m, 221 + t);
    recolor(s, (x, y) => y === top, m.l);
    if (t >= 2) for (const [x, y, z] of [...s.cells.values()]) if (y === -12 && z >= 2) s.put(x, y, z, m.acc);
    if (t >= 3 && m.rune) s.put(3, -10, -1, m.rune).put(-4, -10, -1, m.rune);
    return s;
  },

  leg(kind, t, m) {
    const s = shellOn(BODY.thigh, 1, m.b, (x, y) => y <= 0);
    if (kind === "plate" || kind === "mail") ellipsoid(s, [0, -18, 3.6], [4, 3.4, 2.2], kind === "plate" ? m.l : m.d); // knee cop
    without(s, BODY.thigh);
    finish(s, m, 231 + t);
    if (kind === "plate") onFront(s, 0, -18, t >= 2 ? m.trim : m.d);
    if (kind !== "plate" && kind !== "mail") recolor(s, (x, y) => y === -2, m.trim);
    if (kind === "leather") recolor(s, (x, y) => y === -10, m.d);
    if (t >= 2) recolor(s, (x, y, z) => x >= 4 && z >= 0 && y <= -4 && y >= -16, m.acc);
    if (t >= 3 && m.rune) s.put(5, -8, 1, m.rune).put(5, -12, 1, m.rune);
    return s;
  },

  boot(kind, t, m) {
    const top = kind === "cloth" ? -18 : t >= 2 ? -6 : -8;
    const s = shellOn(BODY.shin, 1, m.b, (x, y) => y <= top && y >= -26);
    if (kind === "plate") roundBox(s, [-4, -26, 5], [3, -23, 9], 1.2, m.b); // a pointed sabaton
    without(s, BODY.shin);
    finish(s, m, 241 + t);
    recolor(s, (x, y) => y === -26 || y === -27, kind === "plate" ? m.d : C.LEATHER_D); // sole
    recolor(s, (x, y) => y === top, kind === "cloth" ? m.trim : m.l);
    if (kind === "plate") recolor(s, (x, y, z) => y < top - 1 && y > -21 && (y & 1) === 0 && z >= 2, m.d); // lames
    if (t >= 2) recolor(s, (x, y, z) => y === top - 2 && z >= 1, m.acc);
    if (t >= 3 && m.rune) for (const x of [-1, 0]) onFront(s, x, top - 4, m.rune);
    return s;
  },
};

// The assassin's hood and mask drawn on the lizard head (Plan 8.1.1): the hood over the
// skull behind the eyes, the mask over the snout and jaw (the eyes and nostrils bare).
export const LIZARD_HEAD = headLizardV2();
function assassinLizard(t, m) {
  const hood = shellOn(LIZARD_HEAD, 2, m.b, (x, y, z) => z <= 1 && y >= 2);
  const mask = shellOn(LIZARD_HEAD, 1, m.d, (x, y, z) => z >= 2 && y >= 1 && y <= 6);
  const s = merge(mantle(m), hood, mask);
  finish(s, m, 131 + t);
  recolor(s, (x, y, z, i) => y === 6 && z >= 2 && i === m.d, m.trim); // mask edge
  if (t >= 2) recolor(s, (x, y, z) => y === 13 && z <= 1, m.trim);
  if (t >= 3) for (const dir of [-1, 1]) capsule(s, [dir > 0 ? 4 : -5, 15, -4], [dir > 0 ? 8 : -9, 21, -6], 1.3, 0.5, m.acc);
  return without(s, LIZARD_HEAD);
}

// Every class × tier piece, with its part and palette: {id: {shape, part, palette}}.
export function armorV2() {
  const out = {};
  for (const t of [1, 2, 3]) {
    for (const cls of Object.keys(CLASS_SETS)) {
      const kind = CLASS_SETS[cls].kind;
      const m = cmats(cls, t);
      const palette = tierPalette(cls, t);
      const id = (slot) => `${cls}_${slot}_t${t}`;
      const add = (name, shape, part) => { out[name] = { shape, part, palette }; };
      const ex = extras(cls, t, m);
      const head = HEADS[cls] ? HEADS[cls](t, m) : plateHead(t, m);
      add(id("head"), head.s, "head");
      if (cls === "assassin") out[`${id("head")}_lizard`] = { shape: assassinLizard(t, m), part: "head", palette, body: LIZARD_HEAD, like: id("head") };
      for (const [suffix, part, shape] of ex.head) add(`${id("head")}_${suffix}`, shape, part);
      add(`${id("shoulders")}_l`, ARMOR.shoulder(kind, t, m, 1), "arm_left");
      add(`${id("shoulders")}_r`, ARMOR.shoulder(kind, t, m, -1), "arm_right");
      for (const [suffix, part, shape] of ex.shoulders) add(`${id("shoulders")}_${suffix}`, shape, part);
      const chest = ARMOR.chest(kind, t, m);
      EMBLEMS[cls](chest, t, m);
      add(id("chest"), chest, "torso");
      add(`${id("chest")}_skirt`, cls === "mage" ? ARMOR.robe(t, m) : ARMOR.skirt(kind, t, m), "hips");
      if (cls === "mage") {
        for (const [side, x] of [["left", "l"], ["right", "r"]]) {
          add(`${id("chest")}_sleeve_${x}`, ARMOR.sleeve(t, m), `arm_${side}`);
          add(`${id("chest")}_bell_${x}`, ARMOR.bell(t, m), `forearm_${side}`);
        }
      }
      for (const [suffix, part, shape] of ex.chest) add(`${id("chest")}_${suffix}`, shape, part);
      for (const side of ["left", "right"]) {
        add(`${id("hands")}_${side[0]}`, ARMOR.glove(kind, t, m), `hand_${side}`);
        add(`${id("hands")}_cuff_${side[0]}`, ARMOR.cuff(kind, t, m), `forearm_${side}`);
        add(`${id("legs")}_${side[0]}`, ARMOR.leg(kind, t, m), `leg_${side}`);
        add(`${id("feet")}_${side[0]}`, ARMOR.boot(kind, t, m), `shin_${side}`);
      }
    }
  }
  return out;
}

// --- Story characters' own outfits (Plan 8.3e) -----------------------------------------
// Mira, after the user's reference: a long black cloak lined in crimson with its hood down,
// a silver brooch with a red gem, dark leather armour with sleeves, brown belts and tall
// laced boots. Pieces hang from the body parts like the equipment's.
const MIRA = { b: C.BLACK_LEATHER, d: C.BLACK_LEATHER_D, l: C.BLACK_LEATHER, trim: C.LEATHER, acc: C.BRONZE, gem: C.GEM, rune: null };
const CLOAK = 77, CLOAK_D = 78; // black leather tones read as heavy black wool at this size

function miraCloak() {
  const s = new Shape();
  const bottom = -44;
  for (let y = 25; y >= bottom; y--) {
    const half = 11 + Math.min(6, Math.floor((25 - y) / 9));
    for (let x = -half - 1; x <= half; x++) {
      const bz = y >= 0 ? (backZ(BODY.torso, x, Math.min(y, 26)) ?? -7) : -8;
      const fold = Math.sin((x + 0.5) * 0.8) * 0.9;
      const z = Math.min(bz, -7) - 1 - (y < 8 ? Math.round(1 + fold) : 0);
      s.put(x, y, z, fold > 0.35 ? CLOAK_D : CLOAK);
      s.put(x, y, z + 1, C.RED_D); // the crimson lining, seen from the sides and under the hem
    }
    // The open front: the cloak falls forward past the arms, its lining showing.
    if (y < 22) {
      for (const side of [-1, 1]) {
        const x = side > 0 ? half + 1 : -half - 2;
        for (let z = -9; z <= 2 + Math.min(4, Math.floor((22 - y) / 10)); z++) {
          s.put(x, y, z, CLOAK);
          s.put(x - side, y, z, C.RED);
        }
      }
    }
  }
  recolor(s, (x, y) => y <= bottom + 1, C.RED_D); // a red hem edge
  without(s, BODY.torso);
  for (const v of s.cells.values()) if (v[3] === CLOAK && noise3(v[0], v[1], v[2], 31) < 0.12) v[3] = CLOAK_D;
  return s;
}

// The hood down: a heavy fold on the shoulders and the upper back, red inside, with the brooch.
function miraHood() {
  const s = new Shape();
  for (let y = 20; y <= 30; y++) {
    for (let x = -12; x <= 11; x++) {
      const bz = backZ(BODY.torso, x, Math.min(y, 26)) ?? -7;
      const thick = y >= 24 ? 4 : 2;
      for (let k = 1; k <= thick; k++) s.put(x, y, Math.min(bz, -6) - k, k === 1 ? C.RED_D : CLOAK);
    }
  }
  const collar = shellOn(BODY.torso, 2, CLOAK, (x, y) => y >= 23 && y <= 27);
  for (const v of collar.cells.values()) s.put(v[0], v[1], v[2], v[2] > 0 && v[1] === 27 ? C.RED : CLOAK);
  // The brooch: a silver knot with a red gem, at the collar's front.
  const fz = (frontZ(BODY.torso, -1, 24) ?? 4) + 2;
  for (const [x, y] of [[-3, 24], [-2, 25], [-1, 25], [0, 25], [1, 24], [-3, 23], [1, 23], [-2, 22], [0, 22], [-1, 22]]) s.put(x, y, fz, C.STEEL_L);
  s.put(-1, 24, fz, C.GEM).put(-1, 23, fz, C.GEM).put(-1, 24, fz + 1, C.WHITE);
  return without(s, BODY.torso);
}

function miraChest() {
  const s = ARMOR.chest("leather", 2, MIRA);
  // A woman's cuirass (Plan 8.3e): shaped over the chest like the body's own.
  const bust = new Shape();
  for (const x of [-4.5, 3.5]) ellipsoid(bust, [x, 17.0, 7.4], [3.8, 3.3, 3.0], MIRA.b);
  for (const v of bust.cells.values()) s.put(v[0], v[1], v[2], v[1] <= 15 ? MIRA.d : MIRA.b);
  // Belts: two brown belts at the waist with bronze buckles, a pouch on the right hip.
  for (const y of [1, 2, 4]) recolor(s, (x, yy) => yy === y, C.LEATHER);
  for (const [x, y] of [[-1, 2], [0, 2], [-1, 4]]) onFront(s, x, y, C.BRONZE);
  for (let y = 7; y <= 18; y += 3) recolor(s, (x, yy, z) => yy === y && z >= 2 && Math.abs(x + 0.5) < 5, MIRA.d); // quilting
  return s;
}

function miraSleeve() {
  const s = shellOn(BODY.arm, 1, MIRA.b, (x, y) => y >= -18);
  ellipsoid(s, [-0.5, 1, -0.5], [4.4, 2.4, 4.4], MIRA.b);
  without(s, BODY.arm);
  finish(s, MIRA, 301);
  return s;
}

function miraForearm() {
  const s = shellOn(BODY.fore, 1, MIRA.b, (x, y) => y >= -18);
  without(s, BODY.fore);
  finish(s, MIRA, 303);
  for (const y of [-6, -10, -14]) recolor(s, (x, yy) => yy === y, C.LEATHER); // straps
  return s;
}

function miraBoot() {
  const s = shellOn(BODY.shin, 1, C.LEATHER_D, (x, y) => y <= 2 && y >= -26);
  without(s, BODY.shin);
  finish(s, { b: C.LEATHER_D, d: C.BLACK_LEATHER, l: C.LEATHER }, 305);
  recolor(s, (x, y) => y === -26 || y === -27, C.BLACK_LEATHER_D);
  for (let y = -20; y <= 0; y += 3) recolor(s, (x, yy, z) => yy === y && z >= 2 && Math.abs(x + 0.5) < 1, C.PAPER_D); // laces
  recolor(s, (x, y) => y === 2, C.LEATHER);
  return s;
}

// Court clothes of the palace's nobles (2026-11-27), in their own colours (P and S tints): a
// gown with a fitted bodice, puffed sleeves and a full skirt to the floor for the ladies; a
// doublet with gold buttons, a sash and a short shoulder cape for the lords; tall boots.
const NOBLE = { b: P, d: SHADE(P), l: LIGHT(P), trim: C.GOLD, acc: C.GOLD_L, gem: C.GEM, rune: null };

function nobleBodice(bust) {
  const s = ARMOR.chest("cloth", 2, NOBLE);
  if (bust) {
    const b = new Shape();
    for (const x of [-4.5, 3.5]) ellipsoid(b, [x, 17.0, 7.4], [3.8, 3.3, 3.0], P);
    for (const v of b.cells.values()) s.put(v[0], v[1], v[2], v[1] <= 15 ? SHADE(P) : P);
  }
  recolor(s, (x, y, z) => y >= 22 && y <= 23 && z >= 2, C.GOLD); // the neckline
  recolor(s, (x, y, z) => z >= 3 && Math.abs(x + 0.5) <= 0.5 && y <= 21, S); // the front lacing
  recolor(s, (x, y) => y <= 1, C.GOLD); // the waist
  return s;
}

function nobleGownSkirt() {
  const s = new Shape();
  const top = 6, bottom = -44;
  for (let y = top; y >= bottom; y--) {
    const k = (top - y) / (top - bottom);
    const rx = 11 + k * 8, rz = 8 + k * 6.5;
    for (let x = -21; x <= 20; x++) for (let z = -16; z <= 16; z++) {
      const d = ((x + 0.5) / rx) ** 2 + ((z + 0.5) / rz) ** 2;
      if (d <= 1 && d >= ((rx - 1.7) / rx) ** 2) s.put(x, y, z, P);
    }
  }
  without(s, BODY.hips);
  finish(s, NOBLE, 311);
  recolor(s, (x, y, z) => y < top - 3 && Math.sin(Math.atan2(z + 0.5, x + 0.5) * 11) > 0.65, SHADE(P)); // the folds
  recolor(s, (x, y) => y <= bottom + 2, S); // a hem in the second colour
  recolor(s, (x, y) => y === bottom + 3, C.GOLD);
  recolor(s, (x, y, z) => z >= 7 && Math.abs(x + 0.5) <= 2.5 && y < top - 2, S); // the front panel
  return s;
}

function nobleSleeve() {
  const s = shellOn(BODY.arm, 1, P, (x, y) => y >= -18);
  ellipsoid(s, [-0.5, -2, -0.5], [5.2, 5, 5.2], P); // the puff at the shoulder
  without(s, BODY.arm);
  finish(s, NOBLE, 313);
  recolor(s, (x, y) => y === -6 || y === -5, C.GOLD);
  for (let a = 0; a < 8; a++) recolor(s, (x, y, z) => y > -6 && Math.round(Math.atan2(z + 0.5, x + 0.5) * 4 / Math.PI) === a - 4 && a % 2 === 0, S); // slashes showing the lining
  return s;
}

function nobleCuff() {
  const s = shellOn(BODY.fore, 1, P, (x, y) => y >= -18);
  without(s, BODY.fore);
  finish(s, NOBLE, 315);
  recolor(s, (x, y) => y <= -16, C.WHITE); // lace at the wrist
  return s;
}

function nobleDoublet() {
  const s = nobleBodice(false);
  for (let y = 3; y <= 20; y += 3) onFront(s, -1, y, C.GOLD_L); // the buttons
  recolor(s, (x, y, z) => z >= 1 && Math.abs((x + 0.5) * 0.9 - (y - 12)) <= 1.3, S); // the sash, shoulder to hip
  return s;
}

function nobleCape() {
  const s = new Shape();
  for (let y = 26; y >= 6; y--) {
    const half = 11 + Math.min(3, Math.floor((26 - y) / 6));
    for (let x = -half - 1; x <= half; x++) {
      const bz = backZ(BODY.torso, x, Math.min(y, 26)) ?? -7;
      s.put(x, y, Math.min(bz, -7) - 1, y <= 7 ? C.GOLD : S).put(x, y, Math.min(bz, -7), P);
    }
  }
  return without(s, BODY.torso);
}

function nobleBoot() {
  const s = shellOn(BODY.shin, 1, C.BLACK_LEATHER, (x, y) => y <= 0 && y >= -26);
  without(s, BODY.shin);
  finish(s, { b: C.BLACK_LEATHER, d: C.BLACK_LEATHER_D, l: C.LEATHER_D }, 317);
  recolor(s, (x, y) => y === 0, C.GOLD);
  return s;
}

export function npcOutfitsV2() {
  const palette = PALETTE;
  const out = {};
  const add = (name, shape, part) => { out[name] = { shape, part, palette, like: "assassin_chest_t2" }; };
  add("noble_gown", nobleBodice(true), "torso");
  add("noble_gown_skirt", nobleGownSkirt(), "hips");
  add("noble_doublet", nobleDoublet(), "torso");
  add("noble_cape", nobleCape(), "torso");
  for (const side of ["left", "right"]) {
    add(`noble_sleeve_${side[0]}`, nobleSleeve(), `arm_${side}`);
    add(`noble_cuff_${side[0]}`, nobleCuff(), `forearm_${side}`);
    add(`noble_boot_${side[0]}`, nobleBoot(), `shin_${side}`);
  }
  add("mira_cloak", miraCloak(), "torso");
  add("mira_hood", miraHood(), "torso");
  add("mira_chest", miraChest(), "torso");
  add("mira_legs_l", ARMOR.leg("leather", 1, MIRA), "leg_left");
  add("mira_legs_r", ARMOR.leg("leather", 1, MIRA), "leg_right");
  for (const side of ["left", "right"]) {
    add(`mira_sleeve_${side[0]}`, miraSleeve(), `arm_${side}`);
    add(`mira_forearm_${side[0]}`, miraForearm(), `forearm_${side}`);
    add(`mira_glove_${side[0]}`, ARMOR.glove("leather", 2, MIRA), `hand_${side}`);
    add(`mira_boot_${side[0]}`, miraBoot(), `shin_${side}`);
  }
  return out;
}
