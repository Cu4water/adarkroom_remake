extends RefCounted
## 主角视角：看向某个东西时它落在准星上，鼠标往哪挪视线往哪转，对准能用的东西才亮，走动绕开障碍。

const EYE := Vector3(0.5, 1.15, 0.5)
const FIRE := Vector3(0.55, 0.32, -1.48)
const DOOR := Vector3(-1.12, 1.07, -2.42)


func test_looking_at_something_puts_it_under_the_crosshair(t: TestCase) -> void:
	for target: Vector3 in [FIRE, DOOR, Vector3(2.5, 2.0, 1.5), Vector3(-2.0, 0.1, 2.0)]:
		var view := Transform3D(PovView.basis(PovView.look_at(EYE, target)), EYE)
		var spot := OpeningView.project(view, target, 65.0, 16.0 / 9.0)
		t.ok(spot.length() < 0.001, "看向 %s 时它落在了屏幕 %s，不在准星上" % [target, spot])
	t.done()


func test_the_view_follows_the_mouse(t: TestCase) -> void:
	var look := PovView.look_at(EYE, FIRE)
	var view := Transform3D(PovView.basis(look), EYE)
	var right := PovView.turn(look, Vector2(40.0, 0.0), 0.002)
	var fire_after := OpeningView.project(Transform3D(PovView.basis(right), EYE), FIRE, 65.0, 16.0 / 9.0)
	t.ok(fire_after.x < OpeningView.project(view, FIRE, 65.0, 16.0 / 9.0).x, "鼠标往右，视线往右，火往屏幕左边走")
	var up := PovView.turn(look, Vector2(0.0, -40.0), 0.002)
	t.ok(up.y > look.y, "鼠标往上，抬头")
	t.done()


func test_the_head_does_not_turn_past_the_limits(t: TestCase) -> void:
	var look := Vector2.ZERO
	for i: int in 100:
		look = PovView.turn(look, Vector2(500.0, -500.0), 0.002)
	t.ok(look.y <= PovView.PITCH_LIMIT + 1e-5, "一直往上挪也不会仰过头：%.3f" % look.y)
	t.ok(absf(look.x) <= PI + 1e-5, "左右可以一直转，角度绕回来：%.3f" % look.x)
	for i: int in 100:
		look = PovView.turn(look, Vector2(0.0, 500.0), 0.002)
	t.ok(look.y >= -PovView.PITCH_LIMIT - 1e-5, "一直往下挪也不会低过头：%.3f" % look.y)
	t.done()


func test_turning_towards_something_eases_and_takes_the_short_way(t: TestCase) -> void:
	var from := Vector2(3.0, 0.2)
	var to := Vector2(-3.0, -0.4)
	t.eq(PovView.blend(from, to, 0.0), from, "还没开始转时就是原来的朝向")
	t.ok(PovView.blend(from, to, 1.0).distance_to(to) < 1e-5, "转完正好对上")
	var half := PovView.blend(from, to, 0.5)
	t.ok(absf(absf(half.x) - PI) < 0.01, "左右走近的那一边，从背后绕过去：%.3f" % half.x)
	t.ok(is_equal_approx(half.y, -0.1), "上下走一半")
	var early := PovView.blend(from, to, 0.1)
	t.ok(absf(early.y - from.y) < 0.1 * absf(to.y - from.y), "起步慢")
	t.done()


func test_only_usable_things_under_the_crosshair_glow(t: TestCase) -> void:
	t.eq(PovView.glow(false, true, 0.6), 0.0, "用不了的东西对准了也不亮")
	t.eq(PovView.glow(true, false, 0.6), 0.0, "用得了但没对准的东西也不亮")
	t.eq(PovView.glow(true, true, 0.6), 0.6, "对准用得了的东西时才亮")
	t.done()


func test_walking_follows_the_gaze_but_stays_level(t: TestCase) -> void:
	var none: Array[Vector3] = []
	var room := Rect2(-2.5, -2.0, 5.0, 4.0)
	var start := Vector3(0.0, 1.5, 1.0)
	var ahead := PovView.walk(start, Vector2(0.0, -1.0), 0.0, 0.5, none, room)
	t.ok(ahead.distance_to(Vector3(0.0, 1.5, 0.5)) < 0.001, "看着 -Z 往前走就是往 -Z 走：%s" % ahead)
	var look := PovView.look_at(start, Vector3(2.0, 0.0, 1.0))
	var sideways := PovView.walk(start, Vector2(0.0, -1.0), look.x, 0.5, none, room)
	t.ok(sideways.distance_to(Vector3(0.5, 1.5, 1.0)) < 0.001, "低头看着右边往前走，平着往右走：%s" % sideways)
	var strafe := PovView.walk(start, Vector2(1.0, 0.0), 0.0, 0.5, none, room)
	t.ok(strafe.x > 0.49, "按右就往右横着走")
	var diagonal := PovView.walk(start, Vector2(1.0, -1.0), 0.0, 0.5, none, room)
	t.ok(absf(diagonal.distance_to(start) - 0.5) < 0.001, "斜着走不会更快")
	t.done()


func test_walking_slides_around_obstacles_and_stops_at_the_walls(t: TestCase) -> void:
	var hearth: Array[Vector3] = [Vector3(0.0, -1.0, 0.8)]
	var room := Rect2(-2.5, -2.0, 5.0, 4.0)
	var spot := Vector3(0.05, 1.5, 1.0)
	for i: int in 90:
		spot = PovView.walk(spot, Vector2(0.0, -1.0), 0.0, 0.05, hearth, room)
	t.ok(Vector2(spot.x, spot.z).distance_to(Vector2(0.0, -1.0)) >= 0.8 - 0.001, "不会走进火塘：%s" % spot)
	t.ok(absf(spot.x) > 0.3, "顶着火塘往前走会沿着边滑开：%s" % spot)
	for i: int in 200:
		spot = PovView.walk(spot, Vector2(-1.0, 1.0), 0.0, 0.05, hearth, room)
	t.ok(is_equal_approx(spot.x, -2.5) and is_equal_approx(spot.z, 2.0), "走到墙角就停住：%s" % spot)
	t.eq(spot.y, 1.5, "走动不改眼睛高度")
	t.done()
