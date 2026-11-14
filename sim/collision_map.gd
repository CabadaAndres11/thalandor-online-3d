class_name CollisionMap
extends RefCounted
## Solid cells of a 1 m grid on the XZ plane. Cell (x, z) covers [x, x+1) × [z, z+1).
## Anything outside [0, size) is solid, so the map borders are walls.

var size: Vector2i = Vector2i.ZERO
var spawn_cell: Vector2i = Vector2i.ZERO
var _solid: Dictionary = {}


static func from_layout(layout: Dictionary) -> CollisionMap:
	var map := CollisionMap.new()
	var s: Array = layout.get("size", [0, 0])
	map.size = Vector2i(int(s[0]), int(s[1]))
	var sp: Array = layout.get("spawn", [0, 0])
	map.spawn_cell = Vector2i(int(sp[0]), int(sp[1]))
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
