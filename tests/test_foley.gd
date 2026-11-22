extends RefCounted
## 木头、门轴、铁链的合成声：同一个种子同一段声音，变体彼此不同，开门和关门是两种吱呀，门轴的音调跟着力走。


func test_the_same_seed_gives_the_same_sound(t: TestCase) -> void:
	t.eq(ProcAudio.log_drop(47).data, ProcAudio.log_drop(47).data, "柴落柴堆，同一个种子结果相同")
	t.eq(ProcAudio.stoke(37).data, ProcAudio.stoke(37).data, "添柴，同一个种子结果相同")
	t.eq(ProcAudio.chain_drag(67).data, ProcAudio.chain_drag(67).data, "拖铁链，同一个种子结果相同")
	t.done()


func test_variants_differ(t: TestCase) -> void:
	t.ok(ProcAudio.log_drop(47).data != ProcAudio.log_drop(53).data, "柴落柴堆的两个变体不一样")
	t.ok(ProcAudio.stoke(37).data != ProcAudio.stoke(38).data, "添柴的两个变体不一样")
	t.ok(ProcAudio.embers(37).data != ProcAudio.embers(38).data, "火星的两个变体不一样")
	t.done()


func test_recorded_wood_is_wired_in(t: TestCase) -> void:
	# 不加载场景：场景里的脚本要用到 Game，测试里没有。
	var text := FileAccess.get_file_as_string("res://presentation/room/room.tscn")
	var paths := {}
	for found: RegExMatch in RegEx.create_from_string('path="([^"]+)" id="([^"]+)"').search_all(text):
		paths[found.get_string(2)] = found.get_string(1)
	for key: String in ["stoke_streams", "log_drop_streams"]:
		var line := RegEx.create_from_string(key + " = (.*)").search(text)
		var ids := RegEx.create_from_string('ExtResource\\("([^"]+)"\\)').search_all(line.get_string(1) if line else "")
		t.ok(ids.size() >= 3, "%s 用录音，至少 3 个变体：%d" % [key, ids.size()])
		for id: RegExMatch in ids:
			var path: String = paths.get(id.get_string(1), "")
			var wav := load(path) as AudioStreamWAV
			t.ok(path.begins_with("res://assets/audio/sfx/") and wav != null and wav.mix_rate == 48000 and not wav.stereo,
				"录音是 assets/audio/sfx 下的 48 kHz 单声道 wav：%s" % path)
	t.done()


func test_opening_and_closing_creak_differently(t: TestCase) -> void:
	var open := ProcAudio.door_open(71)
	var close := ProcAudio.door_close(71)
	t.ok(open.data != close.data, "开门和关门不是同一段声音")
	var open_tail := _crossings(_samples(open), 0.55, 0.75)
	var close_tail := _crossings(_samples(close), 0.55, 0.75)
	t.ok(open_tail != close_tail, "收尾那一段的音调不同：开门 %d，关门 %d" % [open_tail, close_tail])
	t.done()


func test_sounds_are_audible_and_never_clip(t: TestCase) -> void:
	var streams: Dictionary[String, AudioStreamWAV] = {
		"开门": ProcAudio.door_open(71), "关门": ProcAudio.door_close(73), "门撞上": ProcAudio.door(41),
		"柴落柴堆": ProcAudio.log_drop(47), "添柴": ProcAudio.stoke(37), "火星": ProcAudio.embers(37),
		"拖铁链": ProcAudio.chain_drag(67),
	}
	for name: String in streams:
		var loudest := 0.0
		for sample: float in _samples(streams[name]):
			loudest = maxf(loudest, absf(sample))
		t.ok(loudest > 0.3 and loudest < 1.0, "%s有声音，而且不破音：%.3f" % [name, loudest])
	t.done()


func test_creak_rises_with_force_and_needs_enough_push(t: TestCase) -> void:
	var light := DoorCreak.synth(_rng(), 0.5, func(_t: float) -> float: return 0.4)
	var hard := DoorCreak.synth(_rng(), 0.5, func(_t: float) -> float: return 0.9)
	var still := DoorCreak.synth(_rng(), 0.5, func(_t: float) -> float: return 0.2)
	t.ok(_slips(hard) > _slips(light) * 2,
		"推得越使劲，门轴滑得越勤、音调越高：%d 对 %d" % [_slips(hard), _slips(light)])
	t.eq(StkFoley.peak(still), 0.0, "力不够时门轴不动，没有声音")
	t.done()


func test_shaker_rings_only_after_a_shake_and_dies_away(t: TestCase) -> void:
	var quiet := StkFoley.sticks(_rng())
	var silent := true
	for i: int in 2000:
		silent = silent and quiet.tick() == 0.0
	t.ok(silent, "没摇过就没有声音")
	var shaken := StkFoley.crunch(_rng())
	shaken.shake(1.0)
	for i: int in ProcAudio.RATE * 4:
		shaken.tick()
	t.ok(shaken.energy < StkFoley.MIN_ENERGY, "摇过一下以后能量慢慢耗光：%.5f" % shaken.energy)
	t.done()


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	return rng


func _samples(stream: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i: int in stream.data.size() / 2:
		out.append(stream.data.decode_s16(i * 2) / 32768.0)
	return out


## from 到 to 秒之间过零点的次数，粗看音调高低。
func _crossings(samples: PackedFloat32Array, from: float, to: float) -> int:
	var count := 0
	for i: int in range(int(from * ProcAudio.RATE) + 1, mini(int(to * ProcAudio.RATE), samples.size())):
		if (samples[i - 1] < 0.0) != (samples[i] < 0.0):
			count += 1
	return count


## 门轴滑了几下：数声音里突然冒起来的尖峰。
func _slips(samples: PackedFloat32Array) -> int:
	var count := 0
	var envelope := 0.0
	for sample: float in samples:
		var level := absf(sample)
		if level > envelope * 1.6 + 0.02:
			count += 1
		envelope = maxf(level, envelope * 0.97)
	return count
