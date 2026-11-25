class_name SimWorld
extends RefCounted
## Authoritative world: tick counter, players, the seeded random generator and the
## collision map. Only the host runs combat on it.

var tick: int = 0
var players: Dictionary = {} # int -> PlayerState
var balance: Balance
var map: CollisionMap
## The only source of randomness in the simulation (seeded per game).
var rng := RandomNumberGenerator.new()
## Combat events of the current tick (arrays like ["hit", target_id, amount, crit,
## source_id]); the host sends them and clears the list at the start of each tick.
var events: Array = []
var abilities: AbilityDB = AbilityDB.load_default()
## Class upgrades (level 50), see UpgradeDB.
var upgrades: UpgradeDB = UpgradeDB.load_default()
## Items, loot and merchant numbers (data/items), see ItemDB.
var items: ItemDB = ItemDB.load_default()
## Quests (Plan 8.2), see QuestDB and QuestRules.
var quests: QuestDB = QuestDB.load_default()
## Items lying on the ground: drop id -> {owner, item: Item, pos, expire_tick, warned} (see Loot).
var loot: Dictionary = {}
## Non-player entities (monsters; test dummies), id -> CombatEntity.
var monsters: Dictionary = {}
var projectiles: Array = [] # Projectile
var pending_areas: Array = [] # PendingArea
var traps: Array = [] # Trap
var pending_casts: Array = [] # PendingCast (abilities with a repeat block)
var _next_object_id: int = 1
## Hits landed by the cast being resolved (assassin combo points).
var cast_hits: int = 0
## Entities that died during the cast being resolved (refund_on_kill), and the id of whoever
## dealt the damage being applied (on_kill hooks), and cooldown seconds given back by this
## cast (freeze_reduces_cooldowns).
var cast_kills: int = 0
var current_source: int = 0
var cast_cd_reduced: float = 0.0
var _next_monster_id: int = 999
var _pathfinder: Pathfinder
## Keeps the map's monster spawn points populated (null when the map has none).
var spawner: Spawner


func emit(ev: Array) -> void:
	events.append(ev)


## Ids for projectiles and areas (their own sequence, separate from entity ids).
func next_object_id() -> int:
	_next_object_id += 1
	return _next_object_id


## Level of the monsters the arena spawns (Brann sets it, 1..60).
var arena_level: int = 1
## The level of a dungeon instance (Plan 8.1): its hordes use it instead of their band.
## 0 in the open world.
var instance_level: int = 0


## Changes the arena level; idle monsters (no target, no threat) are rebuilt at the new
## level on the spot, the rest take it when they respawn.
func set_arena_level(level: int) -> void:
	arena_level = clampi(level, int(balance.monster_scaling.get("arena_min", 1)), int(balance.monster_scaling.get("arena_max", 60)))
	for e: CombatEntity in monsters.values():
		var m := e as MonsterState
		if m == null or not m.is_alive() or m.team != CombatEntity.TEAM_MONSTERS or m.target_id != 0 or not m.threat.is_empty():
			continue
		if m.def.is_empty():
			continue
		MonsterDB.apply_level(m, monster_level({}, m.def), balance)
		Spawner.scale_health(self, m, 1.0)
	emit(["arena_level", arena_level])


## Level of a monster spawned from `spawn` (map spawn point) of type `def`.
func monster_level(spawn: Dictionary, def: Dictionary) -> int:
	var bonus := int(balance.monster_scaling.get("boss_level_bonus", 2)) if bool(def.get("boss", false)) else 0
	return arena_level + int(spawn.get("level_offset", 0)) + bonus


func add_entity(e: CombatEntity) -> void:
	monsters[e.id] = e


func remove_entity(id: int) -> void:
	monsters.erase(id)


func _init(p_balance: Balance, p_map: CollisionMap, p_seed: int = 1) -> void:
	balance = p_balance
	map = p_map
	rng.seed = p_seed
	if not p_map.spawns.is_empty() or not p_map.hordes.is_empty():
		spawner = Spawner.new(p_map.spawns, p_map.hordes)


func add_player(id: int, position: Vector3) -> PlayerState:
	var s := PlayerState.new()
	s.id = id
	s.position = position
	s.aim = position
	players[id] = s
	rescale_monsters()
	return s


func remove_player(id: int) -> void:
	players.erase(id)
	rescale_monsters()


func entities() -> Array:
	return players.values() + monsters.values()


func entity(id: int) -> CombatEntity:
	return players.get(id, monsters.get(id))


## Health reached 0. Later tasks decide between dead, downed and respawn.
func on_zero_hp(e: CombatEntity) -> void:
	Combat.on_zero_hp(self, e)


## Advances one tick. `inputs` maps player id -> PlayerInput; players without input stay still.
func step(inputs: Dictionary) -> void:
	for id: int in inputs:
		if players.has(id):
			var p: PlayerState = players[id]
			if p.forced_ticks > 0:
				continue # an ability is moving this player (Carga, Voltereta…)
			p.lock_facing = p.has_status("ice_block")
			Movement.apply(p, inputs[id], dt(), balance, map, p.move_mult())
			if p.dodge_started:
				p.dodge_started = false
				p.add_status(StatusEffect.make("invulnerable", tick + ticks(balance.dodge_invuln_s)), 1)
				if not Passives.has_hook(p, "after_dodge_combo").is_empty():
					p.bonus_combo_ready = true
	for p: PlayerState in players.values():
		var held: bool = inputs.has(p.id) and (inputs[p.id] as PlayerInput).buttons & PlayerInput.BTN_INTERACT_HELD != 0
		Combat.update_revive(self, p, held)
	for e: CombatEntity in monsters.values():
		if e is MonsterState:
			MonsterAI.tick(self, e)
	Combat.tick(self)
	Loot.step(self)
	if spawner != null:
		spawner.tick(self)
	if tick % maxi(1, ticks(QuestRules.REACH_EVERY_S)) == 0:
		QuestRules.step_reach(self)
	tick += 1


func dt() -> float:
	return balance.dt()


## Seconds -> whole simulation ticks (at least 1 for positive times).
func ticks(seconds: float) -> int:
	return balance.ticks(seconds)


## Monster ids start at 1000 (players use 1, 2…).
func next_monster_id() -> int:
	_next_monster_id += 1
	return _next_monster_id


func pathfinder() -> Pathfinder:
	if _pathfinder == null:
		_pathfinder = Pathfinder.new(map)
	return _pathfinder


## Monster health follows the group size (GDD §5), keeping each one's fraction.
func rescale_monsters() -> void:
	for e: CombatEntity in monsters.values():
		var m := e as MonsterState
		if m != null and m.is_alive() and m.team == CombatEntity.TEAM_MONSTERS and m.stats.max_hp > 0.0:
			Spawner.scale_health(self, m, m.hp / m.stats.max_hp)
