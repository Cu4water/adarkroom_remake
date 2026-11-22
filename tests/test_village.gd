extends RefCounted


func test_building_needs_a_warm_room(t: TestCase) -> void:
	var sim := _sim_with_builder()
	sim.state.stores[&"wood"] = 100
	sim.state.temperature = FireSystem.Temp.COLD
	t.eq(sim.act(VillageSystem.CMD_BUILD, {"id": &"trap"}), &"too_cold", "屋里冷的时候建造")
	sim.state.temperature = FireSystem.Temp.WARM
	t.eq(sim.act(VillageSystem.CMD_BUILD, {"id": &"trap"}), Simulation.OK, "屋里暖和的时候建造")
	t.eq(sim.store(&"wood"), 90, "第一个陷阱的造价")
	sim.act(VillageSystem.CMD_BUILD, {"id": &"trap"})
	t.eq(sim.store(&"wood"), 70, "第二个陷阱更贵")
	t.done()


func test_building_stops_at_the_maximum(t: TestCase) -> void:
	var sim := _sim_with_builder()
	sim.state.stores[&"wood"] = 100
	sim.state.temperature = FireSystem.Temp.WARM
	t.eq(sim.act(VillageSystem.CMD_BUILD, {"id": &"cart"}), Simulation.OK, "第一辆板车")
	t.eq(sim.act(VillageSystem.CMD_BUILD, {"id": &"cart"}), &"maximum", "第二辆板车")
	t.eq(sim.act(VillageSystem.CMD_BUILD, {"id": &"nothing"}), &"unknown_building", "不存在的建筑")
	t.done()


func test_village_speed_only_speeds_up_the_village(t: TestCase) -> void:
	var slow := TestCase.new_sim(1, 1.0)
	var fast := TestCase.new_sim(1, 10.0)
	for sim: Simulation in [slow, fast]:
		sim.state.population = 4
		sim.state.features[ForestSystem.FEATURE] = true
		sim.act(ForestSystem.CMD_GATHER)
		sim.state.stores[&"wood"] = 0
		sim.run_for(55.0)
	t.eq(slow.store(&"wood"), 20, "原速下四个拾柴人五十五秒结算五次")
	t.eq(fast.store(&"wood"), 220, "十倍速下结算五十五次")
	t.ok(fast.cooldown_left(ForestSystem.CMD_GATHER) > 0.0, "村庄加速不影响亲手拾柴的冷却")
	fast.run_for(6.0)
	t.eq(fast.act(ForestSystem.CMD_GATHER), Simulation.OK, "拾柴的冷却还是原来的六十秒")
	t.done()


func test_wanderers_fill_the_huts(t: TestCase) -> void:
	var sim := TestCase.new_sim()
	sim.state.buildings[VillageSystem.HUT] = 1
	sim.run_for(200.0)
	var population := sim.state.population
	t.ok(population >= 2 and population <= 4, "一间小屋来的人在二到四之间，实际 %d" % population)
	sim.run_for(3600.0)
	t.eq(sim.state.population, sim.tuning.hut_room, "住满之后不再来人")
	t.done()


func test_cart_carries_more_wood(t: TestCase) -> void:
	var sim := TestCase.new_sim()
	sim.state.features[ForestSystem.FEATURE] = true
	sim.act(ForestSystem.CMD_GATHER)
	t.eq(sim.store(&"wood"), sim.tuning.gather_amount, "空手拾柴")
	sim.state.buildings[ForestSystem.CART] = 1
	sim.run_for(sim.tuning.gather_cooldown + 0.1)
	sim.state.stores[&"wood"] = 0
	sim.act(ForestSystem.CMD_GATHER)
	t.eq(sim.store(&"wood"), sim.tuning.gather_amount_cart, "有板车之后拾柴")
	t.done()


func test_traps_yield_one_thing_each(t: TestCase) -> void:
	var sim := TestCase.new_sim()
	t.eq(sim.act(ForestSystem.CMD_TRAPS), &"locked", "没有陷阱时查看陷阱")
	sim.state.buildings[ForestSystem.TRAP] = 3
	sim.state.stores[&"bait"] = 2
	t.eq(sim.act(ForestSystem.CMD_TRAPS), Simulation.OK, "查看陷阱")
	var found := 0
	for id: StringName in sim.tuning.trap_drops:
		found += sim.store(id)
	t.eq(found, 5, "三个陷阱加两份饵")
	t.eq(sim.store(&"bait"), 0, "饵用掉了")
	t.done()


func test_can_build_answers_like_the_command_without_changing_anything(t: TestCase) -> void:
	var sim := TestCase.new_sim()
	t.eq(VillageSystem.can_build(sim, &"trap"), &"locked", "她还没站起来")
	sim = _sim_with_builder()
	sim.state.temperature = FireSystem.Temp.COLD
	sim.state.stores[&"wood"] = 100
	var heard: Array[StringName] = []
	sim.events.narrated.connect(func(key: StringName, _args: Dictionary) -> void: heard.append(key))
	t.eq(VillageSystem.can_build(sim, &"trap"), &"too_cold", "屋里冷")
	sim.state.temperature = FireSystem.Temp.WARM
	t.eq(VillageSystem.can_build(sim, &"nothing"), &"unknown_building", "不存在的建筑")
	t.eq(VillageSystem.can_build(sim, &"trap"), Simulation.OK, "暖和、木头够")
	sim.state.stores[&"wood"] = 5
	t.eq(VillageSystem.can_build(sim, &"trap"), &"not_enough", "木头不够")
	sim.state.buildings[ForestSystem.CART] = 1
	t.eq(VillageSystem.can_build(sim, &"cart"), &"maximum", "板车只要一辆")
	t.eq(sim.store(&"wood"), 5, "只是问一问，木头没动")
	t.ok(heard.is_empty(), "只是问一问，没有叙述")
	t.done()


func test_she_mentions_what_she_can_build_at_half_the_wood(t: TestCase) -> void:
	# 原版 room.js craftUnlocked：木头够造价的一半时，建造者说她能造。
	var sim := _sim_with_builder()
	var heard: Array[StringName] = []
	sim.events.narrated.connect(func(key: StringName, _args: Dictionary) -> void: heard.append(key))
	sim.state.stores[&"wood"] = 4
	sim.step()
	t.ok(not sim.has_feature(VillageSystem.plan_feature(&"trap")), "四根木头还不到陷阱造价的一半")
	sim.state.stores[&"wood"] = 5
	sim.step()
	t.ok(sim.has_feature(VillageSystem.plan_feature(&"trap")), "五根木头够陷阱的一半")
	t.eq(heard, [&"builder.plan.trap"] as Array[StringName], "她说了一次能造陷阱")
	sim.state.stores[&"wood"] = 60
	sim.step()
	t.ok(sim.has_feature(VillageSystem.plan_feature(&"cart")), "先说板车")
	t.ok(not sim.has_feature(VillageSystem.plan_feature(VillageSystem.HUT)), "一步只说一样")
	sim.step()
	t.ok(sim.has_feature(VillageSystem.plan_feature(VillageSystem.HUT)), "下一步再说小屋")
	sim.state.stores[&"wood"] = 0
	sim.run_for(5.0)
	t.eq(heard.size(), 3, "说过的不再重复")
	t.done()


func test_she_says_nothing_before_she_stands_up(t: TestCase) -> void:
	var sim := TestCase.new_sim()
	sim.state.builder_level = BuilderSystem.Level.SLEEPING
	sim.state.stores[&"wood"] = 100
	sim.step()
	t.ok(not sim.has_feature(VillageSystem.plan_feature(&"trap")), "她还睡着")
	t.done()


func test_something_already_built_has_its_plan_without_a_word(t: TestCase) -> void:
	var sim := _sim_with_builder()
	var heard: Array[StringName] = []
	sim.events.narrated.connect(func(key: StringName, _args: Dictionary) -> void: heard.append(key))
	sim.state.buildings[ForestSystem.CART] = 1
	sim.step()
	t.ok(sim.has_feature(VillageSystem.plan_feature(&"cart")), "已经造过的东西有图纸")
	t.ok(heard.is_empty(), "已经造过的东西不再说一遍")
	t.done()


func _sim_with_builder() -> Simulation:
	var sim := TestCase.new_sim()
	sim.state.builder_level = BuilderSystem.Level.HELPING
	sim.state.features[VillageSystem.FEATURE_BUILD] = true
	return sim
