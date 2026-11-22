class_name NpcSpeech
extends Node3D
## 人物头顶的一句话：字幕跟着"哔哔啵啵"的说话声一个字一个字地出来，说完停一会儿再淡掉。
##
## 所有 NPC 说话都走这里，声音由 Babble 合成，字幕只显示 strings.csv 里的句子。
## 正在说的时候又来一句，就排在后面等这句说完。这个节点不认识模拟层，由人物脚本告诉它说什么、站在哪。

## 说完以后字幕停留的秒数，以及每多一个字多停多少秒。
@export var hold_seconds := 1.4
@export var hold_per_char := 0.06
@export var fade_seconds := 0.6
@export var font_size := 30
@export var text_color := Color(0.9, 0.86, 0.78)

var _label: Label3D
var _player: AudioStreamPlayer3D
var _queue: Array[Dictionary] = []
var _line := ""
var _notes: Array[Dictionary] = []
var _time := 0.0
var _speak_end := 0.0
var _hold_end := 0.0
var _streams: Dictionary[String, AudioStreamWAV] = {}


func _ready() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0009
	_label.font_size = font_size
	_label.outline_size = 10
	_label.modulate = text_color
	_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.7)
	_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_label.width = 460.0
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.render_priority = 10
	_label.visible = false
	add_child(_label)
	_player = AudioStreamPlayer3D.new()
	# 屋子很小，不做距离衰减，只保留左右方位，和 RoomAudio 一样。
	_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	_player.panning_strength = 0.7
	add_child(_player)


## 说一句话。text 是要显示的字幕（已经翻译好的句子）；voice_text 是拿去合成声音的字，留空就用 text。
## 字幕只有省略号这类不出声的字时，用 voice_text 给一串含糊的音节。
func say(text: String, voice: Babble.Voice, voice_text := "", volume_db := 0.0) -> void:
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
	_label.outline_modulate.a = 0.7 * fade
	if _time >= _hold_end + fade_seconds:
		_line = ""
		_label.visible = false
		_next()


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
	_label.visible = true
	if not spoken_notes.is_empty():
		_player.stream = _stream_for(spoken, spoken_notes, voice)
		_player.volume_db = line["volume_db"]
		_player.play()


func _stream_for(spoken: String, notes: Array[Dictionary], voice: Babble.Voice) -> AudioStreamWAV:
	var key := "%s|%s" % [spoken, voice.scale]
	if not _streams.has(key):
		_streams[key] = Babble.to_stream(Babble.synth(notes, voice))
	return _streams[key]
