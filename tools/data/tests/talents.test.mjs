// Plan 8.3g: the talent tree in seven closed rings (tools/data/make_talents.mjs).
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { buildTree } from "../make_talents.mjs";

const STATS = ["attack_power_pct", "spell_power_pct", "crit_add", "crit_damage_add", "damage_done_pct", "damage_taken_pct",
  "move_speed_pct", "dodge_add", "block_add", "armor_add", "armor_pct", "max_hp_pct", "hp_regen_add", "lifesteal_add",
  "healing_done_pct", "healing_received_pct", "max_resource_pct", "resource_regen_pct", "cooldown_reduction_add", "threat_pct"];
const tree = buildTree();
const nodes = tree.nodes;
const ids = Object.keys(nodes);

test("seven closed rings of 10·r nodes around the start", () => {
  assert.equal(ids.length, 281);
  for (let r = 1; r <= 7; r++) {
    const count = 10 * r;
    assert.equal(ids.filter((id) => nodes[id].ring === r && id !== "start").length, count, `ring ${r}`);
    for (let i = 0; i < count; i++) {
      const links = nodes[`r${r}_${i}`].links;
      assert.ok(links.includes(`r${r}_${(i + 1) % count}`) && links.includes(`r${r}_${(i + count - 1) % count}`), `r${r}_${i} closes its ring`);
    }
  }
});

test("everything reaches the start", () => {
  const seen = new Set(["start"]);
  const queue = ["start"];
  while (queue.length) for (const n of nodes[queue.pop()].links) if (!seen.has(n)) { seen.add(n); queue.push(n); }
  assert.equal(seen.size, ids.length);
});

test("links are symmetric", () => {
  for (const id of ids) for (const n of nodes[id].links) assert.ok(nodes[n].links.includes(id), `${id} <-> ${n}`);
});

test("only known stats, values grow outward", () => {
  const max = {}; // stat -> {1: max |value| on ring 1, 7: on ring 7}
  for (const id of ids) {
    for (const m of nodes[id].mods) {
      assert.ok(STATS.includes(m.stat), m.stat);
      max[m.stat] ??= {};
      max[m.stat][nodes[id].ring] = Math.max(max[m.stat][nodes[id].ring] ?? 0, Math.abs(m.value));
    }
  }
  for (const [stat, byRing] of Object.entries(max)) if (byRing[1] && byRing[7]) assert.ok(byRing[7] > byRing[1], stat);
});

test("five keystones on rings 4 and 7, notables between", () => {
  const keys = ids.filter((id) => nodes[id].kind === "keystone");
  assert.equal(keys.length, 10);
  assert.deepEqual([...new Set(keys.map((id) => nodes[id].ring))].sort(), [4, 7]);
  for (const id of keys) {
    const angle = (Math.atan2(nodes[id].x, -nodes[id].y) * 180) / Math.PI;
    const dir = tree.directions[Math.round((((angle % 360) + 360) % 360) / 72) % 5];
    assert.equal(nodes[id].dir, dir, id);
  }
  assert.ok(ids.filter((id) => nodes[id].kind === "notable").length >= 40);
});

test("every node has an icon file", () => {
  for (const id of ids) {
    if (id === "start") continue;
    assert.ok(fs.existsSync(`assets/icons/talents/${nodes[id].icon}.png`), `${id}: ${nodes[id].icon}`);
  }
});
