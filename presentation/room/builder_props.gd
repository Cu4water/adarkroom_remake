class_name BuilderProps
extends RefCounted
## 建造者会拿在手上的东西：她搬的那把椅子，她递给主角的那块板子，添柴时手上那根柴。
##
## 只管这些东西摆在哪。椅子放着时在固定的位置；拿在手上时跟着她两手正中走，手怎么晃它就怎么晃；
## 拿起和放下的那几秒里，椅子在"地上的位置"和"手里的位置"之间过渡，跟着她弯腰、直起身一起动，
## 不会一下子跳进手里。

enum ChairAt { HOME, CARRIED, BY_FIRE }

var chair_at := ChairAt.HOME
## 椅子离地有多"进手"：0 是还在地上（或已经放到要放的地方），1 是完全抱在手里。
var lift := 0.0

var _chair: Node3D
var _board: Node3D
var _log: Node3D
var _home := Transform3D.IDENTITY
var _by_fire := Transform3D.IDENTITY
## 拿起之前、或者放下之后，椅子在地上的样子。
var _floor := Transform3D.IDENTITY


## home 是椅子一开始靠墙放的样子，by_fire 是搬到火边以后的样子。
func setup(home: Transform3D, by_fire: Transform3D) -> void:
	_home = home
	_by_fire = by_fire


func bind_chair(chair: Node3D) -> void:
	_chair = chair
	place_chair(chair_at)


## 直接把椅子放到某处。CARRIED 表示从现在的位置开始拿起（lift 归零，由 lift 慢慢抬进手里）。
func place_chair(at: ChairAt) -> void:
	chair_at = at
	match at:
		ChairAt.HOME:
			_floor = _home
			lift = 0.0
		ChairAt.BY_FIRE:
			_floor = _by_fire
			lift = 0.0
		ChairAt.CARRIED:
			_floor = _chair.global_transform if _chair != null else _home
	if _chair != null and at != ChairAt.CARRIED:
		_chair.global_transform = _floor


## 抱着椅子走到了放的地方：接下来 lift 降到 0 时，椅子落在 at 的位置。
func aim_chair(at: ChairAt) -> void:
	_floor = _by_fire if at == ChairAt.BY_FIRE else _home


## 她模型里手上那根柴（添柴时才露出来）。
func bind_log(log: Node3D) -> void:
	_log = log
	show_log(false)


func show_log(shown: bool) -> void:
	if _log != null:
		_log.visible = shown


## 手上什么都不拿：柴和板子都收起来。
func empty_hands(parent: Node3D) -> void:
	show_log(false)
	show_board(parent, false)


## 递板子时手上的那块板子。第一次用时做出来，挂在 parent 下面。
func show_board(parent: Node3D, shown: bool) -> void:
	if _board == null and shown:
		_board = _make_board()
		parent.add_child(_board)
		_board.top_level = true
	if _board != null:
		_board.visible = shown


## 每帧调用：body 是她现在的全局变换，hands 是两手正中的全局位置。
func follow(body: Transform3D, hands: Vector3) -> void:
	var facing := body.basis.orthonormalized()
	if _chair != null and chair_at == ChairAt.CARRIED:
		var held := Transform3D(facing * BuilderPose.CARRY.basis, hands + facing * BuilderPose.CARRY.origin)
		var weight := smoothstep(0.0, 1.0, lift)
		# 离地时先往上抬、后往怀里收，落地时反过来：她还弯着腰的时候椅子不往她身上贴。
		var rise := smoothstep(0.0, 0.7, lift)
		var reach := smoothstep(0.3, 1.0, lift)
		var origin := _floor.origin.lerp(held.origin, reach)
		origin.y = lerpf(_floor.origin.y, held.origin.y, rise)
		_chair.global_transform = Transform3D(
			Basis(_floor.basis.get_rotation_quaternion().slerp(held.basis.get_rotation_quaternion(), weight)), origin)
	if _board != null and _board.visible:
		_board.global_transform = Transform3D(facing * BuilderPose.OFFER.basis, hands + facing * BuilderPose.OFFER.origin)


func chair_position(fallback: Vector3) -> Vector3:
	return _chair.global_position if _chair != null else fallback


## 一块木夹板：木板、夹在上面的纸、顶上的铁夹子。被火照亮，和屋里的东西一样。
func _make_board() -> Node3D:
	var root := Node3D.new()
	root.name = "OfferedBoard"
	root.add_child(_box(Vector3(0.24, 0.32, 0.012), Vector3.ZERO, Color(0.36, 0.24, 0.15)))
	root.add_child(_box(Vector3(0.21, 0.27, 0.002), Vector3(0.0, -0.01, 0.007), Color(0.8, 0.74, 0.6)))
	root.add_child(_box(Vector3(0.09, 0.035, 0.016), Vector3(0.0, 0.14, 0.01), Color(0.22, 0.21, 0.2), 0.6))
	return root


func _box(box_size: Vector3, at: Vector3, color: Color, metallic := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	material.metallic = metallic
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	return instance
