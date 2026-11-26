// Plan 8.1: world pieces (houses, forest, rocks, crypt) and the cells they block.
import { test } from "node:test";
import assert from "node:assert/strict";
import { worldPieces, footprintOf, CELL, SMALL_PIECES, HOUSE_CELL, DECOR } from "../make_world.mjs";

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

// Plan 8.1.3: the stone forge, its open shed and the ground details.
test("the forge is stone and timber with two lit furnaces inside", () => {
  const f = p.house_forge;
  const idx = new Set([...f.parts.walls.cells.values()].map((v) => v[3]));
  assert.ok(!idx.has(22), "no plaster walls");
  assert.equal(f.lights.length, 2, "two furnaces");
});

test("the forge shed is an open house with a lit hearth", () => {
  const s = p.forge_shed;
  assert.ok(s, "forge_shed exists");
  assert.deepEqual(Object.keys(s.parts).sort(), ["floor", "roof", "walls", "walls_cut"]);
  assert.equal(s.scale, 1);
  assert.equal(s.lights.length, 1);
  const fp = new Set(s.footprint.map(([x, z]) => x + "," + z));
  const free = s.interior.filter(([x, z]) => !fp.has(x + "," + z));
  assert.ok(free.length >= 8, "walkable under the roof: " + free.length);
  for (const [x, z] of s.door) assert.ok(!fp.has(x + "," + z), "open front");
});

// Plan 8.3a: the prologue's pieces.
const PROLOGUE = ["garland", "lantern_post", "feast_table", "bonfire", "house_burnt_small", "house_burnt_large",
  "rubble", "fallen_beam", "grave", "army_tent", "kingdom_banner", "camp_ruined", "cart_tracks", "river_bank", "training_dummy"];

test("every prologue piece exists and fits a vox model", () => {
  for (const id of PROLOGUE) {
    assert.ok(p[id], id);
    for (const sh of p[id].parts ? Object.values(p[id].parts) : [p[id].shape]) {
      assert.ok(sh.cells.size > 0, id + " has voxels");
      for (const d of sh.size()) assert.ok(d <= 126, `${id} size ${d}`);
    }
  }
});

test("burnt houses block the same cells as the healthy ones and have no roof left", () => {
  for (const [burnt, healthy] of [["house_burnt_small", "house_small"], ["house_burnt_large", "house_large"]]) {
    assert.deepEqual(p[burnt].footprint, p[healthy].footprint, burnt);
    assert.deepEqual(p[burnt].door, p[healthy].door, burnt);
    assert.deepEqual(Object.keys(p[burnt].parts).sort(), ["floor", "roof", "walls", "walls_cut"]);
    assert.ok(p[burnt].parts.roof.cells.size < p[healthy].parts.roof.cells.size / 3, burnt + " roof burnt away");
    const top = Math.max(...[...p[burnt].parts.walls.cells.values()].map((v) => v[1]));
    assert.ok(top < 30, burnt + " walls burnt down");
  }
});

test("pieces fit in their footprint", () => {
  for (const id of PROLOGUE) {
    if (p[id].parts || p[id].footprint.length === 0) continue;
    const cells = new Set(p[id].footprint.map(([x, z]) => x + "," + z));
    for (const c of footprintOf({ shape: p[id].shape })) {
      const [x, z] = c;
      const near = [...cells].some((k) => { const [a, b] = k.split(",").map(Number); return Math.abs(a - x) <= 1 && Math.abs(b - z) <= 1; });
      assert.ok(near, `${id}: base at ${x},${z} is off its footprint`);
    }
  }
  assert.deepEqual(p.cart_tracks.footprint, []);
});

test("ground details are tiny and block nothing", () => {
  for (const id of DECOR) {
    assert.ok(p[id], id);
    assert.deepEqual(p[id].footprint, [], id);
    for (const d of p[id].shape.size()) assert.ok(d <= 12, id + " is small");
  }
});
