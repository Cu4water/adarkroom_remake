extends RefCounted
## 找建造者说话：她愿意帮忙以前不理人；第一次她把板子交过来，之后只是寒暄。


func test_she_does_not_talk_before_she_helps(t: TestCase) -> void:
	var sim := TestCase.new_sim()
	for level: int in [BuilderSystem.Level.ABSENT, BuilderSystem.Level.COLLAPSED, BuilderSystem.Level.SLEEPING]:
		sim.state.builder_level = level
		t.ok(not BuilderSystem.can_talk(sim), "等级 %d 时不能说话" % level)
		t.eq(sim.act(BuilderSystem.CMD_TALK), &"not_ready", "等级 %d 时说话没有反应" % level)
	t.ok(not sim.has_feature(BuilderSystem.FEATURE_BOARD), "没说上话就没有板子")
	t.done()


func test_the_first_talk_hands_over_the_board_once(t: TestCase) -> void:
	var sim := TestCase.new_sim()
	sim.state.builder_level = BuilderSystem.Level.HELPING
	var beats: Array[StringName] = []
	sim.events.narrated.connect(func(key: StringName, _args: Dictionary) -> void: beats.append(key))
	t.eq(sim.act(BuilderSystem.CMD_TALK), Simulation.OK, "第一次说话")
	t.ok(sim.has_feature(BuilderSystem.FEATURE_BOARD), "第一次说话就拿到板子")
	sim.act(BuilderSystem.CMD_TALK)
	sim.act(BuilderSystem.CMD_TALK)
	t.eq(beats, [&"builder.gives_board", &"builder.chat", &"builder.chat"] as Array[StringName],
		"板子只交一次，之后都是寒暄")
	t.done()


func test_every_chat_line_in_the_table_gets_said(t: TestCase) -> void:
	var listed: Array[String] = []
	for row: String in FileAccess.get_file_as_string("res://i18n/strings.csv").split("\n"):
		if row.begins_with(BuilderLines.CHAT_PREFIX):
			listed.append(row.get_slice(",", 0))
	t.ok(not listed.is_empty(), "表里至少有一句套话")
	var sim := _chatty_sim()
	var reachable := BuilderLines.chat_keys(sim, RefCounted.new())
	listed.sort()
	reachable.sort()
	t.eq(reachable, listed, "表里的套话都属于登记过的组，编号连着，一句都不落")
	t.done()


func test_a_round_of_chat_never_repeats_then_goes_quiet(t: TestCase) -> void:
	var sim := _chatty_sim()
	var lines := BuilderLines.new(7)
	var all := BuilderLines.chat_keys(sim, RefCounted.new())
	var heard: Array[String] = []
	for _i: int in all.size():
		heard.append(lines.next_chat(sim, RefCounted.new()))
		sim.state.elapsed += 1.0
	var unique: Array[String] = heard.duplicate()
	unique.sort()
	all.sort()
	t.eq(unique, all, "一轮里每句都说到，不重复")
	t.eq(lines.next_chat(sim, RefCounted.new()), String(BuilderLines.QUIET), "一轮说完就只剩省略号")
	sim.state.elapsed += BuilderLines.CHAT_REST - 2.0
	t.eq(lines.next_chat(sim, RefCounted.new()), String(BuilderLines.QUIET), "没到一分钟，还是省略号")
	sim.state.elapsed += 1.0
	var again := lines.next_chat(sim, RefCounted.new())
	t.ok(all.has(again), "离上一句满一分钟，她又有话说")
	t.ok(again != heard.back(), "新一轮的第一句不和上一轮的最后一句相同")
	t.done()


func test_chat_order_is_random(t: TestCase) -> void:
	var sim := _chatty_sim()
	var orders: Dictionary[String, bool] = {}
	for rng_seed: int in 6:
		var lines := BuilderLines.new(rng_seed)
		var order := ""
		for _i: int in 4:
			order += lines.next_chat(sim, RefCounted.new()) + "|"
		orders[order] = true
	t.ok(orders.size() > 1, "不同的种子说话的顺序不同")
	t.done()


func test_locked_chat_groups_stay_silent(t: TestCase) -> void:
	var sim := _chatty_sim()
	sim.state.features.erase(ForestSystem.FEATURE)
	var lines := BuilderLines.new(3)
	var board := BuilderLines.group_keys(BuilderSystem.FEATURE_BOARD, RefCounted.new())
	for _i: int in board.size():
		t.ok(board.has(lines.next_chat(sim, RefCounted.new())), "林子还没解锁，只说板子那一组")
	t.eq(lines.next_chat(sim, RefCounted.new()), String(BuilderLines.QUIET), "板子那一组说完就没话了")
	sim.unlock(ForestSystem.FEATURE)
	var forest := BuilderLines.group_keys(ForestSystem.FEATURE, RefCounted.new())
	t.ok(forest.has(lines.next_chat(sim, RefCounted.new())), "新解锁的一组直接接着说")
	t.done()


## 板子和林子都解锁了的局面。
func _chatty_sim() -> Simulation:
	var sim := TestCase.new_sim()
	sim.state.builder_level = BuilderSystem.Level.HELPING
	for group: StringName in BuilderLines.CHAT_GROUPS:
		sim.state.features[group] = true
	return sim


func test_the_board_survives_a_save(t: TestCase) -> void:
	var sim := TestCase.new_sim()
	sim.state.builder_level = BuilderSystem.Level.HELPING
	sim.act(BuilderSystem.CMD_TALK)
	var loaded := TestCase.new_sim()
	loaded.load_run(RunState.from_dict(JSON.parse_string(JSON.stringify(sim.capture().to_dict()))))
	t.ok(loaded.has_feature(BuilderSystem.FEATURE_BOARD), "读档以后板子还在手上")
	t.done()
