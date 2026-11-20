// The v2 voxel humanoid (Plan 6.2): twice the resolution of v1 (98 voxels, ~1.8 cm each,
// HumanRig scale 0.18), adult proportions of about 5.8 heads, sculpted from rounded
// primitives (sculpt.mjs) with two or three tones per material. Same parts, parents and
// joints as v1, so the code animations keep working. Godot axes, faces +Z, symmetric
// about x = -0.5. Pivots are in voxels from the rig origin on the ground.
import { Shape, SHADE, LIGHT, TEX_D, TEX_L, TINT_TROUSERS, TINT_SKIN, TINT_EYES, TINT_HAIR, TINT_PRIMARY } from "./vox.mjs";
import { ellipsoid, capsule, cylinder, roundBox, carve, mirrorX, tone, shadeByFacing } from "./sculpt.mjs";

const T = TINT_TROUSERS, SK = TINT_SKIN, EY = TINT_EYES, HR = TINT_HAIR, P = TINT_PRIMARY;
// Fixed materials: base, dark and light tone of each.
export const LEATHER = 40, LEATHER_D = 41, LEATHER_L = 42;
export const BELT = 43, BELT_D = 44, BELT_L = 45;
export const BRASS = 46, BRASS_D = 47, BRASS_L = 48;
export const SOLE = 49, WHITE = 50, MOUTH = 51, LIP = 52, PUPIL = 53;
export const PALETTE_V2 = {
  [LEATHER]: "#5c3e27", [LEATHER_D]: "#402a1a", [LEATHER_L]: "#7a5636",
  [BELT]: "#4a3220", [BELT_D]: "#2f2015", [BELT_L]: "#634630",
  [BRASS]: "#c9a043", [BRASS_D]: "#8f6f28", [BRASS_L]: "#ead07a",
  [SOLE]: "#1f1710", [WHITE]: "#eee8de", [MOUTH]: "#4a1f1b", [LIP]: "#b0706a", [PUPIL]: "#141012",
};
// Texture tones of each material (base, a little darker, a little lighter), mixed per voxel.
const tint = (t) => [t, TEX_D(t), TEX_L(t)];
export const TONES = {
  [SK]: tint(SK), [P]: tint(P), [T]: tint(T), [HR]: tint(HR),
  [LEATHER]: [LEATHER, LEATHER_D, LEATHER_L], [BELT]: [BELT, BELT_D, BELT_L], [BRASS]: [BRASS, BRASS_D, BRASS_L],
};
// Form tones (folds, faces looking down or away, top edges): stronger than the texture.
const tintForm = (t) => ({ shade: SHADE(t), light: LIGHT(t) });
export const FORM = {
  [SK]: tintForm(SK), [P]: tintForm(P), [T]: tintForm(T), [HR]: tintForm(HR),
  [LEATHER]: { shade: LEATHER_D, light: LEATHER_L }, [BELT]: { shade: BELT_D, light: BELT_L }, [BRASS]: { shade: BRASS_D, light: BRASS_L },
};

// Two or three tones mixed per voxel, then the form: shade facing down/back, light facing up.
export function finish(s, materials, seed, mix = [0.65, 0.25, 0.1]) {
  const map = {};
  const idxs = [];
  for (const m of materials) {
    tone(s, m, TONES[m], seed + m, mix);
    for (const i of TONES[m]) {
      idxs.push(i);
      map[i] = FORM[m];
    }
  }
  return shadeByFacing(s, idxs, map);
}

// The front-most cell (largest z) of the shape at (x, y), or null.
export function frontZ(s, x, y) {
  let best = null;
  for (const [cx, cy, cz] of s.cells.values()) if (cx === x && cy === y && (best === null || cz > best)) best = cz;
  return best;
}

// Paints index i on the front surface at (x, y), `out` voxels proud of it (0 = on it).
function face(s, x, y, i, out = 0) {
  const z = frontZ(s, x, y);
  if (z !== null) s.put(x, y, z + out, i);
}

// Head, pivot at the base of the skull. Local y 0..16 (17 voxels), x -7..6, face at z ~6.
export function headV2() {
  const h = new Shape();
  ellipsoid(h, [-0.5, 9, -1.5], [6.6, 7.6, 7.4], SK); // cranium
  ellipsoid(h, [-0.5, 4.5, 0.5], [5.6, 4.6, 5.8], SK); // cheeks and jaw
  roundBox(h, [-4, 0, -2], [3, 3, 5], 1.5, SK); // chin and jaw line
  carve(h, (t) => roundBox(t, [-9, -2, -10], [8, 16.5 + 3, -7.5], 0, 0)); // flatten the very back
  carve(h, (t) => roundBox(t, [-9, 17, -10], [8, 22, 8], 0, 0)); // 17 voxels tall
  finish(h, [SK], 11, [0.7, 0.2, 0.1]);
  // Ears.
  for (const x of [-8, 7]) roundBox(h, [x, 6, -2], [x, 10, 0], 0.6, SK);
  for (const x of [-8, 7]) h.put(x, 8, -1, SHADE(SK));
  // Brows (hair colour), two rows, thicker at the inner end.
  for (let x = 1; x <= 4; x++) face(h, x, 11, HR, 0);
  for (let x = 1; x <= 2; x++) face(h, x, 12, HR, 0);
  // Eyes: white, iris and a dark pupil; a shade line under each.
  face(h, 4, 9, WHITE); face(h, 3, 9, EY); face(h, 2, 9, PUPIL); face(h, 1, 9, WHITE);
  face(h, 4, 8, SHADE(SK)); face(h, 3, 8, EY); face(h, 2, 8, EY); face(h, 1, 8, SHADE(SK));
  for (let x = 1; x <= 4; x++) face(h, x, 10, SHADE(SK)); // brow shadow over the eye
  // Cheekbones catch the light.
  face(h, 4, 6, LIGHT(SK)); face(h, 5, 7, LIGHT(SK));
  mirrorX(h); // the left half (x >= 0) is drawn; mirror it before the centred features
  // Nose: a ridge between the eyes, a tip proud of the face, nostrils in shade.
  for (let y = 5; y <= 9; y++) for (const x of [-1, 0]) face(h, x, y, y <= 6 ? LIGHT(SK) : SK, 1);
  for (const x of [-1, 0]) face(h, x, 5, LIGHT(SK), 1);
  for (const x of [-2, 1]) face(h, x, 5, SHADE(SK));
  for (const x of [-1, 0]) face(h, x, 4, SHADE(SK));
  // Mouth: upper lip, the line of the mouth, lower lip; a dimple under it.
  for (let x = -3; x <= 2; x++) face(h, x, 3, x === -3 || x === 2 ? SHADE(SK) : x === -2 || x === 1 ? LIP : MOUTH);
  for (let x = -2; x <= 1; x++) face(h, x, 2, LIP);
  for (const x of [-1, 0]) face(h, x, 1, SHADE(SK));
  return h;
}

// Torso, pivot at the waist; neck up to the head pivot (local y 28).
export function torsoV2() {
  const t = new Shape();
  ellipsoid(t, [-0.5, 5, -1], [9.2, 14, 6.1], P); // waist and belly: straight sides, flat front, down to the belt
  ellipsoid(t, [-0.5, 17, 0], [11.2, 9, 7.2], P); // chest and ribs
  for (const x of [-9.5, 8.5]) ellipsoid(t, [x, 22, -0.5], [2.6, 3.0, 4.2], P); // shoulders, gently rounded
  carve(t, (c) => roundBox(c, [-20, 26, -12], [20, 34, 12], 0, 0)); // flat on top of the shoulders
  carve(t, (c) => roundBox(c, [-20, -6, -12], [20, -1, 12], 0, 0));
  finish(t, [P], 21);
  // Fold under the chest and a centre seam (buttoned shirt).
  for (let x = -9; x <= 8; x++) face(t, x, 11, SHADE(P));
  for (let y = 0; y <= 22; y++) face(t, -1, y, SHADE(P));
  for (const y of [5, 10, 15, 20]) face(t, -1, y, LEATHER_L);
  // Open collar in a V, the neck above.
  for (let y = 20; y <= 25; y++) for (let x = -(y - 19); x <= y - 20; x++) face(t, x, y, SK);
  cylinder(t, [-0.5, 23, -1], [-0.5, 29, -1], 4, SK);
  for (let y = 23; y <= 29; y++) t.put(-1, y, -6, SHADE(SK)).put(0, y, -6, SHADE(SK));
  return t;
}

// Pelvis and belt, pivot at the hip joints (local y 0 = rig 46); the waist pivot is 7 up.
export function hipsV2() {
  const h = new Shape();
  ellipsoid(h, [-0.5, 3, -0.5], [10.4, 9, 7.2], T); // pelvis, as broad as the waist above it
  carve(h, (c) => roundBox(c, [-20, -12, -12], [20, -4, 12], 0, 0));
  carve(h, (c) => roundBox(c, [-20, 8, -12], [20, 16, 12], 0, 0));
  finish(h, [T], 31);
  // Belt band at the waist with a brass buckle.
  for (const [x, y, z, i] of [...h.cells.values()]) if (y >= 4 && y <= 6 && [...TONES[T], SHADE(T), LIGHT(T)].includes(i)) h.put(x, y, z, BELT);
  finish(h, [BELT], 33, [0.5, 0.35, 0.15]);
  for (let y = 3; y <= 7; y++) for (let x = -3; x <= 2; x++) face(h, x, y, y === 3 || y === 7 || x === -3 || x === 2 ? BRASS : BELT_D, 1);
  face(h, -1, 5, BRASS_L, 1); face(h, 0, 5, BRASS_L, 1);
  return h;
}

// Upper arm, pivot at the shoulder: a sleeve over the top, bare below.
export function upperArmV2() {
  const a = new Shape();
  capsule(a, [-0.5, -1, -0.5], [-0.5, -19, -0.5], 3.1, 2.7, SK);
  finish(a, [SK], 41, [0.7, 0.2, 0.1]);
  capsule(a, [-0.5, 0, -0.5], [-0.5, -9, -0.5], 3.4, 3.2, P); // sleeve, close to the arm
  carve(a, (c) => roundBox(c, [-8, -20, -8], [8, -10, 8], 0, 0).put(0, 0, 0, 0)); // sleeve hem
  capsule(a, [-0.5, -10, -0.5], [-0.5, -19, -0.5], 2.9, 2.7, SK); // arm under the hem
  finish(a, [P], 43);
  for (const [x, y, z, i] of [...a.cells.values()]) if (y === -9 && [...TONES[P], SHADE(P), LIGHT(P)].includes(i)) a.put(x, y, z, SHADE(P));
  return a;
}

// Forearm with a leather bracer; pivot at the elbow.
function forearmV2() {
  const f = new Shape();
  capsule(f, [-0.5, 0, -0.5], [-0.5, -17, -0.5], 3.0, 2.3, SK);
  finish(f, [SK], 51, [0.7, 0.2, 0.1]);
  cylinder(f, [-0.5, -9, -0.5], [-0.5, -17, -0.5], 3.1, LEATHER);
  finish(f, [LEATHER], 53, [0.55, 0.3, 0.15]);
  for (const [x, y, z] of [...f.cells.values()]) if (y === -9 || y === -17) f.put(x, y, z, LEATHER_D); // bracer edges
  for (const [x, y, z] of [...f.cells.values()]) if (y === -13 && z >= 2) f.put(x, y, z, BRASS); // a brass stud row
  return f;
}

// Fist, knuckles forward, thumb on top; pivot at the wrist.
export function handV2() {
  const h = new Shape();
  roundBox(h, [-3, -8, -2], [2, 0, 3], 1.4, SK);
  finish(h, [SK], 61, [0.7, 0.2, 0.1]);
  for (let x = -3; x <= 2; x++) face(h, x, -4, SHADE(SK)); // finger creases
  for (let x = -3; x <= 2; x++) face(h, x, -6, SHADE(SK));
  for (let x = -2; x <= 1; x += 1) face(h, x, -2, LIGHT(SK)); // knuckles
  return h;
}

// Thigh, pivot at the hip joint.
function thighV2() {
  const l = new Shape();
  capsule(l, [0, -1, 0], [0, -19, 0], 4.0, 3.3, T);
  finish(l, [T], 71);
  for (let y = -16; y <= -2; y += 7) for (const [x, cy, z] of [...l.cells.values()]) if (cy === y && z <= -2) l.put(x, cy, z, SHADE(T)); // folds
  return l;
}

// Shin in a tall boot with a folded cuff, toe cap and sole; pivot at the knee, ground at -26.
function shinV2() {
  const l = new Shape();
  capsule(l, [0, 0, 0], [0, -8, 0], 3.4, 3.2, T);
  finish(l, [T], 81);
  cylinder(l, [0, -6, 0], [0, -22, 0], 3.6, LEATHER); // boot shaft
  roundBox(l, [-4, -26, -3], [3, -21, 7], 1.6, LEATHER); // foot
  finish(l, [LEATHER], 83, [0.55, 0.28, 0.17]);
  cylinder(l, [0, -6, 0], [0, -8, 0], 4.1, LEATHER_L); // folded cuff
  for (const [x, y, z] of [...l.cells.values()]) if (y === -26) l.put(x, y, z, SOLE);
  for (const [x, y, z] of [...l.cells.values()]) if (y === -25 && z >= 6) l.put(x, y, z, SOLE); // sole lip at the toe
  for (const [x, y, z] of [...l.cells.values()]) if (y === -19 && z >= 3) l.put(x, y, z, LEATHER_D); // ankle crease
  return l;
}

export function humanV2() {
  const parts = {};
  parts.hips = { shape: hipsV2(), pivot: [0, 46, 0] };
  parts.torso = { shape: torsoV2(), pivot: [0, 53, 0], parent: "hips" };
  parts.head = { shape: headV2(), pivot: [0, 81, 0], parent: "torso" };
  parts.arm_left = { shape: upperArmV2(), pivot: [16, 76, 0], parent: "torso" };
  parts.arm_right = { shape: upperArmV2(), pivot: [-16, 76, 0], parent: "torso" };
  parts.forearm_left = { shape: forearmV2(), pivot: [16, 56, 0], parent: "arm_left" };
  parts.forearm_right = { shape: forearmV2(), pivot: [-16, 56, 0], parent: "arm_right" };
  parts.hand_left = { shape: handV2(), pivot: [16, 38, 0], parent: "forearm_left" };
  parts.hand_right = { shape: handV2(), pivot: [-16, 38, 0], parent: "forearm_right" };
  parts.leg_left = { shape: thighV2(), pivot: [4, 46, 0], parent: "hips" };
  parts.leg_right = { shape: thighV2(), pivot: [-5, 46, 0], parent: "hips" };
  parts.shin_left = { shape: shinV2(), pivot: [4, 26, 0], parent: "leg_left" };
  parts.shin_right = { shape: shinV2(), pivot: [-5, 26, 0], parent: "leg_right" };
  return { parts, palette: PALETTE_V2 };
}
