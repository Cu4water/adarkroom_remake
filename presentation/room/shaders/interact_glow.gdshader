shader_type spatial;
// 可交互物件的高亮，叠在物件原本的材质上（material_overlay）。
// 一层很淡的暖光，边缘稍亮，像火光多照到了它一点，不改物件本身的颜色。strength 为 0 时完全看不见。
// 不呼吸、不闪：亮度只跟着"能不能用、准星在不在上面"走，变化由脚本做淡入淡出。
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 glow_color : source_color = vec3(1.0, 0.68, 0.34);
uniform float strength : hint_range(0.0, 2.0) = 0.0;
uniform float rim_power = 2.2;
uniform float rim = 0.55;
uniform float fill = 0.22;

void fragment() {
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	ALBEDO = glow_color * (edge * rim + fill) * strength;
}
