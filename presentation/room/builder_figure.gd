class_name BuilderFigure
extends Node3D
## 建造者：从门口跌进来的一团模糊人影，到坐在火边、起身替你添柴的人。
##
## 分四层：
##   身体：BuilderRig 搭的动画状态机和程序化叠加。这里只说"去哪个状态"、"抖多少"，
##         倒下、起身、坐下这些过渡动作由状态机寻路补上。
##   动作：一串步骤（转向、走到某处、在某个动画状态停一会、等状态机走到某个状态、显隐手里的柴、
##         拿起或放下椅子、发信号）。进门、去搬椅子、起身说话、添柴都是动作。
##   外观：随恢复等级和室温变化的模糊暗影过渡。
##   说话：头顶的 NpcSpeech，字幕跟着"哔哔啵啵"的声音逐字出来。
##
## 椅子：她刚进门时椅子在右墙边的暗处。缓过一点以后，她站起来把椅子搬到火边坐下，
## 之后发抖、睡着、帮忙都坐在这把椅子上，添柴时起身，添完再坐回去。椅子和板子摆在哪由 BuilderProps 管。
##
## 这个节点不认识模拟层的规则，由 Room 告诉它等级、室温、"她刚添了一根柴"和"她说了什么"。

## 走到柴堆、弯腰拿起一根柴的那一刻。Room 在这时让柴堆少一根。
signal log_taken
## 柴塞进火里的那一刻。
signal log_tossed
## 椅子落地的那一刻。
signal chair_set_down
## 她把板子递到主角手里的那一刻。
signal board_given

const ChairAt := BuilderProps.ChairAt

## 地板高度都是 0。她在门洞里出现，踉跄着往屋里走几步，冲着火的方向瘫倒。
## 门轴在门洞左边、朝屋里开，她走门洞中间偏右，离开着的门扇远一点；踉跄时胳膊会甩到身子左边三十多厘米。
## 躺下时身子从脚往后伸出一米多，所以倒的地方离后墙和门扇都要留出空。
@export var door_spot := Vector3(-0.98, 0.0, -2.5)
@export var collapse_spot := Vector3(-1.05, 0.0, -1.2)
## 椅子一开始在右墙边的暗处，正面朝屋里；她站在它前面弯腰拿起来。站的地方要让弯下去的膝盖碰不到坐面。
@export var chair_home := Vector3(2.35, 0.0, 0.35)
@export var chair_home_yaw := -PI / 2.0
@export var chair_pick_spot := Vector3(1.7, 0.0, 0.35)
## 从倒下的地方去搬椅子，要从火塘前面绕过去。
@export var to_chair: Array[Vector3] = [Vector3(0.3, 0.0, -0.45)]
## 椅子搬到火塘右侧，正面朝着火，离柴堆两三步。
@export var chair_spot := Vector3(1.45, 0.0, -0.85)
@export var fire_center := Vector3(0.55, 0.0, -1.48)
@export var pile_spot := Vector3(1.42, 0.0, -1.48)
@export var pile_target := Vector3(1.65, 0.0, -1.60)
## 她走路时离火塘中心至少多远。比她坐着的地方离火心近一点，起步不用先绕。
@export var hearth_radius := 0.7
## 走路和踉跄的速度，米每秒。刚缓过来时走得慢。
@export var walk_speed := 0.85
@export var weak_walk_speed := 0.55
@export var stagger_speed := 0.42
## 转身角速度，弧度每秒。
@export var turn_speed := 5.5
## 清晰度每秒最多变多少。故意慢，让玩家看着她一点点从影子里浮出来。
@export var clarity_speed := 0.08
## 等状态机走到某个状态最多等几秒，防止寻路失败时卡住整串动作。
@export var until_timeout := 8.0
## 站起来说"我能帮忙"那一句时，在椅子前站多久再坐回去。
@export var stand_and_speak_seconds := 4.5
## 字幕在头顶上方多高。
@export var speech_height := 0.42

var speech: NpcSpeech

var _rig := BuilderRig.new()
var _materials := BuilderMaterials.new()
var _props := BuilderProps.new()

var _state := BuilderPose.State.HIDDEN
var _temperature := 0
var _blur := 1.0
var _shiver := 0.0
var _cold_left := 0.0
var _shake_left := 0.0
var _head_offset := Vector2.ZERO
var _breath := Vector2.ZERO
var _target_yaw := 0.0

var _steps: Array[Dictionary] = []
var _step_time := 0.0
var _step_anim: StringName = &""
var _step_speed := 1.0
var _time := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 1.0
	_materials.apply(self)
	_rig.setup(self)
	_props.bind_log(find_child("Builder_HeldLog", true, false) as Node3D)
	speech = NpcSpeech.new()
	speech.name = "Speech"
	add_child(speech)
	speech.top_level = true
	visible = false


## 她要搬的那把椅子。Room 在 _ready 里交给她，之后椅子放在哪由她管。
func bind_chair(chair: Node3D) -> void:
	_props.setup(Transform3D(Basis(Vector3.UP, chair_home_yaw), chair_home),
		Transform3D(Basis(Vector3.UP, _layout()["yaw"]), chair_spot))
	_props.bind_chair(chair)


## 按模拟现在的状态直接摆好，不做过渡。
func sync(level: int, temperature: int) -> void:
	_steps.clear()
	_step_time = 0.0
	_step_anim = &""
	_step_speed = 1.0
	_cold_left = 0.0
	_shake_left = 0.0
	_props.empty_hands(self)
	speech.clear()
	_temperature = temperature
	_state = BuilderPose.state_for(level)
	var layout := _layout()
	if BuilderPose.has_chair(_state):
		position = layout["seat"]
		_target_yaw = layout["yaw"]
		_props.place_chair(ChairAt.BY_FIRE)
	else:
		position = collapse_spot
		_target_yaw = BuilderPose.yaw_towards(position, fire_center)
		_props.place_chair(ChairAt.HOME)
	rotation.y = _target_yaw
	_blur = BuilderPose.blur_for(_state, _temperature)
	_shiver = BuilderPose.shiver_for(_state, _temperature)
	_head_offset = BuilderPose.head_offset_for(_state)
	_breath = BuilderPose.breath_for(_state)
	visible = _state != BuilderPose.State.HIDDEN
	_materials.set_blur(_blur)
	if visible:
		_rig.jump_to(BuilderPose.anim_for(_state))
		_advance_and_overlay(0.0, 0.0)


## 她恢复到了下一步。进门、去搬椅子、站起来说话要演一段动作；睡着只是在椅子上慢慢低下头。
func set_level(level: int) -> void:
	var next := BuilderPose.state_for(level)
	if next == _state:
		return
	var previous := _state
	_state = next
	if previous == BuilderPose.State.HIDDEN and next == BuilderPose.State.COLLAPSED:
		_arrive()
	elif previous == BuilderPose.State.COLLAPSED and next == BuilderPose.State.SHIVERING and _steps.is_empty():
		_fetch_chair()
	elif previous == BuilderPose.State.SHIVERING and next == BuilderPose.State.SLEEPING:
		pass
	elif previous == BuilderPose.State.SLEEPING and next == BuilderPose.State.HELPING and _steps.is_empty():
		_stand_and_sit_back()
	else:
		sync(level, _temperature)


func set_temperature(temperature: int) -> void:
	_temperature = temperature


## 让她起身去柴堆拿一根柴塞进火里，再坐回椅子上。她不在帮忙、或者手上正忙，就返回 false。
func stoke() -> bool:
	if _state != BuilderPose.State.HELPING or not _steps.is_empty():
		return false
	var layout := _layout()
	_steps.append({"until": BuilderPose.ANIM_IDLE, "anim_speed": 1.1})
	_steps.append({"to": pile_spot, "anim": BuilderPose.ANIM_WALK})
	_steps.append({"face": pile_target, "wait": _anim_seconds(BuilderPose.ANIM_PICKUP, BuilderPose.PICKUP_GRAB),
		"anim": BuilderPose.ANIM_PICKUP})
	_steps.append({"emit": &"log_taken", "log": true})
	_steps.append({"wait": _anim_seconds(BuilderPose.ANIM_PICKUP, BuilderPose.PICKUP_DONE - BuilderPose.PICKUP_GRAB),
		"anim": BuilderPose.ANIM_PICKUP})
	_steps.append({"to": layout["seat"], "anim": BuilderPose.ANIM_WALK_CARRY})
	_steps.append({"yaw": layout["yaw"], "wait": _anim_seconds(BuilderPose.ANIM_FEED, BuilderPose.FEED_RELEASE),
		"anim": BuilderPose.ANIM_FEED})
	_steps.append({"emit": &"log_tossed", "log": false})
	_steps.append({"wait": _anim_seconds(BuilderPose.ANIM_FEED, BuilderPose.FEED_DONE - BuilderPose.FEED_RELEASE),
		"anim": BuilderPose.ANIM_FEED})
	_steps.append({"yaw": layout["yaw"], "until": BuilderPose.ANIM_SITTING})
	return true


## 第一次找她说话：她从椅子上站起来，抱着板子走到主角跟前递过来，说一句 line，再走回去坐下。
## target 是主角站的地方。她不在帮忙、或者手上正忙，就返回 false。
func hand_over(target: Vector3, line: String) -> bool:
	if _state != BuilderPose.State.HELPING or not _steps.is_empty():
		return false
	var layout := _layout()
	var seat: Vector3 = layout["seat"]
	var stop := BuilderPose.stop_short(seat, target, BuilderPose.OFFER_DISTANCE)
	_steps.append({"until": BuilderPose.ANIM_IDLE})
	# 起身时手还搭在身前，要等开始端着走、手从身侧抬起来时板子才出现。
	_steps.append({"until": BuilderPose.ANIM_WALK_CARRY})
	_steps.append({"board": true})
	for point: Vector3 in BuilderPose.route_around(seat, stop, fire_center, hearth_radius):
		_steps.append({"to": point, "anim": BuilderPose.ANIM_WALK_CARRY})
	_steps.append({"emit": &"board_given"})
	_steps.append({"board": false})
	_steps.append({"say": line})
	_steps.append({"face": target, "wait": 1.8, "anim": BuilderPose.ANIM_IDLE})
	for point: Vector3 in BuilderPose.route_around(stop, seat, fire_center, hearth_radius):
		_steps.append({"to": point, "anim": BuilderPose.ANIM_WALK})
	_steps.append({"yaw": layout["yaw"], "until": BuilderPose.ANIM_SITTING})
	return true


## 屋里太冷，她抱着胳膊哆嗦一阵。
func shiver_once() -> void:
	if visible:
		_cold_left = 2.6


## 她摇摇头。坐着站着都能摇，叠在骨骼动画上。
func shake_head() -> void:
	if visible and _state == BuilderPose.State.HELPING:
		_shake_left = 1.4


## 她说一句话：text 是字幕，voice_text 是拿去合成声音的音节（留空就念字幕本身）。
func say(text: String, voice_text := "", volume_db := 0.0) -> void:
	if visible:
		speech.say(text, Babble.builder_voice(), voice_text, volume_db)


## 现在是不是正在做一串动作。
func busy() -> bool:
	return not _steps.is_empty()


## 动画状态机现在停在哪个状态。测试和调试用。
func current_anim() -> StringName:
	return _rig.current()


## 椅子现在在哪。玩家走动时要绕开她和椅子。
func chair_position() -> Vector3:
	return _props.chair_position(chair_home)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_cold_left = maxf(_cold_left - delta, 0.0)
	_shake_left = maxf(_shake_left - delta, 0.0)
	_run_steps(delta)

	_blur = move_toward(_blur, BuilderPose.blur_for(_state, _temperature), clarity_speed * delta)
	_materials.set_blur(_blur)
	var target_shiver := BuilderPose.shiver_for(_state, _temperature) + (0.75 if _cold_left > 0.0 else 0.0)
	_shiver = move_toward(_shiver, minf(target_shiver, 1.0), delta * 0.7)
	var resting := _steps.is_empty()
	var target_head := BuilderPose.head_offset_for(_state) if resting else Vector2.ZERO
	_head_offset = _head_offset.move_toward(target_head, delta * 1.4)
	_breath = _breath.move_toward(BuilderPose.breath_for(_state) if resting else Vector2.ZERO, delta * 0.5)
	rotation.y = lerp_angle(rotation.y, _target_yaw, minf(turn_speed * delta, 1.0))

	var speed := _step_speed
	if _step_anim != &"":
		_rig.go(_step_anim)
	else:
		speed = BuilderPose.speed_for(_state)
		_rig.go(BuilderPose.anim_for(_state))
	_advance_and_overlay(delta * speed, delta)
	_props.follow(global_transform, _rig.hands_position(global_position + Vector3.UP))
	_follow_head()


func _arrive() -> void:
	_steps.clear()
	_step_time = 0.0
	_props.show_log(false)
	_props.place_chair(ChairAt.HOME)
	position = door_spot
	_target_yaw = BuilderPose.yaw_towards(position, collapse_spot)
	rotation.y = _target_yaw
	_blur = 1.0
	_materials.set_blur(_blur)
	visible = true
	_rig.jump_to(BuilderPose.ANIM_IDLE_COLD)
	_steps.append({"wait": 0.45, "anim": BuilderPose.ANIM_IDLE_COLD})
	_steps.append({"to": collapse_spot, "speed": stagger_speed, "anim": BuilderPose.ANIM_STAGGER, "anim_speed": 0.75})
	_steps.append({"face": fire_center, "wait": 0.6, "anim": BuilderPose.ANIM_STAGGER, "anim_speed": 0.6})
	_steps.append({"until": BuilderPose.ANIM_LYING, "anim_speed": BuilderPose.speed_for(BuilderPose.State.COLLAPSED)})


## 缓过一点：撑地站起来，哆嗦着走到墙边把椅子搬过来，摆在火边坐下。
func _fetch_chair() -> void:
	var layout := _layout()
	var slow := BuilderPose.speed_for(BuilderPose.State.SHIVERING)
	_steps.append({"until": BuilderPose.ANIM_IDLE_COLD, "anim_speed": slow})
	_steps.append({"wait": 0.6, "anim": BuilderPose.ANIM_IDLE_COLD})
	for point: Vector3 in to_chair:
		_steps.append({"to": point, "speed": weak_walk_speed, "anim": BuilderPose.ANIM_WALK, "anim_speed": slow})
	_steps.append({"to": chair_pick_spot, "speed": weak_walk_speed, "anim": BuilderPose.ANIM_WALK, "anim_speed": slow})
	# 弯腰扣住坐面，直起身时椅子跟着手一起离地。
	var grab := _anim_seconds(BuilderPose.ANIM_PICKUP, BuilderPose.PICKUP_GRAB)
	var rise := _anim_seconds(BuilderPose.ANIM_PICKUP, BuilderPose.PICKUP_DONE - BuilderPose.PICKUP_GRAB)
	_steps.append({"face": chair_home, "wait": grab / slow, "anim": BuilderPose.ANIM_PICKUP, "anim_speed": slow})
	_steps.append({"chair": ChairAt.CARRIED})
	_steps.append({"wait": rise / slow, "anim": BuilderPose.ANIM_PICKUP, "anim_speed": slow, "lift": 1.0})
	_steps.append({"to": layout["put"], "speed": weak_walk_speed, "anim": BuilderPose.ANIM_WALK_CARRY,
		"anim_speed": slow})
	# 半蹲下去把它放下，椅子跟着手落到火边，放稳了就直起身。椅背在她跟前，蹲深了头会扎进椅背。
	_steps.append({"aim_chair": ChairAt.BY_FIRE})
	var put := _anim_seconds(BuilderPose.ANIM_FEED, BuilderPose.FEED_SET_DOWN)
	_steps.append({"face": chair_spot, "wait": put / slow, "anim": BuilderPose.ANIM_FEED, "anim_speed": slow,
		"lift": 0.0})
	_steps.append({"chair": ChairAt.BY_FIRE})
	_steps.append({"emit": &"chair_set_down"})
	_steps.append({"wait": 0.6, "anim": BuilderPose.ANIM_IDLE_COLD})
	for point: Vector3 in layout["around"]:
		_steps.append({"to": point, "speed": weak_walk_speed, "anim": BuilderPose.ANIM_WALK, "anim_speed": slow})
	_steps.append({"to": layout["seat"], "speed": weak_walk_speed, "anim": BuilderPose.ANIM_WALK, "anim_speed": slow})
	_steps.append({"yaw": layout["yaw"], "wait": 0.5, "anim": BuilderPose.ANIM_IDLE_COLD})
	_steps.append({"until": BuilderPose.ANIM_SITTING, "anim_speed": slow})


## 醒过来：从椅子上站起来，站着说她能帮忙，再坐回去。
func _stand_and_sit_back() -> void:
	var layout := _layout()
	_steps.append({"until": BuilderPose.ANIM_IDLE, "anim_speed": 0.9})
	_steps.append({"yaw": layout["yaw"], "wait": stand_and_speak_seconds, "anim": BuilderPose.ANIM_IDLE})
	_steps.append({"until": BuilderPose.ANIM_SITTING})


func _run_steps(delta: float) -> void:
	_step_anim = &""
	_step_speed = 1.0
	while not _steps.is_empty():
		var current := _steps[0]
		if current.has("face"):
			_target_yaw = BuilderPose.yaw_towards(position, current["face"])
		if current.has("yaw"):
			_target_yaw = current["yaw"]
		if current.has("log"):
			_props.show_log(bool(current["log"]))
		# 下面这几样只出现在不带等待的单独一步里，只做一次。
		if current.has("chair"):
			_props.place_chair(current["chair"])
		if current.has("aim_chair"):
			_props.aim_chair(current["aim_chair"])
		if current.has("board"):
			_props.show_board(self, current["board"])
		if current.has("say"):
			say(current["say"])
		_step_speed = current.get("anim_speed", 1.0)
		if current.has("to"):
			var to: Vector3 = current["to"]
			var speed: float = current.get("speed", walk_speed)
			var delta_pos := to - position
			if Vector2(delta_pos.x, delta_pos.z).length() > 0.01:
				_target_yaw = atan2(delta_pos.x, delta_pos.z)
			_step_anim = current.get("anim", BuilderPose.ANIM_WALK)
			position = position.move_toward(to, speed * delta)
			if position.distance_to(to) > 0.005:
				return
		elif current.has("wait"):
			_step_anim = current.get("anim", BuilderPose.ANIM_IDLE)
			_step_time += delta
			var wait := float(current["wait"])
			if current.has("lift"):
				if not current.has("lift_from"):
					current["lift_from"] = _props.lift
				_props.lift = lerpf(current["lift_from"], current["lift"], clampf(_step_time / wait, 0.0, 1.0))
			if _step_time < wait:
				return
			_step_time = 0.0
		elif current.has("until"):
			_step_anim = current["until"]
			_step_time += delta
			if not _rig.reached(_step_anim) and _step_time < until_timeout:
				return
			_step_time = 0.0
		elif current.has("emit"):
			emit_signal(current["emit"])
		_steps.pop_front()
	_step_anim = &""
	_step_speed = 1.0


func _layout() -> Dictionary:
	return BuilderPose.seat_layout(chair_spot, fire_center)


func _follow_head() -> void:
	var head := _rig.bone_position(&"Head", global_position + Vector3.UP * 1.45)
	speech.global_position = head + Vector3.UP * speech_height


func _anim_seconds(anim_name: StringName, fraction: float) -> float:
	return _rig.seconds(anim_name, fraction)


## 先推进骨骼动画，再叠加程序化的冷颤、呼吸、低头歪头与摇头。
func _advance_and_overlay(anim_delta: float, delta: float) -> void:
	_rig.advance(anim_delta)
	if delta < 0.0:
		return
	var tremble := _noise.get_noise_1d(_time * 14.0) * _shiver
	var breath := sin(_time * TAU * _breath.y) * _breath.x
	# 摇头：左右来回几下，越摇越轻。
	var shake := sin(_shake_left * TAU * 2.2) * 0.32 * minf(_shake_left, 1.0) if _shake_left > 0.0 else 0.0
	_rig.overlay(tremble, breath, _head_offset, shake)