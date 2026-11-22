class_name BuilderRig
extends RefCounted
## 建造者的骨架和动画状态机：按 BuilderPose.TRANSITIONS 搭 AnimationTree，手动推进，
## 再在骨骼动画之上叠加程序化的冷颤、呼吸、低头歪头和摇头。
##
## 只管"身体怎么动"，不管"她要去哪、做什么"，那是 BuilderFigure 的事。

var skeleton: Skeleton3D
var anim: AnimationPlayer

var _tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var _goal: StringName = &""
var _bones: Dictionary[StringName, int] = {}
var _rest_basis: Dictionary[int, Basis] = {}


## 找到 root 下面 builder.glb 的骨架和动画播放器，把动画状态机搭起来。
func setup(root: Node) -> void:
	skeleton = root.find_child("Skeleton3D", true, false) as Skeleton3D
	anim = root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if skeleton != null:
		for bone: int in skeleton.get_bone_count():
			_bones[StringName(skeleton.get_bone_name(bone))] = bone
			_rest_basis[bone] = skeleton.get_bone_global_rest(bone).basis
	if anim != null:
		for anim_name: StringName in BuilderPose.ALL_ANIMS:
			if anim.has_animation(anim_name):
				var looped := BuilderPose.LOOP_ANIMS.has(anim_name)
				anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
		_build_tree()


## 让状态机寻路去某个状态。同一个目标只发一次，免得每帧重置寻路。
func go(anim_name: StringName) -> void:
	if _playback == null or anim_name == _goal:
		return
	_goal = anim_name
	_playback.travel(anim_name)


## 不演过渡，直接切到某个状态。
func jump_to(anim_name: StringName) -> void:
	if _playback == null:
		return
	_goal = anim_name
	_playback.start(anim_name)
	_tree.advance(0.0)


## 状态机已经停在这个状态，没有还没走完的过渡。
func reached(anim_name: StringName) -> bool:
	return _playback == null or (_playback.get_current_node() == anim_name and _playback.get_travel_path().is_empty())


func current() -> StringName:
	return _playback.get_current_node() if _playback != null else &""


## 一段动画的 fraction 处是第几秒。
func seconds(anim_name: StringName, fraction: float) -> float:
	if anim == null or not anim.has_animation(anim_name):
		return 0.5
	return anim.get_animation(anim_name).length * fraction


func advance(delta: float) -> void:
	if _tree != null:
		_tree.advance(delta)


## 叠加在骨骼动画之上：tremble 是这一帧的冷颤，breath 是胸口起伏（弧度），
## head 是低头与歪头（弧度），shake 是摇头的偏航（弧度）。必须在 advance 之后调用。
func overlay(tremble: float, breath: float, head: Vector2, shake: float) -> void:
	if skeleton == null:
		return
	if absf(tremble) > 0.001 or absf(breath) > 0.0005:
		_add_rotation(&"spine_02", Quaternion(Vector3.FORWARD, tremble * 0.032) * Quaternion(Vector3.RIGHT, breath))
		_add_rotation(&"spine_03", Quaternion(Vector3.RIGHT, -breath * 0.6))
		_add_rotation(&"clavicle_l", Quaternion(Vector3.RIGHT, tremble * 0.028))
		_add_rotation(&"clavicle_r", Quaternion(Vector3.RIGHT, -tremble * 0.028))
	if head.length_squared() > 0.0001 or absf(tremble) > 0.001 or absf(shake) > 0.001:
		_add_rotation(&"Head", Quaternion(Vector3.UP, shake) * Quaternion(Vector3.RIGHT, head.x)
			* Quaternion(Vector3.FORWARD, head.y + tremble * 0.045))


## 头部骨骼现在在世界里的位置。没有骨架时返回 fallback。
func head_position(fallback: Vector3) -> Vector3:
	if skeleton == null or not _bones.has(&"Head"):
		return fallback
	return skeleton.global_transform * skeleton.get_bone_global_pose(_bones[&"Head"]).origin


func _build_tree() -> void:
	var machine := AnimationNodeStateMachine.new()
	for i: int in BuilderPose.ALL_ANIMS.size():
		var anim_name := BuilderPose.ALL_ANIMS[i]
		var node := AnimationNodeAnimation.new()
		node.animation = anim_name
		machine.add_node(anim_name, node, Vector2(i % 5, floori(i / 5.0)) * Vector2(220.0, 140.0))
	for link: Array in BuilderPose.TRANSITIONS:
		var transition := AnimationNodeStateMachineTransition.new()
		transition.xfade_time = link[2]
		if link[3]:
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
			transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
		machine.add_transition(link[0], link[1], transition)
	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	_tree.tree_root = machine
	# 手动推进，保证程序化的发抖、呼吸、歪头永远叠在骨骼动画之后。
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim.get_parent().add_child(_tree)
	_tree.anim_player = _tree.get_path_to(anim)
	_tree.active = true
	_playback = _tree.get("parameters/playback") as AnimationNodeStateMachinePlayback


## 在当前动画姿势之上，绕骨架空间轴叠加一个增量旋转。
func _add_rotation(bone_name: StringName, delta_in_skeleton: Quaternion) -> void:
	if not _bones.has(bone_name):
		return
	var bone := _bones[bone_name]
	var frame := _rest_basis[bone]
	var local := (frame.inverse() * Basis(delta_in_skeleton) * frame).get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * local)
