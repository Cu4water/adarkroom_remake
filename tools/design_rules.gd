class_name DesignRules
extends RefCounted
## 把设计原则写成可以自动检查的规则。每条规则对应一个容易滑下去的方向。
##
## 每个问题是一个字典：severity（ERROR 或 WARNING）、rule、where、message。

const ERROR := &"error"
const WARNING := &"warning"

const NO_GRANTS := "[]"


static func check_all(content: ContentDB, budget: DesignBudget) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for event: EventDef in content.events.values():
		findings.append_array(check_event(event))
	findings.append_array(check_clues(content.events.values(), budget))
	return findings


static func check_event(event: EventDef) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var where := "事件 %s" % event.id
	var seen: Dictionary[String, StringName] = {}
	var grant_sets: Dictionary[String, bool] = {}
	var gives := false
	var priced := false
	for choice: ChoiceDef in event.choices:
		var signature := _signature(choice)
		if seen.has(signature):
			findings.append(_finding(ERROR, &"false_choice", where,
					"选项 %s 和 %s 的代价与结果完全一样，等于没有选择" % [seen[signature], choice.id]))
		else:
			seen[signature] = choice.id
		grant_sets[_grants_signature(choice)] = true
		if choice.has_price():
			priced = true
		for outcome: OutcomeDef in choice.outcomes:
			if outcome.gives_something():
				gives = true
	if event.choices.size() > 1 and grant_sets.size() == 1 and not grant_sets.has(NO_GRANTS):
		findings.append(_finding(WARNING, &"same_reward", where,
				"不管选哪个，最后拿到的东西都一样"))
	if gives and not priced:
		findings.append(_finding(WARNING, &"free_lunch", where,
				"会给东西，但没有任何一个选项需要付出或者可能失去"))
	return findings


## events 里装的是 EventDef。
static func check_clues(events: Array, budget: DesignBudget) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var exposures: Dictionary[StringName, int] = {}
	for event: EventDef in events:
		for clue: StringName in event.clues:
			var count: int = exposures.get(clue, 0)
			exposures[clue] = count + 1
	for clue: StringName in exposures:
		var where := "线索 %s" % clue
		if not budget.clues.has(clue):
			findings.append(_finding(ERROR, &"undeclared_clue", where,
					"没有在 DesignBudget 里登记预算"))
		elif exposures[clue] > budget.clues[clue]:
			findings.append(_finding(ERROR, &"clue_over_budget", where,
					"暴露了 %d 次，预算只有 %d 次" % [exposures[clue], budget.clues[clue]]))
	return findings


static func _finding(severity: StringName, rule: StringName, where: String, message: String) -> Dictionary:
	return {"severity": severity, "rule": rule, "where": where, "message": message}


## 把一个选项的代价和结果整理成一个和书写顺序无关的字符串，用来比较两个选项是否等价。
static func _signature(choice: ChoiceDef) -> String:
	var total := 0.0
	for outcome: OutcomeDef in choice.outcomes:
		total += outcome.weight
	var outcomes: Array[String] = []
	for outcome: OutcomeDef in choice.outcomes:
		var share := snappedf(outcome.weight / total, 0.001) if total > 0.0 else 0.0
		var grants: Array[String] = []
		for grant: StringName in outcome.grants:
			grants.append(str(grant))
		grants.sort()
		outcomes.append(str([share, _sorted_pairs(outcome.stores), outcome.population, grants]))
	outcomes.sort()
	return str([_sorted_pairs(choice.cost), outcomes])


## 一个选项所有可能结果里会给出的非数值的东西，去重排序之后的样子。
static func _grants_signature(choice: ChoiceDef) -> String:
	var grants: Array[String] = []
	for outcome: OutcomeDef in choice.outcomes:
		for grant: StringName in outcome.grants:
			if not grants.has(str(grant)):
				grants.append(str(grant))
	grants.sort()
	return str(grants)


static func _sorted_pairs(amounts: Dictionary[StringName, int]) -> Array[String]:
	var pairs: Array[String] = []
	for id: StringName in amounts:
		pairs.append("%s=%d" % [id, amounts[id]])
	pairs.sort()
	return pairs
