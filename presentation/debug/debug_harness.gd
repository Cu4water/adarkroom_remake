extends Control
## 开发用的调试台，不是游戏界面。
##
## 游戏本体不在屏幕上显示数值，所以开发时需要一个地方能看到模拟的全部状态，
## 并且手动发指令。这里也是表现层接模拟层的最小样例：只订阅事件，只发指令。

const LOG_LINES := 60
const TIME_SCALES: Array[float] = [1.0, 10.0, 60.0]
const DARK := Color(0.02, 0.02, 0.02)
const LIT := Color(0.32, 0.15, 0.04)

var _background: ColorRect
var _actions: VBoxContainer
var _log: RichTextLabel
var _readout: Label

var _fire_button: Button
var _gather_button: Button
var _traps_button: Button
var _speed_button: Button
var _build_buttons: Dictionary[StringName, Button] = {}

var _lines: PackedStringArray = []
var _scale_index := 0


func _ready() -> void:
	Game.ensure_booted()
	_build_ui()
	Game.events.narrated.connect(_on_narrated)
	Game.events.state_replaced.connect(_on_state_replaced)


func _process(_delta: float) -> void:
	var sim: Simulation = Game.sim
	var state := sim.state
	_fire_button.text = "生火" if state.fire == FireSystem.Level.DEAD else "添柴"
	_fire_button.disabled = sim.cooldown_left(FireSystem.COOLDOWN) > 0.0
	_gather_button.visible = sim.has_feature(ForestSystem.FEATURE)
	_gather_button.disabled = sim.cooldown_left(ForestSystem.CMD_GATHER) > 0.0
	_traps_button.visible = sim.building(ForestSystem.TRAP) > 0
	_traps_button.disabled = sim.cooldown_left(ForestSystem.CMD_TRAPS) > 0.0
	for id: StringName in _build_buttons:
		var def: BuildingDef = sim.content.buildings[id]
		var owned := sim.building(id)
		var button: Button = _build_buttons[id]
		button.visible = sim.has_feature(VillageSystem.FEATURE_BUILD)
		button.disabled = owned >= def.maximum or not sim.can_afford(def.cost_for(owned))
	_background.color = DARK.lerp(LIT, state.fire / 4.0)
	_readout.text = _describe(sim)


func _build_ui() -> void:
	_background = ColorRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	margin.add_child(columns)

	_actions = VBoxContainer.new()
	_actions.custom_minimum_size.x = 200.0
	columns.add_child(_actions)

	_log = RichTextLabel.new()
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	columns.add_child(_log)

	_readout = Label.new()
	_readout.custom_minimum_size.x = 300.0
	_readout.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	columns.add_child(_readout)

	_fire_button = _add_button("生火", _on_fire_pressed)
	_gather_button = _add_button("拾柴", _act.bind(ForestSystem.CMD_GATHER, {}))
	_traps_button = _add_button("查看陷阱", _act.bind(ForestSystem.CMD_TRAPS, {}))
	for id: StringName in Game.sim.content.buildings:
		var label := "建造 %s" % tr("building.%s" % id)
		_build_buttons[id] = _add_button(label, _act.bind(VillageSystem.CMD_BUILD, {"id": id}))

	_actions.add_child(HSeparator.new())
	_speed_button = _add_button("", _on_speed_pressed)
	_add_button("存档", Game.save)
	_add_button("新开一局", Game.new_run)
	_apply_time_scale()


func _add_button(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(pressed)
	_actions.add_child(button)
	return button


func _act(command: StringName, args: Dictionary) -> void:
	Game.sim.act(command, args)


func _on_fire_pressed() -> void:
	var dead := Game.sim.state.fire == FireSystem.Level.DEAD
	_act(FireSystem.CMD_LIGHT if dead else FireSystem.CMD_STOKE, {})


func _on_speed_pressed() -> void:
	_scale_index = (_scale_index + 1) % TIME_SCALES.size()
	_apply_time_scale()


func _apply_time_scale() -> void:
	var time_scale := TIME_SCALES[_scale_index]
	Game.sim.clock.time_scale = time_scale
	_speed_button.text = "开发倍速 ×%d" % int(time_scale)


func _on_narrated(key: StringName, args: Dictionary) -> void:
	_lines.append(tr(key).format(_localized(args)))
	if _lines.size() > LOG_LINES:
		_lines = _lines.slice(_lines.size() - LOG_LINES)
	_log.text = "\n".join(_lines)


func _on_state_replaced() -> void:
	_lines.clear()
	_log.text = ""


## 叙述参数里的数组装的是内容 id，这里换成名字再拼起来。
func _localized(args: Dictionary) -> Dictionary:
	var localized := {}
	for key: Variant in args:
		var value: Variant = args[key]
		if value is Array:
			var ids: Array = value
			var names: PackedStringArray = []
			for id: Variant in ids:
				names.append(tr("item.%s" % id))
			localized[key] = "、".join(names)
		else:
			localized[key] = value
	return localized


func _describe(sim: Simulation) -> String:
	var state := sim.state
	var lines: PackedStringArray = [
		"已过 %.0f 秒（村庄 ×%.1f）" % [state.elapsed, sim.tuning.village_speed],
		"火势 %d  室温 %d  建造者 %d" % [state.fire, state.temperature, state.builder_level],
		"人口 %d" % state.population,
		"",
		"库存 " + _pairs(state.stores),
		"建筑 " + _pairs(state.buildings),
		"解锁 " + ", ".join(PackedStringArray(state.features.keys())),
		"",
		"计时 " + _pairs(state.timers),
		"冷却 " + _pairs(state.cooldowns),
	]
	return "\n".join(lines)


func _pairs(values: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key: Variant in values:
		var value: Variant = values[key]
		parts.append("%s %s" % [key, ("%.0f" % value) if value is float else str(value)])
	return "\n     ".join(parts)
