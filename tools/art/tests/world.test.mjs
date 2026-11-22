// Plan 8.1: world pieces (houses, forest, rocks, crypt) and the cells they block.
import { test } from "node:test";
import assert from "node:assert/strict";
import { worldPieces, footprintOf, CELL } from "../make_world.mjs";

const p = worldPieces();
const IDS = ["house_small", "house_large", "house_forge", "fence", "wall_low", "well", "cart", "crates",
  "tree_oak", "tree_pine", "bush", "rock_small", "rock_large", "stump", "bridge", "torch",
  "crypt_arch", "crypt_wall", "crypt_pillar"];

test("every piece exists and fits a vox model", () => {
  for (const id of IDS) {
    assert.ok(p[id], id);
    for (const d of p[id].shape.size()) assert.ok(d <= 126, `${id} size ${d}`);
  }
});

test("a house blocks its whole floor plan", () => {
  const f = footprintOf(p.house_small);
  for (let x = 0; x < 4; x++) for (let z = 0; z < 4; z++) assert.ok(f.some(([a, b]) => a === x && b === z), `${x},${z}`);
  assert.equal(footprintOf(p.house_large).length, 30);
  assert.equal(CELL, 20, "1 m is 20 voxels of 5 cm");
});

test("a bridge blocks nothing and a tree only its trunk", () => {
  assert.deepEqual(p.bridge.footprint, []);
  assert.deepEqual(footprintOf(p.tree_oak), [[0, 0]]);
  assert.deepEqual(footprintOf(p.tree_pine), [[0, 0]]);
});

test("the table carries vox, scale, offset and footprint", () => {
  const t = p.house_forge;
  assert.ok(t.shape.cells.size > 1000);
  assert.ok(Array.isArray(footprintOf(t)));
});
