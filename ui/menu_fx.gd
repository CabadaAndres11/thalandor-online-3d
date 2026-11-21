class_name MenuFx
extends RefCounted
## Light on the menus (Plan 7): every button and panel of the title, character select
## and create screens gets a glow layer (assets/ui/ember_glow.gdshader). Buttons light up
## at the edges and catch a shine when the mouse is over them; the call to action (Play)
## breathes and shines all the time; panels shimmer faintly.

const FX_NAME := "Fx"
const SHADER := preload("res://assets/ui/ember_glow.gdshader")
## How far the glow spills outside a control, in pixels.
const GROW := 12.0
const HOVER_S := 0.18
const BUTTON := "button"
const CALL := "call"
const PANEL := "panel"


## Adds the glow layer to `c` (once) and returns it. kind: BUTTON, CALL or PANEL.
static func decorate(c: Control, kind: String = BUTTON) -> ColorRect:
	var existing := c.get_node_or_null(FX_NAME) as ColorRect
	if existing != null:
		return existing
	var fx := ColorRect.new()
	fx.name = FX_NAME
	fx.color = Color(0, 0, 0, 0) # the shader draws all of it
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.offset_left = -GROW
	fx.offset_top = -GROW
	fx.offset_right = GROW
	fx.offset_bottom = GROW
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("grow", GROW)
	m.set_shader_parameter("phase", randf() * TAU)
	for p: String in ["edge", "pulse", "sweep"]: # unset parameters read back as null
		m.set_shader_parameter(p, 0.0)
	m.set_shader_parameter("period", 4.0)
	match kind:
		CALL:
			m.set_shader_parameter("pulse", 0.6)
			m.set_shader_parameter("sweep", 1.0)
			m.set_shader_parameter("period", 3.2)
		PANEL:
			m.set_shader_parameter("pulse", 0.12)
			m.set_shader_parameter("sweep", 0.45)
			m.set_shader_parameter("period", 9.0)
	fx.material = m
	c.add_child(fx)
	fx.resized.connect(func() -> void: m.set_shader_parameter("layer_size", fx.size))
	m.set_shader_parameter("layer_size", fx.size)
	if c is BaseButton:
		c.mouse_entered.connect(set_hover.bind(c, true))
		c.mouse_exited.connect(set_hover.bind(c, false))
		c.set_meta("fx_sweep", float(m.get_shader_parameter("sweep")))
	return fx


## Lights a control's edges up (or down), in HOVER_S unless instant.
static func set_hover(c: Control, on: bool, instant: bool = false) -> void:
	var fx := c.get_node_or_null(FX_NAME) as ColorRect
	if fx == null:
		return
	var m := fx.material as ShaderMaterial
	var resting := float(c.get_meta("fx_sweep", 0.0))
	var sweep := 1.0 if on else resting
	var edge := 1.0 if on and not (c is BaseButton and (c as BaseButton).disabled) else 0.0
	if instant or not fx.is_inside_tree():
		m.set_shader_parameter("edge", edge)
		m.set_shader_parameter("sweep", sweep)
		return
	var tw := fx.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("edge", v),
		float(m.get_shader_parameter("edge")), edge, HOVER_S)
	m.set_shader_parameter("sweep", sweep)


## Decorates every button and panel under `root` (PanelContainers as PANEL).
static func decorate_tree(root: Node) -> void:
	for n: Node in root.find_children("*", "PanelContainer", true, false):
		decorate(n as Control, PANEL)
	for n: Node in root.find_children("*", "BaseButton", true, false):
		decorate(n as Control, BUTTON)
