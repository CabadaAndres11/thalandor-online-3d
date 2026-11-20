// Voxel monsters (made as data).
//   node tools/art/make_monsters.mjs <out dir>
// Godot axes, monsters face +Z, 1 voxel = 0.1 m. Index 251 (TINT_PRIMARY) takes the
// monster's "tint" from data/monsters; 253 (GLOW) is drawn unshaded (eyes, acid).
//
// Beasts are rigs: one .vox per part plus
// <name>.json with each part's pivot (where it rotates, in voxels from the rig
// origin at ground level below the body centre) and mesh offset (from the pivot).
import fs from "node:fs";
import { write } from "./vox.mjs";
import { beastsV2 } from "./beasts_v2.mjs";

// --- Single bodies ------------------------------------------------------------------

const BODIES = {};

// --- Beasts (rigs) ------------------------------------------------------------------

// The beasts: rigs at 2.5 cm voxels (Plan 6.4.2), sculpted in beasts_v2.mjs.
const [outDir] = process.argv.slice(2);
if (!outDir) {
  console.error("usage: node make_monsters.mjs <out dir>");
  process.exit(1);
}
for (const [name, build] of Object.entries(BODIES)) {
  const { shape, palette } = build();
  write(`${outDir}/${name}.vox`, shape.size(), shape.voxels(), palette);
  console.log(`wrote monster ${name} ${shape.size().join("x")} (${shape.voxels().length} voxels)`);
}
for (const [name, { parts, palette, gait, voxel_scale }] of Object.entries(beastsV2())) {
  const rig = { ...(voxel_scale ? { voxel_scale } : {}), ...(gait ? { gait } : {}), parts: {} };
  for (const [part, { shape, pivot, parent }] of Object.entries(parts)) {
    const file = `${name}_${part}.vox`;
    write(`${outDir}/${file}`, shape.size(), shape.voxels(), palette);
    rig.parts[part] = { file: `res://assets/monsters/vox/${file}`, pivot, offset: shape.min(), ...(parent ? { parent } : {}) };
  }
  fs.writeFileSync(`${outDir}/${name}.json`, JSON.stringify(rig, null, "\t") + "\n");
  console.log(`wrote beast ${name}: ${Object.keys(parts).join(", ")}`);
}
