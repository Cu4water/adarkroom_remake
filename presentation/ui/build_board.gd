class_name BuildBoard
extends Control
## 建造者递过来的数据板：上面是手头有多少木头，下面是她说过能造的东西。
## 每一样画一张线描小图，标着要多少木头、已经有几个、最多几个。现在造得成的亮着，造不成的暗着。
## 点一样就让模拟去造（village.build）；造不成时她会摇头或者打哆嗦，那是 BuilderFigure 演的。
##
## 只用图和数字，没有字。打开时放出鼠标；Esc、右键或者点数据板外面就收起来。

signal closed
signal built(id: StringName)

## 第一章只到陷阱和车。小屋是第二章的事，不上这块板。
const ENTRIES: Array[StringName] = [ForestSystem.TRAP, ForestSystem.CART]
const ICONS: Dictionary[StringName, BoardIcon.Kind] = {
	ForestSystem.TRAP: BoardIcon.Kind.TRAP,
	ForestSystem.CART: BoardIcon.Kind.CART,
}
const WOOD := &"wood"

@export var ink := Color(0.95, 0.84, 0.66)
@export var slate := Color(0.055, 0.05, 0.045, 0.96)
@export var rim := Color(0.62, 0.46, 0.28, 0.55)
## 造不成的那一项暗到多少。
@export var dim := 0.32
@export var open_seconds := 0.18

var _wood_label: Label
var _entries: Dictionary[StringName, Button] = {}
var _costs: Dictionary[StringName, Label] = {}
var _owned: Dictionary[StringName, Label] = {}
var _row: HBoxContainer
var _panel: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override(&"panel", _slate_style())
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 18)
	_panel.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 12)
	header.add_child(_icon(BoardIcon.Kind.WOOD, 40.0))
	_wood_label = _number(30)
	header.add_child(_wood_label)
	column.add_child(header)
	var rule := ColorRect.new()
	rule.color = Color(rim, 0.35)
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", 22)
	_row.custom_minimum_size = Vector2(420.0, 0.0)
	column.add_child(_row)
	for id: StringName in ENTRIES:
		_row.add_child(_entry(id))


func open() -> void:
	_refresh()
	visible = true
	modulate.a = 0.0
	_panel.scale = Vector2.ONE * 0.96
	_panel.pivot_offset = _panel.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, ^"modulate:a", 1.0, open_seconds)
	tween.tween_property(_panel, ^"scale", Vector2.ONE, open_seconds).set_trans(Tween.TRANS_SINE)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _process(_delta: float) -> void:
	if visible:
		_refresh()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		# 点到数据板外面的暗处，就是不看了。
		close()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var click := event as InputEventMouseButton
	var right_click := click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT
	if right_click or event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	var sim: Simulation = Game.sim
	_wood_label.text = str(sim.store(WOOD))
	for id: StringName in ENTRIES:
		var entry := _entries[id]
		entry.visible = sim.has_feature(VillageSystem.plan_feature(id))
		if not entry.visible:
			continue
		var def: BuildingDef = sim.content.buildings[id]
		var owned := sim.building(id)
		_owned[id].text = "%d / %d" % [owned, def.maximum]
		var cost := def.cost_for(owned)
		_costs[id].text = str(cost.get(WOOD, 0)) if owned < def.maximum else "-"
		var ready := VillageSystem.can_build(sim, id) == Simulation.OK
		entry.modulate.a = 1.0 if ready else dim


func _on_entry_pressed(id: StringName) -> void:
	var entry := _entries[id]
	var tween := create_tween()
	if Game.sim.act(VillageSystem.CMD_BUILD, {"id": id}) == Simulation.OK:
		built.emit(id)
		entry.scale = Vector2.ONE * 1.06
		tween.tween_property(entry, ^"scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)
	else:
		var x := entry.position.x
		for offset: float in [-6.0, 5.0, -3.0, 0.0]:
			tween.tween_property(entry, ^"position:x", x + offset, 0.05)


func _entry(id: StringName) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(ink, 0.06)
	hover.border_color = Color(rim, 0.5)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(8)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(ink, 0.12)
	button.add_theme_stylebox_override(&"hover", hover)
	button.add_theme_stylebox_override(&"pressed", pressed)
	button.add_theme_stylebox_override(&"hover_pressed", pressed)
	button.custom_minimum_size = Vector2(190.0, 0.0)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_entry_pressed.bind(id))
	button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 8)
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(column)
	var picture := _icon(ICONS[id], 112.0)
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(picture)
	var cost_row := HBoxContainer.new()
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_child(_icon(BoardIcon.Kind.WOOD, 24.0))
	_costs[id] = _number(24)
	cost_row.add_child(_costs[id])
	column.add_child(cost_row)
	_owned[id] = _number(18)
	_owned[id].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_owned[id].modulate.a = 0.7
	column.add_child(_owned[id])
	button.custom_minimum_size.y = 112.0 + 24.0 + 18.0 * 1.4 + 40.0
	_entries[id] = button
	return button


func _icon(kind: BoardIcon.Kind, side: float) -> BoardIcon:
	var icon := BoardIcon.new(kind, side)
	icon.color = ink
	return icon


func _number(font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", ink)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _slate_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = slate
	style.border_color = rim
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(28.0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	style.shadow_size = 18
	return style
