// The deep hood of every class (after the user's reference, 2026-11-27): a roomy cowl that
// rises to a soft peak, a brim standing out past the face so the face sits in its shadow,
// a dark lining round the opening and cloth falling over the shoulders, the back and the
// sides of the chest down to a stepped, uneven hem. Drawn in the head pivot frame; the
// caller colours it (its own tones and trims) after. Pure geometry: one colour plus the
// lining's.
import { Shape } from "./vox.mjs";
import { ellipsoid, shellAround, noise3 } from "./sculpt.mjs";

// The head pivot is 28 voxels above the torso's.
const TORSO_TO_HEAD = -28;
// The face opening (head frame): the eyes, nose, mouth and cheeks stay bare.
export const HOLE = { x0: -6, x1: 5, y0: -1, y1: 13 };
// An arch: round at the top, straight down the cheeks to the jaw.
const archR = (x, y) => Math.hypot((x + 0.5) / 6.6, Math.max(0, y - 6) / 8.2);
const inHole = (x, y) => y >= HOLE.y0 && archR(x, y) <= 1;
// How far a point lies outside the opening, in voxels (0 inside it).
const outside = (x, y) => Math.max(0, (archR(x, y) - 1) * 7, HOLE.y0 - y);

// head, torso: the body parts (shapes); idx: the cloth; lining: the dark inside.
// opts.drape: the cloth over the shoulders (false for a cowl alone); opts.seed: the hem's noise.
export function deepHood(head, torso, idx, lining, opts = {}) {
  const seed = opts.seed ?? 1;
  const s = new Shape();
  const put = (x, y, z, i) => { if (!head.cells.has(`${x},${y},${z}`)) s.put(x, y, z, i); };
  // Nothing in front of the chin and the neck: the face and the throat stay open (2026-11-27).
  const throat = (x, y, z) => z >= 0 && y < HOLE.y0 && Math.abs(x + 0.5) <= 7.5;
  // The cowl: three voxels over the head, open at the face.
  for (const [x, y, z, i] of shellAround(head, 3, idx, (x, y, z) => !(z >= 0 && inHole(x, y)) && !throat(x, y, z) && y >= -3).cells.values()) put(x, y, z, i);
  // The bulk: the cloth stands well off the head, wider than it, to a soft peak leaning back.
  const bulk = new Shape();
  ellipsoid(bulk, [-0.5, 9, -1.5], [10.5, 10, 9.5], idx);
  ellipsoid(bulk, [-0.5, 17, -3], [7.5, 4.5, 7], idx);
  for (const [x, y, z, i] of bulk.cells.values()) if (!(z >= 0 && inHole(x, y)) && !throat(x, y, z) && y >= -3) put(x, y, z, i);
  // The brim: an arch round the face, level with the brow so it shades nothing below it,
  // sloping back from its edge, the front edge stepped and uneven.
  for (let x = -11; x <= 10; x++) for (let y = -6; y <= 19; y++) {
    if (inHole(x, y)) continue;
    if (y < HOLE.y0 && Math.abs(x + 0.5) <= 6.5) continue; // no shelf under the chin
    if (((x + 0.5) / 11) ** 2 + ((y - 7) / 12.5) ** 2 > 1) continue; // the arch's outline
    const reach = 6 - Math.round(1.5 * outside(x, y)) + Math.floor(noise3(x >> 1, y >> 1, 0, seed) * 2);
    for (let z = 2; z <= reach; z++) put(x, y, z, idx);
  }
  // Locks of cloth falling from the sides of the hood past the shoulders, of uneven length.
  for (let x = -12; x <= 11; x++) {
    if (Math.abs(x + 0.5) < 8.5) continue;
    for (let z = -7; z <= 6; z++) {
      const len = 4 + Math.floor(noise3(x >> 1, 0, z >> 1, seed + 3) * 4) * 3; // 4..13 voxels below the jaw
      for (let y = -2; y >= -2 - len; y--) if (!torso.cells.has(`${x},${y - TORSO_TO_HEAD},${z}`)) put(x, y, z, idx);
    }
  }
  if (opts.drape !== false) {
    // The cloth over the shoulders and the back (torso frame), open over the chest.
    const open = (x, y, z) => z >= 1 && Math.abs(x + 0.5) <= 5.5 && y <= 27; // the throat stays open
    const cloth = shellAround(torso, 2, idx, (x, y, z) => y >= 2 && y <= 27 && !open(x, y, z));
    for (const [x, y, z] of cloth.cells.values()) {
      // The hem: long at the back and in the two front lappets beside the chest, short over
      // the arms, in uneven steps of two voxels.
      const lappet = z >= 1 && Math.abs(x + 0.5) <= 9.5;
      const base = z < 0 ? 4 : lappet ? 6 : 16;
      const hem = base + 2 * Math.floor(noise3(x >> 1, 0, z >> 1, seed + 7) * 3);
      if (y >= hem) put(x, y + TORSO_TO_HEAD, z, idx);
    }
  }
  // The lining: the cloth round the opening, seen inside the brim, is dark.
  for (const v of s.cells.values()) {
    const [x, y, z] = v;
    if (z >= 1 && x >= HOLE.x0 - 1 && x <= HOLE.x1 + 1 && y >= HOLE.y0 && y <= HOLE.y1 + 1) v[3] = lining;
  }
  return s;
}

// The brim's top front band (where a circlet or a brow band goes).
export const onBrimTop = (x, y, z) => y >= 14 && y <= 15 && z >= 6;
