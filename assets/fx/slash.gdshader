shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// The cut of a melee swing: a streak texture masked along the weapon's path (UV.x runs from
// the oldest part of the swing to the newest, UV.y from the hand to the tip of the blade).

uniform sampler2D slash_tex : filter_linear, repeat_disable;
uniform vec4 color : source_color = vec4(1.0);
uniform float fade = 1.0;

void fragment() {
	float tail = smoothstep(0.0, 0.7, UV.x);        // the old end of the cut fades away
	float cut = texture(slash_tex, UV).r;            // the streak, with soft edges
	float tip = smoothstep(0.05, 0.95, UV.y);        // brightest at the tip of the blade
	float a = cut * tail * (0.3 + 0.7 * tip) * fade;
	ALBEDO = mix(color.rgb, vec3(1.0), cut * 0.6);
	ALPHA = clamp(a, 0.0, 1.0);
}
