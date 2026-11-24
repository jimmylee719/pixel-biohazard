## 感染者（敵人）共用腳本：視野、聽覺、震動感應、四種狀態、溫度影響。
## 不同種類只靠 @export 參數和場景外觀區分：
##   - 值班者（巡邏型）：有視野、會被手電筒吸引
##   - 鳴骨者（聽覺型）：全盲、聽覺極好、會感覺到附近的腳步震動、進入警戒時尖鳴呼叫同類
##   - 凍眠體（伏擊型）：躺著像屍體（dormant），有人走過、附近有聲音、或區域暖起來就會醒
##
##   未察覺 ──看到／聽到──► 起疑 ──察覺值滿──► 警戒（追擊）
##     ▲                     │                    │
##     │                 查不到東西            追丟主角
##     │                     ▼                    ▼
##     └──────搜索結束────── 搜索 ◄────────────────┘
class_name Enemy
extends CharacterBody2D

signal state_changed(new_state: State)
signal died

enum State { UNAWARE, SUSPICIOUS, ALERT, SEARCH }

const STATE_NAMES := ["UNAWARE", "SUSPICIOUS", "ALERT", "SEARCH"]
const TILE := 16.0

@export var display_name := "Watcher"

@export_group("移動")
@export var patrol_speed := 30.0
@export var investigate_speed := 40.0
@export var chase_speed := 86.0
@export var turn_speed := 5.0
@export var waypoint_wait := 1.2

@export_group("視覺")
@export var has_sight := true
@export var reacts_to_light := true
@export var vision_range := 110.0
@export var vision_half_angle_deg := 35.0
## 這個距離內不管面向哪裡都會察覺（貼身）
@export var proximity_sense := 14.0
## 搜索結束後一段時間內視野變大
@export var vigilance_duration := 20.0
@export var vigilance_range_mult := 1.2

@export_group("聽覺與其他感知")
@export var hearing_mult := 1.0
## 聽到聲音時增加的察覺值
@export var noise_awareness_gain := 0.15
## 震動感應：這個距離內走路或奔跑的主角會被察覺（潛行不會）；0 = 沒有
@export var feel_radius := 0.0
@export var feel_rate := 2.5
## 進入警戒時尖鳴、呼叫附近同類的半徑（格）；0 = 不會
@export var shriek_radius_tiles := 0.0
## 回聲定位喀喀聲的間隔（秒）；0 = 不發出。只是給玩家的「聲音提示」，不影響其他敵人
@export var click_interval := 0.0

@export_group("察覺值（每秒）")
@export var awareness_rate_far := 0.6
@export var awareness_rate_near := 3.0
@export var awareness_decay := 0.15
@export var suspicious_threshold := 0.25

@export_group("狀態時間")
@export var suspicious_pause := 0.7
@export var lose_contact_time := 2.5
@export var search_duration := 8.0
@export var search_radius := 48.0
@export var catch_distance := 11.0

@export_group("生命與攻擊")
@export var max_health := 80.0
@export var attack_damage := 22.0
@export var attack_infection := 15.0
## 距離多近開始出手（出手前有預備動作，給玩家反應時間）
@export var attack_range := 15.0
@export var attack_reach := 20.0
@export var attack_windup := 0.45
@export var attack_cooldown := 1.0
## 從背後被偷襲時，主角要在牠背後多大的角度內（度）
@export var takedown_back_angle_deg := 110.0

@export_group("休眠（凍眠體）")
## 一開始是躺著睡著的
@export var dormant := false
## 走路或奔跑經過這個距離內就會醒（潛行不會）
@export var wake_radius := 30.0
## 從地上爬起來的時間（這段時間內不會攻擊）
@export var rise_time := 0.7

@export_group("溫度（沒開暖氣的區域）")
@export var cold_speed_mult := 0.55
@export var cold_awareness_mult := 0.6

var state := State.UNAWARE
var awareness := 0.0
var facing := Vector2.RIGHT
var sees_player := false
## 主角目前看不看得到這隻敵人（決定要不要畫出來）
var visible_to_player := false
var patrol_points: Array[Vector2] = []
var in_cold := false
## 距離上一次喀喀聲過了幾秒（除錯顯示和聲音提示用）
var click_age := 99.0
var health := 80.0
var is_dead := false
## 正在休眠（凍眠體）：看起來像屍體，不會動、不會被自動鎖定
var is_dormant := false
## 正在出手的預備動作（畫面提示用）
var winding_up := false
## 用來記錄「這隻已經死了」的 id（區域:編號），由 main 設定
var enemy_key := ""

var _player: Player
var _level: Level
var _nav_map := RID()
var _patrol_index := 0
var _patrol_step := 1
var _wait_timer := 0.0
var _state_time := 0.0
var _no_contact_time := 0.0
var _investigate_target := Vector2.ZERO
var _last_known := Vector2.ZERO
var _search_points: Array[Vector2] = []
var _vigilance_timer := 0.0
var _look_base_angle := 0.0
var _path_refresh := 0.0
var _spawn := Vector2.ZERO
var _fade := 0.0
var _click_timer := 0.0
var _stagger := 0.0
var _windup := 0.0
var _attack_cd := 0.0
var _body_color := Color.WHITE

@onready var _agent: NavigationAgent2D = $NavigationAgent2D
@onready var _body: Node2D = $Body


func _ready() -> void:
	add_to_group("enemies")
	var square := _body.get_child(0) as Polygon2D
	if square:
		_body_color = square.color
	NoiseBus.noise_emitted.connect(_on_noise)
	_click_timer = randf() * maxf(click_interval, 0.1)


func setup(points: Array[Vector2], player: Player, level: Level) -> void:
	patrol_points = points
	_player = player
	_level = level
	_nav_map = level.get_navigation_map()
	_spawn = points[0]
	reset()


func reset() -> void:
	global_position = _spawn
	_stagger = 0.0
	_windup = 0.0
	winding_up = false
	_attack_cd = 0.0
	if enemy_key != "" and WorldState.is_enemy_dead(enemy_key):
		global_position = WorldState.enemy_death_position(enemy_key, _spawn)
		_apply_dead_state()
		return
	_revive()
	is_dormant = dormant
	if is_dormant:
		facing = Vector2.RIGHT
		_set_body_color(_body_color.darkened(0.6))
		_body.scale = Vector2(1.2, 0.6)
		_set_details_visible(false)  # 睡著時藏起結晶，看起來和普通屍體一樣
	velocity = Vector2.ZERO
	awareness = 0.0
	_patrol_index = 1 if patrol_points.size() > 1 else 0
	_patrol_step = 1
	_wait_timer = 0.0
	_vigilance_timer = 0.0
	_no_contact_time = 0.0
	if patrol_points.size() > 1:
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


## 主角躲進櫃子的那一刻，這隻敵人算不算「看到了」。
func is_watching_player() -> bool:
	if is_dormant:
		return false
	if sees_player and (state == State.SUSPICIOUS or state == State.ALERT):
		return true
	# 聽覺型在警戒中、而且就在旁邊，會聽到你鑽進櫃子
	return state == State.ALERT and global_position.distance_to(_player.global_position) <= 3.0 * TILE


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	if is_dead:
		_update_visibility(delta)
		return
	if is_dormant:
		in_cold = _level != null and _level.is_cold(global_position)
		_check_wake()
		_update_visibility(delta)
		return
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	if _stagger > 0.0:
		_stagger -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		move_and_slide()
		_update_visibility(delta)
		return
	in_cold = _level != null and _level.is_cold(global_position)
	_state_time += delta
	_vigilance_timer = maxf(_vigilance_timer - delta, 0.0)
	_no_contact_time += delta

	sees_player = _check_vision()
	_update_awareness(delta)
	_check_feel(delta)
	_check_flashlight_hit()
	_update_clicks(delta)

	if _process_attack(delta):
		move_and_slide()
		_update_visibility(delta)
		return

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
	if not has_sight or _player.is_hiding:
		return false
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	if dist > get_effective_range():
		return false
	if dist > proximity_sense and absf(facing.angle_to(to_player)) > get_half_angle():
		return false
	return Sight.is_clear(self, global_position, _player.global_position)


func _awareness_mult() -> float:
	return cold_awareness_mult if in_cold else 1.0


func _update_awareness(delta: float) -> void:
	if sees_player:
		var dist := global_position.distance_to(_player.global_position)
		var nearness := 1.0 - clampf(dist / get_effective_range(), 0.0, 1.0)
		var rate := lerpf(awareness_rate_far, awareness_rate_near, nearness)
		rate *= _player.get_detection_rate_mult() * _awareness_mult()
		awareness = minf(awareness + rate * delta, 1.0)
		_make_contact(_player.global_position)
	elif state != State.ALERT and _no_contact_time > 0.5:
		awareness = maxf(awareness - awareness_decay * delta, 0.0)


## 震動感應：走路、奔跑的腳步會被附近的聽覺型察覺；潛行不會。
func _check_feel(delta: float) -> void:
	if feel_radius <= 0.0 or _player.is_hiding:
		return
	if _player.gait != Player.Gait.WALK and _player.gait != Player.Gait.RUN:
		return
	if global_position.distance_to(_player.global_position) > feel_radius:
		return
	awareness = minf(awareness + feel_rate * _awareness_mult() * delta, 1.0)
	_make_contact(_player.global_position)
	if state == State.UNAWARE or state == State.SEARCH:
		_investigate(_player.global_position)


## 手電筒照到敵人：有視覺的敵人會發現光，轉頭起疑。
func _check_flashlight_hit() -> void:
	if not has_sight or not reacts_to_light or sees_player or state == State.ALERT:
		return
	if _player.is_in_flashlight(global_position) and Sight.is_clear(self, _player.global_position, global_position):
		if state == State.UNAWARE or state == State.SEARCH:
			awareness = maxf(awareness, suspicious_threshold)
			_investigate(_player.global_position)


func _on_noise(pos: Vector2, radius: float, source: Node) -> void:
	if _player == null or source == self or is_dead:
		return
	var effective := radius * hearing_mult
	if not Sight.is_clear(self, global_position, pos):
		effective *= 0.5  # 隔著牆聽得比較不清楚
	if global_position.distance_to(pos) > effective:
		return
	if is_dormant:
		wake(pos)
		return
	var is_call := source is Enemy  # 同類的尖鳴：只會過去看看，不會直接警戒
	match state:
		State.UNAWARE, State.SEARCH:
			awareness = maxf(awareness, suspicious_threshold + 0.05)
			if not is_call:
				awareness = minf(awareness + noise_awareness_gain * _awareness_mult(), 0.95)
			_investigate(pos)
		State.SUSPICIOUS:
			if not is_call:
				awareness = minf(awareness + noise_awareness_gain * _awareness_mult(), 1.0)
			_investigate_target = pos
			_set_agent_target(pos)
		State.ALERT:
			if not is_call and not sees_player:
				_make_contact(pos)


func _make_contact(pos: Vector2) -> void:
	_last_known = pos
	_no_contact_time = 0.0


func _update_clicks(delta: float) -> void:
	click_age += delta
	if click_interval <= 0.0:
		return
	_click_timer -= delta
	if _click_timer <= 0.0:
		# 越緊張喀喀聲越快；冷的時候變慢
		var interval := click_interval * (0.4 if state == State.ALERT else 1.0)
		if in_cold:
			interval *= 1.6
		_click_timer = interval
		click_age = 0.0


# ── 攻擊、受傷、死亡 ──────────────────────────────────

## 回傳 true = 這一幀在出手（預備動作中），不做一般的狀態行為。
func _process_attack(delta: float) -> bool:
	if _windup > 0.0:
		_windup -= delta
		velocity = Vector2.ZERO
		_turn_toward((_player.global_position - global_position).normalized(), delta * 2.0)
		if _windup <= 0.0:
			winding_up = false
			_attack_cd = attack_cooldown
			if _can_hit_player(attack_reach):
				_player.take_hit(attack_damage, attack_infection, global_position)
		return true
	if _attack_cd <= 0.0 and not _player.is_dead and _can_hit_player(attack_range):
		_windup = attack_windup
		winding_up = true
		velocity = Vector2.ZERO
		return true
	return false


func _can_hit_player(reach: float) -> bool:
	if _player.is_dead:
		return false
	var dist := global_position.distance_to(_player.global_position)
	if _player.is_hiding:
		# 躲在櫃子裡：只有被看到躲進去才會被拖出來；櫃子本身擋路，站在櫃門前就算搆得到
		return _player.hide_spotted and state != State.UNAWARE and dist <= reach + 10.0
	return state == State.ALERT and dist <= reach


## 被攻擊。stagger = 硬直秒數（會打斷出手）。
func take_damage(amount: float, from_pos: Vector2, stagger: float) -> void:
	if is_dead:
		return
	health -= amount
	if is_dormant and health > 0.0:
		wake(from_pos)
	if health <= 0.0:
		_die()
		return
	_stagger = stagger
	_windup = 0.0
	winding_up = false
	velocity = (global_position - from_pos).normalized() * 60.0
	# 被打就知道你在哪了
	awareness = 1.0
	_make_contact(from_pos)
	if state != State.ALERT:
		_set_state(State.ALERT)


# ── 休眠（凍眠體）────────────────────────────────────

## 睡著時：區域變暖、或有人走路／奔跑經過、或貼得太近就會醒。
func _check_wake() -> void:
	if not in_cold and _level != null and _level.zone_at(global_position) != "":
		wake(global_position)  # 暖氣恢復：霜鳴菌甦醒
		return
	if _player.is_hiding or _player.is_dead:
		return
	var dist := global_position.distance_to(_player.global_position)
	var loud_steps := _player.gait == Player.Gait.WALK or _player.gait == Player.Gait.RUN
	if (loud_steps and dist <= wake_radius) or dist <= proximity_sense * 0.6:
		wake(_player.global_position)


## 醒來：先花一點時間爬起來，然後直接進入警戒。
func wake(toward: Vector2) -> void:
	if not is_dormant:
		return
	is_dormant = false
	_set_body_color(_body_color)
	_body.scale = Vector2.ONE
	_set_details_visible(true)
	_stagger = rise_time
	facing = (toward - global_position).normalized() if toward != global_position else facing
	awareness = 1.0
	_make_contact(toward)
	_set_state(State.ALERT)


## 能不能從背後偷襲：沒察覺主角、而且主角在牠背後（睡著的凍眠體一定可以）。
func can_be_taken_down_by(player: Player) -> bool:
	if is_dead:
		return false
	if is_dormant:
		return true
	if state != State.UNAWARE or sees_player:
		return false
	if not has_sight:
		return true  # 看不到的敵人只要沒察覺就可以
	var to_player := player.global_position - global_position
	return absf(facing.angle_to(to_player)) >= deg_to_rad(takedown_back_angle_deg)


func _die() -> void:
	if enemy_key != "":
		WorldState.mark_enemy_dead(enemy_key, global_position)
	_apply_dead_state()
	died.emit()


func _apply_dead_state() -> void:
	is_dead = true
	health = 0.0
	velocity = Vector2.ZERO
	winding_up = false
	awareness = 0.0
	state = State.UNAWARE
	remove_from_group("enemies")
	collision_layer = 0
	_set_body_color(_body_color.darkened(0.6))
	_body.scale = Vector2(1.2, 0.6)


func _revive() -> void:
	is_dead = false
	health = max_health
	if not is_in_group("enemies"):
		add_to_group("enemies")
	collision_layer = 4
	_set_body_color(_body_color)
	_body.scale = Vector2.ONE


## 身體以外的細節（眼睛、結晶）
func _set_details_visible(on: bool) -> void:
	for i in range(1, _body.get_child_count()):
		_body.get_child(i).visible = on


func _set_body_color(c: Color) -> void:
	var square := _body.get_child(0) as Polygon2D
	if square:
		square.color = c


# ── 狀態 ──────────────────────────────────────────────

func _set_state(new_state: State) -> void:
	var previous := state
	state = new_state
	_state_time = 0.0
	_wait_timer = 0.0
	if new_state == State.ALERT:
		awareness = 1.0
		if previous != State.ALERT and shriek_radius_tiles > 0.0:
			NoiseBus.emit_noise(global_position, shriek_radius_tiles * TILE, self)
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
		_look_around(0.9)
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
	if _player.is_hiding and _player.hide_spotted:
		_make_contact(_player.global_position)  # 看到你躲進哪個櫃子了
	if _no_contact_time >= lose_contact_time:
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
	if awareness >= 0.5 and _no_contact_time < 0.1:
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
		_look_around(1.4)
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
	if in_cold:
		speed *= cold_speed_mult
	velocity = dir.normalized() * speed if dir.length() > 0.5 else Vector2.ZERO


func _turn_toward(dir: Vector2, delta: float) -> void:
	if dir == Vector2.ZERO:
		return
	var rate := turn_speed * (cold_speed_mult if in_cold else 1.0)
	var diff := facing.angle_to(dir)
	var step := clampf(diff, -rate * delta, rate * delta)
	facing = facing.rotated(step).normalized()


## 停下時左右張望。
func _look_around(amplitude: float) -> void:
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
