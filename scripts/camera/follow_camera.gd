## 俯視跟隨鏡頭：前視偏移（往面向的方向多看一點）、死區、地圖邊界限制、整數像素對齊。
class_name FollowCamera
extends Camera2D

## 往主角面向方向偏移的距離（像素）
@export var lookahead_distance := 40.0
@export var lookahead_smoothing := 3.0
@export var follow_smoothing := 7.0
## 主角在這個範圍內移動時鏡頭不動（半寬、半高）
@export var deadzone := Vector2(10, 6)

var _target: Player
var _bounds := Rect2()
var _lookahead := Vector2.ZERO
var _focus := Vector2.ZERO


func setup(target: Player, bounds: Rect2) -> void:
	_target = target
	_bounds = bounds
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)
	position_smoothing_enabled = false
	snap_to_target()
	make_current()


## 立刻跳到主角位置（重生時使用）。
func snap_to_target() -> void:
	_lookahead = Vector2.ZERO
	_focus = _clamp_to_bounds(_target.global_position)
	global_position = _focus.round()
	reset_smoothing()


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var desired_lookahead := _target.facing * lookahead_distance
	_lookahead = _lookahead.lerp(desired_lookahead, 1.0 - exp(-lookahead_smoothing * delta))

	var goal := _target.global_position + _lookahead
	var diff := goal - _focus
	var push := Vector2(
		signf(diff.x) * maxf(absf(diff.x) - deadzone.x, 0.0),
		signf(diff.y) * maxf(absf(diff.y) - deadzone.y, 0.0))
	_focus += push * (1.0 - exp(-follow_smoothing * delta))
	_focus = _clamp_to_bounds(_focus)
	global_position = _focus.round()


## 把鏡頭中心限制在地圖內，避免前視偏移把鏡頭推到地圖外又被 limit 卡住。
func _clamp_to_bounds(point: Vector2) -> Vector2:
	var half := get_viewport_rect().size * 0.5 / zoom
	var result := point
	if _bounds.size.x > half.x * 2.0:
		result.x = clampf(point.x, _bounds.position.x + half.x, _bounds.end.x - half.x)
	else:
		result.x = _bounds.get_center().x
	if _bounds.size.y > half.y * 2.0:
		result.y = clampf(point.y, _bounds.position.y + half.y, _bounds.end.y - half.y)
	else:
		result.y = _bounds.get_center().y
	return result
