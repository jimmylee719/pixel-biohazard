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
## true = 固定看整個區域（Boss 戰的特殊鏡頭），不跟隨主角
var fixed := false
var _lookahead := Vector2.ZERO
var _focus := Vector2.ZERO

## ── 潛龍諜影式的多種視角（2.5D）──
## 區域的鏡頭設定（Areas 的 camera_zones，main 每幀依主角位置設定）：
##   zoom_target  推近（1 = 平常，1.25～1.5 = 比較近、比較有壓迫感）
##   frame_point  固定機位：鏡頭停在這個點（像監視器的固定角度），null = 跟隨
## 貼牆視角：主角背貼著牆時，鏡頭往主角前方（離開牆的方向）推出去、拉近一點，看得到走廊前面
var zoom_target := 1.0
var frame_point: Variant = null
var wall_offset := Vector2.ZERO
var _wall := Vector2.ZERO


func setup(target: Player, bounds: Rect2, mode := "follow") -> void:
	_target = target
	_bounds = bounds
	fixed = mode == "fixed"
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)
	position_smoothing_enabled = false
	snap_to_target()
	make_current()


## 立刻跳到主角位置（重生時使用）。
func snap_to_target() -> void:
	if fixed:
		global_position = _bounds.get_center().round()
		reset_smoothing()
		return
	_lookahead = Vector2.ZERO
	_focus = _clamp_to_bounds(_target.global_position)
	global_position = _focus.round()
	reset_smoothing()


func _physics_process(delta: float) -> void:
	if _target == null or fixed:
		return
	# 推近／拉遠：用「彈簧阻尼」慢起慢停（不會一開始很快、最後拖很久），整段大約 0.6 秒
	var z := _smooth_zoom(zoom.x, zoom_target, delta)
	zoom = Vector2(z, z)
	var desired_lookahead := _target.facing * lookahead_distance
	if wall_offset != Vector2.ZERO:
		desired_lookahead = Vector2.ZERO
	_lookahead = _lookahead.lerp(desired_lookahead, 1.0 - exp(-lookahead_smoothing * delta))
	_wall = _wall.lerp(wall_offset, 1.0 - exp(-4.0 * delta))

	var goal: Vector2 = _target.global_position + _lookahead + _wall
	if frame_point != null:
		# 固定機位：鏡頭停在框好的位置，主角離開太遠時才慢慢跟過去
		var fp: Vector2 = frame_point
		goal = fp + (_target.global_position - fp) * 0.25
	var diff := goal - _focus
	var push := Vector2(
		signf(diff.x) * maxf(absf(diff.x) - deadzone.x, 0.0),
		signf(diff.y) * maxf(absf(diff.y) - deadzone.y, 0.0))
	_focus += push * (1.0 - exp(-follow_smoothing * delta))
	_focus = _clamp_to_bounds(_focus)
	global_position = _focus.round()


var _zoom_vel := 0.0
const ZOOM_TIME := 0.28


## 臨界阻尼的平滑（Game Programming Gems 的 SmoothDamp）：速度連續，起步和停下來都是緩的
func _smooth_zoom(from: float, to: float, delta: float) -> float:
	var omega := 2.0 / ZOOM_TIME
	var x := omega * delta
	var k := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := from - to
	var temp := (_zoom_vel + omega * change) * delta
	_zoom_vel = (_zoom_vel - omega * temp) * k
	var out := to + (change + temp) * k
	if absf(out - to) < 0.0005:
		_zoom_vel = 0.0
		return to
	return out


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
