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

test("Nhazar's head shows only its outside (hidden voxels behind the shell)", async () => {
  const { HIDDEN } = await import("../vox.mjs");
  const s = m.nhazar_head.shape;
  let faces = 0;
  for (const [x, y, z, i] of s.cells.values()) {
    if (i === HIDDEN) continue;
    for (const [dx, dy, dz] of [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]]) if (!s.cells.has(`${x + dx},${y + dy},${z + dz}`)) faces++;
  }
  assert.ok(faces < 160000, `${faces} faces drawn`);
});

test("robe hems stay off the ground (y -53)", () => {
  for (const id of ["cult_robe", "acolyte_robe", "vaelthar_robe"]) {
    let lo = Infinity;
    for (const [, y] of m[id].shape.cells.values()) lo = Math.min(lo, y);
    assert.ok(lo >= -52, `${id} reaches ${lo}`);
  }
});

// A hidden voxel draws nothing: if one touched the air outside, the floor behind would show
// through. Flood the air from outside the box and check no hidden voxel borders it.
test("Nhazar's head is watertight: no hidden voxel touches the outside air", async () => {
  const { HIDDEN } = await import("../vox.mjs");
  const s = m.nhazar_head.shape, [sx, sy, sz] = s.size(), [mx, my, mz] = s.min();
  const X = sx + 2, Y = sy + 2, Z = sz + 2, idx = (x, y, z) => (x * Y + y) * Z + z;
  const solid = new Uint8Array(X * Y * Z);
  for (const [x, y, z, i] of s.cells.values()) solid[idx(x - mx + 1, y - my + 1, z - mz + 1)] = i === HIDDEN ? 2 : 1;
  // The body's own head fills the hole the mass leaves round it (it is drawn).
  for (const [x, y, z] of body.head.shape.cells.values()) { const k = idx(x - mx + 1, y - my + 1, z - mz + 1); if (x - mx + 1 >= 0 && x - mx + 1 < X && y - my + 1 >= 0 && y - my + 1 < Y && z - mz + 1 >= 0 && z - mz + 1 < Z && !solid[k]) solid[k] = 1; }
  const air = new Uint8Array(X * Y * Z), stack = [0];
  air[0] = 1;
  while (stack.length) {
    const c = stack.pop(), z = c % Z, y = ((c - z) / Z) % Y, x = (c - z - y * Z) / (Y * Z);
    for (const [dx, dy, dz] of [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]]) {
      const nx = x + dx, ny = y + dy, nz = z + dz;
      if (nx < 0 || ny < 0 || nz < 0 || nx >= X || ny >= Y || nz >= Z) continue;
      const n = idx(nx, ny, nz);
      if (air[n]) continue;
      if (solid[n] === 2) assert.fail(`a hidden voxel at ${nx + mx - 1},${ny + my - 1},${nz + mz - 1} is open to the air`);
      if (solid[n]) continue;
      air[n] = 1;
      stack.push(n);
    }
  }
});
