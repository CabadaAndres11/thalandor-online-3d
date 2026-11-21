shader_type canvas_item;
render_mode blend_add;
// Light on a menu control (Plan 7, MenuFx): drawn on a layer `grow` pixels larger than the
// control. A warm glow hugs its edges inside and spills outside (edge: 0 off, 1 hovered;
// pulse: a slow breath on top), and a band of light sweeps across now and then (sweep).

uniform vec4 glow_color : source_color = vec4(1.0, 0.72, 0.36, 1.0);
uniform vec2 layer_size = vec2(100.0, 40.0);
uniform float grow = 12.0;
uniform float edge = 0.0;
uniform float pulse = 0.0;
uniform float sweep = 0.0;
uniform float period = 4.0;
uniform float phase = 0.0;

void fragment() {
	vec2 px = UV * layer_size;
	vec2 inner_lo = vec2(grow);
	vec2 inner_hi = layer_size - vec2(grow);
	// Distance to the control's border: > 0 outside it, < 0 inside.
	vec2 q = max(inner_lo - px, px - inner_hi);
	float outside = length(max(q, 0.0));
	float inside = -min(max(q.x, q.y), 0.0);
	bool in_rect = q.x <= 0.0 && q.y <= 0.0;
	float breath = 0.5 + 0.5 * sin(TIME * 2.4 + phase);
	float strength = edge + pulse * (0.35 + 0.65 * breath);
	float glow = in_rect ? exp(-inside / 5.0) * 0.55 : exp(-outside / 4.5) * 0.7 * step(outside, grow);
	float a = glow * strength;
	// The sweep: a slanted band crossing the control in the first half of each period.
	if (in_rect && sweep > 0.0) {
		vec2 uv = (px - inner_lo) / max(inner_hi - inner_lo, vec2(1.0));
		float t = fract((TIME + phase) / period) * 2.0;
		float d = (uv.x + uv.y * 0.3) - (t * 1.6 - 0.3);
		a += exp(-pow(d * 9.0, 2.0)) * 0.32 * sweep * step(t, 1.0);
	}
	COLOR = vec4(glow_color.rgb, clamp(a, 0.0, 1.0) * glow_color.a);
}
