class_name GraphicsQuality
extends Node
## 按玩家的设备自动挑画质档：管抗锯齿（TAA、MSAA、FXAA）和阴影的柔化质量。
## 进场景以后再看一会儿帧时间，跑不动就自动降一档。只降不升，免得画面来回跳。
##
## 火光的软阴影（窗框投在墙上的影子）靠 TAA 把每帧的采样噪点抹匀，所以能开 TAA 的档都开；
## 开不了 TAA 的设备退回 FXAA，影子边缘会有一点颗粒，但不会有阶梯状的锯齿。
## 舞台把它放进自己的场景树里。档位记在静态变量里，换舞台时不会又从高档开始试。
## 没有设置菜单之前不存盘，每次启动重新判断。

enum Tier { LOW, MEDIUM, HIGH }

## 刚进场景要编译着色器、合成声音，这几秒的卡顿不算。
const SETTLE_SECONDS := 4.0
## 连续这么多秒的平均帧时间超过预算，就降一档。
const WATCH_SECONDS := 3.0
const FRAME_BUDGET := 1.0 / 50.0
## 核显在这个像素数以内还能开 TAA，再大就退到低档。
const INTEGRATED_PIXELS := 2560 * 1440
## 阴影图集第一象限只放一盏灯：屏幕上占得最多的那盏（火光）独占四分之一张图集。
## 默认是四盏灯平分，火光离窗框三米多、又是斜着照到墙上，分到的那点分辨率会让窗框的影子边缘起锯齿。
## 屋里投影子的灯只有三盏，其余象限够用；图集总大小不变，不多占显存。
const KEY_QUADRANT := Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1

## 现在用的档，-1 是还没判断过。
static var current := -1

var _watch := FrameWatch.new()


## 帧时间观察：先等 SETTLE_SECONDS，之后每 WATCH_SECONDS 秒结一次账，平均帧时间超预算就要降档。
class FrameWatch:
	var _settle := SETTLE_SECONDS
	var _spent := 0.0
	var _frames := 0

	## 喂一帧的时长。返回 true 表示该降一档了，之后重新开始等。
	func feed(delta: float) -> bool:
		if _settle > 0.0:
			_settle -= delta
			return false
		_spent += delta
		_frames += 1
		if _spent < WATCH_SECONDS:
			return false
		var slow := _spent / _frames > FRAME_BUDGET
		_spent = 0.0
		_frames = 0
		if slow:
			_settle = SETTLE_SECONDS
		return slow


## 按显卡类型、渲染器和窗口像素数挑起始档。method 是 RenderingServer.get_current_rendering_method() 的值。
static func tier_for(adapter: RenderingDevice.DeviceType, method: String, pixels: int) -> Tier:
	# TAA 只有 Forward+ 有。
	if method != "forward_plus":
		return Tier.LOW
	if adapter == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
		return Tier.HIGH
	if adapter == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU and pixels <= INTEGRATED_PIXELS:
		return Tier.MEDIUM
	return Tier.LOW


## 一档对应的设置。键：taa、msaa（Viewport.MSAA）、screen_aa（Viewport.ScreenSpaceAA）、
## soft_shadows（RenderingServer.ShadowQuality）、shadow_atlas（阴影图集边长）。
static func settings_for(tier: Tier) -> Dictionary:
	match tier:
		Tier.HIGH:
			return {"taa": true, "msaa": Viewport.MSAA_2X, "screen_aa": Viewport.SCREEN_SPACE_AA_DISABLED,
				"soft_shadows": RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "shadow_atlas": 8192}
		Tier.MEDIUM:
			return {"taa": true, "msaa": Viewport.MSAA_DISABLED, "screen_aa": Viewport.SCREEN_SPACE_AA_DISABLED,
				"soft_shadows": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, "shadow_atlas": 4096}
		_:
			return {"taa": false, "msaa": Viewport.MSAA_DISABLED, "screen_aa": Viewport.SCREEN_SPACE_AA_FXAA,
				"soft_shadows": RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "shadow_atlas": 4096}


func _ready() -> void:
	if current < 0:
		var pixels := DisplayServer.window_get_size().x * DisplayServer.window_get_size().y
		current = tier_for(RenderingServer.get_video_adapter_type(),
			RenderingServer.get_current_rendering_method(), pixels)
	_apply()


func _process(delta: float) -> void:
	if current > Tier.LOW and _watch.feed(delta):
		current -= 1
		_apply()


## 开发用：换到下一档（低档之后回到高档），对比画面用。
func cycle() -> void:
	current = Tier.HIGH if current <= Tier.LOW else current - 1
	_watch = FrameWatch.new()
	_apply()


func _apply() -> void:
	var settings := settings_for(current as Tier)
	var viewport := get_viewport()
	viewport.use_taa = settings["taa"]
	viewport.msaa_3d = settings["msaa"]
	viewport.screen_space_aa = settings["screen_aa"]
	viewport.positional_shadow_atlas_size = settings["shadow_atlas"]
	viewport.set_positional_shadow_atlas_quadrant_subdiv(0, KEY_QUADRANT)
	RenderingServer.positional_soft_shadow_filter_set_quality(settings["soft_shadows"])
	print_verbose("画质档：%s（%s）" % [Tier.keys()[current], RenderingServer.get_video_adapter_name()])
