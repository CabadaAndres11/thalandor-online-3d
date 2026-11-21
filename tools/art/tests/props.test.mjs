// Plan 7: the props of the black sun altar (title scene).
import { test } from "node:test";
import assert from "node:assert/strict";
import { props } from "../make_props.mjs";
import { GLOW } from "../vox.mjs";

const p = props();

test("the altar scene props exist and fit a vox model", () => {
  for (const id of ["torch", "altar_sun", "column_broken", "brazier", "candles", "flagstones"]) {
    assert.ok(p[id], id);
    for (const d of p[id].shape.size()) assert.ok(d <= 126, `${id} size ${d}`);
    assert.ok(p[id].shape.cells.size > 30, `${id} has voxels`);
  }
});

test("the altar carries a glowing black sun", () => {
  const idx = new Set([...p.altar_sun.shape.cells.values()].map((c) => c[3]));
  assert.ok(idx.has(GLOW), "glow");
  assert.equal(p.altar_sun.palette[GLOW].toLowerCase(), "#ff4a2a");
  const [, h] = p.altar_sun.shape.size();
  assert.ok(h >= 30 && h <= 44, `about 1.5-2 m tall at 5 cm voxels (${h})`);
});

test("the brazier and the candles burn", () => {
  for (const id of ["brazier", "candles"]) assert.ok([...p[id].shape.cells.values()].some((c) => c[3] === GLOW), id);
});
