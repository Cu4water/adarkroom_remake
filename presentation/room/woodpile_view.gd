class_name WoodpileView
extends RefCounted
## 柴堆摆几根柴。柴堆就是木头库存的画面，屏幕上不显示数字。
##
## 柴堆一共只有十几根柴，木头却能攒到上百，所以不是"一根木头一根柴"，而是一串门槛：
## 木头不少于最后一个门槛时柴堆是满的；每往下跌过一个门槛，柴堆就少一根。
## 门槛前密后疏：手里只有几根木头的时候，每少一根都看得出来；攒到几十上百以后，
## 柴堆只是慢慢变满。
##
## 纯函数，不碰节点，可以单独测试。

## 默认的门槛，从小到大，一个门槛对应柴堆里的一根柴。
## 开局手里的几根木头一根对一根；最后一个门槛是一间小屋的造价，攒够了柴堆就是满的。
const THRESHOLDS: Array[int] = [1, 2, 3, 4, 6, 8, 11, 15, 20, 28, 38, 52, 72, 100]


## 有 wood 根木头时柴堆摆几根柴。thresholds 必须从小到大排好，长度就是柴堆满的时候的根数。
static func logs_for(wood: int, thresholds: Array[int]) -> int:
	var count := 0
	for threshold: int in thresholds:
		if wood < threshold:
			break
		count += 1
	return count


## 柴堆是不是满的。
static func is_full(wood: int, thresholds: Array[int]) -> bool:
	return logs_for(wood, thresholds) == thresholds.size()


## 拾柴回来时，从门口扔到柴堆上的是哪几根柴（柴堆里的下标，从下往上）。
## before 是拾柴前摆着几根，after 是拾柴后该摆几根，size 是柴堆满的时候的根数。
## 柴堆满着就不扔。木头多了但还没跨过下一个门槛时，也扔一根落到最上面那根的位置，让玩家看见拾回来了。
## 一次最多扔 most 根，剩下的等门关上直接摆好。
static func delivery(before: int, after: int, size: int, most: int) -> Array[int]:
	var slots: Array[int] = []
	if before >= size:
		return slots
	if after <= before:
		if before > 0:
			slots.append(before - 1)
		return slots
	for index: int in range(before, mini(after, before + most)):
		slots.append(index)
	return slots


## 一根柴扔出去以后在空中的样子：weight 从 0 到 1，沿抛物线从 start 飞到 land，边飞边翻滚，落地时正好摆成 land 的朝向。
static func flight(start: Transform3D, land: Transform3D, weight: float, arc: float, spin: Vector3) -> Transform3D:
	var w := clampf(weight, 0.0, 1.0)
	var origin := start.origin.lerp(land.origin, w) + Vector3.UP * arc * 4.0 * w * (1.0 - w)
	var rest := 1.0 - w
	var tumble := Basis.from_euler(spin * rest)
	var basis := land.basis.orthonormalized().slerp(start.basis.orthonormalized(), rest) * tumble
	return Transform3D(basis * Basis.from_scale(land.basis.get_scale()), origin)
