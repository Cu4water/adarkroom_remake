shader_type spatial;
// 小屋里所有不发光的表面共用这一个着色器：木头、灰泥、石头、铁。
//
// Blender 里的材质是"噪声 → 三段色带"的程序化节点，带不进 glTF。
// 这里用同样的思路在 Godot 里重做一遍，颜色直接取自 Blender 的色带，所以是线性空间的值。
// 等以后有了烘焙贴图，这个着色器就可以退役。

#include "noise.gdshaderinc"

uniform vec3 color_dark = vec3(0.1);
uniform vec3 color_mid = vec3(0.3);
uniform vec3 color_light = vec3(0.5);
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float noise_scale = 3.0;
// 木纹之类有方向的表面，沿纹理方向把噪声拉长。
uniform vec3 noise_stretch = vec3(1.0);
// 每个零件（一块木板、一块石头）整体偏亮或偏暗的幅度。
uniform float piece_variation : hint_range(0.0, 1.0) = 0.3;

// 墙面：墙裙以下是另一套颜色。
uniform bool wainscot = false;
uniform vec3 lower_dark = vec3(0.1);
uniform vec3 lower_mid = vec3(0.2);
uniform vec3 lower_light = vec3(0.3);
uniform float wainscot_height = 0.9;

// 火里的炭木：烧得越旺，缝里越红。
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform vec3 heat_color = vec3(1.0, 0.22, 0.025);

varying vec3 local_position;
varying float piece;

vec3 ramp(vec3 dark, vec3 mid, vec3 light, float t) {
	vec3 color = mix(dark, mid, clamp((t - 0.22) / 0.28, 0.0, 1.0));
	return mix(color, light, clamp((t - 0.5) / 0.28, 0.0, 1.0));
}

void vertex() {
	local_position = VERTEX;
	// 导出脚本把每个零件各自的随机值写在了顶点色的红色通道里。
	piece = COLOR.r;
}

void fragment() {
	vec3 p = local_position * noise_stretch * noise_scale + vec3(piece * 37.0, piece * 11.0, piece * 23.0);
	float broad = fbm(p);
	float fine = fbm(p * 5.0 + vec3(7.3, 1.9, 4.1));
	float t = mix(broad, fine, 0.22);
	t = (t - 0.5) * 1.7 + 0.5 + (piece - 0.5) * piece_variation;
	t = clamp(t, 0.0, 1.0);

	vec3 albedo = ramp(color_dark, color_mid, color_light, t);
	if (wainscot) {
		float edge = local_position.y + fbm(local_position * 0.85) * 0.2;
		float upper = smoothstep(wainscot_height, wainscot_height + 0.05, edge);
		albedo = mix(ramp(lower_dark, lower_mid, lower_light, t), albedo, upper);
	}

	ALBEDO = albedo;
	ROUGHNESS = clamp(roughness + (fine - 0.5) * 0.16, 0.0, 1.0);
	METALLIC = metallic;
	if (heat > 0.0) {
		float crack = smoothstep(0.42, 0.72, fbm(p * 2.6 + vec3(0.0, TIME * 0.04, 0.0)));
		EMISSION = heat_color * heat * crack * 3.0;
	}
}
