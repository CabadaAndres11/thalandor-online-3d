// The hit flash over a cloth piece: unshaded white fading with flash.a, deformed like the
// cloth (same include, so the instance uniforms the rig sets reach it too).
shader_type spatial;
render_mode unshaded, cull_back, blend_mix;

#include "res://game/characters/cloth.gdshaderinc"

uniform vec4 flash : source_color = vec4(1.0, 1.0, 1.0, 0.85);

void vertex() {
	cloth_vertex(VERTEX, NORMAL);
}

void fragment() {
	ALBEDO = flash.rgb;
	ALPHA = flash.a;
}
