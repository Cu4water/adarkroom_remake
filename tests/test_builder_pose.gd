extends RefCounted
## 建造者从一团模糊人影到坐在火边添柴的人：等级与室温决定清晰度、发抖、呼吸，
## 动画状态机怎么演过去，以及她搬来的椅子摆在哪、她在哪坐下。

const STAGES: Array[int] = [
	BuilderSystem.Level.COLLAPSED, BuilderSystem.Level.SHIVERING,
	BuilderSystem.Level.SLEEPING, BuilderSystem.Level.HELPING,
]
const VISIBLE_STATES: Array[BuilderPose.State] = [
	BuilderPose.State.COLLAPSED, BuilderPose.State.SHIVERING,
	BuilderPose.State.SLEEPING, BuilderPose.State.HELPING,
]
const FIRE := Vector3(0.55, 0.0, -1.48)


func test_she_is_not_there_before_she_arrives(t: TestCase) -> void:
	t.eq(BuilderPose.state_for(BuilderSystem.Level.ABSENT), BuilderPose.State.HIDDEN, "还没来")
	t.eq(BuilderPose.state_for(BuilderSystem.Level.APPROACHING), BuilderPose.State.HIDDEN, "火光漏出去的时候还在外面")
	t.eq(BuilderPose.state_for(BuilderSystem.Level.COLLAPSED), BuilderPose.State.COLLAPSED, "进门倒在地上")
	t.eq(BuilderPose.state_for(BuilderSystem.Level.HELPING), BuilderPose.State.HELPING, "愿意帮忙")
	t.done()


func test_she_comes_into_focus_as_she_recovers(t: TestCase) -> void:
	for temperature: int in range(FireSystem.Temp.FREEZING, FireSystem.Temp.HOT + 1):
		var last := 2.0
		for level: int in STAGES:
			var blur := BuilderPose.blur_for(BuilderPose.state_for(level), temperature)
			t.ok(blur < last, "室温 %d、等级 %d 时没有比上一步更清楚" % [temperature, level])
			last = blur
	t.eq(BuilderPose.blur_for(BuilderPose.State.COLLAPSED, FireSystem.Temp.FREEZING), 1.0, "刚进门时是一团模糊人影")
	t.eq(BuilderPose.blur_for(BuilderPose.State.HELPING, FireSystem.Temp.WARM), 0.0, "愿意帮忙时是清楚的")
	t.done()


func test_warmth_sharpens_her_and_stills_her(t: TestCase) -> void:
	for state: BuilderPose.State in [BuilderPose.State.COLLAPSED, BuilderPose.State.SHIVERING]:
		t.ok(BuilderPose.blur_for(state, FireSystem.Temp.HOT) < BuilderPose.blur_for(state, FireSystem.Temp.FREEZING),
			"状态 %d：暖和了应该更清楚" % state)
		t.ok(BuilderPose.shiver_for(state, FireSystem.Temp.HOT) < BuilderPose.shiver_for(state, FireSystem.Temp.FREEZING),
			"状态 %d：暖和了应该抖得轻" % state)
	t.eq(BuilderPose.shiver_for(BuilderPose.State.HELPING, FireSystem.Temp.FREEZING), 0.0, "愿意帮忙以后平时不抖")
	t.done()


func test_she_lies_on_the_floor_then_sits_by_the_fire(t: TestCase) -> void:
	for state: BuilderPose.State in VISIBLE_STATES:
		var anim := BuilderPose.anim_for(state)
		t.ok(BuilderPose.ALL_ANIMS.has(anim), "状态 %d 映射了未登记动画 %s" % [state, anim])
		t.ok(BuilderPose.LOOP_ANIMS.has(anim), "常态动画 %s 应该是循环动画" % anim)
	t.eq(BuilderPose.anim_for(BuilderPose.State.COLLAPSED), BuilderPose.ANIM_LYING, "倒下后躺在地上")
	for state: BuilderPose.State in [BuilderPose.State.SHIVERING, BuilderPose.State.SLEEPING, BuilderPose.State.HELPING]:
		t.eq(BuilderPose.anim_for(state), BuilderPose.ANIM_SITTING, "状态 %d 坐在火边的椅子上" % state)
		t.ok(BuilderPose.has_chair(state), "状态 %d 时椅子已经搬到火边" % state)
	t.ok(not BuilderPose.has_chair(BuilderPose.State.COLLAPSED), "刚倒下时椅子还在墙边")
	t.ok(BuilderPose.breath_for(BuilderPose.State.SLEEPING).y < BuilderPose.breath_for(BuilderPose.State.COLLAPSED).y,
		"睡着时呼吸比刚倒下时慢")
	t.ok(BuilderPose.head_offset_for(BuilderPose.State.SLEEPING).y > BuilderPose.head_offset_for(
		BuilderPose.State.SHIVERING).y, "睡着时头歪向一边")
	t.done()


func test_state_machine_links_only_known_animations(t: TestCase) -> void:
	for link: Array in BuilderPose.TRANSITIONS:
		t.ok(BuilderPose.ALL_ANIMS.has(link[0]) and BuilderPose.ALL_ANIMS.has(link[1]),
			"连线 %s -> %s 用了未登记的动画" % [link[0], link[1]])
		t.ok(float(link[2]) >= 0.0 and float(link[2]) < 1.5, "连线 %s -> %s 的交叉淡入时间不合理" % [link[0], link[1]])
		if link[3]:
			t.ok(not BuilderPose.LOOP_ANIMS.has(link[0]), "循环动画 %s 永远播不完，不能用播完才走的连线" % link[0])
	for anim: StringName in BuilderPose.ALL_ANIMS:
		t.ok(not BuilderPose.path_between(BuilderPose.ANIM_IDLE_COLD, anim).is_empty(),
			"从门口抱臂站着走不到状态 %s" % anim)
	t.done()


func test_each_recovery_step_is_acted_out_through_its_transition(t: TestCase) -> void:
	var lying := BuilderPose.ANIM_LYING
	var sitting := BuilderPose.ANIM_SITTING
	t.eq(BuilderPose.path_between(BuilderPose.ANIM_STAGGER, lying),
		[BuilderPose.ANIM_STAGGER, BuilderPose.ANIM_COLLAPSE, lying] as Array[StringName], "踉跄进门后瘫倒在地")
	t.eq(BuilderPose.path_between(lying, BuilderPose.ANIM_IDLE_COLD),
		[lying, BuilderPose.ANIM_GET_UP, BuilderPose.ANIM_IDLE_COLD] as Array[StringName], "缓过一点，撑地站起来")
	t.eq(BuilderPose.path_between(BuilderPose.ANIM_IDLE_COLD, sitting),
		[BuilderPose.ANIM_IDLE_COLD, BuilderPose.ANIM_SIT_DOWN, sitting] as Array[StringName], "搬好椅子坐下")
	t.eq(BuilderPose.path_between(sitting, BuilderPose.ANIM_IDLE),
		[sitting, BuilderPose.ANIM_STAND_UP, BuilderPose.ANIM_IDLE] as Array[StringName], "从椅子上站起来")
	t.done()


func test_carrying_the_chair_and_stoking_run_without_teleporting(t: TestCase) -> void:
	var fetch: Array[StringName] = [
		BuilderPose.ANIM_IDLE_COLD, BuilderPose.ANIM_WALK, BuilderPose.ANIM_PICKUP, BuilderPose.ANIM_WALK_CARRY,
		BuilderPose.ANIM_PICKUP, BuilderPose.ANIM_WALK, BuilderPose.ANIM_SIT_DOWN,
	]
	var stoke: Array[StringName] = [
		BuilderPose.ANIM_STAND_UP, BuilderPose.ANIM_IDLE, BuilderPose.ANIM_WALK, BuilderPose.ANIM_PICKUP,
		BuilderPose.ANIM_WALK_CARRY, BuilderPose.ANIM_FEED, BuilderPose.ANIM_IDLE, BuilderPose.ANIM_SIT_DOWN,
	]
	for chain: Array[StringName] in [fetch, stoke]:
		for i: int in chain.size() - 1:
			t.eq(BuilderPose.path_between(chain[i], chain[i + 1]).size(), 2,
				"%s 应该能直接过渡到 %s" % [chain[i], chain[i + 1]])
	t.ok(BuilderPose.PICKUP_GRAB < BuilderPose.PICKUP_DONE and BuilderPose.PICKUP_DONE < 1.0, "先拿到再直起身")
	t.ok(BuilderPose.FEED_RELEASE < BuilderPose.FEED_DONE and BuilderPose.FEED_DONE < 1.0, "先松手再起身")
	t.done()


func test_the_chair_faces_the_fire_and_she_sits_onto_it(t: TestCase) -> void:
	var chair := Vector3(1.45, 0.0, -0.85)
	var layout := BuilderPose.seat_layout(chair, FIRE)
	var seat: Vector3 = layout["seat"]
	var yaw: float = layout["yaw"]
	var facing := Basis(Vector3.UP, yaw) * Vector3.BACK
	t.ok(facing.dot((FIRE - chair).normalized()) > 0.999, "椅子正面朝着火")
	t.ok(absf(seat.distance_to(chair) - BuilderPose.SEAT_BACK) < 0.001, "她站在椅子前面一个骨盆的距离")
	var pelvis := seat - facing * BuilderPose.SEAT_BACK
	t.ok(pelvis.distance_to(chair) < 0.001, "坐下后骨盆正好落在坐面正中")
	t.ok(seat.distance_to(FIRE) < chair.distance_to(FIRE), "她站在椅子和火之间")
	t.ok((layout["put"] as Vector3).distance_to(FIRE) > chair.distance_to(FIRE), "放椅子时她站在椅子后面")
	t.ok((layout["around"] as Vector3).length() < chair.length(), "绕到前面时走靠屋子中间那一侧")
	t.done()


func test_she_walks_around_the_hearth_not_through_it(t: TestCase) -> void:
	var seat := Vector3(1.2, 0.0, -1.02)
	var player := Vector3(-0.9, 0.0, -1.6)
	var route := BuilderPose.route_around(seat, player, FIRE, 0.7)
	t.ok(route.size() > 1, "火塘挡在中间，要先绕一下")
	t.eq(route[-1], player, "最后到要去的地方")
	for leg: int in route.size():
		var from: Vector3 = seat if leg == 0 else route[leg - 1]
		var hit := Geometry2D.segment_intersects_circle(Vector2(from.x, from.z), Vector2(route[leg].x, route[leg].z),
			Vector2(FIRE.x, FIRE.z), 0.6)
		t.ok(hit < 0.0, "第 %d 段穿过了火塘" % leg)
	var clear := BuilderPose.route_around(seat, Vector3(1.5, 0.0, 0.5), FIRE, 0.7)
	t.eq(clear.size(), 1, "火塘不挡路就直接走")
	t.done()


func test_she_stops_an_arm_length_away(t: TestCase) -> void:
	var stop := BuilderPose.stop_short(Vector3(1.0, 0.0, 0.0), Vector3(-2.0, 0.0, 0.0), 0.9)
	t.ok(stop.is_equal_approx(Vector3(-1.1, 0.0, 0.0)), "停在离主角 0.9 米的地方：%s" % stop)
	var near := BuilderPose.stop_short(Vector3(0.5, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), 0.9)
	t.ok(near.is_equal_approx(Vector3(0.5, 0.0, 0.0)), "本来就够近就不动")
	t.done()
