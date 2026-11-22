class_name SimSystem
extends RefCounted
## 系统只有逻辑，没有状态。
##
## 所有状态都在 Simulation.state 里，所以系统不持有 Simulation 的引用，
## 每次调用时由外面传进来。这样存档只需要序列化 RunState 一个对象。


func domain() -> SimClock.Domain:
	return SimClock.Domain.HAND


## 注册这个系统接受的指令。
func register(_sim: Simulation) -> void:
	pass


## 每个固定步长调用一次。dt 已经按这个系统所在的时间域换算过。
func step(_sim: Simulation, _dt: float) -> void:
	pass
