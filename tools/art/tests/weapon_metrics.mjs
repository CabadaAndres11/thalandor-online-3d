// Test helper: how big a weapon's working end is. L: how far it reaches along the grip
// (+Z, max z); W: how wide it is across (y extent of the cells past the fist, z > 3).
export const ZFAMILIES = ["sword", "short_sword", "dagger", "axe", "mace", "scepter", "greatsword", "great_axe", "warhammer", "halberd"];
export function metrics(shape) {
  let L = -Infinity, ylo = Infinity, yhi = -Infinity;
  for (const [, y, z] of shape.cells.values()) {
    L = Math.max(L, z);
    if (z > 3) { ylo = Math.min(ylo, y); yhi = Math.max(yhi, y); }
  }
  return { L, W: yhi - ylo + 1 };
}
