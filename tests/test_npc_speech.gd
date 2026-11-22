extends RefCounted
## NPC 头顶字幕放在屏幕哪里：底边正中对着说话的人，整句留在画面里，人在身后时贴到画面底边靠他的一侧。
## 连着两句一样的话只说一遍。

const SCREEN := Vector2(1152.0, 648.0)
const BOX := Vector2(200.0, 40.0)
const MARGIN := 10.0


func test_the_line_sits_right_above_the_speaker(t: TestCase) -> void:
	var at := NpcSpeech.place(Vector2(600.0, 300.0), false, BOX, SCREEN, MARGIN)
	t.eq(at, Vector2(500.0, 260.0), "字幕底边正中对着说话人投到屏幕上的点")
	t.done()


func test_the_line_stays_inside_the_screen(t: TestCase) -> void:
	for spot: Vector2 in [Vector2(1140.0, 300.0), Vector2(5.0, 10.0), Vector2(-400.0, 900.0), Vector2(2000.0, -50.0)]:
		var at := NpcSpeech.place(spot, false, BOX, SCREEN, MARGIN)
		var inside := Rect2(Vector2.ONE * MARGIN, SCREEN - Vector2.ONE * MARGIN * 2.0)
		t.ok(inside.encloses(Rect2(at, BOX)), "说话人在 %s 时字幕跑出了画面：%s" % [spot, at])
	t.done()


func test_a_speaker_behind_the_camera_shows_at_the_bottom_on_their_side(t: TestCase) -> void:
	# 镜头身后的点投到屏幕上是左右颠倒的：投在右半边，人其实在左后方。
	var left := NpcSpeech.place(Vector2(900.0, 200.0), true, BOX, SCREEN, MARGIN)
	t.eq(left, Vector2(MARGIN, SCREEN.y - BOX.y - MARGIN), "人在左后方，字幕贴在左下角")
	var right := NpcSpeech.place(Vector2(200.0, 200.0), true, BOX, SCREEN, MARGIN)
	t.eq(right, SCREEN - BOX - Vector2.ONE * MARGIN, "人在右后方，字幕贴在右下角")
	t.done()


func test_the_same_line_twice_in_a_row_is_said_once(t: TestCase) -> void:
	var none: Array[Dictionary] = []
	t.ok(NpcSpeech.repeats_last("木头不够了。", "木头不够了。", none), "正在说的这句又来一遍，不再说")
	t.ok(not NpcSpeech.repeats_last("木头不够了。", "", none), "上一句已经说完淡掉了，同样的话可以再说")
	t.ok(not NpcSpeech.repeats_last("太冷了。", "木头不够了。", none), "不同的话照常排上")
	var queued: Array[Dictionary] = [{"text": "太冷了。"}]
	t.ok(NpcSpeech.repeats_last("太冷了。", "木头不够了。", queued), "和排在最后的那句相同，不再排")
	t.ok(not NpcSpeech.repeats_last("木头不够了。", "木头不够了。", queued), "中间隔了别的话，不算连着说")
	t.done()
