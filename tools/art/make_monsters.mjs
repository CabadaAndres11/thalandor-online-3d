// Voxel monsters (made as data).
//   node tools/art/make_monsters.mjs <out dir>
// Godot axes, monsters face +Z, 1 voxel = 0.1 m. Index 251 (TINT_PRIMARY) takes the
// monster's "tint" from data/monsters; 253 (GLOW) is drawn unshaded (eyes, acid).
//
// Single-body monsters (slime) are one .vox. Beasts are rigs: one .vox per part plus
// <name>.json with each part's pivot (where it rotates, in voxels from the rig
// origin at ground level below the body centre) and mesh offset (from the pivot).
import fs from "node:fs";
import { write, Shape, TINT_PRIMARY, GLOW } from "./vox.mjs";

const P = TINT_PRIMARY;
const DARK = 20, BELLY = 21, BONE = 22, NOSE = 23, PAW = 24, CORE = 25;
const PALETTE = {
  [DARK]: "#1e2026", [BELLY]: "#55585f", [BONE]: "#e6dfcc", [NOSE]: "#0e0e10",
  [PAW]: "#2a2c31", [CORE]: "#1f3d16", [GLOW]: "#ff3b2f",
};

// --- Single bodies ------------------------------------------------------------------

const BODIES = {
  // Acid slime: a heavy blob with a dark core, slanted glowing eyes, acid drips.
  slime() {
    const s = new Shape();
    s.box(0, 0, 0, 9, 6, 9, P);
    for (const [x, z] of [[0, 0], [9, 0], [0, 9], [9, 9]]) s.remove(x, 6, z, x, 6, z).remove(x, 0, z, x, 0, z);
    s.box(1, 7, 1, 8, 7, 8, P);
    s.remove(1, 7, 1, 1, 7, 1).remove(8, 7, 1, 8, 7, 1).remove(1, 7, 8, 1, 7, 8).remove(8, 7, 8, 8, 7, 8);
    s.box(3, 2, 3, 6, 4, 6, CORE); // dark core (seen through the sides' gaps)
    s.remove(0, 3, 4, 0, 4, 5).remove(9, 3, 4, 9, 4, 5); // gaps showing the core
    // Slanted angry eyes: outer corner higher.
    s.put(1, 4, 9, GLOW).put(2, 4, 9, GLOW).put(3, 3, 9, GLOW);
    s.put(8, 4, 9, GLOW).put(7, 4, 9, GLOW).put(6, 3, 9, GLOW);
    s.box(1, 5, 9, 3, 5, 9, DARK).box(6, 5, 9, 8, 5, 9, DARK); // heavy brows
    // Acid drips down the sides and bubbles on top.
    for (const [x, y, z] of [[0, 1, 2], [0, 0, 6], [9, 1, 7], [9, 0, 3], [4, 0, 9], [2, 8, 4], [6, 8, 6], [5, 8, 2]]) s.put(x, y, z, GLOW);
    return { shape: s, palette: { ...PALETTE, [GLOW]: "#b6ff3a" } };
  },
};

// --- Beasts (rigs) ------------------------------------------------------------------

const BEASTS = {
  // Dire wolf: long body with a spiky ridge, big head, fangs, glowing red eyes.
  wolf() {
    const parts = {};
    const body = new Shape();
    body.box(-3, 7, -6, 2, 12, 6, P);
    body.box(-2, 7, -5, 1, 7, 5, BELLY);
    body.box(-3, 12, 3, 2, 13, 6, P); // shoulders hump
    for (let z = -5; z <= 5; z += 2) body.box(-1, 13, z, 0, 14 + (z > 0 ? 1 : 0), z, DARK); // ridge spikes
    parts.body = { shape: body, pivot: [0, 0, 0] };

    const head = new Shape(); // pivot at the neck
    head.box(-3, -3, 0, 2, 2, 5, P);
    head.box(-2, -3, 6, 1, -1, 8, P); // snout
    head.put(-1, -1, 9, NOSE).put(0, -1, 9, NOSE);
    head.box(-2, -4, 7, -2, -4, 8, BONE).box(1, -4, 7, 1, -4, 8, BONE); // fangs
    head.put(-2, -5, 8, BONE).put(1, -5, 8, BONE);
    head.box(-3, 3, 1, -2, 4, 2, DARK).put(-3, 5, 1, DARK); // ears
    head.box(1, 3, 1, 2, 4, 2, DARK).put(2, 5, 1, DARK);
    head.box(-3, 0, 5, -2, 0, 5, GLOW).box(1, 0, 5, 2, 0, 5, GLOW); // eyes
    head.box(-3, 1, 5, -2, 1, 5, DARK).box(1, 1, 5, 2, 1, 5, DARK); // brows
    parts.head = { shape: head, pivot: [0, 11, 6] };

    const leg = () => {
      const l = new Shape(); // pivot at the hip, the foot reaches the ground
      l.box(-1, -7, -1, 0, 0, 0, P);
      l.box(-1, -8, -1, 0, -8, 1, PAW);
      return l;
    };
    parts.leg_front_left = { shape: leg(), pivot: [-2, 8, 4] };
    parts.leg_front_right = { shape: leg(), pivot: [2, 8, 4] };
    parts.leg_back_left = { shape: leg(), pivot: [-2, 8, -4] };
    parts.leg_back_right = { shape: leg(), pivot: [2, 8, -4] };

    const tail = new Shape(); // pivot at the base, pointing back and up
    tail.box(-1, -1, -5, 0, 0, -1, P);
    tail.box(-1, 0, -7, 0, 1, -6, DARK);
    parts.tail = { shape: tail, pivot: [0, 11, -6] };
    return { parts, palette: PALETTE };
  },

  // War boar: a heavy barrel body, hunched shoulders with a bristle crest, a low head
  // with long upturned tusks, glowing eyes and short legs ending in dark hooves.
  boar() {
    const parts = {};
    const body = new Shape();
    body.box(-4, 5, -6, 3, 11, 5, P); // barrel
    body.box(-3, 5, -5, 2, 5, 4, BELLY);
    body.box(-4, 11, 0, 3, 13, 6, P); // shoulder hump, higher at the front
    body.box(-3, 13, 1, 2, 14, 5, P);
    for (let z = -5; z <= 5; z += 1) body.box(-1, 12 + (z >= 0 ? 2 : 0), z, 0, 13 + (z >= 0 ? 3 : 0) - (z % 2 === 0 ? 0 : 1), z, DARK); // bristle crest
    for (const x of [-4, 3]) for (let z = -5; z <= 4; z += 3) body.put(x, 9, z, DARK).put(x, 10, z + 1, DARK); // dark streaks
    parts.body = { shape: body, pivot: [0, 0, 0] };

    const head = new Shape(); // pivot at the neck, the head hangs low and forward
    head.box(-3, -4, 0, 2, 1, 5, P);
    head.box(-2, -4, 6, 1, -1, 8, P); // snout
    head.box(-2, -3, 9, 1, -1, 9, NOSE);
    head.put(-1, -2, 9, BELLY).put(0, -2, 9, BELLY); // nostrils' rim
    // Long tusks curving up and out from the jaw.
    for (const x of [-3, 2]) {
      head.put(x, -4, 7, BONE).put(x, -3, 8, BONE).put(x, -2, 9, BONE).put(x, -1, 10, BONE).put(x, 0, 10, BONE);
    }
    head.box(-3, 2, 1, -2, 3, 2, DARK).box(1, 2, 1, 2, 3, 2, DARK); // ears
    head.box(-3, 0, 5, -2, 0, 5, GLOW).box(1, 0, 5, 2, 0, 5, GLOW); // eyes
    head.box(-3, 1, 5, -2, 1, 5, DARK).box(1, 1, 5, 2, 1, 5, DARK); // brows
    parts.head = { shape: head, pivot: [0, 10, 6] };

    const leg = () => {
      const l = new Shape(); // pivot at the hip, short and thick
      l.box(-1, -4, -1, 1, 0, 1, P);
      l.box(-1, -5, -1, 1, -5, 1, PAW);
      return l;
    };
    parts.leg_front_left = { shape: leg(), pivot: [-3, 5, 3] };
    parts.leg_front_right = { shape: leg(), pivot: [2, 5, 3] };
    parts.leg_back_left = { shape: leg(), pivot: [-3, 5, -4] };
    parts.leg_back_right = { shape: leg(), pivot: [2, 5, -4] };

    const tail = new Shape(); // a short curly tail
    tail.box(0, 0, -2, 0, 0, -1, P).put(0, 1, -2, P).put(0, 1, -3, DARK);
    parts.tail = { shape: tail, pivot: [0, 10, -6] };
    return { parts, palette: { ...PALETTE, [BELLY]: "#8a6a50", [PAW]: "#1b1612", [NOSE]: "#2a1a14" } };
  },

  // Skeleton archer: a standing rig of thin bones with real gaps between them (the
  // monster's "tint" colours the bone, index 251). Ribs are hoops with air between
  // them around a spine; arms and legs are 1-voxel bones with knobbly joints; the
  // forearms and shins are two bones side by side; a skull with empty sockets and a
  // glowing ember in each, a separate jaw with teeth, and a recurve bow in the left
  // hand. Left is +X (the skeleton faces +Z). Parts hang from their parent's pivot.
  skeleton() {
    const parts = {};
    const RAG = DARK, WOOD = PAW, STRING = BELLY;
    // About 2 m: legs 8 voxels, spine and ribs 7, skull 6; hands reach mid-thigh.

    const pelvis = new Shape(); // pivot at the hips
    pelvis.box(-2, 0, -1, 2, 0, 0, P); // hip girdle
    pelvis.put(-3, 1, -1, P).put(3, 1, -1, P).put(-3, 1, 0, P).put(3, 1, 0, P); // iliac wings
    pelvis.put(-2, -1, 0, P).put(2, -1, 0, P); // hip sockets
    pelvis.put(0, 1, -1, P); // sacrum
    // A torn dark loincloth: a few strips of different lengths, front and back.
    for (const [x, len] of [[-2, 2], [0, 3], [2, 2]]) {
      pelvis.box(x, -len, 1, x, 0, 1, RAG);
      if (x !== 0) pelvis.box(x / 2, -len + 1, -2, x / 2, 0, -2, RAG);
    }
    parts.body = { shape: pelvis, pivot: [0, 8, 0] };

    const torso = new Shape(); // pivot at the base of the spine, on top of the pelvis
    torso.box(0, 0, -1, 0, 6, -1, P); // spine
    for (let y = 0; y <= 6; y += 2) torso.put(-1, y, -1, P).put(1, y, -1, P); // vertebra knobs
    for (const [y, half] of [[1, 2], [3, 3], [5, 3]]) {
      // A rib hoop: back to the spine, round the sides, nearly closed in front.
      torso.box(-half, y, -1, half, y, -1, P);
      torso.box(-half, y, 0, -half, y, 1, P).box(half, y, 0, half, y, 1, P);
      torso.box(-half + 1, y, 2, -1, y, 2, P).box(1, y, 2, half - 1, y, 2, P);
    }
    torso.box(0, 2, 2, 0, 5, 2, P); // sternum
    torso.box(-4, 6, 0, 4, 6, 0, P); // collarbones
    torso.put(-4, 5, -1, P).put(4, 5, -1, P); // shoulder blades
    parts.torso = { shape: torso, pivot: [0, 9, 0], parent: "body" };

    // An evil skull: heavy brow ridges slanting down to the middle over big sockets
    // (a scowl), embers burning inside, sharp flared cheekbones and a grin of long teeth.
    const head = new Shape(); // pivot at the top of the spine
    head.put(0, 0, -1, P); // neck vertebra
    head.box(-2, 2, -2, 2, 5, 2, P); // cranium...
    for (const x of [-2, 2]) for (const z of [-2, 2]) head.remove(x, 2, z, x, 5, z); // ...rounded
    head.remove(-2, 5, -1, -2, 5, 1).remove(2, 5, -1, 2, 5, 1).remove(-1, 5, -2, 1, 5, -2);
    head.box(-1, 6, -1, 1, 6, 1, P); // dome
    head.box(-2, 1, 0, 2, 1, 2, P); // upper jaw
    head.remove(-2, 3, 2, -1, 4, 2).remove(1, 3, 2, 2, 4, 2); // big empty eye sockets
    head.box(-2, 3, 1, -1, 4, 1, RAG).box(1, 3, 1, 2, 4, 1, RAG); // deep dark sockets...
    head.put(-1, 3, 1, GLOW).put(1, 3, 1, GLOW); // ...with an ember low in the inner corner
    // Brow ridges jutting out, high at the temples and low in the middle.
    head.put(-2, 5, 3, P).put(-1, 4, 3, P).put(0, 4, 3, P);
    head.put(2, 5, 3, P).put(1, 4, 3, P); // (the low inner ends hide the top of each socket: a scowl)
    head.put(-2, 2, 3, P).put(2, 2, 3, P); // sharp cheekbones jutting forward
    head.remove(0, 2, 2, 0, 2, 2).put(0, 2, 1, RAG); // dark nose hole
    head.remove(-1, 1, 2, -1, 1, 2).remove(1, 1, 2, 1, 1, 2).put(-1, 1, 1, RAG).put(1, 1, 1, RAG); // dark gaps between the upper teeth
    head.put(-2, 0, 2, P).put(2, 0, 2, P); // upper fangs
    head.remove(-2, 3, 0, -2, 3, 0).remove(2, 3, 0, 2, 3, 0); // sunken temples
    parts.head = { shape: head, pivot: [0, 15, -1], parent: "torso" };

    const jaw = new Shape(); // pivot at the hinge, under the skull; hangs a little open
    jaw.box(-2, 0, 0, 2, 0, 3, P);
    jaw.remove(-1, 0, 0, 1, 0, 1); // open behind the chin
    for (const x of [-2, -1, 0, 1, 2]) jaw.put(x, 1, 3, P); // a row of teeth...
    jaw.remove(-1, 1, 3, -1, 1, 3).remove(1, 1, 3, 1, 1, 3); // ...with gaps
    jaw.box(-1, 0, 2, 1, 0, 2, RAG); // the dark of the open mouth behind the teeth
    jaw.put(-2, 2, 3, P).put(2, 2, 3, P); // lower fangs
    parts.jaw = { shape: jaw, pivot: [0, 15, -1], parent: "head" };

    // Arm: humerus, a knobbly elbow, two forearm bones with a gap, bony fingers.
    const arm = () => {
      const a = new Shape(); // pivot at the shoulder
      a.box(0, -4, 0, 0, -1, 0, P);
      a.box(0, -5, -1, 0, -5, 1, P); // elbow
      a.box(0, -8, -1, 0, -6, -1, P).box(0, -8, 1, 0, -6, 1, P); // radius and ulna
      a.box(0, -9, -1, 0, -9, 1, P); // wrist
      a.put(0, -10, -1, P).put(0, -10, 1, P).put(0, -11, 1, P); // claw-like fingers
      return a;
    };
    parts.arm_left = { shape: arm(), pivot: [5, 15, 0], parent: "torso" };
    parts.arm_right = { shape: arm(), pivot: [-5, 15, 0], parent: "torso" };

    // Leg: femur, a knee cap, shin and calf bones with a gap, ankle and a bony foot.
    const leg = () => {
      const l = new Shape(); // pivot at the hip socket
      l.box(0, -3, 0, 0, -1, 0, P);
      l.box(0, -4, 0, 0, -4, 1, P); // knee
      l.box(0, -7, -1, 0, -5, -1, P).box(0, -7, 1, 0, -5, 1, P); // tibia and fibula
      l.put(0, -8, 0, P); // ankle
      l.box(0, -8, 1, 0, -8, 3, P).put(0, -8, -1, P); // foot and heel
      return l;
    };
    parts.leg_left = { shape: leg(), pivot: [2, 8, 0], parent: "body" };
    parts.leg_right = { shape: leg(), pivot: [-2, 8, 0], parent: "body" };

    const bow = new Shape(); // pivot at the grip in the left fist, upright, curving forward
    bow.box(0, -1, 1, 0, 1, 1, WOOD); // grip
    bow.box(0, 2, 0, 0, 3, 0, WOOD).put(0, 4, -1, WOOD).put(0, 5, -1, WOOD).put(0, 6, -2, WOOD); // upper limb
    bow.box(0, -3, 0, 0, -2, 0, WOOD).put(0, -4, -1, WOOD).put(0, -5, -1, WOOD).put(0, -6, -2, WOOD); // lower limb
    bow.box(0, -5, -3, 0, 5, -3, STRING); // string
    parts.bow = { shape: bow, pivot: [5, 5, 1], parent: "arm_left" };
    return {
      parts, gait: "biped",
      palette: { ...PALETTE, [DARK]: "#24222a", [PAW]: "#7a5232", [BELLY]: "#e8e2cf", [GLOW]: "#ff2a1a" },
    };
  },
};

const [outDir] = process.argv.slice(2);
if (!outDir) {
  console.error("usage: node make_monsters.mjs <out dir>");
  process.exit(1);
}
for (const [name, build] of Object.entries(BODIES)) {
  const { shape, palette } = build();
  write(`${outDir}/${name}.vox`, shape.size(), shape.voxels(), palette);
  console.log(`wrote monster ${name} ${shape.size().join("x")} (${shape.voxels().length} voxels)`);
}
for (const [name, build] of Object.entries(BEASTS)) {
  const { parts, palette, gait } = build();
  const rig = gait ? { gait, parts: {} } : { parts: {} };
  for (const [part, { shape, pivot, parent }] of Object.entries(parts)) {
    const file = `${name}_${part}.vox`;
    write(`${outDir}/${file}`, shape.size(), shape.voxels(), palette);
    rig.parts[part] = { file: `res://assets/monsters/vox/${file}`, pivot, offset: shape.min(), ...(parent ? { parent } : {}) };
  }
  fs.writeFileSync(`${outDir}/${name}.json`, JSON.stringify(rig, null, "\t") + "\n");
  console.log(`wrote beast ${name}: ${Object.keys(parts).join(", ")}`);
}
