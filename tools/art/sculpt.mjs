// Voxel sculpting: rounded shapes rasterized into a Shape (vox.mjs) and painting rules,
// so organic volumes (skulls, shoulders, calves, folds) are written as a few primitives
// instead of box after box. Coordinates are voxel centres on Godot axes (Y up, faces +Z).
// Every operation is deterministic: the same input always gives the same voxels.

const EPS = 1e-4;

// Fills every integer cell in [lo, hi] (inclusive, per axis) where inside(x, y, z).
function fill(s, lo, hi, idx, inside) {
  for (let x = Math.floor(lo[0]); x <= Math.ceil(hi[0]); x++)
    for (let y = Math.floor(lo[1]); y <= Math.ceil(hi[1]); y++)
      for (let z = Math.floor(lo[2]); z <= Math.ceil(hi[2]); z++)
        if (inside(x, y, z)) s.put(x, y, z, idx);
  return s;
}

export function ellipsoid(s, c, r, idx) {
  return fill(s, c.map((v, i) => v - r[i]), c.map((v, i) => v + r[i]), idx, (x, y, z) =>
    ((x - c[0]) / r[0]) ** 2 + ((y - c[1]) / r[1]) ** 2 + ((z - c[2]) / r[2]) ** 2 <= 1 + EPS);
}

// Where p projects on segment a-b (0..1, clamped) and its distance to that point.
function onSegment(p, a, b) {
  const d = [b[0] - a[0], b[1] - a[1], b[2] - a[2]];
  const len2 = d[0] ** 2 + d[1] ** 2 + d[2] ** 2 || 1;
  const raw = ((p[0] - a[0]) * d[0] + (p[1] - a[1]) * d[1] + (p[2] - a[2]) * d[2]) / len2;
  const t = Math.min(1, Math.max(0, raw));
  const q = [a[0] + d[0] * t, a[1] + d[1] * t, a[2] + d[2] * t];
  return { t, raw, dist: Math.hypot(p[0] - q[0], p[1] - q[1], p[2] - q[2]) };
}

// A tapered capsule: radius ra at a, rb at b, rounded ends.
export function capsule(s, a, b, ra, rb, idx) {
  const r = Math.max(ra, rb);
  const lo = [0, 1, 2].map((i) => Math.min(a[i], b[i]) - r);
  const hi = [0, 1, 2].map((i) => Math.max(a[i], b[i]) + r);
  return fill(s, lo, hi, idx, (x, y, z) => {
    const { t, dist } = onSegment([x, y, z], a, b);
    return dist <= ra + (rb - ra) * t + EPS;
  });
}

// A flat-ended cylinder from a to b.
export function cylinder(s, a, b, r, idx) {
  const lo = [0, 1, 2].map((i) => Math.min(a[i], b[i]) - r);
  const hi = [0, 1, 2].map((i) => Math.max(a[i], b[i]) + r);
  return fill(s, lo, hi, idx, (x, y, z) => {
    const { raw, dist } = onSegment([x, y, z], a, b);
    return raw >= -EPS && raw <= 1 + EPS && dist <= r + EPS;
  });
}

// A box from lo to hi (inclusive) with edges rounded by `radius`.
export function roundBox(s, lo, hi, radius, idx) {
  const inLo = lo.map((v) => v + radius), inHi = hi.map((v, i) => Math.max(v - radius, inLo[i]));
  return fill(s, lo, hi, idx, (x, y, z) => {
    const p = [x, y, z];
    const d = p.map((v, i) => Math.max(inLo[i] - v, 0, v - inHi[i]));
    return Math.hypot(d[0], d[1], d[2]) <= radius + EPS;
  });
}

// Removes from s every cell that build(tmp) puts in a temporary shape.
export function carve(s, build) {
  const tmp = { cells: new Map(), put(x, y, z, i) { this.cells.set(`${x},${y},${z}`, [x, y, z, i]); return this; } };
  build(tmp);
  for (const key of tmp.cells.keys()) s.cells.delete(key);
  return s;
}

// Copies every cell to its reflection about x = axis (bodies are symmetric about -0.5).
export function mirrorX(s, axis = -0.5) {
  for (const [x, y, z, i] of [...s.cells.values()]) s.put(Math.round(2 * axis - x), y, z, i);
  return s;
}

export function noise3(x, y, z, seed = 0) {
  const n = Math.sin(x * 12.9898 + y * 78.233 + z * 37.719 + seed * 4.1414) * 43758.5453;
  return n - Math.floor(n);
}

// Recolours the cells of `idx` with a mix of [base, shade, light] (fractions `mix`).
export function tone(s, idx, tones, seed = 0, mix = [0.6, 0.25, 0.15]) {
  for (const v of s.cells.values()) {
    if (v[3] !== idx) continue;
    const n = noise3(v[0], v[1], v[2], seed);
    v[3] = n < mix[0] ? tones[0] : n < mix[0] + mix[1] ? tones[1] : tones[2];
  }
  return s;
}

// Surface cells of the given indices: empty above → light tone; else empty below or
// behind (-Z) → shade tone. `map` is {index: {shade, light}}.
export function shadeByFacing(s, idxs, map) {
  const empty = (x, y, z) => !s.cells.has(`${x},${y},${z}`);
  const changes = [];
  for (const [x, y, z, i] of s.cells.values()) {
    if (!idxs.includes(i) || !map[i]) continue;
    if (empty(x, y + 1, z)) changes.push([x, y, z, map[i].light]);
    else if (empty(x, y - 1, z) || empty(x, y, z - 1)) changes.push([x, y, z, map[i].shade]);
  }
  for (const [x, y, z, i] of changes) s.put(x, y, z, i);
  return s;
}
