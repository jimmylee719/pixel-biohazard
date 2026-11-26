## 聲音提示（選項 sound_cues）：畫面外、附近有敵人在走動時，在畫面邊緣那個方向畫一個小小的聲波記號，
## 越近越亮；人類敵人是橘色，回聲體是青色。手機玩家常常沒戴耳機，潛行全靠聽會變成「用猜的」。
## 只顯示「聽得到的」：敵人在動、而且在 RANGE 格以內。敵人在畫面上看得到時不顯示。
##
## 隔著牆聽（不用開選項，一直都有）：還沒走進去的房間裡有人走動時，在腳步的位置畫聲波，並留下前幾步的痕跡——
## 從痕跡看得出「往哪邊走」，但看不到是什麼、面向哪裡（真實情況下隔著門也只聽得到腳步）。
## 站著不動的聽不到；除非你貼著門靜靜地聽（潛行站著不動，或正在從門縫看）：很近的會有很淡、很慢的呼吸聲。
## 想知道裡面的人面向哪裡 → 潛行靠到門邊按互動，把門推開一條縫看（Player.toggle_peek）。
class_name SoundCues
extends Control

const RANGE := 14.0 * Level.TILE
const MARGIN := 10.0

## 隔著牆聽得到腳步的距離、貼著門聽得到呼吸的距離
const HEAR_STEPS := 11.0 * Level.TILE
const HEAR_BREATH := 6.0 * Level.TILE
const STEP_GAP := 11.0
const STEP_LIFE := 1.3

var main: Node
var _t := 0.0
## 敵人 → 最近幾步的位置和時間 [[pos, t], ...]
var _steps := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if main == null or main.level == null:
		return
	var player: Player = main._player
	var cam: Camera2D = main._camera
	if player == null or cam == null:
		return
	var view := get_viewport_rect().size
	var half := view * 0.5
	var z := cam.zoom.x
	var center := cam.get_screen_center_position()
	var screen_rect := Rect2(center - half / z, view / z)
	_draw_through_walls(player, center, half, z)
	if not WorldState.option("sound_cues"):
		return
	for e in main.enemies:
		if not is_instance_valid(e) or e.is_dead or e.velocity.length() < 8.0:
			continue
		var d: float = e.global_position.distance_to(player.global_position)
		if d > RANGE:
			continue
		var k := 1.0 - d / RANGE
		var col := Color(1.0, 0.6, 0.25) if e.faction == "human" else Color(0.3, 1.0, 0.95)
		if screen_rect.grow(-6.0).has_point(e.global_position):
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


## 隔著牆聽到的腳步：只畫在「還沒走進去的房間」（黑幕後面）裡
func _draw_through_walls(player: Player, center: Vector2, half: Vector2, z: float) -> void:
	var lv: Level = main.level
	if lv.fog == null:
		return
	# 貼著門靜靜地聽：潛行站著不動，或正在從門縫看
	var listening: bool = player.peeking != null or (player.is_quiet() and player.velocity.length() < 4.0 and _near_door(player, lv))
	for e in main.enemies:
		if not is_instance_valid(e) or e.is_dead:
			_steps.erase(e)
			continue
		var d: float = e.global_position.distance_to(player.global_position)
		var hidden := lv.fog.is_hidden_cell(lv.cell_of(e.global_position))
		var trail: Array = _steps.get(e, [])
		if e.velocity.length() >= 8.0 and d <= HEAR_STEPS and hidden and not e.is_dormant:
			if trail.is_empty() or trail[-1][0].distance_to(e.global_position) >= STEP_GAP:
				trail.append([e.global_position, _t])
				if trail.size() > 4:
					trail.pop_front()
		while not trail.is_empty() and _t - trail[0][1] > STEP_LIFE:
			trail.pop_front()
		_steps[e] = trail
		if not hidden:
			continue
		var col := Color(1.0, 0.6, 0.25) if e.faction == "human" else Color(0.3, 1.0, 0.95)
		var k := clampf(1.0 - d / HEAR_STEPS, 0.0, 1.0)
		for i in trail.size():
			var age: float = _t - trail[i][1]
			var at: Vector2 = (trail[i][0] - center) * z + half
			if i == trail.size() - 1:
				# 最新的一步：往外擴散的聲波
				var pr := 3.0 + age * 14.0
				draw_arc(at.floor(), pr, 0.0, TAU, 14, Color(col, (0.25 + 0.5 * k) * clampf(1.0 - age / 0.9, 0.0, 1.0)), 1.0)
				draw_rect(Rect2(at.floor() - Vector2(1, 1), Vector2(2, 2)), Color(col, 0.3 + 0.5 * k))
			else:
				# 前幾步：越舊越淡的小點（看得出往哪邊走）
				draw_rect(Rect2(at.floor() - Vector2(1, 1), Vector2(2, 2)), Color(col, (0.15 + 0.35 * k) * (1.0 - age / STEP_LIFE)))
		if listening and trail.is_empty() and d <= HEAR_BREATH and not e.is_dormant:
			var at2: Vector2 = (e.global_position - center) * z + half
			var ph := fmod(_t * 0.6 + float(e.get_instance_id() % 7) * 0.13, 1.0)
			draw_arc(at2.floor(), 3.0 + ph * 5.0, 0.0, TAU, 12, Color(col, 0.28 * (1.0 - ph)), 1.0)


func _near_door(player: Player, lv: Level) -> bool:
	for door in lv.get_inner_doors():
		if not door.is_open and door.global_position.distance_to(player.global_position) < 26.0:
			return true
	return false
