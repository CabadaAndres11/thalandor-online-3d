shader_type spatial;
// A health bar on one quad that always faces the camera: filled up to `fill`
// (0..1) with a dark border. Drawn on top so it never hides behind blocks.
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled;

uniform float fill = 1.0;
uniform vec4 fill_color : source_color = vec4(0.85, 0.2, 0.2, 1.0);
uniform vec4 back_color : source_color = vec4(0.1, 0.1, 0.12, 0.8);
uniform float border = 0.06;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	bool edge = UV.y < border * 3.0 || UV.y > 1.0 - border * 3.0 || UV.x < border * 0.3 || UV.x > 1.0 - border * 0.3;
	vec4 c = UV.x <= fill ? fill_color : back_color;
	ALBEDO = edge ? vec3(0.05) : c.rgb;
	ALPHA = edge ? 0.9 : c.a;
}
