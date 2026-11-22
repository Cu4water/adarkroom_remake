class_name BuilderLines
extends RefCounted
## 她说的话：叙事节拍 → 她头顶冒出哪句、顺带做什么动作。
##
## 找她搭话时说的套话在表现层随机抽、一轮说完歇一会儿；模拟层只记"她搭了一句话"这件事。
## 哪几组套话能说，只读模拟层的解锁。

## 她刚缓过来时低声念叨的，听不出是什么话。只拿来合成声音，字幕只有省略号。
const MUMBLE_VOICE := "mm hm.. mmm hm mm.."
const SPEECH: Dictionary[StringName, StringName] = {
	&"builder.shivers": &"builder.say.mumble",
	&"builder.helps": &"builder.say.helps",
	&"builder.plan.trap": &"builder.say.plan.trap",
	&"builder.plan.cart": &"builder.say.plan.cart",
	&"build.trap": &"builder.say.built.trap",
	&"build.cart": &"builder.say.built.cart",
	&"build.not_enough": &"builder.say.not_enough",
	&"build.too_cold": &"builder.say.too_cold",
}
## 套话是 strings.csv 里的 builder.say.chat.<组>.<编号>。组名就是模拟层的一个解锁名，
## 解锁了才说这一组；编号从 1 连着往下，断了号就算到头。往后要加新的闲聊，在这里加一组，再往表里写。
const CHAT_PREFIX := "builder.say.chat."
const CHAT_GROUPS: Array[StringName] = [BuilderSystem.FEATURE_BOARD, ForestSystem.FEATURE]
## 一轮套话说完以后她只"……"一声，不出声。
const QUIET := &"builder.say.quiet"
## 离上一句套话过了这么久（原速秒数），她才又有话说，新的一轮重新抽。
const CHAT_REST := 60.0
const HAND_OVER := &"builder.say.gives_board"

## 这一轮已经说过的套话键。
var _said: Array[String] = []
var _last_said := -INF
var _last_key := ""
var _rng := RandomNumberGenerator.new()


## rng_seed 为负就随机播种；测试传固定的种子。
func _init(rng_seed := -1) -> void:
	if rng_seed < 0:
		_rng.randomize()
	else:
		_rng.seed = rng_seed


## 这个节拍她有反应就演出来。builder.gives_board 和 builder.stokes 要走动，由 Room 安排。
func react(figure: BuilderFigure, key: StringName, mumble_volume: float, sim: Simulation) -> void:
	if key == &"builder.chat":
		_chat(figure, sim)
		return
	if not SPEECH.has(key):
		return
	if key == &"builder.shivers":
		figure.say(figure.tr(SPEECH[key]), MUMBLE_VOICE, mumble_volume)
		return
	figure.say(figure.tr(SPEECH[key]))
	if key == &"build.too_cold":
		figure.shiver_once()
	elif key == &"build.not_enough":
		figure.shake_head()


## 下一句该说哪个键。已经解锁的套话随机抽，一轮里不重复；一轮说完就回 QUIET，
## 直到离上一句套话过了 CHAT_REST 秒再开新的一轮。新一轮的第一句不和上一轮的最后一句相同。
## 中途解锁了新的一组，新的那几句直接进这一轮。
func next_chat(sim: Simulation, translator: Object) -> String:
	var now := sim.state.elapsed
	if now - _last_said >= CHAT_REST:
		_said.clear()
	var fresh: Array[String] = []
	for key: String in chat_keys(sim, translator):
		if not _said.has(key):
			fresh.append(key)
	if fresh.size() > 1:
		fresh.erase(_last_key)
	if fresh.is_empty():
		return QUIET
	var key := fresh[_rng.randi_range(0, fresh.size() - 1)]
	_said.append(key)
	_last_said = now
	_last_key = key
	return key


## 现在她能说的全部套话键：已经解锁的组里，表里有的每一句。
static func chat_keys(sim: Simulation, translator: Object) -> Array[String]:
	var keys: Array[String] = []
	for group: StringName in CHAT_GROUPS:
		if sim.has_feature(group):
			keys.append_array(group_keys(group, translator))
	return keys


## strings.csv 里这一组有哪些套话键。
static func group_keys(group: StringName, translator: Object) -> Array[String]:
	var keys: Array[String] = []
	var key := "%s%s.%d" % [CHAT_PREFIX, group, 1]
	while translator.tr(key) != key:
		keys.append(key)
		key = "%s%s.%d" % [CHAT_PREFIX, group, keys.size() + 1]
	return keys


## 套话不攒着：还有话排着没说，这一句就不说了。省略号没有能出声的字，NpcSpeech 不会出声。
func _chat(figure: BuilderFigure, sim: Simulation) -> void:
	if figure.speech.has_pending():
		return
	figure.say(figure.tr(next_chat(sim, figure)))
