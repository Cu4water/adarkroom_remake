class_name ProcAudio
extends RefCounted
## 用代码合成的占位音效：风、火的噼啪、点火、添柴、柴落到柴堆上、开门关门的吱呀、门撞上、铁链拖地。
##
## 项目里还没有正式的音频素材，这些只是让第一章的声音逻辑能先跑起来。RoomAudio 上每个声音都留了导出属性，
## 把正式素材拖进去就会盖掉这里生成的。
## 风和火是滤过的噪声；木头和铁链用 StkFoley（移植自 STK 的模态敲击和 PhISEM），门轴用 DoorCreak。
## 每个函数都按 noise_seed 出声，换个种子就是同一个动作的另一个变体。

const RATE := 22050
## 循环音效首尾交叉淡化的长度，半秒。
const LOOP_FADE := 11025
## 开门、关门的吱呀各按多长合成（秒）。门动得快慢不一样时，RoomAudio 用音高去对。
const OPEN_SECONDS := 0.8
const CLOSE_SECONDS := 0.85
## 推门的力随时间（秒）怎么变，见 DoorCreak。开门先是低低一声，紧跟着拔高成尖的"吱——"，
## 顿一下再"呀"一声收住；关门一上来就使着劲，越关越慢、越低，是一声往下走的长"呀——"。
const OPEN_FORCE: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.1, 0.5), Vector2(0.32, 0.9), Vector2(0.44, 0.6),
	Vector2(0.56, 0.78), Vector2(0.72, 0.38), Vector2(0.8, 0.2),
]
const CLOSE_FORCE: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(0.06, 0.82), Vector2(0.28, 0.72), Vector2(0.6, 0.5), Vector2(0.8, 0.33),
	Vector2(0.85, 0.2),
]
## 关门时门轴更涩，滑动的间隔拉长这么多倍，音调比开门低一截。
const CLOSE_STIFFNESS := 1.4
## 拖铁链的速度（0 到 1）随时间（秒）怎么变：拽两把，中间停一下。
const DRAG_SPEED: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(0.12, 0.95), Vector2(0.45, 0.7), Vector2(0.7, 0.2), Vector2(0.88, 0.0),
	Vector2(1.05, 0.0), Vector2(1.2, 0.9), Vector2(1.55, 0.65), Vector2(1.95, 0.15), Vector2(2.2, 0.0),
]
const DRAG_SECONDS := 2.5


## 噼啪声：随机冒出来的短促爆音。
class Pops:
	var rng: RandomNumberGenerator
	var _envelope := 0.0
	var _decay := 0.0
	var _smooth := 0.0

	func _init(p_rng: RandomNumberGenerator) -> void:
		rng = p_rng

	## chance 是这一个采样点上冒出一声的概率。
	func next(white: float, chance: float) -> float:
		if rng.randf() < chance:
			_envelope = maxf(_envelope, pow(rng.randf(), 3.0))
			_decay = exp(-1.0 / (RATE * lerpf(0.0012, 0.012, rng.randf())))
		var out := white * _envelope
		_envelope *= _decay
		_smooth += (out - _smooth) * 0.6
		return _smooth


## 一段可以无缝循环的风声底噪。阵风和远近由 RoomAudio 在播放时用音量和滤波来做。
static func wind_loop(seconds: float, noise_seed: int) -> AudioStreamWAV:
	var rng := _rng(noise_seed)
	var count := int(seconds * RATE)
	var fade := LOOP_FADE
	var buffer := PackedFloat32Array()
	buffer.resize(count + fade)
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	var low := 0.0
	for i: int in count + fade:
		var white := rng.randf() * 2.0 - 1.0
		# 粉红噪声（Paul Kellet 的简化滤波器）。
		b0 = 0.99765 * b0 + white * 0.0990460
		b1 = 0.96300 * b1 + white * 0.2965164
		b2 = 0.57000 * b2 + white * 1.0526913
		var pink := (b0 + b1 + b2 + white * 0.1848) * 0.12
		low += (pink - low) * 0.55
		buffer[i] = low
	return _to_stream(_make_loop(buffer, count, fade), true)


## 一段可以无缝循环的柴火声：低沉的底噪加零星的噼啪。
static func crackle_loop(seconds: float, noise_seed: int) -> AudioStreamWAV:
	var rng := _rng(noise_seed)
	var pops := Pops.new(rng)
	var count := int(seconds * RATE)
	var fade := LOOP_FADE
	var buffer := PackedFloat32Array()
	buffer.resize(count + fade)
	var rumble := 0.0
	var hiss_low := 0.0
	var chance := 11.0 / RATE
	for i: int in count + fade:
		var white := rng.randf() * 2.0 - 1.0
		rumble = (rumble + white * 0.03) * 0.992
		hiss_low += (white - hiss_low) * 0.3
		var hiss := white - hiss_low
		buffer[i] = rumble * 0.9 + hiss * 0.025 + pops.next(white, chance) * 0.85
	return _to_stream(_make_loop(buffer, count, fade), true)


## 点火：擦一下，火"呼"地起来，然后是一阵噼啪。
static func ignite(noise_seed: int) -> AudioStreamWAV:
	var rng := _rng(noise_seed)
	var pops := Pops.new(rng)
	var count := int(1.9 * RATE)
	var buffer := PackedFloat32Array()
	buffer.resize(count)
	var scrape_low := 0.0
	var whoosh_low := 0.0
	for i: int in count:
		var t := float(i) / RATE
		var white := rng.randf() * 2.0 - 1.0
		var sample := 0.0
		scrape_low += (white - scrape_low) * 0.25
		if t < 0.24:
			var rise := t / 0.24
			sample += (white - scrape_low) * rise * rise * 0.45 * (0.55 + 0.45 * sin(t * 610.0))
		if t > 0.2:
			var u := t - 0.2
			var envelope := minf(u / 0.07, 1.0) * exp(-u / 0.42)
			whoosh_low += (white - whoosh_low) * lerpf(0.3, 0.03, minf(u / 0.9, 1.0))
			sample += whoosh_low * envelope * 2.2
		var chance := 0.0 if t < 0.3 else 30.0 / RATE * exp(-(t - 0.3) / 0.7)
		sample += pops.next(white, chance) * 0.7
		buffer[i] = sample * 0.75 * _tail(t, 1.9, 0.15)
	return _to_stream(buffer, false)


## 添柴的木头声：一根粗柴砸在烧着的柴上，闷闷一声"咚"，紧跟着它滚一下，又磕到别的柴上。
## 烧过的木头软，所以敲击比柴堆上的那一下更钝、更低。火里的反应是 embers()。
static func stoke(noise_seed: int) -> AudioStreamWAV:
	var rng := _rng(noise_seed)
	var length := 0.6
	var buffer := _silence(length)
	var gains := StkFoley.bar_gains(rng.randf_range(0.3, 0.5), 0.008)
	_mix(buffer, StkFoley.strike(rng, 0.4, rng.randf_range(260.0, 400.0), StkFoley.WOOD2_RATIOS,
		StkFoley.WOOD2_RADII, gains, 3.0, 0.35, 0.08), 0.0, 0.6)
	var roll := rng.randf_range(0.12, 0.2)
	_mix(buffer, StkFoley.strike(rng, 0.3, rng.randf_range(520.0, 800.0), StkFoley.WOOD1_RATIOS,
		StkFoley.WOOD1_RADII, StkFoley.bar_gains(rng.randf_range(0.2, 0.5), 0.008), 2.0, 0.5, 0.05),
		roll, 0.3)
	for i: int in buffer.size():
		buffer[i] += _thump(float(i) / RATE, 140.0, 65.0, 0.05) * 0.5
	return _to_stream(StkFoley.normalized(_faded(buffer, length, 0.1), 0.85), false)


## 柴压进火里之后：炭块挪动，灰扬起来"噗"一下，火星噼啪几声。和 stoke() 的木头声叠着放。
static func embers(noise_seed: int) -> AudioStreamWAV:
	var rng := _rng(noise_seed)
	var length := 1.4
	var buffer := _silence(length)
	var coals := StkFoley.crunch(rng)
	_mix(buffer, StkFoley.run(coals, 0.6, func(t: float) -> float: return 0.5 * exp(-t / 0.15)), 0.03, 0.28)
	var pops := Pops.new(rng)
	var ash := 0.0
	for i: int in buffer.size():
		var t := float(i) / RATE
		var white := rng.randf() * 2.0 - 1.0
		ash += (white - ash) * 0.08
		var sample := ash * minf(t / 0.015, 1.0) * exp(-t / 0.22) * 0.9
		var chance := 0.0 if t < 0.06 else 45.0 / RATE * exp(-t / 0.35)
		sample += pops.next(white, chance) * 0.55
		buffer[i] += sample
	return _to_stream(StkFoley.normalized(_faded(buffer, length, 0.15), 0.85), false)


## 点了火堆但没添上柴时，拨一下火的轻响。
static func poke(noise_seed: int) -> AudioStreamWAV:
	var rng := _rng(noise_seed)
	var pops := Pops.new(rng)
	var count := int(0.4 * RATE)
	var buffer := PackedFloat32Array()
	buffer.resize(count)
	for i: int in count:
		var t := float(i) / RATE
		var white := rng.randf() * 2.0 - 1.0
		var sample := white * _click(t) * 0.12 + pops.next(white, 70.0 / RATE * exp(-t / 0.08)) * 0.4
		buffer[i] = sample * _tail(t, 0.4, 0.1)
	return _to_stream(buffer, false)


## 一根柴落到柴堆上：干木头磕木头"梆"一声，弹起来再磕一两下，柴堆里的细枝跟着窸窣一阵。
static func log_drop(noise_seed: int) -> AudioStreamWAV:
	var rng := _rng(noise_seed)
	var length := 0.5
	var buffer := _silence(length)
	var base := rng.randf_range(700.0, 1250.0)
	_mix(buffer, _dry_knock(rng, base, 4.0, 0.65), 0.0, 0.8)
	var bounce := rng.randf_range(0.05, 0.09)
	_mix(buffer, _dry_knock(rng, base * rng.randf_range(1.05, 1.3), 3.0, 0.7), bounce, rng.randf_range(0.25, 0.4))
	if rng.randf() < 0.6:
		_mix(buffer, _dry_knock(rng, base * rng.randf_range(1.1, 1.4), 2.0, 0.75),
			bounce + rng.randf_range(0.03, 0.05), 0.12)
	var twigs := StkFoley.sticks(rng)
	twigs.shake(0.6)
	_mix(buffer, StkFoley.run(twigs, 0.2, func(_t: float) -> float: return 0.0), bounce, 0.1)
	for i: int in buffer.size():
		buffer[i] += _thump(float(i) / RATE, 230.0, 170.0, 0.02) * 0.3
	return _to_stream(StkFoley.normalized(_faded(buffer, length, 0.08), 0.85), false)


## 推开门：先"咔"一声门闩松开，门轴低低咯一下，再拔高成"吱——呀"。和关门的吱呀不是同一种。
static func door_open(noise_seed: int) -> AudioStreamWAV:
	var rng := _rng(noise_seed)
	var buffer := _silence(OPEN_SECONDS)
	_mix(buffer, _dry_knock(rng, 1700.0, 0.6, 0.9), 0.0, 0.3)
	var push := func(t: float) -> float: return _contour(t, OPEN_FORCE) + 0.03 * sin(t * 23.0)
	_mix(buffer, DoorCreak.synth(rng, OPEN_SECONDS, push), 0.0, 1.0)
	return _to_stream(StkFoley.normalized(_faded(buffer, OPEN_SECONDS, 0.08), 0.85), false)


## 门往回关：门轴更涩，一声往下走的长"呀——"。撞上门框的那一下是 door()。
static func door_close(noise_seed: int) -> AudioStreamWAV:
	var rng := _rng(noise_seed)
	var push := func(t: float) -> float: return _contour(t, CLOSE_FORCE) + 0.04 * sin(t * 17.0)
	var buffer := DoorCreak.synth(rng, CLOSE_SECONDS, push, CLOSE_STIFFNESS)
	return _to_stream(StkFoley.normalized(_faded(buffer, CLOSE_SECONDS, 0.06), 0.85), false)


## 门撞上门框：一声闷响，门板"嗡"一下，门闩落下"咔"。
static func door(noise_seed: int) -> AudioStreamWAV:
	var rng := _rng(noise_seed)
	var length := 0.6
	var buffer := _silence(length)
	_mix(buffer, StkFoley.strike(rng, 0.4, 190.0, StkFoley.WOOD2_RATIOS, StkFoley.WOOD2_RADII,
		StkFoley.bar_gains(0.4, 0.008), 3.0, 0.4, 0.05), 0.0, 0.4)
	_mix(buffer, _dry_knock(rng, 2100.0, 0.8, 0.9), 0.03, 0.2)
	for i: int in buffer.size():
		var t := float(i) / RATE
		var white := rng.randf() * 2.0 - 1.0
		buffer[i] += _thump(t, 95.0, 50.0, 0.07) * 0.8 + white * _click(t) * 0.3
	return _to_stream(StkFoley.normalized(_faded(buffer, length, 0.1), 0.85), false)


## 一副陷阱拖出门去：铁链在冻土上拽了两把，链环互相磕，蹭着地上的碎石。隔着门，高频闷掉一些。
static func chain_drag(noise_seed: int) -> AudioStreamWAV:
	var rng := _rng(noise_seed)
	var buffer := _silence(DRAG_SECONDS)
	var speed := func(t: float) -> float: return _contour(t, DRAG_SPEED)
	var jerky := func(t: float) -> float: return speed.call(t) * (0.75 + 0.25 * sin(t * 31.0) * sin(t * 7.3))
	_mix(buffer, StkFoley.run(StkFoley.chain(rng), DRAG_SECONDS, jerky), 0.0, 0.55)
	_mix(buffer, _low_passed(StkFoley.run(StkFoley.gravel(rng), DRAG_SECONDS,
		func(t: float) -> float: return speed.call(t) * 0.6), 2500.0), 0.0, 0.3)
	# 拽着走的时候链环一下一下砸地，越快砸得越勤。
	var t := 0.0
	while t < DRAG_SECONDS - 0.2:
		var now: float = speed.call(t)
		if now > 0.15:
			_mix(buffer, StkFoley.strike(rng, 0.18, rng.randf_range(900.0, 1500.0), StkFoley.AGOGO_RATIOS,
				StkFoley.AGOGO_RADII, StkFoley.AGOGO_GAINS, 0.8, 0.8, 0.3), t, now * rng.randf_range(0.3, 0.7))
		t += rng.randf_range(0.04, 0.16) / maxf(now, 0.25)
	buffer = _low_passed(buffer, 5500.0)
	return _to_stream(StkFoley.normalized(_faded(buffer, DRAG_SECONDS, 0.2), 0.8), false)


static func _rng(noise_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed
	return rng


static func _silence(seconds: float) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(int(seconds * RATE))
	return buffer


## 把 part 乘上 gain 叠进 into，从 at 秒开始，超出 into 的部分丢掉。
static func _mix(into: PackedFloat32Array, part: PackedFloat32Array, at: float, gain: float) -> void:
	var start := int(at * RATE)
	for i: int in mini(part.size(), into.size() - start):
		into[start + i] += part[i] * gain


## 结尾淡出，免得声音戛然而止。
static func _faded(buffer: PackedFloat32Array, length: float, fade: float) -> PackedFloat32Array:
	for i: int in buffer.size():
		buffer[i] *= _tail(float(i) / RATE, length, fade)
	return buffer


## 按 points（x 是秒，y 是值，x 从小到大）在 t 秒处取值，相邻两点之间平滑过渡，两头之外取端点的值。
static func _contour(t: float, points: Array[Vector2]) -> float:
	if t <= points[0].x:
		return points[0].y
	for i: int in range(1, points.size()):
		if t < points[i].x:
			var a := points[i - 1]
			var b := points[i]
			return lerpf(a.y, b.y, smoothstep(a.x, b.x, t))
	return points[points.size() - 1].y


## 干木头磕一下。ring 是余音拉长几倍，hardness 越大越脆。
static func _dry_knock(rng: RandomNumberGenerator, base_hz: float, ring: float, hardness: float) -> PackedFloat32Array:
	var gains := StkFoley.bar_gains(rng.randf_range(0.2, 0.5), 0.008)
	return StkFoley.strike(rng, 0.3, base_hz, StkFoley.WOOD1_RATIOS, StkFoley.WOOD1_RADII, gains, ring, hardness, 0.05)


## 一阶低通。
static func _low_passed(buffer: PackedFloat32Array, cutoff_hz: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(buffer.size())
	var k := 1.0 - exp(-TAU * cutoff_hz / RATE)
	var y := 0.0
	for i: int in buffer.size():
		y += (buffer[i] - y) * k
		out[i] = y
	return out


## 一声从 from_hz 滑到 to_hz 的闷响，u 是从它开始算起的时间。
static func _thump(u: float, from_hz: float, to_hz: float, decay: float) -> float:
	if u < 0.0:
		return 0.0
	var slide := 0.08
	var phase := 0.0
	if u < slide:
		phase = from_hz * u + (to_hz - from_hz) * u * u / (2.0 * slide)
	else:
		phase = from_hz * slide + (to_hz - from_hz) * slide / 2.0 + to_hz * (u - slide)
	return sin(TAU * phase) * exp(-u / decay)


static func _click(u: float) -> float:
	return 0.0 if u < 0.0 else exp(-u / 0.006)


## 结尾淡出，免得声音戛然而止。
static func _tail(t: float, length: float, fade: float) -> float:
	return clampf((length - t) / fade, 0.0, 1.0)


## 把多出来的那一截和开头交叉淡化，首尾就接上了。
static func _make_loop(buffer: PackedFloat32Array, count: int, fade: int) -> PackedFloat32Array:
	var out := buffer.slice(0, count)
	for i: int in fade:
		var weight := float(i) / fade
		out[i] = buffer[i] * sqrt(weight) + buffer[count + i] * sqrt(1.0 - weight)
	return out


static func _to_stream(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream
