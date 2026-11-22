class_name FireRig
extends Node3D
## 把火势变成看得见的东西：灯、火焰、余烬、火星。
##
## 屋里只有火这一处光源，没有环境光。火势决定灯照多远，照不到的地方就是黑的，
## 所以"玩家现在能看见什么"完全由火势说了算。
##
## 这个节点不认识模拟层，由 Room 把火势告诉它。内部只有一个连续的量 _shown
## （0 到 4，对应五级火势），所有看得见的东西都是按它在下面这些表里插值出来的。

## 下面每张表都是五个数，依次对应：灭、闷烧、摇曳、燃烧、旺。
## 光照的范围就是"看得见多少"，相邻两级之间故意拉得很开：
##   闷烧   只有炭床自己发红，照不出火塘
##   摇曳   火塘和一圈石头
##   燃烧   火堆和周围一米左右的地板，柴堆在边上，屋里其余地方还是黑的
##   旺     整间屋子才亮起来，火光经墙和屋顶反弹，照到角落和门
const KEY_ENERGY: Array[float] = [0.0, 0.0, 0.5, 1.35, 3.2]
const KEY_RANGE: Array[float] = [0.5, 0.5, 1.1, 2.2, 11.0]
## 光在照到范围边上之前衰减得多快。小火的光贴着火堆，到范围边上已经几乎没了，不会在墙上切出一个圆。
const KEY_ATTENUATION: Array[float] = [2.5, 2.5, 2.2, 2.1, 0.9]
const EMBER_ENERGY: Array[float] = [0.0, 0.3, 0.55, 0.8, 1.3]
const EMBER_RANGE: Array[float] = [0.3, 0.45, 0.7, 1.1, 3.2]
const BOUNCE_ENERGY: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.34]
const FLAME_HEIGHT: Array[float] = [0.0, 0.0, 0.5, 0.9, 1.3]
const FLAME_WIDTH: Array[float] = [0.0, 0.0, 0.65, 0.95, 1.15]
const FLAME_INTENSITY: Array[float] = [0.0, 0.0, 0.6, 0.85, 1.1]
const EMBER_GLOW: Array[float] = [0.0, 0.55, 0.8, 1.0, 1.0]
const LOG_HEAT: Array[float] = [0.0, 0.2, 0.45, 0.8, 1.0]
const SPARKS: Array[float] = [0.0, 0.0, 0.1, 0.4, 1.0]
## 火越小越不稳。
const FLICKER: Array[float] = [0.0, 0.1, 0.24, 0.15, 0.11]

## 火势上升和下降时，每秒走几级。点火要快，熄灭要慢。
@export var rise_speed := 1.5
@export var fall_speed := 0.45

@onready var _key: OmniLight3D = $KeyLight
@onready var _ember: OmniLight3D = $EmberLight
@onready var _bounce: OmniLight3D = $BounceLight
@onready var _sparks: GPUParticles3D = $Sparks

var _target := 0.0
var _shown := 0.0
## 添柴之后火会蹿一下，这个量很快衰减回 0。
var _surge := 0.0
var _time := 0.0
var _noise := FastNoiseLite.new()
var _key_origin := Vector3.ZERO

var _materials: HutMaterials
var _flames: Array[MeshInstance3D] = []
var _flame_rest: Array[Transform3D] = []


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 1.0
	_key_origin = _key.position
	_apply()


## 接上小屋模型里的火焰网格，以及会跟着火势变的那几个材质。
func bind(hut: Node, materials: HutMaterials) -> void:
	_materials = materials
	_flames.clear()
	_flame_rest.clear()
	for node: Node in hut.find_children("Flame_*", "MeshInstance3D", true, false):
		var flame: MeshInstance3D = node
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.set_instance_shader_parameter(&"phase", _flames.size() * 1.7)
		_flames.append(flame)
		_flame_rest.append(flame.transform)
	_apply()


func set_level(level: int, instant := false) -> void:
	_target = float(level)
	if instant:
		_shown = _target
		_surge = 0.0
		_apply()


## 让火蹿一下。添柴成功时给 1，点了没反应（还在冷却）时给个小的。
func kick(strength: float) -> void:
	_surge = maxf(_surge, strength)


## 现在画面上的火势，0 到 4 的连续值。
func shown_level() -> float:
	return _shown


func _process(delta: float) -> void:
	_time += delta
	var speed := rise_speed if _target > _shown else fall_speed
	_shown = move_toward(_shown, _target, speed * delta)
	_surge = move_toward(_surge, 0.0, delta * 0.8)
	_apply()


func _apply() -> void:
	var lit := _shown > 0.001
	# 两层噪声叠在一起：慢的是火势起伏，快的是火苗抖动。
	var wobble := _noise.get_noise_1d(_time * 2.3) * 0.6 + _noise.get_noise_1d(_time * 9.1 + 50.0) * 0.4
	var flicker := 1.0 + wobble * LevelTable.sample(FLICKER, _shown)
	var boost := 1.0 + _surge * 0.35

	_key.light_energy = LevelTable.sample(KEY_ENERGY, _shown) * flicker * boost
	_key.omni_range = LevelTable.sample(KEY_RANGE, _shown)
	_key.omni_attenuation = LevelTable.sample(KEY_ATTENUATION, _shown)
	_key.visible = _key.light_energy > 0.001
	# 主灯跟着火苗轻轻挪动，影子才会晃。
	_key.position = _key_origin + Vector3(
		_noise.get_noise_1d(_time * 5.0 + 11.0), _noise.get_noise_1d(_time * 4.0 + 23.0) * 0.6,
		_noise.get_noise_1d(_time * 5.5 + 37.0)) * 0.025

	_ember.light_energy = LevelTable.sample(EMBER_ENERGY, _shown) * (1.0 + wobble * 0.08) * boost
	_ember.omni_range = LevelTable.sample(EMBER_RANGE, _shown)
	_ember.visible = lit
	_bounce.light_energy = LevelTable.sample(BOUNCE_ENERGY, _shown) * flicker
	_bounce.visible = _bounce.light_energy > 0.001

	_sparks.emitting = lit
	_sparks.amount_ratio = clampf(LevelTable.sample(SPARKS, _shown) + _surge * 0.8, 0.0, 1.0)

	var height := LevelTable.sample(FLAME_HEIGHT, _shown) * (1.0 + _surge * 0.45)
	var width := LevelTable.sample(FLAME_WIDTH, _shown) * (1.0 + _surge * 0.15)
	for index: int in _flames.size():
		var flame := _flames[index]
		flame.visible = height > 0.02
		if flame.visible:
			# 每片火焰的高度再各自起伏一点。
			var own := 1.0 + _noise.get_noise_1d(_time * 3.0 + index * 19.0) * 0.18
			flame.transform = _flame_rest[index] * Transform3D(Basis.from_scale(Vector3(width, height * own, width)))

	if _materials != null:
		var intensity := LevelTable.sample(FLAME_INTENSITY, _shown) * flicker * boost
		_materials.flame_core.set_shader_parameter(&"intensity", intensity)
		_materials.flame_outer.set_shader_parameter(&"intensity", intensity * 0.55)
		_materials.embers.set_shader_parameter(&"glow", minf(LevelTable.sample(EMBER_GLOW, _shown) * boost, 1.0))
		_materials.charred.set_shader_parameter(&"heat", LevelTable.sample(LOG_HEAT, _shown))

