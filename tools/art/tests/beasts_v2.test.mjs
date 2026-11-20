import { test } from "node:test";
import assert from "node:assert/strict";
import { beastsV2 } from "../beasts_v2.mjs";
import { GLOW } from "../vox.mjs";

// Plan 6.4.2: the beasts at 2.5 cm voxels with the same parts and pivots.
const b = beastsV2();
const PARTS = ["body", "head", "leg_front_left", "leg_front_right", "leg_back_left", "leg_back_right", "tail"];

test("each beast has its seven parts and 2.5 cm voxels", () => {
  for (const [name, beast] of Object.entries(b)) {
    assert.equal(beast.voxel_scale, 0.25, name);
    for (const p of PARTS) assert.ok(beast.parts[p] && beast.parts[p].shape.cells.size > 50, `${name} ${p}`);
  }
});

test("legs reach the ground", () => {
  for (const [name, beast] of Object.entries(b)) for (const p of PARTS.filter((x) => x.startsWith("leg_"))) {
    let lo = Infinity;
    for (const [, y] of beast.parts[p].shape.cells.values()) lo = Math.min(lo, y);
    const foot = beast.parts[p].pivot[1] + lo;
    assert.ok(foot >= -1 && foot <= 1, `${name} ${p} foot at ${foot}`);
  }
});

test("eyes burn; only the cult's beasts carry the burning mark", () => {
  const glow = (name) => [...b[name].parts.head.shape.cells.values()].filter((v) => v[3] === GLOW).length;
  assert.ok(glow("hunter_wolf") >= 8, "the wolf's eyes");
  assert.ok(glow("marked_hound") > glow("hunter_wolf"), "the hound's mark");
  assert.ok(glow("marked_boar") > 8, "the boar's eyes and mark");
});

test("parts fit in a .vox and generation is deterministic", () => {
  const again = beastsV2();
  for (const [name, beast] of Object.entries(b)) for (const p of PARTS) {
    for (const d of beast.parts[p].shape.size()) assert.ok(d <= 256, `${name} ${p}`);
    assert.deepEqual([...again[name].parts[p].shape.cells.entries()], [...beast.parts[p].shape.cells.entries()], `${name} ${p}`);
  }
});
