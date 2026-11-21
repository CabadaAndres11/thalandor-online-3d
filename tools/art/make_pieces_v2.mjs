// The v2 versions of the player, NPC (Plan 6.2) and cult enemy (Plan 6.4.1) pieces, sculpted on the v2 body.
//   node tools/art/make_pieces_v2.mjs <out dir> <pieces_v2.json path>
//   (assets/characters/pieces_v2 and data/characters/pieces_v2.json)
// Each piece is drawn in its part's pivot frame (the same frame human_v2.mjs draws the
// part in), so its table offset is just the shape's lowest corner. Same ids, parts, tags
// and hides as the v1 table (data/characters/pieces.json), which the table copies.
import fs from "node:fs";
import { fileURLToPath } from "node:url";
import { write, Shape, TEX_D, TEX_L, TINT_HAIR, TINT_SKIN, SHADE, LIGHT } from "./vox.mjs";
import { ellipsoid, capsule, roundBox, carve, shadeByFacing, shellAround, noise3 } from "./sculpt.mjs";
import { headV2, frontZ, PALETTE_V2, FORM, finish, LIP } from "./human_v2.mjs";
import { headLizardV2 } from "./races_v2.mjs";
import { clothesV2 } from "./clothes_v2.mjs";
import { weaponsV2 } from "./weapons_v2.mjs";
import { monstersV2 } from "./monsters_v2.mjs";

const H = TINT_HAIR;
const HEAD = headV2();

// Removes every cell of the head (pieces sit on it, never inside).
const offHead = (s) => carve(s, (t) => { for (const [x, y, z] of HEAD.cells.values()) t.put(x, y, z, 0); });

// Hair texture: streaks that run down the back and sides and front-to-back over the top,
// then the form (shade facing down/back, light on top).
function strands(s, seed) {
  for (const v of s.cells.values()) {
    if (v[3] !== H) continue;
    const [x, y, z] = v;
    const n = y >= 13 ? noise3(x, 0, Math.floor(z / 6), seed) : noise3(x, 0, z, seed);
    v[3] = n < 0.25 ? TEX_D(H) : n > 0.82 ? TEX_L(H) : H;
  }
  const idxs = [H, TEX_D(H), TEX_L(H)];
  const map = Object.fromEntries(idxs.map((i) => [i, FORM[H]]));
  return shadeByFacing(s, idxs, map);
}

// Near an ear: left bare by short caps.
const nearEar = (x, y, z) => (x <= -7 || x >= 6) && y >= 5 && y <= 11 && z >= -3 && z <= 1;

// The cap of short styles: two layers over the crown, the back down to the nape and the
// sides above the ears; the hairline over the forehead at y 14.
function cap(layers = 2) {
  return shellAround(HEAD, layers, H, (x, y, z) => {
    if (nearEar(x, y, z)) return false;
    if (z >= 3) return y >= 14;
    if (z >= -1) return y >= 11;
    return y >= 5;
  });
}

const merge = (...shapes) => {
  const out = new Shape();
  for (const s of shapes) for (const [x, y, z, i] of s.cells.values()) out.put(x, y, z, i);
  return out;
};

// The front surface of the head, `out` voxels proud of it, for each (x, y) where keep holds.
function overFace(keep, out = 1, depth = 1) {
  const s = new Shape();
  for (let x = -8; x <= 7; x++) for (let y = -2; y <= 17; y++) {
    if (!keep(x, y)) continue;
    const z = frontZ(HEAD, x, y);
    if (z === null) continue;
    for (let d = 0; d < depth; d++) s.put(x, y, z + out + d, H);
  }
  return s;
}

const HAIR = {
  // Short, with a fringe swept to one side.
  hair_short() {
    const fringe = shellAround(HEAD, 2, H, (x, y, z) => z >= 3 && x >= -6 && x <= 3 && y >= 12 + Math.max(0, (x + 6) / 4) && y <= 15);
    return merge(cap(), fringe);
  },
  // Bob: straight to the jaw at the sides and back, a full fringe.
  hair_bob() {
    const sides = shellAround(HEAD, 2, H, (x, y, z) => y >= 2 && ((z <= 2 && (x <= -6 || x >= 5)) || z <= -3));
    const fringe = shellAround(HEAD, 2, H, (x, y, z) => z >= 3 && y >= 12 && y <= 15);
    const s = merge(cap(), sides, fringe);
    for (const v of s.cells.values()) if (v[1] === 2) v[3] = H; // a straight-cut hem (kept in tone)
    return s;
  },
  // Swept back: a thick quiff over the forehead, combed backwards.
  hair_swept() {
    const top = shellAround(HEAD, 3, H, (x, y, z) => y >= 14 && z >= -5);
    const quiff = offHead(ellipsoid(new Shape(), [-0.5, 16, 4], [6.2, 2.6, 3.2], H));
    return merge(cap(), top, quiff);
  },
  // Long: a bob with a curtain down the back to the shoulder blades (worn with hair_bob).
  hair_long() {
    const s = new Shape();
    for (let x = -8; x <= 7; x += 2) { // locks of different lengths, falling a little outwards
      const len = 12 + Math.round(noise3(x, 1, 2, 9) * 6);
      const out = (x + 0.5) * 0.12;
      capsule(s, [x, 11, -9], [x + out, -len, -10.5], 1.7, 1.3, H);
    }
    return offHead(s);
  },
  // Ponytail tied high at the back (worn with hair_short).
  hair_ponytail() {
    const s = offHead(ellipsoid(new Shape(), [-0.5, 12, -9.5], [2.8, 2.6, 2.2], H));
    capsule(s, [-0.5, 10, -11], [-0.5, -8, -12.5], 2.3, 1.3, H);
    offHead(s);
    return s;
  },
  // Round bun at the back of the head (worn with hair_swept).
  hair_bun() {
    return offHead(ellipsoid(new Shape(), [-0.5, 13, -9.8], [3.8, 3.8, 3.2], H));
  },
  // A crest over a shaved head, tallest over the crown, down to the nape.
  hair_mohawk() {
    const s = new Shape();
    for (let z = -8; z <= 6; z++) {
      const h = Math.round(5 - Math.abs(z + 1) / 2.2);
      for (let x = -2; x <= 1; x++) {
        let top = -1;
        for (const [cx, cy, cz] of HEAD.cells.values()) if (cx === x && cz === z && cy > top) top = cy;
        if (top < 12) continue; // only over the skull, never down the face
        for (let y = top + 1; y <= top + Math.max(1, h); y++) s.put(x, y, z, H);
      }
    }
    const nape = shellAround(HEAD, 1, H, (x, y, z) => x >= -2 && x <= 1 && z <= -3 && y >= 4);
    return merge(s, nape);
  },
};

// The mouth and the nose stay bare.
const onMouth = (x, y) => x >= -3 && x <= 2 && y >= 1 && y <= 4;
const onNose = (x, y) => x >= -2 && x <= 1 && y >= 4;

const mustache = () => merge(
  overFace((x, y) => y === 4 && x >= -4 && x <= 3, 1, 2),
  overFace((x, y) => (x === -4 || x === 3) && y >= 1 && y <= 3, 1, 1));

const BEARDS = {
  beard_mustache: mustache,
  beard_goatee() {
    const chin = shellAround(HEAD, 2, H, (x, y, z) => x >= -3 && x <= 2 && y >= -3 && y <= 1 && z >= 2);
    return merge(mustache(), chin);
  },
  // Short: along the jaw and chin, sideburns up to the ears.
  beard_short() {
    return shellAround(HEAD, 1, H, (x, y, z) => {
      if (z < -2 || y > 8 || y < -2 || onMouth(x, y) || onNose(x, y)) return false;
      if (y >= 5) return (x <= -6 || x >= 5) && z <= 2; // sideburns
      return true;
    });
  },
  // Full: thick along the jaw, a mustache and a mass under the chin.
  beard_full() {
    const jaw = shellAround(HEAD, 2, H, (x, y, z) => {
      if (z < -2 || y > 8 || y < -6 || onMouth(x, y) || onNose(x, y)) return false;
      if (y >= 5) return (x <= -6 || x >= 5) && z <= 2;
      return true;
    });
    const mass = offHead(ellipsoid(new Shape(), [-0.5, -1.5, 3], [5.6, 4.6, 4.2], H));
    carve(mass, (t) => { for (let x = -3; x <= 2; x++) for (let y = 1; y <= 4; y++) for (let z = 0; z <= 12; z++) t.put(x, y, z, 0); });
    return merge(jaw, mass, mustache());
  },
};

// --- Plan 7: new hair and beards, face marks, race pieces and lizard crests ------------

const SKN = TINT_SKIN;
const PAINT = 54, INK = 55; // war paint and rune ink
const MARK_PALETTE = { ...PALETTE_V2, [PAINT]: "#8e1b1b", [INK]: "#24406b" };

// A braid: alternating wider and narrower knots down a line.
function braid(s, top, bottom, r) {
  const n = Math.max(2, Math.round(Math.hypot(top[0] - bottom[0], top[1] - bottom[1], top[2] - bottom[2]) / 2));
  for (let k = 0; k <= n; k++) {
    const t = k / n;
    const c = [0, 1, 2].map((i) => top[i] + (bottom[i] - top[i]) * t);
    ellipsoid(s, c, [r * (k % 2 ? 0.8 : 1), 1.2, r * (k % 2 ? 0.8 : 1)], H);
  }
  return s;
}

const NEW_HAIR = {
  // Two braids hanging behind the ears down to the chest.
  hair_braids() {
    const s = new Shape();
    for (const x of [-7.5, 6.5]) braid(s, [x, 8, -3], [x * 1.05, -10, -1], 1.6);
    return merge(cap(), offHead(s));
  },
  // Undercut: shaved sides, a long top combed to one side.
  hair_undercut() {
    const top = shellAround(HEAD, 3, H, (x, y, z) => y >= 14 && x >= -5 && x <= 4);
    const sweep = offHead(ellipsoid(new Shape(), [1.5, 16.5, 2], [5.5, 2.2, 5], H));
    return merge(top, sweep);
  },
  // Long and loose: thick to the shoulders all round.
  hair_loose() {
    const sides = shellAround(HEAD, 2, H, (x, y, z) => y >= -3 && ((z <= 2 && (x <= -6 || x >= 5)) || z <= -3));
    const s = new Shape();
    for (let x = -8; x <= 7; x += 2) capsule(s, [x, 6, -8.5], [x * 1.08, -8, -9.5], 1.8, 1.5, H);
    return merge(cap(), sides, offHead(s));
  },
  // A ponytail tied on the crown, falling down the back.
  hair_high_ponytail() {
    const knot = offHead(ellipsoid(new Shape(), [-0.5, 17, -5], [2.6, 2.4, 2.6], H));
    const tail = offHead(capsule(new Shape(), [-0.5, 17, -7], [-0.5, -2, -11.5], 2.4, 1.2, H));
    return merge(cap(), knot, tail);
  },
  // A single thick warrior braid from the crown down the back.
  hair_warrior_braid() {
    return merge(cap(), offHead(braid(new Shape(), [-0.5, 13, -9], [-0.5, -12, -11], 2.2)));
  },
  // Curls: a round mass of small knots over the skull.
  hair_curls() {
    const s = new Shape();
    for (const [x, y, z] of shellAround(HEAD, 2, H, (x, y, z) => !nearEar(x, y, z) && (z >= 3 ? y >= 13 : y >= 6)).cells.values()) {
      if (noise3(x, y, z, 77) > 0.35) ellipsoid(s, [x, y, z], [1.3, 1.3, 1.3], H);
    }
    return offHead(s);
  },
  // Shaggy: uneven locks over the forehead and the nape.
  hair_shaggy() {
    const s = new Shape();
    for (let x = -7; x <= 6; x += 2) {
      const len = 2 + Math.round(noise3(x, 2, 3, 5) * 4);
      capsule(s, [x, 15, 4], [x, 15 - len, 6.5], 1.5, 1, H);
      capsule(s, [x, 8, -8], [x, 8 - len * 1.5, -9.5], 1.5, 1, H);
    }
    return merge(cap(3), offHead(s));
  },
  // Half up: a small knot at the back, the rest down to the jaw.
  hair_half_up() {
    const sides = shellAround(HEAD, 2, H, (x, y, z) => y >= 1 && ((z <= 2 && (x <= -6 || x >= 5)) || z <= -3));
    const knot = offHead(ellipsoid(new Shape(), [-0.5, 13, -9.5], [2.4, 2.2, 2], H));
    return merge(cap(), sides, knot);
  },
};

const NEW_BEARDS = {
  // Dwarf: a long braided beard to the belt, gathered in a ring.
  beard_dwarf_braided() {
    const jaw = shellAround(HEAD, 2, H, (x, y, z) => z >= -2 && y <= 8 && y >= -6 && !onMouth(x, y) && !onNose(x, y) && (y < 5 || ((x <= -6 || x >= 5) && z <= 2)));
    const b = braid(new Shape(), [-0.5, -5, 5], [-0.5, -24, 7], 3);
    return merge(jaw, offHead(b), mustache());
  },
  // Dwarf: forked in two braids.
  beard_dwarf_forked() {
    const mass = offHead(ellipsoid(new Shape(), [-0.5, -2, 3], [5.6, 4.6, 4.2], H));
    carve(mass, (t) => { for (let x = -3; x <= 2; x++) for (let y = 1; y <= 4; y++) for (let z = 0; z <= 12; z++) t.put(x, y, z, 0); });
    const s = new Shape();
    for (const x of [-3, 2]) braid(s, [x, -5, 5], [x * 1.3, -18, 6.5], 2);
    return merge(mass, offHead(s), mustache());
  },
  beard_sideburns() {
    return shellAround(HEAD, 1, H, (x, y, z) => (x <= -6 || x >= 5) && y >= 3 && y <= 10 && z >= -2 && z <= 2);
  },
  // A thin line along the jaw from ear to ear.
  beard_chinstrap() {
    return shellAround(HEAD, 1, H, (x, y, z) => z >= -2 && y <= 6 && y >= -3 && !onMouth(x, y) && !onNose(x, y) && (y <= 1 || x <= -5 || x >= 4));
  },
  // Stubble: a sparse layer over the jaw.
  beard_stubble() {
    const s = overFace((x, y) => y <= 3 && y >= -1 && !onMouth(x, y) && (x + y) % 2 === 0, 1, 1);
    return s;
  },
};

// Face marks: one voxel proud of the face, in skin shade, paint or ink.
const MARKS = {
  mark_scar_eye: () => overFace((x, y) => x === 3 && y >= 6 && y <= 12, 1, 1),
  mark_scar_cheek: () => overFace((x, y) => y === Math.round(4 + (x + 5) * 0.5) && x <= -2 && x >= -6, 1, 1),
  mark_warpaint: () => overFace((x, y) => (y >= 5 && y <= 6 && (x <= -3 || x >= 2)) || (y <= 1 && x >= -1 && x <= 0), 1, 1),
  mark_runes: () => overFace((x, y) => (y === 13 && x >= -2 && x <= 1) || (y === 12 && (x === -2 || x === 1)) || (x === -6 && y >= 4 && y <= 7), 1, 1),
  mark_freckles: () => overFace((x, y) => y >= 6 && y <= 8 && Math.abs(x + 0.5) >= 2 && noise3(x, y, 0, 13) > 0.55, 1, 1),
};
const MARK_COLOR = { mark_scar_eye: LIP, mark_scar_cheek: LIP, mark_warpaint: PAINT, mark_runes: INK, mark_freckles: SHADE(SKN) };

function recolor(s, idx) {
  for (const v of s.cells.values()) v[3] = idx;
  return s;
}

// Elf ears: long and pointed, up and back from where the human ear is.
function earsElf() {
  const s = new Shape();
  // Long enough for the tips to stand out of any hair at the sides.
  for (const [x, dir] of [[-8, -1], [7, 1]]) capsule(s, [x, 7, -1], [x + dir * 5, 15, -5], 1.7, 0.5, SKN);
  carve(s, (t) => { for (const [x, y, z] of HEAD.cells.values()) t.put(x, y, z, 0); });
  return finish(s, [SKN], 61);
}

// Dwarf nose: big and round, over the human one.
function noseDwarf() {
  const s = offHead(ellipsoid(new Shape(), [-0.5, 6, 8], [2.6, 2.6, 2.4], SKN));
  return finish(s, [SKN], 63);
}

// Lizard tail from the back of the hips, curving down to the ground and out behind.
function tailLizard() {
  const s = new Shape();
  const pts = [[-0.5, 3, -6], [-0.5, -6, -11], [-0.5, -18, -17], [-0.5, -30, -25], [-0.5, -40, -36]];
  const radii = [5, 4.2, 3.2, 2.2, 1];
  for (let k = 0; k + 1 < pts.length; k++) capsule(s, pts[k], pts[k + 1], radii[k], radii[k + 1], SKN);
  finish(s, [SKN], 65, [0.5, 0.3, 0.2]);
  for (const [x, y, z] of [...s.cells.values()]) if (Math.abs(x + 0.5) < 1 && y % 3 === 0) {
    let top = true;
    if (s.cells.has(`${x},${y + 1},${z}`)) top = false;
    if (top) s.put(x, y + 1, z, SHADE(SKN)); // a ridge of scales along the top
  }
  return s;
}

// Crests on the lizard head (they replace hair): hair-tinted, drawn on its skull.
const LIZARD = headLizardV2();
const offLizard = (s) => carve(s, (t) => { for (const [x, y, z] of LIZARD.cells.values()) t.put(x, y, z, 0); });
const CRESTS = {
  crest_fin() { // a fin from the brow to the nape
    const s = new Shape();
    for (let z = -8; z <= 4; z++) for (let y = 16; y <= 16 + Math.round(4 - Math.abs(z + 2) / 2); y++) s.put(-1, y, z, H).put(0, y, z, H);
    return offLizard(s);
  },
  crest_spikes() { // a row of spikes
    const s = new Shape();
    for (let z = -7; z <= 3; z += 3) capsule(s, [-0.5, 15, z], [-0.5, 21, z - 2], 1.4, 0.4, H);
    return offLizard(s);
  },
  crest_frill() { // a frill fanning out behind the jaw
    const s = new Shape();
    for (let a = -1.2; a <= 1.2; a += 0.3) capsule(s, [-0.5, 7, -6], [-0.5 + Math.sin(a) * 11, 7 + Math.cos(a) * 9, -9], 1, 0.6, H);
    return offLizard(s);
  },
  crest_horns() { // two swept-back horns
    const s = new Shape();
    for (const x of [-4, 3]) capsule(s, [x, 14, 0], [x * 1.4, 19, -9], 1.6, 0.5, H);
    return offLizard(s);
  },
};

export function plan7PiecesV2() {
  const out = {};
  let seed = 101;
  for (const [id, build] of Object.entries(NEW_HAIR)) out[id] = { shape: strands(build(), seed++), part: "head", tag: "hair", palette: PALETTE_V2 };
  for (const [id, build] of Object.entries(NEW_BEARDS)) out[id] = { shape: strands(build(), seed++), part: "head", tag: "beard", palette: PALETTE_V2 };
  for (const [id, build] of Object.entries(MARKS)) out[id] = { shape: recolor(build(), MARK_COLOR[id]), part: "head", tag: "mark", palette: MARK_PALETTE };
  for (const [id, build] of Object.entries(CRESTS)) out[id] = { shape: strands(build(), seed++), part: "head", tag: "hair", palette: PALETTE_V2 };
  out.ears_elf = { shape: earsElf(), part: "head", tag: "ears", palette: PALETTE_V2 };
  out.nose_dwarf = { shape: noseDwarf(), part: "head", tag: "face", palette: PALETTE_V2 };
  out.tail_lizard = { shape: tailLizard(), part: "hips", tag: "tail", palette: PALETTE_V2 };
  return out;
}

export function piecesV2() {
  const out = {};
  let seed = 1;
  for (const [id, build] of Object.entries({ ...HAIR, ...BEARDS })) {
    out[id] = { shape: strands(build(), seed++), part: "head", palette: PALETTE_V2 };
  }
  return { ...out, ...plan7PiecesV2(), ...clothesV2(), ...weaponsV2(), ...monstersV2() };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [outDir, jsonPath] = process.argv.slice(2);
  if (!outDir || !jsonPath) {
    console.error("usage: node make_pieces_v2.mjs <out dir> <pieces_v2.json path>");
    process.exit(1);
  }
  const v1 = JSON.parse(fs.readFileSync(new URL("../../data/characters/pieces.json", import.meta.url)));
  fs.mkdirSync(outDir, { recursive: true });
  for (const f of fs.readdirSync(outDir)) if (f.endsWith(".vox")) fs.unlinkSync(`${outDir}/${f}`);
  const table = {};
  for (const [id, p] of Object.entries(piecesV2())) {
    write(`${outDir}/${id}.vox`, p.shape.size(), p.shape.voxels(), p.palette);
    table[id] = {
      file: `res://assets/characters/pieces_v2/${id}.vox`,
      part: p.part,
      offset: p.shape.min(),
      tag: v1[id]?.tag ?? p.tag ?? "",
      hides: v1[id]?.hides ?? p.hides ?? [],
    };
  }
  fs.writeFileSync(jsonPath, JSON.stringify(table, null, "\t") + "\n");
  console.log(`wrote ${Object.keys(table).length} v2 pieces and ${jsonPath}`);
}
