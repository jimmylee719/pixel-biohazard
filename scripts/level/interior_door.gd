## 室內的自動門（地圖符號 +）：有人走近就打開、沒人就關上。
## 關著的時候擋路、擋視線、擋光（看不到門後面）；開著的時候可以通過、看得到。
## access = 需要的權限等級（不夠的話主角打不開，敵人可以）。
## safe = 通往安全屋的門：敵人進不去（另外有一道只擋敵人的看不見的牆）。
class_name InteriorDoor
extends Node2D

## 關著的門用的圖層（Sight 會把它當牆）
const DOOR_LAYER := 32
## 只擋敵人的圖層（安全屋門口）
const SAFE_BARRIER_LAYER := 16
const OPEN_RADIUS := 15.0
const CLOSE_DELAY := 0.6

signal denied

var access := 0
var safe_door := false
var is_open := false
var cell := Vector2i.ZERO
## 同一道寬門的其他格（一起開關）
var partners: Array[InteriorDoor] = []
## 這一格自己附近有人要通過
var wants_open := false
## 主角把門推開一條縫在偷看（門還是關著的：擋路、擋視線）
var ajar := false
## 潛行的主角往門推了多久（推夠久才開）
var _push_t := 0.0
const QUIET_PUSH_TIME := 0.3

var _body: StaticBody2D
var _shape: CollisionShape2D
var _occluder: LightOccluder2D
var _close_timer := 0.0
var _denied_shown := false
var _horizontal := true


## horizontal = 門板橫的（左右是牆、上下通行）
func setup(door_cell: Vector2i, horizontal: bool, need_access: int, is_safe: bool) -> void:
	cell = door_cell
	_horizontal = horizontal
	access = need_access
	safe_door = is_safe
	position = (Vector2(cell) + Vector2(0.5, 0.5)) * Level.TILE


func _ready() -> void:
	_body = StaticBody2D.new()
	_body.collision_layer = DOOR_LAYER
	_body.collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(Level.TILE, Level.TILE)
	_shape.shape = rect
	_body.add_child(_shape)
	add_child(_body)
	_occluder = LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	var h := Level.TILE * 0.5
	poly.polygon = PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	_occluder.occluder = poly
	add_child(_occluder)
	z_index = 1
	queue_redraw()


func is_horizontal() -> bool:
	return _horizontal


func _physics_process(delta: float) -> void:
	var want := false
	var player_near := false
	var pushing := false
	for node in get_tree().get_nodes_in_group("door_users"):
		var n := node as Node2D
		if n == null or n.global_position.distance_to(global_position) > OPEN_RADIUS:
			continue
		if n is Player:
			if n.is_hiding:
				continue
			player_near = true
			if access > WorldState.access_level:
				if not _denied_shown:
					_denied_shown = true
					denied.emit()
				continue
			# 潛行靠近門：門不會自己開（才有機會先聽、先從門縫看）。往門的方向推一下才開
			if n.is_quiet() and not is_open:
				var to_door: Vector2 = (global_position - n.global_position).normalized()
				if n.move_intent.dot(to_door) > 0.55:
					pushing = true
					if _push_t >= QUIET_PUSH_TIME:
						want = true
				continue
			want = true
		elif n is Enemy:
			var e := n as Enemy
			if e.is_dead or e.is_dormant or safe_door:
				continue
			want = true
	_push_t = _push_t + delta if pushing else 0.0
	if not player_near:
		_denied_shown = false
	wants_open = want
	for p in partners:
		if p.wants_open:
			want = true
	if want:
		_close_timer = CLOSE_DELAY
		if not is_open:
			_set_open(true)
	elif is_open:
		_close_timer -= delta
		if _close_timer <= 0.0:
			_set_open(false)


func _set_open(on: bool) -> void:
	is_open = on
	_shape.set_deferred("disabled", on)
	_occluder.visible = not on
	Sfx.play("door_open" if on else "locker_close", global_position, 0.08, -8.0)
	queue_redraw()


func _draw() -> void:
	var h := Level.TILE * 0.5
	var frame := Color(0.18, 0.2, 0.24)
	var panel := Color(0.42, 0.36, 0.24) if not safe_door else Color(0.35, 0.45, 0.4)
	if access > 0:
		panel = Color(0.5, 0.3, 0.25)
	if is_open:
		# 開著：門板縮到兩邊
		if _horizontal:
			draw_rect(Rect2(-h, -h + 5, 3, 6), panel)
			draw_rect(Rect2(h - 3, -h + 5, 3, 6), panel)
		else:
			draw_rect(Rect2(-h + 5, -h, 6, 3), panel)
			draw_rect(Rect2(-h + 5, h - 3, 6, 3), panel)
		return
	draw_rect(Rect2(-h, -h, Level.TILE, Level.TILE), frame)
	if ajar:
		# 推開一條縫：門板中間留一道黑縫
		if _horizontal:
			draw_rect(Rect2(-h + 1, -h + 4, Level.TILE - 2, 8), panel)
			draw_rect(Rect2(-2, -h + 4, 3, 8), Color(0.02, 0.02, 0.03))
		else:
			draw_rect(Rect2(-h + 4, -h + 1, 8, Level.TILE - 2), panel)
			draw_rect(Rect2(-h + 4, -2, 8, 3), Color(0.02, 0.02, 0.03))
		return
	if _horizontal:
		draw_rect(Rect2(-h + 1, -h + 4, Level.TILE - 2, 8), panel)
		draw_line(Vector2(0, -h + 4), Vector2(0, -h + 12), frame, 1.0)
	else:
		draw_rect(Rect2(-h + 4, -h + 1, 8, Level.TILE - 2), panel)
		draw_line(Vector2(-h + 4, 0), Vector2(-h + 12, 0), frame, 1.0)
	if access > 0:
		draw_rect(Rect2(h - 4, -2, 2, 4), Color(1, 0.3, 0.2) if access > WorldState.access_level else Color(0.3, 1, 0.4))
