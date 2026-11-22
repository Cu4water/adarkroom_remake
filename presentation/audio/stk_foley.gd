class_name StkFoley
extends RefCounted
## 从 STK（The Synthesis ToolKit in C++）移植的两种物理启发的合成，给 ProcAudio 拼占位音效：
##   Shaker 是 PhISEM：一群小东西随机相撞，每撞一下往几个共振里灌一点能量。柴枝、炭块、砂石、铁链环都是它。
##   strike() 是 ModalBar 的做法：敲一下，几个固有频率各自衰减。一根木头磕在别的东西上就是它。
## 纯函数，不碰节点；随机数只用调用方给的 rng，同一个种子出同一段声音。
##
## STK 的参数是按 44100 Hz 每个采样定的（极点半径、每个采样的衰减和碰撞概率），这里一律换算成
## ProcAudio.RATE 下每秒效果相同的值。预设的数值照抄 STK，出处写在各个常量上。
##
## 移植自 STK（https://github.com/thestk/stk）的 Shakers 和 ModalBar，原许可如下：
##
## The Synthesis ToolKit in C++ (STK)
## Copyright (c) 1995-2023 Perry R. Cook and Gary P. Scavone
## Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
## documentation files (the "Software"), to deal in the Software without restriction, including without limitation
## the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
## to permit persons to whom the Software is furnished to do so, subject to the following conditions:
## The above copyright notice and this permission notice shall be included in all copies or substantial portions of
## the Software.
## Any person wishing to distribute modifications to the Software is asked to send the modifications to the original
## developer so that they can be incorporated into the canonical version. This is, however, not a binding provision
## of this license.
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
## THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
## AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
## CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
## IN THE SOFTWARE.

const STK_RATE := 44100.0
## 能量低于这个就不再有新的碰撞（STK 的 MIN_ENERGY）。
const MIN_ENERGY := 0.001

## ModalBar 的 Wood1：一块硬木头。四个固有频率的倍数和极点半径。
const WOOD1_RATIOS: Array[float] = [1.0, 2.777, 7.378, 15.377]
const WOOD1_RADII: Array[float] = [0.996, 0.994, 0.994, 0.99]
## ModalBar 的 Wood2：频率挤在一起，听起来更厚、更空。
const WOOD2_RATIOS: Array[float] = [1.0, 1.777, 2.378, 3.377]
const WOOD2_RADII: Array[float] = [0.996, 0.994, 0.994, 0.99]
## ModalBar 的 Agogo：金属铃。负数是不随基频变的固定频率（赫兹）。
const AGOGO_RATIOS: Array[float] = [1.0, 4.08, 6.669, -3725.0]
const AGOGO_RADII: Array[float] = [0.999, 0.999, 0.999, 0.999]
const AGOGO_GAINS: Array[float] = [0.06, 0.05, 0.03, 0.02]


## PhISEM：一群小东西在一起随机相撞。
class Shaker:
	## 现在还剩多少摇晃的能量，0 到 1。
	var energy := 0.0
	var _rng: RandomNumberGenerator
	var _a1 := PackedFloat32Array()
	var _a2 := PackedFloat32Array()
	var _y1 := PackedFloat32Array()
	var _y2 := PackedFloat32Array()
	var _gains := PackedFloat32Array()
	var _freqs := PackedFloat32Array()
	var _radii := PackedFloat32Array()
	## 每个共振每撞一下频率随机偏多少（比例），0 就是不偏。
	var _vary := PackedFloat32Array()
	var _chance := 0.0
	var _gain := 0.0
	var _sound_decay := 0.0
	var _system_decay := 0.0
	var _level := 0.0
	## 最后一道 FIR：b0、b1、b2。
	var _eq := Vector3.ZERO
	var _x1 := 0.0
	var _x2 := 0.0

	## freqs、radii、gains、vary 一一对应，是 STK 预设里的共振；objects 是有多少个小东西在撞，
	## base_gain、sound_decay、system_decay、eq 都是 STK 预设里同名的那几个数。
	func _init(rng: RandomNumberGenerator, freqs: Array[float], radii: Array[float], gains: Array[float],
			vary: Array[float], objects: float, base_gain: float, sound_decay: float, system_decay: float,
			eq: Vector3) -> void:
		_rng = rng
		var scale := STK_RATE / ProcAudio.RATE
		for i: int in freqs.size():
			_freqs.append(freqs[i])
			_radii.append(pow(radii[i], scale))
			_gains.append(gains[i])
			_vary.append(vary[i])
			_a1.append(-2.0 * _radii[i] * cos(TAU * freqs[i] / ProcAudio.RATE))
			_a2.append(_radii[i] * _radii[i])
			_y1.append(0.0)
			_y2.append(0.0)
		_chance = objects / 1024.0 * scale
		_gain = log(objects) * base_gain / objects
		_sound_decay = pow(sound_decay, scale)
		_system_decay = pow(system_decay, scale)
		_eq = eq

	## 摇一下，和 STK 的 noteOn 一样：amount 是 0 到 1 的力度。
	func shake(amount: float) -> void:
		energy = minf(energy + amount * 0.1, 1.0)

	## 一直推着它动（拖、滚）：能量至少保持在 amount。
	func drive(amount: float) -> void:
		energy = maxf(energy, minf(amount, 1.0))

	func tick() -> float:
		var input := 0.0
		if energy >= MIN_ENERGY:
			energy *= _system_decay
			if _rng.randf() < _chance:
				_level += energy
				input = _level
				for i: int in _freqs.size():
					if _vary[i] > 0.0:
						var hz := _freqs[i] * (1.0 + _vary[i] * (_rng.randf() * 2.0 - 1.0))
						_a1[i] = -2.0 * _radii[i] * cos(TAU * hz / ProcAudio.RATE)
		_level *= _sound_decay
		var out := 0.0
		for i: int in _freqs.size():
			var y := input * _gains[i] * _gain - _a1[i] * _y1[i] - _a2[i] * _y2[i]
			_y2[i] = _y1[i]
			_y1[i] = y
			out += y
		var filtered := _eq.x * out + _eq.y * _x1 + _eq.z * _x2
		_x2 = _x1
		_x1 = out
		return filtered


## STK 的 Stix1：两根木棍互相磕。
static func sticks(rng: RandomNumberGenerator) -> Shaker:
	return Shaker.new(rng, [5500.0], [0.6], [1.0], [0.0], 2.0, 6.0, 0.96, 0.998, Vector3(1.0, 0.0, -1.0))


## STK 的 Crunch1：踩碎东西的嘎吱声。这里拿来当火里炭块被压得挪动。
static func crunch(rng: RandomNumberGenerator) -> Shaker:
	return Shaker.new(rng, [800.0], [0.95], [1.0], [0.0], 7.0, 4.0, 0.95, 0.99806, Vector3(1.0, -1.0, 0.0))


## STK 的 Little Rocks：细碎的砂石。这里拿来当铁链蹭过冻土。
static func gravel(rng: RandomNumberGenerator) -> Shaker:
	return Shaker.new(rng, [9000.0], [0.843], [1.0], [0.18], 1600.0, 4.0, 0.98, 0.99586, Vector3(1.0, 0.0, -1.0))


## 铁链：照 STK 的 Sleighbells 改的。雪橇铃是一串薄铃，铁环更厚更沉，所以频率整体往下挪、
## 余音放长一点、同时在撞的东西少一些。
static func chain(rng: RandomNumberGenerator) -> Shaker:
	return Shaker.new(rng, [1700.0, 2950.0, 4300.0, 6100.0, 8200.0], [0.998, 0.997, 0.997, 0.996, 0.995],
		[1.0, 0.9, 0.8, 0.5, 0.3], [0.06, 0.06, 0.06, 0.06, 0.06], 8.0, 1.0, 0.97, 0.9994,
		Vector3(1.0, 0.0, -1.0))


## ModalBar 的敲击点：STK 只按敲的位置改前三个模态的增益，第四个用预设值。position 是 0 到 1。
static func bar_gains(position: float, fourth: float) -> Array[float]:
	var x := position * PI
	return [0.12 * sin(x), -0.03 * sin(0.05 + 3.9 * x), 0.11 * sin(-0.05 + 11.0 * x), fourth]


## 敲一下，返回 seconds 秒长、峰值为 1 的一段声音。
## base_hz 是最低的那个固有频率；ratios、radii、gains 一一对应（见上面的预设）；
## ring 把余音拉长几倍（STK 的木头是小木块，一整根柴要响得久一些）；
## hardness 是 0 到 1，越硬敲击的那一下越短越脆；direct 是敲击声本身直接混进去多少。
## 高过奈奎斯特频率九成的模态直接丢掉。
static func strike(rng: RandomNumberGenerator, seconds: float, base_hz: float, ratios: Array[float],
		radii: Array[float], gains: Array[float], ring: float, hardness: float, direct: float) -> PackedFloat32Array:
	var count := int(seconds * ProcAudio.RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	# STK 用一段录下来的槌击波形来激励；这里用一小段汉宁窗的噪声代替，越硬越短。
	var width := maxi(int(lerpf(0.003, 0.0004, hardness) * ProcAudio.RATE), 2)
	var excite := PackedFloat32Array()
	excite.resize(width)
	for i: int in width:
		excite[i] = (rng.randf() * 2.0 - 1.0) * (0.5 - 0.5 * cos(TAU * (i + 0.5) / width))
	var scale := STK_RATE / ProcAudio.RATE / maxf(ring, 0.01)
	for m: int in ratios.size():
		var hz := -ratios[m] if ratios[m] < 0.0 else ratios[m] * base_hz
		if hz >= ProcAudio.RATE * 0.45:
			continue
		var r := pow(radii[m], scale)
		# STK 的 BiQuad.setResonance(normalize = true)：零点放在 ±1，峰值增益归一。
		var b0 := 0.5 - 0.5 * r * r
		var a1 := -2.0 * r * cos(TAU * hz / ProcAudio.RATE)
		var a2 := r * r
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		for i: int in count:
			var x := excite[i] if i < width else 0.0
			var y := b0 * (x - x2) - a1 * y1 - a2 * y2
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			out[i] += y * gains[m]
	var mode_peak := peak(out)
	if mode_peak > 0.0:
		for i: int in count:
			out[i] /= mode_peak
	for i: int in mini(width, count):
		out[i] += excite[i] * direct
	return normalized(out, 1.0)


## 让一个 Shaker 按 drive 给的力度（随时间变化的 0 到 1）一直被推着走 seconds 秒，返回峰值为 1 的一段声音。
static func run(shaker: Shaker, seconds: float, drive: Callable) -> PackedFloat32Array:
	var count := int(seconds * ProcAudio.RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for i: int in count:
		var amount: float = drive.call(float(i) / ProcAudio.RATE)
		if amount > 0.0:
			shaker.drive(amount)
		out[i] = shaker.tick()
	return normalized(out, 1.0)


static func peak(samples: PackedFloat32Array) -> float:
	var top := 0.0
	for sample: float in samples:
		top = maxf(top, absf(sample))
	return top


## 缩放到峰值为 level。全是零的就原样返回。
static func normalized(samples: PackedFloat32Array, level: float) -> PackedFloat32Array:
	var top := peak(samples)
	if top <= 0.0:
		return samples
	var out := samples.duplicate()
	for i: int in out.size():
		out[i] *= level / top
	return out
