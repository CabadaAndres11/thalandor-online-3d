// Generates the voxel pieces (.vox) of the characters and data/characters/pieces.json.
//   node tools/art/make_pieces.mjs <pieces out dir> <pieces.json path>
// Coordinates are Godot axes, in voxels; the character faces +Z. Each piece is drawn
// in its part's frame:
//   head:  the head occupies x 1..8, y 3..10, z 2..9 (frame origin at [-5, -3, -6]
//          from the head's bottom centre);
//   torso: the torso occupies x 1..8, y 1..9, z 1..6 (origin at [-5, 2, -4] from the
//          torso's origin; the torso mesh spans y 3..12 voxels).
import fs from "node:fs";
import { write, Shape, TINT_HAIR, TINT_PRIMARY, TINT_SECONDARY } from "./vox.mjs";

const H = TINT_HAIR, P = TINT_PRIMARY, S = TINT_SECONDARY;
const HEAD = { x0: 1, x1: 8, y0: 3, y1: 10, z0: 2, z1: 9, part: "head", origin: [-5, -3, -6] };
const TORSO = { x0: 1, x1: 8, y0: 1, y1: 9, z0: 1, z1: 6, part: "torso", origin: [-5, 2, -4] };

// Arms: each arm occupies x 1..4, y 1..11, z 1..4 of its frame (arm-local voxels
// x 0..4 / -4..0, y -10..1, z -2..2). The outer side is +X for the left arm.
const ARM_L = { x0: 1, x1: 4, y0: 1, y1: 11, z0: 1, z1: 4, part: "arm-left", origin: [-1, -11, -3] };
const ARM_R = { x0: 1, x1: 4, y0: 1, y1: 11, z0: 1, z1: 4, part: "arm-right", origin: [-5, -11, -3] };

// Rounded steel shoulder plate with a trim row; `outer` is +1 (left arm) or -1.
function pauldron(f, s, outer) {
  const out = outer > 0 ? f.x1 + 1 : f.x0 - 1;
  const inner = outer > 0 ? f.x0 : f.x1;
  const xa = Math.min(inner, out), xb = Math.max(inner, out);
  s.box(xa, f.y1 - 2, f.z0 - 1, xb, f.y1, f.z1 + 1, P); // shell
  s.box(f.x0, f.y1 + 1, f.z0, f.x1, f.y1 + 1, f.z1, P); // top dome
  s.box(out + outer, f.y1 - 3, f.z0 - 1, out + outer, f.y1, f.z1 + 1, P); // outer flap
  s.box(xa, f.y1 - 3, f.z0 - 1, xb, f.y1 - 3, f.z1 + 1, S); // trim
  s.box(out + outer, f.y1 - 4, f.z0 - 1, out + outer, f.y1 - 4, f.z1 + 1, S);
}

const PIECES = {
  pauldron_left: { frame: ARM_L, tag: "armor", hides: [], build: (f, s) => pauldron(f, s, 1) },
  pauldron_right: { frame: ARM_R, tag: "armor", hides: [], build: (f, s) => pauldron(f, s, -1) },
  // Long hair: a curtain down the back to the shoulders, side locks, volume on top.
  hair_long: {
    frame: HEAD, tag: "hair", hides: [],
    build(f, s) {
      s.box(f.x0 - 1, 0, f.z0 - 2, f.x1 + 1, f.y1 + 1, f.z0 - 1, H);
      s.box(f.x0 - 1, 1, f.z0, f.x0 - 1, f.y1 + 1, f.z0 + 4, H);
      s.box(f.x1 + 1, 1, f.z0, f.x1 + 1, f.y1 + 1, f.z0 + 4, H);
      s.box(f.x0 - 1, f.y1 + 1, f.z0, f.x1 + 1, f.y1 + 1, f.z1 - 1, H);
      s.remove(f.x0 - 1, 0, f.z0 - 2, f.x0 - 1, 0, f.z0 - 1);
      s.remove(f.x1 + 1, 0, f.z0 - 2, f.x1 + 1, 0, f.z0 - 1);
    },
  },
  // Ponytail tied high at the back, hanging to the shoulders.
  hair_ponytail: {
    frame: HEAD, tag: "hair", hides: [],
    build(f, s) {
      s.box(f.x0 + 3, f.y1 - 2, f.z0 - 1, f.x1 - 3, f.y1, f.z0 - 1, H); // knot
      s.box(f.x0 + 3, f.y0 - 2, f.z0 - 2, f.x1 - 3, f.y1 - 1, f.z0 - 2, H); // tail
      s.box(f.x0 + 3, f.y0 - 3, f.z0 - 2, f.x1 - 4, f.y0 - 3, f.z0 - 2, H); // tip
    },
  },
  // Round bun on the top-back of the head.
  hair_bun: {
    frame: HEAD, tag: "hair", hides: [],
    build(f, s) {
      s.box(f.x0 + 2, f.y1 + 1, f.z0 + 1, f.x1 - 2, f.y1 + 3, f.z0 + 4, H);
      s.remove(f.x0 + 2, f.y1 + 3, f.z0 + 1, f.x0 + 2, f.y1 + 3, f.z0 + 4);
      s.remove(f.x1 - 2, f.y1 + 3, f.z0 + 1, f.x1 - 2, f.y1 + 3, f.z0 + 4);
    },
  },
  // Crest along the middle of the head, tallest in the middle.
  hair_mohawk: {
    frame: HEAD, tag: "hair", hides: [],
    build(f, s) {
      s.box(f.x0 + 3, f.y1 + 1, f.z0, f.x1 - 3, f.y1 + 1, f.z1, H);
      s.box(f.x0 + 3, f.y1 + 2, f.z0 + 1, f.x1 - 3, f.y1 + 2, f.z1 - 1, H);
      s.box(f.x0 + 3, f.y1 + 3, f.z0 + 3, f.x1 - 3, f.y1 + 3, f.z1 - 2, H);
      s.box(f.x0 + 3, f.y0 + 2, f.z0 - 1, f.x1 - 3, f.y1, f.z0 - 1, H); // down the back
    },
  },
  // Wide-brimmed pointed hat with a band in the secondary color.
  hat_mage: {
    frame: HEAD, tag: "headgear", hides: ["hair"],
    build(f, s) {
      const y = f.y1 + 1;
      s.box(f.x0 - 3, y, f.z0 - 3, f.x1 + 3, y, f.z1 + 3, P);
      for (const [x, z] of [[f.x0 - 3, f.z0 - 3], [f.x1 + 3, f.z0 - 3], [f.x0 - 3, f.z1 + 3], [f.x1 + 3, f.z1 + 3]]) s.remove(x, y, z, x, y, z);
      s.box(f.x0, y + 1, f.z0, f.x1, y + 1, f.z1, S);
      s.box(f.x0, y + 2, f.z0, f.x1, y + 3, f.z1, P);
      s.box(f.x0 + 1, y + 4, f.z0 + 1, f.x1 - 1, y + 5, f.z1 - 1, P);
      s.box(f.x0 + 2, y + 6, f.z0 + 2, f.x1 - 2, y + 7, f.z1 - 2, P);
      s.box(f.x0 + 3, y + 8, f.z0 + 2, f.x1 - 3, y + 9, f.z1 - 4, P);
      s.box(f.x0 + 3, y + 10, f.z0 + 1, f.x1 - 3, y + 10, f.z0 + 2, P);
    },
  },
  // Archer's hood: a shell over the top, back and sides, open face, short cape.
  hood_archer: {
    frame: HEAD, tag: "headgear", hides: ["hair"],
    build(f, s) {
      s.box(f.x0 - 1, f.y1 + 1, f.z0 - 1, f.x1 + 1, f.y1 + 1, f.z1, P); // top
      s.box(f.x0 - 1, f.y0, f.z0 - 1, f.x1 + 1, f.y1 + 1, f.z0 - 1, P); // back
      s.box(f.x0 - 1, f.y0, f.z0, f.x0 - 1, f.y1 + 1, f.z1, P); // left
      s.box(f.x1 + 1, f.y0, f.z0, f.x1 + 1, f.y1 + 1, f.z1, P); // right
      s.box(f.x0 - 1, f.y1 + 1, f.z1 + 1, f.x1 + 1, f.y1 + 1, f.z1 + 1, P); // brim
      s.box(f.x0 - 1, f.y0 - 1, f.z0 - 2, f.x1 + 1, f.y0 + 1, f.z1 - 2, S); // cape collar
      s.remove(f.x0, f.y0 - 1, f.z0, f.x1, f.y0 + 1, f.z1 - 2); // neck hole
      s.box(f.x0 + 3, f.y1 - 1, f.z0 - 2, f.x1 - 3, f.y1 + 2, f.z0 - 2, P); // point
    },
  },
  // Assassin's scarf covering mouth and nose, knotted at the back.
  mask_assassin: {
    frame: HEAD, tag: "headgear", hides: [],
    build(f, s) {
      s.box(f.x0, f.y0, f.z1 + 1, f.x1, f.y0 + 3, f.z1 + 1, P); // front
      s.box(f.x0 - 1, f.y0, f.z0, f.x0 - 1, f.y0 + 3, f.z1 + 1, P); // left
      s.box(f.x1 + 1, f.y0, f.z0, f.x1 + 1, f.y0 + 3, f.z1 + 1, P); // right
      s.box(f.x0 - 1, f.y0, f.z0 - 1, f.x1 + 1, f.y0 + 3, f.z0 - 1, P); // back
      s.box(f.x0 + 3, f.y0 - 3, f.z0 - 2, f.x1 - 4, f.y0 + 1, f.z0 - 2, S); // knot tails
    },
  },
  // Cleric's lowered hood resting on the shoulders behind the neck.
  hood_cleric: {
    frame: TORSO, tag: "headgear", hides: [],
    build(f, s) {
      s.box(f.x0 + 1, f.y1, f.z0 - 1, f.x1 - 1, f.y1 + 1, f.z0 + 1, P);
      s.box(f.x0 + 2, f.y1 - 3, f.z0 - 1, f.x1 - 2, f.y1 - 1, f.z0 - 1, P); // drape
      s.box(f.x0 + 1, f.y1 + 1, f.z0 + 1, f.x1 - 1, f.y1 + 1, f.z0 + 1, S); // lining edge
    },
  },
};

// --- Monster pieces (data/monsters "look") ----------------------------------------
// Goblin ears use TINT_HAIR (the look gives them the skin color); weapons use the
// look's primary (wood, grip) and secondary (blade, string).
Object.assign(PIECES, {
  // Long pointed ears sticking out sideways and a bit up.
  goblin_ears: {
    frame: HEAD, tag: "monster", hides: [],
    build(f, s) {
      for (const side of [-1, 1]) {
        const x0 = side < 0 ? f.x0 - 1 : f.x1 + 1;
        const at = (dx) => x0 + side * dx;
        s.box(Math.min(at(0), at(1)), 5, 4, Math.max(at(0), at(1)), 8, 6, H);
        s.box(Math.min(at(2), at(3)), 6, 4, Math.max(at(2), at(3)), 8, 5, H);
        s.put(at(4), 8, 4, H).put(at(4), 9, 4, H).put(at(5), 9, 3, H);
      }
    },
  },
  // A short jagged knife held in the right fist, blade forward.
  goblin_knife: {
    frame: ARM_R, tag: "monster", hides: [],
    build(f, s) {
      s.box(2, 1, 5, 3, 2, 6, P); // grip sticking out of the fist
      s.box(1, 1, 7, 4, 2, 7, P); // crude guard
      s.box(2, 1, 8, 3, 2, 12, S); // blade
      s.put(2, 1, 13, S).put(3, 2, 10, P); // tip and a notch
      s.remove(3, 2, 10, 3, 2, 10);
    },
  },
  // A tall recurve bow held upright in the left fist, string toward the body.
  skeleton_bow: {
    frame: ARM_L, tag: "monster", hides: [],
    build(f, s) {
      s.box(2, -1, 6, 3, 3, 6, P); // grip
      s.box(2, 4, 5, 3, 8, 5, P).box(2, 9, 4, 3, 10, 4, P).put(2, 11, 5, P).put(3, 11, 5, P); // upper limb
      s.box(2, -5, 5, 3, -2, 5, P).box(2, -7, 4, 3, -6, 4, P).put(2, -8, 5, P).put(3, -8, 5, P); // lower limb
      s.box(2, -7, 3, 2, 10, 3, S); // string
    },
  },
});


// Orc king (boss): fixed colors for bone, gem, wood and the bright axe edge.
const BONE = 22, GEM = 23, WOOD = 24, EDGE = 25;
const ORC_PALETTE = { [BONE]: "#e6dfcc", [GEM]: "#c0281c", [WOOD]: "#4a3020", [EDGE]: "#d5dae0" };
Object.assign(PIECES, {
  // Lower tusks jutting up in front of the mouth.
  orc_tusks: {
    frame: HEAD, tag: "monster", hides: [], palette: ORC_PALETTE,
    build(f, s) {
      for (const x of [f.x0 + 1, f.x1 - 1]) s.box(x, f.y0 + 1, f.z1 + 1, x, f.y0 + 2, f.z1 + 1, BONE);
    },
  },
  // Heavy spiked gold crown with a red gem at the front.
  orc_crown: {
    frame: HEAD, tag: "monster", hides: [], palette: ORC_PALETTE,
    build(f, s) {
      s.box(f.x0, f.y1 + 1, f.z0, f.x1, f.y1 + 2, f.z1, S);
      s.remove(f.x0 + 1, f.y1 + 1, f.z0 + 1, f.x1 - 1, f.y1 + 2, f.z1 - 1);
      for (const [x, z] of [[f.x0, f.z0], [f.x1, f.z0], [f.x0, f.z1], [f.x1, f.z1], [f.x0 + 3, f.z1], [f.x1 - 3, f.z1], [f.x0 + 3, f.z0], [f.x1 - 3, f.z0]]) {
        s.box(x, f.y1 + 3, z, x, f.y1 + 4, z, S);
      }
      s.box(f.x0 + 3, f.y1 + 3, f.z1, f.x1 - 3, f.y1 + 5, f.z1, S).box(f.x0 + 3, f.y1 + 1, f.z1 + 1, f.x1 - 3, f.y1 + 2, f.z1 + 1, GEM);
    },
  },
  // A huge two-bladed war axe held in the right fist, pointing forward.
  orc_axe: {
    frame: ARM_R, tag: "monster", hides: [], palette: ORC_PALETTE,
    build(f, s) {
      s.box(2, 1, 5, 3, 2, 19, WOOD); // haft
      s.box(2, 1, 4, 3, 2, 4, S).box(2, 1, 20, 3, 2, 20, S); // pommel and cap
      for (const side of [1, -1]) {
        // Crescent blades above and below the haft near its end.
        const y0 = side > 0 ? 3 : 0;
        for (let k = 0; k < 6; k++) {
          const y = side > 0 ? y0 + k : y0 - k;
          const half = k < 2 ? 2 : k < 4 ? 3 : 4;
          s.box(2, y, 17 - half, 3, y, 17 + half - 1, k === 5 ? EDGE : P);
        }
      }
    },
  },
});
const [outDir, jsonPath] = process.argv.slice(2);
if (!outDir || !jsonPath) {
  console.error("usage: node make_pieces.mjs <pieces out dir> <pieces.json path>");
  process.exit(1);
}
const table = {};
for (const [name, def] of Object.entries(PIECES)) {
  const shape = new Shape();
  def.build(def.frame, shape);
  write(`${outDir}/${name}.vox`, shape.size(), shape.voxels(), def.palette ?? {});
  const m = shape.min();
  table[name] = {
    file: `res://assets/characters/pieces/${name}.vox`,
    part: def.frame.part,
    offset: def.frame.origin.map((o, i) => o + m[i]),
    tag: def.tag,
    hides: def.hides,
  };
  console.log(`wrote piece ${name} ${shape.size().join("x")} (${shape.voxels().length} voxels)`);
}
fs.writeFileSync(jsonPath, JSON.stringify(table, null, "\t") + "\n");
console.log("wrote", jsonPath);
