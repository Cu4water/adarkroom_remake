class_name EventDef
extends Resource
## 一个随机事件。id 一旦进了存档就不要再改。

@export var id: StringName
@export var choices: Array[ChoiceDef] = []
## 这个事件向玩家暴露了哪些指向真相的线索。每条线索都要先在 DesignBudget 里登记。
@export var clues: Array[StringName] = []
