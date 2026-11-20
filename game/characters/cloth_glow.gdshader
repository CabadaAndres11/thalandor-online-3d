// Glowing voxels (eyes, runes) on a piece of cloth: unshaded, deformed like the cloth.
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://game/characters/cloth.gdshaderinc"

void vertex() {
	cloth_vertex(VERTEX, NORMAL);
}

void fragment() {
	ALBEDO = COLOR.rgb * COLOR.rgb;
}
