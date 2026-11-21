// World props (made as data).
//   node tools/art/make_props.mjs <out dir>
// Godot axes, 1 voxel = 0.1 m in the mesher; props are shown at scale 0.5 (5 cm voxels)
// so they match the finer style of the graphics overhaul. Index 253 (GLOW) is unshaded.
import fs from "node:fs";
import { fileURLToPath } from "node:url";
import { write, Shape, GLOW } from "./vox.mjs";
import { ellipsoid, cylinder, roundBox, carve } from "./sculpt.mjs";

const WOOD = 20, WOOD_L = 21, WOOD_D = 22, IRON = 26, IRON_L = 27, COAL = 28;
const PALETTE = {
  [WOOD]: "#4a3020", [WOOD_L]: "#5e3d27", [WOOD_D]: "#38231a",
  [IRON]: "#34343a", [IRON_L]: "#5f5f68", [COAL]: "#22160f", [GLOW]: "#ffb347",
};

// Deterministic per-voxel noise so materials get two or three mixed tones.
const noise = (x, y, z) => {
  const n = Math.sin(x * 12.9898 + y * 78.233 + z * 37.719) * 43758.5453;
  return n - Math.floor(n);
};
const wood = (x, y, z) => {
  const n = noise(x, y, z);
  return n < 0.25 ? WOOD_D : n > 0.7 ? WOOD_L : WOOD;
};

// Plan 7, the black sun altar of the title scene: weathered stone, gold, a black sun with
// a red glow, wax and embers.
const STONE = 30, STONE_L = 31, STONE_D = 32, MOSS = 33, GOLD = 34, GOLD_D = 35, BLACK = 36, WAX = 37, WAX_D = 38;
const ALTAR_PALETTE = {
  ...PALETTE, [STONE]: "#5a5550", [STONE_L]: "#6f6a63", [STONE_D]: "#403c38", [MOSS]: "#3f4a2c",
  [GOLD]: "#d9a441", [GOLD_D]: "#8f6a2a", [BLACK]: "#0d0b0b", [WAX]: "#e8dcc0", [WAX_D]: "#bfae8a", [GLOW]: "#ff4a2a",
};
const FIRE_PALETTE = { ...ALTAR_PALETTE, [GLOW]: "#ffb347" };
const stone = (x, y, z) => {
  const n = noise(x, y, z);
  return n < 0.22 ? STONE_D : n > 0.78 ? STONE_L : n > 0.74 && y < 4 ? MOSS : STONE;
};
const paint = (s, f) => { for (const v of s.cells.values()) v[3] = f(v[0], v[1], v[2], v[3]); return s; };

// The black sun: a black disc with eight gold rays, outlined in a red glow (drawn in the
// x-y plane at depth z).
function blackSun(s, cx, cy, z, r) {
  for (let x = -r - 5; x <= r + 5; x++) for (let y = -r - 5; y <= r + 5; y++) {
    const d = Math.hypot(x, y);
    const a = Math.atan2(y, x);
    const ray = Math.abs(Math.sin(a * 4)) < 0.28 && d > r && d <= r + 4.5;
    if (d <= r - 1) s.put(cx + x, cy + y, z, BLACK);
    else if (d <= r) s.put(cx + x, cy + y, z, GLOW);
    else if (ray) s.put(cx + x, cy + y, z, d > r + 3.5 ? GOLD_D : GOLD);
  }
}

const PROPS = {
  // Standing torch: iron foot, wooden pole with two iron bands and an iron bowl of
  // glowing embers on top (about 1.6 m tall at scale 0.5).
  torch() {
    const s = new Shape();
    s.box(-2, 0, -2, 2, 1, 2, IRON).box(-2, 1, -2, 2, 1, 2, IRON_L); // foot
    for (let y = 2; y <= 25; y++) for (let x = -1; x <= 0; x++) for (let z = -1; z <= 0; z++) s.put(x, y, z, wood(x, y, z));
    for (const y of [8, 18]) s.box(-2, y, -2, 1, y, 1, IRON).put(-2, y, -2, IRON_L); // bands
    s.box(-2, 26, -2, 1, 26, 1, IRON); // bowl bottom
    s.box(-3, 27, -3, 2, 29, 2, IRON).remove(-2, 27, -2, 1, 29, 1); // bowl walls
    s.box(-3, 29, -3, 2, 29, 2, IRON_L).remove(-2, 29, -2, 1, 29, 1); // rim
    s.box(-2, 27, -2, 1, 27, 1, COAL);
    for (let x = -2; x <= 1; x++) for (let z = -2; z <= 1; z++) {
      if (noise(x, 28, z) > 0.3) s.put(x, 28, z, GLOW);
    }
    s.box(-1, 29, -1, 0, 29, 0, GLOW);
    return { shape: s, palette: PALETTE };
  },
  // Altar: a stone block with a top slab and a stele standing on it with the black sun.
  altar_sun() {
    const s = new Shape();
    roundBox(s, [-12, 0, -7], [11, 15, 6], 1, STONE);
    roundBox(s, [-13, 16, -8], [12, 17, 7], 0.5, STONE);
    roundBox(s, [-9, 18, -3], [8, 39, 0], 1, STONE); // stele
    paint(s, (x, y, z) => stone(x, y, z));
    for (let x = -12; x <= 11; x++) s.put(x, 8, 7, GOLD_D); // a gold band on the front
    blackSun(s, -0.5, 29, 1, 5);
    for (const x of [-11, 10]) s.put(x, 17, 8, BLACK).put(x, 18, 8, GLOW); // two black candles
    return { shape: s, palette: ALTAR_PALETTE };
  },
  // A fallen column: base, a shaft broken at a slant, rubble at its foot.
  column_broken() {
    const s = new Shape();
    roundBox(s, [-6, 0, -6], [5, 2, 5], 0.5, STONE);
    cylinder(s, [-0.5, 3, -0.5], [-0.5, 34, -0.5], 4.5, STONE);
    carve(s, (t) => { for (let x = -8; x <= 8; x++) for (let z = -8; z <= 8; z++) for (let y = 24 + Math.round(x * 0.8 + z * 0.4); y <= 40; y++) t.put(x, y, z, 0); });
    for (const [x, z, r] of [[7, 3, 2], [-8, -4, 1.6], [6, -6, 1.3]]) ellipsoid(s, [x, 1, z], [r, r * 0.8, r], STONE);
    return { shape: paint(s, (x, y, z) => stone(x, y, z)), palette: ALTAR_PALETTE };
  },
  // A brazier: three iron legs, an iron bowl, embers and a little flame.
  brazier() {
    const s = new Shape();
    for (const [x, z] of [[-4, -3], [3, -3], [-1, 4]]) for (let y = 0; y <= 12; y++) s.put(x + Math.round((y / 12) * (x > 0 ? -1 : 1)), y, z, IRON);
    roundBox(s, [-6, 13, -6], [5, 16, 5], 1, IRON);
    s.remove(-5, 15, -5, 4, 16, 4);
    for (let x = -5; x <= 4; x++) for (let z = -5; z <= 4; z++) s.put(x, 15, z, noise(x, 15, z) > 0.4 ? GLOW : COAL);
    for (let x = -2; x <= 1; x++) for (let z = -2; z <= 1; z++) if (noise(x, 16, z) > 0.3) s.put(x, 16, z, GLOW);
    s.box(-1, 17, -1, 0, 17, 0, GLOW);
    return { shape: s, palette: FIRE_PALETTE };
  },
  // A cluster of candles of different heights on the ground, wax drips at their feet.
  candles() {
    const s = new Shape();
    for (const [x, z, h] of [[0, 0, 7], [3, 1, 5], [-3, 2, 4], [1, -3, 3], [-2, -2, 6]]) {
      s.box(x, 0, z, x, h, z, WAX).put(x, 0, z, WAX_D).put(x + 1, 0, z, WAX_D);
      s.put(x, h + 1, z, GLOW);
    }
    return { shape: s, palette: FIRE_PALETTE };
  },
  // Flagstones: a 2 m patch of square stones with dark joints and a few missing.
  flagstones() {
    const s = new Shape();
    for (let x = -20; x < 20; x++) for (let z = -20; z < 20; z++) {
      const tx = Math.floor((x + 20) / 8), tz = Math.floor((z + 20 + (tx % 2) * 4) / 8);
      if (noise(tx, 0, tz) > 0.86) continue; // a missing stone
      const joint = (x + 20) % 8 === 0 || (z + 20 + (tx % 2) * 4) % 8 === 0;
      s.put(x, 0, z, joint ? STONE_D : stone(tx, 0, tz));
    }
    return { shape: s, palette: ALTAR_PALETTE };
  },
};

export function props() {
  const out = {};
  for (const [name, build] of Object.entries(PROPS)) out[name] = build();
  return out;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [outDir] = process.argv.slice(2);
  if (!outDir) {
    console.error("usage: node make_props.mjs <out dir>");
    process.exit(1);
  }
  fs.mkdirSync(outDir, { recursive: true });
  for (const [name, { shape, palette }] of Object.entries(props())) {
    write(`${outDir}/${name}.vox`, shape.size(), shape.voxels(), palette);
    console.log(`wrote prop ${name} ${shape.size().join("x")} (${shape.voxels().length} voxels)`);
  }
}
