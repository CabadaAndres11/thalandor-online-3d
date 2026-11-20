import { test } from "node:test";
import assert from "node:assert/strict";
import { Shape } from "../vox.mjs";
import { ellipsoid, capsule, cylinder, roundBox, carve, mirrorX, tone, shadeByFacing, noise3 } from "../sculpt.mjs";

const xs = (s) => [...s.cells.values()].map((v) => v[0]);
const ys = (s) => [...s.cells.values()].map((v) => v[1]);
const has = (s, x, y, z) => s.cells.has(`${x},${y},${z}`);

test("ellipsoid is symmetric and has the right extent", () => {
  const s = ellipsoid(new Shape(), [0, 0, 0], [3, 2, 3], 5);
  assert.equal(Math.min(...xs(s)), -3);
  assert.equal(Math.max(...xs(s)), 3);
  assert.equal(Math.max(...ys(s)), 2);
  assert.ok(has(s, 0, 0, 0) && has(s, 3, 0, 0) && has(s, -3, 0, 0));
  assert.ok(!has(s, 3, 2, 3), "corners are rounded off");
});

test("capsule spans both ends with each radius", () => {
  const s = capsule(new Shape(), [0, 0, 0], [0, 10, 0], 3, 1, 7);
  assert.equal(Math.min(...ys(s)), -3);
  assert.equal(Math.max(...ys(s)), 11);
  assert.ok(has(s, 3, 0, 0), "wide end");
  assert.ok(!has(s, 3, 10, 0), "narrow end");
  assert.ok(has(s, 1, 10, 0));
});

test("cylinder and roundBox fill their bounds", () => {
  const c = cylinder(new Shape(), [0, 0, 0], [0, 4, 0], 2, 1);
  assert.ok(has(c, 2, 0, 0) && has(c, 0, 4, 0) && !has(c, 0, 5, 0));
  const b = roundBox(new Shape(), [0, 0, 0], [6, 6, 6], 2, 1);
  assert.ok(has(b, 3, 3, 3) && has(b, 0, 3, 3) && !has(b, 0, 0, 0));
});

test("carve removes cells", () => {
  const s = ellipsoid(new Shape(), [0, 0, 0], [4, 4, 4], 5);
  carve(s, (t) => ellipsoid(t, [0, 0, 0], [2, 2, 2], 1));
  assert.ok(!has(s, 0, 0, 0));
  assert.ok(has(s, 4, 0, 0));
});

test("mirrorX reflects about -0.5", () => {
  const s = new Shape().put(2, 1, 0, 9);
  mirrorX(s);
  assert.ok(has(s, -3, 1, 0));
  const t = new Shape().put(3, 0, 0, 9);
  mirrorX(t, 0);
  assert.ok(has(t, -3, 0, 0));
});

test("tone is deterministic and only uses given tones", () => {
  const make = () => tone(ellipsoid(new Shape(), [0, 0, 0], [5, 5, 5], 5), 5, [5, 6, 7], 42);
  const a = make(), b = make();
  assert.deepEqual([...a.cells.values()], [...b.cells.values()]);
  const used = new Set([...a.cells.values()].map((v) => v[3]));
  for (const i of used) assert.ok([5, 6, 7].includes(i));
  assert.ok(used.size === 3, "all three tones appear");
  const other = tone(new Shape().put(0, 0, 0, 9), 5, [5, 6, 7], 1);
  assert.equal(other.cells.get("0,0,0")[3], 9, "other indices untouched");
});

test("shadeByFacing darkens bottom faces and lights top faces", () => {
  const s = roundBox(new Shape(), [0, 0, 0], [4, 4, 4], 0, 5);
  shadeByFacing(s, [5], { 5: { shade: 6, light: 7 } }, 0.6, -0.45, -0.75);
  assert.equal(s.cells.get("2,0,2")[3], 6, "bottom");
  assert.equal(s.cells.get("2,4,2")[3], 7, "top");
  assert.equal(s.cells.get("2,2,2")[3], 5, "inside");
  assert.equal(s.cells.get("2,2,0")[3], 6, "back");
});

test("noise3 is stable and in [0,1)", () => {
  assert.equal(noise3(1, 2, 3, 4), noise3(1, 2, 3, 4));
  for (let i = 0; i < 100; i++) {
    const n = noise3(i, i * 3, -i, 7);
    assert.ok(n >= 0 && n < 1);
  }
});

test("mirrorX copies only the drawn (+x) half", () => {
  const s = new Shape().put(2, 0, 0, 9).put(-3, 0, 0, 1);
  mirrorX(s);
  assert.equal(s.cells.get("-3,0,0")[3], 9, "the + side wins");
  assert.equal(s.cells.get("2,0,0")[3], 9, "the + side is not overwritten");
});

test("shadeByFacing ignores the small steps of a curved surface", () => {
  const s = ellipsoid(new Shape(), [0, 0, 0], [8, 8, 8], 5);
  shadeByFacing(s, [5], { 5: { shade: 6, light: 7 } });
  // A cell on the equator, front side: it faces +Z, so it keeps its colour.
  assert.equal(s.cells.get("0,0,8")[3], 5);
  assert.equal(s.cells.get("0,-8,0")[3], 6, "the bottom is shaded");
  assert.equal(s.cells.get("0,8,0")[3], 7, "the top is lit");
  // Front cells just above the equator stay unshaded (no stair-step speckle).
  for (let y = -3; y <= 3; y++) {
    const z = Math.max(...[...s.cells.values()].filter((v) => v[0] === 0 && v[1] === y).map((v) => v[2]));
    assert.equal(s.cells.get(`0,${y},${z}`)[3], 5, `y=${y}`);
  }
});

test("shellAround wraps a shape without touching it", async () => {
  const { shellAround } = await import("../sculpt.mjs");
  const src = ellipsoid(new Shape(), [0, 0, 0], [4, 4, 4], 5);
  const shell = shellAround(src, 2, 9, (x, y) => y >= 0);
  for (const key of shell.cells.keys()) assert.ok(!src.cells.has(key), "outside the source");
  assert.ok(shell.cells.has("0,5,0") && shell.cells.has("0,6,0"), "two layers over the top");
  assert.ok(!shell.cells.has("0,7,0"));
  assert.ok(!shell.cells.has("0,-5,0"), "filter keeps y >= 0");
  for (const v of shell.cells.values()) assert.equal(v[3], 9);
});

test("a cylinder with both ends at one point is a one-voxel disc, not a sphere", () => {
  const s = cylinder(new Shape(), [0, 5, 0], [0, 5, 0], 4, 1);
  assert.ok(has(s, 4, 5, 0) && has(s, 0, 5, -4));
  for (const v of s.cells.values()) assert.equal(v[1], 5, "flat");
});
