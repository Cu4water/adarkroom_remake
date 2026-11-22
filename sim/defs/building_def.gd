class_name BuildingDef
extends Resource
## 一种建筑。id 一旦进了存档就不要再改。

@export var id: StringName
@export var maximum := 1
## 第一座的造价。
@export var base_cost: Dictionary[StringName, int] = {}
## 每多拥有一座，造价增加多少。
@export var cost_per_owned: Dictionary[StringName, int] = {}


func cost_for(owned: int) -> Dictionary[StringName, int]:
	var cost: Dictionary[StringName, int] = {}
	for store: StringName in base_cost:
		cost[store] = base_cost[store]
	for store: StringName in cost_per_owned:
		var base: int = cost.get(store, 0)
		cost[store] = base + cost_per_owned[store] * owned
	return cost
