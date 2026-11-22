extends RefCounted
## 小屋模型和代码之间的约定。在 Blender 里改了名字或加了材质，这里会先报出来。

const HUT := "res://assets/hut/hut.glb"


func test_hut_has_the_nodes_the_room_looks_for(t: TestCase) -> void:
	var hut := _load_hut()
	t.ok(hut.find_child("Door", true, false) is Node3D, "找不到门（Door）")
	t.ok(hut.find_child("Hut", true, false) is MeshInstance3D, "找不到屋体（Hut）")
	t.ok(hut.find_child("Embers", true, false) is MeshInstance3D, "找不到余烬（Embers）")
	t.ok(hut.find_children("Flame_*", "MeshInstance3D", true, false).size() >= 2, "火焰（Flame_*）少于两片")
	var firewood := hut.find_children("Firewood_*", "MeshInstance3D", true, false).size()
	t.ok(firewood >= Tuning.new().initial_wood, "柴堆只有 %d 根，摆不下开局的木头" % firewood)
	t.eq(WoodpileView.THRESHOLDS.size(), firewood, "柴堆门槛的个数要和柴堆里柴的根数一样")
	var hearth := hut.find_child("Hearth", true, false) as MeshInstance3D
	t.ok(hearth != null and hearth.get_aabb().end.y < 1.0, "火塘是开放的，不应该有吊在半空的烟罩和烟道")
	hut.free()
	t.done()


func test_every_material_in_the_hut_is_known(t: TestCase) -> void:
	var hut := _load_hut()
	var materials := HutMaterials.new()
	var seen := 0
	for node: Node in hut.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node
		for surface: int in instance.mesh.get_surface_count():
			var material := instance.mesh.surface_get_material(surface)
			t.ok(material != null, "%s 的第 %d 个表面没有材质" % [instance.name, surface])
			if material != null:
				seen += 1
				t.ok(materials.knows(material.resource_name),
					"%s 用了 HutMaterials 不认识的材质 %s" % [instance.name, material.resource_name])
	t.ok(seen > 0, "模型里一个材质都没有")
	hut.free()
	t.done()


func _load_hut() -> Node:
	var scene: PackedScene = load(HUT)
	return scene.instantiate()
