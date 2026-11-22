class_name NarrationLog
extends Control
## 屋里发生的事，一行一行写在屏幕左边。最新的在最上面，越旧越淡，和原版一样。
##
## 这是第一章里唯一的界面。没有数值，没有按钮，没有进度条。

const MAX_LINES := 7
## 每往下一行，不透明度乘上这个数。
const DIMMING := 0.62

@export var text_color := Color(0.87, 0.83, 0.75)
@export var font_size := 18
@export var line_width := 330.0
@export var margin := Vector2(34.0, 30.0)

var _box: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = VBoxContainer.new()
	_box.position = margin
	_box.custom_minimum_size.x = line_width
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override(&"separation", 10)
	add_child(_box)


## 模拟层给的是文案的键和参数，这里换成要显示的那句话。
static func compose(key: StringName, args: Dictionary) -> String:
	var values := {}
	for arg: Variant in args:
		var value: Variant = args[arg]
		if value is Array:
			# 数组里装的是内容 id，换成名字再拼起来。
			var ids: Array = value
			var names: PackedStringArray = []
			for id: Variant in ids:
				names.append(TranslationServer.translate("item.%s" % id))
			values[arg] = "、".join(names)
		else:
			values[arg] = value
	return String(TranslationServer.translate(key)).format(values)


func push(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = line_width
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", text_color)
	label.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override(&"shadow_offset_x", 1)
	label.add_theme_constant_override(&"shadow_offset_y", 1)
	label.modulate.a = 0.0
	_box.add_child(label)
	_box.move_child(label, 0)
	while _box.get_child_count() > MAX_LINES:
		var oldest := _box.get_child(-1)
		_box.remove_child(oldest)
		oldest.queue_free()


func clear() -> void:
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.queue_free()


func _process(delta: float) -> void:
	var target := 1.0
	for child: Node in _box.get_children():
		var label: Label = child
		label.modulate.a = move_toward(label.modulate.a, target, delta * 0.8)
		target *= DIMMING
