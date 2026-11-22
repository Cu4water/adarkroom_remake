class_name HandGlyphs
extends RefCounted
## 手写的数字：每个字是几笔折线，排版时加一点右斜和抖动，像用铅笔或炭条随手写的。
## 数据板上的数字和柴堆上方用火星写出来的数都用它。纯数据和纯函数，不碰节点。
##
## 字形坐标：高为 1，y 向下，宽度见 ADVANCE。排好的笔画按书写顺序排列。

const ADVANCE := 0.6
const NARROW := 0.42
const GAP := 0.14
## 往右斜多少（顶部相对底部右移，占字高的比例）。
const SLANT := 0.12
## 抖动幅度，占字高的比例。
const JITTER := 0.022

const GLYPHS: Dictionary[String, Array] = {
	"0": [[Vector2(0.34, 0.03), Vector2(0.14, 0.12), Vector2(0.05, 0.42), Vector2(0.09, 0.78), Vector2(0.27, 0.98),
		Vector2(0.46, 0.9), Vector2(0.55, 0.58), Vector2(0.52, 0.22), Vector2(0.38, 0.03), Vector2(0.24, 0.07)]],
	"1": [[Vector2(0.08, 0.22), Vector2(0.24, 0.04), Vector2(0.25, 0.97)]],
	"2": [[Vector2(0.06, 0.24), Vector2(0.15, 0.08), Vector2(0.31, 0.02), Vector2(0.47, 0.09), Vector2(0.52, 0.25),
		Vector2(0.45, 0.43), Vector2(0.05, 0.96), Vector2(0.57, 0.93)]],
	"3": [[Vector2(0.07, 0.13), Vector2(0.26, 0.02), Vector2(0.46, 0.08), Vector2(0.5, 0.24), Vector2(0.41, 0.4),
		Vector2(0.23, 0.47), Vector2(0.44, 0.54), Vector2(0.54, 0.72), Vector2(0.47, 0.9), Vector2(0.27, 0.98),
		Vector2(0.05, 0.9)]],
	"4": [[Vector2(0.38, 0.03), Vector2(0.05, 0.66), Vector2(0.58, 0.66)], [Vector2(0.43, 0.3), Vector2(0.42, 0.98)]],
	"5": [[Vector2(0.53, 0.04), Vector2(0.13, 0.05), Vector2(0.08, 0.45), Vector2(0.28, 0.38), Vector2(0.47, 0.46),
		Vector2(0.55, 0.67), Vector2(0.48, 0.88), Vector2(0.28, 0.98), Vector2(0.06, 0.9)]],
	"6": [[Vector2(0.49, 0.06), Vector2(0.31, 0.02), Vector2(0.13, 0.16), Vector2(0.06, 0.5), Vector2(0.08, 0.8),
		Vector2(0.24, 0.97), Vector2(0.43, 0.95), Vector2(0.54, 0.77), Vector2(0.5, 0.58), Vector2(0.32, 0.5),
		Vector2(0.14, 0.56), Vector2(0.07, 0.66)]],
	"7": [[Vector2(0.04, 0.06), Vector2(0.57, 0.04), Vector2(0.31, 0.5), Vector2(0.2, 0.98)]],
	"8": [[Vector2(0.31, 0.48), Vector2(0.11, 0.36), Vector2(0.1, 0.14), Vector2(0.3, 0.02), Vector2(0.5, 0.13),
		Vector2(0.5, 0.35), Vector2(0.31, 0.48), Vector2(0.08, 0.62), Vector2(0.07, 0.85), Vector2(0.3, 0.98),
		Vector2(0.54, 0.85), Vector2(0.52, 0.62), Vector2(0.31, 0.48)]],
	"9": [[Vector2(0.52, 0.34), Vector2(0.39, 0.46), Vector2(0.2, 0.46), Vector2(0.08, 0.31), Vector2(0.11, 0.11),
		Vector2(0.29, 0.02), Vector2(0.47, 0.08), Vector2(0.52, 0.34), Vector2(0.47, 0.98)]],
	"/": [[Vector2(0.48, 0.02), Vector2(0.1, 0.98)]],
	"-": [[Vector2(0.08, 0.56), Vector2(0.5, 0.52)]],
}


static func advance(ch: String) -> float:
	return NARROW if ch == "1" or ch == "/" or ch == "-" else ADVANCE


## 一串字排开以后多宽（字高为 1）。
static func width_of(text: String) -> float:
	var width := 0.0
	for i: int in text.length():
		width += advance(text[i]) + (GAP if i > 0 else 0.0)
	return width


## 一串字排好以后的全部笔画，坐标在 (0,0) 到 (width_of(text), 1) 的框里（斜体会稍微超出右边）。
## 同一个 variant 永远排出同一个样子；没有字形的字符留空位。笔画做了平滑，可以直接画。
static func layout(text: String, variant: int) -> Array[PackedVector2Array]:
	var strokes: Array[PackedVector2Array] = []
	var x := 0.0
	for i: int in text.length():
		var ch := text[i]
		if i > 0:
			x += GAP
		for stroke: Array in GLYPHS.get(ch, []):
			var points := PackedVector2Array()
			for k: int in stroke.size():
				var p: Vector2 = stroke[k]
				var wobble := Vector2(_noise(variant, i, k, 0), _noise(variant, i, k, 1)) * JITTER
				points.append(Vector2(x + p.x + (1.0 - p.y) * SLANT, p.y) + wobble)
			strokes.append(_smooth(points))
		x += advance(ch)
	return strokes


## 笔画的总长，用来按书写顺序一点点写出来。
static func length_of(strokes: Array[PackedVector2Array]) -> float:
	var total := 0.0
	for stroke: PackedVector2Array in strokes:
		for k: int in range(1, stroke.size()):
			total += stroke[k].distance_to(stroke[k - 1])
	return total


## Catmull-Rom 细分，让折线像一笔带过的弧。
static func _smooth(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var result := PackedVector2Array()
	for k: int in points.size() - 1:
		var p0 := points[maxi(k - 1, 0)]
		var p1 := points[k]
		var p2 := points[k + 1]
		var p3 := points[mini(k + 2, points.size() - 1)]
		for s: int in 4:
			result.append(p1.cubic_interpolate(p2, p0, p3, s / 4.0))
	result.append(points[points.size() - 1])
	return result


## 固定的伪随机抖动，-1 到 1。
static func _noise(variant: int, glyph: int, point: int, axis: int) -> float:
	var h := hash([variant, glyph, point, axis])
	return float(h % 2001) / 1000.0 - 1.0
