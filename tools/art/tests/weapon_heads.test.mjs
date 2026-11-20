import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { gearWeaponsV2, BLADE_TONES } from "../gear_weapons_v2.mjs";
import { metrics, ZFAMILIES } from "./weapon_metrics.mjs";

// Plan 6.3.3: bigger, thicker, three-toned blades and heads that read apart by silhouette.
const w = gearWeaponsV2();
const before = JSON.parse(fs.readFileSync(new URL("./weapon_sizes_0.9.2.json", import.meta.url)));
const CY = -4.5;
const BLADED = ["sword", "short_sword", "dagger", "greatsword", "axe", "great_axe", "halberd"];

test("heads and blades are at least 20 % bigger than in 0.9.2", () => {
  for (const f of ZFAMILIES) for (const t of [1, 2, 3]) {
    const id = `w_${f}_t${t}`, now = metrics(w[id].shape), was = before[id];
    assert.ok(now.L - 3 >= (was.L - 3) * 1.2, `${id} reach ${now.L} vs ${was.L}`);
    assert.ok(now.W >= was.W * 1.15, `${id} width ${now.W} vs ${was.W}`);
  }
});

test("blades are thick in the middle", () => {
  for (const f of ["sword", "short_sword", "dagger", "greatsword"]) for (const t of [1, 2, 3]) {
    const s = w[`w_${f}_t${t}`].shape, L = metrics(s).L;
    const mid = Math.round(6 + (L - 6) * 0.45);
    const xs = new Set([...s.cells.values()].filter(([, y, z]) => z === mid && Math.abs(y - CY) <= 1).map(([x]) => x));
    assert.ok(xs.size >= 3, `${f} t${t}: ${xs.size} voxels thick at z ${mid}`);
  }
});

test("every blade has a dark core, a body and a bright edge", () => {
  for (const f of BLADED) for (const t of [1, 2, 3]) {
    const tones = BLADE_TONES(t), idx = new Set([...w[`w_${f}_t${t}`].shape.cells.values()].map((v) => v[3]));
    for (const k of ["core", "body", "edge"]) assert.ok(idx.has(tones[k]), `${f} t${t} has its ${k} tone`);
  }
});

test("families read apart by their side silhouette", () => {
  const profile = (f) => new Set([...w[`w_${f}_t2`].shape.cells.values()].filter(([, , z]) => z > 3).map(([, y, z]) => `${Math.round(y - CY)},${z}`));
  const fams = ZFAMILIES;
  for (let i = 0; i < fams.length; i++) for (let j = i + 1; j < fams.length; j++) {
    const a = profile(fams[i]), b = profile(fams[j]);
    let both = 0;
    for (const k of a) if (b.has(k)) both++;
    const jaccard = both / (a.size + b.size - both);
    assert.ok(jaccard < 0.6, `${fams[i]} vs ${fams[j]} overlap ${jaccard.toFixed(2)}`);
  }
});

test("each tier is bigger than the last", () => {
  for (const f of ZFAMILIES) {
    const m = [1, 2, 3].map((t) => metrics(w[`w_${f}_t${t}`].shape));
    assert.ok(m[2].L * m[2].W > m[0].L * m[0].W, f);
  }
});

test("deterministic", () => {
  const again = gearWeaponsV2();
  for (const id of Object.keys(w)) assert.equal(again[id].shape.cells.size, w[id].shape.cells.size, id);
});
