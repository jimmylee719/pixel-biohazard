## 第一人稱視角（躲在櫃子裡、從窗戶往外看）。
## 用地圖格子做射線投射（像早期的 3D 遊戲），把牆、家具、敵人畫成第一人稱畫面：
## 不用另外做 3D 場景，任何區域都能直接用，而且很省效能（每幀 120 條射線）。
## 櫃子裡：視野窄、很暗、前面有百葉縫，基本上只能「聽」敵人的腳步聲；窗戶：看得比較清楚。
class_name FirstPersonView
extends Control

const W := 480.0
const H := 270.0
const COLS := 120
const MAX_DIST := 18.0
const WALL_HEIGHT := 0.8
## 角色大約是牆高的 0.65
const BODY_HEIGHT := 0.62

var active := false
var mode := ""
## 這一幀畫出來（看得到）的敵人（測試、除錯用）
var visible_enemies: Array[Enemy] = []

var _level: Level
var _origin := Vector2.ZERO
var _dir := Vector2.RIGHT
var _fov := deg_to_rad(66.0)
var _ambient := 0.7
var _zbuf := PackedFloat32Array()
var _hits: Array[Dictionary] = []
var _sprites: Array[Dictionary] = []
var _hint: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_zbuf.resize(COLS)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 3)
	_hint.position = Vector2(0, 30)
	_hint.size = Vector2(W, 14)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)


## from = 眼睛的位置（世界座標），dir = 看的方向。mode：locker、window
func open(level: Level, from: Vector2, dir: Vector2, view_mode: String, hint := "") -> void:
	_level = level
	_origin = from
	_dir = dir.normalized() if dir != Vector2.ZERO else Vector2.DOWN
	mode = view_mode
	active = true
	visible = true
	if mode == "locker":
		_fov = deg_to_rad(62.0)
		_ambient = 0.8
	else:
		_fov = deg_to_rad(70.0)
		_ambient = 0.9 if level.is_lit() or level.outdoor else 0.7
		# 眼睛貼在玻璃上：視點移到整片玻璃的另一側（厚的觀察窗也不會變成隧道）
		var p := from
		for i in 64:
			var ch := level.char_at(level.cell_of(p))
			if ch != "=" and i > 0 and not Level.SOLID_CHARS.contains(ch) and level.char_at(level.cell_of(p - _dir * 6.0)) == "=":
				break
			p += _dir * 4.0
		_origin = p - _dir * 2.0
	_hint.text = hint
	compute()
	queue_redraw()


func close() -> void:
	active = false
	visible = false
	visible_enemies.clear()


func _process(_delta: float) -> void:
	if active:
		compute()
		queue_redraw()


## 算這一幀的牆（每一欄的距離）和看得到的敵人；畫面用 _draw 畫出來
func compute() -> void:
	if _level == null:
		return
	_hits.clear()
	var o := _origin / Level.TILE
	var base_angle := _dir.angle()
	for col in COLS:
		var a := base_angle + (float(col) / COLS - 0.5) * _fov
		var hit := _cast(o, Vector2.from_angle(a))
		hit.perp = maxf(hit.dist * cos(a - base_angle), 0.15)
		_zbuf[col] = hit.perp
		_hits.append(hit)
	_sprites.clear()
	visible_enemies.clear()
	var right := Vector2(-_dir.y, _dir.x)
	var half_tan := tan(_fov * 0.5)
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null:
			continue
		var rel := (e.global_position - _origin) / Level.TILE
		var depth := rel.dot(_dir)
		if depth < 0.3 or depth > MAX_DIST:
			continue
		var sx := W * 0.5 + rel.dot(right) / (depth * half_tan) * W * 0.5
		if sx < -20 or sx > W + 20:
			continue
		var col := clampi(int(sx / (W / COLS)), 0, COLS - 1)
		if _zbuf[col] < depth:
			continue  # 被牆擋住
		visible_enemies.append(e)
		_sprites.append({"e": e, "depth": depth, "sx": sx})
	_sprites.sort_custom(func(a, b): return a.depth > b.depth)  # 遠的先畫


func _draw() -> void:
	if not active or _level == null:
		return
	# 天花板、地板
	var ceiling := Color(0.03, 0.03, 0.05) * _ambient
	ceiling.a = 1.0
	draw_rect(Rect2(0, 0, W, H * 0.5), ceiling)
	for i in 8:
		var k := float(i) / 8.0
		var c := Color(0.16, 0.17, 0.2).lerp(Color(0.05, 0.05, 0.07), 1.0 - k) * _ambient
		c.a = 1.0
		draw_rect(Rect2(0, H * 0.5 + k * H * 0.5, W, H * 0.5 / 8.0 + 1), c)
	_draw_walls()
	_draw_enemies()
	if mode == "locker":
		_draw_locker_slats()
	else:
		_draw_window_frame()


func _draw_walls() -> void:
	var col_w := W / COLS
	for col in _hits.size():
		var hit: Dictionary = _hits[col]
		var perp: float = hit.perp
		var h := H * WALL_HEIGHT / perp
		var top := H * 0.5 - h * 0.55
		var c := _wall_color(hit.ch)
		if hit.side == 1:
			c = c.darkened(0.22)
		c = _shade(c, perp)
		draw_rect(Rect2(floorf(col * col_w), top, ceilf(col_w), h), c)
		# 牆腳的深色線，讓牆和地板分得開
		draw_rect(Rect2(col * col_w, top + h - 1.0, col_w + 0.5, 1.0), c.darkened(0.5))


## 格子射線（DDA）：回傳 {dist, ch, side, glass, glass_dist}
func _cast(o: Vector2, ray: Vector2) -> Dictionary:
	var cell := Vector2i(floori(o.x), floori(o.y))
	var step := Vector2i(1 if ray.x >= 0 else -1, 1 if ray.y >= 0 else -1)
	var delta := Vector2(absf(1.0 / ray.x) if ray.x != 0 else 1e9, absf(1.0 / ray.y) if ray.y != 0 else 1e9)
	var side_dist := Vector2(
		((cell.x + 1 - o.x) if ray.x >= 0 else (o.x - cell.x)) * delta.x,
		((cell.y + 1 - o.y) if ray.y >= 0 else (o.y - cell.y)) * delta.y)
	var side := 0
	var dist := 0.0
	var glass := false
	var glass_dist := 0.0
	var start_ch := _level.char_at(cell)
	while dist < MAX_DIST:
		if side_dist.x < side_dist.y:
			dist = side_dist.x
			side_dist.x += delta.x
			cell.x += step.x
			side = 0
		else:
			dist = side_dist.y
			side_dist.y += delta.y
			cell.y += step.y
			side = 1
		var ch := _level.char_at(cell)
		if ch == "=":
			if not glass and start_ch != "=":
				glass = true
				glass_dist = dist
			continue
		if Level.SOLID_CHARS.contains(ch):
			return {"dist": dist, "ch": ch, "side": side, "glass": glass, "glass_dist": glass_dist}
	return {"dist": MAX_DIST, "ch": "#", "side": side, "glass": glass, "glass_dist": glass_dist}


func _wall_color(ch: String) -> Color:
	match ch:
		"C":
			return Color(0.42, 0.32, 0.22) if not _level.outdoor else Color(0.3, 0.31, 0.34)
		"H":
			return Color(0.3, 0.42, 0.46)
	return Color(0.62, 0.66, 0.74) if _level.outdoor else Color(0.4, 0.43, 0.5)


func _shade(c: Color, dist: float) -> Color:
	var k := _ambient / (1.0 + dist * 0.28)
	return Color(c.r * k, c.g * k, c.b * k, 1.0)


func _draw_enemies() -> void:
	for item in _sprites:
		var e: Enemy = item.e
		if not is_instance_valid(e):
			continue
		var depth: float = item.depth
		var h := H * WALL_HEIGHT * BODY_HEIGHT / depth
		var w := h * 0.6
		var foot := H * 0.5 + H * WALL_HEIGHT / depth * 0.45
		var rect := Rect2(item.sx - w * 0.5, foot - h, w, h)
		if e.is_dead or e.is_dormant:
			rect = Rect2(item.sx - h * 0.5, foot - w * 0.35, h, w * 0.35)  # 躺在地上
		var tex := _enemy_texture(e)
		if tex:
			draw_texture_rect(tex, rect, false, _shade(Color.WHITE, depth))
		else:
			draw_rect(rect, _shade(Color(0.6, 0.62, 0.66), depth))
		# 結晶的微光（凍眠體、怪物）：在黑暗裡也看得到一點點
		if e.faction == "monster" and not e.is_dead:
			draw_rect(Rect2(item.sx - 1, foot - h * 0.8, 2, 2), Color(0.6, 0.9, 1.0, 0.7))


func _enemy_texture(e: Enemy) -> Texture2D:
	if e.sprite_set == "":
		return null
	var to_viewer := (_origin - e.global_position).normalized()
	var d := e.facing.dot(to_viewer)
	var dir := "down" if d > 0.5 else ("up" if d < -0.5 else "right")
	var frame := 0
	if e.velocity.length() > 5.0:
		frame = int(Time.get_ticks_msec() / 160) % 4
	var tex := Art.tex("%s/walk_%s_%d" % [e.sprite_set, dir, frame])
	return tex if tex else Art.tex("%s/walk_down_0" % e.sprite_set)


func _draw_locker_slats() -> void:
	# 百葉門：細細的斜葉片（半透明），從縫隙看得到外面；四周一圈櫃門的暗框
	var y := 6.0
	while y < H:
		draw_rect(Rect2(0, y, W, 3), Color(0.02, 0.025, 0.03, 0.82))
		draw_rect(Rect2(0, y + 3, W, 1), Color(0.18, 0.2, 0.22, 0.55))
		y += 22.0
	var edge := Color(0.015, 0.015, 0.02)
	draw_rect(Rect2(0, 0, 14, H), edge)
	draw_rect(Rect2(W - 14, 0, 14, H), edge)
	draw_rect(Rect2(0, 0, W, 8), edge)
	draw_rect(Rect2(0, H - 10, W, 10), edge)
	# 邊緣往內漸暗（櫃子裡很暗）
	for i in 10:
		var a := 0.5 * (1.0 - i / 10.0)
		draw_rect(Rect2(14 + i * 3, 8, 3, H - 18), Color(0, 0, 0, a))
		draw_rect(Rect2(W - 17 - i * 3, 8, 3, H - 18), Color(0, 0, 0, a))


func _draw_window_frame() -> void:
	var frame := Color(0.12, 0.13, 0.15)
	draw_rect(Rect2(0, 0, W, 14), frame)
	draw_rect(Rect2(0, H - 22, W, 22), frame)
	draw_rect(Rect2(0, 0, 18, H), frame)
	draw_rect(Rect2(W - 18, 0, 18, H), frame)
	draw_rect(Rect2(0, 0, W, H), Color(0.55, 0.75, 0.9, 0.06))  # 玻璃
	draw_rect(Rect2(W * 0.7, 0, 5, H), frame)
	# 玻璃反光
	draw_line(Vector2(60, 30), Vector2(120, 110), Color(1, 1, 1, 0.06), 6.0)
	draw_line(Vector2(300, 40), Vector2(340, 100), Color(1, 1, 1, 0.05), 4.0)
