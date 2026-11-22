class_name BoardIcon
extends Control
## 板子上她用铅笔画的小图：木头、陷阱、车。
## assets/ui/board/ 里有手绘图（icon_wood.png、icon_trap.png、icon_cart.png）就贴图，没有就画几笔抖动的铅笔线顶着。

enum Kind { WOOD, TRAP, CART }

const ART_DIR := "res://assets/ui/board/"
const ART_NAMES: Dictionary[Kind, String] = {Kind.WOOD: "wood", Kind.TRAP: "trap", Kind.CART: "cart"}

@export var kind := Kind.WOOD:
	set(value):
		kind = value
		queue_redraw()
@export var color := Color(0.2, 0.18, 0.16):
	set(value):
		color = value
		queue_redraw()
## 线宽，占图标边长的比例。
@export var line := 0.04


func _init(icon_kind := Kind.WOOD, side := 48.0) -> void:
	kind = icon_kind
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var path := ART_DIR + "icon_%s.png" % ART_NAMES[kind]
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		var aspect := float(texture.get_width()) / texture.get_height()
		var draw_size := Vector2(size.x, size.x / aspect) if aspect >= 1.0 else Vector2(size.y * aspect, size.y)
		draw_texture_rect(texture, Rect2((size - draw_size) * 0.5, draw_size), false, Color(1, 1, 1, color.a))
		return
	match kind:
		Kind.WOOD:
			_draw_wood()
		Kind.TRAP:
			_draw_trap()
		Kind.CART:
			_draw_cart()


## 码起来的三根柴，看见的是截面和年轮。
func _draw_wood() -> void:
	for center: Vector2 in [Vector2(0.3, 0.66), Vector2(0.7, 0.66), Vector2(0.5, 0.32)]:
		_circle(center, 0.19)
		_circle(center, 0.07)


## 箱式陷阱：一只倒扣的箱子一边用木棍支起来，底下放着饵。
func _draw_trap() -> void:
	_line(Vector2(0.06, 0.84), Vector2(0.94, 0.84))
	var corner := Vector2(0.26, 0.84)
	var along := Vector2(0.52, 0.0).rotated(-0.42)
	var up := Vector2(0.0, -0.44).rotated(-0.42)
	_poly([corner, corner + along, corner + along + up, corner + up, corner])
	_line(Vector2(0.78, 0.84), corner + along * 0.98)
	_circle(Vector2(0.56, 0.79), 0.04)


## 运柴的手推车：车斗里码着柴，一个轮子，两根把手。
func _draw_cart() -> void:
	_poly([Vector2(0.1, 0.38), Vector2(0.68, 0.38), Vector2(0.62, 0.64), Vector2(0.16, 0.64), Vector2(0.1, 0.38)])
	for center: Vector2 in [Vector2(0.25, 0.3), Vector2(0.4, 0.3), Vector2(0.55, 0.3)]:
		_circle(center, 0.07)
	_circle(Vector2(0.39, 0.76), 0.13)
	_circle(Vector2(0.39, 0.76), 0.02)
	_line(Vector2(0.66, 0.46), Vector2(0.94, 0.3))
	_line(Vector2(0.62, 0.62), Vector2(0.9, 0.86))


func _line(a: Vector2, b: Vector2) -> void:
	_poly([a, a.lerp(b, 0.5), b])


func _poly(points: Array[Vector2]) -> void:
	var stroke := PackedVector2Array()
	for k: int in points.size():
		var p := points[k]
		stroke.append(p + _wobble(k, p))
	_pencil(stroke)


func _circle(center: Vector2, radius: float) -> void:
	# 手画的圈：起笔和收笔错开一点，半径也不太匀。
	var stroke := PackedVector2Array()
	var steps := 22
	for k: int in steps + 2:
		var angle := -0.6 + TAU * k / steps
		var r := radius * (1.0 + 0.06 * sin(angle * 3.0 + center.x * 9.0))
		stroke.append(center + Vector2(cos(angle), sin(angle)) * r)
	_pencil(stroke)


## 铅笔线：一道实线，叠一道淡一点、稍微错开的。
func _pencil(stroke: PackedVector2Array) -> void:
	var scaled := PackedVector2Array()
	var ghost := PackedVector2Array()
	for p: Vector2 in stroke:
		scaled.append(p * size)
		ghost.append(p * size + Vector2(0.8, 0.6))
	draw_polyline(scaled, color, line * size.x, true)
	draw_polyline(ghost, Color(color, color.a * 0.3), line * size.x * 0.6, true)


func _wobble(index: int, p: Vector2) -> Vector2:
	var h := hash([int(kind), index, int(p.x * 100.0), int(p.y * 100.0)])
	return Vector2(float(h % 201) / 100.0 - 1.0, float(int(h / 201.0) % 201) / 100.0 - 1.0) * 0.012
