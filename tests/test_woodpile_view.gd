extends RefCounted
## 柴堆按门槛摆柴：满、少一根、再少一根……

const SMALL: Array[int] = [1, 3, 10]


func test_pile_is_full_at_the_last_threshold(t: TestCase) -> void:
	t.eq(WoodpileView.logs_for(10, SMALL), 3, "刚好到最后一个门槛")
	t.eq(WoodpileView.logs_for(500, SMALL), 3, "再多也只是满的")
	t.ok(WoodpileView.is_full(10, SMALL), "到最后一个门槛就是满的")
	t.ok(not WoodpileView.is_full(9, SMALL), "差一根就不满")
	t.done()


func test_each_threshold_below_takes_one_log_away(t: TestCase) -> void:
	t.eq(WoodpileView.logs_for(9, SMALL), 2, "跌破最后一个门槛，少一根")
	t.eq(WoodpileView.logs_for(3, SMALL), 2, "还在第二个门槛上")
	t.eq(WoodpileView.logs_for(2, SMALL), 1, "再跌破一个门槛，又少一根")
	t.eq(WoodpileView.logs_for(0, SMALL), 0, "没有木头，柴堆是空的")
	t.done()


func test_default_thresholds_rise_and_match_the_opening(t: TestCase) -> void:
	var thresholds := WoodpileView.THRESHOLDS
	for index: int in range(1, thresholds.size()):
		t.ok(thresholds[index] > thresholds[index - 1], "第 %d 个门槛没有比前一个大" % index)
	var opening := Tuning.new().initial_wood
	t.eq(WoodpileView.logs_for(opening, thresholds), opening, "开局手里的几根木头一根对一根")
	t.ok(WoodpileView.logs_for(opening - 1, thresholds) < WoodpileView.logs_for(opening, thresholds),
		"开局时少一根木头就看得出来")
	t.done()


func test_gathered_wood_is_thrown_onto_a_pile_that_is_not_full(t: TestCase) -> void:
	t.eq(WoodpileView.delivery(3, 6, 14, 4), [3, 4, 5] as Array[int], "跨过几个门槛，就从门口扔进几根，落在柴堆往上的空位")
	t.eq(WoodpileView.delivery(2, 12, 14, 4), [2, 3, 4, 5] as Array[int], "一次最多扔四根，剩下的等门关上直接摆好")
	t.eq(WoodpileView.delivery(9, 9, 14, 4), [8] as Array[int], "木头多了但没跨过门槛，也扔一根落到最上面，让玩家看见拾回来了")
	t.eq(WoodpileView.delivery(0, 0, 14, 4), [] as Array[int], "柴堆空着又没长，没地方落")
	t.eq(WoodpileView.delivery(14, 14, 14, 4), [] as Array[int], "柴堆满了就不扔")
	t.done()


func test_a_thrown_log_arcs_from_the_door_and_lands_in_place(t: TestCase) -> void:
	var start := Transform3D(Basis(Vector3.UP, 1.2), Vector3(-1.1, 0.9, -2.3))
	var land := Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(1.6, 0.1, -1.6))
	var spin := Vector3(TAU, 0.4, PI * 0.5)
	t.ok(WoodpileView.flight(start, land, 0.0, 0.5, spin).origin.is_equal_approx(start.origin), "出手时在门口")
	var end := WoodpileView.flight(start, land, 1.0, 0.5, spin)
	t.ok(end.origin.is_equal_approx(land.origin), "落地时正好在柴堆的位置上")
	t.ok(end.basis.is_equal_approx(land.basis), "落地时摆成柴堆里那根的朝向")
	var middle := WoodpileView.flight(start, land, 0.5, 0.5, spin).origin
	t.ok(middle.y > (start.origin.y + land.origin.y) * 0.5 + 0.4, "飞在半空时被抛高了，是一道弧")
	t.done()
