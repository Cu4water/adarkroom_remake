extends RefCounted


func test_stranger_arrives_then_the_forest_opens(t: TestCase) -> void:
	var sim := TestCase.new_sim()
	sim.act(FireSystem.CMD_LIGHT)
	t.eq(sim.state.builder_level, BuilderSystem.Level.ABSENT, "生火的那一刻她还没出现")
	sim.run_for(sim.tuning.builder_state_delay + 0.5)
	t.eq(sim.state.builder_level, BuilderSystem.Level.COLLAPSED, "陌生人进门")
	t.ok(not sim.has_feature(ForestSystem.FEATURE), "森林还没出现")
	sim.run_for(sim.tuning.need_wood_delay + 0.5)
	t.ok(sim.has_feature(ForestSystem.FEATURE), "木头告急之后森林出现")
	t.eq(sim.store(&"wood"), sim.tuning.initial_wood, "森林出现时手里的木头")
	t.done()


func test_a_warm_room_wakes_the_builder(t: TestCase) -> void:
	var sim := TestCase.new_sim()
	var unlocked: Array[StringName] = []
	sim.events.unlocked.connect(func(feature: StringName) -> void: unlocked.append(feature))
	sim.act(FireSystem.CMD_LIGHT)
	sim.run_for(200.0)
	t.eq(sim.state.builder_level, BuilderSystem.Level.HELPING, "屋里暖和之后她愿意帮忙")
	# 她站起来以后自己也往柴堆里添木头，攒到陷阱造价的一半，她就说她能做陷阱。
	var expected: Array[StringName] = [
		ForestSystem.FEATURE, VillageSystem.FEATURE_BUILD, VillageSystem.plan_feature(ForestSystem.TRAP),
	]
	t.eq(unlocked, expected, "解锁的顺序")
	t.done()


func test_nothing_happens_in_the_dark(t: TestCase) -> void:
	var sim := TestCase.new_sim()
	sim.run_for(600.0)
	t.eq(sim.state.builder_level, BuilderSystem.Level.ABSENT, "不生火就没有人来")
	t.ok(sim.state.features.is_empty(), "不生火就什么都不会出现")
	t.done()
