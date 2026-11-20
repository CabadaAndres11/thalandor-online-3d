// v2 hand weapons (Plan 6.2): the same weapons as v1, twice the voxels (same length in
// metres), with filos, fullers, wrapped grips and studs in two or three tones. Drawn in
// the fist's pivot frame (hand_v2: x -3..2, y -8..0, z -2..3): grips run along +Z through
// the fist's centre (x -0.5, y -4.5), blades point forward; the staff and the bow stand
// upright through it.
import { Shape, GLOW, TINT_SECONDARY } from "./vox.mjs";
import { ellipsoid, capsule, cylinder, roundBox, carve } from "./sculpt.mjs";
import { handV2 } from "./human_v2.mjs";
import { KIT_V2, paint, STEEL, STEEL_D, STEEL_L, GOLD, GOLD_L, LEATHER, LEATHER_D, WOOD, WOOD_D, WOOD_L, STRING } from "./clothes_v2.mjs";

const S = TINT_SECONDARY;
const HAND = handV2();
const CY = -4.5, CX = -0.5, CZ = 0.5; // the centre of the fist
const PALETTE = { ...KIT_V2, [GLOW]: "#9fe0ff" };
const outsideHand = (s) => carve(s, (t) => { for (const [x, y, z] of HAND.cells.values()) t.put(x, y, z, 0); });
const recolor = (s, pred, idx) => { for (const v of s.cells.values()) if (pred(v[0], v[1], v[2], v[3])) v[3] = idx; return s; };

// A straight blade along +Z from z0 to z1, flat (x -1..0), half-width w tapering to a point.
function blade(s, z0, z1, w, m) {
  for (let z = z0; z <= z1; z++) {
    const k = Math.min(1, (z1 - z + 1) / 7);
    const half = Math.max(0.5, w * k);
    for (let y = Math.ceil(CY - half); y <= Math.floor(CY + half); y++) {
      for (const x of [-1, 0]) {
        const d = Math.abs(y - CY);
        s.put(x, y, z, d >= half - 1 ? m.edge : d < 1 && z < z1 - 8 ? m.fuller : m.blade);
      }
    }
  }
  return s;
}

function sword(m, len) {
  const s = new Shape();
  ellipsoid(s, [CX, CY, -4], [1.8, 1.8, 1.5], m.pommel);
  cylinder(s, [CX, CY, -3], [CX, CY, 3], 1.4, m.grip);
  roundBox(s, [-2, CY - 7.5, 4], [1, CY + 7.5, 5], 0.8, m.guard); // cross-guard
  blade(s, 6, 6 + len, 4, m);
  paint(s, [m.pommel, m.grip, m.guard].filter((v, i, a) => a.indexOf(v) === i), 41);
  recolor(s, (x, y, z) => z >= -3 && z <= 3 && (z + 3) % 2 === 0 && Math.abs(y - CY) > 1, LEATHER_D); // grip wraps
  return outsideHand(s);
}

const WEAPONS = {
  weapon_sword: () => sword({ blade: STEEL, edge: STEEL_L, fuller: STEEL_D, guard: GOLD, grip: LEATHER, pommel: GOLD }, 32),
  weapon_wood_sword: () => sword({ blade: WOOD, edge: WOOD_L, fuller: WOOD_D, guard: WOOD_D, grip: LEATHER, pommel: WOOD_D }, 24),
  weapon_mace() {
    const s = new Shape();
    cylinder(s, [CX, CY, -6], [CX, CY, 21], 1.3, WOOD);
    cylinder(s, [CX, CY, -3], [CX, CY, 4], 1.5, LEATHER); // wrapped grip
    ellipsoid(s, [CX, CY, 25], [3.4, 3.4, 4], STEEL);
    for (const [dx, dy] of [[4, 0], [-4, 0], [0, 4], [0, -4]]) { // flanges
      roundBox(s, [Math.round(CX + dx) - (dx ? 1 : 0), Math.round(CY + dy) - (dy ? 1 : 0), 21], [Math.round(CX + dx) + (dx ? 1 : 0), Math.round(CY + dy) + (dy ? 1 : 0), 29], 0.6, STEEL);
    }
    cylinder(s, [CX, CY, 29], [CX, CY, 32], 0.9, GOLD); // spike
    paint(s, [WOOD, LEATHER, STEEL, GOLD], 43);
    recolor(s, (x, y, z) => z === 21 || z === 29, STEEL_D);
    return outsideHand(s);
  },
  // An upright staff through the fist, reaching the ground beside the mage, crowned by a
  // glowing crystal held in gold claws.
  weapon_staff() {
    const s = new Shape();
    cylinder(s, [CX, -36, CZ], [CX, 46, CZ], 1.3, WOOD);
    paint(s, [WOOD], 45);
    for (let y = -30; y <= 40; y += 10) recolor(s, (x, yy) => yy === y, WOOD_D); // knots
    cylinder(s, [CX, 46, CZ], [CX, 47, CZ], 2.3, GOLD);
    for (const [dx, dz] of [[2, 2], [-2, 2], [2, -2], [-2, -2]]) capsule(s, [CX + dx, 47, CZ + dz], [CX + dx * 0.6, 53, CZ + dz * 0.6], 0.7, 0.5, GOLD);
    paint(s, [GOLD], 47);
    ellipsoid(s, [CX, 52, CZ], [2.1, 3.6, 2.1], GLOW);
    return outsideHand(s);
  },
  // An upright longbow in the left fist: the limbs curve back to the tips and the string
  // runs between them, on the archer's side (-Z).
  weapon_bow() {
    const s = new Shape();
    capsule(s, [CX, -13, CZ], [CX, 4, CZ], 1.6, 1.6, WOOD); // riser
    cylinder(s, [CX, -8, CZ], [CX, -1, CZ], 1.8, LEATHER); // grip
    const limb = [[4, 0.5], [12, 0], [18, -1.5], [22, -3.5], [24, -5.5]];
    for (const sign of [1, -1]) {
      for (let i = 0; i < limb.length - 1; i++) {
        const [ya, za] = limb[i], [yb, zb] = limb[i + 1];
        const fy = (y) => (sign > 0 ? y : -9 - y);
        capsule(s, [CX, fy(ya), za], [CX, fy(yb), zb], 1.4 - i * 0.2, 1.2 - i * 0.2, WOOD);
      }
    }
    paint(s, [WOOD, LEATHER], 49);
    for (let y = -33; y <= 24; y++) s.put(-1, y, -6, STRING);
    return outsideHand(s);
  },
  // A crossbow in the right fist, pointing forward: stock, rail, a prod across the front
  // with its tips bent back, the string and a bolt on the rail.
  weapon_crossbow() {
    const s = new Shape();
    roundBox(s, [-2, -8, -8], [1, -2, 20], 1, WOOD); // stock
    roundBox(s, [-2, -1, -4], [1, -1, 18], 0, WOOD_D); // rail
    capsule(s, [-15, -2.5, 19], [14, -2.5, 19], 1.4, 1.4, WOOD); // prod
    for (const x of [-15, 14]) capsule(s, [x, -2.5, 19], [x, -2.5, 13], 1.1, 0.9, WOOD);
    paint(s, [WOOD], 51);
    for (let x = -15; x <= 14; x++) s.put(x, -2, 13, STRING);
    cylinder(s, [CX, 0, -2], [CX, 0, 24], 0.6, STEEL); // bolt
    for (const z of [25, 26]) s.put(-1, 0, z, STEEL_L).put(0, 0, z, STEEL_L);
    roundBox(s, [-1, -10, -3], [0, -9, 1], 0, LEATHER_D); // trigger guard
    return outsideHand(s);
  },
  weapon_dagger_right() {
    const s = new Shape();
    cylinder(s, [CX, CY, -3], [CX, CY, 3], 1.2, LEATHER);
    roundBox(s, [-2, CY - 4, 4], [1, CY + 4, 4], 0.5, S); // guard
    blade(s, 5, 20, 2.6, { blade: STEEL_D, edge: STEEL_L, fuller: STEEL_D });
    ellipsoid(s, [CX, CY, -4], [1.4, 1.4, 1.2], GOLD);
    paint(s, [LEATHER, GOLD], 53);
    return outsideHand(s);
  },
};
WEAPONS.weapon_dagger_left = WEAPONS.weapon_dagger_right;

export function weaponsV2() {
  const out = {};
  for (const [id, build] of Object.entries(WEAPONS)) {
    const left = id === "weapon_bow" || id === "weapon_dagger_left";
    out[id] = { shape: build(), part: left ? "hand_left" : "hand_right", palette: PALETTE };
  }
  return out;
}
