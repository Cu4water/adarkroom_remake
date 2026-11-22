extends RefCounted
## 这两个测试守着架构里最重要的一条：全部状态都在 RunState 里，包括随机数的状态。


func test_same_seed_same_story(t: TestCase) -> void:
	var first := _village_sim(7)
	var second := _village_sim(7)
	_play_for(first, 600.0)
	_play_for(second, 600.0)
	t.eq(_snapshot(first), _snapshot(second), "同一个种子跑出来的结果")
	var other := _village_sim(8)
	_play_for(other, 600.0)
	t.ok(_snapshot(other) != _snapshot(first), "换一个种子结果应该不同")
	t.done()


func test_saving_does_not_change_the_future(t: TestCase) -> void:
	var uninterrupted := _village_sim(7)
	_play_for(uninterrupted, 500.0)

	var before := _village_sim(7)
	_play_for(before, 120.0)
	var parsed: Dictionary = JSON.parse_string(_snapshot(before))
	var after := Simulation.new(ContentDB.load_all(), before.tuning)
	after.load_run(RunState.from_dict(parsed))
	_play_for(after, 380.0)

	t.eq(_snapshot(after), _snapshot(uninterrupted), "中途存读档之后的结果")
	t.done()


## 一个已经有村子的局面，这样人口和陷阱都会用到随机数。
func _village_sim(run_seed: int) -> Simulation:
	var sim := TestCase.new_sim(run_seed, 10.0)
	sim.state.builder_level = BuilderSystem.Level.HELPING
	sim.state.features[ForestSystem.FEATURE] = true
	sim.state.features[VillageSystem.FEATURE_BUILD] = true
	sim.state.buildings[ForestSystem.TRAP] = 3
	sim.state.buildings[VillageSystem.HUT] = 2
	sim.state.stores[&"wood"] = 50
	return sim


func _play_for(sim: Simulation, seconds: float) -> void:
	for _i: int in roundi(seconds / SimClock.STEP):
		if sim.state.fire == FireSystem.Level.DEAD:
			sim.act(FireSystem.CMD_LIGHT)
		if sim.cooldown_left(ForestSystem.CMD_GATHER) <= 0.0:
			sim.act(ForestSystem.CMD_GATHER)
		if sim.cooldown_left(ForestSystem.CMD_TRAPS) <= 0.0:
			sim.act(ForestSystem.CMD_TRAPS)
		sim.step()


func _snapshot(sim: Simulation) -> String:
	return JSON.stringify(sim.capture().to_dict(), "", true, true)
