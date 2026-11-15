// Voxel monsters (made as data).
//   node tools/art/make_monsters.mjs <out dir>
// Godot axes, monsters face +Z, 1 voxel = 0.1 m. Index 251 (TINT_PRIMARY) takes the
// monster's "tint" from data/monsters; 253 (GLOW) is drawn unshaded (eyes, acid).
//
// Single-body monsters (slime) are one .vox. Beasts are rigs: one .vox per part plus
// <name>.json with each part's pivot (where it rotates, in voxels from the rig
// origin at ground level below the body centre) and mesh offset (from the pivot).
import fs from "node:fs";
import { write, Shape, TINT_PRIMARY, GLOW } from "./vox.mjs";

const P = TINT_PRIMARY;
const DARK = 20, BELLY = 21, BONE = 22, NOSE = 23, PAW = 24, CORE = 25;
const PALETTE = {
  [DARK]: "#1e2026", [BELLY]: "#55585f", [BONE]: "#e6dfcc", [NOSE]: "#0e0e10",
  [PAW]: "#2a2c31", [CORE]: "#1f3d16", [GLOW]: "#ff3b2f",
};

// --- Single bodies ------------------------------------------------------------------

const BODIES = {
  // Acid slime: a heavy blob with a dark core, slanted glowing eyes, acid drips.
  slime() {
    const s = new Shape();
    s.box(0, 0, 0, 9, 6, 9, P);
    for (const [x, z] of [[0, 0], [9, 0], [0, 9], [9, 9]]) s.remove(x, 6, z, x, 6, z).remove(x, 0, z, x, 0, z);
    s.box(1, 7, 1, 8, 7, 8, P);
    s.remove(1, 7, 1, 1, 7, 1).remove(8, 7, 1, 8, 7, 1).remove(1, 7, 8, 1, 7, 8).remove(8, 7, 8, 8, 7, 8);
    s.box(3, 2, 3, 6, 4, 6, CORE); // dark core (seen through the sides' gaps)
    s.remove(0, 3, 4, 0, 4, 5).remove(9, 3, 4, 9, 4, 5); // gaps showing the core
    // Slanted angry eyes: outer corner higher.
    s.put(1, 4, 9, GLOW).put(2, 4, 9, GLOW).put(3, 3, 9, GLOW);
    s.put(8, 4, 9, GLOW).put(7, 4, 9, GLOW).put(6, 3, 9, GLOW);
    s.box(1, 5, 9, 3, 5, 9, DARK).box(6, 5, 9, 8, 5, 9, DARK); // heavy brows
    // Acid drips down the sides and bubbles on top.
    for (const [x, y, z] of [[0, 1, 2], [0, 0, 6], [9, 1, 7], [9, 0, 3], [4, 0, 9], [2, 8, 4], [6, 8, 6], [5, 8, 2]]) s.put(x, y, z, GLOW);
    return { shape: s, palette: { ...PALETTE, [GLOW]: "#b6ff3a" } };
  },
};

// --- Beasts (rigs) ------------------------------------------------------------------

const BEASTS = {
  // Dire wolf: long body with a spiky ridge, big head, fangs, glowing red eyes.
  wolf() {
    const parts = {};
    const body = new Shape();
    body.box(-3, 7, -6, 2, 12, 6, P);
    body.box(-2, 7, -5, 1, 7, 5, BELLY);
    body.box(-3, 12, 3, 2, 13, 6, P); // shoulders hump
    for (let z = -5; z <= 5; z += 2) body.box(-1, 13, z, 0, 14 + (z > 0 ? 1 : 0), z, DARK); // ridge spikes
    parts.body = { shape: body, pivot: [0, 0, 0] };

    const head = new Shape(); // pivot at the neck
    head.box(-3, -3, 0, 2, 2, 5, P);
    head.box(-2, -3, 6, 1, -1, 8, P); // snout
    head.put(-1, -1, 9, NOSE).put(0, -1, 9, NOSE);
    head.box(-2, -4, 7, -2, -4, 8, BONE).box(1, -4, 7, 1, -4, 8, BONE); // fangs
    head.put(-2, -5, 8, BONE).put(1, -5, 8, BONE);
    head.box(-3, 3, 1, -2, 4, 2, DARK).put(-3, 5, 1, DARK); // ears
    head.box(1, 3, 1, 2, 4, 2, DARK).put(2, 5, 1, DARK);
    head.box(-3, 0, 5, -2, 0, 5, GLOW).box(1, 0, 5, 2, 0, 5, GLOW); // eyes
    head.box(-3, 1, 5, -2, 1, 5, DARK).box(1, 1, 5, 2, 1, 5, DARK); // brows
    parts.head = { shape: head, pivot: [0, 11, 6] };

    const leg = () => {
      const l = new Shape(); // pivot at the hip, the foot reaches the ground
      l.box(-1, -7, -1, 0, 0, 0, P);
      l.box(-1, -8, -1, 0, -8, 1, PAW);
      return l;
    };
    parts.leg_front_left = { shape: leg(), pivot: [-2, 8, 4] };
    parts.leg_front_right = { shape: leg(), pivot: [2, 8, 4] };
    parts.leg_back_left = { shape: leg(), pivot: [-2, 8, -4] };
    parts.leg_back_right = { shape: leg(), pivot: [2, 8, -4] };

    const tail = new Shape(); // pivot at the base, pointing back and up
    tail.box(-1, -1, -5, 0, 0, -1, P);
    tail.box(-1, 0, -7, 0, 1, -6, DARK);
    parts.tail = { shape: tail, pivot: [0, 11, -6] };
    return { parts, palette: PALETTE };
  },
};

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
for (const [name, build] of Object.entries(BEASTS)) {
  const { parts, palette } = build();
  const rig = { parts: {} };
  for (const [part, { shape, pivot }] of Object.entries(parts)) {
    const file = `${name}_${part}.vox`;
    write(`${outDir}/${file}`, shape.size(), shape.voxels(), palette);
    rig.parts[part] = { file: `res://assets/monsters/vox/${file}`, pivot, offset: shape.min() };
  }
  fs.writeFileSync(`${outDir}/${name}.json`, JSON.stringify(rig, null, "\t") + "\n");
  console.log(`wrote beast ${name}: ${Object.keys(parts).join(", ")}`);
}
