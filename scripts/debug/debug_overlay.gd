## 畫在黑暗之上的資訊（放在 follow_viewport 的 CanvasLayer 裡，用世界座標繪製、不受黑暗影響）：
## - 遊戲提示：敵人頭上的 ? / !（看得到敵人時）、鳴骨者的喀喀聲波紋（聽得到就顯示，「聲音先於影像」）
## - 戰鬥：鎖定框與準心收束、彈道、近戰揮擊、敵人出手前的預備動作
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


func setup(player: Player) -> void:
	_player = player
	NoiseBus.noise_emitted.connect(_on_noise)


## 切換區域時重新綁定。
func bind_area(level: Level, enemies: Array[Enemy]) -> void:
	_level = level
	_enemies = enemies
	_noises.clear()


func _process(delta: float) -> void:
	for n in _noises:
		n.t += delta
	_noises = _noises.filter(func(n): return n.t < NOISE_LIFETIME)
	queue_redraw()


func _draw() -> void:
	if _level == null:
		return
	# 撿到錄音帶等情報後，這個區域的巡邏路線會一直顯示（MGSV 式的情報獎勵）
	var has_intel := WorldState.has_flag("intel:" + _level.area_id)
	if debug_enabled:
		_draw_zones()
		_draw_noises()
	_draw_combat()
	for enemy in _enemies:
		if enemy.is_dead:
			continue
		if enemy.is_dormant:
			_draw_glint(enemy)
			if debug_enabled:
				draw_arc(enemy.global_position, enemy.wake_radius, 0.0, TAU, 24, Color(0.6, 0.9, 1.0, 0.35), 1.0)
			continue
		if enemy.winding_up and (enemy.visible_to_player or debug_enabled):
			_draw_windup(enemy)
		if debug_enabled:
			if enemy.has_sight:
				_draw_vision_cone(enemy)
			if enemy.feel_radius > 0.0:
				draw_arc(enemy.global_position, enemy.feel_radius, 0.0, TAU, 24, Color(STATE_COLORS[enemy.state], 0.5), 1.0)
		if debug_enabled or has_intel:
			_draw_patrol(enemy)
		_draw_clicks(enemy)
		if debug_enabled or enemy.visible_to_player:
			_draw_state_icon(enemy)
		if debug_enabled:
			_draw_awareness_bar(enemy)


func _draw_combat() -> void:
	var combat := _player.combat
	# 鎖定框：四個角，準心收束時框會縮小、變亮
	if combat.aiming and combat.target and not combat.target.is_dead:
		var c := combat.target.global_position
		var size := lerpf(14.0, 7.0, combat.aim_focus)
		var color := Color(1.0, 0.9, 0.3).lerp(Color(1.0, 0.3, 0.2), combat.aim_focus)
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				var corner := c + Vector2(sx, sy) * size
				draw_line(corner, corner - Vector2(sx * 3, 0), color, 1.0)
				draw_line(corner, corner - Vector2(0, sy * 3), color, 1.0)
	elif combat.aiming:
		var tip := _player.global_position + _player.facing * 24.0
		draw_line(_player.global_position + _player.facing * 8.0, tip, Color(1, 0.9, 0.3, 0.5), 1.0)
	# 彈道
	var shot := combat.last_shot
	if not shot.is_empty():
		_draw_shot(shot, combat.current_weapon())
	# 近戰揮擊
	var swing := combat.last_melee
	var slash_tex := Art.tex("fx/slash")
	if not swing.is_empty() and swing.t < 0.12 and swing.move == "slash" and slash_tex:
		# 刀光（tools/gen_pixel_art.py 的 fx/slash）
		draw_set_transform(swing.pos + swing.dir * 9.0, swing.dir.angle())
		draw_texture(slash_tex, -slash_tex.get_size() * 0.5, Color(1, 1, 1, 1.0 - swing.t / 0.12))
		draw_set_transform(Vector2.ZERO)
	elif not swing.is_empty() and swing.t < 0.15:
		var base: float = swing.dir.angle()
		var color := Color(1, 0.3, 0.3) if swing.takedown else Color(0.9, 0.95, 1.0)
		draw_arc(swing.pos, combat.melee_range, base - 0.9, base + 0.9, 8, Color(color, 1.0 - swing.t / 0.15), 1.0)
	# 裝填進度
	if combat.reloading:
		var p := _player.global_position + Vector2(-6, 9)
		draw_rect(Rect2(p, Vector2(12, 2)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(p, Vector2(12 * combat.reload_progress(), 2)), Color(0.9, 0.85, 0.5))


## 開槍：槍口火光（3 格）、飛出去的子彈（曳光）、往旁邊彈出的彈殼
func _draw_shot(shot: Dictionary, weapon: String) -> void:
	var t: float = shot.t
	var dir: Vector2 = (shot.to - shot.from).normalized()
	var muzzle: Vector2 = shot.from + dir * 9.0 + Vector2(0, -3)
	var flash := Art.tex("fx/muzzle_%d" % mini(int(t / 0.03), 2))
	if t < 0.09 and flash:
		draw_set_transform(muzzle, dir.angle())
		draw_texture(flash, Vector2(0, -flash.get_height() * 0.5))
		draw_set_transform(Vector2.ZERO)
	var travel := 0.1
	var bullet := Art.tex("fx/pellet" if weapon == "shotgun" else "fx/bullet")
	if t < travel and bullet:
		var p: Vector2 = muzzle.lerp(shot.to, t / travel)
		if weapon == "shotgun":
			for k in [-0.12, 0.0, 0.12]:
				var q: Vector2 = muzzle + (p - muzzle).rotated(k)
				draw_texture(bullet, q - bullet.get_size() * 0.5)
		else:
			draw_set_transform(p, dir.angle())
			draw_texture(bullet, -bullet.get_size() * 0.5)
			draw_set_transform(Vector2.ZERO)
	elif t < 0.14:
		draw_line(muzzle, shot.to, Color(1.0, 0.95, 0.6, 1.0 - t / 0.14), 1.0)
	# 彈殼：往右後方拋物線彈出，落地停一下
	var casing := Art.tex("fx/shell_casing" if weapon == "shotgun" else "fx/casing")
	if casing and t < 0.6:
		var side := Vector2(-dir.y, dir.x)
		var k := minf(t / 0.3, 1.0)
		var p: Vector2 = shot.from + side * (4.0 + 10.0 * k) - dir * 4.0 * k + Vector2(0, -8.0 * k * (1.0 - k) * 4.0 + 3.0 * k)
		draw_texture(casing, p.floor(), Color(1, 1, 1, clampf((0.6 - t) / 0.2, 0.0, 1.0)))


## 睡著的凍眠體：偶爾閃一下結晶的微光，這是和普通屍體唯一的差別。
func _draw_glint(enemy: Enemy) -> void:
	if not (enemy.visible_to_player or debug_enabled):
		return
	var phase := fmod(Time.get_ticks_msec() * 0.001 + float(enemy.enemy_key.hash() % 100) * 0.037, 2.6)
	if phase < 0.18:
		var p := enemy.global_position + Vector2(2, -1)
		draw_rect(Rect2(p, Vector2(1, 1)), Color(0.7, 1.0, 1.0, 0.9))
		draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), Color(0.7, 1.0, 1.0, 0.35))


## 敵人出手前：身上閃紅光，提示玩家快閃開。
func _draw_windup(enemy: Enemy) -> void:
	var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
	draw_arc(enemy.global_position, 9.0, 0.0, TAU, 12, Color(1, 0.2, 0.15, 0.5 + 0.5 * blink), 1.0)


func _on_noise(pos: Vector2, radius: float, _source: Node) -> void:
	_noises.append({"pos": pos, "radius": radius, "t": 0.0})


func _draw_zones() -> void:
	for zone_name in _level.zones:
		var r: Rect2i = _level.zones[zone_name].rect
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
