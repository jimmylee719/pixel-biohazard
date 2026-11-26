## 郵輪 Boss「典獄長」（守門派的狙擊手指揮官）：在暴風雪的頂層甲板上，從三個制高點輪流狙擊。
## 原創的狙擊對決（不是硬碰硬）：
## - 瞄準：看得到主角時，紅色雷射一點一點移過去鎖定（lock_time 秒），鎖定完就開槍。躲到救生艇、煙囪後面 = 雷射跟丟。
## - 開槍之後要拉槍機（RELOAD）：這時雷射熄掉、他站著不動，是靠近或還擊的機會（受到的傷害較高）。
## - 開兩槍、或被打痛了，就跑到下一個制高點（RELOCATE）。主角太靠近也會跑。
## - 他靠聽的找人：看不到主角時，聽到聲音就把雷射掃過去，對著聲音開槍（丟空瓶 = 騙他浪費一發子彈）。
## - 血量剩一半以下：開始丟照明彈（下一槍之前，整片甲板亮起來，更難躲）。
## 沿用 Enemy 的受傷、死亡、畫面顯示（守門派的圖，白色雪地迷彩），行動邏輯全部覆寫。
class_name BossWarden
extends Enemy

enum Phase { AIM, RELOAD, RELOCATE }

@export var boss_id := "warden"

@export_group("Boss 行動")
@export var lock_time := 1.5
@export var shot_damage := 42.0
@export var reload_time := 2.2
@export var reload_damage_mult := 1.6
@export var relocate_speed := 96.0
@export var sight_range := 420.0
@export var flee_range := 44.0

var phase := Phase.AIM
var lock := 0.0
## 雷射現在指著的位置
var laser_at := Vector2.ZERO
var shots_fired := 0
var stage := 1
var _phase_time := 0.0
var _perch := 0
var _shots_here := 0
var _hurt_here := 0.0
var _noise_target: Variant = null
var _laser: Line2D
var _flare_time := 0.0


func _ready() -> void:
	super._ready()
	_laser = Line2D.new()
	_laser.top_level = true
	_laser.width = 1.0
	_laser.default_color = Color(1.0, 0.15, 0.1, 0.8)
	_laser.z_index = 4
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_laser.material = unshaded
	add_child(_laser)


func reset() -> void:
	super.reset()
	phase = Phase.AIM
	lock = 0.0
	_perch = 0
	_shots_here = 0
	_hurt_here = 0.0
	shots_fired = 0
	stage = 1
	_noise_target = null
	if not patrol_points.is_empty():
		global_position = patrol_points[0]
	laser_at = global_position


func is_boss() -> bool:
	return true


func boss_suffix() -> String:
	return "  (RELOADING)" if phase == Phase.RELOAD else ""


func can_be_taken_down_by(_player_node: Player) -> bool:
	return false


func is_watching_player() -> bool:
	return phase == Phase.AIM and _sees_player()


func _sees_player() -> bool:
	if _player.is_dead or _player.is_hiding:
		return false
	var d := global_position.distance_to(_player.global_position)
	if d > sight_range:
		return false
	# 暴風雪：遠的時候，主角潛行就看不清楚
	if d > sight_range * 0.6 and _player.gait == Player.Gait.SNEAK and _flare_time <= 0.0:
		return false
	return Sight.is_clear(self, global_position, _player.global_position)


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	if is_dead:
		_laser.visible = false
		_update_visibility(delta)
		return
	_phase_time += delta
	_flare_time = maxf(_flare_time - delta, 0.0)
	state = State.ALERT
	awareness = 1.0
	visible_to_player = true
	var moved := false
	match phase:
		Phase.AIM:
			_process_aim(delta)
		Phase.RELOAD:
			velocity = Vector2.ZERO
			if _phase_time >= reload_time:
				if _shots_here >= 2 or _hurt_here >= 40.0:
					_go_next_perch()
				else:
					_set_phase(Phase.AIM)
		Phase.RELOCATE:
			var target: Vector2 = patrol_points[_perch] if not patrol_points.is_empty() else global_position
			_move_along_path(target, relocate_speed, delta)
			move_and_slide()
			moved = true
			if velocity != Vector2.ZERO:
				facing = velocity.normalized()
			if global_position.distance_to(target) < 6.0 or _phase_time > 6.0:
				_set_phase(Phase.AIM)
	if not moved:
		velocity = Vector2.ZERO
	# 主角衝到身邊：跑到下一個制高點
	if phase == Phase.AIM and global_position.distance_to(_player.global_position) < flee_range:
		_go_next_perch()
	_update_laser()
	_update_visibility(delta)


func _process_aim(delta: float) -> void:
	var target: Variant = null
	if _sees_player():
		target = _player.global_position
		_noise_target = null
	elif _noise_target != null:
		target = _noise_target
	if target == null:
		# 跟丟了：雷射慢慢掃、鎖定值掉下來
		lock = maxf(lock - delta * 1.5, 0.0)
		laser_at = laser_at.lerp(global_position + facing * 120.0, 1.0 - exp(-1.5 * delta))
		return
	var t: Vector2 = target
	_turn_toward((t - global_position).normalized(), delta * 2.0)
	# 雷射追過去（有延遲：一直移動比較不容易被鎖定）
	laser_at = laser_at.lerp(t, 1.0 - exp(-3.2 * delta))
	var on_target := laser_at.distance_to(t) < 10.0
	lock += delta * (1.0 if on_target else 0.25)
	if lock >= lock_time:
		_fire(t)


func _fire(target: Vector2) -> void:
	lock = 0.0
	shots_fired += 1
	_shots_here += 1
	Sfx.play("pistol_shot", global_position, 0.0, 4.0)
	Sfx.rumble(120, 0.6)
	NoiseBus.emit_noise(global_position, 18.0 * TILE, self)
	last_ranged = {"from": global_position, "to": target, "t": 0.0, "hit": false}
	if _sees_player() and laser_at.distance_to(_player.global_position) < 12.0:
		last_ranged.hit = true
		_player.take_hit(shot_damage, 0.0, global_position)
	_noise_target = null
	_set_phase(Phase.RELOAD)
	# 第二階段：拉槍機的時候丟照明彈，下一槍之前甲板很亮
	if stage >= 2:
		_flare_time = reload_time + lock_time + 1.0
		boss_event.emit("flare", {"pos": _player.global_position})


func _go_next_perch() -> void:
	if patrol_points.size() > 1:
		_perch = (_perch + 1) % patrol_points.size()
	_shots_here = 0
	_hurt_here = 0.0
	lock = 0.0
	_set_phase(Phase.RELOCATE)


func _set_phase(p: Phase) -> void:
	phase = p
	_phase_time = 0.0


func _update_laser() -> void:
	_laser.visible = phase == Phase.AIM
	if not _laser.visible:
		return
	var from := global_position + Vector2(0, -6)
	_laser.points = PackedVector2Array([from, laser_at])
	var k := clampf(lock / lock_time, 0.0, 1.0)
	# 快鎖定時雷射變粗、變亮，閃爍加快：給玩家逃開的訊號
	_laser.width = 1.0 + k
	var blink := 0.6 + 0.4 * sin(Time.get_ticks_msec() * (0.01 + 0.03 * k))
	_laser.default_color = Color(1.0, 0.15 + 0.3 * k, 0.1, 0.45 + 0.5 * k * blink)


func _on_noise(pos: Vector2, radius: float, source: Node) -> void:
	if _player == null or source == self or is_dead or phase != Phase.AIM:
		return
	if global_position.distance_to(pos) <= radius * 2.0 * hearing_mult and not _sees_player():
		_noise_target = pos


func take_damage(amount: float, from_pos: Vector2, _stagger: float) -> void:
	if is_dead:
		return
	if phase == Phase.RELOAD:
		amount *= reload_damage_mult
	health -= amount
	_hurt_here += amount
	Sfx.play("enemy_hurt", global_position, 0.05, 2.0)
	if health <= 0.0:
		_die()
		return
	if stage == 1 and health / max_health < 0.5:
		stage = 2
		boss_event.emit("phase", {"title": "THE WARDEN", "text": "FLARES UP"})
	# 被打到就知道你在哪
	if phase == Phase.AIM:
		laser_at = laser_at.lerp(from_pos, 0.5)
	if _hurt_here >= 40.0 and phase != Phase.RELOAD:
		_go_next_perch()


func _die() -> void:
	_laser.visible = false
	super._die()
	WorldState.set_flag("defeated:" + boss_id)
	WorldState.emit_event("defeat", boss_id)
