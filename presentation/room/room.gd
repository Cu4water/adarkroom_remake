extends Node3D
## 第一章：一间黑屋子，一堆火。
##
## 这里只做两件事：把玩家的点击变成发给模拟层的指令，把模拟层的事件交给
## 灯光、声音、建造者和柴堆去表现。火要不要木头、陌生人什么时候来，这些规则都不在这里。
##
## 镜头是主角的眼睛（见 PovView）。主角一开始坐在火边；第一次生起火以后鼠标锁在屏幕中间，
## 挪鼠标就是转头，按方向键（WASD）就站起来在屋里走动。按 Esc 放开鼠标，再点一下收回来。
##
## 玩家能做的事：
##   火灭着的时候，点任何地方 → 生火。第一次生火时主角转头看向火，火就在准星上
##   火烧着的时候，对准火堆点 → 添柴
##   对准门点 → 出去拾柴，柴从门口一根根扔进来落到柴堆上
##   对准柴堆点 → 柴堆上方浮起现在的木头数，散掉之前再点不起作用
##   建造者愿意帮忙以后，对准她点 → 她递过来数据板，上面是她能造的东西
## 能点的东西只在当下点了能成、而且准星正对着它的时候才亮起一层淡淡的暖光。
##
## 开场是全黑的，屏幕上没有字，只有一阵一阵的风。叙述文字只在调试版里按 F1 才显示。

const GLOW_SHADER := preload("res://presentation/room/shaders/interact_glow.gdshader")
## 她刚缓过来时低声念叨的，听不出是什么话。只拿来合成声音，字幕只有省略号。
const MUMBLE_VOICE := "mm hm.. mmm hm mm.."
## 她说的话：节拍 → 字幕的文本键。
const SPEECH: Dictionary[StringName, StringName] = {
	&"builder.shivers": &"builder.say.mumble",
	&"builder.helps": &"builder.say.helps",
	&"builder.plan.trap": &"builder.say.plan.trap",
	&"builder.plan.cart": &"builder.say.plan.cart",
}

## 主角坐着时眼睛的位置：火塘左前方，门差不多在正前方，火在右前方。
@export var seat_eye := Vector3(-0.9, 1.15, 0.3)
## 站起来以后眼睛多高，站起来有多快（米每秒）。
@export var stand_height := 1.55
@export var rise_speed := 0.8
## 走路多快（米每秒）。
@export var walk_speed := 1.3
## 眼睛能到的范围（世界 x、z），四面墙往里收了一个身宽。
@export var room_bounds := Rect2(-2.45, -2.05, 4.9, 4.1)
## 挡路的圆（x、z 是圆心，第三个数是半径，已经算上身宽）：火塘、柴堆。
@export var hearth_block := Vector3(0.56, -1.48, 0.88)
@export var pile_block := Vector3(1.46, -1.98, 0.62)
## 建造者和椅子各占多大一块，同样算上了身宽。
@export var person_block := 0.5
## 读档进来时主角看着哪：火和门之间，两个都在画面里。
@export var home_target := Vector3(-0.25, 0.75, -1.9)
## 鼠标挪一个像素，头转多少弧度。
@export var look_sensitivity := 0.0022
## 准星对上能用的东西时亮多少，以及亮度变化的快慢。
@export var glow_level := 0.5
@export var glow_speed := 5.0
## 门外那道光亮起来时的亮度。
@export var door_light_energy := 2.2
## 门开到多大，弧度。负数是朝屋里开。
@export var door_swing := -0.95
## 拾柴时门开到一半就开始往里扔柴，这是第一根出手的时刻（秒）。
@export var delivery_delay := 0.45
## 建造者喃喃自语时的音量（分贝）。
@export var mumble_volume := -9.0

@onready var _camera: Camera3D = $Camera
@onready var _hut: Node3D = $Hut
@onready var _rig: FireRig = $FireRig
@onready var _audio: RoomAudio = $RoomAudio
@onready var _builder: BuilderFigure = $Builder
@onready var _chair: Node3D = $Chair
@onready var _woodpile: Woodpile = $Woodpile
@onready var _log: NarrationLog = $UI/NarrationLog
@onready var _board: BuildBoard = $UI/BuildBoard
@onready var _fire_point: Marker3D = $FirePoint
@onready var _fire_area: Area3D = $FireArea
@onready var _door_area: Area3D = $DoorArea
@onready var _pile_area: Area3D = $WoodpileArea
@onready var _talk_area: Area3D = $Builder/TalkArea
@onready var _door_light: OmniLight3D = $DoorLight
@onready var _crosshair: Control = $UI/Crosshair

var _door: HutDoor
## 主角现在朝哪看、眼睛在哪，见 PovView。
var _look := Vector2.ZERO
var _eye := Vector3.ZERO
var _standing := false
## 生过火没有。生过以后才能转头、走动，才有准星和高亮。
var _ever_lit := false
## 每个能点的东西各自的高亮材质。
var _glows: Dictionary[Area3D, ShaderMaterial] = {}


func _ready() -> void:
	Game.ensure_booted()
	var materials := HutMaterials.new()
	materials.apply(_hut)
	materials.apply(_chair)
	_rig.bind(_hut, materials)
	_door = HutDoor.new(_hut.find_child("Door", true, false), _door_light, door_swing, door_light_energy)
	_door.closed.connect(_on_door_closed)
	_woodpile.bind(_hut)
	_builder.bind_chair(_chair)
	# 圈石和铺地石板在 hut.glb 里合成了一个 Hearth。石头本来就被火照得发白，底光要给足才看得出来。
	_glows[_fire_area] = _wear_glow([_hut.find_child("Hearth", true, false)])
	_glows[_fire_area].set_shader_parameter(&"fill", 0.3)
	_glows[_door_area] = _wear_glow(_door.meshes())
	_glows[_pile_area] = _wear_glow(_woodpile.meshes())
	# 人身上一层底光就像发了光的鬼影，只留一点边缘。
	_glows[_talk_area] = _wear_glow(_builder.find_children("*", "MeshInstance3D", true, false))
	_glows[_talk_area].set_shader_parameter(&"fill", 0.04)
	_glows[_talk_area].set_shader_parameter(&"rim", 0.45)
	_log.visible = false
	_builder.log_taken.connect(_on_builder_took_log)
	_builder.log_tossed.connect(_on_builder_tossed_log)
	_woodpile.log_landed.connect(_audio.play_log_drop)
	_board.closed.connect(_on_board_closed)

	var events: SimEvents = Game.events
	events.fire_changed.connect(_on_fire_changed)
	events.temperature_changed.connect(_builder.set_temperature)
	events.builder_changed.connect(_on_builder_changed)
	events.narrated.connect(_on_narrated)
	events.unlocked.connect(_on_unlocked)
	events.store_changed.connect(_on_store_changed)
	events.state_replaced.connect(_sync)
	_sync()


## 让画面和声音直接对上模拟现在的状态，不做过渡。刚进场景、新开一局、读档之后调用。
func _sync() -> void:
	var state: RunState = Game.sim.state
	_door.reset()
	_board.visible = false
	_ever_lit = not _in_opening()
	_eye = seat_eye
	_standing = false
	_set_look(PovView.look_at(seat_eye, home_target))
	if _ever_lit:
		_capture_mouse(true)
	for material: ShaderMaterial in _glows.values():
		material.set_shader_parameter(&"strength", 0.0)
	_rig.set_level(state.fire, true)
	_audio.set_fire_level(state.fire, true)
	_builder.sync(state.builder_level, state.temperature)
	_log.clear()
	_woodpile.reset()


func _process(delta: float) -> void:
	var sim: Simulation = Game.sim
	_audio.set_guiding(_in_opening())

	var can_gather := ForestSystem.can_gather(sim)
	_door.update_light(can_gather, delta)

	var free := _ever_lit and not _board.visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if free:
		_walk(delta)
	_eye.y = move_toward(_eye.y, stand_height if _standing else seat_eye.y, rise_speed * delta)
	_set_look(_look)

	# 开场黑屏时什么都不亮，只靠风声；生过火以后，准星对着的东西当下点了能成才亮。
	var aimed := _pick() if free else null
	var on_target := false
	for area: Area3D in _glows:
		var ready := _ready_to_use(area, can_gather)
		var lit := PovView.glow(ready, aimed == area, glow_level)
		_fade_glow(_glows[area], lit, delta)
		on_target = on_target or lit > 0.0
	_crosshair.visible = free
	_crosshair.modulate.a = 1.0 if on_target else 0.45


func _unhandled_input(event: InputEvent) -> void:
	if _board.visible:
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		if _ever_lit and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			# 鼠标放开过的话，这一下只是把它收回来，不算点了什么。
			_capture_mouse(true)
			return
		_on_click()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_set_look(PovView.turn(_look, motion.relative, look_sensitivity))
		return
	if event.is_action_pressed(&"ui_cancel") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_capture_mouse(false)
		return
	var key := event as InputEventKey
	if not OS.is_debug_build() or key == null or not key.pressed or key.echo:
		return
	# 开发用：F9 重新开一局回到黑屏；F1 显示叙述文字，对照节拍用。
	if key.keycode == KEY_F9:
		Game.new_run()
	elif key.keycode == KEY_F1:
		_log.visible = not _log.visible


## 还没生过火的黑屏：火灭着，陌生人没来过，森林也还没有。
func _in_opening() -> bool:
	var sim: Simulation = Game.sim
	return sim.state.fire == FireSystem.Level.DEAD and sim.state.builder_level == BuilderSystem.Level.ABSENT \
		and not sim.has_feature(ForestSystem.FEATURE)


## 这样东西现在点了能不能成。
func _ready_to_use(area: Area3D, can_gather: bool) -> bool:
	if not _ever_lit:
		return false
	if area == _fire_area:
		return FireSystem.can_tend(Game.sim)
	if area == _door_area:
		return can_gather and not _door.is_open
	if area == _pile_area:
		return not _woodpile.counting()
	return area == _talk_area and _builder_ready()


## 她愿意帮忙了，而且手上没在忙。
func _builder_ready() -> bool:
	return Game.sim.state.builder_level == BuilderSystem.Level.HELPING and not _builder.busy()


func _on_click() -> void:
	var sim: Simulation = Game.sim
	var hit := _pick() if _ever_lit else null
	if hit == _door_area and sim.has_feature(ForestSystem.FEATURE):
		_gather()
	elif hit == _pile_area:
		_woodpile.show_count()
	elif hit == _talk_area and _builder_ready():
		_board.open()
		_capture_mouse(false)
	elif sim.state.fire == FireSystem.Level.DEAD:
		_light()
	elif hit == _fire_area:
		_stoke()


## 按着方向键就站起来走。方向跟着视线，绕开火塘、柴堆、建造者和椅子。
func _walk(delta: float) -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if input == Vector2.ZERO:
		return
	_standing = true
	var obstacles: Array[Vector3] = [hearth_block, pile_block]
	var chair := _builder.chair_position()
	obstacles.append(Vector3(chair.x, chair.z, person_block))
	if _builder.visible:
		obstacles.append(Vector3(_builder.global_position.x, _builder.global_position.z, person_block))
	_eye = PovView.walk(_eye, input, _look.x, walk_speed * delta, obstacles, room_bounds)


func _light() -> void:
	if Game.sim.act(FireSystem.CMD_LIGHT) != Simulation.OK:
		# 黑着又没柴的时候什么都不发生。能做的只剩出门，门在亮着，玩家转头就能看见。
		return
	if not _ever_lit:
		# 第一次生火：这时候屋里还是黑的，头怎么转玩家都看不见。等火亮起来，它已经在准星上了。
		_set_look(PovView.look_at(_eye, _fire_point.global_position))
		_ever_lit = true
		_capture_mouse(true)
	_audio.play_ignite()


func _stoke() -> void:
	var result := Game.sim.act(FireSystem.CMD_STOKE)
	if result == Simulation.OK:
		_rig.kick(1.0)
		_audio.play_stoke()
	elif result == &"cooldown":
		# 刚添过柴。拨一下火，让玩家知道点到了，只是现在添不了。
		_rig.kick(0.2)
		_audio.play_poke()


func _gather() -> void:
	if _door.is_open:
		return
	var before := _woodpile.shown()
	# 木头在 act 里就进了库存，会马上发库存变化。先当门已经开了，柴堆才不会抢在柴飞进来之前就摆满。
	_door.is_open = true
	if Game.sim.act(ForestSystem.CMD_GATHER) != Simulation.OK:
		_door.is_open = false
		return
	_audio.gust(1.0, 1.7)
	_door.swing(0.7, 1.3, 0.8)
	_woodpile.deliver(before, _door_area.global_position, delivery_delay)


func _on_board_closed() -> void:
	_capture_mouse(true)


## 门关上时柴才落到柴堆上。
func _on_door_closed() -> void:
	_audio.play_door()
	_woodpile.refresh()


func _on_fire_changed(level: int) -> void:
	_rig.set_level(level)
	_audio.set_fire_level(level)


func _on_builder_changed(level: int) -> void:
	if level == BuilderSystem.Level.COLLAPSED:
		# 门被撞开，风灌进来，一个人影踉跄进门，冲着火倒在地上。
		_audio.gust(1.0, 1.4)
		_door.swing(0.22, 1.8, 1.0)
	_builder.set_level(level)


## 叙事节拍。大部分节拍已经由别的信号演出来了（火势、建造者等级、库存），这里只接住没有专门信号的那几个。
func _on_narrated(key: StringName, args: Dictionary) -> void:
	_log.push(NarrationLog.compose(key, args))
	if SPEECH.has(key):
		if key == &"builder.shivers":
			_builder.say(tr(SPEECH[key]), MUMBLE_VOICE, mumble_volume)
		else:
			_builder.say(tr(SPEECH[key]))
	match key:
		&"builder.stokes":
			_on_builder_stokes()
		&"build.too_cold":
			_builder.shiver_once()
		&"build.not_enough":
			_builder.shake_head()


## 她往火里添了一根柴。模拟里木头已经少了，画面上让她走过去拿、再丢进火里。
func _on_builder_stokes() -> void:
	if _builder.stoke():
		_woodpile.held = true
	else:
		_rig.kick(0.6)
		_audio.play_stoke()
		_woodpile.refresh()


func _on_builder_took_log() -> void:
	_woodpile.held = false
	_woodpile.refresh()


func _on_builder_tossed_log() -> void:
	_rig.kick(0.7)
	_audio.play_stoke()


func _on_unlocked(feature: StringName) -> void:
	if feature == ForestSystem.FEATURE:
		# "外面风在嚎。"
		_audio.gust(0.75, 2.5)
		_woodpile.refresh()


func _on_store_changed(id: StringName, _amount: int, _delta: int, _source: StringName) -> void:
	# 出门拾柴的时候，等门关上了柴才出现在柴堆上。
	if id == Woodpile.WOOD and not _door.is_open:
		_woodpile.refresh()


## 转头。只改朝向，站的位置由 _walk 管。
func _set_look(look: Vector2) -> void:
	_look = look
	_camera.global_transform = Transform3D(PovView.basis(_look), _eye)


func _capture_mouse(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


## 给一组网格套上同一份高亮材质，返回它，好统一调亮度。
func _wear_glow(meshes: Array[Node]) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GLOW_SHADER
	material.set_shader_parameter(&"strength", 0.0)
	for node: Node in meshes:
		(node as MeshInstance3D).material_overlay = material
	return material


func _fade_glow(material: ShaderMaterial, wanted: float, delta: float) -> void:
	var now: float = material.get_shader_parameter(&"strength")
	material.set_shader_parameter(&"strength", move_toward(now, wanted, glow_speed * delta))


## 准星对着的是哪个可以点的东西。没有就返回 null。她还不能搭话的时候，视线直接穿过她。
func _pick() -> Area3D:
	var view := _camera.global_transform
	var query := PhysicsRayQueryParameters3D.create(view.origin, view.origin - view.basis.z * 30.0)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	if not _builder_ready():
		query.exclude = [_talk_area.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") as Area3D
