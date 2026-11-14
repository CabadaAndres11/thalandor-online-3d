// Paints the starting outfit of each class on Kenney's UV layout, in the pack's style:
// flat colors, a lighter band on top and a darker one at the bottom of each face.
//   node tools/art/paint_outfits.mjs <out dir> [class ...]
import * as png from "./png.mjs";
import * as L from "./layout.mjs";

const hex = (h, a = 255) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16), a];
const shade = (c, k) => [Math.round(c[0] * k), Math.round(c[1] * k), Math.round(c[2] * k), c[3]];

function fill(img, r, color) {
  for (let y = r[1]; y < r[1] + r[3]; y++) for (let x = r[0]; x < r[0] + r[2]; x++) png.set(img, x, y, color);
}

// A face with Kenney-like shading: light band on top, dark band at the bottom.
function face(img, r, color, { light = 6, dark = 8 } = {}) {
  fill(img, r, color);
  if (light) fill(img, [r[0], r[1], r[2], light], shade(color, 1.12));
  if (dark) fill(img, [r[0], r[1] + r[3] - dark, r[2], dark], shade(color, 0.82));
}

// Horizontal band across every side face of the torso at height y (px from the top).
function torsoBand(img, y, h, color) {
  for (const k of ["left", "front", "right", "back"]) {
    const r = L.TORSO[k];
    fill(img, [r[0], r[1] + y, r[2], h], color);
  }
}

const off = (o, r) => [o[0] + r[0], o[1] + r[1], r[2], r[3]];

// Sleeves down to the hand; optional cuff band just above it. The hand stays empty
// (the skin layer shows through).
function arms(img, color, cuff) {
  for (const o of Object.values(L.ARMS)) {
    face(img, off(o, L.ARM_CAP_TOP), color, { dark: 0 });
    const s = off(o, L.ARM_SIDES);
    const sleeve = [s[0], s[1], s[2], s[3] - L.HAND_PX];
    face(img, sleeve, color, { dark: 0 });
    if (cuff) fill(img, [s[0], s[1] + sleeve[3] - 12, s[2], 12], cuff);
  }
}

// Legs: trousers or robe, then shoes (the last `shoePx` of the side faces + the sole).
function legs(img, color, shoe, { shoePx = 16, hem = null, hemY = 0 } = {}) {
  for (const o of Object.values(L.LEGS)) {
    fill(img, off(o, L.LEG_CAP_TOP), color);
    fill(img, off(o, L.LEG_CAP_BOTTOM), shade(shoe, 0.8));
    const s = off(o, L.LEG_SIDES);
    face(img, [s[0], s[1], s[2], s[3] - shoePx], color, { dark: 0 });
    if (hem) fill(img, [s[0], s[1] + hemY, s[2], 8], hem);
    face(img, [s[0], s[1] + s[3] - shoePx, s[2], shoePx], shoe, { light: 3, dark: 3 });
  }
}

function torso(img, color) {
  for (const k of ["left", "front", "right", "back"]) face(img, L.TORSO[k], color);
  fill(img, L.TORSO.top, shade(color, 1.08));
  fill(img, L.TORSO.bottom, shade(color, 0.8));
}

const OUTFITS = {
  // Long robe in deep violet with golden trim, rope belt, wide cuffs.
  mage(img) {
    const robe = hex("#5b3f9e"), gold = hex("#e8b23a"), rope = hex("#8a5a2b");
    torso(img, robe);
    const f = L.TORSO.front;
    fill(img, [f[0] + f[2] / 2 - 6, f[1], 12, f[3]], gold); // front trim
    fill(img, [f[0] + 24, f[1], f[2] - 48, 10], shade(robe, 0.7)); // collar
    torsoBand(img, 104, 10, rope);
    fill(img, [f[0] + f[2] / 2 - 10, f[1] + 101, 20, 16], gold); // knot
    arms(img, robe, gold);
    legs(img, robe, hex("#3b2a22"), { shoePx: 16, hem: gold, hemY: 128 });
  },
};

const [outDir, ...only] = process.argv.slice(2);
if (!outDir) {
  console.error("usage: node paint_outfits.mjs <out dir> [class ...]");
  process.exit(1);
}
for (const [name, paint] of Object.entries(OUTFITS)) {
  if (only.length && !only.includes(name)) continue;
  const img = png.create(L.SIZE, L.SIZE);
  paint(img);
  png.write(`${outDir}/outfit_${name}.png`, img);
  console.log("wrote outfit", name);
}
