extends RefCounted
## 3D 建造者模型、骨骼动画和材质的素材契约。在 Blender 里改了节点、骨骼、动画或材质，这里会先报出来。

const BUILDER := "res://assets/builder/builder.glb"
const CORE_BONES: Array[String] = [
	"root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head",
	"clavicle_l", "upperarm_l", "lowerarm_l", "hand_l",
	"clavicle_r", "upperarm_r", "lowerarm_r", "hand_r",
	"thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r",
]
const PARTS: Array[String] = [
	"Builder_Head", "Builder_Hair", "Builder_Hands", "Builder_Gloves",
	"Builder_Shirt", "Builder_Trousers", "Builder_Boots",
	"Builder_WorkApron", "Builder_Cloak", "Builder_BeltAndTools", "Builder_HeldLog",
]


func test_builder_has_the_humanoid_skeleton_and_origin(t: TestCase) -> void:
	var builder := _load()
	var skeleton := builder.find_child("Skeleton3D", true, false) as Skeleton3D
	t.ok(skeleton != null, "找不到骨架（Skeleton3D）")
	if skeleton != null:
		for bone: String in CORE_BONES:
			t.ok(skeleton.find_bone(bone) != -1, "找不到骨骼 %s" % bone)
		var root_rest := skeleton.get_bone_global_rest(skeleton.find_bone("root")).origin
		t.ok(root_rest.is_zero_approx(), "脚底 root 不在原点，导出时骨架位置不对")
	builder.free()
	t.done()


func test_builder_has_all_cc0_animations(t: TestCase) -> void:
	var builder := _load()
	var player := builder.find_child("AnimationPlayer", true, false) as AnimationPlayer
	t.ok(player != null, "找不到动画播放器（AnimationPlayer）")
	if player != null:
		for anim_name: StringName in BuilderPose.ALL_ANIMS:
			t.ok(player.has_animation(anim_name), "缺少建造者骨骼动画: %s" % anim_name)
			if player.has_animation(anim_name):
				var anim := player.get_animation(anim_name)
				t.ok(anim.length > 0.1 and anim.get_track_count() > 20,
					"动画 %s 轨道不完整（长度 %.2f，轨道 %d）" % [anim_name, anim.length, anim.get_track_count()])
	builder.free()
	t.done()


func test_builder_meshes_scale_and_materials_match_contract(t: TestCase) -> void:
	var builder := _load()
	var materials := BuilderMaterials.new()
	var total := AABB()
	var first := true
	for part_name: String in PARTS:
		var part := builder.find_child(part_name, true, false) as MeshInstance3D
		t.ok(part != null, "找不到建造者部件 %s" % part_name)
		if part == null:
			continue
		for surface: int in part.mesh.get_surface_count():
			var mat := part.mesh.surface_get_material(surface)
			t.ok(mat != null and materials.knows(mat.resource_name),
				"部件 %s 使用了未知材质 %s" % [part_name, mat.resource_name if mat != null else "<null>"])
		if part_name != "Builder_HeldLog":
			total = part.get_aabb() if first else total.merge(part.get_aabb())
			first = false
	t.ok(absf(total.position.y) < 0.02, "脚底 Y=%.3f 应贴近地板 0" % total.position.y)
	t.ok(total.size.y > 1.62 and total.size.y < 1.75,
		"建造者含兜帽身高 %.2f 米，应在 1.66 米规范附近" % total.size.y)
	builder.free()
	t.done()


func _load() -> Node:
	var scene: PackedScene = load(BUILDER)
	return scene.instantiate()
