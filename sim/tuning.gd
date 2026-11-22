class_name Tuning
extends Resource
## 所有可调的数值。默认值沿用原版，作为调节奏时的基线。

@export_group("时间")
## 村庄时间相对于原速的倍率。1 是原版节奏；10 的时候一个拾柴人大约每秒带回一根木头。
@export_range(0.1, 100.0, 0.1) var village_speed := 1.0

@export_group("火堆")
## 添柴之后隔多久火势降一级。
@export var fire_cool_delay := 300.0
## 室温每隔多久向火势靠近一级。
@export var room_warm_delay := 30.0
@export var fire_cooldown := 10.0
@export var light_cost := 5
@export var stoke_cost := 1

@export_group("建造者")
## 陌生人每隔多久变化一次状态。
@export var builder_state_delay := 30.0
## 陌生人进门之后隔多久木头告急、森林出现。
@export var need_wood_delay := 15.0
@export var builder_income_period := 10.0
@export var builder_income_wood := 2
## 木头攒到一样东西造价的多少，她就说她能造。原版 room.js 是一半。
@export_range(0.0, 1.0, 0.05) var plan_reveal_fraction := 0.5

@export_group("森林")
@export var initial_wood := 4
@export var gather_cooldown := 60.0
@export var gather_amount := 10
@export var gather_amount_cart := 50
@export var traps_cooldown := 90.0
## 陷阱里每种东西出现的权重。
@export var trap_drops: Dictionary[StringName, float] = {
	&"fur": 0.5,
	&"meat": 0.25,
	&"scales": 0.1,
	&"teeth": 0.08,
	&"cloth": 0.065,
	&"charm": 0.005,
}

@export_group("村庄")
@export var hut_room := 4
## 两次来人之间隔多少分钟，x 是下限，y 是上限。
@export var population_delay_minutes := Vector2(0.5, 3.0)
