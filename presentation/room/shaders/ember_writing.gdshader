shader_type spatial;
// 柴堆上方用火星写出来的数：笔画按书写顺序一点点烧出来，笔尖最亮，写完慢慢冷成灰烬再散掉。
// UV.x 是这一点在全部笔画里的书写进度（0 到 1），UV.y 横跨笔画宽度。始终朝向镜头。
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float reveal : hint_range(0.0, 1.2) = 0.0;
uniform float cool : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform vec3 ember : source_color = vec3(1.0, 0.5, 0.16);
uniform vec3 tip : source_color = vec3(1.0, 0.86, 0.6);
uniform vec3 ash : source_color = vec3(0.16, 0.13, 0.11);
uniform float heat = 2.4;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	if (UV.x > reveal) {
		discard;
	}
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float edge = smoothstep(0.0, 0.6, across);
	float near_tip = smoothstep(reveal - 0.07, reveal, UV.x) * (1.0 - cool);
	// 刚写过的地方比写得早的地方热一点。
	float fresh = mix(0.7, 1.0, smoothstep(reveal - 0.5, reveal, UV.x));
	vec3 hot = mix(ember * fresh, tip * 1.6, near_tip) * heat;
	ALBEDO = mix(hot, ash, cool);
	ALPHA = edge * (1.0 - fade) * mix(1.0, 0.75, cool);
}
