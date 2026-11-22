class_name LevelTable
extends RefCounted
## 表现层里"每级火势对应一个数"的表，都用这里的函数取值。
##
## 模拟里的火势是 0 到 4 的整数，但画面和声音要平滑过渡，
## 所以表现层手里的是一个连续的值，落在两级之间时就在两个数之间插值。


static func sample(table: Array[float], level: float) -> float:
	var last := table.size() - 1
	var low := clampi(floori(level), 0, last)
	var high := mini(low + 1, last)
	return lerpf(table[low], table[high], clampf(level - low, 0.0, 1.0))
