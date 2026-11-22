class_name BuilderPose
extends RefCounted
## 建造者在每个阶段"看起来是什么样"，以及她的骨骼动画状态机怎么连。
##
## 模拟层只给两个数：她恢复到了哪一步（BuilderSystem.Level），屋子有多暖（FireSystem.Temp）。
## 这里把它们映射成动画状态机的目标状态、播速、呼吸、头部微调、发抖与模糊程度，
## 以及她搬来的那把椅子摆在火边哪里、她站在哪里坐下。
## 纯数据和纯函数，不碰节点，可以单独测试。BuilderFigure 照着 TRANSITIONS 搭 AnimationTree。

enum State { HIDDEN, COLLAPSED, SHIVERING, SLEEPING, HELPING }

## builder.glb 里的全部骨骼动画（Quaternius UAL1 & UAL2，CC0），同时也是动画状态机的节点名。
const ANIM_IDLE := &"idle"
const ANIM_IDLE_COLD := &"idle_cold"
const ANIM_WALK := &"walk"
const ANIM_WALK_CARRY := &"walk_carry"
const ANIM_STAGGER := &"stagger"
const ANIM_COLLAPSE := &"collapse"
const ANIM_LYING := &"lying"
const ANIM_GET_UP := &"get_up"
const ANIM_PICKUP := &"pickup"
const ANIM_FEED := &"feed"
const ANIM_SIT_DOWN := &"sit_down"
const ANIM_SITTING := &"sitting"
const ANIM_STAND_UP := &"stand_up"

const ALL_ANIMS: Array[StringName] = [
	ANIM_IDLE, ANIM_IDLE_COLD, ANIM_WALK, ANIM_WALK_CARRY, ANIM_STAGGER,
	ANIM_COLLAPSE, ANIM_LYING, ANIM_GET_UP, ANIM_PICKUP, ANIM_FEED,
	ANIM_SIT_DOWN, ANIM_SITTING, ANIM_STAND_UP,
]

## 需要循环播放的动画。其余是播一遍就停在最后一帧的单次动作。
const LOOP_ANIMS: Array[StringName] = [
	ANIM_IDLE, ANIM_IDLE_COLD, ANIM_WALK, ANIM_WALK_CARRY, ANIM_STAGGER, ANIM_LYING, ANIM_SITTING,
]

## 动画状态机的连线：[从, 到, 交叉淡入秒数, 播完才走]。
## 播完才走的连线也会自动走：倒下播完就躺着，起身播完就抱臂站着，坐下播完就坐着。
## 表现层只说"去哪个状态"，中间要经过的过渡动作由状态机按连线寻路补上。
const TRANSITIONS: Array[Array] = [
	# 进门：抱臂站在门口，踉跄几步，瘫倒在地。
	[ANIM_IDLE_COLD, ANIM_STAGGER, 0.4, false],
	[ANIM_STAGGER, ANIM_COLLAPSE, 0.35, false],
	[ANIM_COLLAPSE, ANIM_LYING, 0.15, true],
	# 缓过来一点：撑地站起来，去搬椅子。
	[ANIM_LYING, ANIM_GET_UP, 0.25, false],
	[ANIM_GET_UP, ANIM_IDLE_COLD, 0.3, true],
	# 站着：冷了抱臂，暖了放下手，走动。
	[ANIM_IDLE_COLD, ANIM_IDLE, 0.7, false],
	[ANIM_IDLE, ANIM_IDLE_COLD, 0.7, false],
	[ANIM_IDLE, ANIM_WALK, 0.25, false],
	[ANIM_IDLE_COLD, ANIM_WALK, 0.25, false],
	[ANIM_WALK, ANIM_IDLE, 0.3, false],
	[ANIM_WALK, ANIM_IDLE_COLD, 0.3, false],
	# 弯腰拿起或放下东西（椅子、柴），抱着走。
	[ANIM_WALK, ANIM_PICKUP, 0.25, false],
	[ANIM_IDLE, ANIM_PICKUP, 0.3, false],
	[ANIM_IDLE_COLD, ANIM_PICKUP, 0.3, false],
	[ANIM_PICKUP, ANIM_WALK_CARRY, 0.35, false],
	[ANIM_PICKUP, ANIM_WALK, 0.35, false],
	[ANIM_PICKUP, ANIM_IDLE, 0.4, false],
	[ANIM_WALK, ANIM_WALK_CARRY, 0.3, false],
	[ANIM_WALK_CARRY, ANIM_WALK, 0.3, false],
	[ANIM_WALK_CARRY, ANIM_PICKUP, 0.3, false],
	[ANIM_WALK_CARRY, ANIM_IDLE, 0.3, false],
	# 添柴：抱着柴走回火边，蹲下塞进火里。
	[ANIM_WALK_CARRY, ANIM_FEED, 0.3, false],
	[ANIM_FEED, ANIM_WALK, 0.35, false],
	[ANIM_FEED, ANIM_IDLE, 0.4, false],
	# 坐到火边的椅子上，起身。
	[ANIM_IDLE, ANIM_SIT_DOWN, 0.3, false],
	[ANIM_IDLE_COLD, ANIM_SIT_DOWN, 0.3, false],
	[ANIM_WALK, ANIM_SIT_DOWN, 0.3, false],
	[ANIM_SIT_DOWN, ANIM_SITTING, 0.25, true],
	[ANIM_SITTING, ANIM_STAND_UP, 0.25, false],
	[ANIM_STAND_UP, ANIM_IDLE, 0.3, true],
]

## 拿起、放下动作里手碰到东西的时刻，占整段动作的比例；以及何时可以直起身离开。
const PICKUP_GRAB := 0.33
const PICKUP_DONE := 0.72
const FEED_RELEASE := 0.5
const FEED_DONE := 0.86

## 坐姿动画里骨盆在人物原点后方多远（米），椅子坐面正中要对准它。量自 builder.glb 的 sitting。
const SEAT_BACK := 0.31
## 放椅子时她站在椅子后面多远，放好以后从椅子侧面多远绕到前面。
const PUT_BEHIND := 0.5
const WALK_AROUND := 0.5
## 抱着椅子走的时候，椅子相对她的位置：坐面托在两手之间，椅面朝她，靠背在外侧。
const CARRY := Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.58, 0.4))

## 她缓过来的每一步有多模糊。HELPING 之后就是一个清楚的人。
const BLUR: Dictionary[State, float] = {
	State.HIDDEN: 1.0, State.COLLAPSED: 1.0, State.SHIVERING: 0.7, State.SLEEPING: 0.35, State.HELPING: 0.0,
}
## 每一档室温让她清楚多少：屋子越暖，影子越实。依次对应冻、冷、凉、暖、热。
const WARMTH_CLARITY: Array[float] = [0.0, 0.08, 0.18, 0.3, 0.4]
## 每个状态本来抖得多厉害，再乘上下面这张按室温的表。
const SHIVER: Dictionary[State, float] = {
	State.HIDDEN: 0.0, State.COLLAPSED: 0.6, State.SHIVERING: 1.0, State.SLEEPING: 0.0, State.HELPING: 0.0,
}
const COLD_SHIVER: Array[float] = [1.0, 0.85, 0.55, 0.3, 0.15]

## 每个阶段的动画播放倍率，也决定她往这个阶段过渡时动作有多快：刚缓过来时动作是硬撑着的。
const PLAY_SPEED: Dictionary[State, float] = {
	State.HIDDEN: 1.0, State.COLLAPSED: 0.7, State.SHIVERING: 0.75, State.SLEEPING: 0.55, State.HELPING: 0.85,
}
## 胸口的起伏：x=幅度（弧度），y=每秒几次。倒下时喘得急，坐在椅子上睡着后又慢又深。
const BREATH: Dictionary[State, Vector2] = {
	State.HIDDEN: Vector2.ZERO,
	State.COLLAPSED: Vector2(0.035, 0.42),
	State.SHIVERING: Vector2(0.015, 0.33),
	State.SLEEPING: Vector2(0.03, 0.2),
	State.HELPING: Vector2.ZERO,
}
## 叠加在骨骼动画之上的头部微调（x=低头弧度，y=歪头弧度）。坐着发抖时埋着头，睡着时头歪向一边。
const HEAD_OFFSET: Dictionary[State, Vector2] = {
	State.HIDDEN: Vector2.ZERO,
	State.COLLAPSED: Vector2(0.08, 0.22),
	State.SHIVERING: Vector2(0.4, 0.06),
	State.SLEEPING: Vector2(0.3, 0.42),
	State.HELPING: Vector2(0.04, 0.0),
}


static func state_for(level: int) -> State:
	match level:
		BuilderSystem.Level.COLLAPSED:
			return State.COLLAPSED
		BuilderSystem.Level.SHIVERING:
			return State.SHIVERING
		BuilderSystem.Level.SLEEPING:
			return State.SLEEPING
		BuilderSystem.Level.HELPING:
			return State.HELPING
	return State.HIDDEN


## 这个阶段平时停在哪个动画状态。倒下时躺在地上；缓过一点以后就一直坐在火边的椅子上。
static func anim_for(state: State) -> StringName:
	match state:
		State.COLLAPSED:
			return ANIM_LYING
		State.SHIVERING, State.SLEEPING, State.HELPING:
			return ANIM_SITTING
	return ANIM_IDLE


## 椅子已经搬到火边的阶段。
static func has_chair(state: State) -> bool:
	return state == State.SHIVERING or state == State.SLEEPING or state == State.HELPING


static func speed_for(state: State) -> float:
	return PLAY_SPEED[state]


static func breath_for(state: State) -> Vector2:
	return BREATH[state]


## 叠加在头部骨骼上的俯仰与侧倾微调（弧度）。
static func head_offset_for(state: State) -> Vector2:
	return HEAD_OFFSET[state]


## 她现在有多模糊，0 到 1。
static func blur_for(state: State, temperature: int) -> float:
	var clarity := WARMTH_CLARITY[clampi(temperature, 0, WARMTH_CLARITY.size() - 1)]
	return clampf(BLUR[state] * (1.0 - clarity), 0.0, 1.0)


## 她现在抖得多厉害，0 到 1。
static func shiver_for(state: State, temperature: int) -> float:
	return SHIVER[state] * COLD_SHIVER[clampi(temperature, 0, COLD_SHIVER.size() - 1)]


## 人物或椅子在 from 处正面朝向 to 时的偏航角。模型的正面是 +Z。
static func yaw_towards(from: Vector3, to: Vector3) -> float:
	var dir := to - from
	return atan2(dir.x, dir.z)


## 椅子摆在 chair 处、正面朝着 fire 时，几个要用到的位置（地面高度都是 0）：
##   "seat"   她坐下前站的地方：椅子前方 SEAT_BACK 处，转身坐下骨盆正好落在坐面上
##   "put"    她抱着椅子放下时站的地方：椅子后方
##   "around" 放好椅子以后从侧面绕到前面经过的地方，在靠屋子中间的那一侧
##   "yaw"    椅子和坐着的她朝向的偏航角
static func seat_layout(chair: Vector3, fire: Vector3) -> Dictionary:
	var forward := Vector3(fire.x - chair.x, 0.0, fire.z - chair.z).normalized()
	var side := Vector3(forward.z, 0.0, -forward.x)
	if side.dot(-chair) < 0.0:
		side = -side
	return {
		"seat": chair + forward * SEAT_BACK,
		"put": chair - forward * PUT_BEHIND,
		"around": chair + side * WALK_AROUND,
		"yaw": atan2(forward.x, forward.z),
	}


## 从 from 沿状态机连线走到 to 要经过的状态（含两端）；走不到时返回空数组。
## 和 AnimationTree 的寻路一样取最短路径，测试用它确认每个阶段之间都能演过去。
static func path_between(from: StringName, to: StringName) -> Array[StringName]:
	var previous: Dictionary[StringName, StringName] = {from: &""}
	var queue: Array[StringName] = [from]
	while not queue.is_empty():
		var node: StringName = queue.pop_front()
		if node == to:
			var path: Array[StringName] = []
			var step := to
			while step != &"":
				path.push_front(step)
				step = previous[step]
			return path
		for link: Array in TRANSITIONS:
			var next: StringName = link[1]
			if link[0] == node and not previous.has(next):
				previous[next] = node
				queue.append(next)
	return []
