shader_type spatial;
// Character texture built from layers on Kenney's UV layout. Grey layers are tinted
// (multiplied) by the character's colors; the others keep their own colors.
// Order, bottom to top: skin, face, eyes, outfit, brows, beard, hair.

uniform sampler2D skin_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D face_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D eyes_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D outfit_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D brows_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D beard_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D hair_tex : source_color, filter_nearest, repeat_enable;
uniform vec3 skin_color : source_color = vec3(0.91, 0.72, 0.58);
uniform vec3 eyes_color : source_color = vec3(0.35, 0.22, 0.15);
uniform vec3 hair_color : source_color = vec3(0.30, 0.20, 0.12);

vec3 over(vec3 base, vec4 layer, vec3 tint) {
	return mix(base, layer.rgb * tint, layer.a);
}

void fragment() {
	vec3 c = texture(skin_tex, UV).rgb * skin_color;
	c = over(c, texture(face_tex, UV), vec3(1.0));
	c = over(c, texture(eyes_tex, UV), eyes_color);
	c = over(c, texture(outfit_tex, UV), vec3(1.0));
	c = over(c, texture(brows_tex, UV), hair_color);
	c = over(c, texture(beard_tex, UV), hair_color);
	c = over(c, texture(hair_tex, UV), hair_color);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
