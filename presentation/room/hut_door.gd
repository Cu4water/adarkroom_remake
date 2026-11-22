class_name HutDoor
extends RefCounted
## 门和门外那道光。门外的光就是"现在可以出去拾柴"，拾过之后暗下去，等冷却结束再亮起来。
## 门开到 swing 角度，停一会儿，再关上；关上那一刻发 closed。

signal closed

## 门正开着（从开始开到关上为止）。
var is_open := false

var _door: Node3D
var _rest := Transform3D.IDENTITY
var _light: OmniLight3D
var _swing := 0.0
var _energy := 0.0
var _tween: Tween


## swing 是门开到多大（弧度，负数朝屋里开），energy 是门外的光亮起来时的亮度。
func _init(door: Node3D, light: OmniLight3D, swing: float, energy: float) -> void:
	_door = door
	_rest = door.transform
	_light = light
	_swing = swing
	_energy = energy


func meshes() -> Array[Node]:
	var result := _door.find_children("*", "MeshInstance3D", true, false)
	if _door is MeshInstance3D:
		result.append(_door)
	return result


## 门关好，光熄掉，不做过渡。
func reset() -> void:
	if _tween != null:
		_tween.kill()
	is_open = false
	_door.transform = _rest
	_light.light_energy = 0.0


## 门外的光慢慢亮起或暗下。门开着的时候一直亮着。
func update_light(can_go_out: bool, delta: float) -> void:
	var wanted := _energy if can_go_out or is_open else 0.0
	_light.light_energy = move_toward(_light.light_energy, wanted, delta * _energy / 2.5)
	_light.visible = _light.light_energy > 0.001


## 开门，停一会儿，再关上。angle 是这一次开到多大（弧度，负数朝屋里开），不给就开到默认的 swing。
func swing(open_seconds: float, hold_seconds: float, close_seconds: float, angle := NAN) -> void:
	is_open = true
	# 模型里门本来就虚掩着一点，这里从那个角度接着转到 swing。
	var target := _swing if is_nan(angle) else angle
	var extra := Basis(Vector3.UP, target - _rest.basis.get_euler().y)
	var open := _rest * Transform3D(extra, Vector3.ZERO)
	if _tween != null:
		_tween.kill()
	_tween = _door.create_tween()
	_tween.tween_property(_door, ^"transform", open, open_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold_seconds)
	_tween.tween_property(_door, ^"transform", _rest, close_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_on_closed)


func _on_closed() -> void:
	is_open = false
	closed.emit()
