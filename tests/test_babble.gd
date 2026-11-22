extends RefCounted
## NPC 的"哔哔啵啵"说话声：一个字一声，同一个字同一声，标点管语气，字幕和声音对得上。


func test_one_sound_per_character_and_per_latin_word(t: TestCase) -> void:
	var voice := Babble.builder_voice()
	t.eq(Babble.plan("木头", voice).size(), 2, "两个汉字两声")
	t.eq(Babble.plan("mm hm mmm", voice).size(), 3, "一串字母算一声")
	t.eq(Babble.plan("……", voice).size(), 0, "只有省略号时不出声")
	t.done()


func test_the_same_character_always_sounds_the_same(t: TestCase) -> void:
	var voice := Babble.builder_voice()
	var a := Babble.plan("火", voice)
	var b := Babble.plan("火。火", voice)
	t.eq(a[0]["midi"], b[0]["midi"], "同一个字同一个音高")
	t.eq(a[0]["vowel"], b[0]["vowel"], "同一个字同一个口型")
	t.eq(Babble.synth(a, voice), Babble.synth(Babble.plan("火", voice), voice), "合成结果每次都一样")
	t.done()


func test_punctuation_sets_the_tone(t: TestCase) -> void:
	var voice := Babble.builder_voice()
	var plain := Babble.plan("你好", voice)
	var ask := Babble.plan("你好？", voice)
	var shout := Babble.plan("你好！", voice)
	var sad := Babble.plan("你好……", voice)
	t.eq(float(ask[-1]["glide"]), 5.0, "问号结尾，尾音往上滑")
	t.eq(int(shout[0]["midi"]), int(plain[0]["midi"]) + 3, "带感叹号，整句升高")
	t.eq(int(sad[0]["midi"]), int(plain[0]["midi"]) - 3, "省略号结尾，整句压低")
	t.eq(float(sad[-1]["glide"]), -4.0, "省略号结尾，尾音往下滑")
	t.eq(float(plain[-1]["glide"]), voice.fall, "平常的句尾轻轻往下落")
	t.done()


func test_subtitle_follows_the_voice(t: TestCase) -> void:
	var voice := Babble.builder_voice()
	var text := "我能帮忙。我会造东西。"
	var notes := Babble.plan(text, voice)
	t.eq(notes.size(), 9, "九个字九声")
	var last_time := -1.0
	var last_end := 0
	for note: Dictionary in notes:
		t.ok(float(note["time"]) > last_time, "一声接一声往后排")
		t.ok(int(note["end"]) > last_end, "字幕一个字一个字往后出")
		last_time = note["time"]
		last_end = note["end"]
	t.eq(int(notes[3]["end"]), 5, "第一句说完，字幕连句号一起出来")
	t.eq(int(notes[-1]["end"]), text.length(), "最后一声说完，整句都显示了")
	t.ok(float(notes[4]["time"]) - float(notes[3]["time"]) > voice.step, "句子之间停一下")
	t.done()


func test_samples_stay_in_range_and_cover_the_line(t: TestCase) -> void:
	var voice := Babble.builder_voice()
	var notes := Babble.plan("我能做陷阱！", voice)
	var samples := Babble.synth(notes, voice)
	t.eq(samples.size(), ceili(Babble.length_of(notes) * Babble.RATE), "长度和整句时长一致")
	var loudest := 0.0
	for s: float in samples:
		loudest = maxf(loudest, absf(s))
	t.ok(loudest > 0.05 and loudest <= 1.0, "有声音，而且不破音：%.3f" % loudest)
	t.done()
