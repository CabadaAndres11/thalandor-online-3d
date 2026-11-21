// Race heads on the v2 body (Plan 7): the ogre and the lizardfolk keep the human body
// and change the head. Same pivot as headV2 (the base of the skull, local y 0), drawn
// facing +Z and symmetric about x = -0.5. make_humans.mjs writes them next to the rig.
import { Shape, SHADE, LIGHT, TINT_SKIN, TINT_EYES, TINT_HAIR } from "./vox.mjs";
import { ellipsoid, capsule, roundBox, carve, mirrorX } from "./sculpt.mjs";
import { finish, face, WHITE, MOUTH, PUPIL } from "./human_v2.mjs";

const SK = TINT_SKIN, EY = TINT_EYES, HR = TINT_HAIR;

// Ogre: a broad skull, a heavy brow over small deep eyes, a flat wide nose and a jutting
// jaw with two tusks.
export function headOgreV2() {
  const h = new Shape();
  ellipsoid(h, [-0.5, 10, -1.5], [7.6, 8, 8], SK); // cranium
  ellipsoid(h, [-0.5, 4, 1.5], [7.2, 4.8, 6.6], SK); // jaw, wider than the skull's base
  roundBox(h, [-5, -1, 1], [4, 3, 7], 1.5, SK); // the chin juts forward
  ellipsoid(h, [-0.5, 11.5, 4.5], [7, 2, 2.6], SK); // brow ridge
  carve(h, (t) => roundBox(t, [-10, -4, -12], [9, 22, -8.5], 0, 0)); // flat back
  carve(h, (t) => roundBox(t, [-10, 19, -12], [9, 24, 10], 0, 0));
  finish(h, [SK], 41, [0.6, 0.25, 0.15]);
  for (const x of [-9, 8]) roundBox(h, [x, 7, -2], [x, 10, 0], 0.6, SK); // small ears
  // Eyes deep under the brow, a shade band above them.
  for (let x = 1; x <= 5; x++) face(h, x, 10, SHADE(SK));
  face(h, 2, 9, PUPIL); face(h, 3, 9, EY); face(h, 4, 9, SHADE(SK));
  for (let x = 1; x <= 5; x++) face(h, x, 12, LIGHT(SK));
  face(h, 5, 6, LIGHT(SK));
  mirrorX(h);
  // Flat wide nose with nostrils.
  for (let y = 6; y <= 8; y++) for (let x = -2; x <= 1; x++) face(h, x, y, y === 8 ? LIGHT(SK) : SK, 1);
  for (const x of [-2, 1]) face(h, x, 6, SHADE(SK), 1);
  // A wide mouth, the tusks rising from the lower jaw in front of it.
  for (let x = -4; x <= 3; x++) face(h, x, 4, MOUTH);
  for (const x of [-4, 3]) for (let y = 3; y <= 7; y++) face(h, x, y, WHITE, 1);
  return h;
}

// Lizardfolk: a flat skull running into a long snout, eyes on the sides of the head with
// slit pupils, nostrils at the tip and a mouth line along the snout.
export function headLizardV2() {
  const h = new Shape();
  ellipsoid(h, [-0.5, 9.5, -2], [6, 6.5, 6.8], SK); // skull
  ellipsoid(h, [-0.5, 6, 6], [4.2, 3.6, 7.5], SK); // snout
  ellipsoid(h, [-0.5, 3.5, 3], [4.6, 3.2, 6.5], SK); // lower jaw and throat
  capsule(h, [-0.5, 1, -3], [-0.5, 1, 2], 3.6, 3.6, SK); // neck base
  carve(h, (t) => roundBox(t, [-9, -4, -12], [8, 20, -8.5], 0, 0));
  carve(h, (t) => roundBox(t, [-9, 16, -12], [8, 24, 16], 0, 0));
  finish(h, [SK], 51, [0.5, 0.3, 0.2]); // scales: more contrast than skin
  // Eyes on the sides: iris round a vertical slit, a brow ridge above.
  for (const [y, z] of [[10, 2], [11, 2], [10, 3], [11, 3]]) h.put(5, y, z, EY).put(6, y, z, EY);
  h.put(6, 10, 2, PUPIL).put(6, 11, 2, PUPIL);
  for (let z = 1; z <= 4; z++) h.put(6, 12, z, LIGHT(SK)).put(5, 13, z, LIGHT(SK));
  mirrorX(h);
  // Nostrils on the tip of the snout and the mouth line along both sides.
  let tip = -Infinity;
  for (const [, , z] of h.cells.values()) tip = Math.max(tip, z);
  for (const x of [-2, 1]) h.put(x, 7, tip, SHADE(SK));
  for (const [x, y, z, i] of [...h.cells.values()]) if (y === 4 && z >= 3 && i !== PUPIL && Math.abs(x + 0.5) >= 2.5) h.put(x, y, z, MOUTH);
  for (const x of [-3, 2]) h.put(x, 3, tip - 2, WHITE); // two teeth at the front
  // Row of scales along the ridge of the skull (hair tint where a crest is not worn).
  for (let z = -6; z <= 4; z += 2) h.put(-1, 16, z, SHADE(SK)).put(0, 16, z, SHADE(SK));
  return h;
}

export function raceHeadsV2() {
  return { ogre: headOgreV2(), lizard: headLizardV2() };
}
