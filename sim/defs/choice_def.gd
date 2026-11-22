class_name ChoiceDef
extends Resource
## 事件里的一个选项。

@export var id: StringName
## 选它要先付出什么。
@export var cost: Dictionary[StringName, int] = {}
@export var outcomes: Array[OutcomeDef] = []


## 这个选项有没有代价：要么先付出，要么有可能失去。
func has_price() -> bool:
	if not cost.is_empty():
		return true
	for outcome: OutcomeDef in outcomes:
		if outcome.takes_something():
			return true
	return false
