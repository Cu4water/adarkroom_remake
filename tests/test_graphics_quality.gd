extends RefCounted
## 画质档：按设备挑起始档，跑不动时降档，每档的抗锯齿和阴影设置。


func test_start_tier_follows_the_device(t: TestCase) -> void:
	var discrete := RenderingDevice.DEVICE_TYPE_DISCRETE_GPU
	var integrated := RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU
	t.eq(GraphicsQuality.tier_for(discrete, "forward_plus", 3840 * 2160), GraphicsQuality.Tier.HIGH, "独显用高档")
	t.eq(GraphicsQuality.tier_for(integrated, "forward_plus", 1920 * 1080), GraphicsQuality.Tier.MEDIUM,
		"核显、1080p 用中档")
	t.eq(GraphicsQuality.tier_for(integrated, "forward_plus", 3840 * 2160), GraphicsQuality.Tier.LOW,
		"核显带 4K 屏退到低档")
	t.eq(GraphicsQuality.tier_for(RenderingDevice.DEVICE_TYPE_CPU, "forward_plus", 1920 * 1080),
		GraphicsQuality.Tier.LOW, "软件渲染用低档")
	t.eq(GraphicsQuality.tier_for(discrete, "gl_compatibility", 1920 * 1080), GraphicsQuality.Tier.LOW,
		"兼容渲染器没有 TAA，用低档")
	t.done()


func test_every_tier_has_some_anti_aliasing(t: TestCase) -> void:
	for tier: int in GraphicsQuality.Tier.values():
		var settings := GraphicsQuality.settings_for(tier as GraphicsQuality.Tier)
		var has_aa: bool = settings["taa"] or settings["screen_aa"] != Viewport.SCREEN_SPACE_AA_DISABLED
		t.ok(has_aa, "%s 档开着 TAA 或 FXAA" % GraphicsQuality.Tier.keys()[tier])
		t.ok(settings["soft_shadows"] != RenderingServer.SHADOW_QUALITY_HARD, "每一档的阴影都是软的")
	t.ok(GraphicsQuality.settings_for(GraphicsQuality.Tier.HIGH)["taa"], "高档用 TAA 抹平软阴影的噪点")
	t.done()


func test_slow_frames_ask_for_a_lower_tier_only_after_settling(t: TestCase) -> void:
	var watch := GraphicsQuality.FrameWatch.new()
	var dropped := false
	for i: int in int(GraphicsQuality.SETTLE_SECONDS * 10.0) - 1:
		dropped = dropped or watch.feed(0.1)
	t.ok(not dropped, "刚进场景的那几秒再卡也不降档")
	var frames := 0
	while not watch.feed(0.05):
		frames += 1
		if frames > 1000:
			break
	t.ok(frames < 1000, "等过之后，一直二十帧每秒就要降档")
	t.done()


func test_smooth_frames_keep_the_tier(t: TestCase) -> void:
	var watch := GraphicsQuality.FrameWatch.new()
	var dropped := false
	for i: int in 60 * 20:
		dropped = dropped or watch.feed(1.0 / 60.0)
	t.ok(not dropped, "六十帧每秒跑二十秒不降档")
	t.done()
