extends SceneTree
## 无头经济模拟：让一个勤快的"玩家"自动玩一段时间，按分钟输出木头是从哪里来的。
##
## 用来回答一个问题：村庄加速之后，玩家亲手做的事还有没有分量。
##
## 用法：godot --headless --path . --script res://tools/econ_sim.gd -- --minutes=30 --speed=10 --seed=1

const DEFAULTS := {"minutes": 30.0, "speed": 1.0, "seed": 1.0}
## 最后这几分钟的平均值作为总结。
const SUMMARY_MINUTES := 5


func _init() -> void:
	var options := _parse_args()
	var minutes := int(options["minutes"])
	var tuning := Tuning.new()
	tuning.village_speed = options["speed"]
	var sim := Simulation.new(ContentDB.load_all(), tuning)
	sim.new_run(int(options["seed"]))

	# 这一分钟里各个来源带来了多少木头。
	var gained := {Simulation.BY_HAND: 0, Simulation.BY_BUILDER: 0, Simulation.BY_VILLAGE: 0}
	sim.events.store_changed.connect(
		func(id: StringName, _amount: int, delta: int, source: StringName) -> void:
			if id == &"wood" and delta > 0 and gained.has(source):
				gained[source] += delta
	)

	print("村庄倍率 ×%.1f，种子 %d，共 %d 分钟" % [tuning.village_speed, sim.state.run_seed, minutes])
	print("分钟  木头库存  人口  小屋  亲手/分  建造者/分  村民/分  亲手占比")
	var recent_shares: Array[float] = []
	var steps_per_minute := roundi(60.0 / SimClock.STEP)
	for minute: int in range(1, minutes + 1):
		for key: StringName in gained:
			gained[key] = 0
		for _i: int in steps_per_minute:
			_play(sim)
			sim.step()
		var by_hand: int = gained[Simulation.BY_HAND]
		var by_builder: int = gained[Simulation.BY_BUILDER]
		var by_village: int = gained[Simulation.BY_VILLAGE]
		var total := by_hand + by_builder + by_village
		var share := 100.0 * by_hand / total if total > 0 else 0.0
		recent_shares.append(share)
		print("%4d  %8d  %4d  %4d  %7d  %9d  %7d  %7.1f%%" % [
			minute, sim.store(&"wood"), sim.state.population, sim.building(VillageSystem.HUT),
			by_hand, by_builder, by_village, share])

	var tail := recent_shares.slice(maxi(0, recent_shares.size() - SUMMARY_MINUTES))
	var sum := 0.0
	for share: float in tail:
		sum += share
	print("\n最后 %d 分钟，亲手得到的木头平均占 %.1f%%" % [tail.size(), sum / tail.size()])
	quit()


## 自动玩家的策略：火不让它低于"烧着"，能拾柴就拾柴，能查陷阱就查，木头够了就盖。
func _play(sim: Simulation) -> void:
	var state := sim.state
	if sim.cooldown_left(FireSystem.COOLDOWN) <= 0.0:
		if state.fire == FireSystem.Level.DEAD:
			sim.act(FireSystem.CMD_LIGHT)
		elif state.fire < FireSystem.Level.BURNING and _has_wood_for_fire(sim):
			sim.act(FireSystem.CMD_STOKE)
	if sim.has_feature(ForestSystem.FEATURE) and sim.cooldown_left(ForestSystem.CMD_GATHER) <= 0.0:
		sim.act(ForestSystem.CMD_GATHER)
	if sim.building(ForestSystem.TRAP) > 0 and sim.cooldown_left(ForestSystem.CMD_TRAPS) <= 0.0:
		sim.act(ForestSystem.CMD_TRAPS)
	if sim.has_feature(VillageSystem.FEATURE_BUILD) and state.temperature > FireSystem.Temp.COLD:
		_try_build(sim, _next_building(sim))


func _has_wood_for_fire(sim: Simulation) -> bool:
	return not sim.has_feature(ForestSystem.FEATURE) or sim.store(&"wood") >= sim.tuning.stoke_cost


## 先要板车，然后陷阱和小屋交替着盖，陷阱比小屋多一个。
func _next_building(sim: Simulation) -> StringName:
	if sim.building(ForestSystem.CART) == 0:
		return ForestSystem.CART
	var traps := sim.building(ForestSystem.TRAP)
	var trap_def: BuildingDef = sim.content.buildings[ForestSystem.TRAP]
	if traps < trap_def.maximum and traps <= sim.building(VillageSystem.HUT):
		return ForestSystem.TRAP
	return VillageSystem.HUT


func _try_build(sim: Simulation, id: StringName) -> void:
	var def: BuildingDef = sim.content.buildings[id]
	var owned := sim.building(id)
	if owned < def.maximum and sim.can_afford(def.cost_for(owned)):
		sim.act(VillageSystem.CMD_BUILD, {"id": id})


func _parse_args() -> Dictionary:
	var options := DEFAULTS.duplicate()
	for arg: String in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=")
		if parts.size() == 2 and options.has(parts[0]) and parts[1].is_valid_float():
			options[parts[0]] = parts[1].to_float()
		else:
			push_warning("忽略了看不懂的参数: %s" % arg)
	return options
