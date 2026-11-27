// Generates the equipment models (.vox) and data/items/gear_pieces.json, and writes each
// base's "look" into data/items/bases.json.
//   node tools/art/make_gear.mjs <vox out dir> <gear_pieces.json> <bases.json>
// Armor is drawn as shells around the body parts of HumanRig (make_humans.mjs), in the
// part's own voxels from its pivot (so a piece's offset is just its min corner). Weapons use
// the fist frame of make_pieces.mjs (grips through the middle, blades forward along +Z).
// Armor comes in one set per class (Warrior plate, Cleric and Mage cloth, Archer mail,
// Assassin leather), each with its own headgear, emblems and colors; weapons by type.
// Three tiers: 1 plain, 2 trimmed and riveted, 3 gilded with glowing runes and bigger
// silhouettes. Cloth and leather sets take the wearer's colors (primary and secondary tints).
import fs from "node:fs";
import { formatJson } from "../json_format.mjs";
import { write, Shape, SHADE, LIGHT, TINT_PRIMARY, TINT_SECONDARY, GLOW } from "./vox.mjs";

import { P, S, C, PALETTE, BOX, mats, TIER_COLORS, tierPalette, CLASS_SETS, cmats, wmats } from "./gear_style.mjs";

// --- Class headgear and chest emblems -----------------------------------------------
const HEADS = {
  // A hood under a gold circlet with a sun on the brow; tier 3 a tall mitre.
  cleric(t, m) {
    const s = new Shape();
    const [x0, y0, z0, x1, y1, z1] = BOX.head;
    s.box(x0 - 1, y1 + 1, z0 - 1, x1 + 1, y1 + 1, z1 + 1, m.b);
    s.box(x0 - 1, y0 + 1, z0 - 1, x1 + 1, y1, z0 - 1, m.d);
    s.box(x0 - 1, y0 + 1, z0, x0 - 1, y1, z1 + 1, m.b).box(x1 + 1, y0 + 1, z0, x1 + 1, y1, z1 + 1, m.b);
    s.box(x0 - 2, y0 - 1, z0 - 2, x1 + 2, y0, z1, m.b).remove(x0, y0 - 1, z0, x1, y0, z1 - 1); // mantle
    s.box(x0 - 1, y1 - 1, z1 + 1, x1 + 1, y1 - 1, z1 + 1, m.acc); // circlet
    s.box(-1, y1 - 2, z1 + 2, 0, y1, z1 + 2, m.gem).put(-2, y1 - 1, z1 + 2, m.acc).put(1, y1 - 1, z1 + 2, m.acc); // sun
    if (t >= 2) s.box(x0 - 1, y0 + 1, z1 + 1, x0 - 1, y1 - 2, z1 + 1, m.trim).box(x1 + 1, y0 + 1, z1 + 1, x1 + 1, y1 - 2, z1 + 1, m.trim);
    if (t >= 3) {
      for (let k = 0; k < 5; k++) s.box(x0 + 1 + (k >> 1), y1 + 2 + k, z0 + 2, x1 - 1 - (k >> 1), y1 + 2 + k, z1 - 1, k % 2 ? m.l : m.b); // mitre
      s.box(-1, y1 + 3, z1, 0, y1 + 6, z1, m.acc).box(-2, y1 + 5, z1, 1, y1 + 5, z1, m.acc).put(-1, y1 + 4, z1 + 1, m.rune);
    }
    return { s, hides: ["hair", "hair_cap"] };
  },
  // A pointed wizard's hat with a wide brim and a band; taller, starred and glowing with the tier.
  mage(t, m) {
    const s = new Shape();
    const [x0, , z0, x1, y1, z1] = BOX.head;
    const y = y1 + 1;
    const brim = 3 + t;
    s.box(x0 - brim, y, z0 - brim, x1 + brim, y, z1 + brim, m.b);
    for (const [x, z] of [[x0 - brim, z0 - brim], [x1 + brim, z0 - brim], [x0 - brim, z1 + brim], [x1 + brim, z1 + brim]]) s.remove(x, y, z, x, y, z);
    s.box(x0 - brim + 1, y, z1 + brim, x1 + brim - 1, y, z1 + brim, m.l).box(x0 - brim + 1, y, z0 - brim, x1 + brim - 1, y, z0 - brim, m.d);
    s.box(x0, y + 1, z0, x1, y + 2, z1, m.trim); // band
    s.box(-1, y + 1, z1 + 1, 0, y + 2, z1 + 1, m.acc);
    const levels = t >= 3 ? 3 : 2;
    let lo = 0;
    for (let k = 0; k < levels; k++) {
      const yy = y + 3 + k * 2;
      s.box(x0 + lo, yy, z0 + lo, x1 - lo, yy + 1, z1 - lo, m.b);
      s.box(x0 + lo, yy, z0 + lo, x0 + lo, yy + 1, z1 - lo, m.d);
      if (t >= 2 && k === 1) s.put(-1, yy, z1 - lo + 1, m.acc).put(0, yy + 1, z1 - lo + 1, m.acc); // a star
      lo = Math.min(lo + 1, 3);
    }
    const top = y + 3 + levels * 2;
    s.box(-1, top, z0 + 2, 0, top, z0 + 3, m.b).put(-1, top + 1, z0 + 1, t >= 3 ? m.rune : m.b); // small bent tip
    if (t >= 3) for (let k = 1; k < levels; k += 2) s.put(x0 + Math.min(k, 3), y + 3 + k * 2, z1 - Math.min(k, 3) + 1, m.rune);
    return { s, hides: ["hair"] };
  },
  // A ranger's hood with a long point; tier 2 a leather brow band, tier 3 a feather and glow.
  archer(t, m) {
    const s = new Shape();
    const [x0, y0, z0, x1, y1, z1] = BOX.head;
    const hood = m.hood ?? P;
    s.box(x0 - 1, y1 + 1, z0 - 1, x1 + 1, y1 + 1, z1 + 1, hood);
    s.box(x0 - 1, y0 + 1, z0 - 1, x1 + 1, y1 + 1, z0 - 1, SHADE(hood));
    s.box(x0 - 1, y0 + 1, z0, x0 - 1, y1 + 1, z1, hood).box(x1 + 1, y0 + 1, z0, x1 + 1, y1 + 1, z1, hood);
    s.box(x0 - 1, y1 + 1, z1 + 1, x1 + 1, y1 + 1, z1 + 1, SHADE(hood));
    s.box(x0 - 2, y0 - 1, z0 - 2, x1 + 2, y0, z1 - 1, hood).remove(x0, y0 - 1, z0, x1, y0, z1 - 1); // cape collar
    s.box(x0 - 2, y0 - 1, z0 - 2, x1 + 2, y0 - 1, z0 - 2, m.b); // mail edge under the cape
    for (let k = 0; k < 2 + t; k++) s.box(-1, y1 - 2 - k, z0 - 2 - k, 0, y1 + 1 - k, z0 - 2 - k, hood); // the point
    if (t >= 2) s.box(x0 - 1, y1 - 1, z1 + 1, x1 + 1, y1 - 1, z1 + 1, C.LEATHER).put(-1, y1 - 1, z1 + 2, m.acc);
    if (t >= 3) { for (let k = 0; k < 6; k++) s.put(x1 + 2, y1 - 1 + k, z0 + 1 - (k >> 1), k > 3 ? C.WHITE : S); s.put(x1 + 1, y1, z1, m.rune); }
    return { s, hides: ["hair", "hair_cap"] };
  },
  // A hood and a mask over the lower face; tier 2 a red band, tier 3 small horns and glowing eyes' trim.
  assassin(t, m) {
    const s = new Shape();
    const [x0, y0, z0, x1, y1, z1] = BOX.head;
    s.box(x0 - 1, y1 + 1, z0 - 1, x1 + 1, y1 + 1, z1 + 1, m.b);
    s.box(x0 - 1, y0 + 1, z0 - 1, x1 + 1, y1, z0 - 1, m.d);
    s.box(x0 - 1, y0 + 1, z0, x0 - 1, y1, z1 + 1, m.b).box(x1 + 1, y0 + 1, z0, x1 + 1, y1, z1 + 1, m.b);
    s.box(x0 - 1, y1, z1 + 1, x1 + 1, y1 + 1, z1 + 1, m.l); // brow
    s.box(x0, y0 + 1, z1 + 1, x1, y0 + 3, z1 + 1, m.d).box(x0, y0 + 3, z1 + 1, x1, y0 + 3, z1 + 1, m.trim); // mask
    s.box(x0 - 2, y0 - 1, z0 - 2, x1 + 2, y0, z1, m.b).remove(x0, y0 - 1, z0, x1, y0, z1 - 1);
    if (t >= 2) s.box(x0 - 1, y1 - 1, z1 + 1, x1 + 1, y1 - 1, z1 + 1, m.trim);
    if (t >= 3) {
      for (const [x, dir] of [[x0, -1], [x1, 1]]) s.put(x, y1 + 2, z0 + 3, m.acc).put(x + dir, y1 + 3, z0 + 3, m.acc).put(x + dir, y1 + 4, z0 + 2, C.GOLD_L);
      s.put(x0 + 1, y0 + 2, z1 + 2, m.rune).put(x1 - 1, y0 + 2, z1 + 2, m.rune);
    }
    return { s, hides: ["hair", "hair_cap"] };
  },
};

// --- Epic extras of tiers 2 and 3 ---------------------------------------------------
// A cape hanging from the shoulders down the back (torso part), wider and longer with the
// tier; tier 3 hems it in the trim color with glowing runes. `tattered` cuts its hem.
function cape(t, m, tattered = false) {
  const s = new Shape();
  const z = BOX.torso[2] - 1;
  const bottom = t >= 3 ? -16 : -11;
  for (let y = 11; y >= bottom; y--) {
    const half = 6 + Math.min(2, Math.floor((11 - y) / 8));
    for (let x = -half; x <= half - 1; x++) {
      if (tattered && y < bottom + 4 && (x * 7 + y * 3) % 4 === 0) continue;
      const fold = (x + 20) % 3 === 0;
      s.put(x, y, z - (y < 4 ? 1 : 0), fold ? m.alt_d : m.alt);
    }
  }
  s.box(-6, 11, z, 5, 12, z + 1, m.trim); // clasped at the shoulders
  s.put(-6, 11, z + 2, m.gem).put(5, 11, z + 2, m.gem);
  if (t >= 3) {
    for (let x = -7; x <= 6; x++) s.put(x, bottom, z - 1, m.trim);
    for (let y = bottom + 3; y < 8; y += 4) s.put(-1, y, z - 2, m.rune).put(0, y, z - 2, m.rune);
  }
  return s;
}

// A glowing halo ring behind the head (head part).
function halo(m) {
  const s = new Shape();
  const cy = 10, z = BOX.head[2] - 3, r = 7;
  for (let a = 0; a < 64; a++) {
    const x = Math.round(Math.cos((a / 64) * Math.PI * 2) * r) - 1, y = Math.round(Math.sin((a / 64) * Math.PI * 2) * r) + cy;
    s.put(x, y, z, GLOW);
  }
  for (const [x, y] of [[-1, cy + r + 2], [-1, cy - r - 2], [r + 1, cy], [-r - 3, cy]]) s.put(x, y, z, m.trim);
  return s;
}

// A floating crown of glowing runes above the brim of a hat or hood (head part).
function runeCrown(y) {
  const s = new Shape();
  for (let a = 0; a < 10; a++) {
    const ang = (a / 10) * Math.PI * 2;
    s.put(Math.round(Math.cos(ang) * 7) - 1, y + (a % 2), Math.round(Math.sin(ang) * 7) - 1, GLOW);
  }
  return s;
}

// A crown of golden leaves and glowing buds (head part).
function leafCrown(m) {
  const s = new Shape();
  const [x0, , z0, x1, y1, z1] = BOX.head;
  s.box(x0 - 1, y1 + 2, z0 - 1, x1 + 1, y1 + 2, z1 + 1, m.trim).remove(x0, y1 + 2, z0, x1, y1 + 2, z1);
  for (let x = x0 - 1; x <= x1 + 1; x += 2) s.box(x, y1 + 3, z1 + 1, x, y1 + 4 + ((x & 2) ? 1 : 0), z1 + 1, C.GOLD);
  for (const [x, dir] of [[x0 - 2, -1], [x1 + 2, 1]]) for (let k = 0; k < 5; k++) s.put(x + dir * (k >> 1), y1 + 2 + k, z0 + 1 - (k >> 1), k === 4 ? GLOW : C.GOLD); // antlers
  s.put(-1, y1 + 3, z1 + 2, GLOW).put(0, y1 + 3, z1 + 2, GLOW);
  return s;
}

// Shards of crystal hovering over a shoulder (arm part), `outer` +1 left, -1 right.
function shards(outer) {
  const s = new Shape();
  const x = outer > 0 ? 6 : -7;
  for (const [dx, dy, h] of [[0, 4, 4], [outer, 7, 3], [-outer, 9, 2]]) s.box(x + dx, dy, 0, x + dx, dy + h, 0, h > 3 ? C.CRYSTAL : GLOW);
  return s;
}

// Sunburst rays fanning out above a shoulder (arm part).
function rays(outer, m) {
  const s = new Shape();
  const x = outer > 0 ? 4 : -5;
  for (let k = 0; k < 4; k++) s.box(x + outer * k, 2 + k * 2, -1, x + outer * k, 3 + k * 2, 0, k === 3 ? GLOW : m.trim);
  return s;
}

// What each class adds at a tier: [piece suffix, part, shape] to append to a slot's look.
function extras(cls, t, m) {
  const out = { chest: [], head: [], shoulders: [] };
  if (t < 2) return out;
  const cm = cls === "assassin" ? { ...m, alt: m.trim, alt_d: m.d } : m; // the Assassin wears a crimson scarf
  if (cls !== "archer" || t >= 3) out.chest.push(["cape", "torso", cape(t, cm, cls === "assassin")]);
  if (t >= 3) {
    if (cls === "cleric") out.head.push(["halo", "head", halo(m)]);
    if (cls === "mage") out.head.push(["runes", "head", runeCrown(BOX.head[4] + 4)]);
    if (cls === "archer") out.head.push(["leaves", "head", leafCrown(m)]);
    if (cls === "mage") out.shoulders.push(["shards_l", "arm_left", shards(1)], ["shards_r", "arm_right", shards(-1)]);
    if (cls === "cleric") out.shoulders.push(["rays_l", "arm_left", rays(1, m)], ["rays_r", "arm_right", rays(-1, m)]);
  }
  return out;
}

// Emblems over the class's chest piece.
const EMBLEMS = {
  warrior(s, t, m, z) { s.box(-2, 6, z, 1, 7, z, m.trim).box(-1, 5, z, 0, 8, z, m.trim); }, // a cross
  cleric(s, t, m, z) { // a gold sun on the chest
    s.box(-1, 5, z, 0, 8, z, m.acc).box(-2, 6, z, 1, 7, z, m.acc);
    for (const [x, y] of [[-3, 6], [2, 7], [-1, 9], [0, 4]]) s.put(x, y, z, m.acc);
    if (t >= 3) s.box(-1, 6, z + 1, 0, 7, z + 1, GLOW);
  },
  mage(s, t, m, z) { // an arcane star
    for (const [x, y] of [[-1, 8], [0, 8], [-2, 7], [1, 7], [-1, 6], [0, 6], [-3, 6], [2, 6], [-1, 5], [0, 5], [-2, 4], [1, 4]]) s.put(x, y, z, m.trim);
    if (t >= 2) s.put(-1, 6, z + 1, m.acc).put(0, 6, z + 1, m.acc);
    if (t >= 3) s.put(-1, 7, z + 1, GLOW).put(0, 7, z + 1, GLOW);
  },
  archer(s, t, m, z) { // a leather baldric across the mail and a buckle
    for (let i = 0; i <= 9; i++) s.put(-6 + i, 10 - i, z, C.LEATHER);
    s.put(-1, 5, z, m.acc);
  },
  assassin(s, t, m, z) { // crossed red straps and a dagger sheath
    for (let i = 0; i <= 9; i++) s.put(-6 + i, 10 - i, z, m.trim).put(5 - i, 10 - i, z, m.trim);
    s.box(3, 1, z, 4, 4, z, C.LEATHER_D);
  },
};

// A hollow shell one voxel outside a box (open at the ends listed): base on the outside,
// dark sides and back, light top edge. `grow` thickens it outward.
function shell(s, [x0, y0, z0, x1, y1, z1], m, { grow = 1, top = false, bottom = false } = {}) {
  const a = [x0 - grow, y0, z0 - grow, x1 + grow, y1, z1 + grow];
  s.box(...a, m.b);
  s.remove(x0, y0, z0, x1, y1, z1);
  if (top) s.box(a[0], y1 + 1, a[2], a[3], y1 + grow, a[5], m.b);
  if (bottom) s.box(a[0], y0 - grow, a[2], a[3], y0 - 1, a[5], m.b);
  for (let y = y0; y <= y1; y++) {
    s.box(a[0], y, a[2], a[0], y, a[5], m.d).box(a[3], y, a[2], a[3], y, a[5], m.d); // sides in shade
    s.box(a[0], y, a[2], a[3], y, a[2], m.d); // back
  }
  s.box(a[0] + 1, y1, a[5], a[3] - 1, y1, a[5], m.l); // light top edge at the front
}

// A band of trim around a shell at height y.
function band(s, [x0, , z0, x1, , z1], y, color, grow = 1) {
  s.box(x0 - grow, y, z0 - grow, x1 + grow, y, z1 + grow, color);
  s.remove(x0, y, z0, x1, y, z1);
}

// --- Armor by slot -----------------------------------------------------------------------
const ARMOR = {
  head(kind, t, m) {
    const s = new Shape();
    const [x0, y0, z0, x1, y1, z1] = BOX.head;
    if (kind === "cloth") {
      // A hood over head and shoulders, open at the face; tier 2 a gold circlet, tier 3 a
      // tall peaked cowl with a gem and glowing runes down the sides.
      s.box(x0 - 1, y1 + 1, z0 - 1, x1 + 1, y1 + 1, z1 + 1, m.b);
      s.box(x0 - 1, y0 + 1, z0 - 1, x1 + 1, y1, z0 - 1, m.d);
      s.box(x0 - 1, y0 + 1, z0, x0 - 1, y1, z1 + 1, m.b).box(x1 + 1, y0 + 1, z0, x1 + 1, y1, z1 + 1, m.b);
      s.box(x0 - 1, y1 - 1, z1 + 1, x1 + 1, y1 + 1, z1 + 1, m.l);
      s.box(x0 - 2, y0 - 1, z0 - 2, x1 + 2, y0, z1, m.b).remove(x0, y0 - 1, z0, x1, y0, z1 - 1); // mantle
      const peak = t === 1 ? 2 : t === 2 ? 3 : 6;
      for (let k = 0; k < peak; k++) s.box(-1 - (k < 2 ? 1 : 0), y1 + 2 + k, z0 + k, 0 + (k < 2 ? 1 : 0), y1 + 2 + k, z0 + k + 1, m.b);
      if (t >= 2) s.box(x0 - 1, y1 - 1, z1 + 1, x1 + 1, y1 - 1, z1 + 1, m.acc).box(-1, y1 - 1, z1 + 2, 0, y1, z1 + 2, m.gem);
      if (t >= 3) for (let y = y0 + 2; y <= y1 - 2; y += 2) s.put(x0 - 1, y, z1, m.rune).put(x1 + 1, y, z1, m.rune);
      return { s, hides: ["hair", "hair_cap"] };
    }
    if (kind === "leather") {
      // A close cap with ear flaps (t1), a hood with a half mask (t2), a horned hood (t3).
      s.box(x0 - 1, y1 + 1, z0 - 1, x1 + 1, y1 + 1, z1 + 1, m.b).box(x0 - 1, y1 - 2, z0 - 1, x1 + 1, y1, z0 - 1, m.d);
      s.box(x0 - 1, y1 - 3, z0, x0 - 1, y1, z1, m.b).box(x1 + 1, y1 - 3, z0, x1 + 1, y1, z1, m.b);
      s.box(x0 - 1, y1, z1 + 1, x1 + 1, y1, z1 + 1, m.trim);
      if (t >= 2) {
        s.box(x0 - 1, y0 + 1, z0 - 1, x1 + 1, y1, z0 - 1, m.d).box(x0 - 1, y0 + 1, z0, x0 - 1, y1, z1, m.b).box(x1 + 1, y0 + 1, z0, x1 + 1, y1, z1, m.b);
        s.box(x0, y0 + 1, z1 + 1, x1, y0 + 3, z1 + 1, m.d); // half mask
      }
      if (t >= 3) {
        for (const [x, dir] of [[x0 - 1, -1], [x1 + 1, 1]]) {
          s.box(x, y1 + 1, z0 + 2, x + dir, y1 + 2, z0 + 3, m.acc).put(x + 2 * dir, y1 + 3, z0 + 3, m.acc).put(x + 2 * dir, y1 + 4, z0 + 4, C.GOLD_L);
        }
        s.box(-1, y1 - 1, z1 + 2, 0, y1 - 1, z1 + 2, m.rune);
      }
      return { s, hides: t >= 2 ? ["hair", "hair_cap"] : ["hair_cap"] };
    }
    if (kind === "mail") {
      // A mail coif (t1), with a steel cap and nasal (t2), and swept wings (t3).
      shell(s, [x0, y0 + 1, z0, x1, y1, z1], m, { top: true });
      s.remove(x0 + 1, y0 + 2, z1 + 1, x1 - 1, y1 - 2, z1 + 1); // the face
      for (let y = y0 + 1; y <= y1; y += 2) for (let x = x0 - 1; x <= x1 + 1; x += 2) s.put(x, y, z0 - 1, m.l);
      s.box(x0 - 2, y0, z0 - 2, x1 + 2, y0, z1 + 1, m.b).remove(x0, y0, z0, x1, y0, z1); // collar
      if (t >= 2) {
        s.box(x0 - 1, y1 + 1, z0 - 1, x1 + 1, y1 + 2, z1 + 1, m.acc === C.BRONZE ? C.STEEL : C.DARK);
        s.box(x0 - 1, y1, z1 + 1, x1 + 1, y1, z1 + 1, m.trim).box(-1, y1 - 4, z1 + 2, 0, y1, z1 + 2, C.STEEL);
      }
      if (t >= 3) for (const [x, dir] of [[x0 - 2, -1], [x1 + 2, 1]]) {
        for (let k = 0; k < 4; k++) s.box(x + dir * (k > 1 ? 1 : 0), y1 - 1 + k, z0 - 1 + k, x + dir * (k > 1 ? 1 : 0), y1 - 1 + k, z0 + 2 + k, k === 3 ? C.GOLD_L : m.acc);
        s.put(x, y1 - 2, z1, m.rune);
      }
      return { s, hides: ["hair", "hair_cap"] };
    }
    // Plate: a kettle helm (t1), a great helm with a visor slit and gold cross (t2), a horned
    // great helm with a crest and glowing eyes (t3).
    shell(s, [x0, y0 + 1, z0, x1, y1, z1], m, { top: true });
    if (t === 1) {
      s.remove(x0, y0 + 1, z1 + 1, x1, y1 - 2, z1 + 1);
      s.box(x0 - 3, y1 - 1, z0 - 3, x1 + 3, y1 - 1, z1 + 3, m.b).remove(x0 - 1, y1 - 1, z0 - 1, x1 + 1, y1 - 1, z1 + 1); // brim
      s.box(x0 - 3, y1 - 1, z1 + 3, x1 + 3, y1 - 1, z1 + 3, m.l);
    } else {
      s.box(x0, y1 - 4, z1 + 1, x1, y1 - 4, z1 + 1, C.DARK_D); // visor slit
      s.box(-1, y0 + 2, z1 + 2, 0, y1 - 1, z1 + 2, m.trim).box(x0 + 1, y1 - 3, z1 + 2, x1 - 1, y1 - 3, z1 + 2, m.trim); // cross
      for (let y = y0 + 2; y <= y1 - 6; y += 2) s.put(x0, y, z1 + 1, C.DARK_D).put(x1, y, z1 + 1, C.DARK_D); // breaths
    }
    if (t >= 3) {
      s.box(x0 + 2, y1 - 4, z1 + 1, x0 + 3, y1 - 4, z1 + 1, m.rune).box(x1 - 3, y1 - 4, z1 + 1, x1 - 2, y1 - 4, z1 + 1, m.rune);
      for (let k = 0; k < 5; k++) s.box(-1, y1 + 2 + (k < 3 ? k : 2), z0 + 1 + k, 0, y1 + 2 + (k < 3 ? k : 2), z0 + 1 + k, k % 2 ? C.RED : C.RED_D); // crest
      for (const [x, dir] of [[x0 - 2, -1], [x1 + 2, 1]]) {
        s.box(x, y1 - 2, z0 + 1, x, y1, z0 + 2, m.b);
        for (let k = 1; k <= 4; k++) s.put(x + dir * Math.min(k, 2), y1 + k, z0 + 1, k === 4 ? C.GOLD_L : m.trim);
      }
    }
    return { s, hides: ["hair", "hair_cap"] };
  },

  shoulder(kind, t, m, outer) {
    const s = new Shape();
    const [x0, , z0, x1, y1, z1] = BOX.arm;
    const out = outer > 0 ? x1 + 1 : x0 - 1;
    const big = t - 1; // bigger with the tier
    const xa = Math.min(out, out - outer * (4 + big)), xb = Math.max(out, out - outer * (4 + big));
    const xo = outer > 0 ? xb + big : xa - big; // the outermost column
    if (kind === "cloth" || kind === "leather") {
      // Padded shoulders: a rounded pad with a trim edge; tier 3 a tassel of glowing threads.
      s.box(xa - (outer < 0 ? big : 0), y1 - 2, z0 - 1, xb + (outer > 0 ? big : 0), y1 + 1, z1 + 1, m.b);
      s.box(xa - (outer < 0 ? big : 0), y1 + 1, z0 - 1, xb + (outer > 0 ? big : 0), y1 + 1, z1 + 1, m.l);
      s.box(xo, y1 - 3, z0 - 1, xo, y1 - 2, z1 + 1, m.trim);
      if (kind === "leather") s.box(xo, y1 - 1, z0, xo, y1 - 1, z1, m.acc);
      if (t >= 3) for (let z = z0; z <= z1; z += 2) s.box(xo, y1 - 6, z, xo, y1 - 4, z, m.rune);
      return s;
    }
    // Mail and plate: a dome of lames down the outside; tier 2 gold rims; tier 3 spikes.
    s.box(xa - (outer < 0 ? big : 0), y1 - 1, z0 - 1 - big, xb + (outer > 0 ? big : 0), y1 + 1 + big, z1 + 1 + big, m.b);
    s.box(xa - (outer < 0 ? big : 0), y1 + 1 + big, z0 - 1 - big, xb + (outer > 0 ? big : 0), y1 + 1 + big, z1 + 1 + big, m.l);
    for (let k = 0; k < 2 + big; k++) {
      const y = y1 - 2 - k * 2;
      s.box(xo, y - 1, z0 - 1, xo, y, z1 + 1, kind === "mail" ? m.b : m.b).box(xo, y - 1, z0 - 1, xo, y - 1, z1 + 1, m.d);
    }
    if (t >= 2) s.box(xo, y1 - 1, z0 - 1 - big, xo, y1 + 1 + big, z0 - 1 - big, m.trim).box(xo, y1 - 1, z1 + 1 + big, xo, y1 + 1 + big, z1 + 1 + big, m.trim);
    if (t >= 3) {
      for (const z of [z0, z1]) for (let k = 1; k <= 3; k++) s.put(xo + outer * (k > 1 ? 1 : 0), y1 + 1 + big + k, z, k === 3 ? C.GOLD_L : m.trim);
      s.put(xo, y1, (z0 + z1) >> 1, m.rune);
    }
    return s;
  },

  chest(kind, t, m) {
    const s = new Shape();
    const b = BOX.torso;
    shell(s, [b[0], 0, b[2], b[3], b[4], b[5]], m);
    s.remove(-2, 9, b[5] + 1, 1, 11, b[5] + 1); // collar opening
    const [x0, , z0, x1, , z1] = b;
    if (kind === "cloth") {
      // A robe: a sash, a front panel in the trim color, embroidery that grows with the tier.
      s.box(-1, 0, z1 + 1, 0, 8, z1 + 1, m.trim);
      band(s, b, 3, m.acc);
      if (t >= 2) for (let y = 1; y <= 8; y += 2) s.put(-2, y, z1 + 1, m.acc).put(1, y, z1 + 1, m.acc);
      if (t >= 3) {
        s.box(x0 - 1, 10, z0 - 2, x1 + 1, 12, z0 - 1, m.trim); // high collar
        for (const y of [2, 5, 8]) s.put(-1, y, z1 + 2, m.rune).put(0, y, z1 + 2, m.rune);
      }
      return s;
    }
    if (kind === "leather") {
      // A jerkin: laces up the front, a cross strap, buckles; tier 3 riveted plates.
      for (let y = 1; y <= 9; y += 2) s.box(-1, y, z1 + 1, 0, y, z1 + 1, m.trim);
      for (let i = 0; i <= 9; i++) s.put(x0 + i, 10 - i, z1 + 2, m.d);
      band(s, b, 2, m.d);
      s.box(-1, 2, z1 + 2, 0, 2, z1 + 2, m.acc);
      if (t >= 2) s.box(x0 - 1, 10, z0 - 1, x1 + 1, 11, z1 + 1, m.trim).remove(x0, 10, z0, x1, 11, z1).remove(-2, 9, z1 + 1, 1, 11, z1 + 1);
      if (t >= 3) for (const [x, y] of [[-4, 7], [3, 7], [-4, 4], [3, 4]]) s.box(x, y, z1 + 1, x + 1, y + 1, z1 + 1, m.acc).put(x, y, z1 + 2, m.rune);
      return s;
    }
    if (kind === "mail") {
      // A hauberk: rings in a checker of light and dark, a leather belt, a surcoat panel (t2+).
      for (let y = 0; y <= b[4]; y++) for (let x = x0 - 1; x <= x1 + 1; x++) if ((x + y) % 2 === 0) s.put(x, y, z1 + 1, m.l);
      s.remove(-2, 9, z1 + 1, 1, 11, z1 + 1);
      band(s, b, 3, C.LEATHER);
      s.box(-1, 3, z1 + 2, 0, 3, z1 + 2, m.acc);
      if (t >= 2) { s.box(-3, 4, z1 + 1, 2, 8, z1 + 1, m.trim); s.box(-1, 5, z1 + 2, 0, 7, z1 + 2, m.gem); }
      if (t >= 3) { s.box(-3, 8, z1 + 1, 2, 8, z1 + 1, m.acc); s.put(-1, 6, z1 + 2, m.rune).put(0, 6, z1 + 2, m.rune); }
      return s;
    }
    // Plate: a cuirass with a ridge, plackart lines, a gold emblem (t2), a glowing sun (t3).
    shell(s, [b[0], 4, b[2], b[3], b[4], b[5]], m, { grow: 2 });
    s.remove(-2, 9, z1 + 1, 1, 11, z1 + 2);
    s.box(-1, 4, z1 + 2, 0, 9, z1 + 2, m.l); // ridge
    for (const y of [1, 3]) s.box(x0, y, z1 + 1, x1, y, z1 + 1, m.d);
    if (t >= 2) { band(s, [b[0], 0, b[2], b[3], 0, b[5]], 11, m.trim, 2); s.box(-2, 6, z1 + 3, 1, 7, z1 + 3, m.trim).box(-1, 5, z1 + 3, 0, 8, z1 + 3, m.trim); }
    if (t >= 3) s.box(-1, 6, z1 + 3, 0, 7, z1 + 3, m.rune).put(-2, 8, z1 + 3, m.trim).put(1, 8, z1 + 3, m.trim).put(-2, 5, z1 + 3, m.trim).put(1, 5, z1 + 3, m.trim);
    return s;
  },

  // The Mage's robe below the waist: down to the ankles, flaring out, with a hem in the trim
  // color, a front panel and (tier 3) glowing runes along the hem.
  robe(t, m) {
    const s = new Shape();
    const [x0, y0, z0, x1, y1, z1] = BOX.hips;
    const bottom = y0 - 19;
    for (let y = y1; y >= bottom; y--) {
      const f = Math.floor((y1 - y) / 6); // flare
      s.box(x0 - 1 - f, y, z0 - 1 - f, x1 + 1 + f, y, z1 + 1 + f, m.b);
      s.box(x0 - 1 - f, y, z0 - 1 - f, x0 - 1 - f, y, z1 + 1 + f, m.d).box(x1 + 1 + f, y, z0 - 1 - f, x1 + 1 + f, y, z1 + 1 + f, m.d);
      if (y <= y1 - 2 && (y & 1)) s.put(x0 - f, y, z1 + 1 + f, m.d).put(x1 - f + 1, y, z1 + 1 + f, m.d); // folds
    }
    s.remove(x0, bottom, z0, x1, y1, z1); // hollow (the legs move inside)
    const fb = Math.floor((y1 - bottom) / 6);
    s.box(x0 - 1 - fb, bottom, z1 + 1 + fb, x1 + 1 + fb, bottom + 1, z1 + 1 + fb, m.trim); // hem
    s.box(x0 - 1 - fb, bottom, z0 - 1 - fb, x1 + 1 + fb, bottom, z0 - 1 - fb, m.trim);
    for (let y = y1 - 1; y > bottom + 1; y--) { const f = Math.floor((y1 - y) / 6); s.box(-1, y, z1 + 1 + f, 0, y, z1 + 1 + f, m.trim); } // front panel
    if (t >= 2) for (let y = y1 - 4; y > bottom + 2; y -= 4) { const f = Math.floor((y1 - y) / 6); s.put(-1, y, z1 + 2 + f, m.acc).put(0, y, z1 + 2 + f, m.acc); }
    if (t >= 3) for (let x = x0 - fb; x <= x1 + fb; x += 2) s.put(x, bottom + 2, z1 + 2 + fb, m.rune);
    return s;
  },

  // The Mage's sleeves: the upper sleeve (arm part)...
  sleeve(t, m) {
    const s = new Shape();
    shell(s, BOX.arm, m);
    s.box(BOX.arm[0] - 1, BOX.arm[4], BOX.arm[2] - 1, BOX.arm[3] + 1, BOX.arm[4] + 1, BOX.arm[5] + 1, m.b); // over the shoulder
    if (t >= 2) s.box(BOX.arm[0] - 1, -4, BOX.arm[5] + 1, BOX.arm[3] + 1, -4, BOX.arm[5] + 1, m.acc);
    return s;
  },
  // ...and the long bell cuff hanging past the wrist (forearm part).
  bell(t, m) {
    const s = new Shape();
    const [x0, , z0, x1, , z1] = BOX.fore;
    for (let y = 0; y >= -11; y--) {
      const f = y < -5 ? 2 : y < -2 ? 1 : 0; // widens toward the wrist
      s.box(x0 - 1 - f, y, z0 - 1 - f, x1 + 1 + f, y, z1 + 1 + f, m.b);
      s.box(x0 - 1 - f, y, z0 - 1 - f, x0 - 1 - f, y, z1 + 1 + f, m.d).box(x1 + 1 + f, y, z0 - 1 - f, x1 + 1 + f, y, z1 + 1 + f, m.d);
    }
    s.remove(x0, -11, z0, x1, 0, z1);
    s.remove(x0 - 2, -11, z0 - 2, x1 + 2, -11, z1 + 2); // open at the end, the hand shows
    s.box(x0 - 3, -10, z0 - 3, x1 + 3, -10, z1 + 3, m.trim).remove(x0 - 2, -10, z0 - 2, x1 + 2, -10, z1 + 2); // trim at the opening
    if (t >= 3) s.put(x0 - 3, -9, (z0 + z1) >> 1, m.rune).put(x1 + 3, -9, (z0 + z1) >> 1, m.rune);
    return s;
  },

  // The part of the chest piece over the hips: a skirt (cloth, mail) or tassets (plate).
  skirt(kind, t, m) {
    const s = new Shape();
    const [x0, y0, z0, x1, y1, z1] = BOX.hips;
    const long = kind === "cloth" ? 3 + t : kind === "mail" ? 2 + t : t;
    s.box(x0 - 1, y0 - long, z0 - 1, x1 + 1, y1, z1 + 1, m.b);
    s.remove(x0, y0 - long, z0, x1, y1, z1);
    s.remove(-1, y0 - long, z1 + 1, 0, y0 - 1, z1 + 1).remove(-1, y0 - long, z0 - 1, 0, y0 - 1, z0 - 1); // split for the legs
    s.box(x0 - 1, y0 - long, z0 - 1, x0 - 1, y1, z1 + 1, m.d).box(x1 + 1, y0 - long, z0 - 1, x1 + 1, y1, z1 + 1, m.d);
    s.box(x0 - 1, y0 - long, z1 + 1, x1 + 1, y0 - long, z1 + 1, m.trim);
    if (kind === "plate") for (const x of [x0 - 1, x1 + 1]) s.box(x, y0 - long, z0 - 1, x, y0, z1 + 1, m.l);
    if (t >= 3 && m.rune) s.put(x0, y0 - long + 1, z1 + 1, m.rune).put(x1, y0 - long + 1, z1 + 1, m.rune);
    return s;
  },

  glove(kind, t, m) {
    const s = new Shape();
    shell(s, BOX.hand, m, { bottom: true });
    const [x0, y0, z0, x1, , z1] = BOX.hand;
    if (kind === "plate" || kind === "mail") for (let y = y0; y <= 0; y += 2) s.box(x0 - 1, y, z1 + 1, x1 + 1, y, z1 + 1, m.d); // knuckle plates
    if (t >= 3 && m.rune) s.put(x0 - 1, -2, z1, m.rune).put(x1 + 1, -2, z1, m.rune);
    return s;
  },

  cuff(kind, t, m) {
    const s = new Shape();
    const [x0, , z0, x1, , z1] = BOX.fore;
    const flare = kind === "plate" ? t : kind === "mail" ? 1 : 0;
    const top = -3 - t; // longer with the tier
    s.box(x0 - 1, -8, z0 - 1, x1 + 1, top, z1 + 1, m.b).remove(x0, -8, z0, x1, top, z1);
    s.box(x0 - 1 - flare, -8, z0 - 1 - flare, x1 + 1 + flare, -8, z1 + 1 + flare, m.trim).remove(x0, -8, z0, x1, -8, z1);
    s.box(x0 - 1, top, z0 - 1, x1 + 1, top, z1 + 1, m.l).remove(x0, top, z0, x1, top, z1);
    if (t >= 2) s.box(x0 - 1, -6, z1 + 1, x1 + 1, -6, z1 + 1, m.acc);
    if (t >= 3 && m.rune) s.put(x1 + 1, -5, (z0 + z1) >> 1, m.rune).put(x0 - 1, -5, (z0 + z1) >> 1, m.rune);
    return s;
  },

  leg(kind, t, m) {
    const s = new Shape();
    const [x0, y0, z0, x1, y1, z1] = BOX.thigh;
    shell(s, [x0, y0, z0, x1, y1, z1], m);
    if (kind === "plate" || kind === "mail") {
      s.box(x0 - 1, y0, z1 + 2, x1 + 1, y0 + 2, z1 + 2, kind === "plate" ? m.l : m.d); // knee cop
      if (kind === "plate") s.box(-1, y0 + 1, z1 + 3, 0, y0 + 1, z1 + 3, t >= 2 ? m.trim : m.d);
    } else {
      s.box(x0 - 1, y1 - 1, z1 + 1, x1 + 1, y1 - 1, z1 + 1, m.trim);
      if (kind === "leather") s.box(x0 - 1, -5, z1 + 1, x1 + 1, -5, z1 + 1, m.d);
    }
    if (t >= 2) s.box(x0 - 1, y0 + 4, z1 + 1, x0 - 1, y1 - 2, z1 + 1, m.acc);
    if (t >= 3 && m.rune) s.put(x1 + 1, -4, z1, m.rune).put(x1 + 1, -6, z1, m.rune);
    return s;
  },

  boot(kind, t, m) {
    const s = new Shape();
    const [x0, , z0, x1, , z1] = BOX.shin;
    const top = kind === "cloth" ? -9 : -3 - (t >= 2 ? 0 : 1);
    s.box(x0 - 1, -12, z0 - 1, x1 + 1, top, z1 + 1, m.b).remove(x0, -11, z0, x1, top, z1);
    s.box(x0 - 1, -12, z1 + 2, x1 + 1, -11, z1 + 2 + (kind === "plate" ? 1 : 0), m.b); // toe
    s.box(x0 - 1, -12, z0 - 1, x1 + 1, -12, z1 + 2 + (kind === "plate" ? 1 : 0), kind === "plate" ? m.d : C.LEATHER_D); // sole
    s.box(x0 - 1, top, z0 - 1, x1 + 1, top, z1 + 1, kind === "cloth" ? m.trim : m.l).remove(x0, top, z0, x1, top, z1);
    s.box(x0 - 1, -12, z0 - 1, x0 - 1, top, z1 + 1, m.d).box(x1 + 1, -12, z0 - 1, x1 + 1, top, z1 + 1, m.d);
    if (kind === "plate") for (let y = -10; y < top; y += 2) s.box(x0 - 1, y, z1 + 1, x1 + 1, y, z1 + 1, m.d); // lames
    if (t >= 2) s.box(x0 - 1, top - 1, z1 + 1, x1 + 1, top - 1, z1 + 1, m.acc);
    if (t >= 3 && m.rune) s.put(-1, top - 2, z1 + 2, m.rune).put(0, top - 2, z1 + 2, m.rune);
    return s;
  },
};

// --- Weapons (fist frame of make_pieces.mjs; offhands in the left fist) -----------------
const HAND_R = { x0: 1, x1: 4, y0: 1, y1: 5, z0: 1, z1: 4, part: "hand_right", origin: [-3, -5, -3] };
const HAND_L = { ...HAND_R, part: "hand_left" };

// Metals and woods of a weapon tier.

function blade(f, s, m, len, width, t) {
  const h = width; // 2: one-handed; 3: two-handed
  s.box(2, 2, f.z1 + 2, 2, 1 + h, f.z1 + 1 + len, m.blade);
  s.box(2, 2 + h - 1, f.z1 + 2, 2, 2 + h - 1, f.z1 + 1 + len, m.edge);
  s.box(2, 2, f.z1 + 2, 2, 2, f.z1 + len - 1, m.dark); // fuller
  s.box(2, 2, f.z1 + 2 + len, 2, h, f.z1 + 2 + len, m.blade).put(2, 2, f.z1 + 3 + len, m.edge); // point
  if (m.rune) for (let z = f.z1 + 4; z < f.z1 + len - 1; z += 3) s.put(2, 2, z, m.rune);
  if (t >= 2) s.box(2, 2 + h - 1, f.z1 + 2, 2, 2 + h - 1, f.z1 + 3, m.gold); // ricasso
}

const WEAPON = {
  // One-handed: sword, axe, mace, scepter, short sword, dagger, wand.
  sword(f, s, m, t) {
    s.box(2, 2, f.z0 - 2, 3, 3, f.z0 - 1, m.gold).box(2, 2, f.z0, 3, 3, f.z1, m.grip);
    s.box(2, -1 - (t - 1), f.z1 + 1, 3, 6 + (t - 1), f.z1 + 1, m.guard);
    if (t >= 2) s.put(2, 2, f.z1 + 1, m.gem).put(3, 3, f.z1 + 1, m.gem);
    blade(f, s, m, 14 + t * 2, 3, t);
  },
  short_sword(f, s, m, t) {
    s.box(2, 2, f.z0 - 1, 3, 3, f.z1, m.grip).box(2, 0, f.z1 + 1, 3, 5, f.z1 + 1, m.guard);
    blade(f, s, m, 9 + t, 2, t);
  },
  dagger(f, s, m, t) {
    s.box(2, 2, f.z0 - 1, 3, 3, f.z1, m.grip).box(2, 0, f.z1 + 1, 3, 5, f.z1 + 1, m.guard);
    s.box(2, 2, f.z1 + 2, 2, 4, f.z1 + 6 + t, m.blade).box(2, 4, f.z1 + 2, 2, 4, f.z1 + 6 + t, m.edge);
    s.box(2, 3, f.z1 + 7 + t, 2, 4, f.z1 + 7 + t, m.blade).put(2, 4, f.z1 + 8 + t, m.edge);
    if (t >= 2) s.box(2, 4 + 1, f.z1 + 2, 2, 5, f.z1 + 3, m.gold);
    if (m.rune) s.put(2, 3, f.z1 + 4, m.rune).put(2, 3, f.z1 + 6, m.rune);
  },
  axe(f, s, m, t) {
    s.box(2, 2, f.z0 - 2, 3, 3, f.z1 + 12 + t, m.wood).box(2, 2, f.z0, 3, 3, f.z1, m.grip);
    const z = f.z1 + 8 + t;
    s.box(2, -3 - t, z, 3, 1, z + 4, m.blade).box(2, -4 - t, z - 1, 3, -3 - t, z + 5, m.edge); // bit, facing forward
    s.box(2, 4, z + 1, 3, 6, z + 3, m.dark); // back spike
    if (t >= 2) s.box(2, 1, z + 2, 3, 1, z + 2, m.gold);
    if (m.rune) s.put(2, -1, z + 2, m.rune);
  },
  mace(f, s, m, t) {
    s.box(2, 2, f.z0 - 2, 3, 3, f.z1 + 9, m.wood).box(2, 2, f.z0, 3, 3, f.z1, m.grip);
    s.box(0, 0, f.z1 + 10, 5, 5, f.z1 + 13 + t, m.dark);
    for (const [x0, y0, x1, y1] of [[2, -2, 3, -1], [2, 6, 3, 7], [-2, 2, -1, 3], [6, 2, 7, 3]]) {
      s.box(x0, y0, f.z1 + 10, x1, y1, f.z1 + 13 + t, m.blade).box(x0, y0, f.z1 + 13 + t, x1, y1, f.z1 + 13 + t, m.edge);
    }
    s.box(2, 2, f.z1 + 14 + t, 3, 3, f.z1 + 15 + t, m.gold);
    if (m.rune) s.box(2, 2, f.z1 + 11, 3, 3, f.z1 + 12, m.rune);
  },
  // A sacred scepter: a gilded rod crowned by a sun of rays around a gem.
  scepter(f, s, m, t) {
    s.box(2, 2, f.z0 - 2, 3, 3, f.z1 + 9, m.gold).box(2, 2, f.z0, 3, 3, f.z1, m.grip);
    const z = f.z1 + 10;
    s.box(1, 1, z, 4, 4, z + 2, m.gold).box(2, 2, z + 3, 3, 3, z + 4, m.gem);
    for (const [x, y] of [[2, -1], [2, 6], [-1, 2], [6, 2]]) s.box(x, y, z + 1, x + (x === 2 ? 1 : 0), y + (y === 2 ? 1 : 0), z + 2, m.gold);
    if (t >= 2) for (const [x, y] of [[0, 0], [5, 5], [0, 5], [5, 0]]) s.put(x, y, z + 2, m.gold);
    if (m.rune) s.box(2, 2, z + 5, 3, 3, z + 5, m.rune);
  },
  // A short wand pointing forward with a glowing tip.
  wand(f, s, m, t) {
    s.box(2, 2, f.z0 - 1, 3, 3, f.z1 + 7 + t, m.wood).box(2, 2, f.z0, 3, 3, f.z1, m.grip);
    if (t >= 2) s.box(2, 2, f.z1 + 3, 3, 3, f.z1 + 3, m.gold);
    s.box(2, 2, f.z1 + 8 + t, 3, 3, f.z1 + 9 + t, t >= 2 ? m.crystal : C.CRYSTAL).put(2, 2, f.z1 + 10 + t, GLOW);
  },
  // Two-handed: greatsword, great axe, warhammer, halberd, staff, bow, crossbow.
  greatsword(f, s, m, t) {
    s.box(2, 2, f.z0 - 7, 3, 3, f.z0 - 6, m.gold).box(2, 2, f.z0 - 5, 3, 3, f.z1, m.grip);
    s.box(2, -3 - (t - 1), f.z1 + 1, 3, 8 + (t - 1), f.z1 + 1, m.guard);
    if (t >= 2) s.box(2, -3 - (t - 1), f.z1 + 2, 3, -3 - (t - 1), f.z1 + 3, m.guard).box(2, 8 + (t - 1), f.z1 + 2, 3, 8 + (t - 1), f.z1 + 3, m.guard);
    blade(f, s, m, 22 + t * 2, 4, t);
  },
  great_axe(f, s, m, t) {
    s.box(2, 2, f.z0 - 8, 3, 3, f.z1 + 18 + t, m.wood).box(2, 2, f.z0 - 4, 3, 3, f.z1, m.grip);
    const z = f.z1 + 12 + t;
    for (const dir of [1, -1]) {
      const yb = dir > 0 ? 4 : 1, ye = dir > 0 ? 10 + t : -5 - t;
      s.box(2, Math.min(yb, ye), z, 3, Math.max(yb, ye), z + 5, m.blade);
      s.box(2, ye, z - 1, 3, ye, z + 6, m.edge);
    }
    s.box(1, 1, z + 1, 4, 4, z + 4, m.dark);
    if (t >= 2) s.box(1, 2, z + 2, 4, 3, z + 3, m.gold);
    if (m.rune) s.put(2, 7, z + 2, m.rune).put(2, -2, z + 2, m.rune);
  },
  warhammer(f, s, m, t) {
    s.box(2, 2, f.z0 - 8, 3, 3, f.z1 + 16 + t, m.wood).box(2, 2, f.z0 - 4, 3, 3, f.z1, m.grip);
    const z = f.z1 + 13 + t;
    s.box(-2 - t, 0, z, 7 + t, 5, z + 4, m.dark).box(-2 - t, 0, z, -2 - t, 5, z + 4, m.blade).box(7 + t, 0, z, 7 + t, 5, z + 4, m.blade);
    s.box(-2 - t, 0, z + 4, 7 + t, 5, z + 4, m.edge);
    if (t >= 2) s.box(1, 1, z + 1, 4, 4, z + 3, m.gold);
    if (m.rune) s.box(2, 2, z + 1, 3, 3, z + 3, m.rune);
    s.box(2, 2, z + 5, 3, 3, z + 6 + t, m.blade); // top spike
  },
  halberd(f, s, m, t) {
    s.box(2, 2, f.z0 - 12, 3, 3, f.z1 + 24 + t, m.wood).box(2, 2, f.z0 - 2, 3, 3, f.z1, m.grip);
    const z = f.z1 + 16 + t;
    s.box(2, -4 - t, z, 3, 1, z + 5, m.blade).box(2, -5 - t, z - 1, 3, -4 - t, z + 6, m.edge); // axe blade, facing forward
    s.box(2, 4, z + 2, 3, 6, z + 3, m.dark).put(2, 7, z + 3, m.dark); // back hook
    s.box(2, 2, z + 9 + t, 3, 3, z + 13 + t, m.blade).box(2, 2, z + 14 + t, 2, 3, z + 14 + t, m.edge); // spear point
    if (t >= 2) s.box(1, 1, z - 2, 4, 4, z - 1, m.gold);
    if (m.rune) s.put(2, -1, z + 2, m.rune);
  },
  // An upright staff through the fist, a crystal in claws on top that grows with the tier.
  staff(f, s, m, t) {
    s.box(2, -15, 2, 3, 26, 3, m.wood);
    for (let y = -14; y <= 24; y += 5) s.box(2, y, 2, 3, y, 3, m.wood_d);
    s.box(1, 25, 1, 4, 26, 4, m.gold);
    for (const [x, z] of [[1, 1], [4, 4], [1, 4], [4, 1]]) s.box(x, 27, z, x, 29 + t, z, m.gold);
    s.box(2, 27, 2, 3, 31 + t * 2, 3, m.crystal).box(1, 29, 2, 4, 30 + t, 3, m.crystal).box(2, 29, 1, 3, 30 + t, 4, m.crystal);
    if (t >= 3) { s.box(0, 28, 2, 0, 29, 3, GLOW).box(5, 28, 2, 5, 29, 3, GLOW); }
  },
  bow(f, s, m, t) {
    s.box(2, -1, 2, 2, 7, 3, m.wood).box(2, 1, 2, 2, 5, 3, m.grip);
    const limb = [[8, 10, 2], [11, 13, 1], [14, 15, 0], [16, 16, -1], [17, 17 + (t - 1), -2]];
    for (const [ya, yb, z] of limb) { s.box(2, ya, z, 2, yb, z + 1, m.wood); s.box(2, 6 - yb, z, 2, 6 - ya, z + 1, m.wood); }
    if (t >= 2) for (const y of [9, -3]) s.box(2, y, 2, 2, y, 3, m.gold);
    if (m.rune) for (const y of [12, -6]) s.put(2, y, 1, m.rune);
    s.box(2, -11 - (t - 1), -2, 2, 17 + (t - 1), -2, C.STRING);
  },
  crossbow(f, s, m, t) {
    s.box(2, 1, f.z0 - 1, 3, 3, f.z1 + 9, m.wood).box(2, 1, f.z0 - 1, 3, 1, f.z1 + 9, m.wood_d);
    s.box(2, 4, f.z0, 3, 4, f.z1 + 8, m.wood_d);
    s.box(-4 - t, 3, f.z1 + 8, 9 + t, 4, f.z1 + 9, t >= 2 ? m.blade : m.wood);
    s.box(-4 - t, 3, f.z1 + 5, -4 - t, 4, f.z1 + 8, m.wood).box(9 + t, 3, f.z1 + 5, 9 + t, 4, f.z1 + 8, m.wood);
    s.box(-4 - t, 4, f.z1 + 5, 9 + t, 4, f.z1 + 5, C.STRING);
    s.box(2, 5, f.z1 + 5, 3, 5, f.z1 + 12, m.blade).box(2, 5, f.z1 + 13, 3, 5, f.z1 + 13, m.edge);
    s.box(2, 0, f.z0 + 1, 3, 1, f.z0 + 2, C.LEATHER_D);
    if (m.rune) s.put(2, 2, f.z1 + 4, m.rune);
  },
  // Off-hands in the left fist.
  shield(f, s, m, t) {
    // A kite shield on the outer side of the fist, facing out (−X is the left arm's outside... the
    // left fist's outside is +X).
    const x = 5;
    const h = 7 + t, w = 5 + t;
    s.box(x, 3 - h, 3 - w, x, 3 + h, 3 + w, t === 1 ? m.wood : m.blade);
    s.box(x, 3 - h, 3 - w, x, 3 + h, 3 - w, m.dark).box(x, 3 - h, 3 + w, x, 3 + h, 3 + w, m.dark);
    s.box(x, 3 + h, 3 - w, x, 3 + h, 3 + w, m.dark).box(x, 3 - h, 3 - w, x, 3 - h, 3 + w, m.dark);
    s.remove(x, 3 - h, 3 - w, x, 3 - h + 1, 3 - w + 1).remove(x, 3 - h, 3 + w - 1, x, 3 - h + 1, 3 + w);
    s.box(x + 1, 1, 1, x + 1, 5, 5, t >= 2 ? m.gold : m.dark); // boss
    if (t >= 2) { s.box(x + 1, 3 - h + 2, 3, x + 1, 3 + h - 2, 3, m.gold); s.box(x + 1, 3, 3 - w + 2, x + 1, 3, 3 + w - 2, m.gold); }
    if (m.rune) s.box(x + 2, 2, 2, x + 2, 4, 4, m.rune);
    s.box(4, 2, 2, 4, 4, 4, C.LEATHER_D); // grip strap
  },
  orb(f, s, m, t) {
    // A glowing sphere floating above the open left hand, ringed by gold.
    const cy = 10, cz = 3, r = 2 + Math.min(t, 2);
    for (let x = -r; x <= r; x++) for (let y = -r; y <= r; y++) for (let z = -r; z <= r; z++) {
      if (x * x + y * y + z * z <= r * r + 1) s.put(2 + x, cy + y, cz + z, (x + y + z) % 3 === 0 ? m.crystal : C.CRYSTAL_D);
    }
    s.put(2, cy + 1, cz + r, GLOW);
    if (t >= 2) for (let k = -r - 1; k <= r + 1; k++) s.put(2 + k, cy, cz - r - 1, m.gold).put(2 + k, cy, cz + r + 1, m.gold);
    if (t >= 3) s.box(-r - 1 + 2, cy, cz, r + 1 + 2, cy, cz, GLOW);
  },
  tome(f, s, m, t) {
    // A thick book held flat in the left fist, its cover in the secondary color.
    s.box(0, 6, 0, 5, 7, 8, C.PAPER).box(0, 6, 0, 0, 7, 8, C.PAPER_D);
    s.box(-1, 5, -1, 6, 5, 9, S).box(-1, 8, -1, 6, 8, 9, S).box(-1, 5, -1, -1, 8, 9, SHADE(S)); // covers and spine
    if (t >= 2) { s.box(-1, 8, -1, 0, 8, 9, m.gold).box(5, 8, -1, 6, 8, 9, m.gold); s.box(2, 9, 3, 3, 9, 5, m.gem); }
    if (t >= 3) s.box(1, 9, 1, 4, 9, 1, GLOW).box(1, 9, 7, 4, 9, 7, GLOW);
  },
};
const OFFHAND = ["shield", "orb", "tome"];

// --- Build everything ---------------------------------------------------------------
const [outDir, jsonPath, basesPath] = process.argv.slice(2);
if (!outDir || !jsonPath || !basesPath) {
  console.error("usage: node make_gear.mjs <vox out dir> <gear_pieces.json> <bases.json>");
  process.exit(1);
}
fs.mkdirSync(outDir, { recursive: true });
for (const f of fs.readdirSync(outDir)) if (f.endsWith(".vox")) fs.unlinkSync(`${outDir}/${f}`);
const table = {};
const resPath = (name) => `res://${outDir.replace(/\\/g, "/").replace(/^\.\//, "")}/${name}.vox`;

// Pieces drawn in part coordinates: the offset is the shape's min corner.
function addPart(name, shape, part, hides = [], palette = PALETTE) {
  write(`${outDir}/${name}.vox`, shape.size(), shape.voxels(), palette);
  table[name] = { file: resPath(name), part, offset: shape.min(), tag: "gear", hides };
}
// Weapons drawn in the fist frame: the offset is origin + min.
function addWeapon(name, shape, frame) {
  write(`${outDir}/${name}.vox`, shape.size(), shape.voxels(), PALETTE);
  const mn = shape.min();
  table[name] = { file: resPath(name), part: frame.part, offset: frame.origin.map((o, i) => o + mn[i]), tag: "weapon", hides: [] };
}

const looks = {}; // base id -> {look, look_offhand?}
const TIERS = [1, 2, 3];
for (const t of TIERS) {
  for (const cls of Object.keys(CLASS_SETS)) {
    const kind = CLASS_SETS[cls].kind;
    const m = cmats(cls, t);
    const pal = tierPalette(cls, t);
    const id = (slot) => `${cls}_${slot}_t${t}`;
    const ex = extras(cls, t, m);
    const add = (name, shape, part, hides = []) => addPart(name, shape, part, hides, pal);
    const head = HEADS[cls] ? HEADS[cls](t, m) : ARMOR.head(kind, t, m);
    add(`${id("head")}`, head.s, "head", head.hides);
    looks[id("head")] = { look: [id("head")] };
    for (const [suffix, part, shape] of ex.head) { add(`${id("head")}_${suffix}`, shape, part); looks[id("head")].look.push(`${id("head")}_${suffix}`); }
    add(`${id("shoulders")}_l`, ARMOR.shoulder(kind, t, m, 1), "arm_left");
    add(`${id("shoulders")}_r`, ARMOR.shoulder(kind, t, m, -1), "arm_right");
    looks[id("shoulders")] = { look: [`${id("shoulders")}_l`, `${id("shoulders")}_r`] };
    for (const [suffix, part, shape] of ex.shoulders) { add(`${id("shoulders")}_${suffix}`, shape, part); looks[id("shoulders")].look.push(`${id("shoulders")}_${suffix}`); }
    const chest = ARMOR.chest(kind, t, m);
    EMBLEMS[cls](chest, t, m, BOX.torso[5] + (kind === "plate" ? 3 : 2));
    add(id("chest"), chest, "torso");
    add(`${id("chest")}_skirt`, cls === "mage" ? ARMOR.robe(t, m) : ARMOR.skirt(kind, t, m), "hips");
    looks[id("chest")] = { look: [id("chest"), `${id("chest")}_skirt`] };
    if (cls === "mage") {
      for (const [side, x] of [["left", "l"], ["right", "r"]]) {
        add(`${id("chest")}_sleeve_${x}`, ARMOR.sleeve(t, m), `arm_${side}`);
        add(`${id("chest")}_bell_${x}`, ARMOR.bell(t, m), `forearm_${side}`);
        looks[id("chest")].look.push(`${id("chest")}_sleeve_${x}`, `${id("chest")}_bell_${x}`);
      }
    }
    for (const [suffix, part, shape] of ex.chest) { add(`${id("chest")}_${suffix}`, shape, part); looks[id("chest")].look.push(`${id("chest")}_${suffix}`); }
    for (const side of ["left", "right"]) {
      add(`${id("hands")}_${side[0]}`, ARMOR.glove(kind, t, m), `hand_${side}`);
      add(`${id("hands")}_cuff_${side[0]}`, ARMOR.cuff(kind, t, m), `forearm_${side}`);
      add(`${id("legs")}_${side[0]}`, ARMOR.leg(kind, t, m), `leg_${side}`);
      add(`${id("feet")}_${side[0]}`, ARMOR.boot(kind, t, m), `shin_${side}`);
    }
    looks[id("hands")] = { look: ["l", "r"].flatMap((x) => [`${id("hands")}_${x}`, `${id("hands")}_cuff_${x}`]) };
    looks[id("legs")] = { look: [`${id("legs")}_l`, `${id("legs")}_r`] };
    looks[id("feet")] = { look: [`${id("feet")}_l`, `${id("feet")}_r`] };
  }
  const m = wmats(t);
  for (const [type, build] of Object.entries(WEAPON)) {
    const name = `${type}_t${t}`;
    const off = OFFHAND.includes(type);
    const bow = type === "bow";
    const frame = off || bow ? HAND_L : HAND_R;
    const sh = new Shape();
    build(frame, sh, m, t);
    addWeapon(`w_${name}`, sh, frame);
    looks[name] = { look: [`w_${name}`] };
    if (type === "dagger" || type === "short_sword") {
      const left = new Shape();
      build(HAND_L, left, m, t);
      addWeapon(`w_${name}_left`, left, HAND_L);
      looks[name].look_offhand = [`w_${name}_left`];
    }
  }
}
// --- Boss uniques: each inspired by its boss, with its own glow -----------------------
const UNIQUES = {
  // The Acolyte's black-sun scepter: a blackened rod, a broken sun of five gold rays around a
  // dark core that burns gold.
  unique_acolyte: { frame: HAND_R, glow: "#ffcf6a", build(f, s) {
    s.box(2, 2, f.z0 - 2, 3, 3, f.z1 + 11, C.DARK).box(2, 2, f.z0, 3, 3, f.z1, C.RED_D);
    for (const z of [f.z1 + 3, f.z1 + 7]) s.box(1, 1, z, 4, 4, z, C.GOLD);
    const z = f.z1 + 12;
    s.box(0, 0, z, 5, 5, z + 4, C.DARK_D).box(1, 1, z + 1, 4, 4, z + 3, GLOW);
    for (const [x, y] of [[2, -4], [7, 0], [6, 6], [-2, 6], [-3, 0]]) s.box(Math.min(2, x), Math.min(2, y), z + 2, Math.max(3, x), Math.max(3, y), z + 2, C.GOLD); // rays
    s.remove(4, -1, z + 2, 5, 0, z + 2); // the sun is broken
    s.box(2, 2, z + 5, 3, 3, z + 7, C.GOLD_L);
  } },
  // Vaelthar's staff: a pale twisting shaft, a halo of gold around a violet eye, tendrils below it.
  unique_vaelthar: { frame: HAND_R, glow: "#c07bff", build(f, s) {
    for (let y = -16; y <= 26; y++) s.box(2 + ((y >> 2) & 1), y, 2, 3 + ((y >> 2) & 1), y, 3, (y & 3) === 0 ? C.GOLD_D : C.WHITE);
    const cy = 32;
    for (let a = 0; a < 40; a++) s.put(2 + Math.round(Math.cos((a / 40) * Math.PI * 2) * 6), cy + Math.round(Math.sin((a / 40) * Math.PI * 2) * 6), 2, C.GOLD);
    s.box(1, cy - 2, 2, 4, cy + 2, 3, GLOW).box(2, cy - 1, 4, 3, cy, 4, C.EBONY); // the eye
    for (const x of [-1, 2, 5]) for (let k = 0; k < 5; k++) s.put(x + (k & 1), 26 - k, 3 + (k >> 1), k === 4 ? GLOW : C.CRYSTAL_D); // tendrils
  } },
  // Nhazar's greatsword: a dark blade split by red runes, chains wound round the hilt and a
  // fanged mouth at the guard.
  unique_nhazar: { frame: HAND_R, glow: "#ff3355", build(f, s) {
    s.box(2, 2, f.z0 - 7, 3, 3, f.z0 - 6, C.GOLD).box(2, 2, f.z0 - 5, 3, 3, f.z1, C.BLACK_LEATHER);
    for (let z = f.z0 - 5; z <= f.z1; z += 2) s.box(1, 1, z, 4, 4, z, C.IRON_D); // chains
    s.box(2, -5, f.z1 + 1, 3, 10, f.z1 + 2, C.DARK_D).box(2, 0, f.z1 + 2, 3, 5, f.z1 + 2, C.RED); // guard, its mouth
    for (const y of [1, 3]) s.put(2, y, f.z1 + 3, C.WHITE).put(3, y + 1, f.z1 + 3, C.WHITE); // fangs
    const len = 28;
    s.box(2, 1, f.z1 + 3, 2, 6, f.z1 + 2 + len, C.DARK);
    s.box(2, 6, f.z1 + 3, 2, 6, f.z1 + 2 + len, C.DARK_L).box(2, 1, f.z1 + 3, 2, 1, f.z1 + 2 + len, C.DARK_L);
    for (let z = f.z1 + 4; z < f.z1 + len; z += 2) s.put(2, 3 + (z & 1), z, GLOW); // runes down the middle
    s.box(2, 2, f.z1 + 3 + len, 2, 5, f.z1 + 3 + len, C.DARK).box(2, 3, f.z1 + 4 + len, 2, 4, f.z1 + 4 + len, C.DARK_L);
  } },
};
for (const [id, u] of Object.entries(UNIQUES)) {
  const sh = new Shape();
  u.build(u.frame, sh);
  write(`${outDir}/w_${id}.vox`, sh.size(), sh.voxels(), { ...PALETTE, [GLOW]: u.glow });
  const mn = sh.min();
  table[`w_${id}`] = { file: resPath(`w_${id}`), part: u.frame.part, offset: u.frame.origin.map((o, i) => o + mn[i]), tag: "weapon", hides: [] };
  looks[id] = { look: [`w_${id}`] };
}

fs.writeFileSync(jsonPath, formatJson(table));

// Every base of a tier that has models gets them; others keep what they have.
const bases = JSON.parse(fs.readFileSync(basesPath, "utf8"));
let set = 0;
for (const [id, l] of Object.entries(looks)) {
  if (!bases.bases[id]) continue;
  bases.bases[id].look = l.look;
  if (l.look_offhand) bases.bases[id].look_offhand = l.look_offhand;
  else delete bases.bases[id].look_offhand;
  set++;
}
fs.writeFileSync(basesPath, formatJson(bases));
console.log(`wrote ${Object.keys(table).length} gear pieces; looks set on ${set} bases`);
