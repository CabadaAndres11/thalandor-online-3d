import { test } from "node:test";
import assert from "node:assert/strict";
import { jewelryV2 } from "../gear_jewelry_v2.mjs";
import { GLOW } from "../vox.mjs";

const j = jewelryV2();
const extent = (s) => { const z = s.size(); return Math.max(z[0], z[1]); };
const count = (s, idx) => [...s.cells.values()].filter((v) => v[3] === idx).length;

test("a ring and an amulet per tier", () => {
  for (const t of [1, 2, 3]) for (const k of ["ring", "neck"]) {
    assert.ok(j[`jewel_${k}_t${t}`], `${k} t${t}`);
    assert.ok(j[`jewel_${k}_t${t}`].shape.cells.size > 30, `${k} t${t} has volume`);
  }
});

test("each tier is bigger than the last", () => {
  for (const k of ["ring", "neck"]) {
    assert.ok(extent(j[`jewel_${k}_t2`].shape) >= extent(j[`jewel_${k}_t1`].shape), k);
    assert.ok(extent(j[`jewel_${k}_t3`].shape) > extent(j[`jewel_${k}_t1`].shape), k);
  }
});

test("tier 3 glows, tier 1 does not", () => {
  for (const k of ["ring", "neck"]) {
    assert.ok(count(j[`jewel_${k}_t3`].shape, GLOW) > 0, k);
    assert.equal(count(j[`jewel_${k}_t1`].shape, GLOW), 0, k);
  }
});

test("deterministic", () => {
  const again = jewelryV2();
  for (const id of Object.keys(j)) assert.deepEqual([...again[id].shape.cells.entries()], [...j[id].shape.cells.entries()], id);
});
