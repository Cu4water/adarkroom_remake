extends RefCounted


func test_content_loads_cleanly(t: TestCase) -> void:
	var content := ContentDB.load_all()
	t.eq(Array(content.errors), [], "内容加载时的问题")
	# 这几个 id 在系统代码里被直接用到，内容里必须有。
	for id: StringName in [ForestSystem.TRAP, ForestSystem.CART, VillageSystem.HUT]:
		t.ok(content.buildings.has(id), "内容里要有建筑 %s" % id)
	t.ok(content.default_job() != null, "要有一份默认工作")
	t.done()


func test_buildings_get_more_expensive(t: TestCase) -> void:
	var content := ContentDB.load_all()
	var trap: BuildingDef = content.buildings[ForestSystem.TRAP]
	var hut: BuildingDef = content.buildings[VillageSystem.HUT]
	var cart: BuildingDef = content.buildings[ForestSystem.CART]
	t.eq(trap.cost_for(0)[&"wood"], 10, "第一个陷阱")
	t.eq(trap.cost_for(3)[&"wood"], 40, "第四个陷阱")
	t.eq(hut.cost_for(2)[&"wood"], 200, "第三间小屋")
	t.eq(cart.cost_for(0)[&"wood"], 30, "板车")
	t.done()
