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
