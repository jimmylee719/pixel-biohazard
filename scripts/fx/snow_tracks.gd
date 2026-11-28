## 雪地上的腳印（v0.11）：主角在戶外的雪地走路會留下腳印，一段時間後被雪蓋掉（暴風雪蓋得很快）。
## 看得見的敵人（人類、獵犬）走到新鮮的腳印旁邊會起疑，順著腳印往最新的那一個找過去。
## 一個 Level 一個（Level 建立），畫在地板上、角色下面。
class_name SnowTracks
extends Node2D

## 腳印多久之後完全消失（秒，晴天；下雪、暴風雪依 Weather 的 tracks 倍率變快）
const LIFETIME := 90.0
## 走多遠留一個腳印（像素）
const STRIDE := 7.0
## 敵人在多遠內注意得到腳印（像素）；獵犬靠鼻子，遠很多
const NOTICE := 22.0
const NOTICE_HOUND := 56.0
## 腳印要多新才會被注意到（秒）
const FRESH := 60.0
const MAX_PRINTS := 400

var level: Level
## [{pos, dir, age, left}]
var prints: Array[Dictionary] = []
var _last_pos := Vector2.INF
var _left := false
var _noticed := {}
## 有敵人順著腳印找過來過（第一次會來電提醒）
var followed := false


func _ready() -> void:
	pass


## 主角目前位置留腳印（main 每幀呼叫）
func step(player: Player) -> void:
	if level == null or player.is_hiding or player.is_dead:
		_last_pos = Vector2.INF
		return
	var pos := player.global_position
	var cell := level.cell_of(pos)
	if level._is_indoor_cell(cell) or level.floor_kind_at(cell) != "snow":
		_last_pos = Vector2.INF
		return
	if _last_pos == Vector2.INF:
		_last_pos = pos
		return
	var d := pos.distance_to(_last_pos)
	if d < STRIDE:
		return
	var dir := (pos - _last_pos).normalized()
	_last_pos = pos
	_left = not _left
	prints.append({"pos": pos + dir.orthogonal() * (1.5 if _left else -1.5), "dir": dir, "age": 0.0, "left": _left})
	if prints.size() > MAX_PRINTS:
		prints.pop_front()
	queue_redraw()


func _process(delta: float) -> void:
	if prints.is_empty():
		return
	var rate := float(Weather.value("tracks"))
	var i := 0
	while i < prints.size():
		prints[i].age += delta * rate
		if prints[i].age >= LIFETIME:
			prints.remove_at(i)
		else:
			i += 1
	_notice_check()
	queue_redraw()


## 最新的腳印（敵人要追的方向）
func newest() -> Dictionary:
	return prints[-1] if not prints.is_empty() else {}


## 看得到的敵人走到腳印旁邊：起疑、往最新的腳印找過去（每隻敵人 6 秒最多一次）
func _notice_check() -> void:
	var now := Time.get_ticks_msec()
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.is_dead or e.is_dormant or not e.has_sight or e.is_boss():
			continue
		if e.state != Enemy.State.UNAWARE and e.state != Enemy.State.SEARCH:
			continue
		if _noticed.get(e.get_instance_id(), 0) > now:
			continue
		var reach := NOTICE_HOUND if e.step_style == "paw" else NOTICE
		var hit := false
		for p in prints:
			if p.age < FRESH and e.global_position.distance_to(p.pos) < reach:
				hit = true
				break
		if hit:
			_noticed[e.get_instance_id()] = now + 6000
			e.notice_tracks(newest().pos)
			followed = true


func _draw() -> void:
	for p in prints:
		var a := clampf(1.0 - p.age / LIFETIME, 0.0, 1.0) * 0.55
		var dir: Vector2 = p.dir
		var side := dir.orthogonal()
		var c: Vector2 = p.pos
		var col := Color(0.42, 0.5, 0.62, a)
		# 一個鞋印：前掌＋鞋跟（2 個小橢圓，順著走路方向）
		draw_colored_polygon(_oval(c + dir * 1.2, dir, side, 1.6, 1.1), col)
		draw_colored_polygon(_oval(c - dir * 1.4, dir, side, 1.0, 0.9), col)


func _oval(c: Vector2, dir: Vector2, side: Vector2, rl: float, rw: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 6:
		var a := TAU * k / 6.0
		pts.append(c + dir * cos(a) * rl + side * sin(a) * rw)
	return pts
