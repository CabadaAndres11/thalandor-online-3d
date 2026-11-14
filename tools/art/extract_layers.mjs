// Builds the character texture layers from Kenney Blocky Characters textures.
//   node tools/art/extract_layers.mjs <kenney Textures dir> <out dir>
// Tinted layers are grey (the shader multiplies them by the chosen color), keeping
// Kenney's shading as relative brightness. See tools/art/README.md.
import * as png from "./png.mjs";
import * as L from "./layout.mjs";

const [srcDir, outDir] = process.argv.slice(2);
if (!srcDir || !outDir) {
  console.error("usage: node extract_layers.mjs <kenney Textures dir> <out dir>");
  process.exit(1);
}
const tex = (letter) => png.read(`${srcDir}/texture-${letter}.png`);

const lum = (c) => 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2];

// Does `px` look like `ref` (same hue/saturation, brightness within [lo, hi] of it)?
// Returns the brightness ratio, or -1.
function likeness(px, ref, lo, hi, tol = 0.12) {
  if (px[3] < 128) return -1;
  const lp = Math.max(lum(px), 1), lr = Math.max(lum(ref), 1);
  const ratio = lp / lr;
  if (ratio < lo || ratio > hi) return -1;
  let d = 0;
  for (let i = 0; i < 3; i++) d += (px[i] / lp - ref[i] / lr) ** 2;
  return Math.sqrt(d) <= tol ? ratio : -1;
}

const inRect = (x, y, r) => x >= r[0] && y >= r[1] && x < r[0] + r[2] && y < r[1] + r[3];
const grey = (v, a = 255) => {
  const g = Math.round(Math.min(Math.max(v, 0), 1) * 255);
  return [g, g, g, a];
};

function eachInArea(area, fn) {
  for (let y = area[1]; y < area[1] + area[3]; y++) for (let x = area[0]; x < area[0] + area[2]; x++) fn(x, y);
}

// Skin: flat white everywhere (the tint gives the exact tone) plus Kenney's shading
// (ears, nose) taken from `letter`; the forehead stays flat so bald heads have no
// hair shadow.
function skinLayer(letter, refXY) {
  const src = tex(letter);
  const ref = png.get(src, ...refXY);
  const out = png.create(L.SIZE, L.SIZE);
  for (let y = 0; y < L.SIZE; y++) for (let x = 0; x < L.SIZE; x++) png.set(out, x, y, grey(1));
  // Only the ears (side faces) and the nose keep Kenney's shading: scars, freckles
  // and the shadow under the hair belong to that one character.
  for (const area of [L.HEAD.left, L.HEAD.right, L.NOSE]) {
    eachInArea(area, (x, y) => {
      const r = likeness(png.get(src, x, y), ref, 0.6, 1.15);
      if (r > 0) png.set(out, x, y, grey(Math.min(r, 1)));
    });
  }
  return out;
}

// Hair or beard from `letter`: pixels like the reference color inside the head,
// minus `exclude` rectangles (e.g. the eyebrows, which are drawn separately).
function tintedFrom(letter, refXY, { lo = 0.45, hi = 1.3, exclude = [], areas = Object.values(L.HEAD), gain = 0.9, tol = 0.12 } = {}) {
  const src = tex(letter);
  const ref = png.get(src, ...refXY);
  const out = png.create(L.SIZE, L.SIZE);
  for (const area of areas) {
    eachInArea(area, (x, y) => {
      if (exclude.some((r) => inRect(x, y, r))) return;
      const r = likeness(png.get(src, x, y), ref, lo, hi, tol);
      if (r > 0) png.set(out, x, y, grey(r * gain));
    });
  }
  return out;
}

function rects(list, color) {
  const out = png.create(L.SIZE, L.SIZE);
  for (const r of list) eachInArea(r, (x, y) => png.set(out, x, y, color));
  return out;
}

// Rounded rectangle helper for the drawn features.
function roundRects(list, color, radius) {
  const out = png.create(L.SIZE, L.SIZE);
  for (const r of list) {
    eachInArea(r, (x, y) => {
      const dx = Math.max(r[0] + radius - x - 0.5, x + 0.5 - (r[0] + r[2] - radius), 0);
      const dy = Math.max(r[1] + radius - y - 0.5, y + 0.5 - (r[1] + r[3] - radius), 0);
      if (dx * dx + dy * dy <= radius * radius) png.set(out, x, y, color);
    });
  }
  return out;
}

function merge(...layers) {
  const out = png.create(L.SIZE, L.SIZE);
  for (const l of layers) for (let i = 0; i < out.data.length; i += 4) if (l.data[i + 3] > 0) out.data.set(l.data.subarray(i, i + 4), i);
  return out;
}

const brows = L.BROWS;
const save = (name, img) => {
  png.write(`${outDir}/${name}.png`, img);
  console.log("wrote", name);
};

// Character a: dark short hair, light skin, grey-blue beard.
save("skin", skinLayer("a", [143, 210]));
save("eyes", roundRects(L.EYES, grey(1), 3));
save("brows", roundRects(brows, grey(0.55), 4));
save(
  "face",
  merge(
    roundRects([L.MOUTH], [92, 52, 46, 255], 3),
    rects(L.EYES.map(([x, y]) => [x + 3, y + 3, 4, 4]), [255, 255, 255, 230]),
  ),
);
// Hair never reaches the eyes or the lower middle of the face (freckles, mouths and
// moustaches of the source characters live there).
const notFace = [...brows, ...L.EYES, [140, 196, 104, 60]];
save("hair_short", tintedFrom("a", [192, 64], { exclude: notFace }));
save("hair_bob", tintedFrom("e", [192, 64], { exclude: notFace }));
save("hair_swept", tintedFrom("f", [192, 64], { exclude: notFace }));

const lowerFace = [L.HEAD.front[0], 200, 128, 56];
const lowerSides = [[L.HEAD.left[0], 200, 128, 56], [L.HEAD.right[0], 200, 128, 56]];
save("beard_full", tintedFrom("a", [192, 248], { lo: 0.6, hi: 1.3, exclude: brows }));
save("beard_mustache", tintedFrom("j", [192, 212], { lo: 0.7, hi: 1.3, areas: [[L.HEAD.front[0], 196, 128, 40]] }));
save("beard_short", tintedFrom("k", [192, 245], { lo: 0.85, hi: 1.15, tol: 0.06, areas: [lowerFace, ...lowerSides], gain: 0.75 }));
save("beard_goatee", tintedFrom("a", [192, 248], { lo: 0.6, hi: 1.3, areas: [[166, 214, 54, 42]] }));
