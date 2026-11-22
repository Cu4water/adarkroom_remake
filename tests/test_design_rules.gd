extends RefCounted


func test_identical_choices_are_an_error(t: TestCase) -> void:
	var event := _event(&"copy", [
		_choice(&"left", {}, [_outcome({&"wood": 10}, [])]),
		_choice(&"right", {}, [_outcome({&"wood": 10}, [])]),
	])
	t.ok(_rules(DesignRules.check_event(event)).has(&"false_choice"), "两个一模一样的选项")
	t.done()


## 处决小偷和放走小偷拿到同一个技能，只是其中一边多给一点东西。
func test_same_reward_either_way_is_flagged(t: TestCase) -> void:
	var event := _event(&"thief", [
		_choice(&"hang", {}, [_outcome({&"fur": 5}, [&"stealth"])]),
		_choice(&"spare", {}, [_outcome({}, [&"stealth"])]),
	])
	var rules := _rules(DesignRules.check_event(event))
	t.ok(rules.has(&"same_reward"), "不管怎么选都拿到同一个技能")
	t.ok(rules.has(&"free_lunch"), "没有任何一边需要付出")
	t.done()


func test_a_real_tradeoff_passes(t: TestCase) -> void:
	var event := _event(&"beggar", [
		_choice(&"give", {&"fur": 50}, [_outcome({&"scales": 20}, []), _outcome({}, [])]),
		_choice(&"refuse", {}, []),
	])
	t.eq(_rules(DesignRules.check_event(event)), [], "有付出也可能落空的事件")
	t.done()


func test_clues_must_stay_within_budget(t: TestCase) -> void:
	var first := _event(&"first", [])
	first.clues.assign([&"fleet", &"alloy"])
	var second := _event(&"second", [])
	second.clues.assign([&"fleet"])
	var budget := DesignBudget.new()
	budget.clues.assign({&"fleet": 1})
	var rules := _rules(DesignRules.check_clues([first, second], budget))
	t.ok(rules.has(&"clue_over_budget"), "同一条线索暴露得比预算多")
	t.ok(rules.has(&"undeclared_clue"), "没有登记预算的线索")
	budget.clues.assign({&"fleet": 2, &"alloy": 1})
	t.eq(_rules(DesignRules.check_clues([first, second], budget)), [], "预算够的时候")
	t.done()


func _rules(findings: Array[Dictionary]) -> Array:
	return findings.map(func(finding: Dictionary) -> StringName: return finding["rule"])


func _event(id: StringName, choices: Array) -> EventDef:
	var event := EventDef.new()
	event.id = id
	event.choices.assign(choices)
	return event


func _choice(id: StringName, cost: Dictionary, outcomes: Array) -> ChoiceDef:
	var choice := ChoiceDef.new()
	choice.id = id
	choice.cost.assign(cost)
	choice.outcomes.assign(outcomes)
	return choice


func _outcome(stores: Dictionary, grants: Array) -> OutcomeDef:
	var outcome := OutcomeDef.new()
	outcome.stores.assign(stores)
	outcome.grants.assign(grants)
	return outcome
