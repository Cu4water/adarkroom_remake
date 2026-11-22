class_name Simulation
extends RefCounted
## 模拟层的入口：持有状态，按固定步长驱动各个系统，接收指令，向外发事件。
##
## 不依赖任何节点，可以在命令行里无头运行。表现层和它之间只有两条通道：
## 往里走的是 act() 的指令，往外走的是 events 上的信号。

## act() 成功时的返回值。失败时返回的是说明原因的键。
const OK := &""

## 库存变动的来源，用来区分一件事是谁做的。
const BY_HAND := &"hand"
const BY_BUILDER := &"builder"
const BY_VILLAGE := &"village"
const BY_WORLD := &"world"

var state: RunState
var tuning: Tuning
var content: ContentDB
var events: SimEvents
var clock := SimClock.new()
## 模拟里所有的随机都从这里取，它的状态跟着存档走。
var rng := RandomNumberGenerator.new()

var _systems: Array[SimSystem] = []
var _commands: Dictionary[StringName, Callable] = {}


func _init(p_content: ContentDB, p_tuning: Tuning, p_events: SimEvents = null) -> void:
	content = p_content
	tuning = p_tuning
	events = p_events if p_events != null else SimEvents.new()
	_systems.append(FireSystem.new())
	_systems.append(BuilderSystem.new())
	_systems.append(ForestSystem.new())
	_systems.append(VillageSystem.new())
	for system: SimSystem in _systems:
		system.register(self)


func new_run(run_seed: int) -> void:
	state = RunState.new()
	state.run_seed = run_seed
	rng.seed = run_seed
	events.state_replaced.emit()


func load_run(loaded: RunState) -> void:
	state = loaded
	rng.seed = loaded.run_seed
	rng.state = loaded.rng_state
	events.state_replaced.emit()


## 取出可以拿去存档的状态。
func capture() -> RunState:
	state.rng_state = rng.state
	return state


## 按真实时间推进，给游戏主循环用。
func advance(real_delta: float) -> void:
	for _i: int in clock.consume(real_delta):
		step()


## 直接推进一段模拟时间，给测试和无头工具用。
func run_for(seconds: float) -> void:
	for _i: int in roundi(seconds / SimClock.STEP):
		step()


func step() -> void:
	var hand_dt := SimClock.STEP
	var village_dt := SimClock.STEP * tuning.village_speed
	state.elapsed += hand_dt
	_tick_cooldowns(hand_dt)
	for system: SimSystem in _systems:
		var in_village := system.domain() == SimClock.Domain.VILLAGE
		system.step(self, village_dt if in_village else hand_dt)


#region 指令

func register_command(command: StringName, handler: Callable) -> void:
	assert(not _commands.has(command), "指令重复注册: %s" % command)
	_commands[command] = handler


## 玩家做了一件事。成功返回 OK，失败返回原因。
func act(command: StringName, args: Dictionary = {}) -> StringName:
	if not _commands.has(command):
		push_error("未知指令: %s" % command)
		return &"unknown_command"
	var result: StringName = _commands[command].call(self, args)
	return result

#endregion


#region 库存与建筑

func store(id: StringName) -> int:
	return state.stores.get(id, 0)


func add_store(id: StringName, delta: int, source: StringName) -> void:
	if delta == 0:
		return
	var amount := maxi(0, store(id) + delta)
	state.stores[id] = amount
	events.store_changed.emit(id, amount, delta, source)


func can_afford(cost: Dictionary[StringName, int]) -> bool:
	for id: StringName in cost:
		if store(id) < cost[id]:
			return false
	return true


func pay(cost: Dictionary[StringName, int], source: StringName) -> void:
	for id: StringName in cost:
		add_store(id, -cost[id], source)


func building(id: StringName) -> int:
	return state.buildings.get(id, 0)

#endregion


#region 解锁与叙述

func has_feature(id: StringName) -> bool:
	return state.features.get(id, false)


func unlock(id: StringName) -> void:
	if has_feature(id):
		return
	state.features[id] = true
	events.unlocked.emit(id)


func narrate(key: StringName, args: Dictionary = {}) -> void:
	events.narrated.emit(key, args)

#endregion


#region 计时器与冷却

func start_timer(id: StringName, seconds: float) -> void:
	state.timers[id] = seconds


func has_timer(id: StringName) -> bool:
	return state.timers.has(id)


## 推进一个一次性的计时器。到点时返回 true，并把它移除。
func tick_timer(id: StringName, dt: float) -> bool:
	if not state.timers.has(id):
		return false
	var left: float = state.timers[id] - dt
	if left > 0.0:
		state.timers[id] = left
		return false
	state.timers.erase(id)
	return true


## 推进一个循环的计时器，返回这一步里它到点了几次。
## 加速之后一步可能跨过好几个周期，所以返回的是次数。
func tick_repeating(id: StringName, dt: float, period: float) -> int:
	assert(period > 0.0, "循环计时器的周期必须大于零: %s" % id)
	var left: float = state.timers.get(id, period) - dt
	var fired := 0
	while left <= 0.0:
		left += period
		fired += 1
	state.timers[id] = left
	return fired


func cooldown_left(id: StringName) -> float:
	return state.cooldowns.get(id, 0.0)


func start_cooldown(id: StringName, seconds: float) -> void:
	if seconds > 0.0:
		state.cooldowns[id] = seconds


func _tick_cooldowns(dt: float) -> void:
	for id: StringName in state.cooldowns.keys():
		var left: float = state.cooldowns[id] - dt
		if left > 0.0:
			state.cooldowns[id] = left
		else:
			state.cooldowns.erase(id)

#endregion
