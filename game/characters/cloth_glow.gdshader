// Glowing voxels (eyes, runes) on a piece of cloth: unshaded, deformed like the cloth.
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://game/characters/cloth.gdshaderinc"

void vertex() {
	cloth_vertex(VERTEX, NORMAL);
}

void fragment() {
	ALBEDO = mix(pow((COLOR.rgb + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), COLOR.rgb * (1.0 / 12.92), lessThan(COLOR.rgb, vec3(0.04045))); // the exact sRGB curve, as VoxMesher's material
}
