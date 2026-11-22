class_name SaveStore
extends RefCounted
## 存档的读写。
##
## 用 JSON 而不是 Resource：Resource 文件可以内嵌脚本，读别人给的存档会有执行代码的风险。
## 本局和跨周目分成两个文件，新开一局只动前一个。

## 改了存档结构就加一，并在 _parse 里补上旧版本的迁移。
const VERSION := 1
const RUN_PATH := "user://run.json"
const META_PATH := "user://meta.json"
const BACKUP_SUFFIX := ".bak"


static func save_run(state: RunState, path: String = RUN_PATH) -> Error:
	return _write(path, {"version": VERSION, "run": state.to_dict()})


## 没有存档或者存档读不出来时返回 null。
static func load_run(path: String = RUN_PATH) -> RunState:
	var data := _read(path)
	var run: Variant = data.get("run")
	if not (run is Dictionary):
		return null
	return RunState.from_dict(run)


static func save_meta(meta: MetaState, path: String = META_PATH) -> Error:
	return _write(path, {"version": VERSION, "meta": meta.to_dict()})


static func load_meta(path: String = META_PATH) -> MetaState:
	var data := _read(path)
	var meta: Variant = data.get("meta")
	if not (meta is Dictionary):
		return MetaState.new()
	return MetaState.from_dict(meta)


static func _write(path: String, data: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	# 开着完整精度，计时器读回来才和存进去的一模一样。
	file.store_string(JSON.stringify(data, "\t", true, true))
	file.close()
	# 先写临时文件，再把上一份留作备份，最后换上新的。
	# 无论在哪一步断掉，磁盘上都至少有一份完整的存档。
	if FileAccess.file_exists(path):
		DirAccess.rename_absolute(path, path + BACKUP_SUFFIX)
	return DirAccess.rename_absolute(temp, path)


## 先读正式的那份，读不出来再读备份。都不行就返回空字典。
static func _read(path: String) -> Dictionary:
	for candidate: String in [path, path + BACKUP_SUFFIX]:
		var data := _parse(candidate)
		if not data.is_empty():
			return data
	return {}


static func _parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		push_warning("存档读不出来，已跳过: %s" % path)
		return {}
	var data: Dictionary = json.data
	var version := int(data.get("version", 0))
	if version != VERSION:
		push_warning("存档版本是 %d，当前只认 %d，已跳过: %s" % [version, VERSION, path])
		return {}
	return data
