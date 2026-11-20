// Lit voxel cloth: VoxMesher's material (vertex colours in sRGB, roughness 1) with the cloth
// deformation of cloth.gdshaderinc.
shader_type spatial;
render_mode cull_back;

#include "res://game/characters/cloth.gdshaderinc"

void vertex() {
	cloth_vertex(VERTEX, NORMAL);
}

void fragment() {
	ALBEDO = COLOR.rgb * COLOR.rgb; // sRGB vertex colour to linear (close enough to the exact curve)
	ROUGHNESS = 1.0;
}
