// v2 class clothes, headgear, pauldrons and quiver (Plan 6.2), sculpted over the v2 body
// parts in their pivot frames. Every material shows two or three tones per voxel and
// its form (shade facing down, light on top); seams and trims are drawn on top.
import { Shape, TEX_D, TEX_L, SHADE, LIGHT, TINT_PRIMARY, TINT_SECONDARY } from "./vox.mjs";
import { ellipsoid, capsule, cylinder, roundBox, carve, tone, shadeByFacing, shellAround, noise3 } from "./sculpt.mjs";
import { headV2, torsoV2, upperArmV2, frontZ, PALETTE_V2 } from "./human_v2.mjs";

const P = TINT_PRIMARY, S = TINT_SECONDARY;
// Fixed materials (indices after human_v2's 40..53): base, dark, light.
const STEEL = 60, STEEL_D = 61, STEEL_L = 62, GOLD = 63, GOLD_D = 64, GOLD_L = 65,
  LEATHER = 66, LEATHER_D = 67, LEATHER_L = 68, CLOTH = 69, CLOTH_D = 70, CLOTH_L = 71,
  CHAIN = 72, CHAIN_D = 73, CHAIN_L = 74, WOOD = 75, WOOD_D = 76, WOOD_L = 77, STRING = 78, GEM = 79, GEM_L = 80;
export const KIT_V2 = {
  ...PALETTE_V2,
  [STEEL]: "#aeb7c1", [STEEL_D]: "#6d7682", [STEEL_L]: "#e3e9ef",
  [GOLD]: "#d2a845", [GOLD_D]: "#94712a", [GOLD_L]: "#f1d886",
  [LEATHER]: "#5e3f26", [LEATHER_D]: "#3e2918", [LEATHER_L]: "#7c5735",
  [CLOTH]: "#e9e0cb", [CLOTH_D]: "#bfb39a", [CLOTH_L]: "#f8f3e6",
  [CHAIN]: "#8e97a1", [CHAIN_D]: "#59616b", [CHAIN_L]: "#b9c1c9",
  [WOOD]: "#6e4b2c", [WOOD_D]: "#4a311d", [WOOD_L]: "#8c6440", [STRING]: "#e6dfcc",
  [GEM]: "#b8241a", [GEM_L]: "#ff7a5a",
};
const tint = (t) => ({ tones: [t, TEX_D(t), TEX_L(t)], form: { shade: SHADE(t), light: LIGHT(t) } });
const fixed = (b, d, l) => ({ tones: [b, d, l], form: { shade: d, light: l } });
export const MAT = {
  [P]: tint(P), [S]: tint(S),
  [STEEL]: fixed(STEEL, STEEL_D, STEEL_L), [GOLD]: fixed(GOLD, GOLD_D, GOLD_L), [LEATHER]: fixed(LEATHER, LEATHER_D, LEATHER_L),
  [CLOTH]: fixed(CLOTH, CLOTH_D, CLOTH_L), [CHAIN]: fixed(CHAIN, CHAIN_D, CHAIN_L), [WOOD]: fixed(WOOD, WOOD_D, WOOD_L),
};
export { STEEL, STEEL_D, STEEL_L, GOLD, GOLD_D, GOLD_L, LEATHER, LEATHER_D, LEATHER_L, WOOD, WOOD_D, WOOD_L, STRING, GEM, GEM_L, CHAIN };

// Texture and form for the given materials (metal gets fewer, brighter speckles).
export function paint(s, mats, seed = 1) {
  const idxs = [], map = {};
  for (const m of mats) {
    const metal = m === STEEL || m === GOLD;
    tone(s, m, MAT[m].tones, seed + m, metal ? [0.75, 0.15, 0.1] : [0.65, 0.25, 0.1]);
    for (const i of MAT[m].tones) { idxs.push(i); map[i] = MAT[m].form; }
  }
  return shadeByFacing(s, idxs, map);
}

const HEAD = headV2(), TORSO = torsoV2(), ARM = upperArmV2();
const merge = (...shapes) => {
  const out = new Shape();
  for (const s of shapes) for (const [x, y, z, i] of s.cells.values()) out.put(x, y, z, i);
  return out;
};
const without = (s, part) => carve(s, (t) => { for (const [x, y, z] of part.cells.values()) t.put(x, y, z, 0); });
// Recolours every cell where pred holds.
const recolor = (s, pred, idx) => { for (const v of s.cells.values()) if (pred(v[0], v[1], v[2], v[3])) v[3] = idx; return s; };
// A line along the front surface of `part`, `out` voxels proud of it.
function onFront(part, cells, idx, out = 1) {
  const s = new Shape();
  for (const [x, y] of cells) {
    const z = frontZ(part, x, y);
    if (z !== null) s.put(x, y, z + out, idx);
  }
  return s;
}

// --- Torso pieces (torso pivot frame: waist y 0, shoulders ~22, neck to 29) -----------
function outfitWarrior() {
  const plate = paint(shellAround(TORSO, 1, STEEL, (x, y, z) => y >= 11 && y <= 24 && Math.abs(x + 0.5) <= 10.5), [STEEL], 3);
  recolor(plate, (x, y) => y === 11, STEEL_D); // lower rim
  recolor(plate, (x, y, z) => (x === -1 || x === 0) && z >= 6, STEEL_L); // ridge
  recolor(plate, (x, y, z) => y === 23 && z >= 3, GOLD); // gilded collar edge
  for (const [x, y] of [[-8, 13], [7, 13], [-8, 21], [7, 21]]) for (const p of onFront(plate, [[x, y]], GOLD, 0).cells.values()) plate.put(...p);
  const mail = paint(shellAround(TORSO, 1, CHAIN, (x, y) => y >= 0 && y <= 10), [CHAIN], 5);
  recolor(mail, (x, y) => (x + y) % 2 === 0, CHAIN_D); // ring pattern
  const skirt = new Shape(); // mail skirt over the hips
  for (let y = -9; y <= -1; y++) for (const [x, , z] of shellAround(TORSO, 1, 0, (xx, yy) => yy === 0).cells.values()) skirt.put(x, y, z, (x + y) % 2 ? CHAIN : CHAIN_D);
  return merge(skirt, mail, plate);
}

function outfitCleric() {
  const tabard = new Shape(); // a cloth tabard hanging to the knees, front and back
  for (const side of [1, -1]) {
    for (let y = -26; y <= 23; y++) for (let x = -5; x <= 4; x++) {
      const zs = [];
      for (const [cx, cy, cz] of TORSO.cells.values()) if (cx === x && cy === Math.max(y, 0)) zs.push(cz);
      if (!zs.length) continue;
      const z = side > 0 ? Math.max(...zs) + 1 : Math.min(...zs) - 1;
      tabard.put(x, y, y < 0 ? z + side : z, x === -5 || x === 4 ? S : CLOTH);
    }
  }
  paint(tabard, [CLOTH, S], 7);
  recolor(tabard, (x, y) => y === -26, S); // hem
  for (const [x, y] of [[-1, 8], [0, 8], [-1, 9], [0, 9], [-1, 10], [0, 10], [-1, 11], [0, 11], [-1, 12], [0, 12], [-1, 13], [0, 13],
    [-3, 11], [-2, 11], [1, 11], [2, 11]]) {
    for (const [cx, cy, cz] of [...tabard.cells.values()]) if (cx === x && cy === y && cz > 0) tabard.put(cx, cy, cz + 1, GOLD); // holy sign
  }
  return tabard;
}

function outfitMage() {
  const robe = new Shape(); // a robe skirt from the waist to the shins, flaring out
  for (let y = -38; y <= 3; y++) {
    const k = (3 - y) / 41;
    const rx = 10.6 + k * 4.2, rz = 7.6 + k * 3.0;
    for (let x = -16; x <= 15; x++) for (let z = -12; z <= 12; z++) {
      const d = ((x + 0.5) / rx) ** 2 + ((z + 0.5) / rz) ** 2;
      if (d <= 1 && d >= ((rx - 1.6) / rx) ** 2) robe.put(x, y, z, P);
    }
  }
  paint(robe, [P], 9);
  // Folds: darker vertical bands around the skirt, by angle.
  recolor(robe, (x, y, z, i) => y < -2 && Math.sin(Math.atan2(z + 0.5, x + 0.5) * 9) > 0.55, SHADE(P));
  recolor(robe, (x, y) => y <= -37, S); // hem
  recolor(robe, (x, y, z) => z >= 6 && Math.abs(x + 0.5) <= 1, S); // front opening trim
  const placket = onFront(TORSO, [...Array(20).keys()].flatMap((i) => [[-1, i + 2], [0, i + 2]]), S);
  const collar = paint(shellAround(TORSO, 1, S, (x, y, z) => y >= 24 && y <= 28 && z <= 3), [S], 11);
  return merge(robe, placket, collar);
}

function outfitArcher() {
  const jerkin = paint(shellAround(TORSO, 1, LEATHER, (x, y) => y >= 8 && y <= 22), [LEATHER], 13);
  recolor(jerkin, (x, y) => y === 8, LEATHER_D);
  const strap = new Shape(); // the quiver strap across the chest
  for (let i = 0; i <= 18; i++) {
    const x = 8 - i, y = 24 - i;
    for (const p of onFront(TORSO, [[x, y], [x - 1, y]], WOOD_D, 2).cells.values()) strap.put(...p);
  }
  return merge(jerkin, strap, quiver());
}

function outfitAssassin() {
  const s = new Shape();
  for (let i = 0; i <= 16; i++) { // crossed straps
    for (const [x, y] of [[-10 + i, 24 - i], [9 - i, 24 - i]]) for (const p of onFront(TORSO, [[x, y], [x, y - 1]], LEATHER, 1).cells.values()) s.put(...p);
  }
  for (const p of onFront(TORSO, [[-1, 15], [0, 15], [-1, 16], [0, 16]], GOLD, 2).cells.values()) s.put(...p);
  const sash = paint(shellAround(TORSO, 1, S, (x, y) => y >= 1 && y <= 4), [S], 15);
  const tails = paint(capsule(new Shape(), [-9, 2, 5], [-10, -12, 6], 1.4, 1.0, S), [S], 17);
  return paint(merge(s, sash, tails), [LEATHER], 19);
}

function outfitVillager() {
  const s = new Shape(); // a linen undershirt at the collar and laces
  for (let y = 18; y <= 24; y++) for (let x = -3; x <= 2; x++) if (Math.abs(x + 0.5) <= (y - 17) / 2) for (const p of onFront(TORSO, [[x, y]], CLOTH, 1).cells.values()) s.put(...p);
  for (let y = 12; y <= 20; y += 2) for (const p of onFront(TORSO, [[-1, y], [0, y]], LEATHER_D, 1).cells.values()) s.put(...p);
  const apron = paint(shellAround(TORSO, 1, LEATHER, (x, y, z) => y >= 0 && y <= 4 && z >= 2), [LEATHER], 21);
  return merge(paint(s, [CLOTH], 23), apron);
}

function quiver() {
  const q = paint(capsule(new Shape(), [7, 2, -11], [5, 24, -11], 3.0, 3.4, LEATHER), [LEATHER], 25);
  recolor(q, (x, y) => y === 6 || y === 20, LEATHER_D);
  for (const [x, z] of [[4, -11], [6, -10], [5, -12], [7, -11]]) { // arrows: shafts and fletching
    cylinder(q, [x, 24, z], [x, 30, z], 0.4, WOOD);
    q.put(x, 30, z, STRING).put(x, 31, z, STRING).put(x + 1, 30, z, STRING);
  }
  return without(q, TORSO);
}

function hoodCleric() {
  const h = new Shape(); // a lowered hood resting on the shoulders behind the neck
  ellipsoid(h, [-0.5, 27, -6], [7.5, 4.5, 4.5], P);
  carve(h, (t) => ellipsoid(t, [-0.5, 28, -4], [5.5, 4, 4], 0));
  roundBox(h, [-6, 18, -10], [5, 25, -8], 1.5, P); // drape down the back
  paint(without(h, TORSO), [P], 27);
  recolor(h, (x, y, z) => y >= 30, S); // lining edge
  return h;
}

// --- Head pieces (head pivot frame: y 0..16, face at z ~6) ------------------------------
const nearFace = (x, y, z) => z >= 2 && y <= 13 && y >= -1 && x >= -6 && x <= 5;

function hatMage() {
  const s = new Shape();
  cylinder(s, [-0.5, 16, -1.5], [-0.5, 17, -1.5], 13, P); // wide brim
  carve(s, (t) => cylinder(t, [-0.5, 16, -1.5], [-0.5, 16, -1.5], 8, 0));
  for (let k = 0; k <= 16; k++) { // the cone, bending back at the tip
    const r = 8.2 * (1 - k / 19);
    const bend = k > 9 ? (k - 9) ** 1.5 * 0.45 : 0;
    cylinder(s, [-0.5, 17 + k, -1.5 - bend], [-0.5, 17 + k, -1.5 - bend], Math.max(r, 0.8), P);
  }
  paint(without(s, HEAD), [P], 29);
  recolor(s, (x, y, z) => y === 16 && Math.hypot(x + 0.5, z + 1.5) > 12, SHADE(P)); // brim edge
  recolor(s, (x, y) => y >= 18 && y <= 20, S); // band
  for (const p of [[-1, 19, 6], [0, 19, 6], [-1, 18, 6], [0, 18, 6]]) s.put(p[0], p[1], frontZ(s, p[0], p[1]) ?? 6, GOLD); // buckle
  return s;
}

function hoodArcher() {
  const s = shellAround(HEAD, 2, P, (x, y, z) => !nearFace(x, y, z) && y >= -1);
  ellipsoid(s, [-0.5, 14, -9], [2.5, 3, 2.5], P); // the point at the back
  const cape = shellAround(TORSO, 2, P, (x, y, z) => y >= 20 && y <= 27);
  // The cape is drawn in the head frame: torso y + 53 - 81.
  for (const [x, y, z, i] of cape.cells.values()) s.put(x, y - 28, z, i);
  paint(without(s, HEAD), [P], 31);
  recolor(s, (x, y, z) => z >= 3 && z <= 6 && y >= 12 && y <= 14, SHADE(P)); // brim shadow
  return s;
}

function helmTemplar() {
  const s = shellAround(HEAD, 2, STEEL, (x, y, z) => y >= 3 && !(z >= 2 && y <= 12 && x >= -5 && x <= 4));
  paint(s, [STEEL], 33);
  recolor(s, (x, y, z) => y === 12 && z >= 1, STEEL_D); // brow band
  for (let y = 4; y <= 12; y++) for (const x of [-1, 0]) s.put(x, y, (frontZ(HEAD, x, y) ?? 6) + 2, y === 12 ? STEEL_D : STEEL_L); // nasal bar
  for (let z = -8; z <= 6; z++) for (const x of [-1, 0]) { // gold crest over the top
    let top = 0;
    for (const [cx, cy, cz] of s.cells.values()) if (cx === x && cz === z && cy > top) top = cy;
    if (top > 10) s.put(x, top + 1, z, GOLD).put(x, top + 2, z, z % 3 === 0 ? GOLD_L : GOLD);
  }
  return s;
}

function maskAssassin() {
  const s = shellAround(HEAD, 1, P, (x, y, z) => y >= -1 && y <= 6 && z >= -3);
  for (const [x, y, z] of [...s.cells.values()]) if (z >= 5 && y >= 3) s.put(x, y, z + 1, P); // fuller over the nose
  paint(s, [P], 35);
  recolor(s, (x, y) => y === 6, LIGHT(P)); // top fold
  capsule(s, [-2, 3, -9], [-3, -6, -10], 1.2, 0.8, S).put(1, 3, -9, S); // knot tails
  capsule(s, [1, 3, -9], [2, -5, -10], 1.1, 0.8, S);
  return without(s, HEAD);
}

// --- Arm pieces (upper arm pivot frame: shoulder at 0, outer side +X on the left arm) ---
function pauldron(outer) {
  const s = new Shape();
  ellipsoid(s, [-0.5 + outer * 0.8, 1, -0.5], [5.4, 4.8, 5.6], STEEL); // dome
  carve(s, (t) => roundBox(t, [-12, -12, -12], [12, -1, 12], 0, 0));
  for (let k = 0; k < 2; k++) { // two lames down the outside
    const y = -2 - k * 3;
    for (const [x, , z] of shellAround(ARM, 1, 0, (xx, yy) => yy === y).cells.values()) {
      if (outer * (x + 0.5) > 0) s.put(x, y, z, STEEL).put(x, y - 1, z, k ? STEEL_D : STEEL);
    }
  }
  paint(without(s, ARM), [STEEL], 37 + outer);
  recolor(s, (x, y) => y === -6, S); // trim
  for (const [y, z] of [[-3, 3], [-3, -4]]) s.put(outer > 0 ? 4 : -5, y, z, GOLD); // rivets
  return without(s, ARM);
}

export function clothesV2() {
  const torso = (shape) => ({ shape, part: "torso", palette: KIT_V2 });
  return {
    outfit_warrior: torso(outfitWarrior()),
    outfit_cleric: torso(outfitCleric()),
    outfit_mage: torso(outfitMage()),
    outfit_archer: torso(outfitArcher()),
    outfit_assassin: torso(outfitAssassin()),
    outfit_villager: torso(outfitVillager()),
    quiver_back: torso(quiver()),
    hood_cleric: torso(hoodCleric()),
    hat_mage: { shape: hatMage(), part: "head", palette: KIT_V2 },
    hood_archer: { shape: hoodArcher(), part: "head", palette: KIT_V2 },
    helm_templar: { shape: helmTemplar(), part: "head", palette: KIT_V2 },
    mask_assassin: { shape: maskAssassin(), part: "head", palette: KIT_V2 },
    pauldron_left: { shape: pauldron(1), part: "arm_left", palette: KIT_V2 },
    pauldron_right: { shape: pauldron(-1), part: "arm_right", palette: KIT_V2 },
  };
}
