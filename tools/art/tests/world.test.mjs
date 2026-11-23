// Plan 8.1: world pieces (houses, forest, rocks, crypt) and the cells they block.
import { test } from "node:test";
import assert from "node:assert/strict";
import { worldPieces, footprintOf, CELL, SMALL_PIECES, HOUSE_CELL } from "../make_world.mjs";

const p = worldPieces();
const IDS = ["house_small", "house_large", "house_forge", "fence", "wall_low", "well", "cart", "crates",
  "tree_oak", "tree_pine", "bush", "rock_small", "rock_large", "stump", "bridge", "torch",
  "crypt_arch", "crypt_wall", "crypt_pillar", "signpost"];

test("every piece exists and fits a vox model", () => {
  for (const id of IDS) {
    assert.ok(p[id], id);
    for (const sh of p[id].parts ? Object.values(p[id].parts) : [p[id].shape]) {
      for (const d of sh.size()) assert.ok(d <= 126, `${id} size ${d}`);
    }
  }
});

const HOUSES = { house_small: [6, 6], house_large: [8, 7], house_forge: [7, 7] };

test("houses have four parts, a free door and a walkable inside (Plan 8.1.1)", () => {
  for (const [id, [w, d]] of Object.entries(HOUSES)) {
    const h = p[id];
    assert.deepEqual(Object.keys(h.parts).sort(), ["floor", "roof", "walls", "walls_cut"], id);
    assert.equal(h.interior.length, (w - 2) * (d - 2), id + " interior");
    const fp = new Set(h.footprint.map(([x, z]) => x + "," + z));
    for (const [x, z] of h.door) assert.ok(!fp.has(x + "," + z), id + " door free");
    assert.equal(h.door.length, 2);
    const free = h.interior.filter(([x, z]) => !fp.has(x + "," + z));
    assert.ok(free.length >= 10, id + " walkable inside " + free.length);
    assert.equal(h.scale, 1);
  }
  assert.ok(p.house_small.interior.length >= 12);
  assert.equal(HOUSE_CELL, 10, "houses are 10 cm voxels");
});

test("cut walls stop at 1 m; full walls reach 3 m", () => {
  for (const id of Object.keys(HOUSES)) {
    const top = (sh) => Math.max(...[...sh.cells.values()].map((v) => v[1]));
    assert.ok(top(p[id].parts.walls_cut) <= 10, id);
    assert.ok(top(p[id].parts.walls) >= 30, id);
  }
});

test("the forge has a lit fire", () => {
  assert.ok(p.house_forge.lights.length >= 1);
});

test("a bridge blocks nothing and a tree only its trunk", () => {
  assert.deepEqual(p.bridge.footprint, []);
  assert.deepEqual(footprintOf(p.tree_oak), [[0, 0]]);
  assert.deepEqual(footprintOf(p.tree_pine), [[0, 0]]);
});

test("the table carries vox, scale, offset and footprint", () => {
  const t = p.well;
  assert.ok(t.shape.cells.size > 1000);
  assert.ok(Array.isArray(footprintOf(t)));
});

test("small pieces cast no shadow and are drawn closer (Plan 8.1.1)", () => {
  assert.deepEqual([...SMALL_PIECES].sort(), ["bush", "rock_small", "stump", "torch"]);
});
