// Cloth that follows the body (Plan 6.4.3): a voxel piece's vertices turned about the x axis
// in the piece's own space. HumanRig.cloth_deform is the same maths on the CPU (for tests).
//   mode 1 (skirt): below waist_y each side turns about its hip by its leg's angle, more
//     towards the knee (span); the middle mixes both legs.
//   mode 2 (cape): behind and below the anchor it turns back by `drape`, more towards the hem.
instance uniform int cloth_mode = 0;
instance uniform vec3 hip_l;
instance uniform vec3 hip_r;
instance uniform float ang_l = 0.0;
instance uniform float ang_r = 0.0;
instance uniform float waist_y = 0.0;
instance uniform float span = 1.0;
instance uniform vec3 anchor;
instance uniform float drape = 0.0;

vec3 cloth_rot_x(vec3 d, float a) {
	float c = cos(a), s = sin(a);
	return vec3(d.x, d.y * c - d.z * s, d.y * s + d.z * c);
}

void cloth_vertex(inout vec3 v, inout vec3 n) {
	if (cloth_mode == 1 && v.y < waist_y) {
		float k = clamp((waist_y - v.y) / max(span, 0.001), 0.0, 1.0);
		float w = hip_l.x - hip_r.x;
		float t = abs(w) < 0.001 ? 0.5 : clamp((v.x - hip_r.x) / w, 0.0, 1.0);
		vec3 pivot = mix(hip_r, hip_l, t);
		float a = mix(ang_r, ang_l, t) * k;
		v = pivot + cloth_rot_x(v - pivot, a);
		n = cloth_rot_x(n, a);
	} else if (cloth_mode == 2 && v.y < anchor.y && v.z < anchor.z + 0.3) {
		float k = clamp((anchor.y - v.y) / max(span, 0.001), 0.0, 1.0);
		float a = drape * k;
		v = anchor + cloth_rot_x(v - anchor, a);
		n = cloth_rot_x(n, a);
	}
}
