shader_type spatial;
// 窗玻璃：不接受灯光，所以火光和门外的光不会在玻璃上亮成一个光斑。
// 夜里玻璃像一面暗镜子，映出的是屋里的样子（WindowReflection 渲染好的倒影），屋里越亮倒影越清楚。
// 正对着看反射少，斜着看反射多（Schlick 菲涅尔）。透过去的窗外和反射回来的屋里按反射率混合。
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// 玻璃挡掉的那一点透过来的光。玻璃不受灯光影响，所以它只能让窗外变暗，不能自己带颜色，否则黑屋里玻璃会自己发亮。
uniform float absorb : hint_range(0.0, 1.0) = 0.05;
// 没有倒影贴图（门上的玻璃）时为 0。第二章天亮以后渐隐到 0。
uniform float strength : hint_range(0.0, 1.0) = 0.0;
// 正对着看时的反射率，取真实玻璃的值。色调映射会把暗部提得很亮，再大倒影就像一扇通往另一间屋子的门。
uniform float reflectance : hint_range(0.0, 1.0) = 0.04;
uniform sampler2D reflection : hint_default_black, filter_linear, repeat_disable;
// 窗玻璃矩形：中心、朝右和朝上的单位向量（世界坐标），以及宽和高（米）。
uniform vec3 mirror_origin;
uniform vec3 mirror_right = vec3(1.0, 0.0, 0.0);
uniform vec3 mirror_up = vec3(0.0, 1.0, 0.0);
uniform vec2 mirror_size = vec2(1.0, 1.0);

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// 法线用矩形自己的，不用网格的：模型里玻璃的法线不可靠。
	vec3 normal = normalize(cross(mirror_right, mirror_up));
	float facing = clamp(abs(dot(normal, normalize(CAMERA_POSITION_WORLD - world_position))), 0.0, 1.0);
	float r = strength * mix(reflectance, 1.0, pow(1.0 - facing, 5.0));
	vec3 offset = world_position - mirror_origin;
	// 倒影相机在玻璃另一侧朝屋里看，它的右边是玻璃的左边，所以横向翻过来。
	vec2 uv = vec2(0.5 - dot(offset, mirror_right) / mirror_size.x, 0.5 - dot(offset, mirror_up) / mirror_size.y);
	vec3 mirrored = r > 0.0 ? texture(reflection, uv).rgb : vec3(0.0);
	float alpha = clamp(r + absorb, 0.0, 1.0);
	ALBEDO = alpha > 0.0 ? mirrored * r / alpha : vec3(0.0);
	ALPHA = alpha;
}
