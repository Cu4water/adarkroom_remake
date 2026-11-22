class_name ContentDB
extends RefCounted
## 把 content 目录下的数据读进来，按 id 建索引。
##
## 读的过程中发现的问题记在 errors 里，由调用方决定怎么处理。

const BUILDINGS_DIR := "res://content/buildings"
const JOBS_DIR := "res://content/jobs"
const EVENTS_DIR := "res://content/events"

var buildings: Dictionary[StringName, BuildingDef] = {}
var jobs: Dictionary[StringName, JobDef] = {}
var events: Dictionary[StringName, EventDef] = {}
var errors: PackedStringArray = []


static func load_all() -> ContentDB:
	var db := ContentDB.new()
	for resource: Resource in db._load_dir(BUILDINGS_DIR):
		var building := resource as BuildingDef
		if db._accept(building, resource, "BuildingDef"):
			db._add(db.buildings, building.id, building)
	for resource: Resource in db._load_dir(JOBS_DIR):
		var job := resource as JobDef
		if db._accept(job, resource, "JobDef"):
			db._add(db.jobs, job.id, job)
	for resource: Resource in db._load_dir(EVENTS_DIR):
		var event := resource as EventDef
		if db._accept(event, resource, "EventDef"):
			db._add(db.events, event.id, event)
	db._check_default_job()
	return db


func default_job() -> JobDef:
	for job: JobDef in jobs.values():
		if job.is_default:
			return job
	return null


func _load_dir(dir_path: String) -> Array[Resource]:
	var found: Array[Resource] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		# 目录不存在，说明这一类内容还没开始做。
		return found
	var names := Array(dir.get_files())
	names.sort()
	for file_name: String in names:
		# 导出之后资源文件会变成 .remap，这里还原成原来的路径再读。
		var clean := file_name.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var path := dir_path.path_join(clean)
		var resource: Resource = load(path)
		if resource == null:
			errors.append("%s: 读不出来" % path)
		else:
			found.append(resource)
	return found


func _accept(typed: Resource, resource: Resource, type_name: String) -> bool:
	if typed == null:
		errors.append("%s: 不是 %s" % [resource.resource_path, type_name])
		return false
	return true


func _add(table: Dictionary, id: StringName, def: Resource) -> void:
	if id == &"":
		errors.append("%s: 没有 id" % def.resource_path)
	elif table.has(id):
		var existing: Resource = table[id]
		errors.append("%s: id %s 和 %s 重复" % [def.resource_path, id, existing.resource_path])
	else:
		table[id] = def


func _check_default_job() -> void:
	var defaults := 0
	for job: JobDef in jobs.values():
		if job.is_default:
			defaults += 1
	if defaults > 1:
		errors.append("%s: 有 %d 份默认工作，只能有一份" % [JOBS_DIR, defaults])
