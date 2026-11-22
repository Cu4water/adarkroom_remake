extends RefCounted
## 手写数字：每个数字都有字形，排出来不出框，同一个种子永远写成同一个样子。


func test_every_digit_and_mark_has_a_glyph(t: TestCase) -> void:
	for ch: String in "0123456789/-":
		t.ok(HandGlyphs.GLYPHS.has(ch), "缺少字形 %s" % ch)
		for stroke: Array in HandGlyphs.GLYPHS.get(ch, []):
			t.ok(stroke.size() >= 2, "%s 有一笔少于两个点" % ch)
			for p: Vector2 in stroke:
				t.ok(p.x >= 0.0 and p.x <= HandGlyphs.ADVANCE and p.y >= 0.0 and p.y <= 1.0, "%s 的点 %s 出了字框" % [ch, p])
	t.done()


func test_layout_stays_in_its_box_and_is_stable(t: TestCase) -> void:
	var text := "120/10"
	var strokes := HandGlyphs.layout(text, 7)
	var width := HandGlyphs.width_of(text)
	var margin := HandGlyphs.SLANT + HandGlyphs.JITTER * 2.0
	for stroke: PackedVector2Array in strokes:
		for p: Vector2 in stroke:
			t.ok(p.x > -margin and p.x < width + margin and p.y > -margin and p.y < 1.0 + margin, "点 %s 出了框" % p)
	t.eq(HandGlyphs.layout(text, 7), strokes, "同一个种子写出来一样")
	t.ok(HandGlyphs.layout(text, 8) != strokes, "换个种子笔迹不一样")
	t.ok(HandGlyphs.length_of(strokes) > 0.0, "笔画有长度")
	t.ok(HandGlyphs.width_of("11") < HandGlyphs.width_of("00"), "1 比 0 窄")
	t.done()


func test_ember_ribbon_reveals_in_writing_order(t: TestCase) -> void:
	var strokes := HandGlyphs.layout("40", 3)
	var mesh := EmberWriting.build_mesh(strokes, HandGlyphs.width_of("40"), 0.15, 0.085)
	t.eq(mesh.get_surface_count(), 1, "写出来的是一条带子")
	var uvs: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var last := 0.0
	for uv: Vector2 in uvs:
		t.ok(uv.x >= last - 0.0001, "笔画进度往回走了")
		last = uv.x
	t.ok(is_equal_approx(last, 1.0), "最后一笔写到头")
	t.done()
