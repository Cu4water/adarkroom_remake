extends RefCounted

const DIR := "user://test_tmp"
const RUN_PATH := DIR + "/run.json"
const META_PATH := DIR + "/meta.json"


func test_run_survives_a_round_trip(t: TestCase) -> void:
	var state := RunState.new()
	# 超出 JSON 数字精度的整数，以及不能用十进制写尽的小数。
	state.run_seed = 4611686018427387905
	state.rng_state = -8765432109876543211
	state.fire = 3
	state.builder_level = 2
	state.stores[&"wood"] = 42
	state.features[&"forest"] = true
	state.timers[&"fire.cool"] = 123.45000000000002
	state.cooldowns[&"fire"] = 0.1
	t.eq(SaveStore.save_run(state, RUN_PATH), OK, "写存档")
	var loaded := SaveStore.load_run(RUN_PATH)
	t.ok(loaded != null, "读存档")
	if loaded != null:
		t.eq(loaded.to_dict(), state.to_dict(), "读回来的内容")
		t.eq(loaded.rng_state, state.rng_state, "随机数状态一位都不能差")
	_clean()
	t.done()


func test_broken_save_falls_back_to_the_backup(t: TestCase) -> void:
	var state := RunState.new()
	state.fire = 1
	SaveStore.save_run(state, RUN_PATH)
	state.fire = 2
	SaveStore.save_run(state, RUN_PATH)
	var file := FileAccess.open(RUN_PATH, FileAccess.WRITE)
	file.store_string("{ 写到一半")
	file.close()
	var loaded := SaveStore.load_run(RUN_PATH)
	t.ok(loaded != null, "正式存档坏了之后读备份")
	if loaded != null:
		t.eq(loaded.fire, 1, "读到的是上一次的存档")
	_clean()
	t.done()


func test_missing_save_is_not_an_error(t: TestCase) -> void:
	_clean()
	t.ok(SaveStore.load_run(RUN_PATH) == null, "没有存档时返回 null")
	t.ok(not SaveStore.load_meta(META_PATH).knows(&"ending"), "没有存档时什么都不知道")
	t.done()


func test_meta_only_keeps_knowledge(t: TestCase) -> void:
	var meta := MetaState.new()
	meta.learn(&"ending")
	SaveStore.save_meta(meta, META_PATH)
	t.ok(SaveStore.load_meta(META_PATH).knows(&"ending"), "学到的东西带得走")
	var tampered := MetaState.from_dict({"known": ["ending", 5, {"wood_bonus": 20}], "wood_bonus": 20})
	t.eq(tampered.to_dict(), {"known": ["ending"]}, "数值类的东西进不来")
	_clean()
	t.done()


func _clean() -> void:
	for path: String in [RUN_PATH, META_PATH]:
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)
