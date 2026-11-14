class_name InputSetup
extends RefCounted
## Default key bindings, registered at startup (rebinding comes with the Options window).

const BINDINGS := {
	"move_up": [KEY_W],
	"move_down": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"chat": [KEY_ENTER, KEY_KP_ENTER],
	"menu": [KEY_ESCAPE],
	"debug_overlay": [KEY_F3],
	"toggle_projection": [KEY_F9],
}


static func ensure_actions() -> void:
	for action: String in BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
