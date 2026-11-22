class_name SimEvents
extends RefCounted
## 模拟层对外的唯一出口。表现层只订阅这里的信号，不直接读写系统。
##
## 信号都是由各个系统发出的，所以每个信号都关掉了"未使用"的警告。

## 一句叙述。key 是本地化键；args 里如果有数组，装的是内容 id，由表现层翻译。
@warning_ignore("unused_signal")
signal narrated(key: StringName, args: Dictionary)

## source 说明这次变动是谁造成的，见 Simulation.BY_*。
@warning_ignore("unused_signal")
signal store_changed(id: StringName, amount: int, delta: int, source: StringName)

@warning_ignore("unused_signal")
signal fire_changed(level: int)

@warning_ignore("unused_signal")
signal temperature_changed(level: int)

@warning_ignore("unused_signal")
signal builder_changed(level: int)

## 一个新的东西出现了。界面的扩展就是叙事节点，表现层应该认真对待每一次解锁。
@warning_ignore("unused_signal")
signal unlocked(feature: StringName)

@warning_ignore("unused_signal")
signal building_changed(id: StringName, count: int)

@warning_ignore("unused_signal")
signal population_changed(count: int, delta: int)

## 整个状态被换掉了（新开一局或读档）。表现层收到后按当前状态整体重建。
@warning_ignore("unused_signal")
signal state_replaced
