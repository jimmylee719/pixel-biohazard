## 畫在黑暗之上的資訊（放在 follow_viewport 的 CanvasLayer 裡，用世界座標繪製、不受黑暗影響）：
## - 遊戲提示：敵人頭上的 ? / !（看得到敵人時）、鳴骨者的喀喀聲波紋（聽得到就顯示，「聲音先於影像」）
## - 除錯（F3）：視野扇形、震動感應範圍、聲音半徑、巡邏路線、察覺值、溫度區域
class_name DebugOverlay
extends Node2D

const STATE_COLORS := [
	Color(0.3, 0.9, 0.4),   # 未察覺
	Color(1.0, 0.85, 0.2),  # 起疑
	Color(1.0, 0.25, 0.2),  # 警戒
	Color(1.0, 0.55, 0.15), # 搜索
]
const CONE_RAYS := 24
const NOISE_LIFETIME := 0.6
const CLICK_LIFETIME := 0.5
## 主角離鳴骨者多近才「聽得到」喀喀聲
const CLICK_AUDIBLE_RANGE := 200.0

var debug_enabled := true

var _enemies: Array[Enemy] = []
var _player: Player
var _level: Level
var _noises: Array[Dictionary] = []


func setup(player: Player, enemies: Array[Enemy], level: Level) -> void:
	_player = player
	_enemies = enemies
	_level = level
	NoiseBus.noise_emitted.connect(_on_noise)


func _process(delta: float) -> void:
	for n in _noises:
		n.t += delta
	_noises = _noises.filter(func(n): return n.t < NOISE_LIFETIME)
	queue_redraw()


func _draw() -> void:
	if debug_enabled:
		_draw_zones()
		_draw_noises()
	for enemy in _enemies:
		if debug_enabled:
			if enemy.has_sight:
				_draw_vision_cone(enemy)
			if enemy.feel_radius > 0.0:
				draw_arc(enemy.global_position, enemy.feel_radius, 0.0, TAU, 24, Color(STATE_COLORS[enemy.state], 0.5), 1.0)
			_draw_patrol(enemy)
		_draw_clicks(enemy)
		if debug_enabled or enemy.visible_to_player:
			_draw_state_icon(enemy)
		if debug_enabled:
			_draw_awareness_bar(enemy)


func _on_noise(pos: Vector2, radius: float, _source: Node) -> void:
	_noises.append({"pos": pos, "radius": radius, "t": 0.0})


func _draw_zones() -> void:
	for zone_name in Level.ZONES:
		var r: Rect2i = Level.ZONES[zone_name].rect
		var rect := Rect2(Vector2(r.position) * Level.TILE, Vector2(r.size) * Level.TILE)
		var heated := _level.is_zone_heated(zone_name)
		var color := Color(1.0, 0.5, 0.3, 0.35) if heated else Color(0.4, 0.75, 1.0, 0.5)
		draw_rect(rect.grow(-1), color, false, 1.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(3, 9),
			"%s %s" % [zone_name, "HEAT" if heated else "COLD"], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)


func _draw_noises() -> void:
	for n in _noises:
		var a: float = 1.0 - n.t / NOISE_LIFETIME
		draw_arc(n.pos, n.radius, 0.0, TAU, 32, Color(0.6, 0.8, 1.0, 0.6 * a), 1.0)


## 鳴骨者的喀喀聲：主角在附近就看得到波紋，就算看不到敵人本身。
## 之後換成真正的立體聲音效後，這個波紋可以保留成「聽覺輔助」選項。
func _draw_clicks(enemy: Enemy) -> void:
	if enemy.click_interval <= 0.0 or enemy.click_age > CLICK_LIFETIME:
		return
	var dist := enemy.global_position.distance_to(_player.global_position)
	if dist > CLICK_AUDIBLE_RANGE and not debug_enabled:
		return
	var k := enemy.click_age / CLICK_LIFETIME
	var loudness := clampf(1.0 - dist / CLICK_AUDIBLE_RANGE, 0.25, 1.0)
	var color := Color(0.6, 1.0, 1.0, (1.0 - k) * 0.7 * loudness)
	for i in 2:
		var r := 4.0 + k * 14.0 + i * 4.0
		draw_arc(enemy.global_position, r, -0.6, 0.6, 6, color, 1.0)
		draw_arc(enemy.global_position, r, PI - 0.6, PI + 0.6, 6, color, 1.0)


## 視野扇形會被牆壁截斷，看起來就是敵人實際看得到的範圍。
func _draw_vision_cone(enemy: Enemy) -> void:
	var origin := enemy.global_position
	var half := enemy.get_half_angle()
	var length := enemy.get_effective_range()
	var base := enemy.facing.angle()
	var points := PackedVector2Array([origin])
	for i in CONE_RAYS + 1:
		var angle := base - half + (2.0 * half) * float(i) / CONE_RAYS
		var end := origin + Vector2.RIGHT.rotated(angle) * length
		points.append(Sight.cast(enemy, origin, end))
	var color: Color = STATE_COLORS[enemy.state]
	# 用三角扇形一片一片畫：貼著牆時射線點可能重疊，整塊多邊形會三角化失敗
	var fill := Color(color, 0.18)
	for i in range(1, points.size() - 1):
		var a := points[i] - origin
		var b := points[i + 1] - origin
		if absf(a.cross(b)) > 0.5:
			draw_colored_polygon(PackedVector2Array([origin, points[i], points[i + 1]]), fill)
	points.append(origin)
	draw_polyline(points, Color(color, 0.6), 1.0)


func _draw_patrol(enemy: Enemy) -> void:
	var pts := enemy.patrol_points
	for i in pts.size() - 1:
		draw_dashed_line(pts[i], pts[i + 1], Color(1, 1, 1, 0.15), 1.0, 3.0)
	for p in pts:
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 0.3))


func _draw_state_icon(enemy: Enemy) -> void:
	var icon := ""
	match enemy.state:
		Enemy.State.SUSPICIOUS, Enemy.State.SEARCH:
			icon = "?"
		Enemy.State.ALERT:
			icon = "!"
	if icon == "":
		return
	var pos := enemy.global_position + Vector2(-3, -10)
	draw_string(ThemeDB.fallback_font, pos, icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, STATE_COLORS[enemy.state])


func _draw_awareness_bar(enemy: Enemy) -> void:
	var pos := enemy.global_position + Vector2(-8, 9)
	draw_rect(Rect2(pos, Vector2(16, 2)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(pos, Vector2(16 * enemy.awareness, 2)), STATE_COLORS[enemy.state])
