import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { monstersV2 } from "../monsters_v2.mjs";
import { humanV2 } from "../human_v2.mjs";
import { GLOW } from "../vox.mjs";

// Plan 6.4.1: every cult enemy piece of the v1 table has a v2 version on the same part.
const v1 = JSON.parse(fs.readFileSync(new URL("../../../data/characters/pieces.json", import.meta.url)));
const ids = Object.keys(v1).filter((id) => /^(cult_|acolyte_|inquisitor_|vaelthar_|nhazar_)/.test(id) || id === "weapon_inquisitor_sword");
const m = monstersV2();
const body = humanV2().parts;

test("every cult enemy piece has a v2 version on the same part", () => {
  assert.ok(ids.length >= 31, `${ids.length} ids`);
  for (const id of ids) {
    assert.ok(m[id], `${id} missing`);
    assert.equal(m[id].part, v1[id].part, id);
    assert.ok(m[id].shape.cells.size > 40, `${id} has volume`);
  }
});

test("no piece sits inside its body part", () => {
  for (const id of ids) {
    const part = body[m[id].part].shape;
    for (const key of m[id].shape.cells.keys()) assert.ok(!part.cells.has(key), `${id} inside ${m[id].part} at ${key}`);
  }
});

test("robes reach down near the ground and stay off it", () => {
  for (const id of ["cult_robe", "acolyte_robe", "vaelthar_robe"]) {
    let lo = Infinity;
    for (const [, y] of m[id].shape.cells.values()) lo = Math.min(lo, y);
    assert.ok(lo <= -48 && lo >= -60, `${id} hem at ${lo}`);
  }
});

test("the cult's eyes and suns burn", () => {
  for (const id of ["acolyte_hood", "inquisitor_hood", "vaelthar_mane", "acolyte_robe"]) {
    assert.ok([...m[id].shape.cells.values()].some((v) => v[3] === GLOW), `${id} glows`);
  }
});

test("pieces fit in a .vox (256 a side)", () => {
  for (const id of ids) for (const d of m[id].shape.size()) assert.ok(d <= 256, `${id} ${m[id].shape.size()}`);
});

test("deterministic", () => {
  const again = monstersV2();
  for (const id of ["cult_robe", "vaelthar_tentacles_left", "inquisitor_hood"]) assert.deepEqual([...again[id].shape.cells.entries()], [...m[id].shape.cells.entries()], id);
});
