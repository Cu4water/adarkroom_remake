class_name ForestSystem
extends SimSystem
## 玩家亲手做的户外活动：拾柴、查看陷阱。走原速。

const FEATURE := &"forest"
const CMD_GATHER := &"forest.gather"
const CMD_TRAPS := &"forest.check_traps"

const TRAP := &"trap"
const CART := &"cart"


func register(sim: Simulation) -> void:
	sim.register_command(CMD_GATHER, _gather)
	sim.register_command(CMD_TRAPS, _check_traps)


## 现在出门能不能拾到柴。只读，不改状态，表现层拿它决定门亮不亮。
static func can_gather(sim: Simulation) -> bool:
	return sim.has_feature(FEATURE) and sim.cooldown_left(CMD_GATHER) <= 0.0


func _gather(sim: Simulation, _args: Dictionary) -> StringName:
	if not sim.has_feature(FEATURE):
		return &"locked"
	if sim.cooldown_left(CMD_GATHER) > 0.0:
		return &"cooldown"
	var tuning := sim.tuning
	var amount := tuning.gather_amount_cart if sim.building(CART) > 0 else tuning.gather_amount
	sim.add_store(&"wood", amount, Simulation.BY_HAND)
	sim.narrate(&"forest.gather")
	sim.start_cooldown(CMD_GATHER, tuning.gather_cooldown)
	return Simulation.OK


func _check_traps(sim: Simulation, _args: Dictionary) -> StringName:
	var traps := sim.building(TRAP)
	if traps == 0:
		return &"locked"
	if sim.cooldown_left(CMD_TRAPS) > 0.0:
		return &"cooldown"
	# 每个陷阱出一样东西，有饵的陷阱多出一样。
	var bait := mini(sim.store(&"bait"), traps)
	var found: Dictionary[StringName, int] = {}
	for _i: int in traps + bait:
		var drop := _roll_drop(sim)
		var count: int = found.get(drop, 0)
		found[drop] = count + 1
	sim.add_store(&"bait", -bait, Simulation.BY_HAND)
	for drop: StringName in found:
		sim.add_store(drop, found[drop], Simulation.BY_HAND)
	sim.narrate(&"forest.traps", {"found": found.keys()})
	sim.start_cooldown(CMD_TRAPS, sim.tuning.traps_cooldown)
	return Simulation.OK


func _roll_drop(sim: Simulation) -> StringName:
	var table := sim.tuning.trap_drops
	var total := 0.0
	for id: StringName in table:
		total += table[id]
	var roll := sim.rng.randf() * total
	var last := &""
	for id: StringName in table:
		last = id
		roll -= table[id]
		if roll < 0.0:
			break
	return last
