extends RefCounted
## 木椅的素材契约。建造者坐下的动画按这把椅子的尺寸摆位置，Blender 里改了尺寸或节点名这里会先报出来。

const CHAIR := "res://assets/chair/chair.glb"


func test_chair_is_one_node_standing_on_the_floor(t: TestCase) -> void:
	var root := (load(CHAIR) as PackedScene).instantiate()
	var chair := root.find_child("Chair", true, false) as MeshInstance3D
	t.ok(chair != null, "找不到 Chair 节点")
	if chair != null:
		var box := chair.get_aabb()
		t.ok(absf(box.position.y) < 0.02, "椅腿底 Y=%.3f 应贴着地板" % box.position.y)
		t.ok(box.size.y > 0.85 and box.size.y < 0.95, "靠背顶高 %.2f 米，应在 0.9 米附近" % box.size.y)
		var center := box.get_center()
		t.ok(absf(center.x) < 0.03, "原点应在坐面正中，左右偏了 %.3f" % center.x)
		t.ok(box.end.z < 0.25 and box.position.z < -0.2, "靠背应在 -Z 一侧")
		var materials := HutMaterials.new()
		for surface: int in chair.mesh.get_surface_count():
			var material := chair.mesh.surface_get_material(surface)
			t.ok(material != null and materials.knows(material.resource_name),
				"椅子用了游戏里不认识的材质 %s" % (material.resource_name if material != null else "<null>"))
	root.free()
	t.done()
