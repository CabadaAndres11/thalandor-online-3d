class_name PlayerAvatar
extends Node3D
## A player in the world: their voxel character (HumanRig), their name above it in
## their slot color. Plays idle or walk from how fast
## its drawn position moves.

const SLOT_COLORS := [Color("#E5533D"), Color("#3D8BE5"), Color("#4CC26A"), Color("#E5C33D")]
const NAME_HEIGHT := 2.25
## Speed smoothing time constant: drawn positions of the own player only change on
## physics ticks, so raw per-frame speed alternates between 0 and double.
const SPEED_SMOOTHING_S := 0.1
## A jump longer than this in one frame (spawn, big correction) is not walking.
const TELEPORT_DISTANCE := 2.0

var rig: HumanRig
## Walk animation plays at real speed / move_speed (set from balance by the game).
var move_speed: float = 5.0

var bar: OverheadBar
## How see-through the character is in stealth (0 = solid, 1 = invisible).
const STEALTH_TRANSPARENCY := 0.7
var _translucent: bool = false

var _label: Label3D
var _player_name: String = ""
var _level: int = 0
var _last_position: Variant = null
var _speed: float = 0.0
## Seconds left of an action animation (idle/walk wait for it); dead = stays down.
var _action_left: float = 0.0
var _dead: bool = false


func setup(player_name: String, slot: int, class_id: String, appearance: Dictionary, upgrade: String = "") -> void:
	var color: Color = SLOT_COLORS[clampi(slot, 0, SLOT_COLORS.size() - 1)]
	rig = HumanRig.create(class_id, appearance, null, upgrade)
	rig.auto_update = false
	add_child(rig)
	rig.set_moving_speed(0.0, move_speed)

	_label = Label3D.new()
	_label.text = player_name
	_player_name = player_name
	_label.modulate = color.lightened(0.5)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = false # world size: shrinks with the zoom
	_label.no_depth_test = true
	_label.pixel_size = 0.010
	_label.font_size = 40
	_label.outline_size = 10
	_label.position.y = NAME_HEIGHT
	bar = OverheadBar.new()
	bar.position.y = NAME_HEIGHT - 0.22
	add_child(bar)
	bar.setup("", false, Color(0.3, 0.85, 0.35))
	bar.icon_height = 0.5 # above the name
	add_child(_label)


## state: {"position", "aim", "facing"} from the client ({} = unknown yet).
func apply_state(state: Dictionary, delta: float) -> void:
	var measured := 0.0
	if not state.is_empty():
		var pos: Vector3 = state.position
		if _last_position != null and delta > 0.0:
			var step := Vector2(pos.x - _last_position.x, pos.z - _last_position.z).length()
			if step > TELEPORT_DISTANCE:
				_speed = 0.0 # a jump, not movement
			else:
				measured = step / delta
		_last_position = pos
		position = pos
		if not _dead:
			rotation.y = state.facing # a body on the ground does not turn with the mouse
	if delta > 0.0:
		_speed = lerpf(_speed, measured, 1.0 - exp(-delta / SPEED_SMOOTHING_S))
		_action_left = maxf(_action_left - delta, 0.0)
	if rig != null:
		if _action_left <= 0.0 and not _dead:
			rig.set_moving_speed(_speed, move_speed)
			if rig.current_action() == "cast_long":
				rig.play_action("idle") # the long cast ran out
		rig.update(delta)


func set_health(hp: float, max_hp: float, alive: bool = true) -> void:
	bar.set_health(hp, max_hp)
	if alive and _dead:
		_dead = false # back on its feet (respawn / revive)
		_action_left = 0.0
		if rig != null:
			rig.play_action("idle")


## Status icons above the name, and see-through while in stealth.
func set_statuses(bits: int) -> void:
	bar.set_statuses(bits)
	var stealth := StatusEffect.has_bit(bits, "stealth")
	if stealth == _translucent:
		return
	_translucent = stealth
	if rig == null:
		return
	for n: Node in rig.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).transparency = STEALTH_TRANSPARENCY if stealth else 0.0


func is_translucent() -> bool:
	return _translucent


## Plays the action of an ability kind (melee, shoot, cast, dash), "downed" or "die";
## idle and walk resume when it ends (a body on the ground stays down until alive).
func play_action(kind: String) -> void:
	if rig == null:
		return
	var d := rig.play_action(kind)
	if d <= 0.0:
		return
	_action_left = d
	_dead = kind == "die" or kind == "downed"


## A long cast (a cast time or a channel): arms up and the staff spinning for `seconds`.
func play_long_cast(seconds: float) -> void:
	if rig == null or _dead:
		return
	rig.play_action("cast_long")
	_action_left = seconds


## The long cast ended or was interrupted.
func stop_long_cast() -> void:
	if rig != null and rig.current_action() == "cast_long":
		rig.play_action("idle")
		_action_left = 0.0


## "Nv N name" above the character.
func set_level(level: int) -> void:
	if level == _level or _label == null:
		return
	_level = level
	_label.text = tr("OVERHEAD_LEVEL") % [level, _player_name]


func label_text() -> String:
	return _label.text if _label != null else ""
