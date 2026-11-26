class_name MapMarks
extends RefCounted
## How the map and the minimap draw their marks (Plan 8.1.1).

const COLORS := {
	"self": Color("#ffd27a"), "partner": Color("#7cc4ff"), "npc": Color("#9be36b"),
	"exit": Color("#f2ece0"), "dungeon": Color("#d05ad8"), "quest": Color("#ffcc33"), "foe": Color("#e8433a"),
}
const LEGEND := [["self", "MAP_LEGEND_YOU"], ["partner", "MAP_LEGEND_PARTY"], ["npc", "MAP_LEGEND_NPC"],
	["exit", "MAP_LEGEND_EXIT"], ["dungeon", "MAP_LEGEND_DUNGEON"], ["quest", "MAP_LEGEND_QUEST"], ["foe", "MAP_LEGEND_FOE"]]


## Draws one mark at `at` (canvas coordinates); `turn` is the map's rotation on screen.
static func draw(ci: CanvasItem, m: Dictionary, at: Vector2, radius: float, turn: float = 0.0) -> void:
	var col: Color = COLORS.get(m.kind, Color.WHITE)
	match str(m.kind):
		"self":
			# An arrow along the facing (forward (sin f, cos f) on the ground = map x, y).
			var f := float(m.yaw)
			var dir := Vector2(sin(f), cos(f)).rotated(turn)
			var side := dir.orthogonal()
			var pts := PackedVector2Array([at + dir * radius * 1.6, at - dir * radius + side * radius, at - dir * radius * 0.4, at - dir * radius - side * radius])
			ci.draw_colored_polygon(pts, col)
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color.BLACK, 1.0)
		"quest":
			# A star: the tracked objective (Plan 8.2).
			var star := PackedVector2Array()
			for i in 10:
				var rr := radius * (1.7 if i % 2 == 0 else 0.75)
				star.append(at + Vector2(0, -rr).rotated(TAU * i / 10.0))
			ci.draw_colored_polygon(star, col)
			ci.draw_polyline(star + PackedVector2Array([star[0]]), Color.BLACK, 1.0)
		"foe":
			ci.draw_circle(at, radius * 0.8, col)
		"dungeon":
			var r := Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2)
			ci.draw_rect(r, col)
			ci.draw_rect(r, Color.BLACK, false, 1.0)
		"exit":
			var pts := PackedVector2Array([at + Vector2(0, -radius * 1.3), at + Vector2(radius * 1.3, 0), at + Vector2(0, radius * 1.3), at + Vector2(-radius * 1.3, 0)])
			ci.draw_colored_polygon(pts, col)
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color.BLACK, 1.0)
		_:
			ci.draw_circle(at, radius, col)
			ci.draw_arc(at, radius, 0, TAU, 16, Color.BLACK, 1.0)
