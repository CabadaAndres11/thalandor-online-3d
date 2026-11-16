// The voxel humanoid (players, cultists, NPCs), made as data.
//   node tools/art/make_humans.mjs <out dir>      (assets/characters/vox)
// Godot axes, faces +Z, 1 voxel = 0.1 m before HumanRig.MODEL_SCALE. Writes one .vox
// per part plus human.json with each part's pivot (where it rotates, in voxels from
// the rig origin on the ground) and mesh offset (from the pivot), as BeastRig rigs.
// The body is symmetric about x = -0.5 (even widths). Tinted indices: skin (248),
// eyes (249), hair (250: brows), primary (251: shirt and sleeves), secondary (252:
// trousers); boots, belt and the eye whites are fixed colors.
import fs from "node:fs";
import { write, Shape, TINT_SKIN, TINT_EYES, TINT_HAIR, TINT_PRIMARY, TINT_SECONDARY } from "./vox.mjs";

const SK = TINT_SKIN, EY = TINT_EYES, HR = TINT_HAIR, P = TINT_PRIMARY, S = TINT_SECONDARY;
const BOOT = 30, BELT = 31, BUCKLE = 32, WHITE = 33, SHADE = 34, SOLE = 35;
const PALETTE = {
  [BOOT]: "#3a2a1e", [BELT]: "#4f3520", [BUCKLE]: "#c9a64a", [WHITE]: "#f1ece2",
  [SHADE]: "#2a2420", [SOLE]: "#231a12",
};

function human() {
  const parts = {};

  const hips = new Shape(); // pivot at the hip line, y 8
  hips.box(-3, 0, -2, 2, 1, 1, S);
  hips.box(-3, 1, -2, 2, 1, 1, BELT);
  hips.put(-1, 1, 2, BUCKLE).put(0, 1, 2, BUCKLE); // buckle sticks out a little
  parts.hips = { shape: hips, pivot: [0, 8, 0] };

  const torso = new Shape(); // pivot at the waist, y 10
  torso.box(-3, 0, -2, 2, 5, 1, P);
  torso.box(-4, 4, -2, 3, 5, 1, P); // broad shoulders
  torso.box(-1, 4, 1, 0, 5, 1, SK); // neckline
  torso.box(-1, 5, 0, 0, 5, 0, SK); // neck
  torso.box(-3, 0, -2, 2, 0, 1, P); // hem
  parts.torso = { shape: torso, pivot: [0, 10, 0], parent: "hips" };

  const head = new Shape(); // pivot at the base of the skull, y 16
  head.box(-3, 0, -3, 2, 5, 2, SK);
  head.remove(-3, 5, -3, -3, 5, 2).remove(2, 5, -3, 2, 5, 2); // rounded top corners
  head.remove(-3, 0, -3, 2, 0, -3).remove(-3, 0, 2, -3, 0, 2).remove(2, 0, 2, 2, 0, 2); // jaw line
  // Face on z = 2: eyes with whites on the inside, brows in the hair color, a nose.
  head.put(-2, 2, 2, EY).put(-1, 2, 2, WHITE).put(1, 2, 2, EY).put(0, 2, 2, WHITE);
  head.box(-2, 3, 2, -1, 3, 2, HR).box(0, 3, 2, 1, 3, 2, HR);
  head.box(-1, 1, 3, 0, 1, 3, SK); // nose
  head.put(-1, 0, 2, SHADE).put(0, 0, 2, SHADE); // mouth
  head.put(-4, 2, 0, SK).put(3, 2, 0, SK); // ears
  parts.head = { shape: head, pivot: [0, 16, 0], parent: "torso" };

  // Arm: a sleeve from the shoulder; the hand is its own part (weapons go in it).
  const arm = () => new Shape().box(-1, -5, -1, 0, 0, 0, P).box(-1, -5, -1, 0, -5, 0, SK);
  parts.arm_left = { shape: arm(), pivot: [4, 15, 0], parent: "torso" };
  parts.arm_right = { shape: arm(), pivot: [-4, 15, 0], parent: "torso" };
  const hand = () => new Shape().box(-1, -1, -1, 0, 0, 0, SK);
  parts.hand_left = { shape: hand(), pivot: [4, 9, 0], parent: "arm_left" };
  parts.hand_right = { shape: hand(), pivot: [-4, 9, 0], parent: "arm_right" };

  // Leg: trousers down to the knee-high boots, the toe sticking out in front.
  const leg = () => {
    const l = new Shape();
    l.box(-1, -5, -1, 1, -1, 1, S);
    l.box(-1, -8, -1, 1, -6, 1, BOOT);
    l.box(-1, -6, -1, 1, -6, 1, BELT); // boot cuff
    l.box(-1, -8, 2, 1, -8, 2, SOLE); // toe
    return l;
  };
  parts.leg_left = { shape: leg(), pivot: [1, 8, 0], parent: "hips" };
  parts.leg_right = { shape: leg(), pivot: [-2, 8, 0], parent: "hips" };
  return { parts, palette: PALETTE };
}

const [outDir] = process.argv.slice(2);
if (!outDir) {
  console.error("usage: node make_humans.mjs <out dir>");
  process.exit(1);
}
fs.mkdirSync(outDir, { recursive: true });
const { parts, palette } = human();
const rig = { parts: {} };
for (const [part, { shape, pivot, parent }] of Object.entries(parts)) {
  const file = `human_${part}.vox`;
  write(`${outDir}/${file}`, shape.size(), shape.voxels(), palette);
  rig.parts[part] = { file: `res://assets/characters/vox/${file}`, pivot, offset: shape.min(), ...(parent ? { parent } : {}) };
}
fs.writeFileSync(`${outDir}/human.json`, JSON.stringify(rig, null, "\t") + "\n");
console.log(`wrote human: ${Object.keys(parts).join(", ")}`);
