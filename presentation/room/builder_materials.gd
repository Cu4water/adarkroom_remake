class_name BuilderMaterials
extends RefCounted
## 把 Blender 导出的 3D 建造者材质按名字换成手绘水粉 PBR 着色器，并统一控制模糊人影程度。
##
## 配色取自 docs/art.md 色表与立绘（Art/characters/builder_2d_standee.png）：
## 橄榄褐兜帽披肩 × 灰蓝帆布围裙 × 做旧暖褐皮革工具带 × 暗陶红铁钳点缀。

const SURFACE_SHADER := preload("res://presentation/room/shaders/builder_surface.gdshader")

## 每种材质的三段线性色带（暗、中、亮）与表面参数。
const SURFACES: Dictionary[String, Dictionary] = {
	"Mat_Builder_Skin": {
		"ramp": [Vector3(0.22, 0.11, 0.07), Vector3(0.42, 0.23, 0.145), Vector3(0.60, 0.36, 0.24)],
		"roughness": 0.78, "scale": 4.0, "ao": 0.55, "grime": 0.05,
	},
	"Mat_Builder_Hair": {
		"ramp": [Vector3(0.012, 0.009, 0.007), Vector3(0.032, 0.024, 0.019), Vector3(0.075, 0.055, 0.042)],
		"roughness": 0.86, "scale": 8.0, "ao": 0.65, "grime": 0.0,
	},
	"Mat_Builder_Shirt": {
		"ramp": [Vector3(0.18, 0.125, 0.068), Vector3(0.35, 0.255, 0.145), Vector3(0.50, 0.38, 0.23)],
		"roughness": 0.90, "scale": 6.0, "ao": 0.65, "grime": 0.18,
	},
	"Mat_Builder_Wrap": {
		"ramp": [Vector3(0.24, 0.19, 0.13), Vector3(0.43, 0.35, 0.245), Vector3(0.58, 0.49, 0.36)],
		"roughness": 0.94, "scale": 9.0, "ao": 0.55, "grime": 0.25,
	},
	"Mat_Builder_Trousers": {
		"ramp": [Vector3(0.075, 0.070, 0.036), Vector3(0.155, 0.142, 0.075), Vector3(0.24, 0.215, 0.12)],
		"roughness": 0.92, "scale": 6.5, "ao": 0.68, "grime": 0.35,
	},
	"Mat_Builder_Leather": {
		"ramp": [Vector3(0.085, 0.042, 0.018), Vector3(0.19, 0.095, 0.042), Vector3(0.31, 0.165, 0.078)],
		"roughness": 0.72, "scale": 5.5, "ao": 0.65, "grime": 0.30,
	},
	"Mat_Builder_LeatherDark": {
		"ramp": [Vector3(0.035, 0.018, 0.009), Vector3(0.085, 0.045, 0.022), Vector3(0.145, 0.082, 0.042)],
		"roughness": 0.78, "scale": 6.0, "ao": 0.60, "grime": 0.40,
	},
	"Mat_Builder_Apron": {
		"ramp": [Vector3(0.055, 0.095, 0.125), Vector3(0.115, 0.175, 0.220), Vector3(0.195, 0.265, 0.320)],
		"roughness": 0.91, "scale": 5.5, "ao": 0.65, "grime": 0.35,
	},
	"Mat_Builder_Cloak": {
		"ramp": [Vector3(0.090, 0.092, 0.045), Vector3(0.185, 0.180, 0.092), Vector3(0.285, 0.270, 0.148)],
		"roughness": 0.94, "scale": 5.0, "ao": 0.70, "grime": 0.22,
	},
	"Mat_Builder_Iron": {
		"ramp": [Vector3(0.035, 0.038, 0.042), Vector3(0.085, 0.090, 0.100), Vector3(0.165, 0.170, 0.180)],
		"roughness": 0.56, "metallic": 0.55, "scale": 6.0, "ao": 0.55, "grime": 0.15,
	},
	"Mat_Builder_Rust": {
		"ramp": [Vector3(0.15, 0.048, 0.024), Vector3(0.30, 0.105, 0.052), Vector3(0.44, 0.165, 0.088)],
		"roughness": 0.78, "scale": 7.0, "ao": 0.55, "grime": 0.20,
	},
	"Mat_Builder_Brass": {
		"ramp": [Vector3(0.18, 0.115, 0.035), Vector3(0.38, 0.25, 0.085), Vector3(0.58, 0.42, 0.16)],
		"roughness": 0.42, "metallic": 0.68, "scale": 5.0, "ao": 0.45, "grime": 0.10,
	},
	"Mat_Builder_Rope": {
		"ramp": [Vector3(0.16, 0.115, 0.062), Vector3(0.33, 0.245, 0.135), Vector3(0.48, 0.37, 0.22)],
		"roughness": 0.95, "scale": 10.0, "ao": 0.65, "grime": 0.20,
	},
	"Mat_Builder_Wood": {
		"ramp": [Vector3(0.14, 0.075, 0.035), Vector3(0.28, 0.16, 0.078), Vector3(0.44, 0.26, 0.125)],
		"roughness": 0.80, "scale": 5.0, "ao": 0.60, "grime": 0.15,
	},
}

var _cache: Dictionary[String, ShaderMaterial] = {}
var _unknown: Dictionary[String, bool] = {}


## 把 root 下所有网格的材质换成手绘水粉材质并开启阴影投射。
func apply(root: Node) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node
		if instance.mesh == null:
			continue
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for surface: int in instance.mesh.get_surface_count():
			var source := instance.mesh.surface_get_material(surface)
			if source == null:
				continue
			var mat := _material_for(source.resource_name)
			if mat != null:
				instance.set_surface_override_material(surface, mat)


## 统一设置所有人影材质的模糊/暗影程度（0 清楚，1 暗影模糊）。
func set_blur(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	for mat: ShaderMaterial in _cache.values():
		mat.set_shader_parameter(&"blur", clamped)


## Blender 里的材质名是否在契约表里。
func knows(material_name: String) -> bool:
	return SURFACES.has(material_name)


func _material_for(material_name: String) -> ShaderMaterial:
	if _cache.has(material_name):
		return _cache[material_name]
	if SURFACES.has(material_name):
		var mat := _build(SURFACES[material_name])
		_cache[material_name] = mat
		return mat
	if not _unknown.has(material_name):
		_unknown[material_name] = true
		push_warning("建造者模型里有一个不认识的材质，保持导入时的样子: %s" % material_name)
	return null


func _build(params: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SURFACE_SHADER
	var colors: Array = params["ramp"]
	mat.set_shader_parameter(&"color_dark", colors[0])
	mat.set_shader_parameter(&"color_mid", colors[1])
	mat.set_shader_parameter(&"color_light", colors[2])
	mat.set_shader_parameter(&"roughness", params.get("roughness", 0.88))
	mat.set_shader_parameter(&"metallic", params.get("metallic", 0.0))
	mat.set_shader_parameter(&"noise_scale", params.get("scale", 5.0))
	mat.set_shader_parameter(&"ao_strength", params.get("ao", 0.62))
	mat.set_shader_parameter(&"grime_strength", params.get("grime", 0.25))
	return mat
