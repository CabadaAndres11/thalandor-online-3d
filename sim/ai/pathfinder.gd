class_name Pathfinder
extends RefCounted
## Grid paths for monsters over the collision map (AStarGrid2D, deterministic).
## Diagonal steps only where neither neighbour is solid (no corner cutting).

var _grid := AStarGrid2D.new()
var _map: CollisionMap


func _init(map: CollisionMap) -> void:
	_map = map
	_grid.region = Rect2i(Vector2i.ZERO, map.size)
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	for x in map.size.x:
		for z in map.size.y:
			if map.is_solid(Vector2i(x, z)):
				_grid.set_point_solid(Vector2i(x, z), true)


## Waypoints (cell centres, world XZ) from `from` to `to`, ending exactly at `to`.
## Empty when there is no path (blocked, or either end in a solid cell / off map).
func path(from: Vector3, to: Vector3) -> PackedVector2Array:
	var a := Vector2i(floori(from.x), floori(from.z))
	var b := Vector2i(floori(to.x), floori(to.z))
	if not _grid.is_in_boundsv(a) or not _grid.is_in_boundsv(b) or _grid.is_point_solid(a) or _grid.is_point_solid(b):
		return PackedVector2Array()
	var cells := _grid.get_id_path(a, b)
	if cells.is_empty():
		return PackedVector2Array()
	var out := PackedVector2Array()
	for i in range(1, cells.size()):
		out.append(Vector2(cells[i].x + 0.5, cells[i].y + 0.5))
	if out.is_empty():
		out.append(Vector2(to.x, to.z))
	else:
		out[out.size() - 1] = Vector2(to.x, to.z)
	return out


## True when nothing solid lies on the straight segment (sampled every 0.25 m).
func clear_line(from: Vector3, to: Vector3) -> bool:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var steps := maxi(1, ceili(a.distance_to(b) / 0.25))
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		if _map.is_solid(Vector2i(floori(p.x), floori(p.y))):
			return false
	return true
