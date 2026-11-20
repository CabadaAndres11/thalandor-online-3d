// v2 jewelry (Plan 6.3.1): a ring and an amulet per tier, richer each tier (bronze, gold
// with a red gem, bright gold with a glowing gem and engraving). They are never worn on
// the body: the models only feed the item icons and the loot on the ground.
// Rings stand upright, facing -Z (the icon camera); amulets hang a chain over a pendant.
import { Shape, GLOW } from "./vox.mjs";
import { ellipsoid, cylinder } from "./sculpt.mjs";
import { C, PALETTE } from "./gear_style.mjs";

const METAL = { 1: [C.BRONZE, C.BRONZE_D], 2: [C.GOLD, C.GOLD_D], 3: [C.GOLD_L, C.GOLD] };
const GEM = { 1: null, 2: C.GEM, 3: GLOW };

// A band of radius r (in voxels) and thickness `th`, upright in the XY plane, depth 2..3 in z.
function band(s, r, th, depth, idx, dark) {
  for (let y = -r - th; y <= r + th; y++)
    for (let x = -r - th; x <= r + th; x++) {
      const d = Math.hypot(x, y);
      if (d < r - 0.5 || d > r + th) continue;
      for (let z = 0; z < depth; z++) s.put(x, y, z, z === 0 || z === depth - 1 ? idx : dark);
    }
}

export function ring(t) {
  const s = new Shape();
  const [metal, dark] = METAL[t];
  const r = 4 + t;
  band(s, r, 1 + (t >= 2 ? 1 : 0), 2 + t, metal, dark);
  const top = r + 1 + (t >= 2 ? 1 : 0);
  if (GEM[t] != null) {
    // Claws and a stone on top of the band.
    for (const dx of [-2, 2]) s.put(dx, top + 1, 1, metal).put(dx, top + 2, 1, metal);
    ellipsoid(s, [0, top + 2, 1], [1.6 + t * 0.4, 1.6 + t * 0.4, 1.4], GEM[t]);
    s.put(0, top + 3, 0, C.WHITE); // the stone's glint
  } else {
    // Tier 1: a plain signet block.
    for (let x = -2; x <= 2; x++) for (let y = top; y <= top + 1; y++) for (let z = 0; z <= 2; z++) s.put(x, y, z, metal);
  }
  if (t >= 3) for (let a = 0; a < 12; a++) { // engraved runes around the band
    const ang = (a / 12) * Math.PI * 2;
    if (Math.abs(Math.sin(ang) - 1) < 0.3) continue;
    s.put(Math.round(Math.cos(ang) * (r + 1)), Math.round(Math.sin(ang) * (r + 1)), 0, GLOW);
  }
  return s;
}

export function amulet(t) {
  const s = new Shape();
  const [metal, dark] = METAL[t];
  const chain = t === 1 ? C.IRON : C.GOLD;
  // The chain: a U from the top, links alternating light and dark.
  const cr = 7 + t;
  for (let a = 0; a <= 40; a++) {
    const ang = Math.PI + (a / 40) * Math.PI; // the lower half of a circle, opened upwards
    const x = Math.round(Math.cos(ang) * cr), y = Math.round(-Math.sin(ang) * cr) + 4;
    s.put(x, y + cr, 0, a % 2 ? chain : C.IRON_D);
  }
  // The pendant under the chain's lowest point.
  const py = 2;
  if (t === 1) cylinder(s, [0, py, 0], [0, py, 1], 3, metal);
  else if (t === 2) {
    ellipsoid(s, [0, py, 0.5], [3.5, 4.5, 1.2], metal);
    ellipsoid(s, [0, py, -0.5], [1.8, 2.4, 1], GEM[t]);
  } else {
    // A star of four points with a glowing heart.
    for (const [dx, dy] of [[0, 1], [0, -1], [1, 0], [-1, 0]])
      for (let k = 0; k <= 6; k++) for (let w = -Math.max(0, 2 - (k >> 1)); w <= Math.max(0, 2 - (k >> 1)); w++)
        s.put(dx * k + dy * w, py + dy * k + dx * w, 0, k > 4 ? dark : metal).put(dx * k + dy * w, py + dy * k + dx * w, 1, metal);
    ellipsoid(s, [0, py, -0.5], [2, 2, 1.2], GLOW);
  }
  s.put(0, py + 5 + t, 0, metal); // the bail joining pendant and chain
  return s;
}

export function jewelryV2() {
  const out = {};
  for (const t of [1, 2, 3]) {
    out[`jewel_ring_t${t}`] = { shape: ring(t), part: "hand_right", palette: PALETTE };
    out[`jewel_neck_t${t}`] = { shape: amulet(t), part: "torso", palette: PALETTE };
  }
  return out;
}
