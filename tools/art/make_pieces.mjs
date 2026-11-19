// Generates the voxel pieces (.vox) of the characters and data/characters/pieces.json.
//   node tools/art/make_pieces.mjs <pieces out dir> <pieces.json path>
// Coordinates are Godot axes, in (fine) voxels; the character faces +Z. Each piece is
// drawn in its part's frame, where the part occupies x0..x1, y0..y1, z0..z1 (HumanRig,
// see make_humans.mjs); `origin` turns frame voxels into voxels from the part's pivot.
// Tinted pieces use the tint's shade and light tones for folds and highlights.
import fs from "node:fs";
import { write, Shape, SHADE, LIGHT, TINT_HAIR, TINT_PRIMARY, TINT_SECONDARY, GLOW } from "./vox.mjs";

const H = TINT_HAIR, P = TINT_PRIMARY, S = TINT_SECONDARY;
// Head x -4..3, y 0..9, z -5..3 from its pivot; the face is on z1 (eyes y1 - 4).
const HEAD = { x0: 1, x1: 8, y0: 1, y1: 10, z0: 1, z1: 9, part: "head", origin: [-5, -1, -6] };
// Chest x -6..5, y 0..11 (waist below y 4 is narrower, front z 2), z -4..3.
const TORSO = { x0: 1, x1: 12, y0: 1, y1: 12, z0: 1, z1: 8, part: "torso", origin: [-7, -1, -5] };
// Upper arms x -2..1, y -9..0, z -2..1. The outer side is +X for the left arm.
const ARM_L = { x0: 1, x1: 4, y0: 1, y1: 10, z0: 1, z1: 4, part: "arm_left", origin: [-3, -10, -3] };
const ARM_R = { ...ARM_L, part: "arm_right" };
// Fists x -2..1, y -4..0, z -2..1; grips run through the middle (x 2..3, y 2..3).
const HAND_L = { x0: 1, x1: 4, y0: 1, y1: 5, z0: 1, z1: 4, part: "hand_left", origin: [-3, -5, -3] };
const HAND_R = { ...HAND_L, part: "hand_right" };

// The two middle columns of a frame.
const mid = (f) => [f.x0 + Math.floor((f.x1 - f.x0) / 2), f.x0 + Math.floor((f.x1 - f.x0) / 2) + 1];

// Fixed colors of weapons and outfits, each with a shade and a light tone.
const STEEL = 40, STEEL_D = 41, STEEL_L = 42, WOOD = 43, WOOD_D = 44, GOLD = 45,
  LEATHER = 47, LEATHER_D = 48, STRING = 49, CLOTH = 50, CHAIN = 51, CHAIN_D = 52, GEM = 53;
const KIT = {
  [STEEL]: "#b9c1ca", [STEEL_D]: "#7c8590", [STEEL_L]: "#e6ebf0", [WOOD]: "#6e4b2c", [WOOD_D]: "#4a311d",
  [GOLD]: "#d6ae4c", [LEATHER]: "#5c3e25", [LEATHER_D]: "#3d2918", [STRING]: "#e6dfcc",
  [CLOTH]: "#ece3cf", [CHAIN]: "#8f98a2", [CHAIN_D]: "#5f6770", [GEM]: "#c0281c", [GLOW]: "#9fe0ff",
};

// --- Hair and beards ---------------------------------------------------------------
// Caps are tagged hair_cap (only hoods hide them); long extras are tagged hair.
function cap(f, s) {
  s.box(f.x0, f.y1 + 1, f.z0, f.x1, f.y1 + 1, f.z1, H); // crown
  for (const [x, z] of [[f.x0, f.z0], [f.x1, f.z0], [f.x0, f.z1], [f.x1, f.z1]]) s.remove(x, f.y1 + 1, z, x, f.y1 + 1, z);
  s.box(f.x0, f.y0 + 4, f.z0 - 1, f.x1, f.y1, f.z0 - 1, H); // back, down to the nape
  s.box(f.x0 - 1, f.y1 - 3, f.z0, f.x0 - 1, f.y1, f.z1 - 3, H); // temples, above the ears
  s.box(f.x1 + 1, f.y1 - 3, f.z0, f.x1 + 1, f.y1, f.z1 - 3, H);
  s.box(f.x0, f.y0 + 4, f.z0 - 1, f.x1, f.y0 + 4, f.z0 - 1, SHADE(H)); // nape in shade
  for (let i = 0; i < 4; i++) s.put(f.x0 + 1 + i * 2, f.y1 + 1, f.z0 + 2 + i, LIGHT(H)); // shine
}

const HAIR = {
  // Short with a side-swept fringe.
  hair_short: {
    tag: "hair_cap",
    build(f, s) {
      cap(f, s);
      s.box(f.x0, f.y1, f.z1 + 1, f.x0 + 4, f.y1, f.z1 + 1, H);
      s.box(f.x0, f.y1 - 1, f.z1 + 1, f.x0 + 1, f.y1 - 1, f.z1 + 1, SHADE(H));
    },
  },
  // Bob: straight down the sides and back to the jaw, a full fringe.
  hair_bob: {
    tag: "hair_cap",
    build(f, s) {
      cap(f, s);
      s.box(f.x0, f.y0 + 1, f.z0 - 1, f.x1, f.y1, f.z0 - 1, H);
      s.box(f.x0 - 1, f.y0 + 1, f.z0, f.x0 - 1, f.y1, f.z1 - 1, H);
      s.box(f.x1 + 1, f.y0 + 1, f.z0, f.x1 + 1, f.y1, f.z1 - 1, H);
      s.box(f.x0 - 1, f.y0 + 1, f.z0, f.x0 - 1, f.y0 + 1, f.z1 - 1, SHADE(H)).box(f.x1 + 1, f.y0 + 1, f.z0, f.x1 + 1, f.y0 + 1, f.z1 - 1, SHADE(H));
      s.box(f.x0, f.y1, f.z1 + 1, f.x1, f.y1, f.z1 + 1, H);
      s.box(f.x0, f.y1 - 1, f.z1 + 1, f.x1, f.y1 - 1, f.z1 + 1, SHADE(H));
    },
  },
  // Swept back: a quiff at the front, combed backwards.
  hair_swept: {
    tag: "hair_cap",
    build(f, s) {
      cap(f, s);
      s.box(f.x0, f.y1 + 2, f.z1 - 4, f.x1, f.y1 + 2, f.z1, H);
      s.box(f.x0 + 1, f.y1 + 2, f.z0 + 1, f.x1 - 1, f.y1 + 2, f.z1 - 5, SHADE(H));
      s.box(f.x0, f.y1, f.z1 + 1, f.x1, f.y1 + 1, f.z1 + 1, H);
      s.box(f.x0 + 1, f.y1 + 2, f.z1, f.x1 - 1, f.y1 + 2, f.z1, LIGHT(H));
    },
  },
  // Long hair: a curtain down the back to the shoulder blades.
  hair_long: {
    tag: "hair",
    build(f, s) {
      s.box(f.x0 - 1, f.y0 - 9, f.z0 - 2, f.x1 + 1, f.y1, f.z0 - 2, H);
      s.box(f.x0 - 1, f.y0 - 6, f.z0 - 1, f.x0 - 1, f.y0, f.z0 + 2, H).box(f.x1 + 1, f.y0 - 6, f.z0 - 1, f.x1 + 1, f.y0, f.z0 + 2, H);
      for (let x = f.x0; x <= f.x1; x += 2) s.box(x, f.y0 - 9, f.z0 - 2, x, f.y1 - 2, f.z0 - 2, SHADE(H)); // strands
      s.box(f.x0, f.y0 - 10, f.z0 - 2, f.x1, f.y0 - 10, f.z0 - 2, H);
      for (let x = f.x0; x <= f.x1; x += 3) s.remove(x, f.y0 - 10, f.z0 - 2, x, f.y0 - 10, f.z0 - 2);
    },
  },
  // Ponytail tied high at the back, hanging to the shoulders.
  hair_ponytail: {
    tag: "hair",
    build(f, s) {
      const [a, b] = mid(f);
      s.box(a - 1, f.y1 - 2, f.z0 - 2, b + 1, f.y1, f.z0 - 2, H); // knot
      s.box(a, f.y1 - 2, f.z0 - 3, b, f.y1 - 1, f.z0 - 3, SHADE(H)); // tie
      s.box(a, f.y0 - 6, f.z0 - 3, b, f.y1 - 3, f.z0 - 3, H); // tail
      s.box(a, f.y0 - 6, f.z0 - 3, a, f.y1 - 3, f.z0 - 3, SHADE(H));
      s.put(a, f.y0 - 7, f.z0 - 3, H);
    },
  },
  // Round bun at the back of the head.
  hair_bun: {
    tag: "hair",
    build(f, s) {
      const [a, b] = mid(f);
      s.box(a - 1, f.y1 - 3, f.z0 - 4, b + 1, f.y1, f.z0 - 1, H);
      s.remove(a - 1, f.y1, f.z0 - 4, a - 1, f.y1, f.z0 - 4).remove(b + 1, f.y1, f.z0 - 4, b + 1, f.y1, f.z0 - 4);
      s.remove(a - 1, f.y1 - 3, f.z0 - 4, a - 1, f.y1 - 3, f.z0 - 4).remove(b + 1, f.y1 - 3, f.z0 - 4, b + 1, f.y1 - 3, f.z0 - 4);
      s.box(a - 1, f.y1 - 3, f.z0 - 4, b + 1, f.y1 - 3, f.z0 - 2, SHADE(H));
      s.put(a, f.y1, f.z0 - 3, LIGHT(H));
    },
  },
  // A crest along a shaved head, tallest over the crown, down the back.
  hair_mohawk: {
    tag: "hair_cap",
    build(f, s) {
      const [a, b] = mid(f);
      const heights = [1, 2, 3, 4, 4, 4, 3, 2, 2];
      for (let i = 0; i < heights.length; i++) {
        const z = f.z1 - i;
        s.box(a, f.y1 + 1, z, b, f.y1 + heights[i], z, H);
        s.box(a, f.y1 + 1, z, a, f.y1 + heights[i], z, SHADE(H));
      }
      s.box(a, f.y0 + 3, f.z0 - 1, b, f.y1, f.z0 - 1, H);
    },
  },
};

// Beards sit in front of the jaw (lips on y0 + 1, nose y0 + 2..y0 + 4).
const BEARDS = {
  beard_mustache(f, s) {
    s.box(f.x0 + 1, f.y0 + 2, f.z1 + 1, f.x1 - 1, f.y0 + 2, f.z1 + 1, H);
    s.box(f.x0 + 1, f.y0, f.z1 + 1, f.x0 + 1, f.y0 + 1, f.z1 + 1, H).box(f.x1 - 1, f.y0, f.z1 + 1, f.x1 - 1, f.y0 + 1, f.z1 + 1, H);
    const [a, b] = mid(f);
    s.box(a, f.y0 + 2, f.z1 + 1, b, f.y0 + 2, f.z1 + 1, SHADE(H));
  },
  beard_goatee(f, s) {
    const [a, b] = mid(f);
    s.box(a - 1, f.y0 - 3, f.z1 - 1, b + 1, f.y0, f.z1 + 1, H);
    s.box(a - 1, f.y0 - 3, f.z1 - 1, b + 1, f.y0 - 3, f.z1 + 1, SHADE(H));
    s.box(a, f.y0 - 4, f.z1, b, f.y0 - 4, f.z1 + 1, H);
    s.box(f.x0 + 2, f.y0 + 2, f.z1 + 1, f.x1 - 2, f.y0 + 2, f.z1 + 1, H);
  },
  beard_short(f, s) {
    s.box(f.x0, f.y0 - 1, f.z0 + 3, f.x1, f.y0 - 1, f.z1 + 1, H); // under the jaw
    s.box(f.x0 - 1, f.y0, f.z0 + 3, f.x0 - 1, f.y0 + 5, f.z1 - 1, H); // sideburns
    s.box(f.x1 + 1, f.y0, f.z0 + 3, f.x1 + 1, f.y0 + 5, f.z1 - 1, H);
    s.box(f.x0, f.y0, f.z1 + 1, f.x0 + 1, f.y0 + 2, f.z1 + 1, H).box(f.x1 - 1, f.y0, f.z1 + 1, f.x1, f.y0 + 2, f.z1 + 1, H);
    s.box(f.x0, f.y0, f.z1 + 1, f.x1, f.y0, f.z1 + 1, H); // chin strap
    s.box(f.x0, f.y0 - 1, f.z0 + 3, f.x1, f.y0 - 1, f.z0 + 5, SHADE(H));
  },
  beard_full(f, s) {
    BEARDS.beard_short(f, s);
    BEARDS.beard_mustache(f, s);
    s.box(f.x0, f.y0 - 4, f.z1 - 2, f.x1, f.y0 - 1, f.z1 + 1, H); // the mass under the chin
    s.remove(f.x0, f.y0 - 4, f.z1 - 2, f.x0, f.y0 - 4, f.z1 + 1).remove(f.x1, f.y0 - 4, f.z1 - 2, f.x1, f.y0 - 4, f.z1 + 1);
    s.box(f.x0 + 1, f.y0 - 4, f.z1 - 2, f.x1 - 1, f.y0 - 4, f.z1 + 1, SHADE(H));
    for (let x = f.x0 + 1; x <= f.x1 - 1; x += 2) s.put(x, f.y0 - 2, f.z1 + 1, SHADE(H)); // texture
  },
};

// --- Class gear ----------------------------------------------------------------------

// Steel shoulder plate with lames down the outside, a trim row and rivets; `outer` is
// +1 (left arm) or -1.
function pauldron(f, s, outer) {
  const out = outer > 0 ? f.x1 + 1 : f.x0 - 1;
  const inner = outer > 0 ? f.x0 - 1 : f.x1 + 1;
  const xa = Math.min(inner, out), xb = Math.max(inner, out);
  s.box(xa, f.y1 - 1, f.z0 - 1, xb, f.y1 + 1, f.z1 + 1, P); // dome
  s.box(xa, f.y1 + 1, f.z0 - 1, xb, f.y1 + 1, f.z1 + 1, LIGHT(P));
  s.box(out, f.y1 - 4, f.z0 - 1, out, f.y1 - 2, f.z1 + 1, P); // lames
  s.box(out, f.y1 - 2, f.z0 - 1, out, f.y1 - 2, f.z1 + 1, SHADE(P));
  s.box(out, f.y1 - 5, f.z0 - 1, out, f.y1 - 5, f.z1 + 1, S); // trim
  s.put(out, f.y1 - 3, f.z0, GOLD).put(out, f.y1 - 3, f.z1, GOLD); // rivets
}

const GEAR = {
  quiver_back: {
    frame: TORSO, tag: "gear", palette: KIT,
    build(f, s) {
      for (let i = 0; i <= f.y1 - f.y0 - 3; i++) s.put(f.x0 + 1 + i, f.y1 - 1 - i, f.z1 + 2, WOOD_D); // strap
      s.box(f.x1 - 4, f.y0 + 2, f.z0 - 3, f.x1 - 1, f.y1 + 2, f.z0 - 1, LEATHER); // quiver
      s.box(f.x1 - 4, f.y0 + 2, f.z0 - 3, f.x1 - 4, f.y1 + 2, f.z0 - 1, LEATHER_D);
      for (const x of [f.x1 - 4, f.x1 - 2]) s.box(x, f.y1 + 3, f.z0 - 2, x + 1, f.y1 + 5, f.z0 - 2, STRING); // fletching
    },
  },
  pauldron_left: { frame: ARM_L, tag: "armor", palette: KIT, build: (f, s) => pauldron(f, s, 1) },
  pauldron_right: { frame: ARM_R, tag: "armor", palette: KIT, build: (f, s) => pauldron(f, s, -1) },
  // Wide-brimmed pointed hat with a band, bending at the tip; sits on the hair cap.
  hat_mage: {
    frame: HEAD, tag: "headgear", hides: ["hair"], palette: KIT,
    build(f, s) {
      const y = f.y1 + 2;
      s.box(f.x0 - 4, y, f.z0 - 4, f.x1 + 4, y, f.z1 + 4, P);
      for (const [x, z] of [[f.x0 - 4, f.z0 - 4], [f.x1 + 4, f.z0 - 4], [f.x0 - 4, f.z1 + 4], [f.x1 + 4, f.z1 + 4]]) s.remove(x, y, z, x, y, z);
      s.box(f.x0 - 3, y, f.z0 - 4, f.x1 + 3, y, f.z0 - 4, SHADE(P)); // brim edge
      s.box(f.x0, y + 1, f.z0, f.x1, y + 2, f.z1, S); // band
      s.put(f.x0 + 3, y + 1, f.z1 + 1, GOLD).put(f.x0 + 4, y + 2, f.z1 + 1, GOLD); // buckle
      let lo = 0;
      for (let k = 0; k < 4; k++) {
        const yy = y + 3 + k * 2;
        s.box(f.x0 + lo, yy, f.z0 + lo, f.x1 - lo, yy + 1, f.z1 - lo, P);
        s.box(f.x0 + lo, yy, f.z0 + lo, f.x0 + lo, yy + 1, f.z1 - lo, SHADE(P));
        lo = Math.min(lo + 1, 3);
      }
      const [a, b] = mid(f);
      s.box(a, y + 11, f.z0 + 3, b, y + 12, f.z0 + 4, P).box(a, y + 12, f.z0 + 1, b, y + 13, f.z0 + 2, P).put(a, y + 13, f.z0, P); // bent tip
    },
  },
  // Archer's hood: over the top, back and sides, open at the face, a short cape.
  hood_archer: {
    frame: HEAD, tag: "headgear", hides: ["hair", "hair_cap"], palette: KIT,
    build(f, s) {
      s.box(f.x0 - 1, f.y1 + 1, f.z0 - 1, f.x1 + 1, f.y1 + 1, f.z1 + 1, P); // top and brim
      s.box(f.x0 - 1, f.y0 + 1, f.z0 - 1, f.x1 + 1, f.y1 + 1, f.z0 - 1, P); // back
      s.box(f.x0 - 1, f.y0 + 1, f.z0, f.x0 - 1, f.y1 + 1, f.z1, P); // sides
      s.box(f.x1 + 1, f.y0 + 1, f.z0, f.x1 + 1, f.y1 + 1, f.z1, P);
      s.box(f.x0 - 1, f.y0 + 1, f.z1, f.x0 - 1, f.y1, f.z1, SHADE(P)).box(f.x1 + 1, f.y0 + 1, f.z1, f.x1 + 1, f.y1, f.z1, SHADE(P));
      s.box(f.x0 - 1, f.y1 + 1, f.z1 + 1, f.x1 + 1, f.y1 + 1, f.z1 + 1, SHADE(P));
      s.box(f.x0 - 2, f.y0 - 1, f.z0 - 2, f.x1 + 2, f.y0, f.z1 - 1, P); // cape collar
      s.remove(f.x0, f.y0 - 1, f.z0, f.x1, f.y0, f.z1 - 1);
      s.box(f.x0 - 2, f.y0 - 1, f.z0 - 2, f.x1 + 2, f.y0 - 1, f.z0 - 2, SHADE(P));
      const [a, b] = mid(f);
      s.box(a, f.y1 - 2, f.z0 - 3, b, f.y1 + 2, f.z0 - 2, P); // point
    },
  },
  // Templar's steel helm: dome, brow band, cheek guards and a nasal bar; the face stays
  // open and a gold crest runs over the top.
  helm_templar: {
    frame: HEAD, tag: "headgear", hides: ["hair", "hair_cap"], palette: KIT,
    build(f, s) {
      s.box(f.x0 - 1, f.y1 + 1, f.z0 - 1, f.x1 + 1, f.y1 + 1, f.z1 + 1, STEEL_L); // dome top
      s.box(f.x0 - 1, f.y0 + 1, f.z0 - 1, f.x1 + 1, f.y1, f.z0 - 1, STEEL_D); // back
      s.box(f.x0 - 1, f.y0 + 1, f.z0, f.x0 - 1, f.y1, f.z1 + 1, STEEL); // sides
      s.box(f.x1 + 1, f.y0 + 1, f.z0, f.x1 + 1, f.y1, f.z1 + 1, STEEL);
      s.box(f.x0 - 1, f.y1 - 1, f.z1 + 1, f.x1 + 1, f.y1, f.z1 + 1, STEEL); // brow band
      const [a, b] = mid(f);
      s.box(a, f.y1 - 5, f.z1 + 1, b, f.y1 - 2, f.z1 + 1, STEEL_L); // nasal bar
      s.box(f.x0 - 1, f.y0 + 1, f.z1, f.x0 - 1, f.y0 + 3, f.z1 + 1, STEEL_D).box(f.x1 + 1, f.y0 + 1, f.z1, f.x1 + 1, f.y0 + 3, f.z1 + 1, STEEL_D); // cheek guards
      s.box(a, f.y1 + 2, f.z0, b, f.y1 + 3, f.z1, GOLD); // crest
    },
  },
  // Assassin's scarf over the nose and mouth, knotted at the back.
  mask_assassin: {
    frame: HEAD, tag: "headgear", palette: KIT,
    build(f, s) {
      s.box(f.x0, f.y0, f.z1 + 1, f.x1, f.y0 + 4, f.z1 + 2, P); // front (over the nose)
      s.box(f.x0 - 1, f.y0, f.z0, f.x0 - 1, f.y0 + 4, f.z1 + 1, P).box(f.x1 + 1, f.y0, f.z0, f.x1 + 1, f.y0 + 4, f.z1 + 1, P);
      s.box(f.x0 - 1, f.y0, f.z0 - 1, f.x1 + 1, f.y0 + 4, f.z0 - 1, P);
      s.box(f.x0, f.y0 + 4, f.z1 + 2, f.x1, f.y0 + 4, f.z1 + 2, LIGHT(P)); // top fold
      s.box(f.x0, f.y0 + 1, f.z1 + 2, f.x1, f.y0 + 1, f.z1 + 2, SHADE(P));
      const [a, b] = mid(f);
      s.box(a - 1, f.y0 - 5, f.z0 - 2, a - 1, f.y0 + 1, f.z0 - 2, S).box(b + 1, f.y0 - 4, f.z0 - 2, b + 1, f.y0 + 1, f.z0 - 2, S); // tails
    },
  },
  // Cleric's lowered hood resting on the shoulders behind the neck.
  hood_cleric: {
    frame: TORSO, tag: "headgear", palette: KIT,
    build(f, s) {
      s.box(f.x0 + 2, f.y1 - 1, f.z0 - 2, f.x1 - 2, f.y1 + 2, f.z0 + 1, P);
      s.remove(f.x0 + 4, f.y1, f.z0 + 1, f.x1 - 4, f.y1 + 2, f.z0 + 1);
      s.box(f.x0 + 3, f.y1 - 5, f.z0 - 2, f.x1 - 3, f.y1 - 2, f.z0 - 2, P); // drape
      s.box(f.x0 + 3, f.y1 - 5, f.z0 - 2, f.x1 - 3, f.y1 - 5, f.z0 - 2, SHADE(P));
      s.box(f.x0 + 2, f.y1 + 2, f.z0 - 2, f.x1 - 2, f.y1 + 2, f.z0 - 2, S); // lining edge
    },
  },
  // Outfits: details over the shirt (the chest's front is z1 + 1, the waist's z1 - 4).
  outfit_warrior: {
    frame: TORSO, tag: "outfit", palette: KIT,
    build(f, s) {
      s.box(f.x0, f.y0 + 4, f.z1 + 1, f.x1, f.y1 - 1, f.z1 + 1, STEEL); // breastplate
      s.box(f.x0, f.y0 + 4, f.z1 + 1, f.x0, f.y1 - 1, f.z1 + 1, STEEL_D).box(f.x1, f.y0 + 4, f.z1 + 1, f.x1, f.y1 - 1, f.z1 + 1, STEEL_D);
      s.box(f.x0, f.y0 + 4, f.z1 + 1, f.x1, f.y0 + 4, f.z1 + 1, STEEL_D);
      const [a, b] = mid(f);
      s.box(a, f.y0 + 5, f.z1 + 2, b, f.y1 - 2, f.z1 + 2, STEEL_L); // ridge
      s.box(f.x0 + 1, f.y1 - 2, f.z1 + 1, f.x1 - 1, f.y1 - 2, f.z1 + 1, STEEL_L); // light along the top
      s.box(f.x0 + 1, f.y0, f.z1 - 4, f.x1 - 1, f.y0 + 3, f.z1 - 4, CHAIN); // mail over the waist
      for (let x = f.x0 + 1; x <= f.x1 - 1; x += 2) s.box(x, f.y0, f.z1 - 4, x, f.y0 + 3, f.z1 - 4, CHAIN_D);
      s.box(f.x0, f.y0 + 4, f.z0 - 1, f.x1, f.y1 - 1, f.z0 - 1, STEEL_D); // back plate
    },
  },
  outfit_cleric: {
    frame: TORSO, tag: "outfit", palette: KIT,
    build(f, s) {
      const [a, b] = mid(f);
      s.box(a - 2, f.y0 + 4, f.z1 + 1, b + 2, f.y1 - 2, f.z1 + 1, CLOTH); // tabard
      s.box(a - 2, f.y0 - 6, f.z1 - 3, b + 2, f.y0 + 3, f.z1 - 3, CLOTH);
      s.box(a - 2, f.y0 - 6, f.z1 - 3, a - 2, f.y0 + 3, f.z1 - 3, S).box(b + 2, f.y0 - 6, f.z1 - 3, b + 2, f.y0 + 3, f.z1 - 3, S);
      s.box(a - 2, f.y0 + 4, f.z1 + 1, a - 2, f.y1 - 2, f.z1 + 1, S).box(b + 2, f.y0 + 4, f.z1 + 1, b + 2, f.y1 - 2, f.z1 + 1, S);
      s.box(a, f.y0 + 5, f.z1 + 2, b, f.y1 - 3, f.z1 + 2, GOLD); // holy sign
      s.box(a - 1, f.y1 - 5, f.z1 + 2, b + 1, f.y1 - 5, f.z1 + 2, GOLD);
    },
  },
  outfit_mage: {
    frame: TORSO, tag: "outfit", palette: KIT,
    build(f, s) {
      const [a, b] = mid(f);
      s.box(a, f.y0 + 4, f.z1 + 1, b, f.y1 - 1, f.z1 + 1, S); // placket
      s.box(a, f.y0, f.z1 - 3, b, f.y0 + 3, f.z1 - 3, S);
      s.box(f.x0 - 1, f.y0 - 9, f.z0, f.x1 + 1, f.y0 + 1, f.z1 - 3, P); // robe skirt over the hips
      s.remove(f.x0, f.y0 - 9, f.z0 + 1, f.x1, f.y0 + 1, f.z1 - 4);
      s.box(a, f.y0 - 9, f.z1 - 3, b, f.y0, f.z1 - 3, S); // its opening
      s.box(f.x0 - 1, f.y0 - 9, f.z0, f.x1 + 1, f.y0 - 9, f.z1 - 3, S); // hem
      for (let x = f.x0; x <= f.x1; x += 3) s.box(x, f.y0 - 8, f.z1 - 3, x, f.y0 - 1, f.z1 - 3, SHADE(P)); // folds
      s.box(f.x0 + 2, f.y1 - 1, f.z0, f.x1 - 2, f.y1 + 1, f.z0, S); // high collar
    },
  },
  outfit_archer: {
    frame: TORSO, tag: "outfit", palette: KIT,
    build(f, s) {
      s.box(f.x0, f.y0 + 4, f.z1 + 1, f.x1, f.y1 - 2, f.z1 + 1, LEATHER); // jerkin
      s.box(f.x0, f.y0 + 4, f.z1 + 1, f.x1, f.y0 + 4, f.z1 + 1, LEATHER_D);
      for (let i = 0; i <= f.y1 - f.y0 - 3; i++) s.put(f.x0 + 1 + i, f.y1 - 1 - i, f.z1 + 2, WOOD_D); // quiver strap
      s.box(f.x1 - 4, f.y0 + 2, f.z0 - 3, f.x1 - 1, f.y1 + 2, f.z0 - 1, LEATHER); // quiver
      s.box(f.x1 - 4, f.y0 + 2, f.z0 - 3, f.x1 - 4, f.y1 + 2, f.z0 - 1, LEATHER_D);
      for (const x of [f.x1 - 4, f.x1 - 2]) s.box(x, f.y1 + 3, f.z0 - 2, x + 1, f.y1 + 5, f.z0 - 2, STRING); // fletching
    },
  },
  outfit_assassin: {
    frame: TORSO, tag: "outfit", palette: KIT,
    build(f, s) {
      for (let i = 0; i <= f.y1 - f.y0 - 5; i++) { // crossed straps
        s.put(f.x0 + 1 + i, f.y1 - 1 - i, f.z1 + 1, LEATHER).put(f.x1 - 1 - i, f.y1 - 1 - i, f.z1 + 1, LEATHER);
      }
      const [a, b] = mid(f);
      s.box(a, f.y1 - 7, f.z1 + 2, b, f.y1 - 6, f.z1 + 2, GOLD); // where they cross
      s.box(f.x0 + 1, f.y0 + 1, f.z1 - 3, f.x1 - 1, f.y0 + 2, f.z1 - 3, S); // sash
      s.box(f.x0, f.y0 - 4, f.z1 - 4, f.x0, f.y0 + 2, f.z1 - 3, S); // its tails
    },
  },
  outfit_villager: {
    frame: TORSO, tag: "outfit", palette: KIT,
    build(f, s) {
      const [a, b] = mid(f);
      s.box(a - 1, f.y1 - 3, f.z1 + 1, b + 1, f.y1 - 1, f.z1 + 1, CLOTH); // linen undershirt at the collar
      s.box(a, f.y1 - 6, f.z1 + 1, b, f.y1 - 4, f.z1 + 1, LEATHER_D); // laces
    },
  },
};

// --- Weapons (fist frame: grips through the middle, blades forward) -------------------
const WEAPONS = {
  weapon_sword(f, s, m = { blade: STEEL, edge: STEEL_L, fuller: STEEL_D, guard: GOLD, grip: LEATHER, pommel: GOLD }, len = 16) {
    s.box(2, 2, f.z0 - 2, 3, 3, f.z0 - 1, m.pommel);
    s.box(2, 2, f.z0, 3, 3, f.z1, m.grip);
    s.box(2, -1, f.z1 + 1, 3, 6, f.z1 + 1, m.guard); // cross-guard
    s.box(2, 1, f.z1 + 2, 2, 4, f.z1 + 1 + len, m.blade); // blade (flat, edges up and down)
    s.box(2, 4, f.z1 + 2, 2, 4, f.z1 + 1 + len, m.edge).box(2, 2, f.z1 + 2, 2, 3, f.z1 + len - 2, m.fuller);
    s.box(2, 2, f.z1 + 2 + len, 2, 3, f.z1 + 2 + len, m.blade).put(2, 3, f.z1 + 3 + len, m.edge);
  },
  weapon_wood_sword(f, s) {
    WEAPONS.weapon_sword(f, s, { blade: WOOD, edge: WOOD, fuller: WOOD_D, guard: WOOD_D, grip: LEATHER, pommel: WOOD_D }, 12);
  },
  weapon_mace(f, s) {
    s.box(2, 2, f.z0 - 2, 3, 3, f.z1 + 9, WOOD);
    s.box(2, 2, f.z0, 3, 3, f.z1, LEATHER); // wrapped grip
    s.box(0, 0, f.z1 + 10, 5, 5, f.z1 + 14, STEEL_D); // head
    for (const [x0, y0, x1, y1] of [[2, -2, 3, -1], [2, 6, 3, 7], [-2, 2, -1, 3], [6, 2, 7, 3]]) {
      s.box(x0, y0, f.z1 + 10, x1, y1, f.z1 + 14, STEEL); // flanges
      s.box(x0, y0, f.z1 + 14, x1, y1, f.z1 + 14, STEEL_L);
    }
    s.box(2, 2, f.z1 + 15, 3, 3, f.z1 + 16, GOLD); // spike
  },
  // An upright staff through the fist, reaching the ground beside the mage, crowned
  // by a glowing crystal held in gold claws.
  weapon_staff(f, s) {
    s.box(2, -15, 2, 3, 26, 3, WOOD);
    for (let y = -14; y <= 24; y += 5) s.box(2, y, 2, 3, y, 3, WOOD_D); // knots
    s.box(1, 25, 1, 4, 26, 4, GOLD);
    for (const [x, z] of [[1, 1], [4, 4], [1, 4], [4, 1]]) s.box(x, 27, z, x, 29, z, GOLD); // claws
    s.box(2, 27, 2, 3, 32, 3, GLOW).box(1, 29, 2, 4, 30, 3, GLOW).box(2, 29, 1, 3, 30, 4, GLOW);
  },
  // An upright longbow gripped in the left fist; the limbs curve back to the tips and
  // the string runs between them, on the archer's side.
  weapon_bow(f, s) {
    s.box(2, -1, 2, 2, 7, 3, WOOD).box(2, 1, 2, 2, 5, 3, LEATHER); // riser and grip
    const limb = [[8, 10, 2], [11, 13, 1], [14, 15, 0], [16, 16, -1], [17, 17, -2]];
    for (const [ya, yb, z] of limb) {
      s.box(2, ya, z, 2, yb, z + 1, WOOD);
      s.box(2, 6 - yb, z, 2, 6 - ya, z + 1, WOOD); // mirrored lower limb
    }
    s.box(2, -11, -2, 2, 17, -2, STRING);
  },
  // A crossbow held in the right fist, pointing forward: stock, rail, a prod across the
  // front with the limbs bent back, the string and a bolt laid on the rail.
  weapon_crossbow(f, s) {
    s.box(2, 1, f.z0 - 1, 3, 3, f.z1 + 9, WOOD).box(2, 1, f.z0 - 1, 3, 1, f.z1 + 9, WOOD_D);
    s.box(2, 4, f.z0, 3, 4, f.z1 + 8, WOOD_D); // rail
    s.box(-4, 3, f.z1 + 8, 9, 4, f.z1 + 9, WOOD); // prod
    s.box(-4, 3, f.z1 + 5, -4, 4, f.z1 + 8, WOOD).box(9, 3, f.z1 + 5, 9, 4, f.z1 + 8, WOOD); // tips bent back
    s.box(-4, 4, f.z1 + 5, 9, 4, f.z1 + 5, STRING);
    s.box(2, 5, f.z1 + 5, 3, 5, f.z1 + 12, STEEL).box(2, 5, f.z1 + 13, 3, 5, f.z1 + 13, STEEL_L); // bolt and head
    s.box(2, 0, f.z0 + 1, 3, 1, f.z0 + 2, LEATHER_D); // trigger guard
  },
  weapon_dagger_right(f, s) {
    s.box(2, 2, f.z0 - 1, 3, 3, f.z1, LEATHER);
    s.box(2, 0, f.z1 + 1, 3, 5, f.z1 + 1, S);
    s.box(2, 2, f.z1 + 2, 2, 4, f.z1 + 8, STEEL_D).box(2, 4, f.z1 + 2, 2, 4, f.z1 + 8, STEEL);
    s.box(2, 3, f.z1 + 9, 2, 4, f.z1 + 9, STEEL).put(2, 4, f.z1 + 10, STEEL_L);
  },
};
WEAPONS.weapon_dagger_left = WEAPONS.weapon_dagger_right;

// --- Monster pieces (data/monsters "look") ----------------------------------------------
// The cult of the demon king: faceless hoods with the black sun, long dark robes; its
// acolyte (a boss) with a spiked halo and claws.
// The cult's robes (the user's reference sheet): near-black cloth, grey folds, old
// gold trim, a grey-green pendant.
const ROBE = 60, ROBE_D = 61, ROBE_L = 62, VOID = 63, PANEL = 64, ROPE = 65, ROPE_D = 66, PENDANT = 67, PENDANT_D = 68, GOLD_D = 69;
const CULT_KIT = {
  ...KIT, [ROBE]: "#1c1b1f", [ROBE_D]: "#121114", [ROBE_L]: "#2c2b30", [VOID]: "#09080a", [PANEL]: "#141317",
  [ROPE]: "#37352f", [ROPE_D]: "#25231f", [PENDANT]: "#6f7568", [PENDANT_D]: "#4c5149", [GOLD]: "#b39a5e", [GOLD_D]: "#7d6a3e",
};
// The acolyte: the same robes with brighter old gold and claws.
const GOLD_L = 70, CLAW = 71, CLAW_D = 72;
const ACOLYTE_KIT = { ...CULT_KIT, [GOLD]: "#b8995a", [GOLD_D]: "#7a6539", [GOLD_L]: "#dcc184", [CLAW]: "#141217", [CLAW_D]: "#0b0a0c", [GLOW]: "#ffcf6a" };
// Vaelthar: the same robes, a red underrobe, maroon tentacles, black hair and veil.
const RED = 73, RED_D = 74, TENT = 75, TENT_D = 76, TENT_L = 77, MASK = 78, MASK_L = 79, BLOOD = 80, HAIR_K = 81, HAIR_D = 82, FACE = 83, FACE_D = 84, HAIR_L = 85, SUCKER = 86;
const VAEL_KIT = {
  ...ACOLYTE_KIT, [RED]: "#5e1216", [RED_D]: "#3a0a0d", [TENT]: "#4a121a", [TENT_D]: "#2a070c", [TENT_L]: "#6e2430",
  [MASK]: "#0d0c0f", [MASK_L]: "#1d1b20", [BLOOD]: "#a3201c", [HAIR_K]: "#77717d", [HAIR_D]: "#5b5562", [HAIR_L]: "#a39dab", [SUCKER]: "#8e4650", [FACE]: "#c4b2a0", [FACE_D]: "#8f7d6e", [GLOW]: "#ffbf3a",
};
// Nhazar: a black-brown mass of curls, pale stone masks, the cult's gold.
const CURL = 87, CURL_D = 88, CURL_L = 89, STONE = 90, STONE_D = 91, STONE_L = 92;
const NHAZ_KIT = {
  ...ACOLYTE_KIT, [CURL]: "#1d1517", [CURL_D]: "#0e0a0c", [CURL_L]: "#36282a", [STONE]: "#9a9088", [STONE_D]: "#5e5650",
  [STONE_L]: "#c2b8ae", [GLOW]: "#ffb84a",
};
// Forearms x -2..1, y -8..0, z -2..1.
const FORE_L = { x0: 1, x1: 4, y0: 1, y1: 9, z0: 1, z1: 4, part: "forearm_left", origin: [-3, -9, -3] };
const FORE_R = { ...FORE_L, part: "forearm_right" };
function upperSleeve(f, s) {
  s.box(f.x0 - 1, f.y0 - 1, f.z0 - 1, f.x1 + 1, f.y1 + 1, f.z1 + 1, ROBE);
  s.box(f.x0 - 1, f.y1 + 1, f.z0 - 1, f.x1 + 1, f.y1 + 1, f.z1 + 1, ROBE_L);
  s.box(f.x0 - 1, f.y0 - 1, f.z0 - 1, f.x0 - 1, f.y1, f.z0 - 1, ROBE_D);
}
function bellCuff(f, s) {
  for (let y = f.y0 - 2; y <= f.y1; y++) {
    const w = y < f.y0 + 3 ? 2 : 1; // wider at the mouth
    s.box(f.x0 - w, y, f.z0 - w, f.x1 + w, y, f.z1 + w, ROBE);
    s.remove(f.x0, y, f.z0, f.x1, y, f.z1);
  }
  for (const v of [...s.cells.values()].filter((c) => c[1] <= f.y0 - 1)) {
    s.put(v[0], v[1], v[2], (v[0] * 5 + v[2] * 3) % 4 === 0 ? ROBE : (v[1] === f.y0 - 2 ? GOLD_D : GOLD));
  }
  s.box(f.x0 - 1, f.y0 + 3, f.z0 - 1, f.x0 - 1, f.y1, f.z0 - 1, ROBE_D);
}
const MONSTER = {
  // The cult's faceless hood (from the user's reference): tall, rounded, falling onto
  // the shoulders, the face hidden behind the black sun in old gold, its rays wavy.
  cult_hood: {
    frame: HEAD, tag: "monster", palette: CULT_KIT,
    build(f, s) {
      s.box(f.x0 - 2, f.y0 - 1, f.z0 - 2, f.x1 + 2, f.y1 + 2, f.z1 + 1, ROBE); // shell (the head is inside)
      s.box(f.x0 - 1, f.y1 + 3, f.z0 - 1, f.x1 + 1, f.y1 + 3, f.z1, ROBE); // rounded dome
      s.box(f.x0, f.y1 + 4, f.z0, f.x1, f.y1 + 4, f.z1 - 1, ROBE);
      s.box(f.x0 + 2, f.y1 + 5, f.z0 + 2, f.x1 - 2, f.y1 + 5, f.z1 - 3, ROBE);
      for (const x of [f.x0 - 2, f.x1 + 2]) for (const z of [f.z0 - 2, f.z1 + 1]) s.remove(x, f.y1 + 1, z, x, f.y1 + 2, z); // rounded
      s.box(f.x0 - 4, f.y0 - 4, f.z0 - 3, f.x1 + 4, f.y0 - 1, f.z1 + 1, ROBE); // mantle over the shoulders
      s.box(f.x0 - 4, f.y0 - 4, f.z0 - 3, f.x1 + 4, f.y0 - 4, f.z1 + 1, ROBE_D);
      s.box(f.x0 - 3, f.y0 - 1, f.z0 - 3, f.x1 + 3, f.y0 + 2, f.z1, ROBE); // the hood widens into the mantle
      s.box(f.x0 - 3, f.y0 + 3, f.z0 - 2, f.x1 + 3, f.y0 + 5, f.z1 - 1, ROBE);
      s.box(f.x0 - 3, f.y0 - 1, f.z0 - 3, f.x0 - 3, f.y0 + 5, f.z0 - 2, ROBE_D).box(f.x1 + 3, f.y0 - 1, f.z0 - 3, f.x1 + 3, f.y0 + 5, f.z0 - 2, ROBE_D);
      for (let y = f.y0 - 3; y <= f.y1 + 4; y++) { // folds down the sides, in shade
        s.put(f.x0 - 2, y, f.z0, ROBE_D).put(f.x1 + 2, y, f.z0, ROBE_D);
      }
      s.box(f.x0, f.y1 + 4, f.z0 + 1, f.x1, f.y1 + 4, f.z1 - 2, ROBE_L); // light on the crown
      s.box(f.x0 - 1, f.y0 - 1, f.z1 + 1, f.x1 + 1, f.y1 + 1, f.z1 + 1, VOID); // the dark face
      // The black sun: a dark disk ringed in gold, eight wavy rays.
      const cx = (f.x0 + f.x1) / 2, cy = f.y0 + 5.5, z = f.z1 + 2;
      for (let x = Math.floor(cx) - 3; x <= Math.ceil(cx) + 3; x++) {
        for (let y = Math.floor(cy) - 3; y <= Math.ceil(cy) + 3; y++) {
          const d = Math.hypot(x - cx, y - cy);
          if (d <= 2.2) s.put(x, y, z, VOID);
          else if (d <= 3.1) s.put(x, y, z, GOLD_D);
        }
      }
      for (let k = 0; k < 8; k++) {
        const a = (k * Math.PI) / 4 + Math.PI / 2;
        const len = k % 2 === 0 ? 8.5 : 7;
        for (let t = 3; t <= len; t += 0.25) {
          const wig = Math.sin(t * 1.2 + k) * 0.9;
          const px = cx + Math.cos(a) * t - Math.sin(a) * wig, py = cy + Math.sin(a) * t + Math.cos(a) * wig;
          const c = t < len - 1.5 ? GOLD : GOLD_D;
          s.put(Math.round(px), Math.round(py), z, c);
          if (t < len - 1.5) s.put(Math.round(px + 0.5), Math.round(py), z, c); // bold near the disk
        }
      }
    },
  },
  // A long robe to the floor over the chest and hips: a front panel bordered in gold
  // with the sun, a rope belt tied at the back, a worn gold hem, a grey-green
  // horseshoe pendant on the chest.
  cult_robe: {
    frame: TORSO, tag: "monster", palette: CULT_KIT,
    build(f, s) {
      const [a, b] = mid(f);
      s.box(f.x0 - 1, f.y0 + 3, f.z0 - 1, f.x1 + 1, f.y1, f.z1 + 1, ROBE); // over the chest
      s.box(f.x0 - 2, f.y1 - 1, f.z0 - 1, f.x1 + 2, f.y1 + 1, f.z1, ROBE); // broad shoulders
      s.box(f.x0 - 1, f.y1 + 1, f.z0 - 1, f.x1 + 1, f.y1 + 1, f.z1, ROBE_L);
      const bottom = f.y0 - 25; // just above the ground
      const flareAt = (y) => Math.floor((f.y0 + 2 - y) / 6);
      const front = (y) => f.z1 + 1 + flareAt(y); // clears the belt buckle
      for (let y = bottom; y <= f.y0 + 2; y++) { // skirt, flaring towards the hem
        const flare = flareAt(y);
        const x0 = f.x0 - 2 - flare, x1 = f.x1 + 2 + flare, z0 = f.z0 - 1 - flare, z1 = front(y);
        s.box(x0, y, z0, x1, y, z1, ROBE);
        s.remove(x0 + 1, y, z0 + 1, x1 - 1, y, z1 - 1); // hollow: the legs move inside
        for (let x = x0 + 2; x <= x1 - 1; x += 3) s.put(x, y, z1, ROBE_D).put(x, y, z0, ROBE_D); // folds
      }
      for (let y = bottom; y <= bottom + 1; y++) { // worn gold hem
        for (const v of [...s.cells.values()].filter((c) => c[1] === y)) {
          s.put(v[0], v[1], v[2], (v[0] * 7 + v[2] * 3 + y) % 5 === 0 ? ROBE : (y === bottom ? GOLD_D : GOLD));
        }
      }
      // Front panel from the chest to the hem, bordered in gold, the sun and marks on it.
      const pz = front(bottom + 2) + 1;
      for (let y = bottom + 2; y <= f.y1 - 4; y++) {
        const zz = y > f.y0 + 2 ? f.z1 + 2 : front(y) + 1;
        s.box(a - 3, y, zz, b + 3, y, zz, GOLD).box(a - 2, y, zz, b + 2, y, zz, PANEL);
      }
      s.box(a - 3, bottom + 2, pz, b + 3, bottom + 2, pz, GOLD);
      const sz = front(f.y0 - 9) + 2;
      s.box(a, f.y0 - 10, sz, b, f.y0 - 7, sz, GOLD).box(a - 1, f.y0 - 9, sz, b + 1, f.y0 - 8, sz, GOLD); // small sun
      s.put(a - 2, f.y0 - 8, sz, GOLD_D).put(b + 2, f.y0 - 9, sz, GOLD_D).box(a, f.y0 - 6, sz, b, f.y0 - 5, sz, GOLD_D);
      s.box(a, f.y0 - 14, sz, b, f.y0 - 12, sz, GOLD_D).box(a - 1, f.y0 - 13, sz, b + 1, f.y0 - 13, sz, GOLD_D); // a cross-mark
      s.put(a, f.y0 - 17, sz, GOLD).put(b, f.y0 - 17, sz, GOLD); // a dot
      // Rope belt with its tie hanging at the back.
      s.box(f.x0 - 3, f.y0 + 1, f.z0 - 2, f.x1 + 3, f.y0 + 2, f.z1 + 3, ROPE);
      s.remove(f.x0 - 2, f.y0 + 1, f.z0 - 1, f.x1 + 2, f.y0 + 2, f.z1 + 2);
      s.box(a, f.y0 - 6, f.z0 - 3, b, f.y0 + 2, f.z0 - 3, ROPE).box(a - 1, f.y0 - 7, f.z0 - 3, a - 1, f.y0 - 1, f.z0 - 3, ROPE_D);
      // Horseshoe pendant hanging from the neck.
      for (let y = f.y1 - 4; y <= f.y1; y++) s.put(a - 2, y, f.z1 + 3, PENDANT).put(b + 2, y, f.z1 + 3, PENDANT);
      s.box(a - 1, f.y1 - 5, f.z1 + 3, b + 1, f.y1 - 5, f.z1 + 3, PENDANT);
      s.put(a - 2, f.y1 - 4, f.z1 + 3, PENDANT_D).put(b + 2, f.y1 - 4, f.z1 + 3, PENDANT_D);
    },
  },
  // Wide sleeves over the upper arms...
  cult_sleeve_left: { frame: ARM_L, tag: "monster", palette: CULT_KIT, build: (f, s) => upperSleeve(f, s) },
  cult_sleeve_right: { frame: ARM_R, tag: "monster", palette: CULT_KIT, build: (f, s) => upperSleeve(f, s) },
  // ...opening into bell cuffs with a worn gold hem over the forearms.
  cult_cuff_left: { frame: FORE_L, tag: "monster", palette: CULT_KIT, build: (f, s) => bellCuff(f, s) },
  cult_cuff_right: { frame: FORE_R, tag: "monster", palette: CULT_KIT, build: (f, s) => bellCuff(f, s) },
  // --- The cult acolyte (boss, the user's "Jefe final - El culto del Sol Negro" sheet) ---
  // A tall hood whose face is the black sun: a dark disk with a dim gold eye, twelve
  // straight rays; behind the head a great spiked gold halo.
  acolyte_hood: {
    frame: HEAD, tag: "monster", palette: ACOLYTE_KIT,
    build(f, s) {
      s.box(f.x0 - 2, f.y0 - 1, f.z0 - 2, f.x1 + 2, f.y1 + 2, f.z1 + 1, ROBE); // shell
      for (let k = 0; k < 4; k++) s.box(f.x0 - 1 + k, f.y1 + 3 + k, f.z0 - 1 + k, f.x1 + 1 - k, f.y1 + 3 + k, f.z1 - k, k === 3 ? ROBE_L : ROBE); // peaked crown
      for (const x of [f.x0 - 2, f.x1 + 2]) for (const z of [f.z0 - 2, f.z1 + 1]) s.remove(x, f.y1 + 1, z, x, f.y1 + 2, z);
      s.box(f.x0 - 3, f.y0 - 1, f.z0 - 3, f.x1 + 3, f.y0 + 3, f.z1, ROBE); // widening into the mantle
      for (let y = f.y0 - 1; y <= f.y1 + 3; y++) s.put(f.x0 - 2, y, f.z0, ROBE_D).put(f.x1 + 2, y, f.z0, ROBE_D);
      s.box(f.x0 - 1, f.y0 - 1, f.z1 + 1, f.x1 + 1, f.y1 + 1, f.z1 + 1, VOID); // the dark face
      // The black sun over the face: a dark disk ringed in gold, a dim eye in its middle.
      const cx = (f.x0 + f.x1) / 2, cy = f.y0 + 5.5, z = f.z1 + 2;
      for (let x = Math.floor(cx) - 4; x <= Math.ceil(cx) + 4; x++) {
        for (let y = Math.floor(cy) - 4; y <= Math.ceil(cy) + 4; y++) {
          const d = Math.hypot(x - cx, y - cy);
          if (d <= 2.4) s.put(x, y, z, VOID);
          else if (d <= 3.4) s.put(x, y, z, GOLD_D).put(x, y, z + 1, GOLD);
        }
      }
      s.box(Math.floor(cx), Math.floor(cy), z, Math.ceil(cx), Math.ceil(cy), z, GLOW); // the eye
      for (let k = 0; k < 12; k++) { // straight rays, alternating long and short
        const a = (k * Math.PI) / 6 + Math.PI / 2;
        const len = k % 2 === 0 ? 9 : 6.5;
        for (let t = 3.6; t <= len; t += 0.3) {
          s.put(Math.round(cx + Math.cos(a) * t), Math.round(cy + Math.sin(a) * t), z + (t < 5 ? 1 : 0), t > len - 1.2 ? GOLD_L : GOLD);
        }
      }
      // The halo: a gold ring behind the head with spikes all around (two voxels deep).
      const hy = cy + 3, hz = f.z0 - 5, R = 13;
      for (let x = Math.floor(cx) - R - 6; x <= Math.ceil(cx) + R + 6; x++) {
        for (let y = Math.floor(hy) - R - 6; y <= Math.ceil(hy) + R + 6; y++) {
          const d = Math.hypot(x - cx, y - hy);
          if (Math.abs(d - R) <= 0.75) s.put(x, y, hz, GOLD).put(x, y, hz - 1, GOLD_D);
        }
      }
      for (let k = 0; k < 16; k++) {
        const a = (k * Math.PI) / 8;
        const len = k % 2 === 0 ? 5.5 : 3;
        for (let t = R + 1; t <= R + len; t += 0.3) {
          const x = Math.round(cx + Math.cos(a) * t), y = Math.round(hy + Math.sin(a) * t);
          s.put(x, y, hz, t > R + len - 1 ? GOLD_L : GOLD);
          if (k % 2 === 0 && t < R + 2.5) s.put(x + Math.round(-Math.sin(a)), y + Math.round(Math.cos(a)), hz, GOLD_D); // wider at the root
        }
      }
      for (let k = 0; k < 8; k++) { // spokes joining the ring to the hood
        const a = (k * Math.PI) / 4 + Math.PI / 8;
        for (let t = 7; t <= R - 1; t += 0.4) s.put(Math.round(cx + Math.cos(a) * t), Math.round(hy + Math.sin(a) * t), hz + 1, GOLD_D);
      }
    },
  },
  // A grand robe to the floor: a stepped mantle edged in gold over the shoulders, a gold
  // chain with the sun on the chest, a front tabard ending in a point and a banner with
  // the sun down the back; the hem worn gold and ragged.
  acolyte_robe: {
    frame: TORSO, tag: "monster", palette: ACOLYTE_KIT,
    build(f, s) {
      const [a, b] = mid(f);
      s.box(f.x0 - 1, f.y0 + 3, f.z0 - 1, f.x1 + 1, f.y1, f.z1 + 1, ROBE); // over the chest
      const bottom = f.y0 - 25;
      const flareAt = (y) => Math.floor((f.y0 + 2 - y) / 3.5);
      for (let y = bottom; y <= f.y0 + 2; y++) { // skirt, flaring wide towards the hem
        const fl = flareAt(y);
        const x0 = f.x0 - 2 - fl, x1 = f.x1 + 2 + fl, z0 = f.z0 - 1 - fl, z1 = f.z1 + 1 + fl;
        s.box(x0, y, z0, x1, y, z1, ROBE);
        s.remove(x0 + 1, y, z0 + 1, x1 - 1, y, z1 - 1); // hollow: the legs move inside
        for (let x = x0 + 2; x <= x1 - 1; x += 3) s.put(x, y, z1, ROBE_D).put(x, y, z0, ROBE_D); // folds
        for (let zz = z0 + 2; zz <= z1 - 1; zz += 3) s.put(x0, y, zz, ROBE_D).put(x1, y, zz, ROBE_D);
      }
      for (const v of [...s.cells.values()].filter((c) => c[1] <= bottom + 2)) { // ragged gold hem
        const h = (v[0] * 7 + v[2] * 3) % 5;
        if (v[1] === bottom && h === 0) s.remove(v[0], v[1], v[2], v[0], v[1], v[2]);
        else s.put(v[0], v[1], v[2], v[1] === bottom + 2 ? (h < 2 ? GOLD_D : ROBE) : (h < 3 ? GOLD : GOLD_D));
      }
      // Stepped mantle: two layers over the shoulders, gold edges.
      for (const [dy, w, edge] of [[0, 3, GOLD], [-4, 4, GOLD_D]]) {
        const y0 = f.y1 - 4 + dy, y1 = f.y1 + 1 + dy;
        s.box(f.x0 - w, y0, f.z0 - 2 - (w - 3), f.x1 + w, y1, f.z1 + 1 + (w - 3), ROBE);
        s.remove(f.x0 - w + 1, y0, f.z0 - 1 - (w - 3), f.x1 + w - 1, y1 - 1, f.z1 + (w - 3));
        s.box(f.x0 - w, y0, f.z0 - 2 - (w - 3), f.x1 + w, y0, f.z1 + 1 + (w - 3), edge);
        s.remove(f.x0 - w + 1, y0, f.z0 - 1 - (w - 3), f.x1 + w - 1, y0, f.z1 + (w - 3));
      }
      s.box(f.x0 - 3, f.y1 + 1, f.z0 - 2, f.x1 + 3, f.y1 + 1, f.z1 + 1, ROBE_L);
      // Front tabard, from the chest to a point below the knees, bordered in gold.
      const tz = (y) => (y > f.y0 + 2 ? f.z1 + 2 : f.z1 + 2 + flareAt(y));
      const tip = bottom + 5;
      for (let y = tip; y <= f.y1 - 3; y++) {
        const narrow = Math.max(0, 3 - (y - tip)); // the point
        const xa = a - 3 + narrow, xb = b + 3 - narrow;
        s.box(xa, y, tz(y), xb, y, tz(y), GOLD);
        if (xb - xa >= 2) s.box(xa + 1, y, tz(y), xb - 1, y, tz(y), PANEL);
      }
      const sun = (cy, zf) => { // a small sun in gold
        const zz = zf(cy);
        s.box(a, cy - 1, zz + 1, b, cy + 1, zz + 1, GOLD).box(a - 1, cy, zz + 1, b + 1, cy, zz + 1, GOLD);
        s.put(a - 2, cy + 2, zz + 1, GOLD_D).put(b + 2, cy + 2, zz + 1, GOLD_D).put(a - 2, cy - 2, zz + 1, GOLD_D).put(b + 2, cy - 2, zz + 1, GOLD_D);
        s.put(a, cy + 2, zz + 1, GOLD_D).put(b, cy - 2, zz + 1, GOLD_D);
      };
      sun(f.y0 - 7, tz);
      s.box(a, f.y0 - 15, tz(f.y0 - 13) + 1, b, f.y0 - 11, tz(f.y0 - 13) + 1, GOLD_D).box(a - 1, f.y0 - 12, tz(f.y0 - 12) + 1, b + 1, f.y0 - 12, tz(f.y0 - 12) + 1, GOLD_D); // a cross-mark
      s.put(a, tip + 2, tz(tip + 2) + 1, GOLD).put(b, tip + 2, tz(tip + 2) + 1, GOLD); // a dot
      // Back banner with the sun.
      const bz = (y) => (y > f.y0 + 2 ? f.z0 - 2 : f.z0 - 2 - flareAt(y));
      for (let y = bottom + 3; y <= f.y1 - 2; y++) {
        const narrow = Math.max(0, 3 - (y - bottom - 3));
        s.box(a - 3 + narrow, y, bz(y), b + 3 - narrow, y, bz(y), GOLD);
        if (narrow < 2) s.box(a - 2 + narrow, y, bz(y), b + 2 - narrow, y, bz(y), PANEL);
      }
      const bs = (y) => bz(y) - 2;
      sun(f.y0 - 4, bs);
      s.box(a, f.y0 - 14, bz(f.y0 - 12) - 1, b, f.y0 - 10, bz(f.y0 - 12) - 1, GOLD_D);
      // Rope belt.
      s.box(f.x0 - 3, f.y0 + 1, f.z0 - 2, f.x1 + 3, f.y0 + 2, f.z1 + 2, ROPE);
      s.remove(f.x0 - 2, f.y0 + 1, f.z0 - 1, f.x1 + 2, f.y0 + 2, f.z1 + 1);
      // Gold chain hanging in a U from the shoulders, the sun pendant at its bottom.
      for (let i = 0; i <= 8; i++) {
        const dy = Math.round(Math.sin((i / 8) * Math.PI) * 5);
        s.put(f.x0 + 1 + i, f.y1 - 1 - dy, f.z1 + 2, i % 2 ? GOLD_D : GOLD).put(f.x1 - 1 - i, f.y1 - 1 - dy, f.z1 + 2, i % 2 ? GOLD_D : GOLD);
      }
      s.box(a - 1, f.y1 - 10, f.z1 + 3, b + 1, f.y1 - 6, f.z1 + 3, GOLD);
      s.box(a, f.y1 - 9, f.z1 + 4, b, f.y1 - 7, f.z1 + 4, VOID).put(a, f.y1 - 8, f.z1 + 4, GLOW);
      s.put(a - 2, f.y1 - 8, f.z1 + 3, GOLD_D).put(b + 2, f.y1 - 8, f.z1 + 3, GOLD_D).put(a, f.y1 - 11, f.z1 + 3, GOLD_D).put(b, f.y1 - 11, f.z1 + 3, GOLD_D);
    },
  },
  // Big sleeves: the upper arm wrapped with a gold seam...
  acolyte_sleeve_left: { frame: ARM_L, tag: "monster", palette: ACOLYTE_KIT, build: (f, s) => acolyteSleeve(f, s) },
  acolyte_sleeve_right: { frame: ARM_R, tag: "monster", palette: ACOLYTE_KIT, build: (f, s) => acolyteSleeve(f, s) },
  // ...opening into wide bell cuffs edged in gold, a long drape hanging behind.
  acolyte_cuff_left: { frame: FORE_L, tag: "monster", palette: ACOLYTE_KIT, build: (f, s) => acolyteCuff(f, s) },
  acolyte_cuff_right: { frame: FORE_R, tag: "monster", palette: ACOLYTE_KIT, build: (f, s) => acolyteCuff(f, s) },
  // Black clawed hands: four long splayed fingers curling forward, tips caught in gold.
  acolyte_claws_left: { frame: HAND_L, tag: "monster", palette: ACOLYTE_KIT, build: (f, s) => claws(f, s, 1) },
  acolyte_claws_right: { frame: HAND_R, tag: "monster", palette: ACOLYTE_KIT, build: (f, s) => claws(f, s, -1) },
};
// --- Vaelthar, the First Apostle (boss; the user's reference sheet) -------------------
// A long ash-grey mane around a pale face (a red stripe down the brow, burning gold eyes, a
// black veil over the mouth), a great spiked halo; a vast layered robe over a
// blood-red underrobe, ragged; thick tentacles out of the shoulders. It floats.
const VAEL = {
  mane: {
    frame: HEAD, tag: "monster", palette: VAEL_KIT,
    build(f, s) {
      // A long ash-grey mane: a crown over the head, curtains down both sides onto the
      // shoulders, locks framing the face down the chest and a mass down the back,
      // flaring out and ending in ragged tips. Strands alternate tones, a few catch light.
      const strand = (x, y) => ((x * 3 + Math.floor(y / 3)) % 5 === 0 ? HAIR_L : (x + Math.floor(y / 4)) % 2 ? HAIR_D : HAIR_K);
      const tipOf = (x, z, base, spread) => base - ((x * 7 + z * 5) % spread); // ragged ends
      s.box(f.x0 - 1, f.y1 + 1, f.z0 - 1, f.x1 + 1, f.y1 + 2, f.z1 + 1, HAIR_K); // crown
      s.box(f.x0, f.y1 + 3, f.z0, f.x1, f.y1 + 3, f.z1 - 1, HAIR_D);
      for (let x = f.x0 - 1; x <= f.x1 + 1; x++) s.put(x, f.y1 + 2, f.z1 + 1, strand(x, f.y1));
      const [ma, mb] = mid(f);
      s.box(ma, f.y1 + 1, f.z1 - 2, mb, f.y1 + 3, f.z1 + 1, HAIR_L).box(ma, f.y1 + 1, f.z1 - 2, ma, f.y1 + 3, f.z1 + 1, HAIR_K); // the parting
      for (const side of [-1, 1]) { // side curtains, thicker as they fall
        const edge = side < 0 ? f.x0 - 1 : f.x1 + 1;
        for (let z = f.z0 - 1; z <= f.z1; z++) {
          const end = tipOf(edge, z, f.y0 - 12, 4);
          for (let y = end; y <= f.y1 + 1; y++) {
            const thick = 2;
            for (let k = 0; k < thick; k++) s.put(edge + side * k, y, z, strand(z, y));
          }
        }
      }
      for (const x of [f.x0 - 1, f.x0 - 2, f.x1 + 1, f.x1 + 2]) { // locks over the shoulders, down the chest
        const end = tipOf(x, 1, f.y0 - 16, 5);
        for (let y = end; y <= f.y1; y++) s.put(x, y, f.z1 + 1, strand(x, y)).put(x, y, f.z1 + 2, y < f.y0 ? strand(x + 1, y) : HAIR_K);
      }
      for (let y = f.y1 + 2; y >= f.y0 - 26; y--) { // the back, flaring outwards and away
        const drop = f.y1 + 2 - y;
        const w = Math.floor(drop / 6), back = f.z0 - 1 - Math.floor(drop / 5);
        for (let x = f.x0 - 1 - w; x <= f.x1 + 1 + w; x++) {
          if (y < tipOf(x, 0, f.y0 - 18, 9)) continue;
          s.put(x, y, back, strand(x, y)).put(x, y, back + 1, HAIR_K);
        }
      }
      // A pale face painted over the head.
      s.box(f.x0, f.y0 + 5, f.z1 + 1, f.x1, f.y1 - 1, f.z1 + 1, FACE);
      s.box(f.x0, f.y0 + 4, f.z1 + 1, f.x1, f.y0 + 4, f.z1 + 1, FACE_D);
      // The black veil from below the eyes, hanging in a point down the chest.
      s.box(f.x0, f.y0 - 1, f.z1 + 1, f.x1, f.y0 + 3, f.z1 + 1, MASK);
      const [a, b] = mid(f);
      s.box(f.x0, f.y0 - 5, f.z1 + 1, f.x1, f.y0 - 2, f.z1 + 1, MASK).box(a - 2, f.y0 - 8, f.z1 + 1, b + 2, f.y0 - 6, f.z1 + 1, MASK).box(a, f.y0 - 10, f.z1 + 1, b, f.y0 - 9, f.z1 + 1, MASK);
      s.box(f.x0 + 1, f.y0 + 3, f.z1 + 2, f.x1 - 1, f.y0 + 3, f.z1 + 2, MASK_L);
      s.box(a, f.y0 + 6, f.z1 + 1, b, f.y1 - 1, f.z1 + 1, BLOOD).put(a, f.y0 + 5, f.z1 + 1, BLOOD); // the red stripe down the brow
      s.box(f.x0 + 1, f.y0 + 5, f.z1 + 1, f.x0 + 2, f.y0 + 5, f.z1 + 1, GLOW).box(f.x1 - 2, f.y0 + 5, f.z1 + 1, f.x1 - 1, f.y0 + 5, f.z1 + 1, GLOW); // eyes
      halo(s, (f.x0 + f.x1) / 2, f.y0 + 9, f.z0 - 5, 14, true);
    },
  },
  robe: {
    frame: TORSO, tag: "monster", palette: VAEL_KIT,
    build(f, s) {
      const [a, b] = mid(f);
      s.box(f.x0 - 1, f.y0 + 3, f.z0 - 1, f.x1 + 1, f.y1, f.z1 + 1, ROBE);
      const bottom = f.y0 - 25;
      const flareAt = (y) => Math.floor((f.y0 + 2 - y) / 3);
      for (let y = bottom; y <= f.y0 + 2; y++) { // the outer robe, open at the front
        const fl = flareAt(y);
        const x0 = f.x0 - 2 - fl, x1 = f.x1 + 2 + fl, z0 = f.z0 - 1 - fl, z1 = f.z1 + 1 + fl;
        s.box(x0, y, z0, x1, y, z1, ROBE);
        s.remove(x0 + 1, y, z0 + 1, x1 - 1, y, z1 - 1);
        const gap = Math.floor(fl * 0.8) + 2; // the opening widens downwards
        s.box(a - gap, y, z1, b + gap, y, z1, y % 3 === 0 ? RED_D : RED); // red underrobe
        s.box(a - gap - 1, y, z1, a - gap - 1, y, z1, GOLD).box(b + gap + 1, y, z1, b + gap + 1, y, z1, GOLD); // gold edges
        for (let x = x0 + 2; x <= x1 - 1; x += 3) if (x < a - gap - 1 || x > b + gap + 1) s.put(x, y, z1, ROBE_D);
        for (let x = x0 + 2; x <= x1 - 1; x += 3) s.put(x, y, z0, ROBE_D);
        for (let zz = z0 + 2; zz <= z1 - 1; zz += 3) s.put(x0, y, zz, ROBE_D).put(x1, y, zz, ROBE_D);
      }
      // Ragged hem: tongues of cloth of different lengths, black over red.
      for (const v of [...s.cells.values()].filter((c) => c[1] === bottom)) {
        const h = (v[0] * 7 + v[2] * 5) % 6;
        const red = s.cells.get(`${v[0]},${v[1]},${v[2]}`)[3] === RED || s.cells.get(`${v[0]},${v[1]},${v[2]}`)[3] === RED_D;
        for (let d = 1; d <= h - 2; d++) s.put(v[0], bottom - d, v[2], red ? RED_D : ROBE_D);
        if (!red && h === 0) s.put(v[0], bottom, v[2], GOLD_D);
      }
      // Three stepped mantle layers with gold edges.
      for (const [dy, w] of [[0, 3], [-4, 4], [-8, 5]]) {
        const y0 = f.y1 - 4 + dy, y1 = f.y1 + 1 + dy - (dy ? 2 : 0);
        s.box(f.x0 - w, y0, f.z0 - 2 - (w - 3), f.x1 + w, y1, f.z1 + 1 + (w - 3), ROBE);
        s.remove(f.x0 - w + 1, y0, f.z0 - 1 - (w - 3), f.x1 + w - 1, y1, f.z1 + (w - 3));
        s.box(f.x0 - w, y0, f.z0 - 2 - (w - 3), f.x1 + w, y0, f.z1 + 1 + (w - 3), GOLD);
        s.remove(f.x0 - w + 1, y0, f.z0 - 1 - (w - 3), f.x1 + w - 1, y0, f.z1 + (w - 3));
      }
      s.box(f.x0 - 3, f.y1 + 1, f.z0 - 2, f.x1 + 3, f.y1 + 1, f.z1 + 1, ROBE_L);
      s.box(a - 3, f.y1 + 2, f.z0 + 1, b + 3, f.y1 + 2, f.z1, MASK); // high collar over the neck
      s.box(a - 2, f.y1 - 3, f.z1 + 2, b + 2, f.y1 + 1, f.z1 + 2, MASK); // and over the open shirt collar
      // Front tabard over the red: chest to below the knees, ending in a point.
      const tz = (y) => (y > f.y0 + 2 ? f.z1 + 2 : f.z1 + 2 + flareAt(y));
      const tip = bottom + 6;
      for (let y = tip; y <= f.y1 - 3; y++) {
        const narrow = Math.max(0, 3 - (y - tip));
        const xa = a - 3 + narrow, xb = b + 3 - narrow;
        s.box(xa, y, tz(y), xb, y, tz(y), GOLD);
        if (xb - xa >= 2) s.box(xa + 1, y, tz(y), xb - 1, y, tz(y), PANEL);
      }
      const mark = (cy, zf, big) => {
        const zz = zf(cy) + 1;
        s.box(a, cy - 1, zz, b, cy + 1, zz, GOLD).box(a - 1, cy, zz, b + 1, cy, zz, GOLD);
        if (big) s.box(a, cy - 3, zz, b, cy + 3, zz, GOLD_D).box(a - 2, cy, zz, b + 2, cy, zz, GOLD_D).put(a, cy, zz, VOID).put(b, cy, zz, VOID);
      };
      mark(f.y0 - 6, tz, true);
      for (const y of [f.y0 - 12, f.y0 - 15]) s.box(a, y, tz(y) + 1, b, y, tz(y) + 1, GOLD_D).put(a - 1, y + 1, tz(y) + 1, GOLD_D).put(b + 1, y + 1, tz(y) + 1, GOLD_D); // diamonds
      // Back banner with a big sun.
      const bz = (y) => (y > f.y0 + 2 ? f.z0 - 2 : f.z0 - 2 - flareAt(y));
      for (let y = bottom + 4; y <= f.y1 - 2; y++) {
        const narrow = Math.max(0, 3 - (y - bottom - 4));
        s.box(a - 3 + narrow, y, bz(y), b + 3 - narrow, y, bz(y), GOLD);
        if (narrow < 2) s.box(a - 2 + narrow, y, bz(y), b + 2 - narrow, y, bz(y), PANEL);
      }
      mark(f.y0 - 4, (y) => bz(y) - 2, true);
      // Belt and the chain with the sun medallion.
      s.box(f.x0 - 3, f.y0 + 1, f.z0 - 2, f.x1 + 3, f.y0 + 2, f.z1 + 2, ROPE);
      s.remove(f.x0 - 2, f.y0 + 1, f.z0 - 1, f.x1 + 2, f.y0 + 2, f.z1 + 1);
      for (let i = 0; i <= 8; i++) {
        const dy = Math.round(Math.sin((i / 8) * Math.PI) * 5);
        s.put(f.x0 + 1 + i, f.y1 - 1 - dy, f.z1 + 2, i % 2 ? GOLD_D : GOLD).put(f.x1 - 1 - i, f.y1 - 1 - dy, f.z1 + 2, i % 2 ? GOLD_D : GOLD);
      }
      const my = f.y1 - 8, mz = f.z1 + 3;
      for (let x = a - 4; x <= b + 4; x++) for (let y = my - 4; y <= my + 4; y++) {
        const d = Math.hypot(x - (a + b) / 2, y - my);
        if (d <= 1.6) s.put(x, y, mz + 1, VOID);
        else if (d <= 2.6) s.put(x, y, mz, GOLD);
      }
      for (const [dx, dy] of [[0, 4], [0, -4], [4, 0], [-4, 0], [3, 3], [-3, 3], [3, -3], [-3, -3]]) s.put(Math.round((a + b) / 2 + dx), my + dy, mz, Math.abs(dx) === Math.abs(dy) ? GOLD_D : GOLD);
      s.put(a, my, mz + 1, GLOW);
    },
  },
};
// The spiked halo behind a head: a gold ring with `spikes` all around, long ones at the
// four points crossed like stars (`cross`), spokes to the mount.
function halo(s, cx, hy, hz, R, cross) {
  for (let x = Math.floor(cx) - R - 8; x <= Math.ceil(cx) + R + 8; x++) {
    for (let y = Math.floor(hy) - R - 8; y <= Math.ceil(hy) + R + 8; y++) {
      const d = Math.hypot(x - cx, y - hy);
      if (Math.abs(d - R) <= 0.75) s.put(x, y, hz, GOLD).put(x, y, hz - 1, GOLD_D);
    }
  }
  for (let k = 0; k < 16; k++) {
    const ang = (k * Math.PI) / 8;
    const big = cross && k % 4 === 0;
    const len = big ? 8 : k % 2 === 0 ? 5 : 3;
    for (let t = R + 1; t <= R + len; t += 0.3) {
      const x = Math.round(cx + Math.cos(ang) * t), y = Math.round(hy + Math.sin(ang) * t);
      s.put(x, y, hz, t > R + len - 1 ? GOLD_L : GOLD);
      if (k % 2 === 0 && t < R + 2.5) s.put(x + Math.round(-Math.sin(ang)), y + Math.round(Math.cos(ang)), hz, GOLD_D);
    }
    if (big) { // a crossbar near the tip
      const t = R + len - 2.5, x = cx + Math.cos(ang) * t, y = hy + Math.sin(ang) * t;
      for (let u = -2; u <= 2; u++) s.put(Math.round(x - Math.sin(ang) * u), Math.round(y + Math.cos(ang) * u), hz, GOLD);
    }
  }
  for (let k = 0; k < 8; k++) {
    const ang = (k * Math.PI) / 4 + Math.PI / 8;
    for (let t = 7; t <= R - 1; t += 0.4) s.put(Math.round(cx + Math.cos(ang) * t), Math.round(hy + Math.sin(ang) * t), hz + 1, GOLD_D);
  }
}
// Vaelthar's sleeve, cut at the elbow: it wraps the shoulder and opens into a wide mouth
// with a torn gold hem, hollow so the tentacles inside show as they come out.
function vaelSleeve(f, s) {
  for (let y = f.y0 - 2; y <= f.y1 + 1; y++) {
    const w = y > f.y1 - 3 ? 2 : y > f.y0 + 2 ? 2 : 3; // wider at the mouth
    s.box(f.x0 - w, y, f.z0 - w, f.x1 + w, y, f.z1 + w, ROBE);
    if (y <= f.y1 - 1) s.remove(f.x0 - w + 1, y, f.z0 - w + 1, f.x1 + w - 1, y, f.z1 + w - 1);
  }
  s.box(f.x0 - 2, f.y1 + 1, f.z0 - 2, f.x1 + 2, f.y1 + 1, f.z1 + 2, ROBE_L);
  s.box(f.x0 - 2, f.y1 - 2, f.z0 - 2, f.x1 + 2, f.y1 - 2, f.z1 + 2, GOLD_D); // seam at the shoulder
  s.remove(f.x0 - 1, f.y1 - 2, f.z0 - 1, f.x1 + 1, f.y1 - 2, f.z1 + 1);
  for (const v of [...s.cells.values()].filter((c) => c[1] <= f.y0 - 1)) { // torn gold hem
    const h = (v[0] * 5 + v[2] * 3) % 4;
    if (v[1] === f.y0 - 2 && h === 0) s.remove(v[0], v[1], v[2], v[0], v[1], v[2]);
    else s.put(v[0], v[1], v[2], v[1] === f.y0 - 2 ? GOLD : h === 1 ? ROBE : GOLD_D);
  }
  for (let y = f.y0; y <= f.y1 - 3; y += 1) s.put(f.x0 - 2, y, f.z0 - 2, ROBE_D).put(f.x1 + 2, y, f.z1 + 2, ROBE_D); // folds
}
// Thick tentacles that grow from the shoulder inside the sleeve and pour out of its
// mouth at the elbow (the forearm and hand are gone): they hang in S-curves, sway out
// and curl at the tips; dark underside, pale suckers on the inner side.
function tentacles(f, s, outer) {
  const cx = (f.x0 + f.x1) / 2, cz = (f.z0 + f.z1) / 2;
  s.box(f.x0, f.y0 - 1, f.z0, f.x1, f.y1 - 1, f.z1, TENT_D); // the root, inside the sleeve
  // [heading from straight out (+ forward), drop, reach, sway phase, start offset x, z]
  const arms = [[0.2, 30, 9, 0, 1, 0], [1.2, 26, 7, 1.6, 0, 1], [-1.0, 28, 8, 3.0, 0, -1]];
  arms.forEach(([ang, drop, reach, ph, ox, oz]) => {
    const sx = cx + outer * ox, sy = f.y0 + 1, sz = cz + oz;
    const steps = 80;
    for (let k = 0; k <= steps; k++) {
      const u = k / steps;
      const a = ang + Math.sin(u * 6 + ph) * 0.35 * u;
      let out = reach * Math.pow(u, 0.8) + Math.sin(u * 9 + ph) * 1.5 * u; // S-curves as it hangs
      let y = sy - drop * Math.pow(u, 1.1);
      if (u > 0.8) { // the tip curls outwards and up
        const c = (u - 0.8) / 0.2;
        out += Math.sin(c * Math.PI) * 4;
        y += c * c * 9;
      }
      const x = sx + outer * Math.cos(a) * out, z = sz + Math.sin(a) * out;
      const r = u < 0.35 ? 2 : u < 0.75 ? 1 : 0; // thick, tapering
      const X = Math.round(x), Y = Math.round(y), Z = Math.round(z);
      s.box(X - r, Y - r, Z - r, X + r, Y + r, Z + r, k % 9 === 0 && r > 0 ? TENT_L : TENT);
      if (r > 0) s.box(X - r, Y - r, Z - r, X + r, Y - r, Z + r, TENT_D); // underside
      if (r > 0 && k % 6 === 0) s.put(X - outer * r, Y, Z, SUCKER); // suckers on the inner side
    }
  });
}
// --- Nhazar, the Bishop of a Thousand Voices (boss; the user's reference sheet) -------
// His head is a vast mass of black curls, far bigger than the body, full of pale masks
// that scream, wail, rage and grin; gold crosses stand out of it. Chains with gold weights hang from his hands.
function nhazarHead(f, s) {
  const cx = (f.x0 + f.x1) / 2, cz = (f.z0 + f.z1) / 2, R = 38, cy = f.y0 + R * 0.95;
  for (let x = Math.floor(cx - R - 6); x <= Math.ceil(cx + R + 6); x++) {
    for (let y = Math.floor(cy - R - 6); y <= Math.ceil(cy + R + 6); y++) {
      for (let z = Math.floor(cz - R - 6); z <= Math.ceil(cz + R + 6); z++) {
        const d = Math.hypot(x - cx, y - cy, z - cz) || 1;
        const nx = (x - cx) / d, ny = (y - cy) / d, nz = (z - cz) / d;
        const bump = Math.sin(nx * 11 + ny * 3) * 2.2 + Math.sin(ny * 13 - nz * 5) * 1.9 + Math.sin(nz * 10 + nx * 4) * 2.0;
        const r = R + bump;
        if (d > r || d < r - 2) continue; // a shell (the inside is never seen)
        const curl = Math.sin(x * 1.3 + y * 0.7) + Math.sin(z * 1.1 - y * 0.9);
        const c = d > r - 0.8 ? (curl > 0.9 ? CURL_L : curl < -1.1 ? CURL_D : CURL) : CURL_D;
        s.put(x, y, z, ny > 0.55 && curl > 0.4 ? CURL_L : c);
      }
    }
  }
  for (let k = 0; k < 30; k++) { // loose curls drifting around the mass
    const th = k * 2.4, ph = Math.acos(1 - 2 * ((k + 0.5) / 30));
    const nx = Math.sin(ph) * Math.cos(th), ny = Math.cos(ph), nz = Math.sin(ph) * Math.sin(th);
    const px = Math.round(cx + nx * (R + 8)), py = Math.round(cy + ny * (R + 8)), pz = Math.round(cz + nz * (R + 8));
    s.box(px, py, pz, px + 2, py + 1, pz + 1, CURL).box(px + 2, py + 2, pz, px + 2, py + 3, pz, CURL_D).put(px - 1, py, pz, CURL_D);
  }
  // The masks: big pale stone faces pressed into the curls, each with a face of its own:
  // screaming, wailing in sorrow, raging with burning eyes, grinning madly.
  // S stone, L light, D shade, h hole, N nose (stands out), G glowing.
  const FACES = {
    scream: ["  SSSSS  ", " SLLLLLS ", "SDDSLSDDS", "SSSSLSSSS", "ShhSNShhS", "ShhSNShhS", "SSSDNDSSS", "SDhhhhhDS", "SShhhhhSS", " SShhhSS ", "  SDDDS  "],
    sorrow: ["  SSSSS  ", " SSSLSSS ", "SSSDLDSSS", "SDDSLSDDS", "SShSNShSS", "ShhSNShhS", "SSSDNDSSS", "SSShhhSSS", "SSShhhSSS", " SShhhSS ", "  SSDSS  "],
    rage: ["  SSSSS  ", " SSSLSSS ", "SDDSLSDDS", "SSDDLDDSS", "ShGSNSGhS", "SShSNShSS", "SSDDNDDSS", "ShLhLhLhS", "ShhhhhhhS", " SLhLhLS ", "  SDDDS  "],
    grin: ["  SSSSS  ", " SSLLLSS ", "SSDSLSDSS", "SSSSLSSSS", "ShhSNShhS", "SShSNShSS", "hSSDNDSSh", "ShSSSSShS", "SShhhhhSS", " SSShSSS ", "  SSSSS  "],
  };
  const KINDS = ["scream", "sorrow", "rage", "scream", "grin", "sorrow"];
  const COLOR = { S: STONE, L: STONE_L, D: STONE_D, h: CURL_D, N: STONE_L, G: GLOW };
  const masks = [];
  for (let k = 0; k < 34; k++) { // spread evenly over the mass (fewer underneath)
    const ph = Math.acos(1 - 1.7 * ((k + 0.5) / 34)), th = k * 2.39996;
    masks.push([Math.sin(ph) * Math.cos(th), Math.cos(ph), Math.sin(ph) * Math.sin(th)]);
  }
  masks.forEach(([nx, ny, nz], i) => {
    const axis = Math.abs(nz) >= Math.abs(nx) ? "z" : "x"; // the mask faces the nearest side
    const sgn = axis === "z" ? Math.sign(nz) || 1 : Math.sign(nx) || 1;
    const px = cx + nx * (R - 0.5), py = cy + ny * (R - 0.5), pz = cz + nz * (R - 0.5);
    const face = FACES[KINDS[i % KINDS.length]];
    for (let row = 0; row < 11; row++) for (let col = 0; col < 9; col++) {
      const ch = face[row][col];
      if (ch === " ") continue;
      const u = col - 4, v = 5 - row;
      const X = Math.round(axis === "x" ? px : px + u * sgn), Y = Math.round(py + v), Z = Math.round(axis === "z" ? pz : pz - u * sgn);
      const out = (k) => [axis === "x" ? X + sgn * k : X, Y, axis === "z" ? Z + sgn * k : Z];
      for (let k = -2; k <= 0; k++) s.put(...out(k), k < 0 ? STONE_D : COLOR[ch]); // a thick plate, set into the curls
      if (ch === "N") s.put(...out(1), STONE_L); // the nose stands out
      if (ch === "h" || ch === "G") s.put(...out(-1), ch === "G" ? GLOW : CURL_D); // deep holes
    }
  });
  // Gold crosses standing out of the top, and a broken gold ring behind the mass.
  for (let k = 0; k < 9; k++) { // on the crown, between the masks
    const nx = Math.sin((k - 4) * 0.2), ny = Math.cos((k - 4) * 0.2);
    const bx = Math.round(cx + nx * (R + 1)), by = Math.round(cy + ny * (R + 1)), bz = Math.round(cz + (k % 2 ? -9 : 7));
    s.box(bx, by, bz, bx + 1, by + 11, bz, GOLD).box(bx - 3, by + 8, bz, bx + 4, by + 8, bz, GOLD).box(bx, by + 11, bz, bx + 1, by + 11, bz, GOLD_L).put(bx, by, bz, GOLD_D);
  }
  for (let k = 0; k < 120; k++) {
    if (k % 30 > 21) continue; // broken
    const a = (k / 120) * Math.PI * 2;
    const x = Math.round(cx + Math.cos(a) * (R + 7)), y = Math.round(cy + Math.sin(a) * (R + 7)), z = Math.round(cz - R + 6);
    s.box(x, y, z, x, y, z + 1, k % 5 ? GOLD : GOLD_D);
  }
}
// Gold-weighted chains hanging from the outside of the bell cuff (forearm frame): links,
// then a weight like a small censer.
function nhazarChains(f, s, outer) {
  const edge = outer > 0 ? f.x1 + 4 : f.x0 - 4;
  for (const [dz, len] of [[1, 12], [-2, 8]]) {
    const x = edge, z = Math.round((f.z0 + f.z1) / 2) + dz;
    for (let k = 0; k < len; k++) s.put(x, f.y0 - k, z, k % 2 ? GOLD_D : GOLD).put(x, f.y0 - k, z + (k % 2), k % 2 ? GOLD_D : GOLD);
    const wy = f.y0 - len;
    s.box(x - 1, wy - 3, z - 1, x + 1, wy - 1, z + 1, GOLD).box(x - 1, wy - 2, z - 1, x + 1, wy - 2, z + 1, GOLD_D).put(x, wy - 2, z + 2, GLOW);
    s.put(x, wy - 4, z, GOLD_D);
  }
}
// The high collar that closes the robe around the neck.
function nhazarCollar(f, s) {
  const [a, b] = mid(f);
  s.box(a - 3, f.y1 + 1, f.z0, b + 3, f.y1 + 3, f.z1 + 1, ROBE);
  s.remove(a - 2, f.y1 + 1, f.z0 + 1, b + 2, f.y1 + 3, f.z1);
  s.box(a - 3, f.y1 + 3, f.z0, b + 3, f.y1 + 3, f.z1 + 1, GOLD);
  s.box(a - 2, f.y1 - 3, f.z1 + 2, b + 2, f.y1 + 1, f.z1 + 2, ROBE_D); // over the open shirt collar
  s.box(a - 2, f.y1 + 1, f.z0 + 1, b + 2, f.y1 + 2, f.z1, VOID); // the dark inside
}
// --- The cult inquisitor (an elite of the cultist bands; the user's "Inquisidor solar"
// sheet): a dark hood with burning eyes inside a gold sunburst crown, heavy stepped
// pauldrons, plated forearms, a buckled war belt over the cult robe and a long
// ceremonial sword with gold edges.
function inquisitorHood(f, s) {
  s.box(f.x0 - 2, f.y0 - 1, f.z0 - 2, f.x1 + 2, f.y1 + 2, f.z1 + 1, ROBE); // shell
  for (let k = 0; k < 3; k++) s.box(f.x0 - 1 + k, f.y1 + 3 + k, f.z0 - 1 + k, f.x1 + 1 - k, f.y1 + 3 + k, f.z1 - k, ROBE);
  s.box(f.x0 - 3, f.y0 - 2, f.z0 - 3, f.x1 + 3, f.y0 + 2, f.z1, ROBE); // into the mantle
  for (let y = f.y0 - 1; y <= f.y1 + 2; y++) s.put(f.x0 - 2, y, f.z0, ROBE_D).put(f.x1 + 2, y, f.z0, ROBE_D);
  s.box(f.x0 - 1, f.y0 - 1, f.z1 + 1, f.x1 + 1, f.y1 + 1, f.z1 + 1, VOID); // the dark face
  s.box(f.x0 + 1, f.y0 + 5, f.z1 + 2, f.x0 + 2, f.y0 + 5, f.z1 + 2, GLOW).box(f.x1 - 2, f.y0 + 5, f.z1 + 2, f.x1 - 1, f.y0 + 5, f.z1 + 2, GLOW); // eyes
  // The sunburst crown around the hood: a gold ring with rays, the top one a tall spike.
  const cx = (f.x0 + f.x1) / 2, cy = f.y0 + 6, z = f.z1 + 1, R = 8;
  for (let x = Math.floor(cx) - R - 1; x <= Math.ceil(cx) + R + 1; x++) for (let y = Math.floor(cy) - R - 1; y <= Math.ceil(cy) + R + 1; y++) {
    const d = Math.hypot(x - cx, y - cy);
    if (Math.abs(d - R) <= 0.7 && y > cy - 5) s.put(x, y, z, GOLD).put(x, y, z - 1, GOLD_D);
  }
  for (let k = 0; k < 12; k++) {
    const a = (k * Math.PI) / 6 + Math.PI / 2;
    if (Math.sin(a) < -0.5) continue; // none under the chin
    const len = k === 0 ? 9 : k % 2 === 0 ? 4.5 : 3;
    for (let r = R + 0.5; r <= R + len; r += 0.3) {
      const x = Math.round(cx + Math.cos(a) * r), y = Math.round(cy + Math.sin(a) * r);
      s.put(x, y, z, r > R + len - 1 ? GOLD_L : GOLD);
      if (r < R + 2) s.put(x + Math.round(-Math.sin(a)), y + Math.round(Math.cos(a)), z, GOLD_D);
    }
  }
}
// Heavy stepped pauldron over the shoulder (arm frame; `outer` +1 for the left), gold-edged.
function inquisitorPauldron(f, s, outer) {
  for (const [dy, w] of [[0, 2], [-3, 3], [-6, 3]]) {
    const y0 = f.y1 - 3 + dy, y1 = f.y1 + 1 + dy - (dy ? 1 : 0);
    s.box(f.x0 - w, y0, f.z0 - w, f.x1 + w, y1, f.z1 + w, ROBE_L);
    s.remove(f.x0 - w + 1, y0, f.z0 - w + 1, f.x1 + w - 1, y1 - 1, f.z1 + w - 1);
    s.box(f.x0 - w, y0, f.z0 - w, f.x1 + w, y0, f.z1 + w, GOLD);
    s.remove(f.x0 - w + 1, y0, f.z0 - w + 1, f.x1 + w - 1, y0, f.z1 + w - 1);
  }
  s.box(f.x0 - 2, f.y1 + 2, f.z0 - 2, f.x1 + 2, f.y1 + 2, f.z1 + 2, ROBE_L); // the dome
  const ox = outer > 0 ? f.x1 + 3 : f.x0 - 3;
  s.put(ox, f.y1 - 5, (f.z0 + f.z1) >> 1, GOLD_L).put(ox, f.y1 - 5, ((f.z0 + f.z1) >> 1) + 1, GOLD_L); // rivets
}
// Plated forearm with a gold rim at the wrist.
function inquisitorVambrace(f, s) {
  s.box(f.x0 - 1, f.y0, f.z0 - 1, f.x1 + 1, f.y1 - 1, f.z1 + 1, ROBE_L);
  s.box(f.x0 - 1, f.y0, f.z0 - 1, f.x1 + 1, f.y0, f.z1 + 1, GOLD);
  s.box(f.x0 - 1, f.y0 + 4, f.z1 + 1, f.x1 + 1, f.y0 + 4, f.z1 + 1, GOLD_D);
}
// A war belt with a big square gold buckle over the cult robe (torso frame).
function inquisitorBelt(f, s) {
  const [a, b] = mid(f);
  s.box(f.x0 - 3, f.y0 + 1, f.z0 - 2, f.x1 + 3, f.y0 + 3, f.z1 + 2, ROBE_L);
  s.remove(f.x0 - 2, f.y0 + 1, f.z0 - 1, f.x1 + 2, f.y0 + 3, f.z1 + 1);
  s.box(f.x0 - 3, f.y0 + 3, f.z0 - 2, f.x1 + 3, f.y0 + 3, f.z1 + 2, GOLD_D);
  s.remove(f.x0 - 2, f.y0 + 3, f.z0 - 1, f.x1 + 2, f.y0 + 3, f.z1 + 1);
  s.box(a - 2, f.y0, f.z1 + 3, b + 2, f.y0 + 4, f.z1 + 3, GOLD).box(a - 1, f.y0 + 1, f.z1 + 3, b + 1, f.y0 + 3, f.z1 + 3, VOID).box(a, f.y0 + 2, f.z1 + 4, b, f.y0 + 2, f.z1 + 4, GOLD_L);
  s.box(f.x0 - 2, f.y1 - 1, f.z0 - 2, f.x1 + 2, f.y1 + 1, f.z0 - 2, ROBE); // a short cape over the back
}
// The ceremonial sword: a long dark blade edged in gold with a gold fuller line and
// marks, a cross-guard with a sun stud, a wrapped grip and a ring pommel (fist frame).
function inquisitorSword(f, s) {
  const len = 26;
  s.box(2, 1, f.z0 - 4, 3, 4, f.z0 - 3, GOLD).box(2, 2, f.z0 - 4, 3, 3, f.z0 - 4, VOID); // ring pommel
  s.box(2, 2, f.z0 - 2, 3, 3, f.z1, ROPE_D); // grip
  s.box(2, -3, f.z1 + 1, 3, 8, f.z1 + 2, GOLD).box(2, 2, f.z1 + 1, 3, 3, f.z1 + 2, GOLD_L); // guard and its stud
  s.box(2, -1, f.z1 + 3, 3, 6, f.z1 + 2 + len, VOID); // dark blade, flat, edges up and down
  s.box(2, -1, f.z1 + 3, 3, 0, f.z1 + 2 + len, GOLD).box(2, 5, f.z1 + 3, 3, 6, f.z1 + 2 + len, GOLD); // gold edges
  s.box(2, -1, f.z1 + 3, 3, -1, f.z1 + 2 + len, GOLD_D);
  s.box(2, 2, f.z1 + 4, 3, 3, f.z1 + len - 4, PANEL);
  for (const z of [f.z1 + 7, f.z1 + 14]) s.box(2, 2, z, 3, 3, z + 1, GOLD); // marks
  for (let k = 0; k < 4; k++) s.box(2, 0 + k, f.z1 + 3 + len + k, 3, 5 - k, f.z1 + 3 + len + k, k === 3 ? GOLD_L : k ? VOID : GOLD_D); // tapered point
}
function acolyteSleeve(f, s) {
  s.box(f.x0 - 2, f.y0 - 1, f.z0 - 2, f.x1 + 2, f.y1 + 1, f.z1 + 2, ROBE);
  s.box(f.x0 - 2, f.y1 + 1, f.z0 - 2, f.x1 + 2, f.y1 + 1, f.z1 + 2, ROBE_L);
  s.box(f.x0 - 2, f.y0 - 1, f.z0 - 2, f.x0 - 2, f.y1, f.z0 - 2, ROBE_D).box(f.x1 + 2, f.y0 - 1, f.z0 - 2, f.x1 + 2, f.y1, f.z0 - 2, ROBE_D);
  s.box(f.x0 - 2, f.y0 + 2, f.z1 + 2, f.x1 + 2, f.y0 + 2, f.z1 + 2, GOLD_D); // seam
}
function acolyteCuff(f, s) {
  for (let y = f.y0 - 4; y <= f.y1; y++) {
    const w = y < f.y0 ? 3 : y < f.y0 + 4 ? 2 : 1; // wider at the mouth
    s.box(f.x0 - w, y, f.z0 - w, f.x1 + w, y, f.z1 + w, ROBE);
    s.remove(f.x0, y, f.z0, f.x1, y, f.z1);
  }
  for (let y = f.y0 - 12; y < f.y0 - 4; y++) { // the drape hanging behind
    const w = Math.max(0, 3 - Math.floor((f.y0 - 4 - y) / 3));
    s.box(f.x0 - w, y, f.z0 - 3, f.x1 + w, y, f.z0 - 3, ROBE);
  }
  for (const v of [...s.cells.values()]) {
    const lowest = !s.cells.has(`${v[0]},${v[1] - 1},${v[2]}`);
    if (lowest && v[1] <= f.y0 - 2) s.put(v[0], v[1], v[2], GOLD);
    else if (v[1] === f.y0 - 3 && (v[0] + v[2]) % 3 !== 0) s.put(v[0], v[1], v[2], GOLD_D);
  }
  s.box(f.x0 - 1, f.y0 + 4, f.z0 - 1, f.x0 - 1, f.y1, f.z0 - 1, ROBE_D);
}
// Fingers from the fist's bottom, splayed across X, curling forward; `inner` is the
// side of the thumb (+1 for the left hand).
function claws(f, s, inner) {
  const xs = [f.x0, f.x0 + 1, f.x1 - 1, f.x1].map((x, i) => x + (i - 1.5) * 0.8);
  xs.forEach((x0, i) => {
    const len = i === 1 || i === 2 ? 6 : 5;
    for (let t = 0; t <= len; t++) {
      const x = Math.round(x0 + (i - 1.5) * t * 0.25), y = f.y0 - 1 - t, z = f.z1 - 1 + Math.floor((t * t) / 9);
      s.put(x, y, z, t >= len - 1 ? GOLD : t === 0 ? CLAW_D : CLAW);
    }
  });
  const tx = inner > 0 ? f.x1 + 1 : f.x0 - 1; // thumb
  for (let t = 0; t <= 3; t++) s.put(tx + inner * Math.floor(t / 2), f.y0 + 1 - t, f.z1 + Math.floor(t / 2), t === 3 ? GOLD : CLAW);
  s.box(f.x0, f.y0, f.z1 + 1, f.x1, f.y1 - 1, f.z1 + 1, CLAW_D); // knuckles
}

// --- Table -------------------------------------------------------------------------------
const PIECES = {
  ...GEAR, ...MONSTER,
  vaelthar_mane: VAEL.mane, vaelthar_robe: VAEL.robe,
  inquisitor_hood: { frame: HEAD, tag: "monster", palette: ACOLYTE_KIT, build: (f, s) => inquisitorHood(f, s) },
  inquisitor_belt: { frame: TORSO, tag: "monster", palette: ACOLYTE_KIT, build: (f, s) => inquisitorBelt(f, s) },
  inquisitor_pauldron_left: { frame: ARM_L, tag: "monster", palette: ACOLYTE_KIT, build: (f, s) => inquisitorPauldron(f, s, 1) },
  inquisitor_pauldron_right: { frame: ARM_R, tag: "monster", palette: ACOLYTE_KIT, build: (f, s) => inquisitorPauldron(f, s, -1) },
  inquisitor_vambrace_left: { frame: FORE_L, tag: "monster", palette: ACOLYTE_KIT, build: (f, s) => inquisitorVambrace(f, s) },
  inquisitor_vambrace_right: { frame: FORE_R, tag: "monster", palette: ACOLYTE_KIT, build: (f, s) => inquisitorVambrace(f, s) },
  weapon_inquisitor_sword: { frame: HAND_R, tag: "weapon", palette: ACOLYTE_KIT, build: (f, s) => inquisitorSword(f, s) },
  nhazar_head: { frame: HEAD, tag: "monster", palette: NHAZ_KIT, build: (f, s) => nhazarHead(f, s) },
  nhazar_collar: { frame: TORSO, tag: "monster", palette: NHAZ_KIT, build: (f, s) => nhazarCollar(f, s) },
  nhazar_chains_left: { frame: FORE_L, tag: "monster", palette: NHAZ_KIT, build: (f, s) => nhazarChains(f, s, 1) },
  nhazar_chains_right: { frame: FORE_R, tag: "monster", palette: NHAZ_KIT, build: (f, s) => nhazarChains(f, s, -1) },
  vaelthar_sleeve_left: { frame: ARM_L, tag: "monster", palette: VAEL_KIT, build: (f, s) => vaelSleeve(f, s) },
  vaelthar_sleeve_right: { frame: ARM_R, tag: "monster", palette: VAEL_KIT, build: (f, s) => vaelSleeve(f, s) },
  vaelthar_tentacles_left: { frame: ARM_L, tag: "monster", palette: VAEL_KIT, build: (f, s) => tentacles(f, s, 1) },
  vaelthar_tentacles_right: { frame: ARM_R, tag: "monster", palette: VAEL_KIT, build: (f, s) => tentacles(f, s, -1) },
};
for (const [id, def] of Object.entries(HAIR)) PIECES[id] = { frame: HEAD, tag: def.tag, build: def.build };
for (const [id, build] of Object.entries(BEARDS)) PIECES[id] = { frame: HEAD, tag: "beard", build };
for (const [id, build] of Object.entries(WEAPONS)) {
  PIECES[id] = { frame: id === "weapon_bow" || id === "weapon_dagger_left" ? HAND_L : HAND_R, tag: "weapon", palette: KIT, build: (f, s) => build(f, s) };
}

const [outDir, jsonPath] = process.argv.slice(2);
if (!outDir || !jsonPath) {
  console.error("usage: node make_pieces.mjs <pieces out dir> <pieces.json path>");
  process.exit(1);
}
for (const f of fs.readdirSync(outDir)) if (f.endsWith(".vox")) fs.unlinkSync(`${outDir}/${f}`);
const table = {};
for (const [name, def] of Object.entries(PIECES)) {
  const shape = new Shape();
  def.build(def.frame, shape);
  write(`${outDir}/${name}.vox`, shape.size(), shape.voxels(), def.palette ?? KIT);
  const m = shape.min();
  table[name] = {
    file: `res://assets/characters/pieces/${name}.vox`,
    part: def.frame.part,
    offset: def.frame.origin.map((o, i) => o + m[i]),
    tag: def.tag,
    hides: def.hides ?? [],
  };
}
fs.writeFileSync(jsonPath, JSON.stringify(table, null, "\t") + "\n");
console.log(`wrote ${Object.keys(table).length} pieces and ${jsonPath}`);
