class_name DoorCreak
extends RefCounted
## 门轴的吱呀声，用的是 Andy Farnell《Designing Sound》第 32 章（Creaking door）的模型：
## 推门的力攒起来，攒够了门轴就滑一下，于是出来一串黏滑（stick-slip）脉冲。力越大滑得越勤、每一下越轻，
## 听起来音调越高、越尖；力小的时候是一下一下的"咯、咯"。脉冲先过一组木头共振（门板），
## 再过八条短延迟（四四方方的门框），最后切掉低频。
##
## 结构和参数参考了这个模型的两个开源实现：Faust 的 examples/gameaudio/door.dsp，
## 以及 Wikibooks《Designing Sound in SuperCollider》的 Creaking door 一节。这里按同样的结构用 GDScript 重写，
## 力怎么随时间变化交给调用方，开门和关门各给一条不同的力，听起来就是两种吱呀。
## 纯函数，不碰节点；随机数只用调用方给的 rng。

## 力小于这个时门轴不动（静摩擦）。
const STATIC_FORCE := 0.3
## 门板的木头共振：中心频率（赫兹）和 Q。
const WOOD_HZ: Array[float] = [62.5, 125.0, 250.0, 395.0, 560.0, 790.0]
const WOOD_Q: Array[float] = [1.0, 1.0, 2.0, 2.0, 3.0, 3.0]
## 不过共振、直接混进去的那一份。
const WOOD_DRY := 0.2
## 门框的八条延迟（毫秒）和它们的反馈。
const FRAME_MS: Array[float] = [4.52, 5.06, 6.27, 8.0, 5.48, 7.14, 10.12, 16.0]
const FRAME_FEEDBACK := 0.05
const HIGH_PASS_HZ := 125.0


## 吱呀 seconds 秒。force 是 func(t: float) -> float，给出 t 秒时推门的力（0 到 1）。
## stiffness 把滑动的间隔整体拉长，大于 1 门轴就更涩、音调更低。返回峰值为 1 的一段声音。
static func synth(rng: RandomNumberGenerator, seconds: float, force: Callable, stiffness := 1.0) -> PackedFloat32Array:
	var pulses := _stick_slip(rng, seconds, force, stiffness)
	return StkFoley.normalized(_frame(_wood(pulses)), 1.0)


## 黏滑：每滑一下出一个脉冲，离上一下越久攒的劲越大，这一下就越响、越长。
static func _stick_slip(rng: RandomNumberGenerator, seconds: float, force: Callable,
		stiffness: float) -> PackedFloat32Array:
	var count := int(seconds * ProcAudio.RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var since := 0
	var wait := 0
	var pulse_left := 0
	var pulse_length := 1
	var pulse_amp := 0.0
	for i: int in count:
		var push: float = force.call(float(i) / ProcAudio.RATE)
		since += 1
		if push > STATIC_FORCE:
			wait -= 1
			if wait <= 0:
				var built := sqrt(minf(since * 1000.0 / ProcAudio.RATE, 100.0) / 100.0)
				pulse_amp = sqrt(built + 0.1)
				pulse_length = maxi(int(built * 0.001 * ProcAudio.RATE), 3)
				pulse_left = pulse_length
				since = 0
				var slack := 1.0 - minf(push, 1.0)
				var period_ms := (slack * 60.0 + 3.0 + slack * 6.0 * rng.randf()) * stiffness
				wait = maxi(int(period_ms * 0.001 * ProcAudio.RATE), 1)
		else:
			wait = 0
		if pulse_left > 0:
			var envelope := float(pulse_left) / pulse_length
			out[i] = pulse_amp * envelope * envelope
			pulse_left -= 1
	return out


## 门板：六个并联的带通共振，加一点没过共振的原声。
static func _wood(input: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(input.size())
	for i: int in input.size():
		out[i] = input[i] * WOOD_DRY
	for band: int in WOOD_HZ.size():
		var w := TAU * WOOD_HZ[band] / ProcAudio.RATE
		var alpha := sin(w) / (2.0 * WOOD_Q[band])
		var a0 := 1.0 + alpha
		var b0 := alpha / a0
		var a1 := -2.0 * cos(w) / a0
		var a2 := (1.0 - alpha) / a0
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		for i: int in input.size():
			var x := input[i]
			var y := b0 * (x - x2) - a1 * y1 - a2 * y2
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			out[i] += y
	return out


## 门框：八条带一点反馈的短延迟并联，最后一阶高通切掉脉冲带来的直流和闷响。
static func _frame(input: PackedFloat32Array) -> PackedFloat32Array:
	var count := input.size()
	var summed := PackedFloat32Array()
	summed.resize(count)
	for ms: float in FRAME_MS:
		var delay := maxi(int(ms * 0.001 * ProcAudio.RATE), 1)
		var line := PackedFloat32Array()
		line.resize(count)
		for i: int in count:
			var back := i - delay
			if back >= 0:
				line[i] = input[back] + FRAME_FEEDBACK * line[back]
			summed[i] += line[i]
	var out := PackedFloat32Array()
	out.resize(count)
	var k := exp(-TAU * HIGH_PASS_HZ / ProcAudio.RATE)
	var last_in := 0.0
	var last_out := 0.0
	for i: int in count:
		last_out = k * (last_out + summed[i] - last_in)
		last_in = summed[i]
		out[i] = last_out
	return out
