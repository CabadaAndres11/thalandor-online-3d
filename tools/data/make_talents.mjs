// Generates data/talents.json (the circular talent tree, Anexo C) from the table below.
// Run: node tools/data/make_talents.mjs
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const DIRECTIONS = ['might', 'celerity', 'vitality', 'bastion', 'arcane'];

const m = (stat, value) => ({ type: 'stat', stat, value });

// Steps 1, 2, 3 (notable), 4 and the keystone of each pure spoke. The first modifier of
// a step is its "main bonus" (what hybrids copy at 60 %).
const TABLE = {
  might: [
    [m('attack_power_pct', 0.03)],
    [m('crit_add', 0.01)],
    [m('attack_power_pct', 0.04), m('crit_damage_add', 0.05)],
    [m('damage_done_pct', 0.02)],
    [m('attack_power_pct', 0.08), m('crit_damage_add', 0.10)],
  ],
  celerity: [
    [m('move_speed_pct', 0.03)],
    [m('dodge_add', 0.01)],
    [m('cooldown_reduction_add', 0.03), m('move_speed_pct', 0.03)],
    [m('cooldown_reduction_add', 0.02)],
    [m('cooldown_reduction_add', 0.08)],
  ],
  vitality: [
    [m('hp_regen_add', 1)],
    [m('healing_done_pct', 0.03)],
    [m('lifesteal_add', 0.01), m('healing_received_pct', 0.04)],
    [m('healing_received_pct', 0.03)],
    [m('healing_received_pct', 0.08), m('lifesteal_add', 0.02)],
  ],
  bastion: [
    [m('armor_pct', 0.04)],
    [m('max_hp_pct', 0.03)],
    [m('block_add', 0.02), m('damage_taken_pct', -0.02)],
    [m('armor_add', 15)],
    [m('max_hp_pct', 0.08), m('damage_taken_pct', -0.03)],
  ],
  arcane: [
    [m('spell_power_pct', 0.03)],
    [m('max_resource_pct', 0.04)],
    [m('crit_damage_add', 0.05), m('spell_power_pct', 0.04)],
    [m('resource_regen_pct', 0.05)],
    [m('spell_power_pct', 0.08)],
  ],
};

const round = (v) => Math.round(v * 100000) / 100000;
const scale = (mods, k) => mods.map((x) => ({ ...x, value: round(x.value * k) }));

// Radios in order around the circle: pure, hybrid, pure, hybrid...
const SPOKES = [];
DIRECTIONS.forEach((d, i) => {
  SPOKES.push({ id: d, dir: d, pure: true });
  SPOKES.push({ id: `${d}_${DIRECTIONS[(i + 1) % 5]}`, dir: `${d}_${DIRECTIONS[(i + 1) % 5]}`, a: d, b: DIRECTIONS[(i + 1) % 5], pure: false });
});

const nodes = {};
const link = (a, b) => {
  if (!nodes[a].links.includes(b)) nodes[a].links.push(b);
  if (!nodes[b].links.includes(a)) nodes[b].links.push(a);
};
const add = (id, kind, dir, ring, angle, radius, mods) => {
  nodes[id] = {
    kind, dir, ring,
    x: round(Math.sin(angle) * radius),
    y: round(-Math.cos(angle) * radius),
    mods, links: [],
  };
};

add('start', 'start', '', 1, 0, 0, []);

const RADII = [0.17, 0.29, 0.41, 0.53, 0.65, 0.77, 0.89]; // steps 1..4, key, 5, 6

SPOKES.forEach((s, i) => {
  const angle = (i * 2 * Math.PI) / SPOKES.length;
  const steps = []; // mods for steps 1..4 (and key for pure)
  for (let k = 0; k < 4; k++) {
    steps.push(s.pure ? TABLE[s.dir][k] : [
      ...scale([TABLE[s.a][k][0]], k === 2 ? 1 : 0.6),
      ...scale([TABLE[s.b][k][0]], k === 2 ? 1 : 0.6),
    ]);
  }
  const ids = [];
  for (let k = 0; k < 4; k++) {
    const id = `${s.id}_${k + 1}`;
    add(id, k === 2 ? 'notable' : 'minor', s.dir, 1, angle, RADII[k], steps[k]);
    ids.push(id);
  }
  link('start', ids[0]);
  for (let k = 0; k < 3; k++) link(ids[k], ids[k + 1]);
  let last = ids[3];
  let capMods = steps[2]; // ring 2 step 6 copies the notable (hybrids) or the keystone (pure)
  if (s.pure) {
    const key = `${s.id}_key`;
    add(key, 'keystone', s.dir, 1, angle, RADII[4], TABLE[s.dir][4]);
    link(ids[3], key);
    last = key;
    capMods = TABLE[s.dir][4];
  }
  const five = `${s.id}_5`;
  const six = `${s.id}_6`;
  add(five, 'minor', s.dir, 2, angle, RADII[5], scale(steps[0], 1.5));
  add(six, s.pure ? 'keystone' : 'notable', s.dir, 2, angle, RADII[6], scale(capMods, 1.5));
  link(last, five);
  link(five, six);
});

// Rings between neighbouring spokes: steps 1 and 3 (ring 1) and step 5 (ring 2).
SPOKES.forEach((s, i) => {
  const n = SPOKES[(i + 1) % SPOKES.length];
  link(`${s.id}_1`, `${n.id}_1`);
  link(`${s.id}_3`, `${n.id}_3`);
  link(`${s.id}_5`, `${n.id}_5`);
});

const out = { start: 'start', directions: DIRECTIONS, nodes };
writeFileSync(join(ROOT, 'data', 'talents.json'), JSON.stringify(out, null, 1) + '\n');
const ring = (r) => Object.values(nodes).filter((n) => n.ring === r).length;
console.log(`talents.json: ${Object.keys(nodes).length} nodes (ring 1: ${ring(1)}, ring 2: ${ring(2)})`);
