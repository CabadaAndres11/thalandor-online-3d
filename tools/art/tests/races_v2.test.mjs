// Plan 7: race heads, race pieces, new hair, beards, crests and face marks.
import { test } from "node:test";
import assert from "node:assert/strict";
import { headV2 } from "../human_v2.mjs";
import { raceHeadsV2 } from "../races_v2.mjs";
import { piecesV2 } from "../make_pieces_v2.mjs";
import { TINT_HAIR, TEX_D, TEX_L, SHADE, LIGHT } from "../vox.mjs";

const v2 = piecesV2();
const NEW_HAIR = ["hair_braids", "hair_undercut", "hair_loose", "hair_high_ponytail", "hair_warrior_braid", "hair_curls", "hair_shaggy", "hair_half_up"];
const NEW_BEARDS = ["beard_dwarf_braided", "beard_dwarf_forked", "beard_sideburns", "beard_chinstrap", "beard_stubble"];
const MARKS = ["mark_scar_eye", "mark_scar_cheek", "mark_warpaint", "mark_runes", "mark_freckles"];
const CRESTS = ["crest_fin", "crest_spikes", "crest_frill", "crest_horns"];
const HAIR_TONES = [TINT_HAIR, TEX_D(TINT_HAIR), TEX_L(TINT_HAIR), SHADE(TINT_HAIR), LIGHT(TINT_HAIR)];

const neckBase = (s) => [...s.cells.values()].filter(([x, y, z]) => y <= 1 && x >= -4 && x <= 3 && z >= -3 && z <= 3).length;

test("ogre and lizard heads sit on the same neck pivot as the human head", () => {
  const heads = raceHeadsV2();
  for (const id of ["ogre", "lizard"]) {
    assert.ok(heads[id], id);
    assert.ok(neckBase(heads[id]) > 0, `${id} reaches the neck`);
    assert.ok(Math.min(...[...heads[id].cells.values()].map((c) => c[1])) >= -2, `${id} not sunk into the torso`);
  }
  assert.ok(neckBase(headV2()) > 0);
});

test("the lizard head has a snout and the ogre head is bigger than the human one", () => {
  const heads = raceHeadsV2();
  const maxZ = (s) => Math.max(...[...s.cells.values()].map((c) => c[2]));
  const width = (s) => { const xs = [...s.cells.values()].map((c) => c[0]); return Math.max(...xs) - Math.min(...xs); };
  assert.ok(maxZ(heads.lizard) >= maxZ(headV2()) + 4, "snout");
  assert.ok(width(heads.ogre) > width(headV2()), "ogre width");
});

test("race pieces exist on their parts with their tags", () => {
  assert.equal(v2.ears_elf.part, "head");
  assert.equal(v2.ears_elf.tag, "ears");
  assert.equal(v2.nose_dwarf.part, "head");
  assert.equal(v2.tail_lizard.part, "hips");
  assert.ok(v2.tail_lizard.shape.cells.size > 100, "a real tail");
});

test("crests are hair-tinted pieces on the lizard head", () => {
  for (const id of CRESTS) {
    assert.ok(v2[id], id);
    assert.equal(v2[id].tag, "hair", id);
    assert.ok([...v2[id].shape.cells.values()].every((c) => HAIR_TONES.includes(c[3])), `${id} uses the hair tint`);
  }
});

test("every new hair, beard and mark exists on the head", () => {
  for (const id of [...NEW_HAIR, ...NEW_BEARDS, ...MARKS]) {
    assert.ok(v2[id], id);
    assert.equal(v2[id].part, "head", id);
    assert.ok(v2[id].shape.cells.size > 4, `${id} has voxels`);
  }
  for (const id of NEW_HAIR) assert.equal(v2[id].tag, "hair", id);
});

test("new pieces never overlap the human head and fit a vox model", () => {
  const head = headV2();
  for (const id of [...NEW_HAIR, ...NEW_BEARDS, ...MARKS, "ears_elf", "nose_dwarf"]) {
    for (const key of v2[id].shape.cells.keys()) assert.ok(!head.cells.has(key), `${id} at ${key}`);
  }
  for (const id of [...NEW_HAIR, ...NEW_BEARDS, ...MARKS, ...CRESTS, "ears_elf", "nose_dwarf", "tail_lizard"]) {
    for (const d of v2[id].shape.size()) assert.ok(d <= 126, `${id} size ${d}`);
  }
});
