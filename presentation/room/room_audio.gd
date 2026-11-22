class_name RoomAudio
extends Node3D
## 屋里的声音：风、火，和几个动作的音效。
##
## 风声在这里是状态显示，不是背景音乐：火灭着的时候风就在耳边，
## 火越旺风听起来越远、越闷。玩家不看任何数字也能听出火怎么样了。
##
## 这个节点不认识模拟层，由 Room 把火势告诉它。把它放在火堆的位置上，火声就会从火的方向传来。

## 正式素材。留空就用 ProcAudio 合成的占位声音。带 s 的是同一个动作的几个变体，每次随机挑一个，不连着重复。
@export var wind_stream: AudioStream
@export var fire_stream: AudioStream
@export var ignite_stream: AudioStream
## 添柴分两层：柴砸在火里的木头声，和随后炭块挪动、火星噼啪的火声。
@export var stoke_streams: Array[AudioStream] = []
@export var ember_streams: Array[AudioStream] = []
@export var poke_stream: AudioStream
## 开门、关门的吱呀，和门撞上门框的那一下。
@export var door_open_stream: AudioStream
@export var door_close_stream: AudioStream
@export var door_stream: AudioStream
@export var log_drop_streams: Array[AudioStream] = []
## 造好一副陷阱，铁链在门外地上拖过去。
@export var chain_drag_stream: AudioStream

## 下面每张表都是五个数，依次对应：灭、闷烧、摇曳、燃烧、旺。
## 风的主体音量（分贝）。
const WIND_BODY_DB: Array[float] = [-5.0, -10.0, -14.0, -19.0, -23.0]
## 风里那层尖啸的音量。它掉得比主体快，所以火一起来，最先消失的是刺耳的部分。
const WIND_HOWL_DB: Array[float] = [-10.0, -18.0, -24.0, -31.0, -37.0]
## 风的低通截止频率。越低越闷，听起来像隔着墙。
const WIND_CUTOFF_HZ: Array[float] = [5200.0, 2600.0, 1700.0, 1100.0, 850.0]
const FIRE_DB: Array[float] = [-80.0, -27.0, -16.0, -10.0, -6.0]

const BUS_BODY := &"WindBody"
const BUS_HOWL := &"WindHowl"

## 风声跟上火势变化的速度，每秒走几级。故意慢，让玩家听得出"风在退"。
@export var follow_speed := 0.4
## 生火那一下风退得快一些，这几秒里用这个速度。
@export var hush_speed := 1.1
@export var hush_seconds := 2.5
## 火声跟上火势变化的速度。它得和画面上的火一起起来，所以比风快得多。
@export var fire_follow_speed := 1.5
## 开场黑屏时，每隔多少秒来一阵风，x 是下限，y 是上限。
@export var guide_gust_interval := Vector2(5.0, 9.0)

var _wind_body: AudioStreamPlayer
var _wind_howl: AudioStreamPlayer
var _fire: AudioStreamPlayer3D
var _action: AudioStreamPlayer3D
var _embers: AudioStreamPlayer3D
var _creak: AudioStreamPlayer3D
var _door: AudioStreamPlayer3D
var _log_drop: AudioStreamPlayer3D
var _chain: AudioStreamPlayer3D
## 上一次用的是第几个变体。
var _last_stoke := -1
var _last_log := -1

var _low_pass: AudioEffectLowPassFilter
var _band_pass: AudioEffectBandPassFilter

var _level := 0.0
## 风和火各自听起来的火势，都在往 _level 靠，只是速度不一样。
var _shown := 0.0
var _fire_shown := 0.0
var _fade_in := 0.0
var _time := 0.0
## 一阵风：门开了，或者外面风大了。0 到 1。
var _gust := 0.0
var _gust_target := 0.0
var _gust_hold := 0.0
var _hush_left := 0.0
var _guiding := false
var _guide_left := 0.0
var _noise := FastNoiseLite.new()
## 只用来挑风什么时候来，和模拟无关。
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 1.0
	_low_pass = _bus_effect(BUS_BODY, AudioEffectLowPassFilter.new()) as AudioEffectLowPassFilter
	_band_pass = _bus_effect(BUS_HOWL, AudioEffectBandPassFilter.new()) as AudioEffectBandPassFilter
	_band_pass.resonance = 0.75

	var wind := wind_stream if wind_stream != null else ProcAudio.wind_loop(7.0, 11)
	_wind_body = _player(wind, BUS_BODY)
	_wind_howl = _player(wind, BUS_HOWL)
	_fire = _player_3d(fire_stream if fire_stream != null else ProcAudio.crackle_loop(6.0, 23))
	_action = _player_3d(null)
	_embers = _player_3d(null)
	_creak = _player_3d(null)
	_door = _player_3d(door_stream if door_stream != null else ProcAudio.door(41))
	_log_drop = _player_3d(null)
	_chain = _player_3d(chain_drag_stream if chain_drag_stream != null else ProcAudio.chain_drag(67))
	if ignite_stream == null:
		ignite_stream = ProcAudio.ignite(31)
	if stoke_streams.is_empty():
		for noise_seed: int in [37, 38, 39]:
			stoke_streams.append(ProcAudio.stoke(noise_seed))
	if ember_streams.is_empty():
		for noise_seed: int in [37, 38, 39]:
			ember_streams.append(ProcAudio.embers(noise_seed))
	if poke_stream == null:
		poke_stream = ProcAudio.poke(43)
	if door_open_stream == null:
		door_open_stream = ProcAudio.door_open(71)
	if door_close_stream == null:
		door_close_stream = ProcAudio.door_close(73)
	if log_drop_streams.is_empty():
		for noise_seed: int in [47, 53, 59, 61]:
			log_drop_streams.append(ProcAudio.log_drop(noise_seed))

	_update(0.0)
	_wind_body.play()
	# 两层用的是同一段噪声，错开播放位置就听不出来了。
	_wind_howl.play(wind.get_length() * 0.45)
	_fire.play()


func set_fire_level(level: int, instant := false) -> void:
	_level = float(level)
	if instant:
		_shown = _level
		_fire_shown = _level


## 开场黑屏时打开：屋里什么都看不见，只有风一阵一阵地来，告诉玩家这不是卡住了，这里有东西。
func set_guiding(on: bool) -> void:
	if on and not _guiding:
		_guide_left = guide_gust_interval.x * 0.6
	_guiding = on


## 来一阵风。strength 是 0 到 1，hold 是它顶着不退的秒数。
func gust(strength: float, hold: float) -> void:
	_gust_target = clampf(strength, 0.0, 1.0)
	_gust_hold = hold


## 火着起来的那一下：风先退一截，像是被火挡在了外面。
func play_ignite() -> void:
	_action.pitch_scale = 1.0
	_play_action(ignite_stream, 0.0)
	_hush_left = hush_seconds


func play_stoke() -> void:
	_last_stoke = _variant(stoke_streams.size(), _last_stoke)
	_action.pitch_scale = _rng.randf_range(0.85, 0.97)
	_play_action(stoke_streams[_last_stoke], -6.0)
	_embers.stream = ember_streams[_rng.randi() % ember_streams.size()]
	_embers.volume_db = -5.0
	_embers.play()


func play_poke() -> void:
	_action.pitch_scale = 1.0
	_play_action(poke_stream, -8.0)


## 一根柴落到柴堆上。at 是落点，声音从那个方向传来；一根接一根落下时音高稍微错开。
func play_log_drop(at: Vector3) -> void:
	_last_log = _variant(log_drop_streams.size(), _last_log)
	_log_drop.stream = log_drop_streams[_last_log]
	_log_drop.global_position = at
	_log_drop.pitch_scale = _rng.randf_range(0.92, 1.08)
	_log_drop.volume_db = -8.0
	_log_drop.play()


## 门开始开。at 是门的位置，seconds 是门这一次开过去要多久：撞开的时候快，吱呀声也跟着急促、尖一些。
func play_door_open(at: Vector3, seconds: float) -> void:
	_play_creak(door_open_stream, at, ProcAudio.OPEN_SECONDS / seconds, -9.0)


## 门开始往回关。seconds 是这一次关回来要多久。
func play_door_close(at: Vector3, seconds: float) -> void:
	_play_creak(door_close_stream, at, ProcAudio.CLOSE_SECONDS / seconds, -11.0)


## 门撞上门框。
func play_door(at: Vector3) -> void:
	_door.global_position = at
	_door.volume_db = -6.0
	_door.play()


## 门外有人把一副新陷阱拖走了。at 是门的位置。
func play_chain_drag(at: Vector3) -> void:
	_chain.global_position = at
	_chain.volume_db = -10.0
	_chain.play()


func _process(delta: float) -> void:
	_update(delta)


func _update(delta: float) -> void:
	_time += delta
	_fade_in = move_toward(_fade_in, 1.0, delta / 2.5)
	_hush_left = maxf(_hush_left - delta, 0.0)
	var speed := hush_speed if _hush_left > 0.0 and _level > _shown else follow_speed
	_shown = move_toward(_shown, _level, speed * delta)
	_fire_shown = move_toward(_fire_shown, _level, fire_follow_speed * delta)

	if _guiding:
		_guide_left -= delta
		if _guide_left <= 0.0:
			gust(_rng.randf_range(0.3, 0.6), _rng.randf_range(1.0, 2.2))
			_guide_left = _rng.randf_range(guide_gust_interval.x, guide_gust_interval.y)

	_gust_hold -= delta
	if _gust_hold <= 0.0:
		_gust_target = 0.0
	var gust_speed := 1.6 if _gust_target > _gust else 0.35
	_gust = move_toward(_gust, _gust_target, gust_speed * delta)

	# 风自己的起伏。两条慢噪声，一条管强弱，一条管尖啸的音高。
	var swell := _noise.get_noise_1d(_time * 0.17)
	var whistle := _noise.get_noise_1d(_time * 0.11 + 40.0)
	var fade_db := linear_to_db(maxf(_fade_in, 0.0001))

	_wind_body.volume_db = LevelTable.sample(WIND_BODY_DB, _shown) + swell * 3.0 + _gust * 9.0 + fade_db
	_wind_howl.volume_db = LevelTable.sample(WIND_HOWL_DB, _shown) + (swell + whistle) * 3.5 + _gust * 13.0 + fade_db
	var cutoff := LevelTable.sample(WIND_CUTOFF_HZ, _shown) * (1.0 + swell * 0.25)
	_low_pass.cutoff_hz = lerpf(cutoff, 6500.0, _gust * 0.85)
	_band_pass.cutoff_hz = 430.0 + whistle * 170.0 + swell * 90.0 + _gust * 160.0

	_fire.volume_db = LevelTable.sample(FIRE_DB, _fire_shown)
	_fire.pitch_scale = lerpf(0.85, 1.1, _fire_shown / 4.0)


func _play_action(stream: AudioStream, volume_db: float) -> void:
	_action.stream = stream
	_action.volume_db = volume_db
	_action.play()


## 音高按门动的快慢对齐，但不让它变得像别的东西：太快的不尖成哨子，太慢的不沉成闷雷。
func _play_creak(stream: AudioStream, at: Vector3, pitch: float, volume_db: float) -> void:
	_creak.stream = stream
	_creak.global_position = at
	_creak.pitch_scale = clampf(pitch, 0.8, 1.5)
	_creak.volume_db = volume_db
	_creak.play()


## 从 count 个变体里随机挑一个的序号，不和上一次的 last 相同。
func _variant(count: int, last: int) -> int:
	if count < 2:
		return 0
	var index := _rng.randi_range(0, count - 2)
	return index + 1 if last >= 0 and index >= last else index


func _player(stream: AudioStream, bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	add_child(player)
	return player


func _player_3d(stream: AudioStream) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	# 屋子很小，不做距离衰减，只保留左右方位。
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	player.panning_strength = 0.7
	add_child(player)
	return player


## 取一条带指定效果器的音频总线，没有就建一条。
static func _bus_effect(bus_name: StringName, effect: AudioEffect) -> AudioEffect:
	var index := AudioServer.get_bus_index(bus_name)
	if index != -1:
		return AudioServer.get_bus_effect(index, 0)
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")
	AudioServer.add_bus_effect(index, effect)
	return effect

