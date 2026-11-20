// The v2 versions of the player, NPC (Plan 6.2) and cult enemy (Plan 6.4.1) pieces, sculpted on the v2 body.
//   node tools/art/make_pieces_v2.mjs <out dir> <pieces_v2.json path>
//   (assets/characters/pieces_v2 and data/characters/pieces_v2.json)
// Each piece is drawn in its part's pivot frame (the same frame human_v2.mjs draws the
// part in), so its table offset is just the shape's lowest corner. Same ids, parts, tags
// and hides as the v1 table (data/characters/pieces.json), which the table copies.
import fs from "node:fs";
import { fileURLToPath } from "node:url";
import { write, Shape, TEX_D, TEX_L, TINT_HAIR } from "./vox.mjs";
import { ellipsoid, capsule, roundBox, carve, shadeByFacing, shellAround, noise3 } from "./sculpt.mjs";
import { headV2, frontZ, PALETTE_V2, FORM } from "./human_v2.mjs";
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

export function piecesV2() {
  const out = {};
  let seed = 1;
  for (const [id, build] of Object.entries({ ...HAIR, ...BEARDS })) {
    out[id] = { shape: strands(build(), seed++), part: "head", palette: PALETTE_V2 };
  }
  return { ...out, ...clothesV2(), ...weaponsV2(), ...monstersV2() };
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
      tag: v1[id]?.tag ?? "",
      hides: v1[id]?.hides ?? [],
    };
  }
  fs.writeFileSync(jsonPath, JSON.stringify(table, null, "\t") + "\n");
  console.log(`wrote ${Object.keys(table).length} v2 pieces and ${jsonPath}`);
}
