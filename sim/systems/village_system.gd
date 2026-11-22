class_name VillageSystem
extends SimSystem
## 村庄自己运转的部分：建造、人口、村民的产出。走加速之后的村庄时间。

const FEATURE_BUILD := &"build"
const CMD_BUILD := &"village.build"

const HUT := &"hut"
const TIMER_POPULATION := &"village.population"
const TIMER_BUILDER_INCOME := &"income.builder"
## 她说过能造某样东西以后，这样东西才算"有了图纸"。解锁名是这个前缀加建筑 id。
const PLAN_PREFIX := "plan."


func domain() -> SimClock.Domain:
	return SimClock.Domain.VILLAGE


func register(sim: Simulation) -> void:
	sim.register_command(CMD_BUILD, _build)


func step(sim: Simulation, dt: float) -> void:
	_step_plans(sim)
	_step_population(sim, dt)
	_step_income(sim, dt)


static func plan_feature(id: StringName) -> StringName:
	return StringName(PLAN_PREFIX + id)


## 现在造这样东西能不能成。只读，不改状态，不发叙述；成了返回 Simulation.OK，否则返回原因。
## 表现层拿它决定数据板上哪一项是亮的。
static func can_build(sim: Simulation, id: StringName) -> StringName:
	if not sim.has_feature(FEATURE_BUILD):
		return &"locked"
	var def: BuildingDef = sim.content.buildings.get(id)
	if def == null:
		return &"unknown_building"
	if sim.state.temperature <= FireSystem.Temp.COLD:
		return &"too_cold"
	var owned := sim.building(def.id)
	if owned >= def.maximum:
		return &"maximum"
	if not sim.can_afford(def.cost_for(owned)):
		return &"not_enough"
	return Simulation.OK


## 参数：{"id": 建筑的 id}
func _build(sim: Simulation, args: Dictionary) -> StringName:
	var id: StringName = args.get("id", &"")
	var reason := can_build(sim, id)
	if reason == &"too_cold":
		sim.narrate(&"build.too_cold")
	elif reason == &"not_enough":
		sim.narrate(&"build.not_enough")
	if reason != Simulation.OK:
		return reason
	var def: BuildingDef = sim.content.buildings[id]
	var owned := sim.building(def.id)
	var cost := def.cost_for(owned)
	sim.pay(cost, Simulation.BY_HAND)
	sim.state.buildings[def.id] = owned + 1
	sim.events.building_changed.emit(def.id, owned + 1)
	sim.narrate(StringName("build.%s" % def.id))
	return Simulation.OK


## 她站到火边以后，手头的木头攒到一样东西造价的一定比例，她就说她能造这样东西。
## 原版 room.js 的 craftUnlocked：木头够一半、其余材料都见过，或者已经造过一座。
## 一步最多说一样，从最便宜的开始，免得一次拾柴回来好几样东西同时冒出来。
func _step_plans(sim: Simulation) -> void:
	if sim.state.builder_level < BuilderSystem.Level.HELPING:
		return
	var waiting: Array[BuildingDef] = []
	for def: BuildingDef in sim.content.buildings.values():
		if not sim.has_feature(plan_feature(def.id)):
			waiting.append(def)
	waiting.sort_custom(_cheaper_first)
	for def: BuildingDef in waiting:
		if sim.building(def.id) > 0:
			sim.unlock(plan_feature(def.id))
			continue
		if _within_reach(sim, def.cost_for(0)):
			sim.unlock(plan_feature(def.id))
			sim.narrate(StringName("builder.plan.%s" % def.id))
			return


func _within_reach(sim: Simulation, cost: Dictionary[StringName, int]) -> bool:
	for id: StringName in cost:
		if id == &"wood":
			if sim.store(id) < cost[id] * sim.tuning.plan_reveal_fraction:
				return false
		elif sim.store(id) <= 0:
			return false
	return true


static func _cheaper_first(a: BuildingDef, b: BuildingDef) -> bool:
	var cost_a: int = a.base_cost.get(&"wood", 0)
	var cost_b: int = b.base_cost.get(&"wood", 0)
	return cost_a < cost_b if cost_a != cost_b else String(a.id) < String(b.id)


func _step_population(sim: Simulation, dt: float) -> void:
	if sim.building(HUT) == 0:
		return
	if not sim.has_timer(TIMER_POPULATION):
		_schedule_arrival(sim)
	elif sim.tick_timer(TIMER_POPULATION, dt):
		_arrive(sim)
		_schedule_arrival(sim)


func _schedule_arrival(sim: Simulation) -> void:
	var span := sim.tuning.population_delay_minutes
	var minutes := floorf(sim.rng.randf() * (span.y - span.x)) + span.x
	sim.start_timer(TIMER_POPULATION, minutes * 60.0)


func _arrive(sim: Simulation) -> void:
	var state := sim.state
	var space := sim.building(HUT) * sim.tuning.hut_room - state.population
	if space <= 0:
		return
	var arrivals := maxi(1, int(sim.rng.randf() * space / 2.0 + space / 2.0))
	state.population += arrivals
	sim.events.population_changed.emit(state.population, arrivals)
	sim.narrate(_arrival_key(arrivals))


func _arrival_key(arrivals: int) -> StringName:
	if arrivals == 1:
		return &"village.arrive.1"
	if arrivals < 5:
		return &"village.arrive.2"
	if arrivals < 10:
		return &"village.arrive.3"
	if arrivals < 30:
		return &"village.arrive.4"
	return &"village.arrive.5"


func _step_income(sim: Simulation, dt: float) -> void:
	var tuning := sim.tuning
	if sim.state.builder_level >= BuilderSystem.Level.HELPING:
		var rounds := sim.tick_repeating(TIMER_BUILDER_INCOME, dt, tuning.builder_income_period)
		sim.add_store(&"wood", tuning.builder_income_wood * rounds, Simulation.BY_BUILDER)
	for job: JobDef in sim.content.jobs.values():
		var rounds := sim.tick_repeating(StringName("income.%s" % job.id), dt, job.period)
		var count := _worker_count(sim, job)
		for _i: int in rounds:
			_pay_out(sim, job, count)


func _worker_count(sim: Simulation, job: JobDef) -> int:
	if not job.is_default:
		return sim.state.workers.get(job.id, 0)
	var assigned := 0
	for other: StringName in sim.state.workers:
		assigned += sim.state.workers[other]
	return maxi(0, sim.state.population - assigned)


## 一份工作的一次结算。只要有一样原料不够，这一次就整个作废。
func _pay_out(sim: Simulation, job: JobDef, count: int) -> void:
	if count <= 0:
		return
	for id: StringName in job.stores:
		if sim.store(id) + job.stores[id] * count < 0:
			return
	for id: StringName in job.stores:
		sim.add_store(id, job.stores[id] * count, Simulation.BY_VILLAGE)
