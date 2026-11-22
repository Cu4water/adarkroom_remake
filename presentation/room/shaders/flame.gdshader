shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// 火焰。网格是 Blender 里那几片尖锥，原点在根部，这里让它们晃起来。
// 火焰的大小由 FireRig 缩放节点来控制，这里只管形状的抖动和颜色。

uniform vec3 color_base = vec3(1.0, 0.8, 0.28);
uniform vec3 color_mid = vec3(1.0, 0.36, 0.04);
uniform vec3 color_tip = vec3(0.78, 0.08, 0.008);
uniform float intensity = 1.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
// 网格没缩放时的高度，用来把顶点高度换算成 0 到 1。
uniform float mesh_height = 0.55;
uniform float sway = 1.0;
// 每片火焰各自的相位，免得它们晃得整整齐齐。
instance uniform float phase = 0.0;

varying float height;

void vertex() {
	height = clamp(VERTEX.y / mesh_height, 0.0, 1.0);
	float t = TIME + phase;
	float bend = height * height * sway;
	VERTEX.x += (sin(t * 6.3 + VERTEX.y * 8.0) * 0.04 + sin(t * 13.1 + VERTEX.y * 19.0) * 0.018) * bend;
	VERTEX.z += (cos(t * 5.1 + VERTEX.y * 9.0) * 0.04 + sin(t * 11.7 + VERTEX.y * 15.0) * 0.018) * bend;
	VERTEX.y *= 1.0 + (0.10 * sin(t * 8.7) + 0.05 * sin(t * 17.3 + 1.3)) * height;
}

void fragment() {
	vec3 color = mix(color_base, color_mid, smoothstep(0.08, 0.5, height));
	color = mix(color, color_tip, smoothstep(0.5, 0.95, height));
	ALBEDO = color * intensity;
	ALPHA = opacity * (1.0 - 0.8 * smoothstep(0.5, 1.0, height));
}
