## 聲音提示（選項 sound_cues）：畫面外、附近有敵人在走動時，在畫面邊緣那個方向畫一個小小的聲波記號，
## 越近越亮；人類敵人是橘色，回聲體是青色。手機玩家常常沒戴耳機，潛行全靠聽會變成「用猜的」。
## 只顯示「聽得到的」：敵人在動、而且在 RANGE 格以內。敵人在畫面上看得到時不顯示；
## 在畫面上但被房間黑幕擋住的，只在那一格畫很淡的聲波（隔著牆聽到腳步，不會看到敵人本身）。
class_name SoundCues
extends Control

const RANGE := 14.0 * Level.TILE
const MARGIN := 10.0

var main: Node
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if main == null or not WorldState.option("sound_cues") or main.level == null:
		return
	var player: Node2D = main._player
	var cam: Camera2D = main._camera
	if player == null or cam == null:
		return
	var view := get_viewport_rect().size
	var half := view * 0.5
	var center := cam.get_screen_center_position()
	var screen_rect := Rect2(center - half, view)
	for e in main.enemies:
		if not is_instance_valid(e) or e.is_dead or e.velocity.length() < 8.0:
			continue
		var d: float = e.global_position.distance_to(player.global_position)
		if d > RANGE:
			continue
		var k := 1.0 - d / RANGE
		var col := Color(1.0, 0.6, 0.25) if e.faction == "human" else Color(0.3, 1.0, 0.95)
		if screen_rect.grow(-6.0).has_point(e.global_position):
			# 在畫面上、但在還沒走進去的房間裡（黑幕後面）：在那個位置畫很淡的聲波（隔著牆聽到腳步聲）
			var lv: Level = main.level
			if lv.fog and lv.fog.is_hidden_cell(lv.cell_of(e.global_position)):
				var at: Vector2 = Vector2(lv.cell_of(e.global_position)) * Level.TILE + Vector2(8, 8) - center + half
				var pr := 4.0 + fmod(_t * 10.0, 8.0)
				draw_arc(at.floor(), pr, 0.0, TAU, 12, Color(col, (0.2 + 0.35 * k) * (1.0 - (pr - 4.0) / 8.0)), 1.0)
			continue
		var dir: Vector2 = (e.global_position - center).normalized()
		if dir == Vector2.ZERO:
			continue
		# 從畫面中心往那個方向，貼到畫面邊緣
		var sx := (half.x - MARGIN) / maxf(absf(dir.x), 0.001)
		var sy := (half.y - MARGIN) / maxf(absf(dir.y), 0.001)
		var p := half + dir * minf(sx, sy)
		col.a = 0.25 + 0.6 * k
		var pulse := 0.5 + 0.5 * sin(_t * 9.0 + d * 0.05)
		var ang := dir.angle()
		for i in 3:
			var r := 3.0 + i * 3.0 + pulse * 1.5
			draw_arc(p.floor(), r, ang - 0.6, ang + 0.6, 6, Color(col, col.a * (1.0 - i * 0.28)), 1.0)
