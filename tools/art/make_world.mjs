// World pieces (Plan 8.1): village houses, fences, the forest, rocks and the crypt, at
// 5 cm voxels (shown at scale 0.5 like the props), and their footprint: the 1 m cells
// (20 voxels) they block, read from their base (voxels under 1.2 m).
//   node tools/art/make_world.mjs <out dir> <pieces.json path>
//   (assets/world and data/zones/pieces.json)
// Each piece is drawn with its origin at the corner of its cell (0, 0): voxel x 0..19 is
// cell 0. Godot axes (Y up). Trees stand on the centre of their cell.
import fs from "node:fs";
import { fileURLToPath } from "node:url";
import { write, Shape, GLOW } from "./vox.mjs";
import { ellipsoid, capsule, cylinder, roundBox, carve, noise3 } from "./sculpt.mjs";

export const CELL = 20; // voxels per metre-cell
const BASE_H = 24; // voxels under this height block the cell (1.2 m)
// Small pieces: no shadow and a shorter draw distance (Plan 8.1.1).
export const SMALL_PIECES = ["bush", "rock_small", "stump", "torch"];

const WOOD = 1, WOOD_D = 2, WOOD_L = 3, PLANK = 4, PLANK_D = 5, THATCH = 6, THATCH_D = 7, THATCH_L = 8,
  STONE = 9, STONE_D = 10, STONE_L = 11, MOSS = 12, LEAF = 13, LEAF_D = 14, LEAF_L = 15, PINE = 16, PINE_D = 17,
  BARK = 18, BARK_D = 19, IRON = 20, IRON_L = 21, PLASTER = 22, PLASTER_D = 23, WATER = 24, COAL = 25, HAY = 26;
const PALETTE = {
  [WOOD]: "#6b4528", [WOOD_D]: "#4b2f1b", [WOOD_L]: "#86593a", [PLANK]: "#8a6a45", [PLANK_D]: "#6d5133",
  [THATCH]: "#b08d4a", [THATCH_D]: "#8a6c33", [THATCH_L]: "#caa85f", [STONE]: "#7d7870", [STONE_D]: "#5d5953",
  [STONE_L]: "#99948a", [MOSS]: "#55683a", [LEAF]: "#3f7a32", [LEAF_D]: "#2c5a24", [LEAF_L]: "#5a9640",
  [PINE]: "#2e5a36", [PINE_D]: "#1f4027", [BARK]: "#5a4030", [BARK_D]: "#3f2c20", [IRON]: "#3a3a40",
  [IRON_L]: "#62626b", [PLASTER]: "#d8ccb2", [PLASTER_D]: "#b8aa8e", [WATER]: "#3d6f8f", [COAL]: "#22160f",
  [HAY]: "#d1b060", [GLOW]: "#ffb347", [27]: "#8a3b32", [28]: "#6a2b25",
};

// Two or three tones of a material mixed in patches of 3 voxels (Plan 8.1.1: less grain,
// and equal faces side by side merge into far fewer triangles).
function paint(s, from, tones, seed) {
  for (const v of s.cells.values()) {
    if (v[3] !== from) continue;
    const n = noise3(Math.floor(v[0] / 3), Math.floor(v[1] / 3), Math.floor(v[2] / 3), seed);
    v[3] = n < 0.25 ? tones[1] : n > 0.8 ? tones[2] ?? tones[0] : tones[0];
  }
  return s;
}

function merge(...shapes) {
  const out = new Shape();
  for (const s of shapes) for (const [x, y, z, i] of s.cells.values()) out.put(x, y, z, i);
  return out;
}

// A gabled thatched roof over [x0, x1] × [z0, z1] starting at height y, ridge along x.
function roof(s, x0, x1, z0, z1, y, overhang = 3) {
  const half = (z1 - z0) / 2 + overhang;
  const mid = (z0 + z1) / 2;
  for (let h = 0; h <= half; h++) {
    for (let x = x0 - overhang; x <= x1 + overhang; x++) {
      for (const z of [Math.round(mid - half + h), Math.round(mid + half - h)]) {
        s.put(x, y + h, z, THATCH).put(x, y + h - 1, z, THATCH_D);
      }
    }
  }
  return paint(s, THATCH, [THATCH, THATCH_D, THATCH_L], 7);
}

// Walkable houses (Plan 8.1.1): 10 cm voxels (shown at scale 1.0), w × d cells, four
// parts so the game can open a house when its player steps inside: the floor with its
// furniture, the walls (3 m), the same walls cut at 1 m, and the roof. The wall ring
// blocks its cells but for a 2-cell door in the middle of the front (+Z); large
// furniture blocks its cells too. Origin at the corner of cell (0, 0).
export const HOUSE_CELL = 10;
const HOUSE_H = 30, CUT_H = 10;

function houseParts(w, d, furnish = () => {}) {
  const C = HOUSE_CELL, W = w * C, D = d * C;
  const floor = new Shape(), walls = new Shape(), roofShape = new Shape();
  const door = [[Math.floor(w / 2) - 1, d - 1], [Math.floor(w / 2), d - 1]];
  const dx0 = door[0][0] * C, dx1 = (door[1][0] + 1) * C - 1;
  // Stone footing and plank floor.
  floor.box(0, 0, 0, W - 1, 0, D - 1, STONE);
  paint(floor, STONE, [STONE, STONE_D, STONE_L], 3);
  floor.box(3, 0, 3, W - 4, 0, D - 4, PLANK);
  floor.box(dx0, 0, D - 3, dx1, 0, D - 1, PLANK);
  for (let x = 3; x <= W - 4; x += 4) floor.box(x, 0, 3, x, 0, D - 4, PLANK_D); // board seams
  // Plaster walls 3 voxels thick on the outer edge of the ring, timber corners and beams.
  walls.box(0, 1, 0, W - 1, HOUSE_H, 2, PLASTER).box(0, 1, D - 3, W - 1, HOUSE_H, D - 1, PLASTER);
  walls.box(0, 1, 0, 2, HOUSE_H, D - 1, PLASTER).box(W - 3, 1, 0, W - 1, HOUSE_H, D - 1, PLASTER);
  paint(walls, PLASTER, [PLASTER, PLASTER_D], 5);
  for (const x of [0, W - 3]) for (const z of [0, D - 3]) walls.box(x, 1, z, x + 2, HOUSE_H, z + 2, WOOD);
  for (const y of [1, HOUSE_H]) {
    walls.box(0, y, 0, W - 1, y, 2, WOOD).box(0, y, D - 3, W - 1, y, D - 1, WOOD);
    walls.box(0, y, 0, 2, y, D - 1, WOOD).box(W - 3, y, 0, W - 1, y, D - 1, WOOD);
  }
  walls.remove(dx0, 1, D - 3, dx1, 21, D - 1); // doorway
  walls.box(dx0 - 1, 1, D - 3, dx0 - 1, 22, D - 1, WOOD).box(dx1 + 1, 1, D - 3, dx1 + 1, 22, D - 1, WOOD);
  walls.box(dx0 - 1, 22, D - 3, dx1 + 1, 22, D - 1, WOOD);
  for (const x of [C + 3, W - C - 7]) if (x + 4 < dx0 - 1 || x > dx1 + 1) walls.remove(x, 13, D - 3, x + 4, 18, D - 1); // front windows
  walls.remove(Math.floor(W / 2) - 2, 13, 0, Math.floor(W / 2) + 2, 18, 2); // back window
  const cut = new Shape();
  for (const v of walls.cells.values()) if (v[1] <= CUT_H) cut.put(v[0], v[1], v[2], v[3]);
  // Gabled thatch, ridge along x.
  roof(roofShape, 0, W - 1, 0, D - 1, HOUSE_H + 1, 3);
  const blocked = new Set();
  const block = (cx, cz) => blocked.add(cx + "," + cz);
  const lights = [];
  furnish({ floor, roof: roofShape, W, D, C, block, lights });
  const footprint = [], interior = [];
  for (let x = 0; x < w; x++) for (let z = 0; z < d; z++) {
    const ring = x === 0 || z === 0 || x === w - 1 || z === d - 1;
    const isDoor = door.some(([a, b]) => a === x && b === z);
    if (ring && !isDoor) footprint.push([x, z]);
    else if (!ring) {
      interior.push([x, z]);
      if (blocked.has(x + "," + z)) footprint.push([x, z]);
    }
  }
  footprint.sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  return { parts: { floor, walls, walls_cut: cut, roof: roofShape }, footprint, interior, door, lights };
}

// Furniture, drawn in a cell (cx, cz) of a house; each one blocks its cells.
const CLOTH = 27, CLOTH_D = 28;
function bed(f, cx, cz) { // two cells long along z
  const x0 = cx * f.C, z0 = cz * f.C;
  f.floor.box(x0 + 1, 1, z0 + 1, x0 + 8, 4, z0 + 18, WOOD).box(x0 + 1, 5, z0 + 1, x0 + 8, 6, z0 + 18, CLOTH);
  f.floor.box(x0 + 2, 7, z0 + 2, x0 + 7, 7, z0 + 5, PLASTER).box(x0 + 1, 5, z0 + 7, x0 + 8, 6, z0 + 8, CLOTH_D);
  f.block(cx, cz);
  f.block(cx, cz + 1);
}
function table(f, cx, cz, len = 1) { // len cells along x
  const x0 = cx * f.C, z0 = cz * f.C, x1 = (cx + len) * f.C - 1;
  f.floor.box(x0 + 1, 8, z0 + 1, x1 - 1, 8, z0 + 8, PLANK);
  for (const x of [x0 + 2, x1 - 2]) for (const z of [z0 + 2, z0 + 7]) f.floor.box(x, 1, z, x, 7, z, WOOD);
  f.floor.box(x0 + 3, 9, z0 + 3, x0 + 4, 10, z0 + 4, IRON_L); // a mug
  for (let i = 0; i < len; i++) f.block(cx + i, cz);
}
function chest(f, cx, cz) {
  const x0 = cx * f.C, z0 = cz * f.C;
  f.floor.box(x0 + 2, 1, z0 + 3, x0 + 7, 5, z0 + 7, WOOD).box(x0 + 2, 6, z0 + 3, x0 + 7, 6, z0 + 7, WOOD_L);
  f.floor.box(x0 + 2, 4, z0 + 2, x0 + 7, 4, z0 + 2, IRON).put(x0 + 4, 3, z0 + 2, IRON_L);
  f.block(cx, cz);
}
function shelf(f, cx, cz) {
  const x0 = cx * f.C, z0 = cz * f.C;
  f.floor.box(x0 + 1, 1, z0 + 1, x0 + 8, 18, z0 + 3, WOOD);
  for (const y of [6, 12]) f.floor.box(x0 + 2, y, z0 + 1, x0 + 7, y + 1, z0 + 2, HAY);
  f.block(cx, cz);
}
function hearth(f, cx, cz) {
  const x0 = cx * f.C, z0 = cz * f.C;
  f.floor.box(x0, 1, z0, x0 + 9, 12, z0 + 6, STONE).remove(x0 + 2, 1, z0 + 2, x0 + 7, 7, z0 + 6);
  f.floor.box(x0 + 2, 1, z0 + 2, x0 + 7, 1, z0 + 5, COAL).put(x0 + 4, 2, z0 + 3, GLOW).put(x0 + 5, 2, z0 + 4, GLOW);
  roundBox(f.roof, [x0 + 1, 31, z0 + 1], [x0 + 8, 62, z0 + 6], 0, STONE); // chimney through the roof
  f.lights.push([cx, cz]);
  f.block(cx, cz);
}
function anvil(f, cx, cz) {
  const x0 = cx * f.C, z0 = cz * f.C;
  f.floor.box(x0 + 3, 1, z0 + 3, x0 + 6, 6, z0 + 6, WOOD).box(x0 + 1, 7, z0 + 3, x0 + 8, 9, z0 + 6, IRON);
  f.floor.box(x0 + 2, 10, z0 + 3, x0 + 7, 10, z0 + 6, IRON_L);
  f.block(cx, cz);
}
function forgeFire(f, cx, cz) {
  const x0 = cx * f.C, z0 = cz * f.C;
  f.floor.box(x0, 1, z0, x0 + 9, 8, z0 + 9, STONE).box(x0 + 2, 8, z0 + 2, x0 + 7, 8, z0 + 7, COAL);
  for (const [x, z] of [[3, 3], [5, 4], [4, 6], [6, 6]]) f.floor.put(x0 + x, 9, z0 + z, GLOW);
  roundBox(f.roof, [x0 + 2, 31, z0 + 2], [x0 + 7, 66, z0 + 7], 0, STONE);
  f.lights.push([cx, cz]);
  f.block(cx, cz);
}
function barrel(f, cx, cz) {
  const x0 = cx * f.C, z0 = cz * f.C;
  cylinder(f.floor, [x0 + 4.5, 1, z0 + 4.5], [x0 + 4.5, 10, z0 + 4.5], 3.6, WOOD);
  for (const y of [3, 8]) cylinder(f.floor, [x0 + 4.5, y, z0 + 4.5], [x0 + 4.5, y, z0 + 4.5], 3.8, IRON);
  f.block(cx, cz);
}

function treeOak(seed) {
  const s = new Shape();
  capsule(s, [9.5, 0, 9.5], [9.5, 46, 9.5], 4, 2.6, BARK);
  for (const [dx, dz] of [[-6, 2], [6, -3]]) capsule(s, [9.5, 34, 9.5], [9.5 + dx * 2, 52, 9.5 + dz * 2], 1.6, 1, BARK);
  paint(s, BARK, [BARK, BARK_D], seed);
  const crown = new Shape();
  for (const [cx, cy, cz, r] of [[9.5, 64, 9.5, 20], [-2, 56, 12, 13], [21, 58, 6, 14], [12, 74, 16, 12], [6, 58, -4, 13]]) {
    ellipsoid(crown, [cx, cy, cz], [r, r * 0.8, r], LEAF);
  }
  carve(crown, (t) => { for (const v of s.cells.values()) t.put(v[0], v[1], v[2], 0); });
  paint(crown, LEAF, [LEAF, LEAF_D, LEAF_L], seed + 1);
  for (const v of crown.cells.values()) if (v[1] < 52 && v[3] === LEAF) v[3] = LEAF_D; // shade under the crown
  return merge(s, crown);
}

function treePine(seed) {
  const s = new Shape();
  cylinder(s, [9.5, 0, 9.5], [9.5, 30, 9.5], 2.6, BARK);
  paint(s, BARK, [BARK, BARK_D], seed);
  for (let i = 0; i < 5; i++) {
    const y = 26 + i * 15, r = 18 - i * 3.2;
    for (let h = 0; h < 18; h++) {
      const rr = r * (1 - h / 18);
      for (let x = Math.floor(9.5 - rr); x <= Math.ceil(9.5 + rr); x++)
        for (let z = Math.floor(9.5 - rr); z <= Math.ceil(9.5 + rr); z++)
          if (Math.hypot(x - 9.5, z - 9.5) <= rr) s.put(x, y + h, z, h < 2 ? PINE_D : PINE);
    }
  }
  return paint(s, PINE, [PINE, PINE_D, LEAF_D], seed + 2);
}

function rock(rx, ry, rz, seed) {
  const s = new Shape();
  ellipsoid(s, [rx, ry * 0.6, rz], [rx, ry, rz], STONE);
  ellipsoid(s, [rx * 1.3, ry * 0.5, rz * 0.8], [rx * 0.6, ry * 0.7, rz * 0.6], STONE);
  carve(s, (t) => roundBox(t, [-20, -40, -20], [80, -1, 80], 0, 1));
  paint(s, STONE, [STONE, STONE_D, STONE_L], seed);
  for (const v of s.cells.values()) if (v[1] > ry * 1.1 && noise3(v[0], 0, v[2], seed) > 0.5) v[3] = MOSS;
  return s;
}

export function worldPieces() {
  const out = {};
  const add = (id, shape, opts = {}) => {
    out[id] = { shape, ...opts };
    out[id].footprint = opts.footprint ?? footprintOf(out[id]);
  };
  const addHouse = (id, h) => { out[id] = { ...h, scale: 1 }; };
  addHouse("house_small", houseParts(6, 6, (f) => { bed(f, 1, 1); table(f, 4, 1); chest(f, 4, 4); }));
  addHouse("house_large", houseParts(8, 7, (f) => {
    bed(f, 1, 1); bed(f, 2, 1); table(f, 4, 3, 2); hearth(f, 6, 1); shelf(f, 6, 5);
  }));
  addHouse("house_forge", houseParts(7, 7, (f) => { forgeFire(f, 5, 1); anvil(f, 3, 3); barrel(f, 1, 5); barrel(f, 1, 1); }));
  const fence = new Shape();
  for (const x of [1, 19, 38]) fence.box(x, 0, 9, x + 1, 22, 10, WOOD);
  for (const y of [8, 17]) fence.box(0, y, 9, 39, y + 1, 9, PLANK);
  add("fence", paint(fence, WOOD, [WOOD, WOOD_D, WOOD_L], 2));
  const wall = new Shape();
  wall.box(0, 0, 6, 39, 20, 13, STONE);
  for (let x = 0; x < 40; x += 6) wall.box(x, 21, 6, x + 3, 24, 13, STONE);
  add("wall_low", paint(wall, STONE, [STONE, STONE_D, STONE_L], 4));
  const well = new Shape();
  cylinder(well, [19.5, 0, 19.5], [19.5, 18, 19.5], 15, STONE);
  cylinder(well, [19.5, 1, 19.5], [19.5, 19, 19.5], 11, 0);
  for (const v of [...well.cells.values()]) if (v[3] === 0) well.cells.delete(`${v[0]},${v[1]},${v[2]}`);
  well.box(10, 10, 10, 29, 10, 29, WATER);
  for (const x of [6, 32]) well.box(x, 18, 18, x + 1, 50, 21, WOOD);
  well.box(6, 50, 18, 33, 51, 21, WOOD);
  roof(well, 2, 37, 10, 29, 52, 2);
  add("well", paint(well, STONE, [STONE, STONE_D, STONE_L], 6));
  const cart = new Shape();
  cart.box(4, 12, 6, 50, 14, 33, PLANK).box(4, 15, 6, 50, 24, 7, PLANK).box(4, 15, 32, 50, 24, 33, PLANK);
  for (const [x, z] of [[14, 3], [14, 36], [40, 3], [40, 36]]) cylinder(cart, [x, 10, z], [x, 10, z + 2], 10, WOOD);
  cart.box(50, 12, 18, 70, 13, 21, WOOD).box(10, 15, 9, 46, 21, 30, HAY);
  add("cart", paint(cart, PLANK, [PLANK, PLANK_D], 8));
  const crates = new Shape();
  for (const [x, z, h] of [[2, 2, 16], [20, 4, 14], [8, 20, 12], [6, 6, 30]]) crates.box(x, h > 16 ? 17 : 0, z, x + 14, h > 16 ? 30 : h, z + 14, PLANK);
  add("crates", paint(crates, PLANK, [PLANK, PLANK_D, WOOD_L], 10));
  add("tree_oak", treeOak(21));
  add("tree_pine", treePine(23));
  const bush = new Shape();
  for (const [cx, cz, r] of [[9, 9, 9], [15, 6, 6], [5, 14, 6]]) ellipsoid(bush, [cx, 5, cz], [r, r * 0.8, r], LEAF);
  carve(bush, (t) => roundBox(t, [-20, -20, -20], [40, -1, 40], 0, 1));
  add("bush", paint(bush, LEAF, [LEAF, LEAF_D, LEAF_L], 25), { footprint: [] });
  add("rock_small", rock(9, 8, 8, 27));
  add("rock_large", rock(26, 22, 22, 29));
  const stump = new Shape();
  cylinder(stump, [9.5, 0, 9.5], [9.5, 8, 9.5], 6, BARK);
  stump.box(5, 8, 5, 14, 8, 14, WOOD_L);
  add("stump", paint(stump, BARK, [BARK, BARK_D], 30));
  const bridge = new Shape();
  for (let x = 0; x < 80; x++) bridge.box(x, 4, 2, x, 5, 37, x % 4 === 0 ? PLANK_D : PLANK);
  for (const z of [1, 38]) { bridge.box(0, 6, z, 79, 18, z, 0); bridge.box(0, 17, z, 79, 18, z, WOOD); for (let x = 0; x < 80; x += 10) bridge.box(x, 0, z, x + 1, 18, z, WOOD); }
  for (const v of [...bridge.cells.values()]) if (v[3] === 0) bridge.cells.delete(`${v[0]},${v[1]},${v[2]}`);
  add("bridge", bridge, { footprint: [] });
  // A signpost at each way out of a zone (Plan 8.1.1): a post and a board.
  const sign = new Shape();
  sign.box(8, 0, 8, 11, 44, 11, WOOD);
  sign.box(0, 30, 7, 19, 39, 8, PLANK).box(0, 30, 9, 19, 39, 9, PLANK_D);
  sign.box(-6, 31, 7, -1, 38, 8, PLANK).put(-7, 34, 7, PLANK).put(-7, 35, 7, PLANK); // arrow tip
  add("signpost", paint(sign, WOOD, [WOOD, WOOD_D], 45), { footprint: [[0, 0]] });
  const torch = new Shape();
  torch.box(7, 0, 7, 11, 1, 11, IRON).box(8, 2, 8, 9, 25, 9, WOOD).box(7, 26, 7, 10, 26, 10, IRON);
  torch.box(6, 27, 6, 11, 29, 11, IRON).remove(7, 27, 7, 10, 29, 10).box(7, 27, 7, 10, 27, 10, COAL).box(8, 28, 8, 9, 29, 9, GLOW);
  add("torch", torch, { footprint: [] });
  const arch = new Shape();
  roundBox(arch, [0, 0, 6], [79, 70, 25], 1, STONE);
  carve(arch, (t) => { roundBox(t, [16, 0, 0], [63, 48, 40], 0, 1); ellipsoid(t, [39.5, 48, 15], [23.5, 16, 30], 1); });
  add("crypt_arch", paint(arch, STONE, [STONE, STONE_D, STONE_L], 31), {
    footprint: [[0, 0], [0, 1], [3, 0], [3, 1]],
  });
  const cwall = new Shape();
  cwall.box(0, 0, 0, 39, 64, 19, STONE);
  for (let y = 8; y < 64; y += 10) cwall.box(0, y, 0, 39, y, 0, STONE_D); // courses of stone
  add("crypt_wall", paint(cwall, STONE, [STONE, STONE_D, STONE_L], 33));
  const pillar = new Shape();
  cylinder(pillar, [9.5, 0, 9.5], [9.5, 70, 9.5], 7, STONE);
  pillar.box(1, 0, 1, 18, 4, 18, STONE).box(1, 66, 1, 18, 70, 18, STONE);
  add("crypt_pillar", paint(pillar, STONE, [STONE, STONE_D, STONE_L], 35));
  return out;
}

// The cells a piece blocks: 1 m cells holding a voxel under BASE_H, sorted.
export function footprintOf(piece) {
  if (piece.footprint && piece.shape === undefined) return piece.footprint;
  const cells = new Set();
  for (const [x, y, z] of piece.shape.cells.values()) {
    if (y < BASE_H) cells.add(`${Math.floor(x / CELL)},${Math.floor(z / CELL)}`);
  }
  return [...cells].map((k) => k.split(",").map(Number)).sort((a, b) => a[0] - b[0] || a[1] - b[1]);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [outDir, jsonPath] = process.argv.slice(2);
  if (!outDir || !jsonPath) {
    console.error("usage: node make_world.mjs <out dir> <pieces.json path>");
    process.exit(1);
  }
  fs.mkdirSync(outDir, { recursive: true });
  const table = {};
  for (const [id, p] of Object.entries(worldPieces())) {
    if (p.parts) {
      const parts = {};
      for (const [part, sh] of Object.entries(p.parts)) {
        write(`${outDir}/${id}_${part}.vox`, sh.size(), sh.voxels(), PALETTE);
        parts[part] = { vox: `res://assets/world/${id}_${part}.vox`, offset: sh.min() };
      }
      table[id] = { parts, scale: 1.0, footprint: p.footprint, interior: p.interior, door: p.door, lights: p.lights,
        shadow: "medium", range: 90 };
      continue;
    }
    write(`${outDir}/${id}.vox`, p.shape.size(), p.shape.voxels(), PALETTE);
    const small = SMALL_PIECES.includes(id);
    table[id] = { vox: `res://assets/world/${id}.vox`, scale: 0.5, offset: p.shape.min(), footprint: p.footprint,
      shadow: small ? "never" : "medium", range: small ? 55 : 90 };
  }
  fs.writeFileSync(jsonPath, JSON.stringify(table, null, "\t") + "\n");
  console.log(`wrote ${Object.keys(table).length} world pieces and ${jsonPath}`);
}
