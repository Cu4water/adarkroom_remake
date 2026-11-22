extends RefCounted
## 窗玻璃的倒影：倒影相机从玻璃另一侧正对着看，视锥正好框住玻璃，玻璃上每一点取到的就是从那里反射看到的东西。

const BOX := AABB(Vector3(-2.843, 0.92, -1.21), Vector3(0.008, 1.42, 2.32))
const SEAT := Vector3(-0.9, 1.15, 0.3)


func test_the_glass_faces_into_the_room(t: TestCase) -> void:
	var frame := WindowReflection.frame_for(BOX, Vector3.ZERO)
	t.ok(frame.basis.z.is_equal_approx(Vector3.RIGHT), "法线朝屋里：%s" % frame.basis.z)
	t.ok(frame.basis.y.is_equal_approx(Vector3.UP), "矩形的 y 朝上：%s" % frame.basis.y)
	t.ok(WindowReflection.size_for(BOX, frame).is_equal_approx(Vector2(2.32, 1.42)), "宽 2.32 米、高 1.42 米")
	t.done()


func test_the_mirror_camera_sits_outside_and_clips_at_the_glass(t: TestCase) -> void:
	var frame := WindowReflection.frame_for(BOX, Vector3.ZERO)
	var view := WindowReflection.mirror_view(frame, SEAT)
	var camera: Transform3D = view["transform"]
	var outside := frame.affine_inverse() * camera.origin
	t.ok(outside.z < 0.0, "倒影相机在窗外：%s" % outside)
	t.ok(is_equal_approx(view["near"], -outside.z), "近裁剪面正好落在玻璃上")
	t.ok((-camera.basis.z).is_equal_approx(frame.basis.z), "倒影相机正对着玻璃往屋里看")
	t.done()


func test_glass_corners_fill_the_reflection_image(t: TestCase) -> void:
	var frame := WindowReflection.frame_for(BOX, Vector3.ZERO)
	var size := WindowReflection.size_for(BOX, frame)
	for corner: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
		var point := frame * Vector3(corner.x * size.x, corner.y * size.y, 0.0)
		var seen := _seen_at(frame, size, SEAT, point)
		t.ok(seen.is_equal_approx(WindowReflection.glass_uv(frame, size, point)),
			"玻璃的角 %s 落在倒影图的 %s，玻璃取的是 %s" % [corner, seen, WindowReflection.glass_uv(frame, size, point)])
	t.done()


func test_each_spot_on_the_glass_shows_what_it_reflects(t: TestCase) -> void:
	var frame := WindowReflection.frame_for(BOX, Vector3.ZERO)
	var size := WindowReflection.size_for(BOX, frame)
	var normal := frame.basis.z
	for eye: Vector3 in [SEAT, Vector3(-1.8, 1.55, -0.6), Vector3(0.5, 1.55, 1.2)]:
		for thing: Vector3 in [Vector3(0.55, 0.5, -1.48), Vector3(1.5, 2.2, 1.0), Vector3(-0.5, 0.3, -1.95)]:
			# 屋里的东西沿玻璃翻到窗外，眼睛看向它的那条线穿过玻璃的地方，就是它在玻璃上出现的位置。
			var image := thing - 2.0 * (thing - frame.origin).dot(normal) * normal
			var plane := Plane(normal, frame.origin)
			var spot: Vector3 = plane.intersects_segment(eye, image)
			var expected := _seen_at(frame, size, eye, thing)
			var got := WindowReflection.glass_uv(frame, size, spot)
			t.ok(got.distance_to(expected) < 0.001, "从 %s 看 %s：玻璃取 %s，倒影图里在 %s" % [eye, thing, got, expected])
	t.done()


## 倒影相机拍到的图里，point 落在哪（0 到 1，左上角是原点）。照 Camera3D 视锥模式、保持高度的算法。
func _seen_at(frame: Transform3D, size: Vector2, eye: Vector3, point: Vector3) -> Vector2:
	var view := WindowReflection.mirror_view(frame, eye)
	var camera: Transform3D = view["transform"]
	var projection := Projection.create_frustum_aspect(size.y, size.x / size.y, view["offset"], view["near"],
		WindowReflection.FAR)
	var local := camera.affine_inverse() * point
	var clip := projection * Vector4(local.x, local.y, local.z, 1.0)
	return Vector2(clip.x / clip.w * 0.5 + 0.5, 0.5 - clip.y / clip.w * 0.5)
