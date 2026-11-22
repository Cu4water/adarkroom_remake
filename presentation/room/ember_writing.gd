class_name EmberWriting
extends MeshInstance3D
## 在空中用火星写一串数：一笔一笔烧出来，停一会儿，冷成灰往上飘着散掉，然后自己删掉。
## 字形来自 HandGlyphs，和板子上的手写数字是同一套笔迹。

signal finished

const SHADER := preload("res://presentation/room/shaders/ember_writing.gdshader")

## 字高（米）、笔画宽（占字高的比例）。
@export var height := 0.16
@export var stroke_width := 0.085
## 每个字写多久、写完停多久、冷却散掉多久、散掉时往上飘多少。
@export var seconds_per_glyph := 0.28
@export var hold_seconds := 0.6
@export var cool_seconds := 1.1
@export var rise := 0.12

var _material: ShaderMaterial


## 写下 text。调用之前先把它放到要写的位置（字的正中）。
func write(text: String, variant: int) -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	mesh = build_mesh(HandGlyphs.layout(text, variant), HandGlyphs.width_of(text), height, stroke_width * height)
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var start := position
	var tween := create_tween()
	tween.tween_method(_set_param.bind(&"reveal"), 0.0, 1.02, seconds_per_glyph * text.length() + 0.1)
	tween.tween_interval(hold_seconds)
	tween.tween_method(_set_param.bind(&"cool"), 0.0, 1.0, cool_seconds * 0.6)
	tween.parallel().tween_method(_set_param.bind(&"fade"), 0.0, 1.0, cool_seconds).set_delay(cool_seconds * 0.2)
	tween.parallel().tween_property(self, ^"position", start + Vector3.UP * rise, cool_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_done)


## 把排好的笔画做成一条条带子：x 往右、y 往上，原点在整串字的正中。
## UV.x 是书写进度，UV.y 横跨带子。纯函数，测试可以直接调。
static func build_mesh(strokes: Array[PackedVector2Array], width: float, glyph_height: float,
		ribbon: float) -> ArrayMesh:
	var total := maxf(HandGlyphs.length_of(strokes), 0.0001)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var walked := 0.0
	var center := Vector2(width * 0.5 + HandGlyphs.SLANT * 0.5, 0.5)
	for stroke: PackedVector2Array in strokes:
		for k: int in stroke.size():
			var here := stroke[k]
			if k > 0:
				walked += here.distance_to(stroke[k - 1])
			var ahead := stroke[mini(k + 1, stroke.size() - 1)] - stroke[maxi(k - 1, 0)]
			var side := Vector2(-ahead.y, ahead.x).normalized() * ribbon * 0.5 / glyph_height
			for s: int in 2:
				var p := here + side * (1.0 if s == 0 else -1.0) - center
				vertices.append(Vector3(p.x, -p.y, 0.0) * glyph_height)
				uvs.append(Vector2(walked / total, float(s)))
			if k > 0:
				var base := vertices.size() - 4
				indices.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	if not vertices.is_empty():
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result


func _set_param(value: float, param: StringName) -> void:
	_material.set_shader_parameter(param, value)


func _done() -> void:
	finished.emit()
	queue_free()
