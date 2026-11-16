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
  weapon_dagger_right(f, s) {
    s.box(2, 2, f.z0 - 1, 3, 3, f.z1, LEATHER);
    s.box(2, 0, f.z1 + 1, 3, 5, f.z1 + 1, S);
    s.box(2, 2, f.z1 + 2, 2, 4, f.z1 + 8, STEEL_D).box(2, 4, f.z1 + 2, 2, 4, f.z1 + 8, STEEL);
    s.box(2, 3, f.z1 + 9, 2, 4, f.z1 + 9, STEEL).put(2, 4, f.z1 + 10, STEEL_L);
  },
};
WEAPONS.weapon_dagger_left = WEAPONS.weapon_dagger_right;

// --- Monster pieces (data/monsters "look") ----------------------------------------------
const BONE = 22;
const MONSTER_KIT = { ...KIT, [BONE]: "#e6dfcc" };
const MONSTER = {
  goblin_ears: {
    frame: HEAD, tag: "monster",
    build(f, s) {
      for (const side of [-1, 1]) {
        const x0 = side < 0 ? f.x0 - 1 : f.x1 + 1;
        for (let k = 0; k < 6; k++) s.box(x0 + side * k, f.y0 + 4 + Math.floor(k / 2), f.z0 + 3, x0 + side * k, f.y0 + 6 + Math.floor(k / 2), f.z0 + 4, H);
      }
    },
  },
  goblin_knife: { frame: HAND_R, tag: "monster", palette: MONSTER_KIT, build: (f, s) => WEAPONS.weapon_dagger_right(f, s) },
  orc_tusks: {
    frame: HEAD, tag: "monster", palette: MONSTER_KIT,
    build(f, s) {
      for (const x of [f.x0 + 1, f.x1 - 1]) s.box(x, f.y0, f.z1 + 1, x, f.y0 + 3, f.z1 + 1, BONE);
    },
  },
  orc_crown: {
    frame: HEAD, tag: "monster", palette: MONSTER_KIT,
    build(f, s) {
      s.box(f.x0, f.y1 + 1, f.z0, f.x1, f.y1 + 3, f.z1, GOLD);
      s.remove(f.x0 + 1, f.y1 + 1, f.z0 + 1, f.x1 - 1, f.y1 + 3, f.z1 - 1);
      for (let x = f.x0; x <= f.x1; x += 2) s.box(x, f.y1 + 4, f.z1, x, f.y1 + 5, f.z1, GOLD).box(x, f.y1 + 4, f.z0, x, f.y1 + 5, f.z0, GOLD);
      const [a, b] = mid(f);
      s.box(a, f.y1 + 2, f.z1 + 1, b, f.y1 + 3, f.z1 + 1, GEM);
    },
  },
  orc_axe: {
    frame: HAND_R, tag: "monster", palette: MONSTER_KIT,
    build(f, s) {
      s.box(2, 2, f.z0 - 2, 3, 3, f.z1 + 22, WOOD);
      for (let k = 0; k < 8; k++) {
        const half = 3 + Math.floor(k / 2);
        s.box(2, 4 + k, f.z1 + 18 - half, 2, 4 + k, f.z1 + 18 + half, k === 7 ? STEEL_L : STEEL);
        s.box(2, 1 - k, f.z1 + 18 - half, 2, 1 - k, f.z1 + 18 + half, k === 7 ? STEEL_L : STEEL);
      }
    },
  },
};

// --- Table -------------------------------------------------------------------------------
const PIECES = { ...GEAR, ...MONSTER };
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
