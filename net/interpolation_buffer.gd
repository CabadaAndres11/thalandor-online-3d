class_name InterpolationBuffer
extends RefCounted
## Recent snapshot samples of one remote player, sampled at a fractional tick.

const CAPACITY := 32

var _samples: Array = [] # [{"tick", "position", "aim", "facing"}] ordered by tick


func push(tick: int, position: Vector3, aim: Vector3, facing: float) -> void:
	if not _samples.is_empty() and tick <= int(_samples[-1].tick):
		return
	_samples.append({"tick": tick, "position": position, "aim": aim, "facing": facing})
	if _samples.size() > CAPACITY:
		_samples.pop_front()


func sample(render_tick: float) -> Dictionary:
	if _samples.is_empty():
		return {}
	var first: Dictionary = _samples[0]
	if render_tick <= first.tick:
		return _view(first)
	for i in range(1, _samples.size()):
		var b: Dictionary = _samples[i]
		if render_tick <= b.tick:
			var a: Dictionary = _samples[i - 1]
			var t := (render_tick - a.tick) / float(b.tick - a.tick)
			return {
				"position": (a.position as Vector3).lerp(b.position, t),
				"aim": (a.aim as Vector3).lerp(b.aim, t),
				"facing": lerp_angle(a.facing, b.facing, t),
			}
	return _view(_samples[-1])


func latest_tick() -> int:
	return -1 if _samples.is_empty() else int(_samples[-1].tick)


func size() -> int:
	return _samples.size()


func _view(s: Dictionary) -> Dictionary:
	return {"position": s.position, "aim": s.aim, "facing": s.facing}
