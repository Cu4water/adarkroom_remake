shader_type spatial;
// 余烬。glow 为 0 时就是一块黑炭，升上去之后从缝里透出红光。

#include "noise.gdshaderinc"

uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform float strength = 3.0;

varying vec3 local_position;
varying float piece;

// Blender 里余烬材质的四段色带。
vec3 ember_ramp(float t) {
	vec3 color = mix(vec3(0.04, 0.02, 0.015), vec3(0.65, 0.07, 0.008), clamp((t - 0.28) / 0.22, 0.0, 1.0));
	color = mix(color, vec3(1.0, 0.32, 0.03), clamp((t - 0.5) / 0.22, 0.0, 1.0));
	return mix(color, vec3(1.0, 0.72, 0.14), clamp((t - 0.72) / 0.14, 0.0, 1.0));
}

void vertex() {
	local_position = VERTEX;
	piece = COLOR.r;
}

void fragment() {
	float pattern = fbm(local_position * 16.0 + vec3(piece * 31.0, TIME * 0.03, piece * 7.0));
	float pulse = 0.85 + 0.15 * sin(TIME * 1.7 + piece * 40.0);
	float t = clamp((pattern * 1.25 + 0.12) * (0.4 + 0.6 * glow) * pulse, 0.0, 1.0);
	ALBEDO = vec3(0.03, 0.02, 0.018);
	ROUGHNESS = 0.92;
	EMISSION = ember_ramp(t) * strength * glow;
}
