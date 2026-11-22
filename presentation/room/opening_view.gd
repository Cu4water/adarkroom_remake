class_name OpeningView
extends RefCounted
## 开场那一下的相机：玩家在黑暗里点了哪里，火堆就出现在哪里。
##
## 纯数学，不碰节点，所以可以单独测试。
## 屏幕位置统一用 NDC：x、y 都是 -1 到 1，右和上为正，(0, 0) 是屏幕中心。
## 相机固定高度方向的视角（Camera3D 的默认设置），fov 是竖直方向的角度。

## 火堆最远能贴到离屏幕边缘多近。再往外点，火会有一半在画面外面。
const EDGE := 0.9


## 相机坐标系里，穿过屏幕上某一点的那条视线的方向。
static func local_ray(ndc: Vector2, fov_degrees: float, aspect: float) -> Vector3:
	var half := tan(deg_to_rad(fov_degrees) * 0.5)
	return Vector3(ndc.x * half * aspect, ndc.y * half, -1.0).normalized()


## 世界里的一个点落在屏幕的什么位置。点在相机背后时返回 Vector2.INF。
static func project(view: Transform3D, point: Vector3, fov_degrees: float, aspect: float) -> Vector2:
	var local := view.affine_inverse() * point
	if local.z >= -0.001:
		return Vector2.INF
	var half := tan(deg_to_rad(fov_degrees) * 0.5)
	return Vector2(local.x / (-local.z * half * aspect), local.y / (-local.z * half))


## 相机站在哪。
##
## 要让火堆偏到屏幕左边，可以把头往右转，也可以人往右挪。只转头的话，点得越偏，
## 相机就越是对着一面空墙。所以这里让位置分担一部分：点左边人往右挪，点上边人往下蹲。
## reach 是点到屏幕最边上时，位置在水平和竖直方向各挪多远。
static func eye_for(ndc: Vector2, home: Vector3, reach: Vector2) -> Vector3:
	return home + Vector3(-ndc.x * reach.x, -ndc.y * reach.y, 0.0)


## 相机站在 eye，要让 target 正好落在 ray 这条视线上，该朝哪个方向看。
## 只转偏航和俯仰，不歪头。
static func aim(eye: Vector3, target: Vector3, ray: Vector3) -> Basis:
	var look := aim_look(eye, target, ray)
	return Basis(Vector3.UP, look.x) * Basis(Vector3.RIGHT, look.y)


## 同 aim，答案写成 PovView 的朝向：x=偏航，y=俯仰。
static func aim_look(eye: Vector3, target: Vector3, ray: Vector3) -> Vector2:
	var forward := (target - eye).normalized()
	# 俯仰不改变水平转角，所以先解俯仰：让视线的竖直分量等于目标方向的竖直分量。
	var a := ray.y
	var b := -ray.z
	var reachable := sqrt(a * a + b * b)
	var pitch := atan2(b, a) - acos(clampf(forward.y / reachable, -1.0, 1.0))
	# 再转偏航，把水平方向对上。
	var pitched := Basis(Vector3.RIGHT, pitch) * ray
	var yaw := atan2(forward.x, forward.z) - atan2(pitched.x, pitched.z)
	return Vector2(wrapf(yaw, -PI, PI), pitch)


## 人不动，只转头：玩家点了屏幕上的 ndc，算出让 target 落在那里的朝向。点得太靠边时收到 EDGE 以内。
static func look_for(ndc: Vector2, eye: Vector3, target: Vector3, fov_degrees: float, aspect: float) -> Vector2:
	var spot := ndc.clamp(Vector2(-EDGE, -EDGE), Vector2(EDGE, EDGE))
	return aim_look(eye, target, local_ray(spot, fov_degrees, aspect))


## 屏幕上的像素位置换成 NDC。
static func to_ndc(pixel: Vector2, screen: Vector2) -> Vector2:
	return Vector2(pixel.x / screen.x * 2.0 - 1.0, 1.0 - pixel.y / screen.y * 2.0)


## 玩家点了屏幕上的 ndc，算出让 target 落在那里的相机位姿。
static func solve(ndc: Vector2, target: Vector3, home: Vector3, reach: Vector2,
		fov_degrees: float, aspect: float) -> Transform3D:
	var spot := ndc.clamp(Vector2(-EDGE, -EDGE), Vector2(EDGE, EDGE))
	var eye := eye_for(spot, home, reach)
	return Transform3D(aim(eye, target, local_ray(spot, fov_degrees, aspect)), eye)
