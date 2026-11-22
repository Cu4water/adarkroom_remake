extends SceneTree
## 跑 tests 目录下的全部测试。有失败时退出码是 1。
##
## 用法：godot --headless --path . --script res://tools/run_tests.gd
##
## 约定：文件名以 test_ 开头，方法名以 test_ 开头，方法接收一个 TestCase，最后调用 done()。

const TESTS_DIR := "res://tests"


func _init() -> void:
	var total := 0
	var failed := 0
	var names := DirAccess.get_files_at(TESTS_DIR)
	names.sort()
	for file_name: String in names:
		if not (file_name.begins_with("test_") and file_name.ends_with(".gd")):
			continue
		var script: GDScript = load(TESTS_DIR.path_join(file_name))
		if script == null or not script.can_instantiate():
			total += 1
			failed += 1
			print("失败  %s  脚本加载不了" % file_name)
			continue
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			var record := TestCase.new()
			var suite: Object = script.new()
			suite.call(method_name, record)
			if not record.finished:
				record.failures.append("没有跑到 done()：中途出错，或者忘了调用")
			var label := "%s.%s" % [file_name.get_basename(), method_name]
			if record.failures.is_empty():
				print("通过  %s" % label)
			else:
				failed += 1
				print("失败  %s" % label)
				for failure: String in record.failures:
					print("        %s" % failure)
	print("\n共 %d 个测试，%d 个失败" % [total, failed])
	quit(1 if failed > 0 else 0)
