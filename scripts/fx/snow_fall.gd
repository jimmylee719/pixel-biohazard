## 下雪的畫面（v0.11）：主角在戶外時，依天氣畫斜斜飄下來的雪（螢幕座標，不影響遊戲）。暴風雪 = 又多又快又橫。
class_name SnowFall
extends Control

var main: Node
var _flakes: Array[Vector3] = []
var _amount := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for i in 160:
		_flakes.append(Vector3(randf(), randf(), randf()))


func _process(delta: float) -> void:
	var target := 0.0
	if main and main.level and main._player and not main.level.is_indoor_at(main._player.global_position) \
			and main.level.climate_id() != "temperate" and main.tactical_hud.visible:
		target = float(Weather.value("snow"))
	_amount = move_toward(_amount, target, delta * 0.8)
	visible = _amount > 0.01
	if not visible:
		return
	var wind := 0.15 + _amount * 0.9
	for i in _flakes.size():
		var f := _flakes[i]
		f.y += delta * (0.18 + f.z * 0.25) * (1.0 + _amount)
		f.x += delta * wind * (0.3 + f.z * 0.4)
		if f.y > 1.0:
			f = Vector3(randf() * 1.2 - 0.2, -0.02, f.z)
		if f.x > 1.05:
			f.x -= 1.1
		_flakes[i] = f
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var n := int(_flakes.size() * _amount)
	for i in n:
		var f := _flakes[i]
		var p := (Vector2(f.x, f.y) * view).floor()
		var c := Color(0.85, 0.9, 1.0, 0.35 + f.z * 0.45)
		draw_rect(Rect2(p, Vector2(1, 1) if f.z < 0.6 else Vector2(2, 1)), c)
