class_name CharacterPreview
extends SubViewportContainer
## A character turning slowly in its own little 3D world; drag with the mouse to turn
## it by hand (it resumes turning when released).

const TURN_DEG_PER_S := 6.0 # slow enough to look at the details
const DRAG_DEG_PER_PX := 0.6

var rig: HumanRig
## The gear the shown character wears (Inventory.VISIBLE base ids; [] = the class outfit).
var gear: Array = []
## false: the character stays facing the camera (character window).
var turning: bool = true

var _viewport: SubViewport
var _pivot: Node3D
var _dragging: bool = false


func _init() -> void:
	stretch = true
	mouse_filter = MOUSE_FILTER_STOP
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	add_child(_viewport)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	var cam := Camera3D.new()
	cam.fov = 32
	_viewport.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.35, 4.6), Vector3(0, 0.95, 0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 0.8
	_viewport.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c9d6e6")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)


func show_character(class_id: String, appearance: Dictionary, gear: Array = []) -> void:
	self.gear = gear
	if rig != null:
		rig.queue_free()
	rig = HumanRig.create(class_id, appearance, null, "", gear)
	_pivot.add_child(rig)
	rig.set_moving_speed(0.0, 1.0)


func _process(delta: float) -> void:
	if turning and not _dragging:
		_pivot.rotation_degrees.y += TURN_DEG_PER_S * delta


func _gui_input(event: InputEvent) -> void:
	if not turning:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (event as InputEventMouseButton).pressed
	elif event is InputEventMouseMotion and _dragging:
		_pivot.rotation_degrees.y += (event as InputEventMouseMotion).relative.x * DRAG_DEG_PER_PX
