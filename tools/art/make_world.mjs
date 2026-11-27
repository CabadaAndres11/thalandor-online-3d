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
// Ground details (Plan 8.1.3): tiny, no shadow, only seen up close; ZoneView sows them.
export const DECOR = ["grass_tuft", "flower_blue", "flower_white", "flower_yellow", "pebbles"];

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
  [29]: "#9a4a32", [30]: "#7a3826", [31]: "#b8644a", [32]: "#4f7fd6", [33]: "#eeeae0", [34]: "#e8c73a",
  [35]: "#5f9a40", [36]: "#477a30", [37]: "#7fb552",
  [38]: "#3a3530", [39]: "#5b4632", [40]: "#c8bc9a", [41]: "#a89b78", [42]: "#2f4f8f", [43]: "#d4a62a",
  [44]: "#b9b2a4", [45]: "#9b9486", [46]: "#8a2a2a", [47]: "#6a1e1e", [48]: "#7a5232",
  [49]: "#e6e0d0", [50]: "#c9c1ac", [51]: "#f4efe2", [52]: "#3c7a38", [53]: "#2c5e2a", [54]: "#5d86bd", [55]: "#e29ac0", [56]: "#2e4f8f",
};
// Plan 8.3b: city stone (light and dark), the palace red (light and dark) and a horse's coat.
const CSTONE = 44, CSTONE_D = 45, RED = 46, RED_D = 47, HORSE = 48;
// Plan 8.3a: ash, earth, army canvas (light and dark), the kingdom's blue and gold.
// Plan 8.3f: marble (base, dark, light), garden greens, a pink flower, window glass, a darker blue.
const MARBLE = 49, MARBLE_D = 50, MARBLE_L = 51, HEDGE = 52, HEDGE_D = 53, GLASS = 54, FLOWER_P = 55, ROYAL_D = 56;
const ASH = 38, EARTH = 39, CANVAS = 40, CANVAS_D = 41, ROYAL = 42, ROYAL_GOLD = 43;

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
const BRICK = 29, BRICK_D = 30, BRICK_L = 31, FLOWER_B = 32, FLOWER_W = 33, FLOWER_Y = 34, GRASS = 35, GRASS_D = 36, GRASS_L = 37;

// Bricks: courses of 2 voxels, staggered joints in mortar-dark tone.
function brick(s, x0, y0, z0, x1, y1, z1) {
  for (let x = x0; x <= x1; x++) for (let y = y0; y <= y1; y++) for (let z = z0; z <= z1; z++) {
    const course = Math.floor(y / 2);
    const along = (x1 - x0 >= z1 - z0 ? x : z) + (course % 2) * 2;
    s.put(x, y, z, y % 2 === 0 || along % 4 === 0 ? BRICK_D : (noise3(x >> 1, y >> 1, z >> 1, 3) > 0.7 ? BRICK_L : BRICK));
  }
  return s;
}

// A roof of planks (instead of thatch): the same gable, in boards with dark seams.
function plankRoof(s) {
  for (const v of s.cells.values()) {
    if (v[3] === THATCH || v[3] === THATCH_D || v[3] === THATCH_L) v[3] = v[0] % 4 === 0 ? PLANK_D : (v[3] === THATCH_D ? WOOD : PLANK);
  }
  return s;
}

function houseParts(w, d, furnish = () => {}, style = {}) {
  const C = HOUSE_CELL, W = w * C, D = d * C, HH = style.tall ? HOUSE_H * 2 : HOUSE_H;
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
  walls.box(0, 1, 0, W - 1, HH, 2, PLASTER).box(0, 1, D - 3, W - 1, HH, D - 1, PLASTER);
  walls.box(0, 1, 0, 2, HH, D - 1, PLASTER).box(W - 3, 1, 0, W - 1, HH, D - 1, PLASTER);
  paint(walls, PLASTER, [PLASTER, PLASTER_D], 5);
  // Plan 8.3d: the village's other houses. Logs: horizontal trunks; beams: timber framing
  // over the plaster; barn: vertical boards.
  if (style.logs) for (const v of walls.cells.values()) v[3] = v[1] % 4 === 0 ? WOOD_D : (v[1] % 4 === 2 ? WOOD_L : WOOD);
  if (style.barn) for (const v of walls.cells.values()) v[3] = (v[0] + v[2]) % 5 === 0 ? PLANK_D : PLANK;
  if (style.beams) for (const v of walls.cells.values()) {
    if (v[3] !== PLASTER && v[3] !== PLASTER_D) continue;
    const along = (v[2] <= 2 || v[2] >= D - 3) ? v[0] : v[2];
    if (along % 12 < 2 || v[1] === HOUSE_H || v[1] === HOUSE_H + 1 || (along % 12 - 2) === Math.floor(((v[1] - 1) % HOUSE_H) / 3)) v[3] = WOOD_D;
  }
  if (style.stone) { // the forge (Plan 8.1.3): rough stone, darker at the foot
    for (const v of walls.cells.values()) v[3] = v[1] < 6 ? STONE_D : STONE;
    paint(walls, STONE, [STONE, STONE_D, STONE_L], 51);
  }
  for (const x of [0, W - 3]) for (const z of [0, D - 3]) walls.box(x, 1, z, x + 2, HH, z + 2, WOOD);
  for (const y of style.tall ? [1, HOUSE_H, HH] : [1, HH]) {
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
  roof(roofShape, 0, W - 1, 0, D - 1, HH + 1, 3);
  // The gable ends under the roof are closed (plaster with a timber edge); they belong to
  // the roof, so they go with it when the house opens.
  {
    const half = (D - 1) / 2 + 3, mid = (D - 1) / 2;
    for (let h = 0; h <= half; h++) {
      const z0 = Math.round(mid - half + h) + 1, z1 = Math.round(mid + half - h) - 1;
      for (const x of [0, 1, 2, W - 3, W - 2, W - 1]) for (let z = Math.max(z0, 0); z <= Math.min(z1, D - 1); z++) {
        roofShape.put(x, HH + 1 + h, z, z === Math.max(z0, 0) || z === Math.min(z1, D - 1) ? WOOD : (style.stone ? STONE : PLASTER));
      }
    }
    paint(roofShape, PLASTER, [PLASTER, PLASTER_D], 47);
    paint(roofShape, STONE, [STONE, STONE_D, STONE_L], 49);
  }
  if (style.planks) plankRoof(roofShape);
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
// A brick furnace against the back wall: an arched mouth full of embers, and (the first)
// a brick chimney up through the roof with an iron cap.
function furnace(f, cx, cz, chimney) {
  const x0 = cx * f.C, z0 = cz * f.C;
  brick(f.floor, x0, 1, z0, x0 + 9, 16, z0 + 8);
  f.floor.remove(x0 + 2, 1, z0 + 4, x0 + 7, 7, z0 + 8); // the mouth
  for (let x = x0 + 3; x <= x0 + 6; x++) f.floor.put(x, 8, z0 + 8, BRICK_D);
  f.floor.box(x0 + 2, 1, z0 + 4, x0 + 7, 1, z0 + 7, COAL);
  for (const [x, z] of [[3, 5], [5, 6], [4, 7], [6, 5]]) f.floor.put(x0 + x, 2, z0 + z, GLOW);
  if (chimney) {
    brick(f.roof, x0 + 2, 31, z0 + 1, x0 + 7, 66, z0 + 6);
    f.roof.box(x0 + 1, 67, z0, x0 + 8, 68, z0 + 7, IRON).box(x0 + 3, 69, z0 + 2, x0 + 6, 72, z0 + 5, IRON_L);
  }
  f.lights.push([cx, cz]);
  f.block(cx, cz);
}
function bellows(f, cx, cz) {
  const x0 = cx * f.C, z0 = cz * f.C;
  f.floor.box(x0 + 2, 1, z0 + 2, x0 + 7, 4, z0 + 7, WOOD).box(x0 + 3, 5, z0 + 3, x0 + 6, 7, z0 + 6, CLOTH_D);
  f.floor.box(x0 + 4, 4, z0, x0 + 5, 5, z0 + 1, IRON);
  f.block(cx, cz);
}
function toolRack(f, cx, cz) {
  const x0 = cx * f.C, z0 = cz * f.C;
  f.floor.box(x0 + 1, 1, z0 + 1, x0 + 8, 20, z0 + 2, WOOD);
  for (const x of [2, 4, 6]) f.floor.box(x0 + x, 10, z0 + 3, x0 + x, 17, z0 + 3, IRON_L).put(x0 + x, 17, z0 + 4, IRON);
  f.block(cx, cz);
}
function workbench(f, cx, cz) {
  const x0 = cx * f.C, z0 = cz * f.C;
  f.floor.box(x0 + 1, 7, z0 + 1, x0 + 8, 8, z0 + 8, PLANK).box(x0 + 1, 5, z0 + 2, x0 + 8, 6, z0 + 7, WOOD);
  for (const x of [1, 8]) for (const z of [1, 8]) f.floor.box(x0 + x, 1, z0 + z, x0 + x, 6, z0 + z, WOOD_D);
  f.floor.box(x0 + 4, 6, z0 + 7, x0 + 5, 6, z0 + 7, IRON); // drawer handle
  f.block(cx, cz);
}
function anvilStump(f, cx, cz) {
  const x0 = cx * f.C, z0 = cz * f.C;
  cylinder(f.floor, [x0 + 4.5, 1, z0 + 4.5], [x0 + 4.5, 6, z0 + 4.5], 3.4, BARK);
  f.floor.box(x0 + 3, 7, z0 + 3, x0 + 6, 8, z0 + 6, IRON).box(x0 + 1, 9, z0 + 3, x0 + 8, 10, z0 + 6, IRON).box(x0 + 1, 10, z0 + 4, x0 + 2, 10, z0 + 5, IRON_L);
  f.floor.box(x0 + 5, 11, z0 + 4, x0 + 7, 11, z0 + 4, WOOD).put(x0 + 4, 11, z0 + 4, IRON_L); // a hammer
  f.block(cx, cz);
}

// The open shed beside the forge (Plan 8.1.3, after the user's reference): posts and a
// plank roof, cobbles, a brick wall at the back and on the right, an outdoor forge, an
// anvil on a stump, a workbench and a water barrel. A house without front or left wall.
function shedParts(w, d) {
  const C = HOUSE_CELL, W = w * C, D = d * C, H = 26;
  const floor = new Shape(), walls = new Shape(), roofShape = new Shape();
  for (let x = 0; x < W; x++) for (let z = 0; z < D; z++) { // cobbles: stones with dark joints
    const j = (x % 4 === 0) || ((z + (Math.floor(x / 4) % 2) * 2) % 4 === 0);
    floor.put(x, 0, z, j ? STONE_D : (noise3(x >> 2, 0, z >> 2, 9) > 0.6 ? STONE_L : STONE));
  }
  brick(walls, 0, 1, 0, W - 1, H, 2); // back wall
  brick(walls, W - 3, 1, 0, W - 1, H, D - 1); // right wall
  for (const [x, z] of [[0, D - 3], [0, 0]]) walls.box(x, 1, z, x + 2, H + 2, z + 2, WOOD); // posts
  walls.box(W - 3, 1, D - 3, W - 1, H + 2, D - 1, WOOD);
  walls.box(0, H, D - 3, W - 1, H + 1, D - 1, WOOD).box(0, H, 0, 2, H + 1, D - 1, WOOD); // beams
  paint(walls, WOOD, [WOOD, WOOD_D, WOOD_L], 53);
  const cut = new Shape();
  for (const v of walls.cells.values()) if (v[1] <= CUT_H) cut.put(v[0], v[1], v[2], v[3]);
  // A flat roof of boards falling to the front, overhanging all round.
  for (let x = -2; x <= W + 1; x++) for (let z = -2; z <= D + 2; z++) {
    const y = H + 4 - Math.floor((z + 2) / 8);
    roofShape.put(x, y, z, x % 5 === 0 ? PLANK_D : PLANK).put(x, y - 1, z, WOOD);
  }
  const blocked = new Set();
  const block = (cx, cz) => blocked.add(cx + "," + cz);
  const lights = [];
  const f = { floor, roof: roofShape, W, D, C, block, lights };
  workbench(f, 0, 1);
  anvilStump(f, 2, 1);
  furnace(f, w - 2, 1, false);
  barrel(f, w - 2, 2);
  block(0, d - 1); // the front post
  const footprint = [], interior = [], door = [];
  for (let x = 0; x < w; x++) for (let z = 0; z < d; z++) {
    if (z === 0 || x === w - 1) { footprint.push([x, z]); continue; } // brick walls
    interior.push([x, z]);
    if (blocked.has(x + "," + z)) footprint.push([x, z]);
    else if (z === d - 1) door.push([x, z]);
  }
  footprint.sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  return { parts: { floor, walls, walls_cut: cut, roof: roofShape }, footprint, interior, door, lights };
}

// Ground details (Plan 8.1.3), at 5 cm voxels: a tuft of grass blades, flowers, pebbles.
function grassTuft(seed) {
  const s = new Shape();
  for (let i = 0; i < 7; i++) {
    const x = 2 + Math.floor(noise3(i, 1, seed, 1) * 6), z = 2 + Math.floor(noise3(i, 2, seed, 1) * 6);
    const h = 2 + Math.floor(noise3(i, 3, seed, 1) * 4);
    for (let y = 0; y < h; y++) s.put(x, y, z, y === h - 1 ? GRASS_L : (y < 1 ? GRASS_D : GRASS));
  }
  return s;
}
function flower(petal) {
  const s = new Shape();
  s.box(4, 0, 4, 4, 4, 4, GRASS_D).put(5, 1, 4, GRASS).put(3, 2, 4, GRASS);
  s.put(4, 6, 4, FLOWER_Y === petal ? WOOD_L : FLOWER_Y);
  for (const [dx, dz] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) s.put(4 + dx, 5, 4 + dz, petal);
  s.put(4, 5, 4, petal);
  return s;
}
function pebbles() {
  const s = new Shape();
  for (const [x, z, w, d] of [[1, 1, 2, 2], [5, 2, 3, 2], [3, 5, 2, 3], [7, 6, 1, 1]]) s.box(x, 0, z, x + w - 1, 0, z + d - 1, noise3(x, 0, z, 5) > 0.5 ? STONE_L : STONE);
  s.box(5, 1, 2, 6, 1, 2, STONE_L);
  return s;
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

// A house after the assault (Plan 8.3a): the same house with the walls burnt down to
// ragged stumps, the roof gone but for a few charred beams, and ash on the floor. The cells
// it blocks are the healthy house's, so the ruins stand where the houses stood.
function burntHouse(h, seed) {
  const { floor, walls, roof: roofShape } = h.parts;
  const W = Math.max(...[...floor.cells.values()].map((v) => v[0])) + 1;
  const D = Math.max(...[...floor.cells.values()].map((v) => v[2])) + 1;
  for (const v of [...walls.cells.values()]) {
    const top = 6 + Math.floor(noise3(v[0] >> 2, 0, v[2] >> 2, seed) * 22);
    if (v[1] > top) { walls.cells.delete(`${v[0]},${v[1]},${v[2]}`); continue; }
    const n = noise3(v[0] >> 1, v[1] >> 1, v[2] >> 1, seed + 1);
    v[3] = v[3] === WOOD || v[1] > top - 3 ? COAL : (n < 0.45 ? ASH : n < 0.7 ? STONE_D : v[3]);
  }
  const cut = new Shape();
  for (const v of walls.cells.values()) if (v[1] <= CUT_H) cut.put(v[0], v[1], v[2], v[3]);
  const beams = new Shape();
  for (const v of roofShape.cells.values()) if (v[3] === STONE || v[3] === STONE_D || v[3] === STONE_L) beams.put(v[0], Math.min(v[1], 40), v[2], STONE_D);
  for (const x of [3, W - 6]) beams.box(x, HOUSE_H - 2, 1, x + 2, HOUSE_H, D - 2, COAL); // two beams still across
  for (let i = 0; i < W - 6; i++) beams.put(4 + i, 2 + Math.floor(i * 0.25), Math.floor(D / 2), COAL).put(4 + i, 2 + Math.floor(i * 0.25), Math.floor(D / 2) + 1, COAL); // one fallen in
  for (const v of floor.cells.values()) {
    if (v[1] > 0) { v[3] = noise3(v[0], v[1], v[2], seed + 2) > 0.4 ? COAL : WOOD_D; continue; }
    const n = noise3(v[0] >> 1, 0, v[2] >> 1, seed + 3);
    if (n > 0.55) v[3] = ASH; else if (n < 0.15) v[3] = COAL;
  }
  for (let i = 0; i < 6; i++) floor.put(5 + Math.floor(noise3(i, 1, seed, 4) * (W - 10)), 1, 5 + Math.floor(noise3(i, 2, seed, 4) * (D - 10)), GLOW); // embers
  return { ...h, parts: { floor, walls, walls_cut: cut, roof: beams }, lights: [] };
}

// Charred planks and broken stones, a low heap that blocks its cells.
function rubbleHeap(seed) {
  const s = new Shape();
  for (const [cx, cz, r] of [[12, 14, 10], [26, 22, 9], [18, 28, 7]]) ellipsoid(s, [cx, 0, cz], [r, r * 0.6, r], STONE);
  carve(s, (t) => roundBox(t, [-20, -20, -20], [60, -1, 60], 0, 1));
  paint(s, STONE, [STONE, STONE_D, ASH], seed);
  for (const [x, z, len, dir] of [[4, 8, 26, 0], [10, 30, 22, 1], [20, 6, 18, 0]]) {
    for (let i = 0; i < len; i++) s.box(dir ? x + 1 : x + i, 5 + (i % 7 === 0 ? 1 : 0), dir ? z - i : z, dir ? x + 2 : x + i, 6, dir ? z - i : z + 1, i % 3 ? COAL : WOOD_D);
  }
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
  addHouse("house_forge", houseParts(7, 7, (f) => {
    furnace(f, 1, 1, true); furnace(f, 5, 1, false); bellows(f, 3, 1); toolRack(f, 5, 4); barrel(f, 1, 5);
  }, { stone: true, planks: true }));
  addHouse("forge_shed", shedParts(6, 4));
  add("grass_tuft", grassTuft(3), { footprint: [] });
  add("flower_blue", flower(FLOWER_B), { footprint: [] });
  add("flower_white", flower(FLOWER_W), { footprint: [] });
  add("flower_yellow", flower(FLOWER_Y), { footprint: [] });
  add("pebbles", pebbles(), { footprint: [] });
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
  for (let x = 0; x < 160; x++) bridge.box(x, 4, 2, x, 5, 37, x % 4 === 0 ? PLANK_D : PLANK);
  for (const z of [1, 38]) { bridge.box(0, 6, z, 159, 18, z, 0); bridge.box(0, 17, z, 159, 18, z, WOOD); for (let x = 0; x < 160; x += 10) bridge.box(x, 0, z, x + 1, 18, z, WOOD); }
  for (const v of [...bridge.cells.values()]) if (v[3] === 0) bridge.cells.delete(`${v[0]},${v[1]},${v[2]}`);
  // The deck (8 m x 2 m) is walkable even over water (the zone clears those cells).
  add("bridge", bridge, { footprint: [], deck: Array.from({ length: 16 }, (_, i) => [i >> 1, i & 1]) });
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
  // The wooden sparring dummy of the prologue (Plan 8.3a): a cross base, a post, a straw body
  // tied with rope, a straw head and two wooden arms.
  const dummy = new Shape();
  dummy.box(2, 0, 8, 17, 2, 11, WOOD_D).box(8, 0, 2, 11, 2, 17, WOOD_D);
  dummy.box(8, 2, 8, 11, 40, 11, WOOD);
  ellipsoid(dummy, [9.5, 26, 9.5], [6, 9, 5], THATCH);
  ellipsoid(dummy, [9.5, 40, 9.5], [4.5, 4.5, 4.5], THATCH_L);
  for (const y of [20, 31]) dummy.box(3, y, 4, 16, y, 15, WOOD_D);
  dummy.box(-4, 29, 8, 23, 31, 10, WOOD).box(-5, 27, 8, -3, 31, 10, WOOD_D).box(22, 27, 8, 24, 31, 10, WOOD_D);
  add("training_dummy", paint(dummy, THATCH, [THATCH, THATCH_D, THATCH_L], 41), { footprint: [[0, 0]] });

  // --- The road and the capital (Plan 8.3b) ---
  // The city wall: 2 m of dressed stone, 4 m high, with merlons.
  const cityWall = new Shape();
  cityWall.box(0, 0, 4, 39, 72, 15, CSTONE);
  for (let x = 0; x < 40; x += 10) cityWall.box(x, 73, 4, x + 5, 80, 15, CSTONE);
  for (let y = 10; y < 72; y += 12) cityWall.box(0, y, 4, 39, y, 4, CSTONE_D);
  add("city_wall", paint(cityWall, CSTONE, [CSTONE, CSTONE_D], 91));
  // The cityGate: two towers and an arch over a 3 m way through (cells 1-3 stay free).
  const cityGate = new Shape();
  for (const x0 of [0, 80]) { cityGate.box(x0, 0, 0, x0 + 19, 100, 19, CSTONE); for (let x = x0; x < x0 + 20; x += 8) cityGate.box(x, 101, 0, x + 4, 108, 19, CSTONE); }
  cityGate.box(20, 64, 4, 79, 84, 15, CSTONE);
  ellipsoid(cityGate, [49.5, 64, 9.5], [30, 10, 6], 0);
  for (const v of [...cityGate.cells.values()]) if (v[3] === 0) cityGate.cells.delete(`${v[0]},${v[1]},${v[2]}`);
  cityGate.box(42, 86, 2, 57, 99, 3, ROYAL).box(48, 90, 1, 51, 95, 1, ROYAL_GOLD);
  add("city_gate", paint(cityGate, CSTONE, [CSTONE, CSTONE_D], 93), { footprint: [[0, 0], [4, 0]] });
  // A two-storey stone house of the capital, walkable like the village's.
  addHouse("house_city", houseParts(7, 6, (f) => { table(f, 2, 2, 2); shelf(f, 5, 1); chest(f, 5, 3); }, { stone: true, tall: true, planks: true }));
  // Two more interiors so the capital's houses differ: a home with a hearth, and a bedroom.
  addHouse("house_city_b", houseParts(7, 6, (f) => { hearth(f, 3, 1); bed(f, 1, 1); shelf(f, 5, 1); chest(f, 5, 3); }, { stone: true, tall: true, planks: true }));
  addHouse("house_city_c", houseParts(7, 6, (f) => { bed(f, 1, 1); bed(f, 5, 1); table(f, 2, 2, 2); chest(f, 1, 4); }, { stone: true, tall: true, planks: true }));
  // A market stall: a counter, four posts and a striped awning; goods on the counter.
  const stall = new Shape();
  stall.box(2, 0, 10, 37, 16, 17, PLANK).box(2, 16, 9, 37, 17, 18, PLANK_D);
  for (const [x, z] of [[2, 2], [36, 2], [2, 17], [36, 17]]) stall.box(x, 0, z, x + 1, 44, z + 1, WOOD);
  for (let x = 0; x < 40; x++) for (let z = 0; z < 22; z++) stall.put(x, 45 + Math.floor((21 - z) / 7), z, Math.floor(x / 5) % 2 ? FLOWER_W : CLOTH);
  for (let x = 5; x < 36; x += 7) ellipsoid(stall, [x, 19, 13.5], [2.5, 2, 2.5], x % 2 ? HAY : CLOTH);
  add("market_stall", paint(stall, PLANK, [PLANK, PLANK_D], 95));
  // The fountain of the square: a round basin, water and a column with a bowl.
  const fountain = new Shape();
  cylinder(fountain, [29.5, 0, 29.5], [29.5, 12, 29.5], 28, CSTONE);
  cylinder(fountain, [29.5, 3, 29.5], [29.5, 13, 29.5], 25, 0);
  for (const v of [...fountain.cells.values()]) if (v[3] === 0) fountain.cells.delete(`${v[0]},${v[1]},${v[2]}`);
  cylinder(fountain, [29.5, 3, 29.5], [29.5, 9, 29.5], 25, WATER);
  cylinder(fountain, [29.5, 0, 29.5], [29.5, 40, 29.5], 3, CSTONE);
  cylinder(fountain, [29.5, 40, 29.5], [29.5, 43, 29.5], 9, CSTONE_D);
  cylinder(fountain, [29.5, 43, 29.5], [29.5, 44, 29.5], 7, WATER);
  add("fountain", paint(fountain, CSTONE, [CSTONE, CSTONE_D], 97));
  // A street cityLamp of the city: an iron post and a glowing cage.
  const cityLamp = new Shape();
  cityLamp.box(7, 0, 7, 12, 2, 12, CSTONE_D).box(9, 3, 9, 10, 54, 10, IRON).box(6, 55, 6, 13, 55, 13, IRON).box(6, 64, 6, 13, 64, 13, IRON).box(7, 56, 7, 12, 63, 12, GLOW).box(8, 65, 8, 11, 67, 11, IRON_L);
  for (const [x, z] of [[6, 6], [13, 6], [6, 13], [13, 13]]) cityLamp.box(x, 56, z, x, 63, z, IRON);
  add("city_lamp", cityLamp, { footprint: [[0, 0]] });
  // The palace: a column 6 m high, a red carpet, the throne on its dais, braziers and the crypt's cityGate.
  const column = new Shape();
  cylinder(column, [9.5, 4, 9.5], [9.5, 116, 9.5], 7, CSTONE);
  column.box(0, 0, 0, 19, 4, 19, CSTONE_D).box(0, 116, 0, 19, 120, 19, CSTONE_D);
  for (let y = 10; y < 116; y += 3) for (let a = 0; a < 8; a++) column.put(Math.round(9.5 + Math.cos(a * Math.PI / 4) * 7), y, Math.round(9.5 + Math.sin(a * Math.PI / 4) * 7), CSTONE_D);
  add("palace_column", column, { footprint: [[0, 0]] });
  const carpet = new Shape();
  carpet.box(0, 0, 0, 39, 0, 79, RED);
  for (const x of [1, 38]) carpet.box(x, 0, 0, x, 0, 79, ROYAL_GOLD);
  for (let z = 6; z < 80; z += 14) carpet.box(16, 0, z, 23, 0, z + 2, RED_D);
  add("palace_carpet", carpet, { footprint: [] });
  const throne = new Shape();
  throne.box(0, 0, 0, 39, 4, 39, CSTONE).box(4, 5, 0, 35, 8, 30, CSTONE_D);
  throne.box(10, 9, 8, 29, 18, 24, ROYAL_GOLD).box(12, 19, 8, 27, 20, 22, RED);
  throne.box(10, 9, 4, 29, 64, 8, ROYAL_GOLD).box(13, 22, 8, 26, 58, 9, RED);
  throne.box(17, 64, 4, 22, 72, 8, ROYAL_GOLD);
  for (const x of [8, 29]) throne.box(x, 18, 8, x + 2, 28, 24, ROYAL_GOLD);
  add("throne", throne);
  const brazier = new Shape();
  brazier.box(8, 0, 8, 11, 26, 11, IRON);
  cylinder(brazier, [9.5, 26, 9.5], [9.5, 31, 9.5], 7, IRON);
  cylinder(brazier, [9.5, 30, 9.5], [9.5, 31, 9.5], 6, COAL);
  for (let i = 0; i < 18; i++) brazier.put(6 + (i * 7) % 8, 32 + (i % 4), 6 + (i * 5) % 8, GLOW);
  add("brazier", brazier, { footprint: [[0, 0]] });
  const gatePosts = (sh) => { for (const x0 of [0, 40]) sh.box(x0, 0, 6, x0 + 19, 90, 13, STONE_D); sh.box(20, 80, 6, 39, 90, 13, STONE_D); };
  const shut = new Shape();
  gatePosts(shut);
  for (let x = 21; x < 40; x += 4) shut.box(x, 0, 9, x + 1, 79, 10, IRON);
  for (let y = 10; y < 80; y += 18) shut.box(20, y, 9, 39, y + 1, 10, IRON_L);
  add("crypt_gate_closed", paint(shut, STONE_D, [STONE_D, STONE], 99), { footprint: [[0, 0], [2, 0]] });
  const raised = new Shape();
  gatePosts(raised);
  for (let x = 21; x < 40; x += 4) raised.box(x, 70, 9, x + 1, 79, 10, IRON);
  add("crypt_gate_open", paint(raised, STONE_D, [STONE_D, STONE], 99), { footprint: [[0, 0], [2, 0]] });
  // Plan 8.3f: the palace in marble and gardens: a wall block, a hedge and the palace seen from the city.
  const pwall = new Shape();
  pwall.box(0, 0, 0, 39, 64, 19, MARBLE).box(0, 60, 0, 39, 63, 19, MARBLE_L).box(0, 64, 0, 39, 66, 19, ROYAL_GOLD);
  for (let y = 8; y < 60; y += 10) pwall.box(0, y, 0, 39, y, 0, MARBLE_D);
  add("palace_wall", paint(pwall, MARBLE, [MARBLE, MARBLE_D, MARBLE_L], 111));
  const pblock = new Shape();
  pblock.box(0, 0, 0, 19, 70, 19, MARBLE).box(-1, 66, -1, 20, 70, 20, MARBLE_L).box(0, 71, 0, 19, 72, 19, ROYAL_GOLD);
  for (let y = 8; y < 64; y += 10) pblock.box(0, y, 0, 19, y, 0, MARBLE_D);
  add("palace_block", paint(pblock, MARBLE, [MARBLE, MARBLE_D, MARBLE_L], 113), { footprint: [[0, 0]] });
  const hedge = new Shape();
  roundBox(hedge, [0, 0, 0], [19, 44, 19], 3, HEDGE);
  for (const v of hedge.cells.values()) {
    const n = noise3(v[0], v[1], v[2], 115);
    v[3] = n < 0.12 ? FLOWER_P : n < 0.5 ? HEDGE_D : HEDGE;
  }
  add("hedge", hedge, { footprint: [[0, 0]] });
  // The palace seen from the city (10 voxels a metre): a marble front with a colonnade, a door
  // between two towers with blue roofs and a dome.
  const pal = new Shape();
  const PW = 200, PD = 56;
  pal.box(0, 0, 0, PW - 1, 3, PD - 1, MARBLE_D); // plinth
  pal.box(0, 4, 40, PW - 1, 89, 44, MARBLE).box(0, 4, 0, PW - 1, 89, 4, MARBLE); // front and back
  pal.box(0, 4, 0, 4, 89, 44, MARBLE).box(PW - 5, 4, 0, PW - 1, 89, 44, MARBLE); // sides
  pal.box(0, 86, 0, PW - 1, 92, 47, MARBLE_L).box(0, 93, 0, PW - 1, 94, 47, ROYAL_GOLD); // cornice
  for (let x = 10; x < PW - 10; x += 20) { // the colonnade on the porch
    cylinder(pal, [x, 4, 50], [x, 86, 50], 4, MARBLE_L);
    pal.box(x - 5, 4, 45, x + 5, 6, 55, MARBLE_D).box(x - 5, 85, 45, x + 5, 88, 55, MARBLE_D);
  }
  pal.box(0, 86, 45, PW - 1, 89, 55, MARBLE_L); // porch roof
  for (let x = 20; x < PW - 20; x += 20) if (x < 85 || x > 115) pal.box(x - 4, 30, 44, x + 4, 70, 44, GLASS).box(x - 5, 28, 44, x + 5, 29, 45, ROYAL_GOLD);
  pal.box(88, 4, 40, 111, 55, 44, WOOD_D).box(88, 56, 40, 111, 58, 45, ROYAL_GOLD).box(99, 4, 44, 100, 55, 45, ROYAL_GOLD);
  for (const cx of [15, PW - 16]) { // towers
    pal.box(cx - 15, 4, 0, cx + 15, 135, 4, MARBLE).box(cx - 15, 4, 40, cx + 15, 135, 44, MARBLE);
    pal.box(cx - 15, 4, 0, cx - 11, 135, 44, MARBLE).box(cx + 11, 4, 0, cx + 15, 135, 44, MARBLE);
    pal.box(cx - 17, 130, -2, cx + 17, 136, 46, MARBLE_L).box(cx - 17, 137, -2, cx + 17, 138, 46, ROYAL_GOLD);
    pal.box(cx - 4, 85, 44, cx + 4, 118, 44, GLASS);
    for (let y = 139; y < 200; y++) {
      const r = Math.round(19 * (1 - (y - 139) / 61));
      cylinder(pal, [cx, y, 22], [cx, y, 22], r, y % 6 < 3 ? ROYAL : ROYAL_D);
    }
    pal.box(cx, 200, 22, cx, 212, 22, ROYAL_GOLD).box(cx - 2, 206, 22, cx + 2, 207, 22, ROYAL_GOLD);
  }
  ellipsoid(pal, [PW / 2, 94, 22], [34, 40, 22], ROYAL); // the dome
  for (const v of [...pal.cells.values()]) if (v[3] === ROYAL && v[1] < 94) pal.cells.delete(`${v[0]},${v[1]},${v[2]}`);
  pal.box(PW / 2 - 1, 130, 22, PW / 2, 150, 22, ROYAL_GOLD);
  const palFoot = [];
  for (let x = 0; x < PW / 10; x++) for (let z = 0; z < 6; z++) palFoot.push([x, z]);
  out["palace_facade"] = { shape: paint(pal, MARBLE, [MARBLE, MARBLE_D, MARBLE_L], 117), scale: 1, footprint: palFoot };
  // The road: the caravan's wagon with its canvas, a horse standing still, the bandits' palisade.
  const wagon = new Shape();
  wagon.box(4, 12, 6, 70, 14, 33, PLANK).box(4, 15, 6, 70, 22, 7, PLANK).box(4, 15, 32, 70, 22, 33, PLANK);
  for (const [x, z] of [[16, 3], [16, 36], [58, 3], [58, 36]]) cylinder(wagon, [x, 10, z], [x, 10, z + 2], 10, WOOD);
  for (let x = 6; x <= 68; x++) for (let a = 0; a <= 20; a++) {
    const t = (a / 20) * Math.PI;
    wagon.put(x, 22 + Math.round(Math.sin(t) * 22), Math.round(19.5 - Math.cos(t) * 14), x % 12 < 2 ? CANVAS_D : CANVAS);
  }
  wagon.box(70, 12, 18, 90, 13, 21, WOOD);
  add("caravan_wagon", paint(wagon, PLANK, [PLANK, PLANK_D], 101));
  const horse = new Shape();
  ellipsoid(horse, [20, 30, 9.5], [16, 8, 6], HORSE);
  for (const [x, z] of [[9, 6], [9, 13], [31, 6], [31, 13]]) horse.box(x, 0, z, x + 2, 24, z + 2, HORSE);
  capsule(horse, [33, 34, 9.5], [40, 46, 9.5], 4, 3, HORSE);
  ellipsoid(horse, [43, 46, 9.5], [6, 3.5, 3], HORSE);
  horse.box(32, 38, 9, 37, 48, 10, COAL).box(2, 22, 9, 5, 34, 10, COAL);
  for (const [x, z] of [[9, 6], [9, 13], [31, 6], [31, 13]]) horse.box(x, 0, z, x + 2, 2, z + 2, COAL);
  add("horse", paint(horse, HORSE, [HORSE, WOOD_D], 103));
  const palisade = new Shape();
  for (let x = 1; x < 60; x += 5) { cylinder(palisade, [x + 1.5, 0, 9.5], [x + 1.5, 44, 9.5], 2.3, x % 2 ? WOOD : BARK); palisade.box(x + 1, 45, 9, x + 2, 48, 10, WOOD_L); }
  palisade.box(0, 20, 7, 59, 21, 7, WOOD_D).box(0, 34, 7, 59, 35, 7, WOOD_D);
  add("bandit_palisade", paint(palisade, WOOD, [WOOD, WOOD_D], 105));

  // --- The prologue (Plan 8.3a) ---
  // The festival on the eve: pennants on a rope between two posts, 3 m wide.
  const garland = new Shape();
  for (const x of [8, 49]) garland.box(x, 0, 9, x + 1, 56, 10, WOOD);
  const FLAGS = [CLOTH, FLOWER_Y, FLOWER_B, FLOWER_W];
  for (let x = 10; x <= 48; x++) {
    const y = 54 - Math.round(6 * Math.sin(((x - 10) / 38) * Math.PI));
    garland.put(x, y, 9, WOOD_D);
    if ((x - 11) % 5 === 0) for (let h = 1; h <= 5; h++) for (let w = -2 + Math.ceil(h / 2); w <= 2 - Math.ceil(h / 2) + 1; w++) garland.put(x + w, y - h, 9, FLAGS[((x - 11) / 5) % 4]);
  }
  add("garland", paint(garland, WOOD, [WOOD, WOOD_D], 61), { footprint: [[0, 0], [2, 0]] });
  // A post with an arm and a lantern hanging from it.
  const lantern = new Shape();
  lantern.box(6, 0, 6, 13, 2, 13, STONE).box(8, 3, 8, 11, 52, 11, WOOD).box(8, 50, 8, 22, 52, 11, WOOD);
  lantern.box(18, 47, 8, 18, 49, 11, IRON).box(15, 38, 7, 21, 46, 12, IRON).box(16, 39, 8, 20, 45, 11, GLOW);
  lantern.box(15, 46, 7, 21, 46, 12, IRON_L);
  add("lantern_post", paint(lantern, WOOD, [WOOD, WOOD_D], 63), { footprint: [[0, 0]] });
  // A long table with benches on both sides and the feast on it: 3 m along x.
  const feast = new Shape();
  feast.box(0, 15, 5, 59, 16, 14, PLANK);
  for (const x of [2, 29, 56]) feast.box(x, 0, 6, x + 1, 14, 13, WOOD);
  for (const z of [0, 17]) { feast.box(0, 8, z, 59, 9, z + 2, PLANK_D); for (const x of [2, 56]) feast.box(x, 0, z + 1, x + 1, 7, z + 1, WOOD); }
  feast.box(4, 15, 5, 55, 15, 14, CLOTH_D).box(2, 16, 7, 57, 16, 12, CLOTH); // a cloth
  for (let x = 6; x < 56; x += 9) {
    ellipsoid(feast, [x, 18.5, 9.5], [3, 1.6, 2], HAY); // bread
    feast.box(x + 4, 17, 6, x + 5, 19, 7, IRON_L).box(x + 4, 17, 12, x + 5, 19, 13, IRON_L); // mugs
  }
  ellipsoid(feast, [30, 19, 9.5], [5, 2.5, 3], WOOD_L); // a roast
  add("feast_table", paint(feast, PLANK, [PLANK, PLANK_D], 65));
  // The bonfire on the green: a ring of stones, logs leaning together, embers and flames.
  const bonfire = new Shape();
  for (let a = 0; a < 16; a++) {
    const x = 19.5 + Math.cos(a / 16 * Math.PI * 2) * 15, z = 19.5 + Math.sin(a / 16 * Math.PI * 2) * 15;
    ellipsoid(bonfire, [x, 1, z], [2.6, 2.4, 2.6], STONE);
  }
  for (let a = 0; a < 6; a++) {
    const x = 19.5 + Math.cos(a / 6 * Math.PI * 2) * 11, z = 19.5 + Math.sin(a / 6 * Math.PI * 2) * 11;
    capsule(bonfire, [x, 0, z], [19.5, 24, 19.5], 1.8, 1.2, a % 2 ? WOOD : BARK);
  }
  bonfire.box(12, 0, 12, 27, 1, 27, COAL);
  for (let y = 2; y < 18; y++) for (let x = 13; x <= 26; x++) for (let z = 13; z <= 26; z++) {
    const r = Math.hypot(x - 19.5, z - 19.5);
    if (r < 7 * (1 - y / 20) && noise3(x, y, z, 67) > 0.35) bonfire.put(x, y, z, GLOW);
  }
  add("bonfire", paint(bonfire, STONE, [STONE, STONE_D], 69));

  // The ruins after the assault, on the healthy houses' cells.
  addHouse("house_burnt_small", burntHouse(houseParts(6, 6, (f) => { bed(f, 1, 1); table(f, 4, 1); chest(f, 4, 4); }), 71));
  addHouse("house_burnt_large", burntHouse(houseParts(8, 7, (f) => {
    bed(f, 1, 1); bed(f, 2, 1); table(f, 4, 3, 2); hearth(f, 6, 1); shelf(f, 6, 5);
  }), 73));
  // Plan 8.3d: three more village houses (and their ruins), the ranch's barn, cows and a trough.
  const timber = () => houseParts(7, 6, (f) => { bed(f, 1, 1); table(f, 4, 1, 2); shelf(f, 5, 3); }, { tall: true, planks: true, beams: true });
  const logHouse = () => houseParts(6, 5, (f) => { bed(f, 1, 1); chest(f, 4, 1); barrel(f, 4, 3); }, { logs: true, planks: true });
  const stoneHouse = () => houseParts(6, 6, (f) => { furnace(f, 1, 1, true); table(f, 3, 3, 2); shelf(f, 4, 1); }, { stone: true });
  addHouse("house_timber", timber());
  addHouse("house_log", logHouse());
  addHouse("house_stone", stoneHouse());
  addHouse("house_burnt_timber", burntHouse(timber(), 107));
  addHouse("house_burnt_log", burntHouse(logHouse(), 109));
  addHouse("house_burnt_stone", burntHouse(stoneHouse(), 111));
  addHouse("barn", houseParts(8, 7, (f) => {
    for (const [cx, cz] of [[1, 1], [2, 1], [5, 1], [6, 1]]) { f.floor.box(cx * f.C + 1, 1, cz * f.C + 1, cx * f.C + 8, 8, cz * f.C + 8, HAY); f.block(cx, cz); }
    for (const cx of [1, 5]) { f.floor.box(cx * f.C + 1, 1, 4 * f.C + 2, cx * f.C + 18, 5, 4 * f.C + 7, WOOD); f.floor.box(cx * f.C + 2, 5, 4 * f.C + 3, cx * f.C + 17, 5, 4 * f.C + 6, HAY); f.block(cx, 4); f.block(cx + 1, 4); }
  }, { barn: true, planks: true }));
  const cow = new Shape();
  ellipsoid(cow, [20, 22, 9.5], [15, 8, 7], 33);
  for (const [x, z] of [[9, 5], [9, 12], [30, 5], [30, 12]]) cow.box(x, 0, z, x + 2, 16, z + 2, 33);
  capsule(cow, [33, 24, 9.5], [38, 26, 9.5], 4, 3.5, 33);
  ellipsoid(cow, [41, 25, 9.5], [5, 4, 4], 33);
  cow.box(44, 22, 7, 46, 25, 12, CLOTH_D).box(39, 30, 5, 40, 32, 6, PLASTER_D).box(39, 30, 13, 40, 32, 14, PLASTER_D);
  for (const v of cow.cells.values()) if (v[3] === 33 && noise3(v[0] >> 2, v[1] >> 2, v[2] >> 2, 113) > 0.6) v[3] = COAL;
  for (const [x, z] of [[9, 5], [9, 12], [30, 5], [30, 12]]) cow.box(x, 0, z, x + 2, 1, z + 2, COAL);
  cow.box(2, 16, 9, 3, 26, 10, COAL);
  add("cow", cow, { footprint: [] });
  const trough = new Shape();
  trough.box(0, 0, 4, 39, 8, 15, WOOD).remove(2, 3, 6, 37, 8, 13).box(2, 3, 6, 37, 5, 13, WATER);
  add("trough", paint(trough, WOOD, [WOOD, WOOD_D], 115));
  add("rubble", rubbleHeap(75));
  // A roof beam, charred, fallen across the ground: 3 m along x.
  const beam = new Shape();
  for (let x = 0; x < 58; x++) beam.box(x, 0 + Math.floor(x / 20), 8, x, 4 + Math.floor(x / 20), 12, x % 5 === 0 ? COAL : (noise3(x, 0, 0, 77) > 0.5 ? COAL : WOOD_D));
  beam.box(55, 0, 6, 57, 7, 14, COAL);
  add("fallen_beam", beam);
  // A fresh grave: a mound of earth, 1 × 2 m, and a wooden cross at its head.
  const grave = new Shape();
  ellipsoid(grave, [9.5, 0, 22], [7, 4, 15], EARTH);
  carve(grave, (t) => roundBox(t, [-20, -20, -20], [40, -1, 60], 0, 1));
  paint(grave, EARTH, [EARTH, WOOD_D, STONE_D], 79);
  grave.box(8, 0, 4, 11, 32, 6, WOOD).box(3, 22, 4, 16, 25, 6, WOOD).box(7, 0, 3, 12, 3, 7, STONE);
  for (const x of [5, 13]) grave.put(x, 4, 30, FLOWER_W).put(x, 4, 18, FLOWER_Y);
  add("grave", grave);

  // Verrin's camp: a canvas tent (3 × 3 m, open to the front, +Z) and the kingdom's banner.
  const tent = new Shape();
  for (let h = 0; h <= 28; h++) {
    const half = 29 - h;
    for (let z = 2; z <= 57; z++) for (const x of [29.5 - half, 29.5 + half]) {
      tent.put(Math.round(x), h, z, z % 12 < 2 ? CANVAS_D : CANVAS);
    }
  }
  for (let h = 0; h <= 28; h++) for (let x = Math.round(0.5 + h); x <= Math.round(58.5 - h); x++) tent.put(x, h, 2, CANVAS_D); // back wall
  for (const z of [1, 58]) tent.box(29, 0, z, 30, 32, z, WOOD); // poles
  tent.box(29, 29, 1, 30, 30, 58, WOOD); // ridge
  tent.box(18, 0, 58, 41, 0, 59, ASH); // trodden ground at the door
  for (const [x, z] of [[-3, 6], [62, 6], [-3, 54], [62, 54]]) tent.box(x, 0, z, x + 1, 3, z + 1, WOOD_D); // pegs
  add("army_tent", tent, { footprint: [[0, 0], [1, 0], [2, 0], [0, 1], [2, 1], [0, 2], [2, 2]] });
  const banner = new Shape();
  banner.box(6, 0, 6, 13, 2, 13, STONE).box(8, 3, 8, 11, 78, 11, WOOD).box(8, 74, 8, 30, 75, 11, WOOD);
  banner.box(12, 40, 9, 29, 73, 10, ROYAL);
  for (let y = 40; y <= 73; y++) for (const x of [12, 29]) banner.put(x, y, 9, ROYAL_GOLD).put(x, y, 10, ROYAL_GOLD);
  for (let x = 12; x <= 29; x++) if ((x - 12) % 6 < 3) banner.put(x, 39, 9, ROYAL).put(x, 39, 10, ROYAL);
  for (const [x, y] of [[20, 62], [21, 62], [19, 58], [22, 58], [20, 54], [21, 54], [18, 60], [23, 60], [20, 50], [21, 50]]) { banner.put(x, y, 9, ROYAL_GOLD).put(x, y, 10, ROYAL_GOLD); } // a gold star
  banner.box(9, 79, 9, 10, 81, 10, ROYAL_GOLD);
  add("kingdom_banner", banner, { footprint: [[0, 0]] });

  // The trail in the forest: a ruined camp (a cold fire, a fallen tent, smashed crates),
  // the ruts of a cart, and a river bank (stones and reeds before the water).
  const camp = new Shape();
  for (let a = 0; a < 10; a++) ellipsoid(camp, [30 + Math.cos(a / 10 * Math.PI * 2) * 7, 0.5, 30 + Math.sin(a / 10 * Math.PI * 2) * 7], [1.8, 1.6, 1.8], STONE);
  camp.box(26, 0, 26, 34, 0, 34, COAL);
  for (let i = 0; i < 26; i++) camp.box(4 + i, Math.max(0, 8 - Math.floor(i / 3)), 4, 4 + i, Math.max(0, 8 - Math.floor(i / 3)), 22, i % 7 < 2 ? CANVAS_D : CANVAS); // a tent fallen flat
  camp.box(40, 0, 40, 51, 6, 51, PLANK).remove(42, 2, 40, 50, 6, 50); // a smashed crate
  for (const [x, z] of [[44, 10], [48, 16], [10, 44], [15, 50]]) camp.box(x, 0, z, x + 8, 1, z + 1, PLANK_D); // boards scattered
  camp.box(52, 0, 28, 55, 3, 31, IRON_L); // a pot
  add("camp_ruined", paint(camp, STONE, [STONE, STONE_D], 81));
  const tracks = new Shape();
  for (let z = 0; z < 60; z++) for (const x of [4, 14]) {
    const dx = Math.round(Math.sin(z / 18) * 1.5);
    tracks.box(x + dx, 0, z, x + dx + 2, 0, z, noise3(x, 0, z >> 1, 83) > 0.3 ? EARTH : WOOD_D);
  }
  add("cart_tracks", tracks, { footprint: [] });
  const bank = new Shape();
  bank.box(0, 0, 20, 79, 0, 59, WATER);
  for (let x = 0; x < 80; x++) {
    const edge = 18 + Math.round(noise3(x >> 2, 0, 0, 85) * 6);
    bank.box(x, 0, 0, x, 1, edge, EARTH);
    if (noise3(x, 1, 0, 85) > 0.55) ellipsoid(bank, [x, 1, edge], [2.5, 2, 2], STONE);
    if (x % 5 === 2) bank.box(x, 2, edge - 3, x, 10 + (x % 4) * 2, edge - 3, GRASS_D); // reeds
  }
  paint(bank, EARTH, [EARTH, MOSS, STONE_D], 87);
  add("river_bank", bank, { footprint: [[0, 1], [1, 1], [2, 1], [3, 1], [0, 2], [1, 2], [2, 2], [3, 2]] });
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
    const small = SMALL_PIECES.includes(id) || DECOR.includes(id);
    table[id] = { vox: `res://assets/world/${id}.vox`, scale: p.scale ?? 0.5, offset: p.shape.min(), footprint: p.footprint, ...(p.deck ? { deck: p.deck } : {}),
      shadow: small ? "never" : "medium", range: DECOR.includes(id) ? 30 : (small ? 55 : 90) };
  }
  fs.writeFileSync(jsonPath, JSON.stringify(table, null, "\t") + "\n");
  console.log(`wrote ${Object.keys(table).length} world pieces and ${jsonPath}`);
}
