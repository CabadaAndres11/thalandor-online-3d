import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { gearV2 } from "../make_gear_v2.mjs";
import { humanV2 } from "../human_v2.mjs";

const v1 = JSON.parse(fs.readFileSync(new URL("../../../data/items/gear_pieces.json", import.meta.url)));
const v2 = gearV2();
const body = humanV2().parts;
const armorIds = Object.keys(v1).filter((id) => v1[id].tag !== "weapon");
const CLASSES = ["warrior", "cleric", "mage", "archer", "assassin"];

test("every v1 armour id has a v2 piece on the same part", () => {
  for (const id of armorIds) {
    assert.ok(v2[id], `${id} missing`);
    assert.equal(v2[id].part, v1[id].part, id);
    assert.ok(v2[id].shape.cells.size > 15, `${id} has volume`);
  }
});

test("armour never sits inside its v2 body part", () => {
  for (const id of armorIds) {
    const part = body[v2[id].part].shape;
    let inside = 0;
    for (const key of v2[id].shape.cells.keys()) if (part.cells.has(key)) inside++;
    assert.equal(inside, 0, `${id}: ${inside} cells inside ${v2[id].part}`);
  }
});

test("tier silhouettes grow", () => {
  for (const cls of CLASSES) for (const slot of ["head", "shoulders_l", "chest"]) {
    const n = [1, 2, 3].map((t) => v2[`${cls}_${slot.replace("_l", "")}_t${t}${slot.endsWith("_l") ? "_l" : ""}`].shape.cells.size);
    assert.ok(n[2] > n[1] && n[1] >= n[0], `${cls} ${slot}: ${n.join(" < ")}`);
  }
});

test("head pieces keep the eyes visible (warrior helms apart)", () => {
  for (const id of armorIds.filter((i) => v2[i].part === "head" && !i.startsWith("warrior_"))) {
    for (const [x, y, z] of v2[id].shape.cells.values()) {
      const eyeColumn = (x >= 1 && x <= 4) || (x >= -5 && x <= -2);
      assert.ok(!(y >= 7 && y <= 10 && eyeColumn && z >= 4), `${id} covers the eyes at ${x},${y},${z}`);
    }
  }
});

test("generation is deterministic", () => {
  const again = gearV2();
  for (const id of ["warrior_chest_t3", "mage_head_t3", "archer_chest_t2_cape"].filter((i) => v2[i])) {
    assert.deepEqual([...again[id].shape.cells.values()].sort(), [...v2[id].shape.cells.values()].sort(), id);
  }
});

const weaponIds = Object.keys(v1).filter((id) => v1[id].tag === "weapon");
const extent = (shape, axis) => {
  const vs = [...shape.cells.values()].map((v) => v[axis]);
  return Math.max(...vs) - Math.min(...vs) + 1;
};
const longest = (shape) => Math.max(extent(shape, 0), extent(shape, 1), extent(shape, 2));

test("every v1 weapon id has a v2 piece on the same hand", () => {
  for (const id of weaponIds) {
    assert.ok(v2[id], `${id} missing`);
    assert.equal(v2[id].part, v1[id].part, id);
  }
});

test("off-hand items are held in the left hand", () => {
  for (const id of weaponIds.filter((i) => /^w_(shield|orb|tome|bow)_t\d$|_left$/.test(i))) assert.equal(v2[id].part, "hand_left", id);
});

test("weapons keep their v1 length in metres (±20 %)", async () => {
  const { VoxRead } = await import("./vox_read.mjs");
  for (const id of weaponIds) {
    const v1len = VoxRead(new URL(`../../../${v1[id].file.replace("res://", "")}`, import.meta.url)) * 2; // v1 voxels are twice as big
    const len = longest(v2[id].shape);
    assert.ok(len >= v1len * 0.8 && len <= v1len * 1.25, `${id}: ${len} v2 voxels vs ${v1len} (v1 ×2)`);
  }
});

test("tier 3 weapons are larger than tier 1", () => {
  for (const fam of ["sword", "axe", "mace", "greatsword", "great_axe", "warhammer", "halberd", "staff", "bow", "shield", "orb"]) {
    assert.ok(v2[`w_${fam}_t3`].shape.cells.size > v2[`w_${fam}_t1`].shape.cells.size, fam);
  }
});
