class_name GraphicsQuality
extends RefCounted
## Video quality levels. A level only strips effects an ambience asks for.

enum { LOW, MEDIUM, HIGH }

const PARTICLE_SCALE := [0.25, 0.6, 1.0]
const NAMES := ["QUALITY_LOW", "QUALITY_MEDIUM", "QUALITY_HIGH"]


static func clamp_level(q: int) -> int:
	return clampi(q, LOW, HIGH)
