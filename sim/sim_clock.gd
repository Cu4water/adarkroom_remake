class_name SimClock
extends RefCounted
## 固定步长时钟。
##
## 模拟只按 STEP 推进，和帧率无关，所以同一个种子加同一串指令一定得到同一个结果。
## 时间分成两个域：
##   HAND    玩家亲手做的事（火、室温、手动操作的冷却），永远是原速。
##   VILLAGE 村庄自己运转的事（村民、人口），按 Tuning.village_speed 加速。

enum Domain { HAND, VILLAGE }

const STEP := 0.05
## 单帧最多补多少步。卡顿之后多出来的时间直接丢掉，不追帧。
const MAX_STEPS_PER_FRAME := 400

## 开发和测试用的整体倍率。不是给玩家的倍速功能。
var time_scale := 1.0
var paused := false

var _accumulator := 0.0


## 吃进一段真实时间，返回这一帧应该推进几步。
func consume(real_delta: float) -> int:
	if paused:
		return 0
	_accumulator += real_delta * time_scale
	var steps := int(_accumulator / STEP)
	if steps > MAX_STEPS_PER_FRAME:
		_accumulator = 0.0
		return MAX_STEPS_PER_FRAME
	_accumulator -= steps * STEP
	return steps
