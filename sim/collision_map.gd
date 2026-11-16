class_name CollisionMap
extends RefCounted
## Solid cells of a 1 m grid on the XZ plane. Cell (x, z) covers [x, x+1) × [z, z+1).
## Anything outside [0, size) is solid, so the map borders are walls.

var size: Vector2i = Vector2i.ZERO
var spawn_cell: Vector2i = Vector2i.ZERO
## Where players reappear after dying (defaults to the spawn cell).
var respawn_cell: Vector2i = Vector2i.ZERO
## Monster spawn points: {type, at: [x, z], count, radius, respawn_s, elite_chance}.
var spawns: Array = []
## NPCs standing on the map: {id, at: [x, z], facing (degrees)}.
var npcs: Array = []
var _solid: Dictionary = {}


static func from_layout(layout: Dictionary) -> CollisionMap:
	var map := CollisionMap.new()
	map.npcs = (layout.get("npcs", []) as Array).duplicate(true)
	var s: Array = layout.get("size", [0, 0])
	map.size = Vector2i(int(s[0]), int(s[1]))
	var sp: Array = layout.get("spawn", [0, 0])
	map.spawn_cell = Vector2i(int(sp[0]), int(sp[1]))
	var rp: Array = layout.get("respawn_point", sp)
	map.respawn_cell = Vector2i(int(rp[0]), int(rp[1]))
	map.spawns = layout.get("spawns", [])
	for block: Array in layout.get("blocks", []):
		map.set_solid(Vector2i(int(block[0]), int(block[1])), true)
	return map


func set_solid(cell: Vector2i, solid: bool) -> void:
	if solid:
		_solid[cell] = true
	else:
		_solid.erase(cell)


func is_solid(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return true
	return _solid.has(cell)


func spawn_point() -> Vector3:
	return Vector3(spawn_cell.x + 0.5, 0.0, spawn_cell.y + 0.5)


func respawn_point() -> Vector3:
	return Vector3(respawn_cell.x + 0.5, 0.0, respawn_cell.y + 0.5)
