class_name ProcAudio
extends RefCounted
## 用代码合成的占位音效：风、火的噼啪、点火、添柴、关门。
##
## 项目里还没有正式的音频素材，这些只是让第一章的声音逻辑能先跑起来。
## 都是滤过的噪声，听起来够用但谈不上好。RoomAudio 上每个声音都留了导出属性，
## 把正式素材拖进去就会盖掉这里生成的。

const RATE := 22050
## 循环音效首尾交叉淡化的长度，半秒。
const LOOP_FADE := 11025


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


## 添柴：木头落进火里两声闷响，溅起一阵火星。
static func stoke(noise_seed: int) -> AudioStreamWAV:
	var rng := _rng(noise_seed)
	var pops := Pops.new(rng)
	var count := int(1.3 * RATE)
	var buffer := PackedFloat32Array()
	buffer.resize(count)
	var low := 0.0
	for i: int in count:
		var t := float(i) / RATE
		var white := rng.randf() * 2.0 - 1.0
		var sample := _thump(t, 150.0, 70.0, 0.045) * 0.7 + _thump(t - 0.17, 120.0, 60.0, 0.04) * 0.5
		sample += white * (_click(t) + _click(t - 0.17)) * 0.3
		low += (white - low) * 0.12
		sample += low * exp(-t / 0.3) * 0.5
		var chance := 0.0 if t < 0.05 else 45.0 / RATE * exp(-t / 0.35)
		sample += pops.next(white, chance) * 0.7
		buffer[i] = sample * _tail(t, 1.3, 0.15)
	return _to_stream(buffer, false)


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


## 一根柴落到柴堆上：干木头磕木头，一声脆响带一下轻弹。
static func log_drop(noise_seed: int) -> AudioStreamWAV:
	var rng := _rng(noise_seed)
	var count := int(0.35 * RATE)
	var buffer := PackedFloat32Array()
	buffer.resize(count)
	for i: int in count:
		var t := float(i) / RATE
		var white := rng.randf() * 2.0 - 1.0
		var sample := _thump(t, 260.0, 180.0, 0.025) * 0.55 + _thump(t - 0.07, 300.0, 220.0, 0.015) * 0.25
		sample += white * (_click(t) * 0.4 + _click(t - 0.07) * 0.15)
		buffer[i] = sample * _tail(t, 0.35, 0.08)
	return _to_stream(buffer, false)


## 门关上的一声。
static func door(noise_seed: int) -> AudioStreamWAV:
	var rng := _rng(noise_seed)
	var count := int(0.6 * RATE)
	var buffer := PackedFloat32Array()
	buffer.resize(count)
	for i: int in count:
		var t := float(i) / RATE
		var white := rng.randf() * 2.0 - 1.0
		var sample := _thump(t, 95.0, 50.0, 0.07) * 0.8 + _thump(t - 0.09, 130.0, 80.0, 0.03) * 0.3
		sample += white * (_click(t) * 0.35 + _click(t - 0.09) * 0.15)
		buffer[i] = sample * _tail(t, 0.6, 0.1)
	return _to_stream(buffer, false)


static func _rng(noise_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed
	return rng


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
