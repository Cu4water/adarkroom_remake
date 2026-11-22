class_name BuilderSystem
extends SimSystem
## 陌生人从出现到愿意帮忙的过程。这是开场的一部分，走原速。

enum Level { ABSENT = -1, APPROACHING, COLLAPSED, SHIVERING, SLEEPING, HELPING }

const TIMER_STATE := &"builder.state"
const TIMER_NEED_WOOD := &"builder.need_wood"


func step(sim: Simulation, dt: float) -> void:
	var state := sim.state
	if state.builder_level == Level.ABSENT and state.fire >= FireSystem.Level.FLICKERING:
		_set_level(sim, Level.APPROACHING)
		sim.narrate(&"builder.light_spills")
		sim.start_timer(TIMER_STATE, sim.tuning.builder_state_delay)
	if sim.tick_timer(TIMER_NEED_WOOD, dt):
		_unlock_forest(sim)
	if sim.tick_timer(TIMER_STATE, dt):
		_advance(sim)


func _advance(sim: Simulation) -> void:
	var level := sim.state.builder_level
	var warm := sim.state.temperature >= FireSystem.Temp.WARM
	if level == Level.APPROACHING:
		_set_level(sim, Level.COLLAPSED)
		sim.narrate(&"builder.arrives")
		sim.start_timer(TIMER_NEED_WOOD, sim.tuning.need_wood_delay)
	elif warm and level == Level.COLLAPSED:
		_set_level(sim, Level.SHIVERING)
		sim.narrate(&"builder.shivers")
	elif warm and level == Level.SHIVERING:
		_set_level(sim, Level.SLEEPING)
		sim.narrate(&"builder.calms")
	elif warm and level == Level.SLEEPING:
		# 原版里这一步要等玩家切回房间页面才发生，那是界面上的条件，这里改成到点就发生。
		_set_level(sim, Level.HELPING)
		sim.narrate(&"builder.helps")
		sim.unlock(VillageSystem.FEATURE_BUILD)
	if sim.state.builder_level < Level.HELPING:
		sim.start_timer(TIMER_STATE, sim.tuning.builder_state_delay)


func _unlock_forest(sim: Simulation) -> void:
	sim.add_store(&"wood", sim.tuning.initial_wood, Simulation.BY_WORLD)
	sim.unlock(ForestSystem.FEATURE)
	sim.narrate(&"forest.wind_howls")
	sim.narrate(&"forest.wood_running_out")


func _set_level(sim: Simulation, level: int) -> void:
	sim.state.builder_level = level
	sim.events.builder_changed.emit(level)
