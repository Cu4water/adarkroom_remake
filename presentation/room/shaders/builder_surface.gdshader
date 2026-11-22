shader_type spatial;
// 建造者 3D 模型的手绘水粉 PBR 着色器，与小屋 hut_surface.gdshader 同一套视觉语言。
//
// 材质用 UV 空间里的多层 FBM 笔触混合三段线性色带，动画播放时笔触跟着布料走、不滑移；
// 顶点色来自 Blender 导出：R=零件微色差，G=BVH 烘焙的几何 AO 阴影，B=下摆磨损脏旧。
//
// 模糊人影（blur 0..1）：
//   她刚跌进门倒在角落时 blur 接近 1：色彩褪成炭灰黑影、笔触抹平、轮廓边缘被暗影柔化吞噬，
//   在火光边缘只显出一团朦胧颤抖的人影；随着屋子变暖、她缓过来，衣服的色块与细节一点点浮现。

#include "noise.gdshaderinc"

uniform vec3 color_dark = vec3(0.08);
uniform vec3 color_mid = vec3(0.18);
uniform vec3 color_light = vec3(0.32);
uniform float roughness : hint_range(0.0, 1.0) = 0.88;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float noise_scale = 5.0;
// 顶点 AO 对明暗的压暗强度，让兜帽深处、围巾和腰带缝隙更有手绘体积感。
uniform float ao_strength : hint_range(0.0, 1.0) = 0.62;
// 下摆和靴底的脏旧压暗强度。
uniform float grime_strength : hint_range(0.0, 1.0) = 0.25;
// 0 是清楚的人，1 是暗处一团看不清细节的模糊人影。
uniform float blur : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_color;

vec3 ramp(vec3 dark, vec3 mid, vec3 light, float t) {
	vec3 color = mix(dark, mid, clamp((t - 0.22) / 0.28, 0.0, 1.0));
	return mix(color, light, clamp((t - 0.5) / 0.28, 0.0, 1.0));
}

void vertex() {
	v_color = COLOR.rgb;
}

void fragment() {
	float piece = v_color.r;
	float ao = mix(1.0, v_color.g, ao_strength);
	float grime = v_color.b * grime_strength;

	vec3 p = vec3(UV * noise_scale, piece * 17.0);
	float broad = fbm(p);
	float fine = fbm(p * 4.5 + vec3(5.1, 2.7, 3.3));
	float t = mix(broad, fine, 0.22 * (1.0 - blur * 0.8));
	t = clamp((t - 0.5) * 1.65 + 0.5 + (piece - 0.5) * 0.14, 0.0, 1.0);

	vec3 painted = ramp(color_dark, color_mid, color_light, t);
	painted *= ao * (1.0 - grime * 0.45);

	// 模糊人影态：色彩褪去并压成暗灰黑影，轮廓边缘按视线夹角进一步柔暗融入黑暗。
	float luma = dot(painted, vec3(0.3, 0.59, 0.11));
	float ndotv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float rim_fade = mix(1.0, smoothstep(0.08, 0.72, ndotv), blur * 0.88);
	vec3 shadow_tone = vec3(luma * 0.34 + 0.015) * rim_fade;
	ALBEDO = mix(painted, shadow_tone, blur * 0.90);

	ROUGHNESS = clamp(mix(roughness + (fine - 0.5) * 0.14, 0.98, blur), 0.0, 1.0);
	METALLIC = metallic * (1.0 - blur);
	SPECULAR = mix(0.22, 0.02, blur);
}

void light() {
	// 模糊态略增包裹漫反射，让她在火光边缘虽看不清五官衣着，仍能读出人的轮廓。
	float wrap = mix(0.12, 0.42, blur);
	float ndotl = clamp((dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap), 0.0, 1.0);
	DIFFUSE_LIGHT += ndotl * ATTENUATION * LIGHT_COLOR / PI;
}
