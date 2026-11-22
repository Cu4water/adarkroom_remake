class_name DesignBudget
extends Resource
## 每条指向真相的线索，一周目里最多可以暴露几次。
##
## 没在这里登记的线索不允许出现在内容里：想加一处暗示，先决定这条线索值多少预算。

@export var clues: Dictionary[StringName, int] = {}
