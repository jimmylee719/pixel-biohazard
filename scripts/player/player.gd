## 主角：8 方向移動（潛行／走路／奔跑）、手電筒與打火機、發出聲音、躲藏、撿取與投擲、敲牆、
## 滅火器、生命值與感染值。
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
## 會擋住身體的東西：牆＋窗戶（窗戶看得穿但走不過去）
const MOVE_MASK := 41

@export_group("移動")
@export var sneak_speed := 36.0
@export var walk_speed := 62.0
@export var run_speed := 108.0
@export var acceleration := 900.0
@export var turn_smoothing := 14.0
## 舉槍時邊走邊射（可以後退、橫移，面向不變）
@export var aim_move_speed := 40.0
## 類比搖桿輕推（小於這個力道）= 自動潛行（安靜），推到底才是走路。鍵盤永遠是 1。
@export var analog_sneak_tilt := 0.6
## 卡在牆角時自動往旁邊滑開的最大距離（像素）：撞到柱子邊緣不會卡住
@export var corner_assist := 7.0

@export_group("視野與光")
@export var flashlight_range := 150.0
@export var flashlight_half_angle_deg := 28.0
## 不開手電筒時，看得到身邊多遠
@export var dark_sight_radius := 56.0
## 打火機：比手電筒暗、照得近，但不會一道光束出賣你的方向；也能點火、取暖
@export var lighter_radius := 72.0

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

@export_group("體溫（失溫，依區域氣候）")
## 體溫低於這個值會發抖：走得慢、瞄得慢
@export var shiver_threshold := 35.0
@export var shiver_speed_mult := 0.88
## 體溫降到 0 之後，生命值每秒下降多少
@export var freeze_drain := 1.5
## 火堆旁邊每秒回暖多少
@export var fire_warmth := 8.0

@export_group("物品")
@export var max_bottles := 3
@export var throw_distance := 96.0
@export var bottle_noise_tiles := 6.0
## 敲牆：在牆的另一邊也聽得到（MGS 式的引誘）
@export var knock_noise_tiles := 4.0
@export var knock_reach := 14.0

@export_group("滅火器")
@export var spray_range := 56.0
@export var spray_half_angle_deg := 32.0
@export var spray_blind_time := 3.0
@export var extinguisher_charges := 6
@export var extinguisher_throw_noise_tiles := 10.0

var facing := Vector2.DOWN
var gait := Gait.IDLE
var sneaking := false
var flashlight_on := true
## 打火機（和手電筒互斥；手電筒鍵依序切換：手電筒 → 打火機 → 全關）
var lighter_on := false
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
var _step_timer := 0.0
var _shiver_timer := 0.0
var _hide_return := Vector2.ZERO
var _flashlight_before_hide := true
var _lighter_before_hide := false
var _ambient_energy := 1.0
var _invulnerable := 0.0
var _knock_cd := 0.0
var _spray_cd := 0.0
var _lighter: PointLight2D
var _sprite: CharacterSprite
## 最近一次噴滅火器 {pos, dir, t}（畫面效果）
var last_spray := {}

@onready var _flashlight: PointLight2D = $Flashlight
@onready var _ambient: PointLight2D = $AmbientLight
@onready var _facing_marker: Node2D = $FacingMarker
@onready var _body: Node2D = $Body
@onready var combat: PlayerCombat = $Combat


func _ready() -> void:
	add_to_group("player")
	add_to_group("door_users")
	_lighter = PointLight2D.new()
	_lighter.texture = LightTextures.make_radial()
	_lighter.texture_scale = lighter_radius / (LightTextures.SIZE * 0.5)
	_lighter.color = Color(1.0, 0.72, 0.4)
	_lighter.energy = 0.9
	_lighter.shadow_enabled = true
	_lighter.enabled = false
	add_child(_lighter)
	_sprite = CharacterSprite.new()
	if _sprite.setup("player"):
		_body.add_child(_sprite)
		(_body as Polygon2D).color = Color(0, 0, 0, 0)  # 色塊藏起來，只留像素圖（無敵閃爍仍由 Body 控制）
		_facing_marker.visible = false
	else:
		_sprite = null
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
	_update_body_temp(delta)
	_knock_cd = maxf(_knock_cd - delta, 0.0)
	_spray_cd = maxf(_spray_cd - delta, 0.0)
	if not last_spray.is_empty():
		last_spray.t += delta
	if lighter_on:
		_lighter.energy = 0.85 + 0.12 * sin(Time.get_ticks_msec() * 0.023) + randf() * 0.05
	focus = _find_focus()
	if input_enabled and Input.is_action_just_pressed("interact") and combat.grabbed == null:
		if focus and not (combat.grab_target() != null and focus is Locker):
			focus.use(self)
			focus = _find_focus()
		elif not is_hiding:
			# 面前有可以抓的敵人就擒拿，不然就敲牆
			if not combat.grab():
				knock()

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
			cycle_light()
		if Input.is_action_just_pressed("throw") and combat.grabbed == null:
			if WorldState.carrying == "extinguisher":
				throw_extinguisher()
			elif not is_carrying():
				throw_item()
		if WorldState.carrying == "extinguisher" and Input.is_action_just_pressed("fire"):
			spray()

	# 舉槍時可以邊走邊射：面向固定（鎖定目標時由 Combat 朝向目標），所以能後退、橫移
	var aim_moving := combat.aiming or combat.grabbed != null

	# 搬燃料桶時不能跑；舉槍時也不能跑
	var running := input_enabled and Input.is_action_pressed("run") and move_input != Vector2.ZERO \
		and WorldState.carrying != "fuel" and not aim_moving
	if running:
		sneaking = false

	# 類比輕推 = 潛行：手機上不用另外按潛行鍵，手指放輕就安靜
	var tilt := minf(move_input.length(), 1.0)
	var light_tilt := tilt > 0.0 and tilt < analog_sneak_tilt and not running
	var speed := walk_speed
	if running:
		speed = run_speed
	elif sneaking or light_tilt:
		speed = sneak_speed
	if aim_moving:
		speed = minf(speed, aim_move_speed)
	speed *= get_speed_mult()
	var move_dir := move_input.normalized() if tilt > 0.0 else Vector2.ZERO
	# 輕推的範圍內速度還是跟著力道（推越少走越慢），潛行速度以上就固定
	var drive := clampf(tilt / analog_sneak_tilt, 0.35, 1.0) if light_tilt else 1.0
	velocity = velocity.move_toward(move_dir * speed * drive, acceleration * delta)
	var wanted := velocity
	move_and_slide()
	if move_dir != Vector2.ZERO:
		_assist_corner(move_dir, wanted, delta)

	if move_input.length() > 0.1 and not aim_moving:
		facing = facing.slerp(move_input.normalized(), 1.0 - exp(-turn_smoothing * delta)).normalized()

	if velocity.length() < 4.0:
		gait = Gait.IDLE
	elif running:
		gait = Gait.RUN
	elif sneaking or light_tilt:
		gait = Gait.SNEAK
	else:
		gait = Gait.WALK

	_flashlight.rotation = facing.angle()
	_facing_marker.rotation = facing.angle()
	_update_sprite()
	_update_noise(delta)
	_update_steps(delta)


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
	Sfx.play("player_hurt")
	Sfx.rumble(120, 0.7)
	if WorldState.health <= 0.0:
		_die()


func _die() -> void:
	Sfx.play("player_death")
	is_dead = true
	input_enabled = false
	died.emit()


## 感染值滿了以後，生命值會慢慢流失。
func _update_infection(delta: float) -> void:
	if WorldState.infection >= WorldState.MAX_INFECTION:
		WorldState.health -= infection_drain * delta
		if WorldState.health <= 0.0:
			_die()


## 體溫：依所在位置的氣候失溫或回暖。打火機開著、奔跑時失溫比較慢；火堆旁回暖很快。
func _update_body_temp(delta: float) -> void:
	if level == null:
		return
	var rate := level.exposure_at(global_position)
	if Fire.warm_at(get_tree(), global_position):
		rate = -fire_warmth
	elif rate > 0.0:
		if lighter_on:
			rate *= 0.7
		if gait == Gait.RUN:
			rate *= 0.8
	WorldState.body_temp -= rate * delta
	if WorldState.body_temp <= 0.0 and rate > 0.0:
		WorldState.health -= freeze_drain * delta
		if WorldState.health <= 0.0:
			_die()


func is_shivering() -> bool:
	return WorldState.body_temp < shiver_threshold


func get_body_temp_state() -> String:
	if WorldState.body_temp >= 60.0:
		return "Warm"
	if WorldState.body_temp >= shiver_threshold:
		return "Cold"
	return "Freezing" if WorldState.body_temp > 0.0 else "Hypothermic"


## 雙手拿著東西（燃料桶、滅火器）：不能用武器、不能丟一般的投擲物
func is_carrying() -> bool:
	return WorldState.carrying != ""


func get_speed_mult() -> float:
	var mult := 1.0
	if WorldState.carrying == "fuel":
		mult *= 0.85
	if WorldState.health < wounded_threshold:
		mult *= wounded_speed_mult
	if WorldState.infection >= WorldState.MAX_INFECTION:
		mult *= infected_speed_mult
	if combat.reloading:
		mult *= reload_speed_mult
	if is_shivering():
		mult *= shiver_speed_mult
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
		"warm":
			if WorldState.body_temp >= WorldState.MAX_BODY_TEMP - 1.0:
				return false
			WorldState.body_temp += item.warm
		"weapon":
			# 武器不消耗：使用 = 裝備
			combat.interrupt()
			WorldState.equipped = item_id
			return true
		"throwable":
			# 投擲物：使用 = 準備丟這種
			WorldState.ready_throw = item_id
			return true
		"craft":
			# 材料：和需要的東西組合（例如酒精＋空瓶 = 汽油彈）
			var recipe: Dictionary = item.recipe
			if WorldState.inv_count(recipe.needs) <= 0:
				return false
			WorldState.inv_remove(item_id, 1)
			WorldState.inv_remove(recipe.needs, 1)
			if WorldState.inv_add(recipe.makes, 1) == 0:
				# 放不下：材料還回去
				WorldState.inv_add(item_id, 1)
				WorldState.inv_add(recipe.needs, 1)
				return false
			WorldState.ready_throw = recipe.makes
			return true
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
	Sfx.play("locker_close", global_position)

	is_hiding = true
	hiding_in = locker
	_hide_return = global_position
	_flashlight_before_hide = flashlight_on
	_lighter_before_hide = lighter_on
	flashlight_on = false
	lighter_on = false
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
	lighter_on = _lighter_before_hide and not flashlight_on
	_apply_flashlight()
	NoiseBus.emit_noise(global_position, locker_noise_tiles * TILE, self)
	Sfx.play("locker_open", global_position)


func _leave_locker_state() -> void:
	is_hiding = false
	hiding_in = null
	hide_spotted = false
	collision_layer = BODY_LAYER
	collision_mask = MOVE_MASK
	_body.visible = true
	_facing_marker.visible = _sprite == null
	_ambient.energy = _ambient_energy
	hiding_changed.emit(false)


# ── 物品 ──────────────────────────────────────────────

## 現在會丟出去的投擲物：準備的那種；用完了就照順序換有的那種。沒有就是空字串。
func current_throwable() -> String:
	if WorldState.inv_count(WorldState.ready_throw) > 0 and Items.THROWABLES.has(WorldState.ready_throw):
		return WorldState.ready_throw
	for id in Items.THROW_ORDER:
		if WorldState.inv_count(id) > 0:
			return id
	return ""


## 朝面向的方向丟出投擲物，碰到牆會提早落地。汽油彈用打火機點著再丟（打火機永遠在身上）。
func throw_item(item_id := "") -> bool:
	if item_id == "":
		item_id = current_throwable()
	if item_id == "" or WorldState.inv_count(item_id) <= 0 or is_hiding or is_carrying():
		return false
	WorldState.inv_remove(item_id, 1)
	var stats: Dictionary = Items.THROWABLES[item_id]
	var thrown := ThrownObject.new()
	thrown.setup(item_id, stats.noise_tiles, stats.fire, stats.color)
	if stats.fire:
		Sfx.play("lighter_flick")
	_launch(thrown)
	return true


func throw_bottle() -> bool:
	return throw_item("bottle")


func _launch(thrown: ThrownObject) -> void:
	var target := Sight.cast(self, global_position, global_position + facing * throw_distance)
	target -= facing * 4.0  # 不要落在牆裡
	get_parent().add_child(thrown)
	thrown.launch(global_position, target)
	Sfx.play("throw_whoosh", global_position)


# ── 光源：手電筒、打火機 ─────────────────────────────────

## 手電筒 → 打火機 → 全關 → 手電筒
func cycle_light() -> void:
	if flashlight_on:
		flashlight_on = false
		lighter_on = true
	elif lighter_on:
		lighter_on = false
	else:
		flashlight_on = true
	_apply_flashlight()
	if lighter_on:
		NoiseBus.emit_noise(global_position, 0.5 * TILE, self)  # 打火機「喀」一聲
		Sfx.play("lighter_flick")
	else:
		Sfx.play("flashlight_click")


# ── 敲牆 ──────────────────────────────────────────────

## 面前貼著牆的位置（沒有就回傳 null）。
func knock_point() -> Variant:
	if is_hiding or is_carrying() or level == null:
		return null
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + facing * knock_reach, WALL_MASK)
	var hit := space.intersect_ray(query)
	return hit.position if not hit.is_empty() else null


## 敲牆：牆的位置發出聲音，引誘附近（包括牆後面）的敵人過來看看。
func knock() -> bool:
	if _knock_cd > 0.0:
		return false
	var p = knock_point()
	if p == null:
		return false
	_knock_cd = 0.6
	NoiseBus.emit_noise(p, knock_noise_tiles * TILE, self)
	Sfx.play("knock", p)
	return true


# ── 滅火器 ────────────────────────────────────────────

## 噴一下：撲滅前方的火，噴到的敵人看不見、失去你的位置，留下一團擋視線的白霧。
func spray() -> bool:
	if WorldState.carrying != "extinguisher" or _spray_cd > 0.0 or is_hiding:
		return false
	_spray_cd = 0.4
	WorldState.extinguisher_charge -= 1
	NoiseBus.emit_noise(global_position, 3.0 * TILE, self)  # 噴射聲（先發出，噴到的敵人才不會循著聲音找到你）
	Sfx.play("extinguisher_spray", global_position)
	var half := deg_to_rad(spray_half_angle_deg)
	for f in get_tree().get_nodes_in_group(Fire.GROUP):
		if Sight.in_cone(global_position, facing, f.global_position, half, spray_range + f.radius):
			f.put_out()
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and not enemy.is_dead \
				and Sight.in_cone(global_position, facing, enemy.global_position, half, spray_range) \
				and Sight.is_clear(self, global_position, enemy.global_position):
			enemy.blind(spray_blind_time)
	if level:
		for item in level.get_interactables():
			if item is OilDrum and item.is_lit() \
					and Sight.in_cone(global_position, facing, item.global_position, half, spray_range):
				item.put_out()
	var cloud := SmokeCloud.new()
	get_parent().add_child(cloud)
	cloud.global_position = Sight.cast(self, global_position, global_position + facing * spray_range * 0.6)
	last_spray = {"pos": global_position, "dir": facing, "t": 0.0}
	if WorldState.extinguisher_charge <= 0:
		WorldState.carrying = ""
	return true


## 把滅火器丟出去：落地「哐」一聲很大聲（可以當誘餌），丟了就沒了。
func throw_extinguisher() -> bool:
	if WorldState.carrying != "extinguisher" or is_hiding:
		return false
	WorldState.carrying = ""
	WorldState.extinguisher_charge = 0
	var thrown := ThrownObject.new()
	thrown.setup("extinguisher", extinguisher_throw_noise_tiles, false, Color(0.85, 0.15, 0.12))
	_launch(thrown)
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


func _update_sprite() -> void:
	if _sprite == null:
		return
	# 近戰動作（刀、拳、踢）優先，再來是舉槍瞄準
	var swing: Dictionary = combat.last_melee
	if not swing.is_empty() and swing.t < 0.22 and swing.move in ["slash", "punch", "kick"]:
		_sprite.show_pose(swing.move, swing.dir, true)
		return
	if combat.aiming and combat.has_weapon():
		_sprite.show_pose("aim_" + combat.current_weapon(), facing, true)
		return
	match gait:
		Gait.RUN:
			_sprite.show_pose("walk", facing, true, 1.8)
		Gait.WALK:
			_sprite.show_pose("walk", facing, true, 1.0)
		Gait.SNEAK:
			_sprite.show_pose("sneak", facing, true, 0.7)
		_:
			if sneaking:
				_sprite.show_pose("sneak", facing, false)
			else:
				_sprite.show_pose("idle", facing, true, 0.4)


# ── 被看見的程度 ─────────────────────────────────────────

## 主角看不看得到某一點：沒被牆擋住，而且在身邊微光或手電筒光錐範圍內。
func can_see_point(point: Vector2) -> bool:
	var dist := global_position.distance_to(point)
	var radius := dark_sight_radius * (0.5 if is_hiding else 1.0)  # 從櫃子縫隙看出去
	# 燈亮著的區域：只要沒被牆擋住就看得到
	if lighter_on and not is_hiding:
		radius = maxf(radius, lighter_radius * 0.85)
	var lit := dist <= radius or is_in_flashlight(point) or (level != null and level.is_lit() and not is_hiding) \
		or Fire.lit_at(get_tree(), point)
	return lit and Sight.is_clear(self, global_position, point)


func is_in_flashlight(point: Vector2) -> bool:
	return flashlight_on and Sight.in_cone(
		global_position, facing, point, deg_to_rad(flashlight_half_angle_deg), flashlight_range)


## 敵人的視野距離倍率：開手電筒的人在黑暗中很顯眼；燈亮著的區域就藏不住了。
func get_detection_range_mult() -> float:
	var mult := 1.4 if flashlight_on else (1.0 if lighter_on else 0.7)
	if (level and level.is_lit()) or Fire.lit_at(get_tree(), global_position):
		mult = maxf(mult, 1.2)  # 燈光或火光底下藏不住
	if gait == Gait.SNEAK or (gait == Gait.IDLE and sneaking):
		mult *= 0.85
	return mult


## 敵人的察覺速度倍率：動作越大、越亮，越快被發現。
func get_detection_rate_mult() -> float:
	var mult := 1.5 if flashlight_on else (1.1 if lighter_on else 0.8)
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
	if is_carrying():
		return "CARRY"
	return ["IDLE", "SNEAK", "WALK", "RUN"][gait]


func _apply_flashlight() -> void:
	if flashlight_on:
		lighter_on = false
	_flashlight.enabled = flashlight_on
	if _lighter:
		_lighter.enabled = lighter_on


func light_name() -> String:
	if flashlight_on:
		return "Flashlight"
	return "Lighter" if lighter_on else "Dark"


## 撞到牆角：如果往旁邊挪一點點就能繼續往前走，就自動滑過去（不用很準地對齊門口、柱子）
func _assist_corner(dir: Vector2, wanted: Vector2, delta: float) -> void:
	if get_slide_collision_count() == 0 or wanted.length() < 1.0:
		return
	var normal := get_slide_collision(0).get_normal()
	if normal.dot(dir) > -0.7:
		return  # 斜著撞牆，move_and_slide 本來就會沿牆滑
	var side := Vector2(-dir.y, dir.x)
	var step := minf(wanted.length() * delta, corner_assist)
	for k in range(1, int(corner_assist) + 1):
		for s in [side, -side]:
			var offset: Vector2 = s * float(k)
			if not test_move(global_transform, offset) \
					and not test_move(global_transform.translated(offset), dir * 2.0):
				move_and_collide(s * step)
				return


## 腳步聲（玩家聽到的，跟敵人聽到的 NoiseBus 分開：潛行也有很輕的腳步聲）
func _update_steps(delta: float) -> void:
	var interval := 0.0
	var quiet := 0.0
	match gait:
		Gait.SNEAK:
			interval = 0.62
			quiet = -8.0
		Gait.WALK:
			interval = 0.42
		Gait.RUN:
			interval = 0.28
			quiet = 3.0
		_:
			_step_timer = 0.12  # 一起步很快就有第一步
			return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = interval
		var surface := level.step_surface(global_position) if level else "concrete"
		Sfx.play("step_" + surface, global_position, 0.1, quiet)
	if is_shivering():
		_shiver_timer -= delta
		if _shiver_timer <= 0.0:
			_shiver_timer = 3.5
			Sfx.play("shiver_breath")


func _update_noise(delta: float) -> void:
	var radius := 0.0
	var interval := 0.0
	match gait:
		Gait.WALK:
			radius = (walk_noise_tiles + (1.5 if is_carrying() else 0.0)) * TILE
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
