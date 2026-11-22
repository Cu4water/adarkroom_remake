extends RefCounted
## 开场相机：点哪里，火就在哪里。

const FIRE := Vector3(0.55, 0.32, -1.48)
const HOME := Vector3(0.06, 1.25, 2.1)
const REACH := Vector2(1.9, 0.5)
const FOV := 57.4

## 屏幕上的几个点：正中、四个角附近、还有几个随便的位置。
const SPOTS: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(-0.9, 0.9), Vector2(0.9, 0.9), Vector2(-0.9, -0.9), Vector2(0.9, -0.9),
	Vector2(0.25, -0.35), Vector2(-0.6, 0.1), Vector2(0.4, 0.7), Vector2(0.0, -0.85),
]
const ASPECTS: Array[float] = [16.0 / 9.0, 4.0 / 3.0, 21.0 / 9.0, 9.0 / 16.0]


func test_fire_lands_where_the_player_clicked(t: TestCase) -> void:
	for aspect: float in ASPECTS:
		for spot: Vector2 in SPOTS:
			var view := OpeningView.solve(spot, FIRE, HOME, REACH, FOV, aspect)
			var landed := OpeningView.project(view, FIRE, FOV, aspect)
			t.ok(landed.distance_to(spot) < 0.0005, "宽高比 %.2f 点 %s，火落在了 %s" % [aspect, spot, landed])
	t.done()


func test_turning_only_the_head_puts_the_fire_under_the_click(t: TestCase) -> void:
	var eye := Vector3(-0.9, 1.15, 0.3)
	for aspect: float in ASPECTS:
		for spot: Vector2 in SPOTS:
			var look := OpeningView.look_for(spot, eye, FIRE, FOV, aspect)
			var landed := OpeningView.project(Transform3D(PovView.basis(look), eye), FIRE, FOV, aspect)
			t.ok(landed.distance_to(spot) < 0.0005, "宽高比 %.2f 点 %s，火落在了 %s" % [aspect, spot, landed])
	t.ok(OpeningView.look_for(Vector2.ZERO, eye, FIRE, FOV, 16.0 / 9.0).distance_to(PovView.look_at(eye, FIRE)) < 1e-4,
		"点正中间和直接看着火是同一个朝向")
	t.eq(OpeningView.to_ndc(Vector2(0.0, 0.0), Vector2(1920.0, 1080.0)), Vector2(-1.0, 1.0), "左上角")
	t.eq(OpeningView.to_ndc(Vector2(960.0, 540.0), Vector2(1920.0, 1080.0)), Vector2.ZERO, "正中间")
	t.done()


func test_camera_never_tilts_its_head(t: TestCase) -> void:
	for spot: Vector2 in SPOTS:
		var view := OpeningView.solve(spot, FIRE, HOME, REACH, FOV, 16.0 / 9.0)
		t.ok(absf(view.basis.x.y) < 0.0001, "点 %s 时相机歪了" % spot)
		t.ok(view.basis.y.y > 0.0, "点 %s 时相机倒过来了" % spot)
		t.ok(view.basis.is_equal_approx(view.basis.orthonormalized()), "点 %s 时相机的朝向不是纯旋转" % spot)
	t.done()


func test_camera_stays_inside_the_room(t: TestCase) -> void:
	# 屋子内侧：x 在 ±2.78 之间，前墙在 z = 2.38，地板到天花板是 0 到 2.85。
	for spot: Vector2 in [Vector2(-1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0), Vector2(1.0, -1.0)]:
		var eye := OpeningView.solve(spot, FIRE, HOME, REACH, FOV, 16.0 / 9.0).origin
		t.ok(absf(eye.x) < 2.4, "点 %s 时相机贴到侧墙了: %s" % [spot, eye])
		t.ok(eye.y > 0.5 and eye.y < 2.3, "点 %s 时相机高度不对: %s" % [spot, eye])
		t.ok(eye.z < 2.3, "点 %s 时相机进了前墙: %s" % [spot, eye])
	t.done()


func test_clicks_at_the_very_edge_keep_the_fire_on_screen(t: TestCase) -> void:
	var view := OpeningView.solve(Vector2(1.0, -1.0), FIRE, HOME, REACH, FOV, 16.0 / 9.0)
	var landed := OpeningView.project(view, FIRE, FOV, 16.0 / 9.0)
	t.ok(landed.distance_to(Vector2(OpeningView.EDGE, -OpeningView.EDGE)) < 0.0005, "点在屏幕角上时火落在了 %s" % landed)
	t.done()


func test_points_behind_the_camera_do_not_project(t: TestCase) -> void:
	var view := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	t.eq(OpeningView.project(view, Vector3(0.0, 0.0, 3.0), FOV, 1.0), Vector2.INF, "相机背后的点")
	t.ok(OpeningView.project(view, Vector3(0.0, 0.0, -3.0), FOV, 1.0).length() < 0.0001, "正前方的点应该在屏幕中心")
	t.done()


func test_level_table_blends_between_levels(t: TestCase) -> void:
	var table: Array[float] = [0.0, 10.0, 30.0]
	t.eq(LevelTable.sample(table, 0.0), 0.0, "第 0 级")
	t.eq(LevelTable.sample(table, 1.5), 20.0, "第 1 级和第 2 级中间")
	t.eq(LevelTable.sample(table, 2.0), 30.0, "最后一级")
	t.eq(LevelTable.sample(table, 9.0), 30.0, "超出范围时停在最后一级")
	t.eq(LevelTable.sample(table, -1.0), 0.0, "低于范围时停在第一级")
	t.done()
