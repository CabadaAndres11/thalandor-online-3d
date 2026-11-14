// Generates the voxel pieces (.vox) of the characters.
//   node tools/art/make_pieces.mjs <out dir> [piece ...]
// Coordinates are Godot axes, in voxels; the character faces +Z. Head-mounted pieces
// share one frame: the head occupies x 1..8, y 3..10, z 2..9 (offset in
// data/characters/pieces.json: [-5, -3, -6] from the head's bottom centre).
import { write, Shape, TINT_HAIR, TINT_PRIMARY, TINT_SECONDARY } from "./vox.mjs";

const H = TINT_HAIR, P = TINT_PRIMARY, S = TINT_SECONDARY;
const HEAD_FRAME = { x0: 1, x1: 8, y0: 3, y1: 10, z0: 2, z1: 9 };

const PIECES = {
  // Long hair: a curtain down the back to the shoulders, side locks, some volume on top.
  hair_long() {
    const s = new Shape();
    const f = HEAD_FRAME;
    s.box(f.x0 - 1, 0, f.z0 - 2, f.x1 + 1, f.y1 + 1, f.z0 - 1, H); // back curtain
    s.box(f.x0 - 1, 1, f.z0, f.x0 - 1, f.y1 + 1, f.z0 + 4, H); // left lock
    s.box(f.x1 + 1, 1, f.z0, f.x1 + 1, f.y1 + 1, f.z0 + 4, H); // right lock
    s.box(f.x0 - 1, f.y1 + 1, f.z0, f.x1 + 1, f.y1 + 1, f.z1 - 1, H); // top volume
    s.remove(f.x0 - 1, 0, f.z0 - 2, f.x0 - 1, 0, f.z0 - 1); // rounded ends
    s.remove(f.x1 + 1, 0, f.z0 - 2, f.x1 + 1, 0, f.z0 - 1);
    return s;
  },
  // Wide-brimmed pointed hat in the class colors, with a band in the secondary color.
  hat_mage() {
    const s = new Shape();
    const f = HEAD_FRAME;
    const y = f.y1 + 1; // sits on the head
    s.box(f.x0 - 3, y, f.z0 - 3, f.x1 + 3, y, f.z1 + 3, P); // brim
    s.remove(f.x0 - 3, y, f.z0 - 3, f.x0 - 3, y, f.z0 - 3).remove(f.x1 + 3, y, f.z0 - 3, f.x1 + 3, y, f.z0 - 3);
    s.remove(f.x0 - 3, y, f.z1 + 3, f.x0 - 3, y, f.z1 + 3).remove(f.x1 + 3, y, f.z1 + 3, f.x1 + 3, y, f.z1 + 3);
    s.box(f.x0, y + 1, f.z0, f.x1, y + 1, f.z1, S); // band
    s.box(f.x0, y + 2, f.z0, f.x1, y + 3, f.z1, P);
    s.box(f.x0 + 1, y + 4, f.z0 + 1, f.x1 - 1, y + 5, f.z1 - 1, P);
    s.box(f.x0 + 2, y + 6, f.z0 + 2, f.x1 - 2, y + 7, f.z1 - 2, P);
    s.box(f.x0 + 3, y + 8, f.z0 + 2, f.x1 - 3, y + 9, f.z1 - 4, P); // tip leans back
    s.box(f.x0 + 3, y + 10, f.z0 + 1, f.x1 - 3, y + 10, f.z0 + 2, P);
    return s;
  },
};

const [outDir, ...only] = process.argv.slice(2);
if (!outDir) {
  console.error("usage: node make_pieces.mjs <out dir> [piece ...]");
  process.exit(1);
}
// Offset of the head frame's origin from the head's bottom centre, in voxels.
const HEAD_FRAME_OFFSET = [-5, -3, -6];
for (const [name, build] of Object.entries(PIECES)) {
  if (only.length && !only.includes(name)) continue;
  const shape = build();
  write(`${outDir}/${name}.vox`, shape.size(), shape.voxels());
  const m = shape.min();
  const offset = HEAD_FRAME_OFFSET.map((o, i) => o + m[i]);
  console.log(`wrote piece ${name} ${shape.size().join("x")} (${shape.voxels().length} voxels), head offset [${offset.join(", ")}]`);
}
