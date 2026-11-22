class_name HandNumber
extends Control
## 板子上用铅笔写的一个数（也可以带 "/" 和 "-"）。
## assets/ui/board/ 里有手绘的数字图（digit_0.png……digit_slash.png、digit_dash.png）就贴图，没有就按 HandGlyphs 画笔画。

const ART_DIR := "res://assets/ui/board/"
const ART_NAMES: Dictionary[String, String] = {"/": "slash", "-": "dash"}

@export var text := "":
	set(value):
		if value == text:
			return
		text = value
		_resize()
@export var glyph_height := 28.0:
	set(value):
		glyph_height = value
		_resize()
@export var ink := Color(0.2, 0.18, 0.16)
## 线宽，占字高的比例。
@export var line := 0.085
@export var variant := 1


func _init(start := "", height := 28.0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = start
	glyph_height = height


func _draw() -> void:
	var top := (size.y - glyph_height) * 0.5
	if _has_art():
		var x := 0.0
		for i: int in text.length():
			var texture := _art(text[i])
			var w := HandGlyphs.advance(text[i]) * glyph_height
			if texture != null:
				var aspect := float(texture.get_width()) / texture.get_height()
				var draw_w := glyph_height * aspect
				draw_texture_rect(texture, Rect2(x + (w - draw_w) * 0.5, top, draw_w, glyph_height), false, ink)
			x += w + HandGlyphs.GAP * glyph_height
		return
	var origin := Vector2(glyph_height * 0.06, top)
	for stroke: PackedVector2Array in HandGlyphs.layout(text, variant):
		var points := PackedVector2Array()
		for p: Vector2 in stroke:
			points.append(origin + p * glyph_height)
		# 铅笔：一道实线，再叠一道淡一点、稍微错开的，像压了两遍。
		draw_polyline(points, ink, line * glyph_height, true)
		var ghost := points.duplicate()
		for k: int in ghost.size():
			ghost[k] += Vector2(0.6, -0.5)
		draw_polyline(ghost, Color(ink, ink.a * 0.35), line * glyph_height * 0.6, true)


func _resize() -> void:
	custom_minimum_size = Vector2((HandGlyphs.width_of(text) + HandGlyphs.SLANT + 0.12) * glyph_height, glyph_height * 1.15)
	queue_redraw()


func _has_art() -> bool:
	return ResourceLoader.exists(ART_DIR + "digit_0.png")


func _art(ch: String) -> Texture2D:
	var path := ART_DIR + "digit_%s.png" % ART_NAMES.get(ch, ch)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
