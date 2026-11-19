// World props (made as data).
//   node tools/art/make_props.mjs <out dir>
// Godot axes, 1 voxel = 0.1 m in the mesher; props are shown at scale 0.5 (5 cm voxels)
// so they match the finer style of the graphics overhaul. Index 253 (GLOW) is unshaded.
import { write, Shape, GLOW } from "./vox.mjs";

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
};

const [outDir] = process.argv.slice(2);
if (!outDir) {
  console.error("usage: node make_props.mjs <out dir>");
  process.exit(1);
}
for (const [name, build] of Object.entries(PROPS)) {
  const { shape, palette } = build();
  write(`${outDir}/${name}.vox`, shape.size(), shape.voxels(), palette);
  console.log(`wrote prop ${name} ${shape.size().join("x")} (${shape.voxels().length} voxels)`);
}
