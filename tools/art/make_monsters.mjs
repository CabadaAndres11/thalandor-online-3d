// Voxel monster bodies (whole monsters made as data, like the slime).
//   node tools/art/make_monsters.mjs <out dir>
// Godot axes, the monster faces +Z. Index 251 (TINT_PRIMARY) takes the monster's
// "tint" from data/monsters, so one model serves several colors.
import { write, Shape, TINT_PRIMARY, TINT_SECONDARY } from "./vox.mjs";

const P = TINT_PRIMARY;
const EYE_WHITE = 10, EYE_DARK = 11, MOUTH = 12;
const PALETTE = { [EYE_WHITE]: "#f4f4f0", [EYE_DARK]: "#1c1c22", [MOUTH]: "#2e5a28" };

const MONSTERS = {
  // A rounded jelly cube with two eyes and a little mouth.
  slime() {
    const s = new Shape();
    s.box(0, 0, 0, 9, 6, 9, P);
    for (const [x, z] of [[0, 0], [9, 0], [0, 9], [9, 9]]) s.remove(x, 6, z, x, 6, z).remove(x, 0, z, x, 0, z);
    s.box(1, 7, 1, 8, 7, 8, P); // rounded top
    s.remove(1, 7, 1, 1, 7, 1).remove(8, 7, 1, 8, 7, 1).remove(1, 7, 8, 1, 7, 8).remove(8, 7, 8, 8, 7, 8);
    // Eyes on the front face (z = 9), a slightly darker mouth.
    for (const x0 of [2, 6]) {
      s.box(x0, 3, 9, x0 + 1, 5, 9, EYE_WHITE);
      s.put(x0 + (x0 === 2 ? 1 : 0), 4, 9, EYE_DARK);
    }
    s.box(4, 2, 9, 5, 2, 9, MOUTH);
    return s;
  },
};

const [outDir] = process.argv.slice(2);
if (!outDir) {
  console.error("usage: node make_monsters.mjs <out dir>");
  process.exit(1);
}
for (const [name, build] of Object.entries(MONSTERS)) {
  const shape = build();
  write(`${outDir}/${name}.vox`, shape.size(), shape.voxels(), PALETTE);
  console.log(`wrote monster ${name} ${shape.size().join("x")} (${shape.voxels().length} voxels)`);
}
