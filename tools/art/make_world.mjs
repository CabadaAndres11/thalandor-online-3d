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

const WOOD = 1, WOOD_D = 2, WOOD_L = 3, PLANK = 4, PLANK_D = 5, THATCH = 6, THATCH_D = 7, THATCH_L = 8,
  STONE = 9, STONE_D = 10, STONE_L = 11, MOSS = 12, LEAF = 13, LEAF_D = 14, LEAF_L = 15, PINE = 16, PINE_D = 17,
  BARK = 18, BARK_D = 19, IRON = 20, IRON_L = 21, PLASTER = 22, PLASTER_D = 23, WATER = 24, COAL = 25, HAY = 26;
const PALETTE = {
  [WOOD]: "#6b4528", [WOOD_D]: "#4b2f1b", [WOOD_L]: "#86593a", [PLANK]: "#8a6a45", [PLANK_D]: "#6d5133",
  [THATCH]: "#b08d4a", [THATCH_D]: "#8a6c33", [THATCH_L]: "#caa85f", [STONE]: "#7d7870", [STONE_D]: "#5d5953",
  [STONE_L]: "#99948a", [MOSS]: "#55683a", [LEAF]: "#3f7a32", [LEAF_D]: "#2c5a24", [LEAF_L]: "#5a9640",
  [PINE]: "#2e5a36", [PINE_D]: "#1f4027", [BARK]: "#5a4030", [BARK_D]: "#3f2c20", [IRON]: "#3a3a40",
  [IRON_L]: "#62626b", [PLASTER]: "#d8ccb2", [PLASTER_D]: "#b8aa8e", [WATER]: "#3d6f8f", [COAL]: "#22160f",
  [HAY]: "#d1b060", [GLOW]: "#ffb347",
};

// Two or three tones of a material mixed per voxel.
function paint(s, from, tones, seed) {
  for (const v of s.cells.values()) {
    if (v[3] !== from) continue;
    const n = noise3(v[0], v[1], v[2], seed);
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

// A village house of w × d cells: timber frame on stone footing, plaster walls, a door
// on the front (+Z), small windows and a thatched roof.
function house(w, d, extra = () => {}) {
  const s = new Shape();
  const W = w * CELL - 1, D = d * CELL - 1, H = 52;
  s.box(0, 0, 0, W, 5, D, STONE); // footing
  paint(s, STONE, [STONE, STONE_D, STONE_L], 3);
  s.box(1, 6, 1, W - 1, H, D - 1, PLASTER);
  s.remove(3, 6, 3, W - 3, H, D - 3); // hollow
  paint(s, PLASTER, [PLASTER, PLASTER_D], 5);
  for (const x of [1, W - 1, Math.round(W / 2)]) s.box(x, 6, 1, x, H, 1, WOOD).box(x, 6, D - 1, x, H, D - 1, WOOD); // posts
  for (const z of [1, D - 1]) s.box(1, 6, z, W - 1, 7, z, WOOD).box(1, H - 1, z, W - 1, H, z, WOOD); // beams
  for (const x of [1, W - 1]) s.box(x, 6, 1, x, 7, D - 1, WOOD).box(x, H - 1, 1, x, H, D - 1, WOOD);
  const door = Math.round(W / 2) - 6;
  s.remove(door, 6, D - 2, door + 9, 32, D); // doorway
  s.box(door, 6, D - 3, door + 9, 32, D - 3, PLANK); // the door, set back
  paint(s, PLANK, [PLANK, PLANK_D], 9);
  for (const x of [8, W - 16]) { s.remove(x, 26, D - 1, x + 7, 34, D - 1); s.box(x, 25, D, x + 7, 25, D, WOOD); } // windows
  roof(s, 0, W, 0, D, H + 1);
  extra(s, W, D, H);
  return s;
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
  add("house_small", house(4, 4));
  add("house_large", house(6, 5));
  add("house_forge", house(5, 5, (s, W, D) => {
    roundBox(s, [W - 18, 0, 4], [W - 6, 90, 14], 1, STONE); // chimney
    paint(s, STONE, [STONE, STONE_D, STONE_L], 13);
    s.box(8, 6, D + 2, 18, 14, D + 8, IRON).box(6, 15, D + 1, 20, 17, D + 9, IRON_L); // anvil
    s.box(W - 30, 6, D + 1, W - 22, 12, D + 9, STONE).box(W - 29, 13, D + 2, W - 23, 13, D + 8, COAL);
    s.put(W - 27, 14, D + 5, GLOW).put(W - 25, 14, D + 4, GLOW);
  }));
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
    write(`${outDir}/${id}.vox`, p.shape.size(), p.shape.voxels(), PALETTE);
    table[id] = { vox: `res://assets/world/${id}.vox`, scale: 0.5, offset: p.shape.min(), footprint: p.footprint };
  }
  fs.writeFileSync(jsonPath, JSON.stringify(table, null, "\t") + "\n");
  console.log(`wrote ${Object.keys(table).length} world pieces and ${jsonPath}`);
}
