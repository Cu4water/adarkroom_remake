class_name OutcomeDef
extends Resource
## 一个选项可能导致的一种结果。

## 这种结果出现的相对权重。
@export var weight := 1.0
## 库存变化，负数表示失去。
@export var stores: Dictionary[StringName, int] = {}
## 人口变化，负数表示有人死去或离开。
@export var population := 0
## 给予的非数值的东西，比如技能或者解锁。
@export var grants: Array[StringName] = []


func gives_something() -> bool:
	if population > 0 or not grants.is_empty():
		return true
	for store: StringName in stores:
		if stores[store] > 0:
			return true
	return false


func takes_something() -> bool:
	if population < 0:
		return true
	for store: StringName in stores:
		if stores[store] < 0:
			return true
	return false
