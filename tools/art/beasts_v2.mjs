// Beasts at 2.5 cm voxels (Plan 6.4.2): the marked hound, the marked boar and the hunter's
// wolf, the same designs as before (make_monsters.mjs v1) sculpted four times as dense, with the
// same parts and pivots (×4) so BeastRig animates them as before (rig "voxel_scale" 0.25).
// Monsters face +Z; y 0 is the ground. The skin takes the monster's tint (TINT_PRIMARY) with
// its texture and form tones.
import { Shape, TINT_PRIMARY, GLOW, SHADE, LIGHT, TEX_D, TEX_L } from "./vox.mjs";
import { ellipsoid, capsule, cylinder, roundBox, tone, shadeByFacing } from "./sculpt.mjs";

const P = TINT_PRIMARY;
export const B = { DARK: 20, BELLY: 21, BONE: 22, NOSE: 23, PAW: 24, VOID: 25, IRON: 26, IRON_L: 27, IRON_D: 28, BONE_D: 29, DARK_L: 30 };
const { DARK, BELLY, BONE, NOSE, PAW, VOID, IRON, IRON_L, IRON_D, BONE_D, DARK_L } = B;
export const BEAST_PALETTE = {
  [DARK]: "#1e2026", [DARK_L]: "#34363e", [BELLY]: "#55585f", [BONE]: "#e6dfcc", [BONE_D]: "#b7ae98", [NOSE]: "#0e0e10",
  [PAW]: "#2a2c31", [VOID]: "#070608", [IRON]: "#3a3a40", [IRON_L]: "#6c6c74", [IRON_D]: "#26262b", [GLOW]: "#ff3b2f",
};
const BOAR_PALETTE = { ...BEAST_PALETTE, [BELLY]: "#8a6a50", [PAW]: "#1b1612", [NOSE]: "#2a1a14" };
const CX = -0.5;
const r = Math.round;

// Fur: the tint in three tones by noise, darker underneath, lighter on top; fixed colours get
// a little texture of their own.
function finish(s, seed) {
  tone(s, P, [P, TEX_D(P), TEX_L(P)], seed, [0.62, 0.26, 0.12]);
  tone(s, DARK, [DARK, DARK_L, DARK], seed + 1, [0.75, 0.25, 0]);
  tone(s, IRON, [IRON, IRON_D, IRON_L], seed + 2, [0.7, 0.2, 0.1]);
  tone(s, BONE, [BONE, BONE_D, BONE], seed + 3, [0.75, 0.25, 0]);
  const form = { shade: SHADE(P), light: LIGHT(P) };
  return shadeByFacing(s, [P, TEX_D(P), TEX_L(P)], { [P]: form, [TEX_D(P)]: form, [TEX_L(P)]: form });
}
// A ring round the z axis (a collar on a neck that runs along z), radius R, from z0 to z1.
function collar(s, cy, R, z0, z1, mark = true) {
  for (let z = z0; z <= z1; z++) for (let a = 0; a < 96; a++) {
    const t = (a / 96) * Math.PI * 2;
    for (const rr of [R, R + 1]) s.put(r(CX + Math.cos(t) * rr), r(cy + Math.sin(t) * rr), z, z === z1 ? IRON_L : IRON);
  }
  for (let k = 0; k < 8; k++) { // spikes all round
    const t = (k / 8) * Math.PI * 2 + Math.PI / 8;
    capsule(s, [CX + Math.cos(t) * (R + 1), cy + Math.sin(t) * (R + 1), (z0 + z1) / 2], [CX + Math.cos(t) * (R + 5), cy + Math.sin(t) * (R + 5), (z0 + z1) / 2], 1.2, 0.3, IRON_L);
  }
  if (!mark) return;
  // The cult's mark under the throat: a black sun with five burning rays.
  const my = cy - R - 2, mz = z1 + 1;
  ellipsoid(s, [CX, my, mz], [2.4, 2.4, 1], IRON_D);
  s.put(-1, r(my), mz + 1, VOID).put(0, r(my), mz + 1, VOID);
  for (let k = 0; k < 5; k++) {
    const t = (k / 5) * Math.PI * 2 + Math.PI / 2;
    for (let d = 2; d <= 4; d++) s.put(r(CX + Math.cos(t) * d), r(my + Math.sin(t) * d), mz + 1, GLOW);
  }
}
// Glowing eyes with a dark brow over each.
function eyes(s, xs, y, z) {
  for (const x of xs) {
    roundBox(s, [x - 1, y, z], [x + 1, y + 1, z], 0, GLOW);
    roundBox(s, [x - 2, y + 2, z - 1], [x + 2, y + 3, z], 0, DARK);
  }
}

// --- The marked hound (and the hunter's wolf) ---------------------------------------------
function hound(withCollar) {
  const parts = {};
  const body = new Shape();
  ellipsoid(body, [CX, 42, 13], [11, 13, 12], P); // deep chest
  ellipsoid(body, [CX, 41, -3], [8.5, 10, 12], P); // ribs to the waist
  ellipsoid(body, [CX, 42, -16], [10, 11.5, 10], P); // haunches
  ellipsoid(body, [CX, 50, 11], [9.5, 7, 10], P); // the shoulder hump
  for (const v of body.cells.values()) if (v[1] < 33) v[3] = BELLY;
  for (let z = -20; z <= 20; z += 4) { // the spiky ridge down the back
    let top = 0;
    for (const [x, y, zz] of body.cells.values()) if (Math.abs(x - CX) < 1 && zz === z && y > top) top = y;
    capsule(body, [CX, top - 1, z], [CX, top + 5 + (z > 0 ? 4 : 1) + ((z / 4) & 1) * 2, z - 2], 1.8, 0.4, DARK);
  }
  parts.body = { shape: finish(body, 11), pivot: [0, 0, 0] };

  const head = new Shape(); // pivot at the neck
  capsule(head, [CX, -3, 0], [CX, -8, -12], 9, 10, P); // the neck, into the body
  ellipsoid(head, [CX, 1, 8], [9, 9, 10], P); // the skull
  capsule(head, [CX, -3, 14], [CX, -5, 32], 6, 4.4, P); // the snout
  capsule(head, [CX, -10, 12], [CX, -9.5, 29], 4.2, 3, P); // the lower jaw
  for (let z = 15; z <= 31; z++) for (let x = -4; x <= 3; x++) head.put(x, -8, z, VOID); // the mouth
  ellipsoid(head, [CX, -3.5, 33], [3.4, 2.6, 2], NOSE);
  for (const x of [-4, 3]) capsule(head, [x, -7, 28], [x, -13, 29], 1.1, 0.4, BONE); // fangs
  for (let z = 18; z <= 26; z += 2) for (const x of [-3, 2]) head.put(x, -9, z, BONE); // teeth
  for (const side of [-1, 1]) capsule(head, [CX + side * 5, 7, 4], [CX + side * 7.5, 17, -1], 3, 0.6, DARK); // pointed ears
  eyes(head, [-5, 4], 2, 17);
  if (withCollar) collar(head, -5, 10, -8, -4);
  for (const v of head.cells.values()) if (v[3] === P && v[1] < -9) v[3] = BELLY; // the pale throat
  parts.head = { shape: finish(head, 13), pivot: [0, 44, 24], parent: "body" }; // bobs with the body

  // Legs: a muscled thigh, a long shank, a paw with claws; the back legs bend at the hock.
  const leg = (back, seed) => {
    const l = new Shape();
    ellipsoid(l, [CX, -4, 0], [4.6, 8, 5.5], P);
    const knee = back ? [CX, -13, -3] : [CX, -15, 1];
    const hock = back ? [CX, -23, 2] : [CX, -24, 1];
    capsule(l, [CX, -8, 0], knee, 3.4, 2.6, P);
    capsule(l, knee, hock, 2.6, 2.1, P);
    capsule(l, hock, [CX, -29, 1], 2.1, 2, P);
    ellipsoid(l, [CX, -30.5, 2.5], [3.2, 1.8, 4], PAW);
    for (const x of [-2, 0, 2]) l.put(x, -31, 7, BONE).put(x, -32, 7, BONE);
    return finish(l, seed);
  };
  parts.leg_front_left = { shape: leg(false, 15), pivot: [-8, 32, 16] };
  parts.leg_front_right = { shape: leg(false, 16), pivot: [8, 32, 16] };
  parts.leg_back_left = { shape: leg(true, 17), pivot: [-8, 32, -16] };
  parts.leg_back_right = { shape: leg(true, 18), pivot: [8, 32, -16] };

  const tail = new Shape(); // pivot at the base, back and up, a dark brush at the tip
  capsule(tail, [CX, 0, 0], [CX, 3, -12], 3.2, 2.4, P);
  capsule(tail, [CX, 3, -12], [CX, 7, -24], 2.4, 1.6, P);
  capsule(tail, [CX, 6, -22], [CX, 9, -30], 2.2, 0.6, DARK);
  parts.tail = { shape: finish(tail, 19), pivot: [0, 44, -24], parent: "body" };
  return { parts, palette: BEAST_PALETTE, voxel_scale: 0.25 };
}

// --- The marked boar ----------------------------------------------------------------------------
function boar() {
  const parts = {};
  const body = new Shape();
  ellipsoid(body, [CX, 34, -2], [15, 14, 22], P); // the barrel
  ellipsoid(body, [CX, 45, 9], [13, 10, 12], P); // the hump, higher at the front
  for (const v of body.cells.values()) if (v[1] < 24) v[3] = BELLY;
  for (let z = -18; z <= 20; z += 2) { // the bristle crest
    let top = 0;
    for (const [x, y, zz] of body.cells.values()) if (Math.abs(x - CX) < 1 && zz === z && y > top) top = y;
    const h = (z >= 0 ? 7 : 4) + ((z / 2) & 1) * 2;
    for (const dx of [-1, 0]) capsule(body, [CX + dx, top - 1, z], [CX + dx, top + h, z - 1], 1, 0.4, DARK);
  }
  parts.body = { shape: finish(body, 21), pivot: [0, 0, 0] };

  const head = new Shape(); // pivot at the neck; the head hangs low and forward
  capsule(head, [CX, -2, 0], [CX, -6, -10], 10, 11, P); // neck, into the hump
  ellipsoid(head, [CX, -4, 8], [11, 11, 12], P);
  capsule(head, [CX, -8, 16], [CX, -10, 31], 7, 6, P); // the snout
  cylinder(head, [CX, -10, 32], [CX, -10, 34], 6.4, NOSE); // the snout disc...
  for (const x of [-3, 2]) ellipsoid(head, [x, -10, 35], [1.2, 1.6, 0.6], VOID); // ...and its nostrils
  for (const side of [-1, 1]) { // long tusks curving up and out from the jaw
    capsule(head, [CX + side * 6, -14, 26], [CX + side * 8.5, -10, 33], 1.8, 1.4, BONE);
    capsule(head, [CX + side * 8.5, -10, 33], [CX + side * 9.5, -1, 37], 1.4, 0.6, BONE);
  }
  for (const side of [-1, 1]) capsule(head, [CX + side * 7, 6, 3], [CX + side * 11, 10, -2], 3, 1, DARK); // ears
  eyes(head, [-6, 5], 0, 17);
  collar(head, -5, 11, -6, -2);
  parts.head = { shape: finish(head, 23), pivot: [0, 40, 24], parent: "body" }; // bobs with the body

  const leg = (seed) => { // short and thick, ending in a split hoof
    const l = new Shape();
    ellipsoid(l, [CX, -3, 0], [5.5, 7, 6], P);
    capsule(l, [CX, -6, 0], [CX, -16, 1], 4.5, 3.6, P);
    roundBox(l, [-4, -20, -2], [3, -17, 5], 1, PAW);
    for (let y = -20; y <= -17; y++) for (let z = 1; z <= 5; z++) l.cells.delete(`${-1},${y},${z}`); // the split
    return finish(l, seed);
  };
  parts.leg_front_left = { shape: leg(25), pivot: [-10, 20, 12] };
  parts.leg_front_right = { shape: leg(26), pivot: [10, 20, 12] };
  parts.leg_back_left = { shape: leg(27), pivot: [-10, 20, -16] };
  parts.leg_back_right = { shape: leg(28), pivot: [10, 20, -16] };

  const tail = new Shape(); // a short curly tail
  for (let k = 0; k <= 24; k++) {
    const t = (k / 24) * Math.PI * 2.2, rr = 4 - k * 0.12;
    ellipsoid(tail, [CX, Math.sin(t) * rr + 2, 3 - Math.cos(t) * rr - k * 0.3], [1.4, 1.4, 1.4], k > 20 ? DARK : P); // starts in the rump
  }
  parts.tail = { shape: finish(tail, 29), pivot: [0, 40, -24], parent: "body" };
  return { parts, palette: BOAR_PALETTE, voxel_scale: 0.25 };
}

export function beastsV2() {
  return { marked_hound: hound(true), marked_boar: boar(), hunter_wolf: hound(false) };
}
