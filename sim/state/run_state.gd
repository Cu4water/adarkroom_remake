class_name RunState
extends RefCounted
## 一局游戏的全部状态。
##
## 系统本身不存任何东西，计时器和冷却也都在这里，所以存档就是把这个对象序列化。
## 新加字段时记得同时改 to_dict 和 from_dict。

var run_seed := 0
var rng_state := 0
## 这一局已经过去的原速时间，单位秒。
var elapsed := 0.0

var fire := 0
var temperature := 0
var builder_level := -1
var population := 0

var stores: Dictionary[StringName, int] = {}
var buildings: Dictionary[StringName, int] = {}
## 被分配了具体工作的村民数量。没有分配的人口默认去拾柴。
var workers: Dictionary[StringName, int] = {}
var features: Dictionary[StringName, bool] = {}
## 各个倒计时还剩多少秒，按所属系统的时间域流逝。
var timers: Dictionary[StringName, float] = {}
## 手动操作的冷却还剩多少秒，永远按原速流逝。
var cooldowns: Dictionary[StringName, float] = {}


func to_dict() -> Dictionary:
	return {
		# 这两个是 64 位整数，JSON 的数字存不下，所以写成字符串。
		"run_seed": str(run_seed),
		"rng_state": str(rng_state),
		"elapsed": elapsed,
		"fire": fire,
		"temperature": temperature,
		"builder_level": builder_level,
		"population": population,
		"stores": stores.duplicate(),
		"buildings": buildings.duplicate(),
		"workers": workers.duplicate(),
		"features": features.duplicate(),
		"timers": timers.duplicate(),
		"cooldowns": cooldowns.duplicate(),
	}


static func from_dict(data: Dictionary) -> RunState:
	var state := RunState.new()
	state.run_seed = str(data.get("run_seed", "0")).to_int()
	state.rng_state = str(data.get("rng_state", "0")).to_int()
	state.elapsed = float(data.get("elapsed", 0.0))
	state.fire = int(data.get("fire", 0))
	state.temperature = int(data.get("temperature", 0))
	state.builder_level = int(data.get("builder_level", -1))
	state.population = int(data.get("population", 0))
	_read_ints(data.get("stores"), state.stores)
	_read_ints(data.get("buildings"), state.buildings)
	_read_ints(data.get("workers"), state.workers)
	_read_floats(data.get("timers"), state.timers)
	_read_floats(data.get("cooldowns"), state.cooldowns)
	var features: Variant = data.get("features")
	if features is Dictionary:
		var source: Dictionary = features
		for key: Variant in source:
			state.features[StringName(str(key))] = bool(source[key])
	return state


static func _read_ints(raw: Variant, into: Dictionary[StringName, int]) -> void:
	if not (raw is Dictionary):
		return
	var source: Dictionary = raw
	for key: Variant in source:
		into[StringName(str(key))] = int(source[key])


static func _read_floats(raw: Variant, into: Dictionary[StringName, float]) -> void:
	if not (raw is Dictionary):
		return
	var source: Dictionary = raw
	for key: Variant in source:
		into[StringName(str(key))] = float(source[key])
