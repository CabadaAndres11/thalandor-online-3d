shader_type spatial;
// Recolors a Cube Pets model: its texture becomes grey and is tinted, except very
// bright and very dark pixels (eyes, nose, teeth), which keep their own color.

uniform sampler2D tex : source_color, filter_nearest;
uniform vec3 tint : source_color = vec3(1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 c = texture(tex, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tinted = clamp(l * tint * 1.7, 0.0, 1.0);
	float keep = smoothstep(0.80, 0.90, l) + (1.0 - smoothstep(0.10, 0.18, l));
	ALBEDO = mix(mix(c.rgb, tinted, strength), c.rgb, clamp(keep, 0.0, 1.0));
	ROUGHNESS = 1.0;
}
