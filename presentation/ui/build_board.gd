class_name BuildBoard
extends Control
## 建造者递过来的那块板子（参考《铁巢重炮》的剪贴板）：一块木夹板夹着一张纸，纸上是她用铅笔画的
## 能造的东西。拿到以后平时斜拿在画面右下角，只露出一角，角上夹着一片画了 Tab 键的签条；
## 按住 Tab 举到画面正中放大，放出鼠标，一松手就放回去。
##
## 纸上：顶上是手头有多少木头；下面每样东西一行，一张小图、要多少木头、已有几个 / 最多几个。
## 现在造得成的写得深，造不成的淡；造满了的划掉。点一样就让模拟去造（village.build）。
## 只有图和手写的数字，没有字。assets/ui/board/ 里有手绘图就用图（见 BoardIcon、HandNumber），
## clipboard.png 是整块夹板的底图。

signal raised
signal lowered

enum Pose { AWAY, HELD, RAISED }

## 第一章只到陷阱和车。小屋是第二章的事，不上这块板。
const ENTRIES: Array[StringName] = [ForestSystem.TRAP, ForestSystem.CART]
const ICONS: Dictionary[StringName, BoardIcon.Kind] = {
	ForestSystem.TRAP: BoardIcon.Kind.TRAP,
	ForestSystem.CART: BoardIcon.Kind.CART,
}
const WOOD := &"wood"
const CLIPBOARD_ART := "res://assets/ui/board/clipboard.png"

## 夹板的大小（举起来时的像素），纸边距（上、右、下、左，占夹板的比例）。
@export var sheet_size := Vector2(430.0, 570.0)
@export var paper_margin := Vector4(0.13, 0.08, 0.06, 0.08)
## 平时拿在右下角：缩多小、斜多少、露出来的那一角有多大（像素）。
@export var held_scale := 0.42
@export var held_tilt := 0.3
@export var held_peek := Vector2(140.0, 150.0)
## 举起来时斜多少，以及动作多快。松开 Tab 时放回去得快，不拖泥带水。
@export var raised_tilt := -0.03
@export var move_seconds := 0.3
@export var release_seconds := 0.1
## 左上角那片签条：宽、高（夹板像素），以及压在夹板底下的那一截有多长。
@export var tab_size := Vector2(150.0, 100.0)
@export var tab_tuck := 24.0
@export var ink := Color(0.2, 0.18, 0.16)
@export var paper := Color(0.86, 0.8, 0.67)
@export var wood := Color(0.38, 0.25, 0.15)
## 造不成的那一项淡到多少。
@export var faint := 0.35

var _pose := Pose.AWAY
var _sheet: Control
var _tab: Control
var _wood_number: HandNumber
var _entries: Dictionary[StringName, Entry] = {}
var _tween: Tween


## 纸上的一行。可以点；鼠标停在上面时用铅笔圈起来，造满了就划一道。
class Entry extends Button:
	var ink := Color.BLACK
	var maxed := false
	var cost: HandNumber
	var owned: HandNumber

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size).grow(-4.0)
		if is_hovered() and not maxed:
			var ring := PackedVector2Array()
			for k: int in 30:
				var a := -2.6 + TAU * 1.06 * k / 29.0
				var wobble := 1.0 + 0.03 * sin(a * 3.0)
				ring.append(r.get_center() + Vector2(cos(a) * r.size.x * 0.5, sin(a) * r.size.y * 0.5) * wobble)
			draw_polyline(ring, Color(ink, 0.7), 2.2, true)
		if maxed:
			draw_line(Vector2(r.position.x, r.get_center().y + 6.0), Vector2(r.end.x, r.get_center().y - 4.0),
				Color(ink, 0.8), 2.6, true)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet = Control.new()
	_sheet.size = sheet_size
	_sheet.pivot_offset = sheet_size * 0.5
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.draw.connect(_draw_sheet)
	add_child(_sheet)
	_tab = Control.new()
	_tab.position = Vector2(sheet_size.x * 0.06, tab_tuck - tab_size.y)
	_tab.size = tab_size
	_tab.show_behind_parent = true
	_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab.draw.connect(_draw_tab)
	_sheet.add_child(_tab)

	var margin := MarginContainer.new()
	margin.position = Vector2(paper_margin.w, paper_margin.x) * sheet_size
	margin.size = sheet_size * Vector2(1.0 - paper_margin.y - paper_margin.w, 1.0 - paper_margin.x - paper_margin.z)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	_sheet.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 10)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override(&"separation", 10)
	header.add_child(_icon(BoardIcon.Kind.WOOD, 46.0))
	_wood_number = _number(34.0)
	header.add_child(_wood_number)
	column.add_child(header)
	for id: StringName in ENTRIES:
		column.add_child(_entry(id))
	visible = false

	# 拿在右下角时露出来的那一角正好是木头数，所以不管举没举起来，模拟一变就重写。
	var events: SimEvents = Game.events
	events.store_changed.connect(_refresh_if_shown.unbind(4))
	events.building_changed.connect(_refresh_if_shown.unbind(2))
	events.temperature_changed.connect(_refresh_if_shown.unbind(1))
	events.unlocked.connect(_refresh_if_shown.unbind(1))
	events.state_replaced.connect(_refresh_if_shown)


## 她把板子递过来：从画面下方滑进右下角。
func give() -> void:
	if _pose != Pose.AWAY:
		return
	_refresh()
	visible = true
	var held := _held_place()
	_sheet.position = held[0] + Vector2(0.0, sheet_size.y)
	_sheet.rotation = held[1]
	_sheet.scale = Vector2.ONE * held_scale
	_go(Pose.HELD, move_seconds * 2.0)


## 按存档直接摆好：有板子就拿在右下角，没有就不显示。
func set_owned(owned: bool) -> void:
	if _tween != null:
		_tween.kill()
	_pose = Pose.HELD if owned else Pose.AWAY
	visible = owned
	_set_interactive(false)
	_tab.modulate.a = 1.0
	if owned:
		_refresh()
		var held := _held_place()
		_sheet.position = held[0]
		_sheet.rotation = held[1]
		_sheet.scale = Vector2.ONE * held_scale


func is_raised() -> bool:
	return _pose == Pose.RAISED


func raise() -> void:
	if _pose == Pose.HELD:
		_refresh()
		_go(Pose.RAISED, move_seconds)
		raised.emit()


func lower() -> void:
	if _pose == Pose.RAISED:
		_go(Pose.HELD, release_seconds)
		lowered.emit()


## 屋里有多亮，0 到 1。火小了，手里的纸也跟着暗下去。
func set_light(level: float) -> void:
	var shade := lerpf(0.28, 1.0, clampf(level, 0.0, 1.0))
	modulate = Color(shade, shade * 0.97, shade * 0.92)


## 窗口失焦时收不到松开 Tab 的事件，所以每帧再对一下：举着的时候 Tab 已经不按着了就放回去。
func _process(_delta: float) -> void:
	if _pose == Pose.RAISED and not Input.is_action_pressed(&"board"):
		lower()


func _unhandled_input(event: InputEvent) -> void:
	if _pose == Pose.AWAY or not event.is_action(&"board") or event.is_echo():
		return
	if event.is_pressed():
		raise()
	else:
		lower()
	get_viewport().set_input_as_handled()


func _go(pose: Pose, seconds: float) -> void:
	_pose = pose
	_set_interactive(pose == Pose.RAISED)
	var place := _raised_place() if pose == Pose.RAISED else _held_place()
	var size_scale := _raised_scale() if pose == Pose.RAISED else held_scale
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_sheet, ^"position", place[0], seconds)
	_tween.tween_property(_sheet, ^"rotation", place[1], seconds)
	_tween.tween_property(_sheet, ^"scale", Vector2.ONE * size_scale, seconds)
	_tween.tween_property(_tab, ^"modulate:a", 0.0 if pose == Pose.RAISED else 1.0, seconds)


## [左上角位置, 旋转]：右下角只露出一角，像斜拿在右手里。
func _held_place() -> Array:
	var screen := get_viewport_rect().size
	var visible_center := screen - held_peek + sheet_size * held_scale * 0.5
	return [visible_center - sheet_size * 0.5, held_tilt]


func _raised_place() -> Array:
	return [(get_viewport_rect().size - sheet_size) * 0.5, raised_tilt]


## 举起来时占画面高度的九成左右。
func _raised_scale() -> float:
	return minf(get_viewport_rect().size.y * 0.92 / sheet_size.y, 1.25)


func _set_interactive(on: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	for entry: Entry in _entries.values():
		entry.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


func _refresh_if_shown() -> void:
	if _pose != Pose.AWAY:
		_refresh()


func _refresh() -> void:
	var sim: Simulation = Game.sim
	_wood_number.text = str(sim.store(WOOD))
	for id: StringName in ENTRIES:
		var entry := _entries[id]
		entry.visible = sim.has_feature(VillageSystem.plan_feature(id))
		if not entry.visible:
			continue
		var def: BuildingDef = sim.content.buildings[id]
		var owned := sim.building(id)
		entry.owned.text = "%d/%d" % [owned, def.maximum]
		entry.maxed = owned >= def.maximum
		entry.cost.text = "-" if entry.maxed else str(def.cost_for(owned).get(WOOD, 0))
		var ready := VillageSystem.can_build(sim, id) == Simulation.OK
		entry.modulate.a = 1.0 if ready else faint
		entry.queue_redraw()


func _on_entry_pressed(id: StringName) -> void:
	var entry := _entries[id]
	var tween := create_tween()
	if Game.sim.act(VillageSystem.CMD_BUILD, {"id": id}) == Simulation.OK:
		entry.scale = Vector2.ONE * 1.05
		tween.tween_property(entry, ^"scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)
	else:
		var x := entry.position.x
		for offset: float in [-5.0, 4.0, -2.0, 0.0]:
			tween.tween_property(entry, ^"position:x", x + offset, 0.05)
	_refresh()


func _draw_sheet() -> void:
	var rect := Rect2(Vector2.ZERO, sheet_size)
	if ResourceLoader.exists(CLIPBOARD_ART):
		_sheet.draw_texture_rect(load(CLIPBOARD_ART) as Texture2D, rect, false)
		return
	var board := StyleBoxFlat.new()
	board.bg_color = wood
	board.set_corner_radius_all(14)
	board.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	board.shadow_size = 14
	_sheet.draw_style_box(board, rect)
	var sheet_rect := Rect2(Vector2(paper_margin.w, paper_margin.x) * sheet_size,
		sheet_size * Vector2(1.0 - paper_margin.y - paper_margin.w, 1.0 - paper_margin.x - paper_margin.z))
	_sheet.draw_rect(sheet_rect, paper)
	# 纸边一圈旧了的暗黄，像在火边放久了。
	_sheet.draw_rect(sheet_rect, Color(0.55, 0.42, 0.25, 0.35), false, 6.0)
	var clip := Rect2(sheet_size.x * 0.32, sheet_size.y * 0.035, sheet_size.x * 0.36, sheet_size.y * 0.11)
	var metal := StyleBoxFlat.new()
	metal.bg_color = Color(0.3, 0.29, 0.27)
	metal.set_corner_radius_all(8)
	_sheet.draw_style_box(metal, clip)
	_sheet.draw_rect(clip.grow(-6.0), Color(0.42, 0.4, 0.37), false, 2.0)


## 签条：一截旧纸从夹板上沿底下露出来，上面用铅笔描了一个键帽，键帽里是 Tab 键的 ↹，不写字。
func _draw_tab() -> void:
	var shown := Rect2(Vector2.ZERO, Vector2(tab_size.x, tab_size.y - tab_tuck))
	var label := StyleBoxFlat.new()
	label.bg_color = paper.darkened(0.12)
	label.corner_radius_top_left = 12
	label.corner_radius_top_right = 12
	label.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	label.shadow_size = 6
	_tab.draw_style_box(label, Rect2(Vector2.ZERO, tab_size))
	var pencil := Color(ink, 0.85)
	var key := shown.grow(-14.0)
	var key_box := StyleBoxFlat.new()
	key_box.draw_center = false
	key_box.border_color = pencil
	key_box.set_border_width_all(3)
	key_box.set_corner_radius_all(9)
	_tab.draw_style_box(key_box, key)
	var left := key.position.x + key.size.x * 0.22
	var right := key.end.x - key.size.x * 0.22
	var upper := key.position.y + key.size.y * 0.28
	var lower_y := key.position.y + key.size.y * 0.74
	var head := key.size.y * 0.16
	_tab.draw_line(Vector2(left, upper), Vector2(right, upper), pencil, 3.0, true)
	_tab.draw_polyline(PackedVector2Array([Vector2(right - head, upper - head), Vector2(right, upper),
		Vector2(right - head, upper + head)]), pencil, 3.0, true)
	_tab.draw_line(Vector2(right + 4.0, upper - head), Vector2(right + 4.0, upper + head), pencil, 3.0, true)
	_tab.draw_line(Vector2(right, lower_y), Vector2(left, lower_y), pencil, 3.0, true)
	_tab.draw_polyline(PackedVector2Array([Vector2(left + head, lower_y - head), Vector2(left, lower_y),
		Vector2(left + head, lower_y + head)]), pencil, 3.0, true)
	_tab.draw_line(Vector2(left - 4.0, lower_y - head), Vector2(left - 4.0, lower_y + head), pencil, 3.0, true)


func _entry(id: StringName) -> Entry:
	var entry := Entry.new()
	entry.ink = ink
	entry.pressed.connect(_on_entry_pressed.bind(id))
	entry.resized.connect(func() -> void: entry.pivot_offset = entry.size * 0.5)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override(&"separation", 16)
	entry.add_child(row)
	row.add_child(_icon(ICONS[id], 104.0))
	var numbers := VBoxContainer.new()
	numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	numbers.alignment = BoxContainer.ALIGNMENT_CENTER
	var cost_row := HBoxContainer.new()
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.add_theme_constant_override(&"separation", 6)
	cost_row.add_child(_icon(BoardIcon.Kind.WOOD, 30.0))
	entry.cost = _number(30.0)
	cost_row.add_child(entry.cost)
	numbers.add_child(cost_row)
	entry.owned = _number(24.0)
	entry.owned.ink = Color(ink, 0.75)
	numbers.add_child(entry.owned)
	row.add_child(numbers)
	entry.custom_minimum_size = Vector2(0.0, 118.0)
	_entries[id] = entry
	return entry


func _icon(kind: BoardIcon.Kind, side: float) -> BoardIcon:
	var icon := BoardIcon.new(kind, side)
	icon.color = ink
	return icon


func _number(height: float) -> HandNumber:
	var number := HandNumber.new("", height)
	number.ink = ink
	number.variant = hash(height)
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return number
