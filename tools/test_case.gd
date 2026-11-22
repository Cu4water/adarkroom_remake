class_name TestCase
extends RefCounted
## 传给每个测试方法的记录器。
##
## 测试方法的最后一行必须调用 done()。脚本中途出错时函数会直接返回，
## 没有 done() 的测试会被判为失败，这样出错的测试不会被当成通过。

var failures: PackedStringArray = []
var finished := false


func ok(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s：期望 %s，实际 %s" % [message, expected, actual])


func done() -> void:
	finished = true


## 测试里常用的一套模拟：真实内容，默认数值。
static func new_sim(run_seed: int = 1, village_speed: float = 1.0) -> Simulation:
	var tuning := Tuning.new()
	tuning.village_speed = village_speed
	var sim := Simulation.new(ContentDB.load_all(), tuning)
	sim.new_run(run_seed)
	return sim
