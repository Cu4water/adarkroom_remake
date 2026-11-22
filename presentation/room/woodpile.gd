class_name Woodpile
extends Node3D
## 柴堆。木头的存量就是柴堆上摆了几根柴（按 WoodpileView 的门槛），平时屏幕上不显示数字。
##
## 出门拾柴时，柴从门口一根根扔进来落到柴堆上；建造者去拿柴时，等她弯腰拿起的那一刻才少一根。
## 对准柴堆点一下，柴堆上方浮起一个数字，是现在有多少木头；数字散掉之前再点不起作用。

signal log_landed(at: Vector3)

const WOOD := &"wood"

## 拾柴时柴从门口扔向柴堆：一根飞多久、两根之间隔多久、抛多高、一次最多扔几根。
@export var delivery_flight := 0.7
@export var delivery_gap := 0.2
@export var delivery_arc := 0.55
@export var delivery_most := 4
## 点柴堆时浮起的数字：离柴堆顶多高出现、再往上飘多少、多久散掉、多大。
@export var count_height := 0.28
@export var count_rise := 0.3
@export var count_seconds := 1.8
@export var count_pixel_size := 0.0028
@export var count_color := Color(1.0, 0.9, 0.74)

## 建造者去拿柴的路上为 true：柴堆先不变。
var held := false

## 柴堆里的每一根柴，从下往上排。
var _logs: Array[Node3D] = []
## 正在空中飞向柴堆的柴：柴堆下标 → 飞着的那根。落地之前柴堆上那个位置先空着。
var _incoming: Dictionary[int, Node3D] = {}
var _count: Label3D


## 找到 hut.glb 里的每一根柴。
func bind(hut: Node3D) -> void:
	for node: Node in hut.find_children("Firewood_*", "Node3D", true, false):
		_logs.append(node)
	_logs.sort_custom(_lower_first)


## 柴堆里的每一根柴的网格，用来套高亮。
func meshes() -> Array[Node]:
	var result: Array[Node] = []
	result.assign(_logs)
	return result


## 回到和模拟一致的样子：天上飞的柴、浮着的数字都收掉。
func reset() -> void:
	for flyer: Node3D in _incoming.values():
		flyer.queue_free()
	_incoming.clear()
	if _count != null:
		_count.queue_free()
		_count = null
	held = false
	refresh()


## 柴堆上现在代表的木头数。森林出现之前模拟里还没有"木头"这个概念，
## 这时摆的是陌生人到了之后才算进库存的那几根。
func wood() -> int:
	var sim: Simulation = Game.sim
	return sim.store(WOOD) if sim.has_feature(ForestSystem.FEATURE) else sim.tuning.initial_wood


func refresh() -> void:
	if held:
		return
	var count := WoodpileView.logs_for(wood(), WoodpileView.THRESHOLDS)
	for index: int in _logs.size():
		_logs[index].visible = index < count and not _incoming.has(index)


## 柴堆上看得见的柴，加上正在飞过来的。
func shown() -> int:
	var count := 0
	for log_node: Node3D in _logs:
		if log_node.visible:
			count += 1
	return count + _incoming.size()


## 拾柴回来：before 是出门前柴堆上的根数，柴从 doorway 一根根扔进来，first_delay 秒后扔第一根。
func deliver(before: int, doorway: Vector3, first_delay: float) -> void:
	var after := WoodpileView.logs_for(wood(), WoodpileView.THRESHOLDS)
	var slots := WoodpileView.delivery(before, after, _logs.size(), delivery_most)
	for order: int in slots.size():
		_throw_log(slots[order], doorway, first_delay + order * delivery_gap, order)


## 数字还浮着。
func counting() -> bool:
	return _count != null


## 在柴堆上方浮起现在的木头数。数字还没散掉时什么都不做，返回 false。
func show_count() -> bool:
	if _count != null:
		return false
	_count = Label3D.new()
	_count.text = str(wood())
	_count.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_count.pixel_size = count_pixel_size
	_count.font_size = 72
	_count.outline_size = 14
	_count.modulate = count_color
	_count.outline_modulate = Color(0.08, 0.05, 0.03, 0.85)
	_count.shaded = false
	_count.double_sided = true
	add_child(_count)
	var start := _top() + Vector3.UP * count_height
	_count.global_position = start
	var label := _count
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, ^"global_position", start + Vector3.UP * count_rise, count_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, ^"modulate:a", 0.0, count_seconds * 0.55).set_delay(count_seconds * 0.45)
	tween.tween_property(label, ^"outline_modulate:a", 0.0, count_seconds * 0.55).set_delay(count_seconds * 0.45)
	tween.chain().tween_callback(_on_count_gone.bind(label))
	return true


func _on_count_gone(label: Label3D) -> void:
	if _count == label:
		_count = null
	label.queue_free()


## 柴堆最高那根柴的顶上正中。
func _top() -> Vector3:
	if _logs.is_empty():
		return global_position
	var bounds := AABB()
	for index: int in _logs.size():
		var mesh := _logs[index] as MeshInstance3D
		var box: AABB = mesh.global_transform * mesh.get_aabb() if mesh != null else AABB(_logs[index].global_position, Vector3.ZERO)
		bounds = box if index == 0 else bounds.merge(box)
	return Vector3(bounds.get_center().x, bounds.end.y, bounds.get_center().z)


## 从门口扔一根柴，delay 秒后出手，落到柴堆第 index 根的位置。order 只用来让每根翻滚得不一样。
func _throw_log(index: int, doorway: Vector3, delay: float, order: int) -> void:
	var target := _logs[index]
	var flyer := target.duplicate() as Node3D
	target.get_parent().add_child(flyer)
	flyer.visible = false
	if flyer is GeometryInstance3D:
		# 柴堆上的高亮不跟着飞出去。
		(flyer as GeometryInstance3D).material_overlay = null
	if not target.visible:
		_incoming[index] = flyer
	var land := target.global_transform
	var from := doorway + Vector3(0.08 * (order % 2), -0.2, 0.15)
	var start := Transform3D(land.basis.rotated(Vector3.UP, 1.1 + order * 0.6), from)
	var spin := Vector3(TAU * (1.0 + order % 2), 0.4 * order, PI * 0.5)
	flyer.global_transform = start
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(flyer.show)
	tween.tween_method(
		func(weight: float) -> void:
			flyer.global_transform = WoodpileView.flight(start, land, weight, delivery_arc, spin),
		0.0, 1.0, delivery_flight)
	tween.tween_callback(_on_log_landed.bind(index, flyer))


func _on_log_landed(index: int, flyer: Node3D) -> void:
	if _incoming.get(index) == flyer:
		_incoming.erase(index)
	log_landed.emit(flyer.global_position)
	flyer.queue_free()
	refresh()


static func _lower_first(a: Node3D, b: Node3D) -> bool:
	return a.global_position.y < b.global_position.y
