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
      for (const d of sh.size()) assert.ok(d <= 256, `${id} size ${d}`);
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

// Plan 8.3b: the road, the capital and the palace.
const CAPITAL = ["city_wall", "city_gate", "house_city", "market_stall", "fountain", "city_lamp", "palace_column", "palace_carpet",
  "throne", "brazier", "crypt_gate_closed", "crypt_gate_open", "caravan_wagon", "horse", "bandit_palisade"];

test("every capital piece exists and fits a vox model", () => {
  for (const id of CAPITAL) {
    assert.ok(p[id], id);
    for (const sh of p[id].parts ? Object.values(p[id].parts) : [p[id].shape]) {
      assert.ok(sh.cells.size > 0, id);
      for (const d of sh.size()) assert.ok(d <= 126, `${id} size ${d}`);
    }
  }
});

test("the city house has two storeys, a free door and a walkable inside", () => {
  const h = p.house_city;
  const top = Math.max(...[...h.parts.walls.cells.values()].map((v) => v[1]));
  assert.ok(top >= 60, "two storeys: " + top);
  const fp = new Set(h.footprint.map(([x, z]) => x + "," + z));
  for (const [x, z] of h.door) assert.ok(!fp.has(x + "," + z), "door free");
  assert.ok(h.interior.filter(([x, z]) => !fp.has(x + "," + z)).length >= 10, "walkable inside");
});

test("the gate leaves its way through free, and both crypt gates share their footprint", () => {
  assert.deepEqual(p.city_gate.footprint, [[0, 0], [4, 0]]);
  assert.deepEqual(p.crypt_gate_closed.footprint, p.crypt_gate_open.footprint);
  assert.deepEqual(p.palace_carpet.footprint, []);
  const low = (sh) => [...sh.cells.values()].filter((v) => v[0] >= 21 && v[0] <= 38 && v[1] < 40).length;
  assert.ok(low(p.crypt_gate_closed.shape) > 0, "closed: bars across");
  assert.equal(low(p.crypt_gate_open.shape), 0, "open: the way is clear");
});

// Plan 8.3d: the village's houses, barn and cows.
test("the new village houses are walkable and their ruins keep their footprint", () => {
  for (const id of ["house_timber", "house_log", "house_stone", "barn"]) {
    const h = p[id];
    assert.ok(h && h.parts, id);
    for (const sh of Object.values(h.parts)) for (const d of sh.size()) assert.ok(d <= 126, `${id} size ${d}`);
    const fp = new Set(h.footprint.map(([x, z]) => x + "," + z));
    for (const [x, z] of h.door) assert.ok(!fp.has(x + "," + z), id + " door free");
    assert.ok(h.interior.filter(([x, z]) => !fp.has(x + "," + z)).length >= 4, id + " walkable inside");
  }
  for (const id of ["timber", "log", "stone"]) assert.deepEqual(p["house_burnt_" + id].footprint, p["house_" + id].footprint, id);
  assert.deepEqual(p.cow.footprint, []);
  assert.ok(p.trough.footprint.length > 0);
});

test("ground details are tiny and block nothing", () => {
  for (const id of DECOR) {
    assert.ok(p[id], id);
    assert.deepEqual(p[id].footprint, [], id);
    for (const d of p[id].shape.size()) assert.ok(d <= 12, id + " is small");
  }
});
