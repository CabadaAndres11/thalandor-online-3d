// The voxel humanoid (players, cultists, NPCs), made as data.
//   node tools/art/make_humans.mjs <out dir>      (assets/characters/vox)
// Godot axes, faces +Z. Fine voxels: HumanRig scales the rig so the body (49 voxels)
// is about 1.76 m tall. Writes one .vox per part plus human.json with each part's
// pivot (where it rotates, in voxels from the rig origin on the ground) and mesh
// offset (from the pivot), as BeastRig rigs. Symmetric about x = -0.5.
// Adult proportions: a head about 1/5 of the height, long limbs with elbows and
// knees. Each material has a base, a shade (folds, sides away from the light, under
// the chest) and a light (top edges, cheekbones) tone, so it reads modelled rather
// than flat; HumanRig tints them per character (skin, eyes, hair, shirt, trousers).
import fs from "node:fs";
import { fileURLToPath } from "node:url";
import { write, Shape, SHADE, LIGHT, TINT_TROUSERS, TINT_SKIN, TINT_EYES, TINT_HAIR, TINT_PRIMARY } from "./vox.mjs";
import { humanV2 } from "./human_v2.mjs";
export { humanV2 };

const T = TINT_TROUSERS, SK = TINT_SKIN, EY = TINT_EYES, HR = TINT_HAIR, P = TINT_PRIMARY;
const BOOT = 30, BELT = 31, BUCKLE = 32, WHITE = 33, MOUTH = 34, SOLE = 35, BOOT_D = 36, BOOT_L = 37, BELT_D = 38;
const PALETTE = {
  [BOOT]: "#5a3d26", [BOOT_D]: "#3e2a1a", [BOOT_L]: "#7a5636", [BELT]: "#4a3220", [BELT_D]: "#33231a",
  [BUCKLE]: "#d4ad4a", [WHITE]: "#efe9df", [MOUTH]: "#5a2a24", [SOLE]: "#231a12",
};

// Shade the faces of a box that look away from the light: its -X/+X sides by
// `sides`, its back (-Z) and its bottom row.
function shadeSides(s, x0, y0, z0, x1, y1, z1, tint) {
  for (const v of [...s.cells.values()]) {
    const [x, y, z, i] = v;
    if (i !== tint || x < x0 || x > x1 || y < y0 || y > y1 || z < z0 || z > z1) continue;
    if (x === x0 || x === x1 || z === z0) s.put(x, y, z, SHADE(tint));
  }
}

export function human() {
  const parts = {};

  // Pelvis and belt (pivot at the hip joints' height).
  const hips = new Shape();
  hips.box(-5, -2, -3, 4, 3, 2, T);
  shadeSides(hips, -5, -2, -3, 4, 1, 2, T);
  hips.box(-5, 2, -3, 4, 3, 2, BELT).box(-5, 2, -3, 4, 2, 2, BELT_D);
  hips.box(-2, 1, 3, 1, 4, 3, BUCKLE).box(-1, 2, 3, 0, 3, 3, BELT_D); // buckle
  parts.hips = { shape: hips, pivot: [0, 22, 0] };

  // Torso: waist, a broader chest and shoulders, the neck.
  const torso = new Shape(); // pivot at the waist
  torso.box(-5, 0, -3, 4, 3, 2, P);
  torso.box(-6, 4, -4, 5, 11, 3, P);
  torso.remove(-6, 11, -4, -6, 11, 3).remove(5, 11, -4, 5, 11, 3); // sloping shoulders
  shadeSides(torso, -6, 0, -4, 5, 11, 3, P);
  for (let x = -5; x <= 4; x++) torso.put(x, 4, 3, SHADE(P)); // fold under the chest
  for (let x = -5; x <= 4; x++) torso.put(x, 10, 3, LIGHT(P)).put(x, 11, 2, LIGHT(P)); // light on the shoulders
  torso.box(-2, 9, 4, 1, 11, 4, SK).remove(-2, 11, 3, 1, 11, 3).box(-1, 10, 3, 0, 11, 3, SK); // open collar
  torso.box(-2, 12, -2, 1, 13, 1, SK).box(-2, 12, -2, 1, 13, -2, SHADE(SK)); // neck
  parts.torso = { shape: torso, pivot: [0, 26, 0], parent: "hips" };

  // Head: a rounded skull, brow, cheekbones, nose, lips, ears.
  const head = new Shape(); // pivot at the base of the skull
  head.box(-4, 0, -5, 3, 9, 3, SK);
  for (const x of [-4, 3]) for (const z of [-5, 3]) head.remove(x, 0, z, x, 9, z); // round the corners
  head.remove(-4, 9, -5, 3, 9, -4).remove(-4, 9, -5, -4, 9, 3).remove(3, 9, -5, 3, 9, 3); // round the top
  head.remove(-4, 0, -5, 3, 0, -3).remove(-4, 0, -2, -4, 1, 3).remove(3, 0, -2, 3, 1, 3); // jaw line
  shadeSides(head, -4, 0, -5, 3, 9, 3, SK);
  // Face on z = 3.
  head.box(-3, 6, 3, -2, 6, 3, HR).box(1, 6, 3, 2, 6, 3, HR); // brows
  head.put(-3, 5, 3, WHITE).put(-2, 5, 3, EY).put(1, 5, 3, EY).put(2, 5, 3, WHITE); // eyes
  head.box(-3, 4, 3, -2, 4, 3, SHADE(SK)).box(1, 4, 3, 2, 4, 3, SHADE(SK)); // under the eyes
  head.put(-3, 3, 3, LIGHT(SK)).put(2, 3, 3, LIGHT(SK)); // cheekbones
  head.box(-1, 3, 4, 0, 5, 4, SK).box(-1, 3, 4, 0, 3, 4, LIGHT(SK)); // nose, its tip catches the light
  head.box(-1, 2, 3, 0, 2, 3, SHADE(SK)); // under the nose
  head.box(-2, 1, 3, 1, 1, 3, SHADE(SK)).box(-1, 1, 3, 0, 1, 3, MOUTH); // lips
  head.box(-5, 3, -1, -5, 5, 0, SK).box(4, 3, -1, 4, 5, 0, SK); // ears
  head.put(-5, 4, 0, SHADE(SK)).put(4, 4, 0, SHADE(SK));
  parts.head = { shape: head, pivot: [0, 40, 0], parent: "torso" };

  // Upper arm: a sleeve over the shoulder, bare below; inner side in shade.
  const upper = (inner) => {
    const a = new Shape();
    a.box(-2, -9, -2, 1, 0, 1, SK);
    a.box(-2, -5, -2, 1, 1, 1, P).box(-2, -5, -2, 1, -5, 1, SHADE(P)); // sleeve and its hem
    a.box(-2, 1, -2, 1, 1, 1, LIGHT(P));
    a.box(inner, -9, -2, inner, -6, 1, SHADE(SK));
    return a;
  };
  parts.arm_left = { shape: upper(-2), pivot: [8, 36, 0], parent: "torso" };
  parts.arm_right = { shape: upper(1), pivot: [-8, 36, 0], parent: "torso" };
  // Forearm with a leather bracer at the wrist.
  const fore = (inner) => {
    const a = new Shape();
    a.box(-2, -8, -2, 1, 0, 1, SK);
    a.box(inner, -8, -2, inner, 0, 1, SHADE(SK));
    a.box(-2, -8, -2, 1, -5, 1, BOOT).box(-2, -5, -2, 1, -5, 1, BOOT_L).box(-2, -8, -2, 1, -8, 1, BOOT_D);
    return a;
  };
  parts.forearm_left = { shape: fore(-2), pivot: [8, 26, 0], parent: "arm_left" };
  parts.forearm_right = { shape: fore(1), pivot: [-8, 26, 0], parent: "arm_right" };
  // Fist, knuckles forward, thumb on top.
  const hand = () => {
    const h = new Shape();
    h.box(-2, -4, -2, 1, 0, 1, SK);
    h.remove(-2, -4, -2, -2, -4, 1).remove(1, -4, -2, 1, -4, 1);
    h.box(-2, -3, 1, 1, -3, 1, SHADE(SK)); // finger crease
    return h;
  };
  parts.hand_left = { shape: hand(), pivot: [8, 18, 0], parent: "forearm_left" };
  parts.hand_right = { shape: hand(), pivot: [-8, 18, 0], parent: "forearm_right" };

  // Thigh; the inner side in shade.
  const thigh = (inner) => {
    const l = new Shape();
    l.box(-2, -10, -2, 2, 0, 2, T);
    l.box(inner, -10, -2, inner, 0, 2, SHADE(T)).box(-2, -10, -2, 2, -10, -2, SHADE(T));
    l.box(-2, -1, 2, 2, -1, 2, SHADE(T)); // crease at the hip
    return l;
  };
  parts.leg_left = { shape: thigh(-2), pivot: [2, 22, 0], parent: "hips" };
  parts.leg_right = { shape: thigh(2), pivot: [-3, 22, 0], parent: "hips" };
  // Shin in a tall boot with a folded cuff, a toe cap and a sole.
  const shin = () => {
    const l = new Shape();
    l.box(-2, -3, -2, 2, 0, 2, T);
    l.box(-2, -12, -2, 2, -4, 2, BOOT);
    l.box(-2, -4, -2, 2, -4, 2, BOOT_L); // folded cuff
    l.box(-2, -5, -2, -2, -11, 2, BOOT_D).box(2, -5, -2, 2, -11, 2, BOOT_D); // sides in shade
    l.box(-2, -12, -2, 2, -12, -2, BOOT_D).box(-2, -12, 3, 2, -11, 4, BOOT); // heel, toe
    l.box(-2, -12, -2, 2, -12, 4, SOLE);
    l.box(-2, -10, 2, 2, -10, 2, BOOT_D); // ankle crease
    return l;
  };
  parts.shin_left = { shape: shin(), pivot: [2, 12, 0], parent: "leg_left" };
  parts.shin_right = { shape: shin(), pivot: [-3, 12, 0], parent: "leg_right" };
  return { parts, palette: PALETTE };
}

// Writes one .vox per part and <name>.json (pivots, offsets, parents) for Godot.
function writeRig(name, build, outDir, resDir) {
  fs.mkdirSync(outDir, { recursive: true });
  for (const f of fs.readdirSync(outDir)) if (f.startsWith(name + "_") && f.endsWith(".vox")) fs.unlinkSync(`${outDir}/${f}`);
  const { parts, palette } = build();
  const rig = { parts: {} };
  for (const [part, { shape, pivot, parent }] of Object.entries(parts)) {
    const file = `${name}_${part}.vox`;
    write(`${outDir}/${file}`, shape.size(), shape.voxels(), palette);
    rig.parts[part] = { file: `${resDir}/${file}`, pivot, offset: shape.min(), ...(parent ? { parent } : {}) };
  }
  fs.writeFileSync(`${outDir}/${name}.json`, JSON.stringify(rig, null, "\t") + "\n");
  console.log(`wrote ${name}: ${Object.keys(parts).join(", ")}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  // node make_humans.mjs <v1 out dir> [<v2 out dir>]
  const [outDir, outDirV2 = outDir.replace(/vox\/?$/, "vox_v2")] = process.argv.slice(2);
  if (!outDir) {
    console.error("usage: node make_humans.mjs <out dir> [<v2 out dir>]");
    process.exit(1);
  }
  writeRig("human", human, outDir, "res://assets/characters/vox");
  writeRig("human_v2", humanV2, outDirV2, "res://assets/characters/vox_v2");
}
