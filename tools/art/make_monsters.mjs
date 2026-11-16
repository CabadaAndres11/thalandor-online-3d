// Voxel monsters (made as data).
//   node tools/art/make_monsters.mjs <out dir>
// Godot axes, monsters face +Z, 1 voxel = 0.1 m. Index 251 (TINT_PRIMARY) takes the
// monster's "tint" from data/monsters; 253 (GLOW) is drawn unshaded (eyes, acid).
//
// Beasts are rigs: one .vox per part plus
// <name>.json with each part's pivot (where it rotates, in voxels from the rig
// origin at ground level below the body centre) and mesh offset (from the pivot).
import fs from "node:fs";
import { write, Shape, TINT_PRIMARY, GLOW } from "./vox.mjs";

const P = TINT_PRIMARY;
const DARK = 20, BELLY = 21, BONE = 22, NOSE = 23, PAW = 24, IRON = 26, IRON_L = 27;
const PALETTE = {
  [DARK]: "#1e2026", [BELLY]: "#55585f", [BONE]: "#e6dfcc", [NOSE]: "#0e0e10",
  [PAW]: "#2a2c31", [IRON]: "#3a3a40", [IRON_L]: "#6c6c74", [GLOW]: "#ff3b2f",
};

// --- Single bodies ------------------------------------------------------------------

const BODIES = {};

// --- Beasts (rigs) ------------------------------------------------------------------

// An iron collar around the neck (the head part's back, z = zBack) from y0 to y1 and
// x half-width hw, with the cult mark glowing at the throat.
function collar(s, y0, y1, zBack, hw) {
  const x0 = -3 - hw, x1 = 2 + hw;
  s.box(x0, y0, zBack, x1, y1 - 1, zBack, IRON);
  s.box(x0, y0, zBack, x0, y1 - 1, zBack + 2, IRON).box(x1, y0, zBack, x1, y1 - 1, zBack + 2, IRON);
  s.box(x0, y1 - 1, zBack, x1, y1 - 1, zBack, IRON_L);
  s.box(-1, y0 - 1, zBack + 1, 0, y0, zBack + 2, GLOW); // the mark
}


const BEASTS = {
  // Marked hound: a cult war-hound. Long body with a spiky ridge, big head, fangs,
  // glowing red eyes and an iron collar with the cult's burning mark (the five-rayed
  // black sun) at the throat.
  marked_hound() {
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
    collar(head, -4, 3, -3, 0);
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

  // Marked boar: a cult war-boar in iron plates. A heavy barrel body, hunched shoulders with a bristle crest, a low head
  // with long upturned tusks, glowing eyes and short legs ending in dark hooves.
  marked_boar() {
    const parts = {};
    const body = new Shape();
    body.box(-4, 5, -6, 3, 11, 5, P); // barrel
    body.box(-3, 5, -5, 2, 5, 4, BELLY);
    body.box(-4, 11, 0, 3, 13, 6, P); // shoulder hump, higher at the front
    body.box(-3, 13, 1, 2, 14, 5, P);
    for (let z = -5; z <= 5; z += 1) body.box(-1, 12 + (z >= 0 ? 2 : 0), z, 0, 13 + (z >= 0 ? 3 : 0) - (z % 2 === 0 ? 0 : 1), z, DARK); // bristle crest
    for (const x of [-5, 4]) body.box(x, 7, -3, x, 11, 4, IRON).box(x, 11, -3, x, 11, 4, IRON_L); // iron side plates
    for (const x of [-5, 4]) for (const z of [-2, 3]) body.put(x, 9, z, IRON_L); // rivets
    parts.body = { shape: body, pivot: [0, 0, 0] };

    const head = new Shape(); // pivot at the neck, the head hangs low and forward
    head.box(-3, -4, 0, 2, 1, 5, P);
    head.box(-2, -4, 6, 1, -1, 8, P); // snout
    head.box(-2, -3, 9, 1, -1, 9, NOSE);
    head.put(-1, -2, 9, BELLY).put(0, -2, 9, BELLY); // nostrils' rim
    // Long tusks curving up and out from the jaw.
    for (const x of [-3, 2]) {
      head.put(x, -4, 7, BONE).put(x, -3, 8, BONE).put(x, -2, 9, BONE).put(x, -1, 10, BONE).put(x, 0, 10, BONE);
    }
    head.box(-3, 2, 1, -2, 3, 2, DARK).box(1, 2, 1, 2, 3, 2, DARK); // ears
    head.box(-3, 0, 5, -2, 0, 5, GLOW).box(1, 0, 5, 2, 0, 5, GLOW); // eyes
    head.box(-3, 1, 5, -2, 1, 5, DARK).box(1, 1, 5, 2, 1, 5, DARK); // brows
    collar(head, -5, 2, -4, 0);
    parts.head = { shape: head, pivot: [0, 10, 6] };

    const leg = () => {
      const l = new Shape(); // pivot at the hip, short and thick
      l.box(-1, -4, -1, 1, 0, 1, P);
      l.box(-1, -5, -1, 1, -5, 1, PAW);
      return l;
    };
    parts.leg_front_left = { shape: leg(), pivot: [-3, 5, 3] };
    parts.leg_front_right = { shape: leg(), pivot: [2, 5, 3] };
    parts.leg_back_left = { shape: leg(), pivot: [-3, 5, -4] };
    parts.leg_back_right = { shape: leg(), pivot: [2, 5, -4] };

    const tail = new Shape(); // a short curly tail
    tail.box(0, 0, -2, 0, 0, -1, P).put(0, 1, -2, P).put(0, 1, -3, DARK);
    parts.tail = { shape: tail, pivot: [0, 10, -6] };
    return { parts, palette: { ...PALETTE, [BELLY]: "#8a6a50", [PAW]: "#1b1612", [NOSE]: "#2a1a14" } };
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
  const { parts, palette, gait } = build();
  const rig = gait ? { gait, parts: {} } : { parts: {} };
  for (const [part, { shape, pivot, parent }] of Object.entries(parts)) {
    const file = `${name}_${part}.vox`;
    write(`${outDir}/${file}`, shape.size(), shape.voxels(), palette);
    rig.parts[part] = { file: `res://assets/monsters/vox/${file}`, pivot, offset: shape.min(), ...(parent ? { parent } : {}) };
  }
  fs.writeFileSync(`${outDir}/${name}.json`, JSON.stringify(rig, null, "\t") + "\n");
  console.log(`wrote beast ${name}: ${Object.keys(parts).join(", ")}`);
}
