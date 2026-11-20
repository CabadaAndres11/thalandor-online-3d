import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { piecesV2 } from "../make_pieces_v2.mjs";
import { headV2 } from "../human_v2.mjs";

const v1 = JSON.parse(fs.readFileSync(new URL("../../../data/characters/pieces.json", import.meta.url)));
const v2 = piecesV2();
const HAIR = ["hair_short", "hair_bob", "hair_swept", "hair_mohawk", "hair_long", "hair_ponytail", "hair_bun"];
const BEARDS = ["beard_mustache", "beard_goatee", "beard_short", "beard_full"];

test("every v2 hair and beard exists with the v1 part", () => {
  for (const id of [...HAIR, ...BEARDS]) {
    assert.ok(v2[id], id);
    assert.equal(v2[id].part, v1[id].part, id);
    assert.ok(v2[id].shape.cells.size > 20, `${id} has volume`);
  }
});

test("hair caps cover the top of the v2 skull", () => {
  const head = headV2();
  const surface = [...head.cells.values()].filter(([x, y, z]) => y >= 14 &&
    [[0, 1, 0], [1, 0, 0], [-1, 0, 0], [0, 0, 1], [0, 0, -1]].some(([dx, dy, dz]) => !head.cells.has(`${x + dx},${y + dy},${z + dz}`)));
  for (const id of ["hair_short", "hair_bob", "hair_swept"]) {
    const hair = v2[id].shape;
    const near = (x, y, z) => {
      for (let dx = -1; dx <= 1; dx++) for (let dy = -1; dy <= 1; dy++) for (let dz = -1; dz <= 1; dz++)
        if (hair.cells.has(`${x + dx},${y + dy},${z + dz}`)) return true;
      return false;
    };
    const bare = surface.filter(([x, y, z]) => !near(x, y, z));
    assert.equal(bare.length, 0, `${id}: ${bare.length} bare skull cells`);
  }
});

test("hair and beards never overlap the head", () => {
  const head = headV2();
  for (const id of [...HAIR, ...BEARDS]) {
    for (const key of v2[id].shape.cells.keys()) assert.ok(!head.cells.has(key), `${id} at ${key}`);
  }
});

test("the face stays visible under caps and beards", () => {
  for (const id of [...HAIR, ...BEARDS]) {
    for (const [x, y, z] of v2[id].shape.cells.values()) {
      const onEyes = y >= 7 && y <= 10 && x >= -6 && x <= 5 && z >= 3;
      assert.ok(!onEyes, `${id} covers the eyes at ${x},${y},${z}`);
    }
  }
});

const CLOTHES = ["outfit_warrior", "outfit_cleric", "outfit_mage", "outfit_archer", "outfit_assassin", "outfit_villager",
  "hat_mage", "hood_archer", "helm_templar", "mask_assassin", "hood_cleric", "pauldron_left", "pauldron_right", "quiver_back"];

test("every class piece has a v2 version on the v1 part", () => {
  for (const id of CLOTHES) {
    assert.ok(v2[id], id);
    assert.equal(v2[id].part, v1[id].part, id);
    assert.ok(v2[id].shape.cells.size > 30, `${id} has volume`);
  }
});

test("clothes never sit inside the body part they hang from", async () => {
  const body = (await import("../human_v2.mjs")).humanV2().parts;
  for (const id of CLOTHES) {
    const part = body[v2[id].part].shape;
    for (const key of v2[id].shape.cells.keys()) assert.ok(!part.cells.has(key), `${id} inside ${v2[id].part} at ${key}`);
  }
});

test("headgear keeps the eyes visible", () => {
  for (const id of ["hat_mage", "hood_archer", "helm_templar", "mask_assassin"]) {
    for (const [x, y, z] of v2[id].shape.cells.values()) {
      const eyeColumn = (x >= 1 && x <= 4) || (x >= -5 && x <= -2);
      assert.ok(!(y >= 7 && y <= 10 && eyeColumn && z >= 4), `${id} covers the eyes at ${x},${y},${z}`);
    }
  }
});

test("every piece the class and upgrade data name has a v2 version (weapons apart)", () => {
  const classes = JSON.parse(fs.readFileSync(new URL("../../../data/characters/classes.json", import.meta.url)));
  const ids = new Set();
  for (const c of classes.classes ?? classes) {
    for (const id of [...(c.pieces ?? []), ...(c.fixed_pieces ?? []), c.headgear ?? ""]) if (id) ids.add(id);
  }
  for (const id of ids) assert.ok(v2[id], `${id} has no v2 version`);
});

test("every hand weapon has a v2 version on the v1 hand", () => {
  for (const id of ["weapon_sword", "weapon_wood_sword", "weapon_mace", "weapon_staff", "weapon_bow", "weapon_crossbow", "weapon_dagger_right", "weapon_dagger_left"]) {
    assert.ok(v2[id], id);
    assert.equal(v2[id].part, v1[id].part, id);
    assert.ok(v2[id].shape.cells.size > 40, `${id} has volume`);
  }
});
