## 主角：8 方向移動（潛行／走路／奔跑）、手電筒、發出聲音、躲藏、撿取與投擲、生命值與感染值。
## 戰鬥（近戰、手槍）在子節點 Combat（player_combat.gd）。
## 所有輸入只透過 InputMap 動作名稱讀取，之後加觸控和手把不用改這裡。
class_name Player
extends CharacterBody2D

signal hiding_changed(is_hidden: bool)
signal hurt(damage: float)
signal died

enum Gait { IDLE, SNEAK, WALK, RUN }

const TILE := 16.0
const BODY_LAYER := 2
const WALL_MASK := 1

@export_group("移動")
@export var sneak_speed := 36.0
@export var walk_speed := 62.0
@export var run_speed := 108.0
@export var acceleration := 900.0
@export var turn_smoothing := 14.0

@export_group("視野與光")
@export var flashlight_range := 150.0
@export var flashlight_half_angle_deg := 28.0
## 不開手電筒時，看得到身邊多遠
@export var dark_sight_radius := 56.0

@export_group("聲音（半徑單位：格）")
@export var walk_noise_tiles := 2.0
@export var run_noise_tiles := 6.0
@export var walk_noise_interval := 0.5
@export var run_noise_interval := 0.3
@export var locker_noise_tiles := 2.0

@export_group("生命與感染")
## 受傷後的無敵時間
@export var hurt_invulnerability := 0.9
@export var knockback_speed := 160.0
## 生命值低於這個比例時走路變慢、扶牆
@export var wounded_threshold := 35.0
@export var wounded_speed_mult := 0.8
## 感染值滿了以後，生命值每秒下降多少
@export var infection_drain := 1.5
@export var infected_speed_mult := 0.85
@export var reload_speed_mult := 0.6

@export_group("物品")
@export var max_bottles := 3
@export var throw_distance := 96.0
@export var bottle_noise_tiles := 6.0

var facing := Vector2.DOWN
var gait := Gait.IDLE
var sneaking := false
var flashlight_on := true
var input_enabled := true
## 攜帶的空瓶數存在世界狀態裡，切換區域、回到檢查點都會跟著走
var bottles: int:
	get:
		return WorldState.bottles
	set(value):
		WorldState.bottles = maxi(value, 0)

var health: float:
	get:
		return WorldState.health
var infection: float:
	get:
		return WorldState.infection
var is_dead := false

## 躲藏狀態
var is_hiding := false
var hiding_in: Locker = null
## 躲進去的那一刻有沒有被敵人看見
var hide_spotted := false

## 由 main 設定，用來找附近可以互動的東西
var level: Level
## 目前可以互動的對象（顯示提示用）
var focus: Interactable = null

var _noise_timer := 0.0
var _hide_return := Vector2.ZERO
var _flashlight_before_hide := true
var _ambient_energy := 1.0
var _invulnerable := 0.0

@onready var _flashlight: PointLight2D = $Flashlight
@onready var _ambient: PointLight2D = $AmbientLight
@onready var _facing_marker: Node2D = $FacingMarker
@onready var _body: Node2D = $Body
@onready var combat: PlayerCombat = $Combat


func _ready() -> void:
	_flashlight.texture = LightTextures.make_cone(flashlight_half_angle_deg)
	_flashlight.texture_scale = flashlight_range / (LightTextures.SIZE * 0.5)
	_ambient.texture = LightTextures.make_radial()
	_ambient_energy = _ambient.energy
	_ambient.texture_scale = (dark_sight_radius * 1.4) / (LightTextures.SIZE * 0.5)
	_apply_flashlight()


func _physics_process(delta: float) -> void:
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_body.modulate.a = 0.4 if _invulnerable > 0.0 and fmod(_invulnerable, 0.2) < 0.1 else 1.0
	if is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		move_and_slide()
		return
	_update_infection(delta)
	focus = _find_focus()
	if input_enabled and Input.is_action_just_pressed("interact") and focus:
		focus.use(self)
		focus = _find_focus()

	if is_hiding:
		velocity = Vector2.ZERO
		gait = Gait.IDLE
		return

	var move_input := Vector2.ZERO
	if input_enabled:
		move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if Input.is_action_just_pressed("sneak"):
			sneaking = not sneaking
		if Input.is_action_just_pressed("flashlight"):
			flashlight_on = not flashlight_on
			_apply_flashlight()
		if Input.is_action_just_pressed("throw"):
			throw_bottle()

	# 舉槍時站定，只能轉向（鎖定目標時面向由 Combat 控制）
	if combat.aiming:
		if move_input.length() > 0.1 and combat.target == null:
			facing = move_input.normalized()
		move_input = Vector2.ZERO

	var running := input_enabled and Input.is_action_pressed("run") and move_input != Vector2.ZERO
	if running:
		sneaking = false

	var speed := walk_speed
	if running:
		speed = run_speed
	elif sneaking:
		speed = sneak_speed
	speed *= get_speed_mult()
	velocity = velocity.move_toward(move_input * speed, acceleration * delta)
	move_and_slide()

	if move_input.length() > 0.1:
		facing = facing.slerp(move_input.normalized(), 1.0 - exp(-turn_smoothing * delta)).normalized()

	if velocity.length() < 4.0:
		gait = Gait.IDLE
	elif running:
		gait = Gait.RUN
	elif sneaking:
		gait = Gait.SNEAK
	else:
		gait = Gait.WALK

	_flashlight.rotation = facing.angle()
	_facing_marker.rotation = facing.angle()
	_update_noise(delta)


func reset_to(spawn: Vector2) -> void:
	if is_hiding:
		_leave_locker_state()
	is_dead = false
	_invulnerable = 0.0
	combat.interrupt()
	global_position = spawn
	velocity = Vector2.ZERO
	facing = Vector2.UP
	sneaking = false
	_noise_timer = 0.0
	focus = null


# ── 生命、感染、受傷 ────────────────────────────────────

## 被敵人打到。躲在櫃子裡被打到 = 被拖出來。
func take_hit(damage: float, infection_amount: float, from_pos: Vector2) -> void:
	if _invulnerable > 0.0 or is_dead:
		return
	if is_hiding:
		exit_hiding()
	WorldState.health -= damage
	WorldState.infection += infection_amount
	_invulnerable = hurt_invulnerability
	var away := (global_position - from_pos).normalized()
	velocity = (away if away != Vector2.ZERO else -facing) * knockback_speed
	combat.interrupt()
	hurt.emit(damage)
	if WorldState.health <= 0.0:
		_die()


func _die() -> void:
	is_dead = true
	input_enabled = false
	died.emit()


## 感染值滿了以後，生命值會慢慢流失。
func _update_infection(delta: float) -> void:
	if WorldState.infection >= WorldState.MAX_INFECTION:
		WorldState.health -= infection_drain * delta
		if WorldState.health <= 0.0:
			_die()


func get_speed_mult() -> float:
	var mult := 1.0
	if WorldState.health < wounded_threshold:
		mult *= wounded_speed_mult
	if WorldState.infection >= WorldState.MAX_INFECTION:
		mult *= infected_speed_mult
	if combat.reloading:
		mult *= reload_speed_mult
	return mult


## 狀態文字（不顯示數字，GDD：用狀態呈現）
func get_condition() -> String:
	if WorldState.health >= 65.0:
		return "Fine"
	if WorldState.health >= wounded_threshold:
		return "Caution"
	return "Danger"


## 使用物品欄裡的消耗品。成功回傳 true。
func use_item(item_id: String) -> bool:
	if WorldState.inv_count(item_id) <= 0 or is_dead:
		return false
	var item := Items.get_item(item_id)
	match item.kind:
		"heal":
			if WorldState.health >= WorldState.MAX_HEALTH:
				return false
			WorldState.health += item.heal
		"cure":
			if WorldState.infection <= 0.0:
				return false
			WorldState.infection -= item.cure
		_:
			return false
	WorldState.inv_remove(item_id, 1)
	return true


# ── 躲藏 ──────────────────────────────────────────────

func enter_hiding(locker: Locker) -> void:
	# 先判斷有沒有被看見，再發出櫃門聲
	hide_spotted = false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_watching_player():
			hide_spotted = true
	NoiseBus.emit_noise(global_position, locker_noise_tiles * TILE, self)

	is_hiding = true
	hiding_in = locker
	_hide_return = global_position
	_flashlight_before_hide = flashlight_on
	flashlight_on = false
	_apply_flashlight()
	global_position = locker.global_position
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_body.visible = false
	_facing_marker.visible = false
	_ambient.energy = _ambient_energy * 0.45  # 從櫃子縫隙看出去，只看得到一點點
	hiding_changed.emit(true)


func exit_hiding() -> void:
	if not is_hiding:
		return
	_leave_locker_state()
	global_position = _hide_return
	flashlight_on = _flashlight_before_hide
	_apply_flashlight()
	NoiseBus.emit_noise(global_position, locker_noise_tiles * TILE, self)


func _leave_locker_state() -> void:
	is_hiding = false
	hiding_in = null
	hide_spotted = false
	collision_layer = BODY_LAYER
	collision_mask = WALL_MASK
	_body.visible = true
	_facing_marker.visible = true
	_ambient.energy = _ambient_energy
	hiding_changed.emit(false)


# ── 物品 ──────────────────────────────────────────────

## 朝面向的方向丟出一個空瓶，碰到牆會提早落地。
func throw_bottle() -> bool:
	if bottles <= 0 or is_hiding:
		return false
	bottles -= 1
	var target := Sight.cast(self, global_position, global_position + facing * throw_distance)
	target -= facing * 4.0  # 不要落在牆裡
	var bottle := ThrownBottle.new()
	bottle.noise_radius = bottle_noise_tiles * TILE
	get_parent().add_child(bottle)
	bottle.launch(global_position, target)
	return true


func _find_focus() -> Interactable:
	if level == null:
		return null
	if is_hiding:
		return hiding_in
	var best: Interactable = null
	var best_dist := INF
	for item in level.get_interactables():
		if not item.can_interact(self):
			continue
		var d := global_position.distance_to(item.global_position)
		if d <= item.interact_range and d < best_dist:
			best = item
			best_dist = d
	return best


# ── 被看見的程度 ─────────────────────────────────────────

## 主角看不看得到某一點：沒被牆擋住，而且在身邊微光或手電筒光錐範圍內。
func can_see_point(point: Vector2) -> bool:
	var dist := global_position.distance_to(point)
	var radius := dark_sight_radius * (0.5 if is_hiding else 1.0)  # 從櫃子縫隙看出去
	var lit := dist <= radius or is_in_flashlight(point)
	return lit and Sight.is_clear(self, global_position, point)


func is_in_flashlight(point: Vector2) -> bool:
	return flashlight_on and Sight.in_cone(
		global_position, facing, point, deg_to_rad(flashlight_half_angle_deg), flashlight_range)


## 敵人的視野距離倍率：開手電筒的人在黑暗中很顯眼。
func get_detection_range_mult() -> float:
	var mult := 1.4 if flashlight_on else 0.7
	if gait == Gait.SNEAK or (gait == Gait.IDLE and sneaking):
		mult *= 0.85
	return mult


## 敵人的察覺速度倍率：動作越大、越亮，越快被發現。
func get_detection_rate_mult() -> float:
	var mult := 1.5 if flashlight_on else 0.8
	match gait:
		Gait.RUN:
			mult *= 1.6
		Gait.SNEAK:
			mult *= 0.55
		Gait.IDLE:
			mult *= 0.5 if sneaking else 0.7
	return mult


func get_gait_name() -> String:
	if is_dead:
		return "DEAD"
	if combat.aiming:
		return "AIM"
	if is_hiding:
		return "HIDDEN"
	return ["IDLE", "SNEAK", "WALK", "RUN"][gait]


func _apply_flashlight() -> void:
	_flashlight.enabled = flashlight_on


func _update_noise(delta: float) -> void:
	var radius := 0.0
	var interval := 0.0
	match gait:
		Gait.WALK:
			radius = walk_noise_tiles * TILE
			interval = walk_noise_interval
		Gait.RUN:
			radius = run_noise_tiles * TILE
			interval = run_noise_interval
		_:
			_noise_timer = 0.0
			return
	_noise_timer -= delta
	if _noise_timer <= 0.0:
		_noise_timer = interval
		NoiseBus.emit_noise(global_position, radius, self)
