class_name MetaState
extends RefCounted
## 跨周目保留的东西。只有"知道了什么"，没有数值。
##
## 这里刻意不提供任何能存数字的接口，存档格式也只是一串 id：
## 二周目带走的应该是理解，不是加成。

var _known: Dictionary[StringName, bool] = {}


func learn(id: StringName) -> void:
	_known[id] = true


func knows(id: StringName) -> bool:
	return _known.has(id)


func to_dict() -> Dictionary:
	var ids: Array[String] = []
	for id: StringName in _known:
		ids.append(str(id))
	ids.sort()
	return {"known": ids}


static func from_dict(data: Dictionary) -> MetaState:
	var meta := MetaState.new()
	var raw: Variant = data.get("known")
	if raw is Array:
		var ids: Array = raw
		for id: Variant in ids:
			if id is String:
				meta.learn(StringName(str(id)))
	return meta
