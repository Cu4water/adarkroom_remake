class_name JobDef
extends Resource
## 村民的一种工作。id 一旦进了存档就不要再改。

@export var id: StringName
## 没有被分配到别处的人口都算在这份工作上。全部内容里只应该有一个。
@export var is_default := false
## 每隔多少秒结算一次，按村庄时间计。
@export var period := 10.0
## 每个人每次结算带来的库存变化，负数表示消耗。
@export var stores: Dictionary[StringName, int] = {}
