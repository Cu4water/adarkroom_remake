extends RefCounted


func test_first_fire_is_free(t: TestCase) -> void:
	var sim := TestCase.new_sim()
	t.eq(sim.act(FireSystem.CMD_LIGHT), Simulation.OK, "第一次生火")
	t.eq(sim.state.fire, FireSystem.Level.BURNING, "生火之后的火势")
	t.eq(sim.store(&"wood"), 0, "森林出现之前生火不花木头")
	t.done()


func test_stoke_shares_a_cooldown_with_light(t: TestCase) -> void:
	var sim := TestCase.new_sim()
	sim.act(FireSystem.CMD_LIGHT)
	t.eq(sim.act(FireSystem.CMD_STOKE), &"cooldown", "刚生完火就添柴")
	sim.run_for(sim.tuning.fire_cooldown + 0.1)
	t.eq(sim.act(FireSystem.CMD_STOKE), Simulation.OK, "冷却结束之后添柴")
	t.eq(sim.state.fire, FireSystem.Level.ROARING, "添柴之后的火势")
	t.done()


func test_fire_costs_wood_once_the_forest_exists(t: TestCase) -> void:
	var sim := TestCase.new_sim()
	sim.state.features[ForestSystem.FEATURE] = true
	t.eq(sim.act(FireSystem.CMD_LIGHT), &"not_enough", "没有木头时生火")
	t.eq(sim.state.fire, FireSystem.Level.DEAD, "生火失败之后的火势")
	sim.state.stores[&"wood"] = 6
	t.eq(sim.act(FireSystem.CMD_LIGHT), Simulation.OK, "有木头时生火")
	t.eq(sim.store(&"wood"), 1, "生火花掉的木头")
	t.done()


func test_the_fire_says_when_it_can_be_tended(t: TestCase) -> void:
	var sim := TestCase.new_sim()
	t.ok(FireSystem.can_tend(sim), "开局火灭着，可以生火")
	sim.act(FireSystem.CMD_LIGHT)
	t.ok(not FireSystem.can_tend(sim), "刚生完火在冷却")
	sim.run_for(sim.tuning.fire_cooldown + 0.1)
	t.ok(FireSystem.can_tend(sim), "冷却完可以添柴")
	sim.state.features[ForestSystem.FEATURE] = true
	sim.state.stores[&"wood"] = sim.tuning.stoke_cost - 1
	t.ok(not FireSystem.can_tend(sim), "有了森林以后，木头不够就添不了")
	sim.state.stores[&"wood"] = sim.tuning.stoke_cost
	t.ok(FireSystem.can_tend(sim), "木头够了又能添")
	t.eq(sim.store(&"wood"), sim.tuning.stoke_cost, "只是问一下，不花木头")
	t.done()


func test_the_forest_says_when_wood_can_be_gathered(t: TestCase) -> void:
	var sim := TestCase.new_sim()
	t.ok(not ForestSystem.can_gather(sim), "森林出现之前没处拾柴")
	sim.state.features[ForestSystem.FEATURE] = true
	t.ok(ForestSystem.can_gather(sim), "森林出现了可以拾柴")
	sim.act(ForestSystem.CMD_GATHER)
	t.ok(not ForestSystem.can_gather(sim), "刚拾过在冷却")
	sim.run_for(sim.tuning.gather_cooldown + 0.1)
	t.ok(ForestSystem.can_gather(sim), "冷却完又能拾")
	t.done()


func test_fire_cools_one_level_at_a_time(t: TestCase) -> void:
	var sim := TestCase.new_sim()
	sim.act(FireSystem.CMD_LIGHT)
	sim.run_for(sim.tuning.fire_cool_delay - 1.0)
	t.eq(sim.state.fire, FireSystem.Level.BURNING, "还没到降温的时候")
	sim.run_for(2.0)
	t.eq(sim.state.fire, FireSystem.Level.FLICKERING, "到点之后降一级")
	t.done()


func test_room_follows_the_fire_one_level_at_a_time(t: TestCase) -> void:
	var sim := TestCase.new_sim()
	sim.act(FireSystem.CMD_LIGHT)
	sim.run_for(sim.tuning.room_warm_delay + 0.1)
	t.eq(sim.state.temperature, FireSystem.Temp.COLD, "第一次升温")
	sim.run_for(sim.tuning.room_warm_delay * 3.0)
	t.eq(sim.state.temperature, FireSystem.Temp.WARM, "升到和火势一样就停")
	t.done()


func test_builder_keeps_a_low_fire_alive(t: TestCase) -> void:
	var sim := TestCase.new_sim()
	sim.act(FireSystem.CMD_LIGHT)
	sim.run_for(sim.tuning.fire_cool_delay * 4.0)
	t.eq(sim.state.builder_level, BuilderSystem.Level.HELPING, "建造者已经在帮忙")
	t.eq(sim.state.fire, FireSystem.Level.FLICKERING, "她把火维持在快灭的那一级")
	t.done()
