extends Node
## 全局唯一的自动加载。只负责持有模拟、驱动时钟、存读档，不放任何玩法逻辑。
##
## events 在整个程序运行期间是同一个对象，新开一局或读档都不会换掉它，
## 所以表现层订阅一次就够了。

const TUNING_PATH := "res://content/tuning.tres"
const AUTOSAVE_INTERVAL := 30.0

var events := SimEvents.new()
var sim: Simulation
var meta: MetaState

var _autosave_left := AUTOSAVE_INTERVAL


func _ready() -> void:
	set_process(false)


## 入口场景在自己的 _ready 里调用。重复调用没有副作用，所以单独运行某个场景时也可以调。
func ensure_booted() -> void:
	if sim != null:
		return
	var content := ContentDB.load_all()
	for message: String in content.errors:
		push_error(message)
	var tuning: Tuning = load(TUNING_PATH)
	meta = SaveStore.load_meta()
	sim = Simulation.new(content, tuning, events)
	var saved := SaveStore.load_run()
	if saved != null:
		sim.load_run(saved)
	else:
		sim.new_run(randi())
	set_process(true)


func new_run() -> void:
	sim.new_run(randi())
	save()


func save() -> void:
	SaveStore.save_run(sim.capture())
	SaveStore.save_meta(meta)
	_autosave_left = AUTOSAVE_INTERVAL


func _process(delta: float) -> void:
	sim.advance(delta)
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and sim != null:
		save()
