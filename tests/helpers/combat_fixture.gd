class_name CombatFixture
extends RefCounted
## Builds small combat worlds for tests: a map with optional blocks, the test
## abilities (data/abilities/_test.json) and helpers to add entities and run ticks.

const TEST_ABILITIES := "res://data/abilities/_test.json"

var world: SimWorld
## Every event emitted while running (run() clears world.events each tick).
var log: Array = []


func _init(blocks: Array = [], size := Vector2i(30, 30), seed_value := 7) -> void:
	var map := CollisionMap.from_layout({"size": [size.x, size.y], "spawn": [5, 5], "blocks": blocks})
	var b := Balance.load_from()
	b.damage_variance = 0.0 # exact numbers in combat tests (variance has its own test)
	world = SimWorld.new(b, map, seed_value)
	world.abilities = AbilityDB.load_files([TEST_ABILITIES])


func player(id: int, pos: Vector3, hp := 100.0, resource := 100.0) -> PlayerState:
	var p := world.add_player(id, pos)
	p.stats = CombatStats.from_dict({"max_hp": hp, "max_resource": 100, "crit_chance": 0})
	p.hp = hp
	p.resource = resource
	return p


## A target dummy on the monster team (no AI): a plain CombatEntity in the world.
func dummy(id: int, pos: Vector3, hp := 100.0) -> CombatEntity:
	var e := CombatEntity.new()
	e.id = id
	e.team = CombatEntity.TEAM_MONSTERS
	e.position = pos
	e.stats = CombatStats.from_dict({"max_hp": hp})
	e.hp = hp
	world.add_entity(e)
	return e


func run(seconds: float) -> void:
	for i in world.ticks(seconds):
		log.append_array(world.events)
		world.events.clear()
		Combat.tick(world)
		log.append_array(world.events)
		world.events.clear()
		world.tick += 1


func events_of(type: String) -> Array:
	return (log + world.events).filter(func(ev: Array) -> bool: return ev[0] == type)
