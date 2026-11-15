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
	"slot_1": [KEY_1],
	"slot_2": [KEY_2],
	"slot_3": [KEY_3],
	"slot_4": [KEY_4],
	"dodge": [KEY_SPACE],
	"interact": [KEY_E],
	"abilities_window": [KEY_K],
}

## Mouse buttons of actions (GDD §3.2).
const MOUSE_BINDINGS := {
	"attack_basic": [MOUSE_BUTTON_LEFT],
	"attack_secondary": [MOUSE_BUTTON_RIGHT],
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
	for action: String in MOUSE_BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for button: MouseButton in MOUSE_BINDINGS[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)
