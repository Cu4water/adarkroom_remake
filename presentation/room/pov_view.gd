class_name PovView
extends RefCounted
## 主角的眼睛和脚。转头：左右随便转，抬头低头有上限，不歪头。走动：只在屋里，绕开火塘、柴堆和人。
##
## 朝向用一个 Vector2 表示：x=偏航（弧度，0 是看向 -Z，正数往左转），y=俯仰（弧度，正数抬头）。
## 挡路的东西用 Vector3 表示一个地面上的圆：x、y 是圆心的世界 x、z，z 是半径（已经算上主角的身宽）。
## 纯函数，不碰节点，可以单独测试。

## 抬头低头最多转多少。再多就像仰面躺倒了。
const PITCH_LIMIT := 1.3


## 朝向对应的相机朝向。
static func basis(look: Vector2) -> Basis:
	return Basis(Vector3.UP, look.x) * Basis(Vector3.RIGHT, look.y)


## 从 eye 看向 target 的朝向：target 正好落在屏幕中心。
static func look_at(eye: Vector3, target: Vector3) -> Vector2:
	var dir := (target - eye).normalized()
	return Vector2(atan2(-dir.x, -dir.z), clampf(asin(clampf(dir.y, -1.0, 1.0)), -PITCH_LIMIT, PITCH_LIMIT))


## 鼠标挪了 mouse_delta 像素以后的朝向。鼠标往右，视线往右；鼠标往上，视线往上。
static func turn(look: Vector2, mouse_delta: Vector2, sensitivity: float) -> Vector2:
	return Vector2(
		wrapf(look.x - mouse_delta.x * sensitivity, -PI, PI),
		clampf(look.y - mouse_delta.y * sensitivity, -PITCH_LIMIT, PITCH_LIMIT))


## 可交互物件现在该亮多少：只有用得了、而且准星正对着它的时候才亮。
static func glow(ready: bool, aimed: bool, level: float) -> float:
	return level if ready and aimed else 0.0


## 按着方向键走了 distance 米以后站在哪。input 是 Input.get_vector 的结果（y 负是往前），
## 方向跟着视线的偏航走，不跟俯仰：低着头走也是平着走。
## 撞到挡路的圆就沿着圆边滑开，最后限制在 bounds（世界 x、z 的范围）里。只改 x、z，不改高度。
static func walk(position: Vector3, input: Vector2, yaw: float, distance: float,
		obstacles: Array[Vector3], bounds: Rect2) -> Vector3:
	if input.length_squared() > 1.0:
		input = input.normalized()
	var step := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y) * distance
	var spot := Vector2(position.x + step.x, position.z + step.z)
	for _pass: int in 2:
		for obstacle: Vector3 in obstacles:
			var center := Vector2(obstacle.x, obstacle.y)
			var away := spot - center
			if away.length() < obstacle.z:
				spot = center + (away.normalized() if away.length() > 0.0001 else Vector2.RIGHT) * obstacle.z
		spot = spot.clamp(bounds.position, bounds.end)
	return Vector3(spot.x, position.y, spot.y)
