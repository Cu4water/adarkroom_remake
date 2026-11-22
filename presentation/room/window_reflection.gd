class_name WindowReflection
extends Node3D
## 夜里的窗玻璃像一面暗镜子：屋里亮起来，玻璃上就映出火、屋梁、建造者。
## 第二章天亮以后外面比屋里亮，倒影就看不见了，那时候调 fade_to(0.0, 秒数)。
##
## 做法是平面倒影的"视锥模式"，算法移植自 V-Sekai/godot_planar_reflection 的 mirror.gd
## （https://github.com/V-Sekai/godot_planar_reflection，MIT 许可，
## Copyright (c) 2023-present V-Sekai Contributors; Copyright (c) 2022 Lyuma and SaracenOne;
## Copyright (c) 2022 Simon Flores；最早出自 cheece/godot-vr-mirror-test-g4）：
## 把玩家的眼睛沿玻璃翻到窗外，让一台相机从那里正对着玻璃往屋里看，近裁剪面正好落在玻璃上，
## 视锥用 frustum offset 框住玻璃这个矩形。这样窗户那面墙和窗外的东西都在近裁剪面后面，
## 自动不进倒影；渲染出来的图正好铺满玻璃，玻璃按自己在矩形里的位置去取就行。

const GLASS_SHADER := preload("res://presentation/room/shaders/window_glass.gdshader")
## 玻璃自己放在这一层，倒影相机不拍它。
const GLASS_LAYER := 1 << 19
const FAR := 30.0

## 倒影的分辨率是屏幕高度的几分之几，按画质档取。倒影本来就淡，不需要全分辨率。
const RESOLUTION: Array[float] = [0.25, 0.35, 0.5]

## 倒影有多强，0 到 1。
var strength := 1.0

var _glass: MeshInstance3D
var _material: ShaderMaterial
var _viewport: SubViewport
var _camera: Camera3D
var _notifier: VisibleOnScreenNotifier3D
## 玻璃矩形：原点在中心，x 朝右，y 朝上，z 是法线、朝屋里。
var _frame := Transform3D.IDENTITY
var _size := Vector2.ONE
var _tween: Tween


## glass 是窗玻璃的网格，inside 是屋里随便一点，用来分清玻璃哪面朝屋里。
func bind(glass: MeshInstance3D, inside: Vector3) -> void:
	_glass = glass
	var box := glass.global_transform * glass.get_aabb()
	_frame = frame_for(box, inside)
	_size = size_for(box, _frame)
	_glass.layers = GLASS_LAYER

	_viewport = SubViewport.new()
	_viewport.use_hdr_2d = true
	_viewport.positional_shadow_atlas_size = 2048
	_viewport.set_positional_shadow_atlas_quadrant_subdiv(0, Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1)
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.cull_mask = ~GLASS_LAYER & 0xFFFFF
	_camera.environment = _environment()
	_camera.projection = Camera3D.PROJECTION_FRUSTUM
	_viewport.add_child(_camera)

	_material = ShaderMaterial.new()
	_material.shader = GLASS_SHADER
	_material.set_shader_parameter(&"reflection", _viewport.get_texture())
	_material.set_shader_parameter(&"mirror_origin", _frame.origin)
	_material.set_shader_parameter(&"mirror_right", _frame.basis.x)
	_material.set_shader_parameter(&"mirror_up", _frame.basis.y)
	_material.set_shader_parameter(&"mirror_size", _size)
	for surface: int in _glass.mesh.get_surface_count():
		_glass.set_surface_override_material(surface, _material)

	_notifier = VisibleOnScreenNotifier3D.new()
	_notifier.aabb = glass.get_aabb()
	_glass.add_child(_notifier)
	RenderingServer.frame_pre_draw.connect(_update)


## 倒影在 seconds 秒内变到 target 的强度。
func fade_to(target: float, seconds: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, ^"strength", clampf(target, 0.0, 1.0), seconds)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_update):
		RenderingServer.frame_pre_draw.disconnect(_update)


## 主相机在 _process 里动完以后、这一帧开画之前，把倒影相机摆好。
func _update() -> void:
	var eye_camera := get_viewport().get_camera_3d()
	_material.set_shader_parameter(&"strength", strength)
	var eye := eye_camera.global_position if eye_camera != null else _frame.origin
	var wanted := strength > 0.001 and _notifier.is_on_screen() and (_frame.affine_inverse() * eye).z > 0.01
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if wanted else SubViewport.UPDATE_DISABLED
	if not wanted:
		return
	var height := get_viewport().get_visible_rect().size.y * RESOLUTION[clampi(GraphicsQuality.current, 0, 2)]
	_viewport.size = Vector2i(maxi(int(height * _size.x / _size.y), 1), maxi(int(height), 1))
	var view := mirror_view(_frame, eye)
	_camera.global_transform = view["transform"]
	_camera.set_frustum(_size.y, view["offset"], view["near"], FAR)
	RenderingServer.camera_set_transform(_camera.get_camera_rid(), _camera.global_transform)


## 倒影相机的摆法。返回 transform（相机的世界变换）、offset（视锥偏移）、near（近裁剪距离）。
static func mirror_view(frame: Transform3D, eye: Vector3) -> Dictionary:
	var p := frame.affine_inverse() * eye
	var mirrored := Vector3(p.x, p.y, -p.z)
	return {
		"transform": frame * Transform3D(Basis.FLIP_X * Basis.FLIP_Z, mirrored),
		"offset": Vector2(mirrored.x, -mirrored.y),
		"near": absf(mirrored.z),
	}


## 玻璃上一点在倒影图里的位置（0 到 1，左上角是原点）。和 window_glass.gdshader 里的算法一致。
static func glass_uv(frame: Transform3D, size: Vector2, point: Vector3) -> Vector2:
	var offset := point - frame.origin
	return Vector2(0.5 - offset.dot(frame.basis.x) / size.x, 0.5 - offset.dot(frame.basis.y) / size.y)


## 由玻璃的包围盒定出矩形：最薄的那根轴是法线，翻到朝 inside 那边；y 尽量朝上。
static func frame_for(box: AABB, inside: Vector3) -> Transform3D:
	var thin := 0
	for axis: int in 3:
		if box.size[axis] < box.size[thin]:
			thin = axis
	var normal := Vector3.ZERO
	normal[thin] = 1.0
	var center := box.get_center()
	if (inside - center).dot(normal) < 0.0:
		normal = -normal
	var up := Vector3.UP if thin != Vector3.AXIS_Y else Vector3.FORWARD
	var right := up.cross(normal).normalized()
	return Transform3D(Basis(right, normal.cross(right), normal), center)


static func size_for(box: AABB, frame: Transform3D) -> Vector2:
	return Vector2(absf(box.size.dot(frame.basis.x)), absf(box.size.dot(frame.basis.y)))


## 倒影用的环境：和屋里一样的背景和雾，但不做色调映射和泛光。倒影最后贴回主画面，那边再统一做一次。
func _environment() -> Environment:
	var source := get_world_3d().environment
	var env := source.duplicate() as Environment if source != null else Environment.new()
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = false
	env.ssao_enabled = false
	env.volumetric_fog_enabled = false
	return env
