// Writes MagicaVoxel .vox files (version 150: MAIN > SIZE, XYZI, RGBA).
// Voxels are given in Godot axes (Y up) and stored in MagicaVoxel axes (Z up), the
// inverse of VoxFile's conversion: Godot (x, y, z) -> MagicaVoxel (x, z, y).
// Tintable palette indices (see game/characters/vox_mesher.gd):
export const TINT_HAIR = 250;
export const TINT_PRIMARY = 251;
export const TINT_SECONDARY = 252;
import fs from "node:fs";

function u32(v) {
  const b = Buffer.alloc(4);
  b.writeUInt32LE(v);
  return b;
}

function chunk(id, content, children = Buffer.alloc(0)) {
  return Buffer.concat([Buffer.from(id, "ascii"), u32(content.length), u32(children.length), content, children]);
}

// size: [x, y, z] (Godot); voxels: [[x, y, z, index]] (Godot); palette: {index: "#rrggbb"}.
export function write(path, size, voxels, palette = {}) {
  for (const v of voxels) {
    if (v[0] < 0 || v[1] < 0 || v[2] < 0 || v[0] >= size[0] || v[1] >= size[1] || v[2] >= size[2]) {
      throw new Error(`${path}: voxel ${v} outside size ${size}`);
    }
  }
  const sizeData = Buffer.concat([u32(size[0]), u32(size[2]), u32(size[1])]);
  const xyzi = Buffer.alloc(4 + voxels.length * 4);
  xyzi.writeUInt32LE(voxels.length);
  voxels.forEach((v, i) => xyzi.set([v[0], v[2], v[1], v[3]], 4 + i * 4));
  const rgba = Buffer.alloc(256 * 4);
  for (let i = 1; i < 256; i++) {
    const hex = palette[i] ?? "#999999";
    rgba.set([parseInt(hex.slice(1, 3), 16), parseInt(hex.slice(3, 5), 16), parseInt(hex.slice(5, 7), 16), 255], (i - 1) * 4);
  }
  const main = chunk("MAIN", Buffer.alloc(0), Buffer.concat([chunk("SIZE", sizeData), chunk("XYZI", xyzi), chunk("RGBA", rgba)]));
  fs.writeFileSync(path, Buffer.concat([Buffer.from("VOX ", "ascii"), u32(150), main]));
}

// Small builder: a set of voxels with box/layer helpers (later calls overwrite).
export class Shape {
  constructor() {
    this.cells = new Map();
  }
  put(x, y, z, index) {
    this.cells.set(`${x},${y},${z}`, [x, y, z, index]);
    return this;
  }
  box(x0, y0, z0, x1, y1, z1, index) {
    for (let x = x0; x <= x1; x++) for (let y = y0; y <= y1; y++) for (let z = z0; z <= z1; z++) this.put(x, y, z, index);
    return this;
  }
  remove(x0, y0, z0, x1, y1, z1) {
    for (let x = x0; x <= x1; x++) for (let y = y0; y <= y1; y++) for (let z = z0; z <= z1; z++) this.cells.delete(`${x},${y},${z}`);
    return this;
  }
  // Lowest corner of the shape (may be negative).
  min() {
    const m = [Infinity, Infinity, Infinity];
    for (const v of this.cells.values()) for (let i = 0; i < 3; i++) m[i] = Math.min(m[i], v[i]);
    return m;
  }
  // Voxels moved so the shape starts at (0, 0, 0).
  voxels() {
    const m = this.min();
    return [...this.cells.values()].map((v) => [v[0] - m[0], v[1] - m[1], v[2] - m[2], v[3]]);
  }
  size() {
    const m = this.min();
    const s = [0, 0, 0];
    for (const v of this.cells.values()) for (let i = 0; i < 3; i++) s[i] = Math.max(s[i], v[i] - m[i] + 1);
    return s;
  }
}
