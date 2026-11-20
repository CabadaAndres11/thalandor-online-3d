// Test helper: the longest side (in voxels) of a .vox file's model (SIZE chunk).
import fs from "node:fs";
export function VoxRead(url) {
  const b = fs.readFileSync(url);
  const i = b.indexOf("SIZE");
  const x = b.readUInt32LE(i + 12), y = b.readUInt32LE(i + 16), z = b.readUInt32LE(i + 20);
  return Math.max(x, y, z);
}
