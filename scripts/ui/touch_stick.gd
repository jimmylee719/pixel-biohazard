## 浮動虛擬搖桿：手指在畫面左半邊按下的地方就是搖桿中心，拖曳的方向和距離 = 移動方向和力道。
## 轉成 move_up/down/left/right 四個 InputMap 動作（有力道），所以面板的上下選擇也能用。
class_name TouchStick
extends Node2D

const ACTIONS := {"move_left": Vector2.LEFT, "move_right": Vector2.RIGHT,
	"move_up": Vector2.UP, "move_down": Vector2.DOWN}
## 搖桿能拉多遠（像素）
const RADIUS := 30.0
const DEADZONE := 0.25
## 搖桿只在這個範圍內按下才算（畫面左邊、上方選單按鈕以下）
const ZONE := Rect2(0, 56, 220, 214)

var active := true
var vector := Vector2.ZERO

var _touch := -1
var _center := Vector2.ZERO
var _knob := Vector2.ZERO


func _input(event: InputEvent) -> void:
	if not active:
		return
	var touch := event as InputEventScreenTouch
	if touch:
		if touch.pressed and _touch == -1 and ZONE.has_point(touch.position):
			touch_down(touch.index, touch.position)
		elif not touch.pressed and touch.index == _touch:
			release()
		return
	var drag := event as InputEventScreenDrag
	if drag and drag.index == _touch:
		touch_move(drag.position)


func touch_down(index: int, pos: Vector2) -> void:
	_touch = index
	_center = pos
	_knob = pos
	vector = Vector2.ZERO
	queue_redraw()


func touch_move(pos: Vector2) -> void:
	var offset := (pos - _center).limit_length(RADIUS)
	_knob = _center + offset
	vector = offset / RADIUS
	_apply()
	queue_redraw()


func release() -> void:
	_touch = -1
	vector = Vector2.ZERO
	_apply()
	queue_redraw()


func is_touching() -> bool:
	return _touch != -1


func _apply() -> void:
	for action in ACTIONS:
		var dir: Vector2 = ACTIONS[action]
		var strength := vector.dot(dir)
		if strength > DEADZONE:
			Input.action_press(action, clampf(strength, 0.0, 1.0))
		else:
			Input.action_release(action)


func _draw() -> void:
	if _touch == -1:
		return
	draw_circle(_center, RADIUS, Color(1, 1, 1, 0.12))
	draw_arc(_center, RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.35), 1.0)
	draw_circle(_knob, 10.0, Color(1, 1, 1, 0.4))
