class_name NpcSpeech
extends Node3D
## 人物头顶的一句话：字幕跟着"哔哔啵啵"的说话声一个字一个字地出来，说完停一会儿再淡掉。
##
## 所有 NPC 说话都走这里，声音由 Babble 合成，字幕只显示 strings.csv 里的句子。
## 正在说的时候又来一句，就排在后面等这句说完。这个节点不认识模拟层，由人物脚本告诉它说什么、站在哪。
##
## 说话声是听不懂的音节，字幕是唯一能读到的内容，所以字幕画在所有界面的最上层（板子举起来也盖不住），
## 位置是这个节点投到屏幕上的地方；人走到画面外或者身后时，字幕贴着屏幕边，不会被截掉。

## 说完以后字幕停留的秒数，以及每多一个字多停多少秒。
@export var hold_seconds := 1.4
@export var hold_per_char := 0.06
@export var fade_seconds := 0.6
## 字号、描边、一行多宽，都是界面像素（按 1152×648 的基准画面）。
@export var font_size := 14
@export var outline_size := 4
@export var line_width := 200.0
## 贴着屏幕边时离边多远。
@export var screen_margin := 10.0
## 字幕所在的画布层，要比所有界面都高。
@export var layer := 100
@export var text_color := Color(0.9, 0.86, 0.78)

var _label: Label
var _player: AudioStreamPlayer3D
var _queue: Array[Dictionary] = []
var _line := ""
var _notes: Array[Dictionary] = []
var _time := 0.0
var _speak_end := 0.0
var _hold_end := 0.0
var _streams: Dictionary[String, AudioStreamWAV] = {}


func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = layer
	add_child(canvas)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.custom_minimum_size = Vector2(line_width, 0.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override(&"font_size", font_size)
	_label.add_theme_constant_override(&"outline_size", outline_size)
	_label.add_theme_color_override(&"font_color", text_color)
	_label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	_label.visible = false
	canvas.add_child(_label)
	_player = AudioStreamPlayer3D.new()
	# 屋子很小，不做距离衰减，只保留左右方位，和 RoomAudio 一样。
	_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	_player.panning_strength = 0.7
	add_child(_player)


## 说一句话。text 是要显示的字幕（已经翻译好的句子）；voice_text 是拿去合成声音的字，留空就用 text。
## 字幕只有省略号这类不出声的字时，用 voice_text 给一串含糊的音节。
## 和还没说完的最后一句一样就不再说，免得连着点两下听到两遍同样的话。
func say(text: String, voice: Babble.Voice, voice_text := "", volume_db := 0.0) -> void:
	if repeats_last(text, _line, _queue):
		return
	_queue.append({"text": text, "voice": voice, "voice_text": voice_text, "volume_db": volume_db})
	if _line == "":
		_next()


## 正在说或者字幕还没淡掉。
func busy() -> bool:
	return _line != ""


## 还有排着没说的话（不算正在说的这句）。
func has_pending() -> bool:
	return not _queue.is_empty()


## 立刻闭嘴，清空排着的话。
func clear() -> void:
	_queue.clear()
	_line = ""
	_player.stop()
	_label.visible = false


## text 是不是和最后一句还没说完的话相同。current 是正在说的那句（说完淡掉以后是空串），
## queue 是排着的话；排着的有话就比队尾那句，没有就比正在说的那句。
static func repeats_last(text: String, current: String, queue: Array[Dictionary]) -> bool:
	var last: String = queue.back()["text"] if not queue.is_empty() else current
	return text == last


## 字幕框的左上角放在哪。spot 是说话人投到屏幕上的点（字幕的底边正中对着它），
## behind 表示说话人在镜头身后（这时 spot 是镜像过去的，要翻回来），size 是字幕框大小，screen 是画面大小。
## 字幕整个留在画面里，离边至少 margin；人在身后时字幕贴在画面底边、靠他那一侧。
static func place(spot: Vector2, behind: bool, size: Vector2, screen: Vector2, margin: float) -> Vector2:
	var anchor := spot
	if behind:
		anchor = Vector2(screen.x if spot.x < screen.x * 0.5 else 0.0, screen.y)
	var top_left := anchor - Vector2(size.x * 0.5, size.y)
	var lowest := screen - size - Vector2.ONE * margin
	return Vector2(clampf(top_left.x, margin, maxf(lowest.x, margin)),
		clampf(top_left.y, margin, maxf(lowest.y, margin)))


func _process(delta: float) -> void:
	if _line == "":
		return
	_time += delta
	var shown := 0
	for note: Dictionary in _notes:
		if _time + 0.02 >= float(note["time"]):
			shown = int(note["end"])
	if _notes.is_empty():
		shown = _line.length()
	_label.text = _line.substr(0, shown)
	var fade := clampf((_hold_end + fade_seconds - _time) / fade_seconds, 0.0, 1.0)
	_label.modulate.a = text_color.a * fade
	_place_label()
	if _time >= _hold_end + fade_seconds:
		_line = ""
		_label.visible = false
		_next()


func _place_label() -> void:
	var camera := get_viewport().get_camera_3d()
	_label.visible = camera != null and is_visible_in_tree()
	if not _label.visible:
		return
	_label.reset_size()
	var behind := camera.is_position_behind(global_position)
	var spot := camera.unproject_position(global_position)
	_label.position = place(spot, behind, _label.size, _label.get_viewport_rect().size, screen_margin)


func _next() -> void:
	if _queue.is_empty():
		return
	var line: Dictionary = _queue.pop_front()
	var voice: Babble.Voice = line["voice"]
	_line = line["text"]
	var spoken: String = line["voice_text"] if line["voice_text"] != "" else _line
	var spoken_notes := Babble.plan(spoken, voice)
	# 字幕跟着声音出字，一个字对一声。声音用的是另一串音节时，字幕按它自己的字数和语速出；
	# 一个能出声的字都没有（比如只有省略号）就整句直接显示。
	_notes = spoken_notes if spoken == _line else Babble.plan(_line, voice)
	_time = 0.0
	_speak_end = Babble.length_of(spoken_notes)
	_hold_end = _speak_end + hold_seconds + hold_per_char * _line.length()
	_label.text = ""
	_place_label()
	if not spoken_notes.is_empty():
		_player.stream = _stream_for(spoken, spoken_notes, voice)
		_player.volume_db = line["volume_db"]
		_player.play()


func _stream_for(spoken: String, notes: Array[Dictionary], voice: Babble.Voice) -> AudioStreamWAV:
	var key := "%s|%s" % [spoken, voice.scale]
	if not _streams.has(key):
		_streams[key] = Babble.to_stream(Babble.synth(notes, voice))
	return _streams[key]
