shader_type canvas_item;
// A soft diagonal glow that drifts across a window, with faint scanlines.

uniform vec4 glow_color : source_color = vec4(0.55, 0.82, 1.0, 1.0);
uniform float speed = 0.09;
uniform float strength = 0.16;

void fragment() {
	float t = fract(TIME * speed);
	float d = (UV.x * 0.75 + UV.y * 0.35) - (t * 2.4 - 0.7);
	float band = exp(-pow(d * 5.0, 2.0));
	float scan = 0.025 * (0.5 + 0.5 * sin(UV.y * 260.0 + TIME * 0.6));
	COLOR = vec4(glow_color.rgb, band * strength + scan);
}
