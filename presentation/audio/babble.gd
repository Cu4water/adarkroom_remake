class_name Babble
extends RefCounted
## 把一句话变成"哔哔啵啵"的说话声：一条锯齿波，两个带通滤波器捏出口型，一个字一声。
## 人物开口但不说出能听懂的词（docs/audio.md 第 1 节），所有 NPC 的话都用它配声。
##
## 做法：每个字用一个小哈希选音高和口型，所以同一个字永远是同一声；每个人物一组音阶；
## 标点管语气：问号结尾尾音上扬，带感叹号整句升高，省略号结尾整句压低、尾音下滑。
## 纯函数，不碰节点，可以单独测试。字幕按 plan() 给出的每个字的时刻逐字显示，和声音对得上。
##
## 算法和参数移植自 bibibobo（https://github.com/hakihakii/bibibobo），原许可如下：
##
## MIT License
## Copyright (c) 2026 hakihakii (Lumoswitch)
## Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
## documentation files (the "Software"), to deal in the Software without restriction, including without limitation
## the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
## to permit persons to whom the Software is furnished to do so, subject to the following conditions:
## The above copyright notice and this permission notice shall be included in all copies or substantial portions of
## the Software.
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
## THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
## AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
## CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
## IN THE SOFTWARE.

const RATE := 22050
## 五种口型，每种是两个共振峰频率（赫兹）。
const VOWELS: Array[Vector2] = [
	Vector2(800, 1200), Vector2(400, 2200), Vector2(350, 800), Vector2(600, 1700), Vector2(300, 2600),
]
## 句末标点：问号、感叹号、句号、逗号、顿号、分号、省略号，全角半角都算。
const PUNCT := "\\x{FF1F}?\\x{FF01}!\\x{3002}.\\x{FF0C},\\x{3001}\\x{FF1B};\\x{2026}"
## 一个汉字算一声，一串英文或数字算一声。
const SYLLABLE := "[A-Za-z_/.0-9]+|[\\x{4E00}-\\x{9FFF}]"
## 句子之间停多少秒，以及整段末尾留多少秒的尾巴。
const GAP := 0.22
const TAIL := 0.4


## 一个人物的声线。
class Voice:
	## 音阶，MIDI 音高。
	var scale: Array[int]
	## 共振峰整体乘多少：大于 1 更尖，小于 1 更闷。
	var formant: float
	## 每个字最长多少秒，以及占字间隔的比例。
	var max_dur: float
	var hold: float
	## 字头的小滑音有多少个半音。
	var chirp: float
	## 句尾往下落多少个半音。
	var fall: float
	var gain: float
	## 每个字间隔多少秒，也就是语速。
	var step: float

	func _init(p_scale: Array[int], p_formant: float, p_max_dur: float, p_hold: float, p_chirp: float,
			p_fall: float, p_gain: float, p_step: float) -> void:
		scale = p_scale
		formant = p_formant
		max_dur = p_max_dur
		hold = p_hold
		chirp = p_chirp
		fall = p_fall
		gain = p_gain
		step = p_step


## 建造者：D4 F4 G4 A4 C5，偏低、慢，句尾往下落，像累坏了的人在说话。
static func builder_voice() -> Voice:
	return Voice.new([62, 65, 67, 69, 72], 1.0, 0.18, 0.72, 0.4, -2.0, 0.16, 0.15)


## 同一个字永远得到同一个数，所以同一个字永远是同一声。
static func hash_of(syllable: String) -> int:
	var h := 7
	for i: int in syllable.length():
		h = (h * 31 + syllable.unicode_at(i)) % 9973
	return h


## 这句话要发的每一声：{"time": 第几秒开口, "midi": 音高, "dur": 秒, "glide": 结尾滑几个半音,
## "vowel": 口型, "end": 这一声说完以后字幕该显示到第几个字符}。
static func plan(text: String, voice: Voice) -> Array[Dictionary]:
	var notes: Array[Dictionary] = []
	var sentence_re := RegEx.create_from_string("[^%s\\n]+[%s]*" % [PUNCT, PUNCT])
	var syllable_re := RegEx.create_from_string(SYLLABLE)
	var ask_re := RegEx.create_from_string("[\\x{FF1F}?]$")
	var shout_re := RegEx.create_from_string("[\\x{FF01}!]")
	var sad_re := RegEx.create_from_string("(\\x{2026}|\\.\\.\\.)$")
	var t := 0.02
	for sentence: RegExMatch in sentence_re.search_all(text):
		var body := sentence.get_string()
		var tokens := syllable_re.search_all(body)
		if tokens.is_empty():
			continue
		var ask := ask_re.search(body) != null
		var shout := shout_re.search(body) != null
		var sad := sad_re.search(body) != null
		for i: int in tokens.size():
			var word := tokens[i].get_string()
			var last := i == tokens.size() - 1
			var h := hash_of(word)
			var glide := voice.fall if last else 0.0
			if last and ask:
				glide = 5.0
			elif last and sad:
				glide = -4.0
			notes.append({
				"time": t + i * voice.step,
				"midi": voice.scale[h % voice.scale.size()] + (3 if shout else 0) - (3 if sad else 0),
				"dur": minf(voice.step * voice.hold, voice.max_dur) + (0.1 if last and (ask or shout or sad) else 0.0),
				"glide": glide,
				"vowel": h % VOWELS.size(),
				"end": sentence.get_end() if last else sentence.get_start() + tokens[i].get_end(),
			})
		t += tokens.size() * voice.step + GAP
	return notes


## 整句说完要多少秒。
static func length_of(notes: Array[Dictionary]) -> float:
	if notes.is_empty():
		return 0.0
	var last: Dictionary = notes[-1]
	return float(last["time"]) + float(last["dur"]) + TAIL


## 合成单声道采样，范围 -1 到 1。
static func synth(notes: Array[Dictionary], voice: Voice) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(ceili(length_of(notes) * RATE))
	for note: Dictionary in notes:
		_sing(out, note, voice)
	for i: int in out.size():
		out[i] = tanh(out[i] * 2.4)
	return out


static func to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream


## 把一声写进 out。锯齿波用 polyBLEP 抗混叠，两个状态变量滤波器取带通输出当口型。
static func _sing(out: PackedFloat32Array, note: Dictionary, voice: Voice) -> void:
	var dur: float = note["dur"]
	var glide: float = note["glide"]
	var base := 440.0 * pow(2.0, (float(note["midi"]) - 69.0) / 12.0)
	var formants: Vector2 = VOWELS[int(note["vowel"])] * voice.formant
	var f1 := 2.0 * sin(PI * minf(formants.x, RATE / 6.0) / RATE)
	var f2 := 2.0 * sin(PI * minf(formants.y, RATE / 6.0) / RATE)
	var start := floori(float(note["time"]) * RATE)
	var count := floori(dur * RATE)
	var phase := 0.0
	var lp1 := 0.0
	var bp1 := 0.0
	var lp2 := 0.0
	var bp2 := 0.0
	for i: int in mini(count, out.size() - start):
		var x := float(i) / RATE
		var bend := glide * (x / dur) + voice.chirp * exp(-x * 30.0)
		var pitch := base * pow(2.0, bend / 12.0) * (1.0 + 0.012 * sin(TAU * 6.0 * x))
		var dt := pitch / RATE
		phase += dt
		if phase >= 1.0:
			phase -= 1.0
		var s := 2.0 * phase - 1.0
		if phase < dt:
			var u := phase / dt
			s -= u + u - u * u - 1.0
		elif phase > 1.0 - dt:
			var u := (phase - 1.0) / dt
			s -= u * u + u + u + 1.0
		var hp1 := s - lp1 - bp1 / 4.0
		bp1 += f1 * hp1
		lp1 += f1 * bp1
		var hp2 := s - lp2 - bp2 / 5.0
		bp2 += f2 * hp2
		lp2 += f2 * bp2
		var envelope := minf(1.0, x * 200.0) * minf(1.0, (dur - x) * 40.0)
		out[start + i] += (bp1 + 0.7 * bp2) * envelope * voice.gain
