class_name BoardIcon
extends Control
## 数据板上的线描小图：木头、陷阱、车。不用贴图，直接按比例画线，缩放到多大都清楚。

enum Kind { WOOD, TRAP, CART }

@export var kind := Kind.WOOD:
	set(value):
		kind = value
		queue_redraw()
@export var color := Color(0.95, 0.82, 0.62):
	set(value):
		color = value
		queue_redraw()
## 线宽，占图标边长的比例。
@export var line := 0.045


func _init(icon_kind := Kind.WOOD, side := 48.0) -> void:
	kind = icon_kind
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
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
	draw_line(a * size, b * size, color, line * size.x, true)


func _poly(points: Array[Vector2]) -> void:
	var scaled := PackedVector2Array()
	for point: Vector2 in points:
		scaled.append(point * size)
	draw_polyline(scaled, color, line * size.x, true)


func _circle(center: Vector2, radius: float) -> void:
	draw_arc(center * size, radius * size.x, 0.0, TAU, 40, color, line * size.x, true)
