// Generates the voxel pieces (.vox) of the characters and data/characters/pieces.json.
//   node tools/art/make_pieces.mjs <pieces out dir> <pieces.json path>
// Coordinates are Godot axes, in voxels; the character faces +Z. Each piece is drawn
// in its part's frame, where the part occupies x0..x1, y0..y1, z0..z1 (HumanRig, see
// make_humans.mjs); `origin` turns frame voxels into voxels from the part's pivot.
import fs from "node:fs";
import { write, Shape, TINT_HAIR, TINT_PRIMARY, TINT_SECONDARY, GLOW } from "./vox.mjs";

const H = TINT_HAIR, P = TINT_PRIMARY, S = TINT_SECONDARY;
// Head x -3..2, y 0..5, z -3..2 from its pivot; the face is on z1.
const HEAD = { x0: 1, x1: 6, y0: 3, y1: 8, z0: 2, z1: 7, part: "head", origin: [-4, -3, -5] };
// Torso x -3..2, y 0..5, z -2..1 (shoulders x -4..3 on y 4..5).
const TORSO = { x0: 1, x1: 6, y0: 1, y1: 6, z0: 1, z1: 4, part: "torso", origin: [-4, -1, -3] };
// Arms x -1..0, y -5..0, z -1..0. The outer side is +X for the left arm.
const ARM_L = { x0: 1, x1: 2, y0: 1, y1: 6, z0: 1, z1: 2, part: "arm_left", origin: [-2, -6, -2] };
const ARM_R = { ...ARM_L, part: "arm_right" };
// Fists x -1..0, y -1..0, z -1..0; weapons stick out forward (+Z).
const HAND_L = { x0: 1, x1: 2, y0: 1, y1: 2, z0: 1, z1: 2, part: "hand_left", origin: [-2, -2, -2] };
const HAND_R = { ...HAND_L, part: "hand_right" };

// The two middle columns of a frame (the body is 6 wide, so x0 + 2 .. x0 + 3).
const mid = (f) => [f.x0 + Math.floor((f.x1 - f.x0) / 2), f.x0 + Math.floor((f.x1 - f.x0) / 2) + 1];

// Fixed colors of weapons and outfits.
const STEEL = 40, WOOD = 41, GOLD = 42, LEATHER = 43, DARKSTEEL = 44, STRING = 45, CLOTH = 46, CHAIN = 47;
const KIT = {
  [STEEL]: "#cfd5dc", [WOOD]: "#6b4a2b", [GOLD]: "#d8b24a", [LEATHER]: "#5a3d24",
  [DARKSTEEL]: "#7d858f", [STRING]: "#e8e2cf", [CLOTH]: "#efe7d4", [CHAIN]: "#9aa2ab", [GLOW]: "#9fe0ff",
};

// --- Hair (cap + extras) and beards --------------------------------------------------
// Caps are tagged hair_cap (only hoods hide them); long extras are tagged hair.
function cap(f, s) {
  s.box(f.x0, f.y1 + 1, f.z0, f.x1, f.y1 + 1, f.z1, H); // top
  s.box(f.x0, f.y0 + 2, f.z0 - 1, f.x1, f.y1 + 1, f.z0 - 1, H); // back, down to the ears
  s.box(f.x0 - 1, f.y1 - 1, f.z0, f.x0 - 1, f.y1, f.z1 - 2, H); // temples
  s.box(f.x1 + 1, f.y1 - 1, f.z0, f.x1 + 1, f.y1, f.z1 - 2, H);
  s.box(f.x0, f.y1, f.z1 + 1, f.x0 + 2, f.y1, f.z1 + 1, H); // a lock of fringe on one side
}

const HAIR = {
  hair_short: { tag: "hair_cap", build: (f, s) => cap(f, s) },
  // Bob: a cap that falls straight down the sides and back to the jaw.
  hair_bob: {
    tag: "hair_cap",
    build(f, s) {
      cap(f, s);
      s.box(f.x0, f.y0, f.z0 - 1, f.x1, f.y1, f.z0 - 1, H);
      s.box(f.x0 - 1, f.y0, f.z0, f.x0 - 1, f.y1, f.z1 - 1, H);
      s.box(f.x1 + 1, f.y0, f.z0, f.x1 + 1, f.y1, f.z1 - 1, H);
      s.box(f.x0, f.y1, f.z1 + 1, f.x1, f.y1, f.z1 + 1, H); // full fringe
    },
  },
  // Swept back: tall at the front, combed backwards, no fringe.
  hair_swept: {
    tag: "hair_cap",
    build(f, s) {
      cap(f, s);
      s.remove(f.x0, f.y1, f.z1 + 1, f.x1, f.y1, f.z1 + 1);
      s.box(f.x0, f.y1 + 2, f.z1 - 2, f.x1, f.y1 + 2, f.z1, H);
      s.box(f.x0 + 1, f.y1 + 2, f.z0, f.x1 - 1, f.y1 + 2, f.z1 - 3, H);
    },
  },
  // Long hair: a curtain down the back past the shoulders.
  hair_long: {
    tag: "hair",
    build(f, s) {
      s.box(f.x0 - 1, f.y0 - 3, f.z0 - 2, f.x1 + 1, f.y1, f.z0 - 2, H);
      s.box(f.x0, f.y0 - 4, f.z0 - 2, f.x1, f.y0 - 4, f.z0 - 2, H);
    },
  },
  // Ponytail tied high at the back, hanging to the shoulders.
  hair_ponytail: {
    tag: "hair",
    build(f, s) {
      const [a, b] = mid(f);
      s.box(a, f.y1 - 1, f.z0 - 2, b, f.y1, f.z0 - 2, H); // knot
      s.box(a, f.y0 - 2, f.z0 - 3, b, f.y1 - 1, f.z0 - 3, H); // tail
    },
  },
  // Round bun on the top-back of the head.
  hair_bun: {
    tag: "hair",
    build(f, s) {
      const [a, b] = mid(f);
      s.box(a - 1, f.y1 - 1, f.z0 - 3, b + 1, f.y1 + 1, f.z0 - 2, H); // bun at the back of the head
      s.box(a, f.y1 + 2, f.z0 - 3, b, f.y1 + 2, f.z0 - 2, H);
    },
  },
  // Crest along the middle of a shaved head, down the back.
  hair_mohawk: {
    tag: "hair_cap",
    build(f, s) {
      const [a, b] = mid(f);
      s.box(a, f.y1 + 1, f.z0, b, f.y1 + 1, f.z1 + 1, H);
      s.box(a, f.y1 + 2, f.z0, b, f.y1 + 2, f.z1, H);
      s.box(a, f.y1 + 3, f.z0 + 2, b, f.y1 + 3, f.z1 - 1, H);
      s.box(a, f.y0 + 2, f.z0 - 1, b, f.y1, f.z0 - 1, H);
    },
  },
};

// Beards sit in front of the jaw (the mouth is on y0, the nose on y0 + 1).
const BEARDS = {
  beard_mustache(f, s) {
    s.box(f.x0 + 1, f.y0, f.z1 + 1, f.x1 - 1, f.y0, f.z1 + 1, H);
    s.put(f.x0 + 1, f.y0 - 1, f.z1 + 1, H).put(f.x1 - 1, f.y0 - 1, f.z1 + 1, H);
  },
  beard_goatee(f, s) {
    const [a, b] = mid(f);
    s.box(a, f.y0 - 2, f.z1 - 1, b, f.y0 - 1, f.z1 + 1, H);
    s.box(a - 1, f.y0, f.z1 + 1, b + 1, f.y0, f.z1 + 1, H);
  },
  beard_short(f, s) {
    s.box(f.x0, f.y0 - 1, f.z0 + 2, f.x1, f.y0 - 1, f.z1 + 1, H); // under the jaw
    s.box(f.x0 - 1, f.y0, f.z0 + 2, f.x0 - 1, f.y0 + 2, f.z1, H); // sideburns
    s.box(f.x1 + 1, f.y0, f.z0 + 2, f.x1 + 1, f.y0 + 2, f.z1, H);
    s.box(f.x0, f.y0, f.z1 + 1, f.x0, f.y0, f.z1 + 1, H).box(f.x1, f.y0, f.z1 + 1, f.x1, f.y0, f.z1 + 1, H);
  },
  beard_full(f, s) {
    BEARDS.beard_short(f, s);
    BEARDS.beard_mustache(f, s);
    s.box(f.x0, f.y0 - 3, f.z1 - 1, f.x1, f.y0 - 2, f.z1 + 1, H);
    s.remove(f.x0, f.y0 - 3, f.z1 - 1, f.x0, f.y0 - 3, f.z1 + 1).remove(f.x1, f.y0 - 3, f.z1 - 1, f.x1, f.y0 - 3, f.z1 + 1);
  },
};

// --- Class gear ------------------------------------------------------------------------

// Rounded steel shoulder plate with a trim row; `outer` is +1 (left arm) or -1.
function pauldron(f, s, outer) {
  const out = outer > 0 ? f.x1 + 1 : f.x0 - 1;
  const inner = outer > 0 ? f.x0 : f.x1;
  const xa = Math.min(inner, out), xb = Math.max(inner, out);
  s.box(xa, f.y1 - 1, f.z0 - 1, xb, f.y1 + 1, f.z1 + 1, P); // shell
  s.box(out + outer, f.y1 - 2, f.z0 - 1, out + outer, f.y1, f.z1 + 1, P); // outer flap
  s.box(xa, f.y1 - 2, f.z0 - 1, xb, f.y1 - 2, f.z1 + 1, S); // trim
}

const GEAR = {
  pauldron_left: { frame: ARM_L, tag: "armor", build: (f, s) => pauldron(f, s, 1) },
  pauldron_right: { frame: ARM_R, tag: "armor", build: (f, s) => pauldron(f, s, -1) },
  // Wide-brimmed pointed hat with a band, sitting on top of the hair cap.
  hat_mage: {
    frame: HEAD, tag: "headgear", hides: ["hair"],
    build(f, s) {
      const y = f.y1 + 2;
      s.box(f.x0 - 3, y, f.z0 - 3, f.x1 + 3, y, f.z1 + 3, P);
      for (const [x, z] of [[f.x0 - 3, f.z0 - 3], [f.x1 + 3, f.z0 - 3], [f.x0 - 3, f.z1 + 3], [f.x1 + 3, f.z1 + 3]]) s.remove(x, y, z, x, y, z);
      s.box(f.x0, y + 1, f.z0, f.x1, y + 1, f.z1, S);
      s.box(f.x0, y + 2, f.z0, f.x1, y + 3, f.z1, P);
      s.box(f.x0 + 1, y + 4, f.z0 + 1, f.x1 - 1, y + 5, f.z1 - 1, P);
      const [a, b] = mid(f);
      s.box(a, y + 6, f.z0 + 2, b, y + 7, f.z1 - 2, P);
      s.box(a, y + 8, f.z0 + 1, b, y + 8, f.z0 + 2, P);
    },
  },
  // Archer's hood: a shell over the top, back and sides, open face, short cape.
  hood_archer: {
    frame: HEAD, tag: "headgear", hides: ["hair", "hair_cap"],
    build(f, s) {
      s.box(f.x0 - 1, f.y1 + 1, f.z0 - 1, f.x1 + 1, f.y1 + 1, f.z1 + 1, P); // top and brim
      s.box(f.x0 - 1, f.y0, f.z0 - 1, f.x1 + 1, f.y1 + 1, f.z0 - 1, P); // back
      s.box(f.x0 - 1, f.y0, f.z0, f.x0 - 1, f.y1 + 1, f.z1, P); // left
      s.box(f.x1 + 1, f.y0, f.z0, f.x1 + 1, f.y1 + 1, f.z1, P); // right
      s.box(f.x0 - 1, f.y0 - 1, f.z0 - 2, f.x1 + 1, f.y0, f.z1 - 1, S); // cape collar
      s.remove(f.x0, f.y0 - 1, f.z0, f.x1, f.y0, f.z1 - 1); // neck hole
      const [a, b] = mid(f);
      s.box(a, f.y1 - 1, f.z0 - 2, b, f.y1 + 2, f.z0 - 2, P); // point
    },
  },
  // Assassin's scarf over mouth and nose, knotted at the back.
  mask_assassin: {
    frame: HEAD, tag: "headgear",
    build(f, s) {
      s.box(f.x0, f.y0, f.z1 + 1, f.x1, f.y0 + 1, f.z1 + 2, P); // front (over the nose)
      s.box(f.x0 - 1, f.y0, f.z0, f.x0 - 1, f.y0 + 1, f.z1 + 1, P);
      s.box(f.x1 + 1, f.y0, f.z0, f.x1 + 1, f.y0 + 1, f.z1 + 1, P);
      s.box(f.x0 - 1, f.y0, f.z0 - 1, f.x1 + 1, f.y0 + 1, f.z0 - 1, P);
      const [a, b] = mid(f);
      s.box(a, f.y0 - 3, f.z0 - 2, b, f.y0, f.z0 - 2, S); // knot tails
    },
  },
  // Cleric's lowered hood resting on the shoulders behind the neck.
  hood_cleric: {
    frame: TORSO, tag: "headgear",
    build(f, s) {
      s.box(f.x0, f.y1, f.z0 - 1, f.x1, f.y1 + 1, f.z0, P);
      s.box(f.x0 + 1, f.y1 - 3, f.z0 - 1, f.x1 - 1, f.y1 - 1, f.z0 - 1, P); // drape
      s.box(f.x0, f.y1 + 1, f.z0 + 1, f.x1, f.y1 + 1, f.z0 + 1, S); // lining edge
    },
  },
  // Outfits: details over the plain shirt (torso frame, front is z1 + 1).
  outfit_warrior: {
    frame: TORSO, tag: "outfit", palette: KIT,
    build(f, s) {
      s.box(f.x0, f.y0 + 1, f.z1 + 1, f.x1, f.y1 - 1, f.z1 + 1, STEEL); // breastplate
      s.box(f.x0, f.y0 + 1, f.z1 + 1, f.x0, f.y1 - 1, f.z1 + 1, DARKSTEEL).box(f.x1, f.y0 + 1, f.z1 + 1, f.x1, f.y1 - 1, f.z1 + 1, DARKSTEEL);
      s.box(f.x0, f.y0 + 1, f.z1 + 1, f.x1, f.y0 + 1, f.z1 + 1, DARKSTEEL); // rims
      const [a, b] = mid(f);
      s.box(a, f.y0 + 2, f.z1 + 2, b, f.y1 - 1, f.z1 + 2, STEEL); // ridge down the middle
      s.box(f.x0, f.y0, f.z1 + 1, f.x1, f.y0, f.z1 + 1, CHAIN); // mail below it
    },
  },
  outfit_cleric: {
    frame: TORSO, tag: "outfit", palette: KIT,
    build(f, s) {
      const [a, b] = mid(f);
      s.box(a - 1, f.y0, f.z1 + 1, a - 1, f.y1 - 1, f.z1 + 1, S); // stole
      s.box(b + 1, f.y0, f.z1 + 1, b + 1, f.y1 - 1, f.z1 + 1, S);
      s.box(a, f.y1 - 3, f.z1 + 1, b, f.y1 - 3, f.z1 + 1, GOLD); // holy sign
      s.box(a, f.y1 - 4, f.z1 + 1, a, f.y1 - 2, f.z1 + 1, GOLD);
    },
  },
  outfit_mage: {
    frame: TORSO, tag: "outfit", palette: KIT,
    build(f, s) {
      const [a] = mid(f);
      s.box(a, f.y0, f.z1 + 1, a + 1, f.y1 - 1, f.z1 + 1, S); // golden placket
      s.box(f.x0, f.y0, f.z1 + 1, f.x1, f.y0, f.z1 + 1, S); // hem trim
      s.box(f.x0 - 1, f.y0 - 3, f.z0 - 1, f.x1 + 1, f.y0, f.z1 + 1, P); // robe skirt over the hips
    },
  },
  outfit_archer: {
    frame: TORSO, tag: "outfit", palette: KIT,
    build(f, s) {
      s.box(f.x0, f.y0, f.z1 + 1, f.x1, f.y1 - 1, f.z1 + 1, LEATHER); // jerkin
      for (let i = 0; i <= f.y1 - f.y0; i++) s.put(f.x0 + i, f.y1 - i, f.z1 + 2, WOOD); // quiver strap
      s.box(f.x1 - 2, f.y0 + 1, f.z0 - 1, f.x1 - 1, f.y1 + 2, f.z0 - 1, LEATHER); // quiver
      s.box(f.x1 - 2, f.y1 + 3, f.z0 - 1, f.x1 - 1, f.y1 + 3, f.z0 - 1, STRING); // fletching
    },
  },
  outfit_assassin: {
    frame: TORSO, tag: "outfit", palette: KIT,
    build(f, s) {
      for (let i = 0; i <= f.y1 - f.y0 - 1; i++) { // crossed straps
        s.put(f.x0 + i, f.y1 - 1 - i, f.z1 + 1, LEATHER).put(f.x1 - i, f.y1 - 1 - i, f.z1 + 1, LEATHER);
      }
      s.box(f.x0, f.y0, f.z1 + 1, f.x1, f.y0, f.z1 + 1, S); // red sash
      s.box(f.x0 - 1, f.y0, f.z0 - 1, f.x0 - 1, f.y0 - 2, f.z0, S); // sash tails
    },
  },
  outfit_villager: {
    frame: TORSO, tag: "outfit", palette: KIT,
    build(f, s) {
      const [a, b] = mid(f);
      s.box(a, f.y1 - 2, f.z1 + 1, b, f.y1 - 1, f.z1 + 1, CLOTH); // open collar of a linen shirt
      s.box(f.x0, f.y0, f.z1 + 1, f.x1, f.y0, f.z1 + 1, LEATHER); // belt
    },
  },
};

// --- Weapons (fist frame; blades point forward) --------------------------------------
const WEAPONS = {
  weapon_sword(f, s, mat = { blade: STEEL, guard: S, grip: LEATHER, pommel: GOLD }, len = 8) {
    s.put(1, 1, f.z0 - 1, mat.pommel).box(1, 1, f.z0, 1, 2, f.z1, mat.grip);
    s.box(1, 0, f.z1 + 1, 1, 3, f.z1 + 1, mat.guard);
    s.box(1, 1, f.z1 + 2, 1, 2, f.z1 + 1 + len, mat.blade);
    s.put(1, 1, f.z1 + 2 + len, mat.blade);
  },
  weapon_wood_sword(f, s) {
    WEAPONS.weapon_sword(f, s, { blade: WOOD, guard: WOOD, grip: LEATHER, pommel: WOOD }, 6);
  },
  weapon_mace(f, s) {
    s.box(1, 1, f.z0 - 1, 1, 2, f.z1 + 5, WOOD); // haft
    s.box(0, 0, f.z1 + 6, 2, 3, f.z1 + 8, DARKSTEEL); // head
    for (const [y, x] of [[-1, 1], [4, 1]]) s.box(x, y, f.z1 + 6, x, y, f.z1 + 8, STEEL); // flanges
    s.box(-1, 1, f.z1 + 6, -1, 2, f.z1 + 8, STEEL).box(3, 1, f.z1 + 6, 3, 2, f.z1 + 8, STEEL);
    s.box(1, 1, f.z1 + 9, 1, 2, f.z1 + 9, GOLD);
  },
  // An upright staff (it stands on the ground beside the mage) crowned by a crystal.
  weapon_staff(f, s) {
    s.box(1, -6, f.z1 + 1, 1, 10, f.z1 + 1, WOOD);
    s.box(0, 9, f.z1 + 1, 2, 9, f.z1 + 1, GOLD).put(0, 10, f.z1 + 1, GOLD).put(2, 10, f.z1 + 1, GOLD);
    s.box(1, 11, f.z1, 1, 13, f.z1 + 2, GLOW).box(0, 12, f.z1 + 1, 2, 12, f.z1 + 1, GLOW);
  },
  // An upright longbow in the left fist, limbs curving back toward the archer.
  weapon_bow(f, s) {
    s.box(1, -1, f.z1 + 1, 1, 4, f.z1 + 1, WOOD); // grip, just in front of the fist
    s.box(1, 5, f.z1, 1, 6, f.z1, WOOD).box(1, 7, f.z1 - 1, 1, 8, f.z1 - 1, WOOD).put(1, 9, f.z1 - 2, WOOD);
    s.box(1, -3, f.z1, 1, -2, f.z1, WOOD).box(1, -5, f.z1 - 1, 1, -4, f.z1 - 1, WOOD).put(1, -6, f.z1 - 2, WOOD);
    s.box(1, -5, f.z1 - 3, 1, 8, f.z1 - 3, STRING);
  },
  weapon_dagger_right(f, s) {
    s.box(1, 1, f.z0, 1, 2, f.z1, LEATHER);
    s.box(1, 0, f.z1 + 1, 1, 3, f.z1 + 1, S);
    s.box(1, 1, f.z1 + 2, 1, 2, f.z1 + 5, DARKSTEEL).put(1, 2, f.z1 + 6, DARKSTEEL);
  },
};
WEAPONS.weapon_dagger_left = WEAPONS.weapon_dagger_right;

// --- Monster pieces (data/monsters "look") -------------------------------------------
const BONE = 22, GEM = 23, EDGE = 25;
const MONSTER_KIT = { ...KIT, [BONE]: "#e6dfcc", [GEM]: "#c0281c", [EDGE]: "#d5dae0" };
const MONSTER = {
  goblin_ears: {
    frame: HEAD, tag: "monster",
    build(f, s) {
      for (const side of [-1, 1]) {
        const x0 = side < 0 ? f.x0 - 1 : f.x1 + 1;
        const at = (dx) => x0 + side * dx;
        s.box(Math.min(at(0), at(1)), f.y0 + 2, f.z0 + 2, Math.max(at(0), at(1)), f.y0 + 4, f.z0 + 3, H);
        s.put(at(2), f.y0 + 4, f.z0 + 2, H).put(at(3), f.y0 + 5, f.z0 + 2, H);
      }
    },
  },
  goblin_knife: { frame: HAND_R, tag: "monster", palette: MONSTER_KIT, build: (f, s) => WEAPONS.weapon_dagger_right(f, s) },
  orc_tusks: {
    frame: HEAD, tag: "monster", palette: MONSTER_KIT,
    build(f, s) {
      for (const x of [f.x0 + 1, f.x1 - 1]) s.box(x, f.y0, f.z1 + 1, x, f.y0 + 1, f.z1 + 1, BONE);
    },
  },
  orc_crown: {
    frame: HEAD, tag: "monster", palette: MONSTER_KIT,
    build(f, s) {
      s.box(f.x0, f.y1 + 1, f.z0, f.x1, f.y1 + 2, f.z1, S);
      s.remove(f.x0 + 1, f.y1 + 1, f.z0 + 1, f.x1 - 1, f.y1 + 2, f.z1 - 1);
      for (const [x, z] of [[f.x0, f.z0], [f.x1, f.z0], [f.x0, f.z1], [f.x1, f.z1]]) s.box(x, f.y1 + 3, z, x, f.y1 + 4, z, S);
      const [a, b] = mid(f);
      s.box(a, f.y1 + 1, f.z1 + 1, b, f.y1 + 2, f.z1 + 1, GEM);
    },
  },
  orc_axe: {
    frame: HAND_R, tag: "monster", palette: MONSTER_KIT,
    build(f, s) {
      s.box(1, 1, f.z0 - 1, 1, 2, f.z1 + 12, WOOD);
      for (const side of [1, -1]) {
        for (let k = 0; k < 4; k++) {
          const y = side > 0 ? 3 + k : -k;
          const half = k < 2 ? 2 : 3;
          s.box(1, y, f.z1 + 10 - half, 1, y, f.z1 + 10 + half - 1, k === 3 ? EDGE : P);
        }
      }
    },
  },
};

// --- Table -----------------------------------------------------------------------------
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
