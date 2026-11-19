import { test } from "node:test";
import assert from "node:assert/strict";
import { human, humanV2 } from "../make_humans.mjs";
import { TINT_SKIN, SHADE, LIGHT } from "../vox.mjs";

const v1 = human(), v2 = humanV2();
// Highest/lowest voxel of a part in rig space (pivot + cell).
const extent = (rig, name, axis, fn) => {
  const p = rig.parts[name];
  return fn(...[...p.shape.cells.values()].map((v) => v[axis] + p.pivot[axis]));
};
// Pivot in rig space: pivots are already absolute (from the rig origin).

test("v2 has the same parts and parents as v1", () => {
  assert.deepEqual(Object.keys(v2.parts).sort(), Object.keys(v1.parts).sort());
  for (const [k, p] of Object.entries(v1.parts)) assert.equal(v2.parts[k].parent, p.parent, k);
});

test("v2 is 96-99 voxels tall and stands on the ground", () => {
  const top = extent(v2, "head", 1, Math.max);
  assert.ok(top >= 95 && top <= 98, `top ${top}`);
  const bottom = Math.min(extent(v2, "shin_left", 1, Math.min), extent(v2, "shin_right", 1, Math.min));
  assert.equal(bottom, 0);
});

test("head is 15-19 voxels tall", () => {
  const h = extent(v2, "head", 1, Math.max) - extent(v2, "head", 1, Math.min) + 1;
  assert.ok(h >= 15 && h <= 19, `head ${h}`);
});

test("v2 is symmetric", () => {
  for (const [l, r] of [["arm_left", "arm_right"], ["leg_left", "leg_right"], ["shin_left", "shin_right"], ["hand_left", "hand_right"]]) {
    const lmin = extent(v2, l, 0, Math.min), lmax = extent(v2, l, 0, Math.max);
    const rmin = extent(v2, r, 0, Math.min), rmax = extent(v2, r, 0, Math.max);
    assert.equal(-1 - lmax, rmin, `${l}/${r}`);
    assert.equal(-1 - lmin, rmax, `${l}/${r}`);
  }
});

test("skin uses three tones", () => {
  const used = new Set([...v2.parts.head.shape.cells.values()].map((v) => v[3]));
  for (const i of [TINT_SKIN, SHADE(TINT_SKIN), LIGHT(TINT_SKIN)]) assert.ok(used.has(i), `tone ${i}`);
});

test("generation is deterministic", () => {
  const again = humanV2();
  for (const k of Object.keys(v2.parts)) {
    assert.deepEqual([...again.parts[k].shape.cells.values()].sort(), [...v2.parts[k].shape.cells.values()].sort(), k);
  }
});
