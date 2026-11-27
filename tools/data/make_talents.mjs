// Generates data/talents.json (Plan 8.3g): the talent tree in seven closed rings around a
// common start, every ring linked to the next, the five directions mixing at their borders,
// values growing outward, and a recommended route per class.
// Run: node tools/data/make_talents.mjs
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { formatJson } from '../json_format.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

export const DIRECTIONS = ['might', 'celerity', 'vitality', 'bastion', 'arcane'];
export const RINGS = 7;
const BLEND_AT = 0.4; // |offset from a direction's centre| / 36° from which a node mixes two directions

// The stats of each direction, in the order the nodes cycle through them.
export const POOLS = {
  might: ['attack_power_pct', 'crit_add', 'crit_damage_add', 'damage_done_pct'],
  celerity: ['move_speed_pct', 'dodge_add', 'cooldown_reduction_add'],
  vitality: ['hp_regen_add', 'lifesteal_add', 'healing_done_pct', 'healing_received_pct'],
  bastion: ['armor_pct', 'max_hp_pct', 'block_add', 'armor_add', 'damage_taken_pct', 'threat_pct'],
  arcane: ['spell_power_pct', 'max_resource_pct', 'resource_regen_pct'],
};
// What a small node gives on ring 1 (the old tree's small nodes); outer rings give more.
export const BASE = {
  attack_power_pct: 0.03, crit_add: 0.01, crit_damage_add: 0.05, damage_done_pct: 0.02,
  move_speed_pct: 0.03, dodge_add: 0.01, cooldown_reduction_add: 0.02,
  hp_regen_add: 1, lifesteal_add: 0.01, healing_done_pct: 0.03, healing_received_pct: 0.03,
  armor_pct: 0.04, armor_add: 15, max_hp_pct: 0.03, block_add: 0.02, damage_taken_pct: -0.02, threat_pct: 0.1,
  spell_power_pct: 0.03, max_resource_pct: 0.04, resource_regen_pct: 0.05,
};
// The icon (assets/icons/talents/<name>.png) of each stat.
export const STAT_ICON = {
  attack_power_pct: 'attack_power', spell_power_pct: 'spell_power', crit_add: 'crit', crit_damage_add: 'crit_damage',
  damage_done_pct: 'damage_done', damage_taken_pct: 'damage_taken', move_speed_pct: 'move_speed', dodge_add: 'dodge',
  block_add: 'block', armor_add: 'armor', armor_pct: 'armor', max_hp_pct: 'max_hp', hp_regen_add: 'hp_regen',
  lifesteal_add: 'lifesteal', healing_done_pct: 'healing_done', healing_received_pct: 'healing_received',
  max_resource_pct: 'max_resource', resource_regen_pct: 'resource_regen', cooldown_reduction_add: 'cooldown', threat_pct: 'threat',
};

const round = (v) => Math.round(v * 100000) / 100000;
const ringMult = (r) => 1 + (r - 1) / 6;
const mod = (stat, k) => ({ type: 'stat', stat, value: round(BASE[stat] * k) });
export const count = (r) => 10 * r;

export function buildTree() {
  const nodes = {};
  const link = (a, b) => {
    if (!nodes[a].links.includes(b)) nodes[a].links.push(b);
    if (!nodes[b].links.includes(a)) nodes[b].links.push(a);
  };
  nodes.start = { kind: 'start', dir: '', mix: '', ring: 0, x: 0, y: 0, icon: '', mods: [], links: [] };
  for (let r = 1; r <= RINGS; r++) {
    const n = count(r);
    for (let i = 0; i < n; i++) {
      const deg = (360 * i) / n;
      const d = Math.round(deg / 72) % 5;
      const t = (deg - Math.round(deg / 72) * 72) / 36; // -1..1 from the centre of `d`
      const dir = DIRECTIONS[d];
      const mix = Math.abs(t) >= BLEND_AT ? DIRECTIONS[(d + (t > 0 ? 1 : 4)) % 5] : '';
      const keystone = (r === 4 || r === RINGS) && Math.abs(t) < 1e-9;
      const kind = keystone ? 'keystone' : r >= 2 && i % 5 === 2 ? 'notable' : 'minor';
      const k = ringMult(r);
      const pool = POOLS[dir];
      const p = (r + i) % pool.length;
      let mods;
      if (kind === 'keystone') mods = [mod(pool[0], 2.5 * k), mod(pool[1], 2.5 * k)];
      else if (kind === 'notable') {
        mods = [mod(pool[p], k), mod(pool[(p + 1) % pool.length], k)];
        if (mix) mods.push(mod(POOLS[mix][(r + i) % POOLS[mix].length], 0.5 * k));
      } else if (mix) mods = [mod(pool[p], 0.6 * k), mod(POOLS[mix][(r + i) % POOLS[mix].length], 0.6 * k)];
      else mods = [mod(pool[p], k)];
      const a = (2 * Math.PI * i) / n;
      nodes[`r${r}_${i}`] = {
        kind, dir, mix, ring: r,
        x: round(Math.sin(a) * 0.13 * r), y: round(-Math.cos(a) * 0.13 * r),
        icon: STAT_ICON[mods[0].stat], mods, links: [],
      };
    }
  }
  for (let r = 1; r <= RINGS; r++) {
    const n = count(r);
    for (let i = 0; i < n; i++) {
      link(`r${r}_${i}`, `r${r}_${(i + 1) % n}`); // the ring is closed
      if (r === 1) link(`r1_${i}`, 'start');
      else if (i % 2 === 0) link(`r${r}_${i}`, `r${r - 1}_${Math.round((i * count(r - 1)) / n) % count(r - 1)}`);
    }
  }
  return { start: 'start', directions: DIRECTIONS, nodes };
}

// How much each class wants of each stat (its recommended route follows them).
export const PRIORITIES = {
  warrior: { armor_pct: 3, max_hp_pct: 3, attack_power_pct: 3, block_add: 2, damage_taken_pct: 2, armor_add: 2, threat_pct: 1, crit_add: 1, hp_regen_add: 1 },
  cleric: { healing_done_pct: 3, spell_power_pct: 3, max_resource_pct: 2, resource_regen_pct: 2, max_hp_pct: 1, armor_pct: 1, cooldown_reduction_add: 1 },
  mage: { spell_power_pct: 3, crit_add: 2, crit_damage_add: 2, max_resource_pct: 2, resource_regen_pct: 2, cooldown_reduction_add: 2 },
  archer: { attack_power_pct: 3, crit_add: 3, crit_damage_add: 2, move_speed_pct: 2, dodge_add: 2, damage_done_pct: 2 },
  assassin: { attack_power_pct: 3, crit_damage_add: 3, crit_add: 2, dodge_add: 2, damage_done_pct: 2, lifesteal_add: 2, move_speed_pct: 1 },
};
export const ROUTE_LENGTH = 100;

// The recommended route of each class: 100 nodes, each bought next to the start or to an
// earlier one, choosing the most valuable for the class with a one-step look ahead.
export function buildRoutes(tree) {
  const nodes = tree.nodes;
  const order = (id) => { const [r, i] = id.slice(1).split('_').map(Number); return r * 1000 + i; };
  const routes = {};
  for (const [cls, want] of Object.entries(PRIORITIES)) {
    const score = (id) => nodes[id].mods.reduce((s, m) => s + (want[m.stat] ?? 0) * Math.abs(m.value) / Math.abs(BASE[m.stat]), 0);
    const owned = new Set([tree.start]);
    const route = [];
    while (route.length < ROUTE_LENGTH) {
      let best = null, bestValue = -1;
      for (const id of Object.keys(nodes)) {
        if (owned.has(id) || !nodes[id].links.some((n) => owned.has(n))) continue;
        const ahead = Math.max(0, ...nodes[id].links.filter((n) => !owned.has(n)).map(score));
        const value = score(id) + 0.5 * ahead;
        if (value > bestValue || (value === bestValue && order(id) < order(best))) { best = id; bestValue = value; }
      }
      owned.add(best);
      route.push(best);
    }
    routes[cls] = route;
  }
  return routes;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const tree = buildTree();
  const out = { ...tree, routes: buildRoutes(tree) };
  writeFileSync(join(ROOT, 'data', 'talents.json'), formatJson(out));
  console.log(`talents.json: ${Object.keys(tree.nodes).length} nodes in ${RINGS} rings`);
}
