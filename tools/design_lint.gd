extends SceneTree
## 检查 content 目录里的内容有没有违反设计原则。有错误时退出码是 1。
##
## 用法：godot --headless --path . --script res://tools/design_lint.gd

const BUDGET_PATH := "res://content/design_budget.tres"


func _init() -> void:
	var content := ContentDB.load_all()
	var budget: DesignBudget = load(BUDGET_PATH)
	var errors := 0
	var warnings := 0
	for message: String in content.errors:
		errors += 1
		print("错误  内容  %s" % message)
	for finding: Dictionary in DesignRules.check_all(content, budget):
		var is_error: bool = finding["severity"] == DesignRules.ERROR
		if is_error:
			errors += 1
		else:
			warnings += 1
		print("%s  %s  %s：%s" % ["错误" if is_error else "警告", finding["rule"], finding["where"], finding["message"]])
	print("建筑 %d，工作 %d，事件 %d；错误 %d，警告 %d" % [
		content.buildings.size(), content.jobs.size(), content.events.size(), errors, warnings])
	quit(1 if errors > 0 else 0)
