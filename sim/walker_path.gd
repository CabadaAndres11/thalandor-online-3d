class_name WalkerPath
extends RefCounted
## Where a walking villager is at a time (Plan 8.3a): it walks its route at `speed` m/s and
## waits `pause_s` at every point. A loop goes back to the first point; otherwise it walks
## the route back. Only the time decides it, so every client draws it in the same place.
## Route points are cells: the villager walks through their centres.


static func _cell(p: Vector2) -> Vector3:
	return Vector3(p.x + 0.5, 0, p.y + 0.5)


## The points it visits in one cycle, in order (back to the start included).
static func _cycle(route: Array, loop: bool) -> Array:
	var pts: Array = route.duplicate()
	if pts.size() < 2:
		return pts
	if loop:
		pts.append(route[0])
	else:
		var back := route.duplicate()
		back.reverse()
		pts += back.slice(1)
	return pts


static func cycle_s(route: Array, speed: float, pause_s: float, loop: bool) -> float:
	var pts := _cycle(route, loop)
	var total := 0.0
	for i in range(1, pts.size()):
		total += (pts[i] as Vector2).distance_to(pts[i - 1]) / maxf(speed, 0.01) + pause_s
	return total


## {position: Vector3, facing: float, moving: bool} at time t (seconds).
static func at(route: Array, speed: float, pause_s: float, loop: bool, t: float) -> Dictionary:
	if route.is_empty():
		return {"position": Vector3.ZERO, "facing": 0.0, "moving": false}
	var pts := _cycle(route, loop)
	if pts.size() < 2:
		return {"position": _cell(pts[0]), "facing": 0.0, "moving": false}
	var total := cycle_s(route, speed, pause_s, loop)
	var left := fposmod(t, total) if total > 0.0 else 0.0
	var facing := 0.0
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var d := b - a
		var walk := d.length() / maxf(speed, 0.01)
		facing = atan2(d.x, d.y) if d.length() > 0.0 else facing
		if left < walk:
			var p := a.lerp(b, left / walk)
			return {"position": _cell(p), "facing": facing, "moving": true}
		left -= walk
		if left < pause_s:
			return {"position": _cell(b), "facing": facing, "moving": false}
		left -= pause_s
	return {"position": _cell(pts[0]), "facing": facing, "moving": false}
