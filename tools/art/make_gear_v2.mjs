// The v2 equipment models (Plan 6.3) and data/items/gear_pieces_v2.json.
//   node tools/art/make_gear_v2.mjs <vox out dir> <gear_pieces_v2.json>
//   (assets/items/vox_v2 and data/items/gear_pieces_v2.json)
// Same ids, parts, tags and hides as data/items/gear_pieces.json (copied from it); every
// piece is drawn in its part's pivot frame, so its offset is the shape's lowest corner.
// bases.json keeps the looks' ids; jewelry (never worn) is named by its bases' "model".
import fs from "node:fs";
import { fileURLToPath } from "node:url";
import { write } from "./vox.mjs";
import { armorV2, npcOutfitsV2, BODY } from "./gear_armor_v2.mjs";
import { carve } from "./sculpt.mjs";
import { gearWeaponsV2 as weapons } from "./gear_weapons_v2.mjs";
import { jewelryV2 } from "./gear_jewelry_v2.mjs";

// The body part each piece hangs from (pieces never sit inside it).
const PART_BODY = { head: "head", torso: "torso", hips: "hips", arm_left: "arm", arm_right: "arm", forearm_left: "fore",
  forearm_right: "fore", hand_left: "hand", hand_right: "hand", leg_left: "thigh", leg_right: "thigh", shin_left: "shin", shin_right: "shin" };


export function gearV2() {
  const all = { ...armorV2(), ...npcOutfitsV2(), ...weapons() };
  for (const p of Object.values(all)) {
    const part = p.body ?? BODY[PART_BODY[p.part]]; // a race variant is carved by its race head
    if (part) carve(p.shape, (c) => { for (const [x, y, z] of part.cells.values()) c.put(x, y, z, 0); });
  }
  // Jewelry is never worn (only icons and loot use it), so it is not carved.
  return { ...all, ...jewelryV2() };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [outDir, jsonPath] = process.argv.slice(2);
  if (!outDir || !jsonPath) {
    console.error("usage: node make_gear_v2.mjs <vox out dir> <gear_pieces_v2.json>");
    process.exit(1);
  }
  const v1 = JSON.parse(fs.readFileSync(new URL("../../data/items/gear_pieces.json", import.meta.url)));
  fs.mkdirSync(outDir, { recursive: true });
  for (const f of fs.readdirSync(outDir)) if (f.endsWith(".vox")) fs.unlinkSync(`${outDir}/${f}`);
  const table = {};
  for (const [id, p] of Object.entries(gearV2())) {
    write(`${outDir}/${id}.vox`, p.shape.size(), p.shape.voxels(), p.palette);
    table[id] = {
      file: `res://assets/items/vox_v2/${id}.vox`,
      part: p.part,
      offset: p.shape.min(),
      tag: v1[p.like ?? id]?.tag ?? "gear",
      hides: v1[p.like ?? id]?.hides ?? [],
    };
  }
  fs.writeFileSync(jsonPath, JSON.stringify(table, null, "\t") + "\n");
  console.log(`wrote ${Object.keys(table).length} v2 gear pieces and ${jsonPath}`);
}
