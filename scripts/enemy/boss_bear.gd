## 中期 Boss「苔原之母」：被感染的北極熊。
## 全盲、聽覺極好。聽到大的聲音就朝聲音的方向直線衝撞；撞到柱子或牆會暈眩，這時受到的傷害比較高。
## 靠近時會揮爪。冷的時候（關掉機庫暖氣）所有動作都會變慢。
## 沿用 Enemy 的聽覺、受傷、死亡記錄、畫面顯示，只換掉行動邏輯。
class_name BossBear
extends Enemy

enum Phase { ROAM, WINDUP, CHARGE, STUNNED, SWIPE, RECOVER }

@export var boss_id := "tundra_mother"

@export_group("Boss 行動")
@export var roam_speed := 24.0
@export var stalk_speed := 44.0
@export var charge_speed := 210.0
@export var charge_windup := 0.8
@export var charge_max_distance := 320.0
## 聲音在這個距離內就會直接衝過去
@export var charge_trigger_range := 180.0
@export var charge_damage := 40.0
@export var charge_infection := 25.0
@export var stun_time := 2.2
@export var stun_damage_mult := 1.5
@export var swipe_range := 24.0
@export var swipe_windup := 0.5
@export var swipe_damage := 30.0
@export var swipe_infection := 20.0
@export var swipe_cooldown := 1.2
## 走路／奔跑的主角在這個距離內會被感覺到（潛行不會）
@export var boss_feel_range := 56.0
@export var recover_time := 0.6

var phase := Phase.ROAM

var _phase_time := 0.0
var _charge_dir := Vector2.ZERO
var _charge_from := Vector2.ZERO
var _charge_hit := false
var _target := Vector2.ZERO
var _has_target := false
var _swipe_cd := 0.0
var _roam_timer := 0.0


func reset() -> void:
	super.reset()
	if not is_dead:
		_set_phase(Phase.ROAM)
		_has_target = false


func is_watching_player() -> bool:
	return false


func can_be_taken_down_by(_player_node: Player) -> bool:
	return false


func is_stunned() -> bool:
	return phase == Phase.STUNNED


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	if is_dead:
		_update_visibility(delta)
		return
	in_cold = _level != null and _level.is_cold(global_position)
	var slow := cold_speed_mult if in_cold else 1.0
	_phase_time += delta
	_swipe_cd = maxf(_swipe_cd - delta, 0.0)
	_feel_player()
	winding_up = phase == Phase.WINDUP or phase == Phase.SWIPE
	state = State.UNAWARE if phase == Phase.ROAM and not _has_target else State.ALERT
	awareness = 0.0 if state == State.UNAWARE else 1.0

	var moved := false
	match phase:
		Phase.ROAM:
			_process_roam(delta, slow)
		Phase.WINDUP:
			velocity = Vector2.ZERO
			_turn_toward(_charge_dir, delta * 3.0)
			if _phase_time >= charge_windup / slow:
				_charge_from = global_position
				_charge_hit = false
				_set_phase(Phase.CHARGE)
		Phase.CHARGE:
			velocity = _charge_dir * charge_speed * slow
			move_and_slide()
			moved = true
			if not _charge_hit and _can_hit(18.0):
				_charge_hit = true
				_player.take_hit(charge_damage, charge_infection, global_position)
			if get_slide_collision_count() > 0:
				_set_phase(Phase.STUNNED)  # 撞到牆或柱子
			elif global_position.distance_to(_charge_from) >= charge_max_distance:
				_set_phase(Phase.RECOVER)
		Phase.STUNNED:
			velocity = Vector2.ZERO
			if _phase_time >= stun_time:
				_set_phase(Phase.RECOVER)
		Phase.SWIPE:
			velocity = Vector2.ZERO
			_turn_toward((_player.global_position - global_position).normalized(), delta * 2.0)
			if _phase_time >= swipe_windup / slow:
				if _can_hit(swipe_range + 6.0):
					_player.take_hit(swipe_damage, swipe_infection, global_position)
				_swipe_cd = swipe_cooldown
				_set_phase(Phase.RECOVER)
		Phase.RECOVER:
			velocity = Vector2.ZERO
			if _phase_time >= recover_time / slow:
				_set_phase(Phase.ROAM)

	if not moved:
		move_and_slide()
	if velocity.length() > 2.0:
		_turn_toward(velocity.normalized(), delta)
	_update_visibility(delta)


func _process_roam(delta: float, _slow: float) -> void:
	if _swipe_cd <= 0.0 and _can_hit(swipe_range):
		_set_phase(Phase.SWIPE)
		return
	if _has_target:
		if global_position.distance_to(_target) < 10.0:
			_has_target = false
		else:
			_move_along_path(_target, stalk_speed, delta)  # 冷的時候 _move_along_path 會自己變慢
		return
	# 沒有聲音的時候：在機庫裡慢慢徘徊
	_roam_timer -= delta
	if _roam_timer <= 0.0:
		_roam_timer = randf_range(2.5, 4.5)
		var center := _spawn
		_target = center + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(20.0, 80.0)
		if _nav_map.is_valid():
			_target = NavigationServer2D.map_get_closest_point(_nav_map, _target)
	_move_along_path(_target, roam_speed, delta)


func _can_hit(reach: float) -> bool:
	return not _player.is_dead and not _player.is_hiding \
		and global_position.distance_to(_player.global_position) <= reach


## 走路或奔跑的腳步震動
func _feel_player() -> void:
	if _player.is_hiding or _player.is_dead:
		return
	if _player.gait != Player.Gait.WALK and _player.gait != Player.Gait.RUN:
		return
	if global_position.distance_to(_player.global_position) <= boss_feel_range:
		_hear(_player.global_position)


func _on_noise(pos: Vector2, radius: float, source: Node) -> void:
	if _player == null or source == self or is_dead:
		return
	var effective := radius * hearing_mult
	if not Sight.is_clear(self, global_position, pos):
		effective *= 0.5
	if global_position.distance_to(pos) <= effective:
		_hear(pos)


## 聽到聲音：近的話直接衝過去，遠的話走過去。
func _hear(pos: Vector2) -> void:
	_target = pos
	_has_target = true
	if phase == Phase.ROAM and global_position.distance_to(pos) <= charge_trigger_range \
			and global_position.distance_to(pos) > swipe_range:
		_charge_dir = (pos - global_position).normalized()
		_set_phase(Phase.WINDUP)


func _set_phase(p: Phase) -> void:
	phase = p
	_phase_time = 0.0


func take_damage(amount: float, from_pos: Vector2, _stagger: float) -> void:
	if is_dead:
		return
	if phase == Phase.STUNNED:
		amount *= stun_damage_mult
	health -= amount
	if health <= 0.0:
		_die()
		return
	_hear(from_pos)  # 被打到就知道你在哪


func _die() -> void:
	super._die()
	WorldState.set_flag("defeated:" + boss_id)
	WorldState.emit_event("defeat", boss_id)
