class_name HutMaterials
extends RefCounted
## 把 Blender 导出的小屋模型上的材质，按名字换成游戏里的材质。
##
## Blender 那边的材质全是程序化节点，带不进 glTF，导出来只剩名字。
## 这里的颜色取自 Blender 材质里的色带（线性空间），改了 Blender 的材质之后要在这里同步。
## 等以后有了烘焙贴图，这个文件和 hut_surface.gdshader 就可以退役。

const SURFACE_SHADER := preload("res://presentation/room/shaders/hut_surface.gdshader")
const FLAME_SHADER := preload("res://presentation/room/shaders/flame.gdshader")
const EMBER_SHADER := preload("res://presentation/room/shaders/ember.gdshader")

const GLASS := "Mat_Cabin_Glass"
const EMBERS := "Mat_Glowing_Embers"
const FLAME_CORE := "Mat_Flame_Core"
const FLAME_OUTER := "Mat_Flame_Outer"
const CHARRED := "Mat_Charred_Wood"

## 每种表面的参数。ramp 是暗、中、亮三段颜色。
const SURFACES: Dictionary[String, Dictionary] = {
	"Mat_Wood_Floor": {
		"ramp": [Vector3(0.16, 0.088, 0.042), Vector3(0.31, 0.175, 0.085), Vector3(0.48, 0.285, 0.138)],
		"roughness": 0.75, "scale": 3.2, "stretch": Vector3(1.8, 1.0, 0.55),
	},
	"Mat_Wood_Beam": {
		"ramp": [Vector3(0.07, 0.038, 0.018), Vector3(0.15, 0.082, 0.038), Vector3(0.24, 0.135, 0.065)],
		"roughness": 0.8, "scale": 3.2,
	},
	"Mat_Wood_Desk": {
		"ramp": [Vector3(0.22, 0.115, 0.048), Vector3(0.4, 0.22, 0.095), Vector3(0.58, 0.34, 0.155)],
		"roughness": 0.7, "scale": 3.2,
	},
	"Mat_Wall_Plaster": {
		"ramp": [Vector3(0.34, 0.24, 0.17), Vector3(0.48, 0.36, 0.26), Vector3(0.6, 0.47, 0.35)],
		"lower": [Vector3(0.075, 0.135, 0.135), Vector3(0.125, 0.205, 0.195), Vector3(0.19, 0.28, 0.26)],
		"roughness": 0.87, "scale": 2.4, "variation": 0.0,
	},
	"Mat_Red_Brick": {
		"ramp": [Vector3(0.18, 0.055, 0.032), Vector3(0.34, 0.115, 0.065), Vector3(0.48, 0.18, 0.105)],
		"roughness": 0.9, "scale": 6.0, "variation": 0.5,
	},
	"Mat_Doormat": {
		"ramp": [Vector3(0.14, 0.1, 0.065), Vector3(0.28, 0.21, 0.14), Vector3(0.42, 0.33, 0.22)],
		"roughness": 0.95, "scale": 9.0,
	},
	"Mat_Hearth_Stone": {
		"ramp": [Vector3(0.055, 0.052, 0.048), Vector3(0.115, 0.108, 0.098), Vector3(0.185, 0.172, 0.152)],
		"roughness": 0.9, "scale": 5.0, "variation": 0.45,
	},
	"Mat_Paint_Teal": {
		"ramp": [Vector3(0.08, 0.14, 0.16), Vector3(0.15, 0.24, 0.27), Vector3(0.24, 0.34, 0.36)],
		"roughness": 0.7, "scale": 4.0,
	},
	"Mat_Door_Olive": {
		"ramp": [Vector3(0.08, 0.12, 0.055), Vector3(0.16, 0.22, 0.095), Vector3(0.25, 0.31, 0.14)],
		"roughness": 0.72, "scale": 4.0,
	},
	"Mat_Dark_Iron": {
		"ramp": [Vector3(0.035, 0.038, 0.042), Vector3(0.08, 0.085, 0.095), Vector3(0.15, 0.155, 0.165)],
		"roughness": 0.55, "metallic": 0.5, "scale": 5.0,
	},
	"Mat_Ash_Bed": {
		"ramp": [Vector3(0.03, 0.028, 0.028), Vector3(0.08, 0.075, 0.072), Vector3(0.15, 0.14, 0.135)],
		"roughness": 0.97, "scale": 9.0,
	},
	CHARRED: {
		"ramp": [Vector3(0.015, 0.012, 0.01), Vector3(0.045, 0.032, 0.022), Vector3(0.12, 0.075, 0.042)],
		"roughness": 0.92, "scale": 7.0, "variation": 0.4,
	},
	"Mat_Night_Pine": {
		"ramp": [Vector3(0.008, 0.014, 0.022), Vector3(0.015, 0.024, 0.038), Vector3(0.024, 0.038, 0.055)],
		"roughness": 0.95, "scale": 2.0,
	},
}

## 这几个材质的参数会跟着火势变，FireRig 要直接改它们。
var flame_core: ShaderMaterial
var flame_outer: ShaderMaterial
var embers: ShaderMaterial
var charred: ShaderMaterial

var _cache: Dictionary[String, Material] = {}
var _unknown: Dictionary[String, bool] = {}


func _init() -> void:
	flame_core = _flame(Vector3(1.0, 0.8, 0.28), Vector3(1.0, 0.36, 0.04), Vector3(0.78, 0.08, 0.008))
	flame_outer = _flame(Vector3(1.0, 0.58, 0.1), Vector3(0.98, 0.26, 0.03), Vector3(0.65, 0.06, 0.01))
	embers = ShaderMaterial.new()
	embers.shader = EMBER_SHADER
	charred = _surface(SURFACES[CHARRED])
	_cache[FLAME_CORE] = flame_core
	_cache[FLAME_OUTER] = flame_outer
	_cache[EMBERS] = embers
	_cache[CHARRED] = charred
	_cache[GLASS] = _glass()


## 把 root 下面所有网格的材质换掉。
func apply(root: Node) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node
		if instance.mesh == null:
			continue
		for surface: int in instance.mesh.get_surface_count():
			var source := instance.mesh.surface_get_material(surface)
			if source == null:
				continue
			var material := _material_for(source.resource_name)
			if material != null:
				instance.set_surface_override_material(surface, material)


## 这个名字的材质有没有对应的游戏材质。Blender 里新加或改名了材质，这里就会是 false。
func knows(material_name: String) -> bool:
	return _cache.has(material_name) or SURFACES.has(material_name)


func _material_for(material_name: String) -> Material:
	if _cache.has(material_name):
		return _cache[material_name]
	if SURFACES.has(material_name):
		var material := _surface(SURFACES[material_name])
		_cache[material_name] = material
		return material
	if not _unknown.has(material_name):
		_unknown[material_name] = true
		push_warning("小屋模型里有一个不认识的材质，保持导入时的样子: %s" % material_name)
	return null


func _surface(params: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SURFACE_SHADER
	var colors: Array = params["ramp"]
	material.set_shader_parameter(&"color_dark", colors[0])
	material.set_shader_parameter(&"color_mid", colors[1])
	material.set_shader_parameter(&"color_light", colors[2])
	material.set_shader_parameter(&"roughness", params.get("roughness", 0.8))
	material.set_shader_parameter(&"metallic", params.get("metallic", 0.0))
	material.set_shader_parameter(&"noise_scale", params.get("scale", 3.0))
	material.set_shader_parameter(&"noise_stretch", params.get("stretch", Vector3.ONE))
	material.set_shader_parameter(&"piece_variation", params.get("variation", 0.3))
	if params.has("lower"):
		var lower: Array = params["lower"]
		material.set_shader_parameter(&"wainscot", true)
		material.set_shader_parameter(&"lower_dark", lower[0])
		material.set_shader_parameter(&"lower_mid", lower[1])
		material.set_shader_parameter(&"lower_light", lower[2])
	return material


func _flame(base: Vector3, mid: Vector3, tip: Vector3) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FLAME_SHADER
	material.set_shader_parameter(&"color_base", base)
	material.set_shader_parameter(&"color_mid", mid)
	material.set_shader_parameter(&"color_tip", tip)
	return material


## 不接受灯光的玻璃，火光和门外的光不会在上面亮成光斑。窗玻璃的倒影由 WindowReflection 另外配材质。
func _glass() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WindowReflection.GLASS_SHADER
	return material
