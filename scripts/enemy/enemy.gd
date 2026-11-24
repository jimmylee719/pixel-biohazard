## 巡邏型敵人（原型）：扇形視野、聽覺、四種狀態。
##
##   未察覺 ──看到／聽到──► 起疑 ──察覺值滿──► 警戒（追擊）
##     ▲                     │                    │
##     │                 查不到東西            追丟主角
##     │                     ▼                    ▼
##     └──────搜索結束────── 搜索 ◄────────────────┘
class_name Enemy
extends CharacterBody2D

signal caught_player
signal state_changed(new_state: State)

enum State { UNAWARE, SUSPICIOUS, ALERT, SEARCH }

const STATE_NAMES := ["UNAWARE", "SUSPICIOUS", "ALERT", "SEARCH"]

@export_group("移動")
@export var patrol_speed := 30.0
@export var investigate_speed := 40.0
@export var chase_speed := 86.0
@export var turn_speed := 5.0
@export var waypoint_wait := 1.2

@export_group("視野")
@export var vision_range := 110.0
@export var vision_half_angle_deg := 35.0
## 這個距離內不管面向哪裡都會察覺（貼身）
@export var proximity_sense := 14.0
## 搜索結束後一段時間內視野變大
@export var vigilance_duration := 20.0
@export var vigilance_range_mult := 1.2

@export_group("察覺值（每秒）")
@export var awareness_rate_far := 0.6
@export var awareness_rate_near := 3.0
@export var awareness_decay := 0.15
@export var suspicious_threshold := 0.25

@export_group("狀態時間")
@export var suspicious_pause := 0.7
@export var lose_sight_time := 2.5
@export var search_duration := 8.0
@export var search_radius := 48.0
@export var catch_distance := 11.0

var state := State.UNAWARE
var awareness := 0.0
var facing := Vector2.RIGHT
var sees_player := false
## 主角目前看不看得到這隻敵人（決定要不要畫出來）
var visible_to_player := false
var patrol_points: Array[Vector2] = []

var _player: Player
var _nav_map := RID()
var _patrol_index := 0
var _patrol_step := 1
var _wait_timer := 0.0
var _state_time := 0.0
var _unseen_time := 0.0
var _investigate_target := Vector2.ZERO
var _last_known := Vector2.ZERO
var _search_points: Array[Vector2] = []
var _vigilance_timer := 0.0
var _look_base_angle := 0.0
var _path_refresh := 0.0
var _spawn := Vector2.ZERO
var _fade := 0.0

@onready var _agent: NavigationAgent2D = $NavigationAgent2D
@onready var _body: Node2D = $Body


func _ready() -> void:
	NoiseBus.noise_emitted.connect(_on_noise)


func setup(points: Array[Vector2], player: Player, nav_map: RID) -> void:
	patrol_points = points
	_player = player
	_nav_map = nav_map
	_spawn = points[0]
	reset()


func reset() -> void:
	global_position = _spawn
	velocity = Vector2.ZERO
	awareness = 0.0
	_patrol_index = 1 if patrol_points.size() > 1 else 0
	_patrol_step = 1
	_wait_timer = 0.0
	_vigilance_timer = 0.0
	facing = (patrol_points[_patrol_index] - global_position).normalized()
	_set_state(State.UNAWARE)


func get_state_name() -> String:
	return STATE_NAMES[state]


## 目前實際的視野距離（受主角亮度、警覺加成影響）。
func get_effective_range() -> float:
	var r := vision_range
	if _player:
		r *= _player.get_detection_range_mult()
	if _vigilance_timer > 0.0:
		r *= vigilance_range_mult
	return r


func get_half_angle() -> float:
	return deg_to_rad(vision_half_angle_deg)


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_state_time += delta
	_vigilance_timer = maxf(_vigilance_timer - delta, 0.0)

	sees_player = _check_vision()
	_update_awareness(delta)
	_check_flashlight_hit()

	match state:
		State.UNAWARE:
			_process_unaware(delta)
		State.SUSPICIOUS:
			_process_suspicious(delta)
		State.ALERT:
			_process_alert(delta)
		State.SEARCH:
			_process_search(delta)

	move_and_slide()
	if velocity.length() > 2.0:
		_turn_toward(velocity.normalized(), delta)
	_update_visibility(delta)


# ── 感知 ──────────────────────────────────────────────

func _check_vision() -> bool:
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	if dist > get_effective_range():
		return false
	if dist > proximity_sense and absf(facing.angle_to(to_player)) > get_half_angle():
		return false
	return Sight.is_clear(self, global_position, _player.global_position)


func _update_awareness(delta: float) -> void:
	if sees_player:
		var dist := global_position.distance_to(_player.global_position)
		var nearness := 1.0 - clampf(dist / get_effective_range(), 0.0, 1.0)
		var rate := lerpf(awareness_rate_far, awareness_rate_near, nearness)
		rate *= _player.get_detection_rate_mult()
		awareness = minf(awareness + rate * delta, 1.0)
		_last_known = _player.global_position
		_unseen_time = 0.0
	else:
		_unseen_time += delta
		if state != State.ALERT:
			awareness = maxf(awareness - awareness_decay * delta, 0.0)


## 手電筒照到敵人：敵人會發現光，轉頭起疑。
func _check_flashlight_hit() -> void:
	if sees_player or state == State.ALERT:
		return
	if _player.is_in_flashlight(global_position) and Sight.is_clear(self, _player.global_position, global_position):
		if state == State.UNAWARE or state == State.SEARCH:
			awareness = maxf(awareness, suspicious_threshold)
			_investigate(_player.global_position)


func _on_noise(pos: Vector2, radius: float, _source: Node) -> void:
	if _player == null:
		return
	var effective := radius
	if not Sight.is_clear(self, global_position, pos):
		effective *= 0.5  # 隔著牆聽得比較不清楚
	if global_position.distance_to(pos) > effective:
		return
	match state:
		State.UNAWARE, State.SEARCH:
			awareness = maxf(awareness, suspicious_threshold + 0.05)
			_investigate(pos)
		State.SUSPICIOUS:
			awareness = minf(awareness + 0.15, 1.0)
			_investigate_target = pos
			_set_agent_target(pos)
		State.ALERT:
			if not sees_player:
				_last_known = pos


# ── 狀態 ──────────────────────────────────────────────

func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_wait_timer = 0.0
	if new_state == State.ALERT:
		awareness = 1.0
	state_changed.emit(new_state)


func _investigate(pos: Vector2) -> void:
	_investigate_target = pos
	_set_agent_target(pos)
	if state != State.SUSPICIOUS:
		_set_state(State.SUSPICIOUS)


func _process_unaware(delta: float) -> void:
	if sees_player and awareness >= suspicious_threshold:
		_investigate(_player.global_position)
		return
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		return
	var target := patrol_points[_patrol_index]
	if global_position.distance_to(target) < 4.0:
		velocity = Vector2.ZERO
		if _wait_timer <= 0.0:
			_look_base_angle = facing.angle()
		_wait_timer += delta
		_look_around(delta, 0.9)
		if _wait_timer >= waypoint_wait:
			_wait_timer = 0.0
			_advance_patrol()
		return
	_move_along_path(target, patrol_speed, delta)


func _advance_patrol() -> void:
	if patrol_points.size() < 2:
		return
	var next := _patrol_index + _patrol_step
	if next < 0 or next >= patrol_points.size():
		_patrol_step = -_patrol_step  # 來回巡邏
		next = _patrol_index + _patrol_step
	_patrol_index = next


func _process_suspicious(delta: float) -> void:
	if awareness >= 1.0:
		_set_state(State.ALERT)
		return
	if sees_player:
		_investigate_target = _player.global_position
	# 先停下來轉頭看，再慢慢走過去
	if _state_time < suspicious_pause:
		velocity = Vector2.ZERO
		_turn_toward((_investigate_target - global_position).normalized(), delta)
		return
	if global_position.distance_to(_investigate_target) < 6.0:
		velocity = Vector2.ZERO
		_wait_timer += delta
		if _wait_timer >= waypoint_wait:
			_start_search(_investigate_target)
		return
	_move_along_path(_investigate_target, investigate_speed, delta)


func _process_alert(delta: float) -> void:
	if global_position.distance_to(_player.global_position) <= catch_distance:
		velocity = Vector2.ZERO
		caught_player.emit()
		return
	if _unseen_time >= lose_sight_time:
		_start_search(_last_known)
		return
	_move_along_path(_last_known, chase_speed, delta)


func _start_search(center: Vector2) -> void:
	_set_state(State.SEARCH)
	_search_points.clear()
	_search_points.append(center)
	for i in 3:
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(search_radius * 0.4, search_radius)
		var p := center + offset
		if _nav_map.is_valid():
			p = NavigationServer2D.map_get_closest_point(_nav_map, p)
		_search_points.append(p)


func _process_search(delta: float) -> void:
	if sees_player and awareness >= 0.5:
		_set_state(State.ALERT)
		return
	if sees_player and awareness >= suspicious_threshold:
		_investigate(_player.global_position)
		return
	if _state_time >= search_duration or _search_points.is_empty():
		_finish_search()
		return
	var target := _search_points[0]
	if global_position.distance_to(target) < 5.0:
		velocity = Vector2.ZERO
		if _wait_timer <= 0.0:
			_look_base_angle = facing.angle()
		_wait_timer += delta
		_look_around(delta, 1.4)
		if _wait_timer >= 1.0:
			_wait_timer = 0.0
			_search_points.pop_front()
		return
	_move_along_path(target, investigate_speed, delta)


func _finish_search() -> void:
	awareness = 0.0
	_vigilance_timer = vigilance_duration
	_patrol_index = _nearest_patrol_index()
	_set_state(State.UNAWARE)


func _nearest_patrol_index() -> int:
	var best := 0
	var best_dist := INF
	for i in patrol_points.size():
		var d := global_position.distance_squared_to(patrol_points[i])
		if d < best_dist:
			best_dist = d
			best = i
	return best


# ── 移動 ──────────────────────────────────────────────

func _set_agent_target(pos: Vector2) -> void:
	_agent.target_position = pos
	_path_refresh = 0.25


func _move_along_path(target: Vector2, speed: float, delta: float) -> void:
	_path_refresh -= delta
	if _path_refresh <= 0.0 or _agent.target_position.distance_to(target) > 8.0:
		_set_agent_target(target)
	var next := _agent.get_next_path_position()
	var dir := next - global_position
	if dir.length() < 0.5:
		# 導航還沒準備好或已經到了：直接朝目標走
		dir = target - global_position
	velocity = dir.normalized() * speed if dir.length() > 0.5 else Vector2.ZERO


func _turn_toward(dir: Vector2, delta: float) -> void:
	if dir == Vector2.ZERO:
		return
	var diff := facing.angle_to(dir)
	var step := clampf(diff, -turn_speed * delta, turn_speed * delta)
	facing = facing.rotated(step).normalized()


## 停下時左右張望。
func _look_around(_delta: float, amplitude: float) -> void:
	var angle := _look_base_angle + sin(_wait_timer * 2.2) * amplitude
	facing = Vector2.RIGHT.rotated(angle)


# ── 顯示 ──────────────────────────────────────────────

## 主角看不到的敵人就不畫出來（淡入淡出）。
func _update_visibility(delta: float) -> void:
	visible_to_player = _player.can_see_point(global_position)
	var target_alpha := 1.0 if visible_to_player else 0.0
	_fade = move_toward(_fade, target_alpha, delta * 6.0)
	_body.modulate.a = _fade
	_body.rotation = facing.angle()
