// Paints the starting outfit of each class on Kenney's UV layout, in the pack's style:
// flat colors, a lighter band on top and a darker one at the bottom of each face.
//   node tools/art/paint_outfits.mjs <out dir> [class ...]
import * as png from "./png.mjs";
import * as L from "./layout.mjs";

const hex = (h, a = 255) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16), a];
const clamp8 = (v) => Math.min(255, Math.max(0, Math.round(v)));
const shade = (c, k) => [clamp8(c[0] * k), clamp8(c[1] * k), clamp8(c[2] * k), c[3]];

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

// Diagonal strap across the torso front (shoulder to opposite hip).
function strap(img, color, width = 12, leftToRight = true) {
  const f = L.TORSO.front;
  for (let y = 0; y < f[3]; y++) {
    const t = y / f[3];
    const cx = leftToRight ? f[0] + 8 + t * (f[2] - 16) : f[0] + f[2] - 8 - t * (f[2] - 16);
    for (let x = Math.round(cx - width / 2); x < Math.round(cx + width / 2); x++) png.set(img, x, f[1] + y, color);
  }
}

// Chain mail: grey with staggered dark rings.
function mail(img, r) {
  const base = hex("#7f868e"), ring = hex("#5a6068"), glint = hex("#9aa1a9");
  fill(img, r, base);
  for (let y = r[1]; y < r[1] + r[3] - 2; y += 6) {
    const shift = ((y - r[1]) / 6) % 2 ? 3 : 0;
    for (let x = r[0] + shift; x < r[0] + r[2] - 2; x += 6) {
      fill(img, [x, y, 3, 3], ring);
      fill(img, [x, y, 1, 1], glint);
    }
  }
}

const OUTFITS = {
  // Steel breastplate and backplate over mail, red tabard under the belt, mail
  // sleeves with steel vambraces, mail leggings with knee cops, greaves and sabatons.
  // The pauldrons are voxel pieces.
  warrior(img) {
    const steel = hex("#8d96a1"), dark = hex("#5c636c"), tabard = hex("#8e3b2e");
    const leather = hex("#5e3a22"), gold = hex("#d9a83a");
    // Mail everywhere on the torso first, then the plates on front and back.
    for (const k of ["left", "front", "right", "back"]) mail(img, L.TORSO[k]);
    fill(img, L.TORSO.top, steel);
    fill(img, L.TORSO.bottom, shade(tabard, 0.8));
    for (const k of ["front", "back"]) {
      const r = L.TORSO[k];
      const plate = [r[0] + 6, r[1], r[2] - 12, 96];
      face(img, plate, steel, { light: 8, dark: 6 });
      fill(img, [plate[0], plate[1], 4, plate[3]], shade(steel, 0.85)); // edges
      fill(img, [plate[0] + plate[2] - 4, plate[1], 4, plate[3]], shade(steel, 0.85));
      if (k === "front") fill(img, [r[0] + r[2] / 2 - 3, r[1] + 6, 6, 80], shade(steel, 1.2)); // ridge
      for (const y of [72, 84]) fill(img, [plate[0], plate[1] + y, plate[2], 2], dark); // lames
      for (const x of [plate[0] + 8, plate[0] + plate[2] - 12]) fill(img, [x, plate[1] + 10, 4, 4], dark); // rivets
    }
    torsoBand(img, 96, 10, leather);
    const f = L.TORSO.front;
    fill(img, [f[0] + f[2] / 2 - 8, f[1] + 95, 16, 12], gold); // buckle
    // Tabard panels hanging below the belt, front and back.
    for (const k of ["front", "back"]) {
      const r = L.TORSO[k];
      face(img, [r[0] + 30, r[1] + 106, r[2] - 60, 38], tabard, { light: 0, dark: 6 });
      fill(img, [r[0] + r[2] / 2 - 6, r[1] + 112, 12, 12], gold);
    }
    // Arms: mail sleeves, steel vambraces above the hand.
    for (const o of Object.values(L.ARMS)) {
      fill(img, off(o, L.ARM_CAP_TOP), steel);
      const s = off(o, L.ARM_SIDES);
      mail(img, [s[0], s[1], s[2], s[3] - L.HAND_PX]);
      face(img, [s[0], s[1] + s[3] - L.HAND_PX - 40, s[2], 40], steel, { light: 4, dark: 4 });
    }
    // Legs: mail, knee cops, greaves, sabatons.
    for (const o of Object.values(L.LEGS)) {
      fill(img, off(o, L.LEG_CAP_TOP), shade(tabard, 0.8));
      fill(img, off(o, L.LEG_CAP_BOTTOM), dark);
      const s = off(o, L.LEG_SIDES);
      mail(img, [s[0], s[1], s[2], 60]);
      face(img, [s[0], s[1] + 56, s[2], 20], steel, { light: 4, dark: 4 }); // knees
      face(img, [s[0], s[1] + 76, s[2], 64], shade(steel, 0.95), { light: 3, dark: 6 }); // greaves
      face(img, [s[0], s[1] + 140, s[2], 20], dark, { light: 3, dark: 3 }); // sabatons
    }
  },
  // Cream habit with a blue stole down the front, rope belt, sandals.
  cleric(img) {
    const habit = hex("#e9e2cf"), stole = hex("#3a6fb0"), rope = hex("#b08a52");
    torso(img, habit);
    const f = L.TORSO.front;
    fill(img, [f[0] + 30, f[1], 14, f[3]], stole);
    fill(img, [f[0] + f[2] - 44, f[1], 14, f[3]], stole);
    fill(img, [f[0] + 33, f[1] + 70, 8, 8], hex("#e8b23a")); // embroidered crosses
    fill(img, [f[0] + f[2] - 41, f[1] + 70, 8, 8], hex("#e8b23a"));
    torsoBand(img, 104, 8, rope);
    arms(img, habit, shade(habit, 0.85));
    legs(img, habit, hex("#7a5532"), { shoePx: 12, hem: stole, hemY: 132 });
  },
  // Leather jerkin over a green shirt, quiver strap across the chest and quiver on
  // the back, dark trousers and tall boots.
  archer(img) {
    const jerkin = hex("#6b4a2b"), shirt = hex("#4f7a3a"), strapC = hex("#3b2717");
    torso(img, jerkin);
    const f = L.TORSO.front, b = L.TORSO.back;
    fill(img, [f[0], f[1], f[2], 14], shirt); // shirt collar
    strap(img, strapC, 12, true);
    torsoBand(img, 110, 10, strapC);
    // Quiver on the back with fletchings.
    fill(img, [b[0] + 70, b[1] + 6, 30, 110], hex("#4a311c"));
    for (const x of [74, 82, 90]) fill(img, [b[0] + x, b[1], 6, 10], hex("#e9e2cf"));
    arms(img, shirt, jerkin);
    legs(img, hex("#3f4a2e"), hex("#4a311c"), { shoePx: 40 });
  },
  // Close-fitting charcoal clothes, crossed straps, dark red sash, soft boots.
  assassin(img) {
    const cloth = hex("#2d2f3a"), sash = hex("#8a2433"), strapC = hex("#1b1c24");
    torso(img, cloth);
    strap(img, strapC, 8, true);
    strap(img, strapC, 8, false);
    torsoBand(img, 100, 14, sash);
    const s = L.TORSO.right;
    fill(img, [s[0] + 30, s[1] + 100, 16, 40], sash); // sash tails
    arms(img, cloth, sash);
    legs(img, shade(cloth, 1.1), hex("#1b1c24"), { shoePx: 30 });
  },

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

// --- Monster skins (the skin color comes from data/monsters "look") ---------------

// Ragged bottom edge: a band whose lower edge goes up and down in teeth.
function ragged(img, r, color, tooth = 10) {
  for (let x = r[0]; x < r[0] + r[2]; x++) {
    const k = Math.floor((x - r[0]) / tooth) % 3;
    const h = r[3] - (k === 0 ? 0 : k === 1 ? 6 : 12);
    for (let y = r[1]; y < r[1] + h; y++) png.set(img, x, y, color);
  }
}

const MONSTERS = {
  // Orc king: blackened iron breastplate over dark leather, a fur mantle on the
  // shoulders, red war paint across the eyes, a heavy belt with a gold skull buckle,
  // iron bracers, dark trousers and iron-shod boots. Pauldrons, crown, tusks and axe
  // are voxel pieces.
  orc_king(img) {
    const iron = hex("#3a3d44"), ironLight = hex("#5a5f69"), leather = hex("#2e2219");
    const fur = hex("#5a4632"), furDark = hex("#3e3022"), gold = hex("#c9962e"), paint = hex("#a01c14");
    for (const k of ["left", "front", "right", "back"]) face(img, L.TORSO[k], leather);
    for (const k of ["front", "back"]) {
      const r = L.TORSO[k];
      const plate = [r[0] + 8, r[1] + 16, r[2] - 16, 82];
      face(img, plate, iron, { light: 6, dark: 6 });
      for (const y of [30, 54]) fill(img, [plate[0], plate[1] + y, plate[2], 3], ironLight);
      for (const x of [plate[0] + 6, plate[0] + plate[2] - 10]) for (const y of [8, 70]) fill(img, [x, plate[1] + y, 4, 4], gold);
    }
    // Fur mantle: a ragged band across the top of the torso.
    for (const k of ["left", "front", "right", "back"]) {
      const r = L.TORSO[k];
      ragged(img, [r[0], r[1], r[2], 22], fur, 6);
      for (let x = r[0] + 3; x < r[0] + r[2]; x += 9) fill(img, [x, r[1] + 4, 3, 10], furDark);
    }
    fill(img, L.TORSO.top, fur);
    torsoBand(img, 100, 14, hex("#5b1a14"));
    const f = L.TORSO.front;
    // Gold skull buckle: a square skull with dark eye holes.
    fill(img, [f[0] + f[2] / 2 - 10, f[1] + 98, 20, 18], gold);
    fill(img, [f[0] + f[2] / 2 - 6, f[1] + 102, 4, 4], leather);
    fill(img, [f[0] + f[2] / 2 + 2, f[1] + 102, 4, 4], leather);
    fill(img, [f[0] + f[2] / 2 - 4, f[1] + 110, 8, 2], leather);
    fill(img, L.TORSO.bottom, leather);
    // Arms: bare green skin with iron bracers above the hands.
    for (const o of Object.values(L.ARMS)) {
      fill(img, off(o, L.ARM_CAP_TOP), fur);
      const s = off(o, L.ARM_SIDES);
      face(img, [s[0], s[1] + s[3] - L.HAND_PX - 44, s[2], 40], iron, { light: 4, dark: 4 });
      fill(img, [s[0], s[1] + s[3] - L.HAND_PX - 26, s[2], 3], gold);
    }
    legs(img, hex("#2a2420"), iron, { shoePx: 34 });
    // War paint: a red band across the eyes on the face.
    const head = L.HEAD.front;
    for (const e of L.EYES) {
      for (let y = e[1] - 6; y < e[1] + e[3] + 6; y++) for (let x = e[0] - 10; x < e[0] + e[2] + 10; x++) {
        const inEye = x >= e[0] && x < e[0] + e[2] && y >= e[1] && y < e[1] + e[3];
        if (!inEye) png.set(img, x, y, paint);
      }
    }
    fill(img, [head[0] + 56, head[1] + 66, 16, 6], paint);
  },
  // Goblin: bare green skin, a crude leather harness, a ragged loincloth, leather
  // wrist wraps and ragged short trousers; bare feet.
  goblin(img) {
    const leather = hex("#4a3322"), cloth = hex("#5b4630"), dirt = hex("#3a2a1a", 110);
    strap(img, leather, 10, true);
    torsoBand(img, 100, 10, leather);
    const f = L.TORSO.front;
    fill(img, [f[0] + 20, f[1] + 20, 10, 10], hex("#9aa0a6")); // a rusty buckle
    for (const k of ["front", "back"]) ragged(img, [L.TORSO[k][0] + 18, L.TORSO[k][1] + 110, L.TORSO[k][2] - 36, 34], cloth);
    fill(img, L.TORSO.bottom, shade(cloth, 0.8));
    for (const o of Object.values(L.ARMS)) {
      const s = off(o, L.ARM_SIDES);
      fill(img, [s[0], s[1] + s[3] - L.HAND_PX - 22, s[2], 16], leather); // wraps
      fill(img, [s[0], s[1] + s[3] - L.HAND_PX - 16, s[2], 2], shade(leather, 0.7));
    }
    for (const o of Object.values(L.LEGS)) {
      fill(img, off(o, L.LEG_CAP_TOP), cloth);
      const s = off(o, L.LEG_SIDES);
      ragged(img, [s[0], s[1], s[2], 66], cloth, 12);
      for (const x of [20, 90, 170, 230]) fill(img, [s[0] + x, s[1] + 100 + (x % 30), 8, 6], dirt);
    }
    for (const x of [30, 70, 100]) fill(img, [f[0] + x, f[1] + 60 + (x % 20), 8, 6], dirt);
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
for (const [name, paint] of Object.entries(MONSTERS)) {
  if (only.length && !only.includes(name)) continue;
  const img = png.create(L.SIZE, L.SIZE);
  paint(img);
  png.write(`${outDir}/outfit_${name}.png`, img);
  console.log("wrote monster skin", name);
}
