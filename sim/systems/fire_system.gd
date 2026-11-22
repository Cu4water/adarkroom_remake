class_name FireSystem
extends SimSystem
## 火堆和室温。数值和规则沿用原版 room.js。

enum Level { DEAD, SMOLDERING, FLICKERING, BURNING, ROARING }
enum Temp { FREEZING, COLD, MILD, WARM, HOT }

const CMD_LIGHT := &"fire.light"
const CMD_STOKE := &"fire.stoke"
## 生火和添柴共用一个冷却。
const COOLDOWN := &"fire"
const TIMER_COOL := &"fire.cool"
const TIMER_TEMP := &"fire.temp"


func register(sim: Simulation) -> void:
	sim.register_command(CMD_LIGHT, _light)
	sim.register_command(CMD_STOKE, _stoke)


func step(sim: Simulation, dt: float) -> void:
	if sim.tick_timer(TIMER_COOL, dt):
		_cool(sim)
	for _i: int in sim.tick_repeating(TIMER_TEMP, dt, sim.tuning.room_warm_delay):
		_adjust_temperature(sim)


func _light(sim: Simulation, _args: Dictionary) -> StringName:
	if sim.state.fire != Level.DEAD:
		return &"fire.already_lit"
	if sim.cooldown_left(COOLDOWN) > 0.0:
		return &"cooldown"
	if not _burn_wood(sim, sim.tuning.light_cost):
		sim.narrate(&"fire.not_enough_wood")
		return &"not_enough"
	_set_fire(sim, Level.BURNING)
	sim.start_cooldown(COOLDOWN, sim.tuning.fire_cooldown)
	return Simulation.OK


func _stoke(sim: Simulation, _args: Dictionary) -> StringName:
	if sim.state.fire == Level.DEAD:
		return &"fire.dead"
	if sim.cooldown_left(COOLDOWN) > 0.0:
		return &"cooldown"
	if not _burn_wood(sim, sim.tuning.stoke_cost):
		sim.narrate(&"fire.wood_out")
		return &"not_enough"
	_set_fire(sim, mini(sim.state.fire + 1, Level.ROARING))
	sim.start_cooldown(COOLDOWN, sim.tuning.fire_cooldown)
	return Simulation.OK


## 现在点火堆能不能成：火灭着就是生火，烧着就是添柴。只读，不改状态，表现层拿它决定火堆亮不亮。
static func can_tend(sim: Simulation) -> bool:
	if sim.cooldown_left(COOLDOWN) > 0.0:
		return false
	var cost := sim.tuning.light_cost if sim.state.fire == Level.DEAD else sim.tuning.stoke_cost
	return _has_wood(sim, cost)


## 森林出现之前，屋里还没有"木头"这个概念，生火不要钱。
static func _has_wood(sim: Simulation, amount: int) -> bool:
	return not sim.has_feature(ForestSystem.FEATURE) or sim.store(&"wood") >= amount


func _burn_wood(sim: Simulation, amount: int) -> bool:
	if not _has_wood(sim, amount):
		return false
	if not sim.has_feature(ForestSystem.FEATURE):
		return true
	sim.add_store(&"wood", -amount, Simulation.BY_HAND)
	return true


func _set_fire(sim: Simulation, level: int) -> void:
	sim.state.fire = level
	sim.start_timer(TIMER_COOL, sim.tuning.fire_cool_delay)
	sim.events.fire_changed.emit(level)
	sim.narrate(StringName("fire.state.%d" % level))


func _cool(sim: Simulation) -> void:
	var state := sim.state
	if state.fire == Level.DEAD:
		return
	# 建造者愿意帮忙之后，会在火快灭的时候自己添一根柴，把火势维持住。
	# 原版里她对着已经灭掉的火也会照添不误，这里改成火灭了她就不管了。
	var builder_helps := state.builder_level >= BuilderSystem.Level.HELPING
	if builder_helps and state.fire <= Level.FLICKERING and sim.store(&"wood") > 0:
		sim.add_store(&"wood", -1, Simulation.BY_BUILDER)
		sim.narrate(&"builder.stokes")
		sim.start_timer(TIMER_COOL, sim.tuning.fire_cool_delay)
		return
	_set_fire(sim, state.fire - 1)


## 火势和室温都是 0 到 4 五级，室温每次向火势靠近一级。
func _adjust_temperature(sim: Simulation) -> void:
	var state := sim.state
	if state.temperature == state.fire:
		return
	state.temperature += signi(state.fire - state.temperature)
	sim.events.temperature_changed.emit(state.temperature)
	sim.narrate(StringName("room.temp.%d" % state.temperature))
