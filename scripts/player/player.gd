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

@export_group("閃躲（快速跳開）")
## 一次跳多遠、多久；跳的過程中不會被打到
@export var dodge_distance := 50.0
@export var dodge_time := 0.24
## v0.14：閃躲每 3 秒只能用一次（從開始跳算起）
@export var dodge_cooldown := 3.0
## 落地的聲音（格）
@export var dodge_noise_tiles := 3.0

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

@export_group("滅火器")
@export var spray_range := 56.0
@export var spray_half_angle_deg := 32.0
@export var spray_blind_time := 3.0
@export var extinguisher_charges := 6
@export var extinguisher_throw_noise_tiles := 10.0

var facing := Vector2.DOWN
## 閃躲中剩下的時間（> 0 = 正在跳）
var dodging := 0.0
## 這次閃躲是往後跳（瞄準時後退）
var dodge_back := false
var _dodge_dir := Vector2.ZERO
var _dodge_cd := 0.0
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
		refresh_outfit()
		WorldState.gear_changed.connect(refresh_outfit)
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
	if dragging:
		if not is_instance_valid(dragging) or dragging.stashed or (not dragging.is_dead and not dragging.is_asleep()) or is_hiding:
			dragging = null
		else:
			dragging.global_position = dragging.global_position.lerp(global_position - facing * 11.0, 0.35)
	_update_infection(delta)
	_update_body_temp(delta)
	_update_hazard(delta)
	_update_peek()
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
			# 面前有可以抓的敵人就擒拿；不然，貼著關著的門 = 把門推開一條縫往裡面看
			if not combat.grab():
				toggle_peek()

	if is_hiding:
		velocity = Vector2.ZERO
		gait = Gait.IDLE
		return

	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	if vaulting > 0.0:
		_process_vault(delta)
		return
	if input_enabled and Input.is_action_just_pressed("dodge") and not combat.choking:
		# 空白鍵：面前是矮的家具（桌子、木箱）＝翻過去；不然＝閃躲
		var push := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if not vault(push):
			dodge(push)
	if dodging > 0.0:
		_process_dodge(delta)
		return

	var move_input := Vector2.ZERO
	if input_enabled and not combat.choking:
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
	move_intent = move_dir
	# 輕推的範圍內速度還是跟著力道（推越少走越慢），潛行速度以上就固定
	var drive := clampf(tilt / analog_sneak_tilt, 0.35, 1.0) if light_tilt else 1.0
	velocity = velocity.move_toward(move_dir * speed * drive, acceleration * delta)
	var wanted := velocity
	move_and_slide()
	if move_dir != Vector2.ZERO:
		_assist_corner(move_dir, wanted, delta)
	_update_wall_press(move_dir, running, delta)

	if move_input.length() > 0.1 and not aim_moving and wall_press == Vector2.ZERO:
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


## 貼牆（潛龍諜影式）：往牆的方向一直推（不跑）約 0.35 秒 = 背貼著牆。這時鏡頭會往前方推出去，看得到走廊前面；
## 主角面向牆的反方向（背對牆），速度放到最慢、不出聲。放開方向或改推別的方向就離開牆。
## wall_press = 牆的法線（從牆指向主角），沒有貼牆時是 Vector2.ZERO。
var wall_press := Vector2.ZERO
var _press_t := 0.0
const WALL_PRESS_TIME := 0.35


func _update_wall_press(move_dir: Vector2, running: bool, delta: float) -> void:
	var normal := Vector2.ZERO
	if move_dir != Vector2.ZERO and not running and not combat.aiming and not is_carrying():
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var n := col.get_normal()
			# 只算牆（圖層 1），而且是正面推過去（不是沿著牆滑）
			if col.get_collider() is CollisionObject2D and (col.get_collider().collision_layer & 1) != 0 \
					and n.dot(move_dir) < -0.75:
				normal = n
	if normal != Vector2.ZERO:
		_press_t += delta
		if _press_t >= WALL_PRESS_TIME:
			if wall_press == Vector2.ZERO:
				Sfx.play("step_concrete", global_position, 0.05, -6.0)
			wall_press = normal.round().normalized() if absf(normal.x) > 0.9 or absf(normal.y) > 0.9 else normal
			facing = wall_press
			velocity = Vector2.ZERO
	else:
		_press_t = 0.0
		wall_press = Vector2.ZERO


## 閃躲：往推的方向快速跳開（沒推方向 = 往面向跳；瞄準中沒推方向 = 往後跳）。
## 瞄準中往後推 = 後跳，跳的時候繼續鎖定、可以落地馬上開槍。跳的過程不會被打到，落地有一點聲音。
func dodge(input_dir: Vector2) -> bool:
	if _dodge_cd > 0.0 or dodging > 0.0 or is_hiding or is_dead or is_carrying() or combat.grabbed != null:
		return false
	var dir := input_dir.normalized() if input_dir.length() > 0.2 else (-facing if combat.aiming else facing)
	dodging = dodge_time
	_dodge_dir = dir
	dodge_back = dir.dot(facing) < -0.3
	_dodge_cd = dodge_cooldown
	sneaking = false
	if not combat.aiming:
		facing = dir
	Sfx.play("knife_swing", global_position, 0.15, -8.0)
	return true


# ── 翻越（v0.14）：空白鍵跟環境互動 ─────────────────────────
## 翻過矮的家具（桌子、木箱、床、腳櫃）：要貼著它、另一邊是空地。敵人不會翻，可以拿來甩掉追兵。
const VAULT_TIME := 0.42
const VAULT_REACH := 13.0
var vaulting := 0.0
var _vault_from := Vector2.ZERO
var _vault_to := Vector2.ZERO
var _vault_dir := Vector2.ZERO


## 現在按空白鍵會翻到哪裡（Vector2.INF = 不能翻）
func vault_target(push := Vector2.ZERO) -> Vector2:
	if level == null or is_hiding or is_dead or is_carrying() or combat.grabbed != null or dragging:
		return Vector2.INF
	var d := push if push.length() > 0.2 else facing
	var dir := Vector2i(signi(roundi(d.x)) if absf(d.x) >= absf(d.y) else 0, signi(roundi(d.y)) if absf(d.y) > absf(d.x) else 0)
	if dir == Vector2i.ZERO:
		return Vector2.INF
	var pc := level.cell_of(global_position)
	var obstacle := pc + dir
	if not level.is_vaultable(obstacle):
		return Vector2.INF
	var center := (Vector2(obstacle) + Vector2(0.5, 0.5)) * TILE
	var dirf := Vector2(dir)
	# 要貼著：主角到障礙物那格邊緣的距離
	if (center - global_position).dot(dirf) > TILE * 0.5 + VAULT_REACH:
		return Vector2.INF
	var land := obstacle + dir
	if not level.is_open_floor(land):
		return Vector2.INF
	var to := (Vector2(land) + Vector2(0.5, 0.5)) * TILE
	# 垂直方向維持原本的位置（沿著桌子邊翻過去）
	if dir.x != 0:
		to.y = clampf(global_position.y, float(land.y) * TILE + 5.0, float(land.y + 1) * TILE - 5.0)
	else:
		to.x = clampf(global_position.x, float(land.x) * TILE + 5.0, float(land.x + 1) * TILE - 5.0)
	return to


func vault(push := Vector2.ZERO) -> bool:
	var to := vault_target(push)
	if to == Vector2.INF:
		return false
	vaulting = VAULT_TIME
	_vault_from = global_position
	_vault_to = to
	_vault_dir = (to - global_position).normalized()
	facing = _vault_dir
	sneaking = false
	collision_mask = 0  # 翻的過程不撞家具
	Sfx.play("knife_swing", global_position, 0.2, -10.0)
	NoiseBus.emit_noise(global_position, 1.5 * TILE, self)
	return true


func _process_vault(delta: float) -> void:
	vaulting = maxf(vaulting - delta, 0.0)
	var k := 1.0 - vaulting / VAULT_TIME
	var e := k * k * (3.0 - 2.0 * k)
	global_position = _vault_from.lerp(_vault_to, e)
	velocity = Vector2.ZERO
	gait = Gait.RUN
	if _sprite:
		_sprite.show_pose("dodge", facing, true)
		_sprite.position.y -= sin(k * PI) * 7.0  # 跳起來
	_flashlight.rotation = facing.angle()
	_facing_marker.rotation = facing.angle()
	if vaulting <= 0.0:
		collision_mask = MOVE_MASK
		global_position = _vault_to
		NoiseBus.emit_noise(global_position, 2.0 * TILE, self)
		Sfx.play(("step_" + level.step_surface(global_position)) if level else "step_concrete", global_position, 0.1, 2.0)


func _process_dodge(delta: float) -> void:
	dodging -= delta
	velocity = _dodge_dir * (dodge_distance / dodge_time)
	move_and_slide()
	gait = Gait.RUN
	_flashlight.rotation = facing.angle()
	_facing_marker.rotation = facing.angle()
	if _sprite:
		_sprite.show_pose("dodge_back" if dodge_back else "dodge", facing, true)
	if dodging <= 0.0:
		dodging = 0.0
		velocity *= 0.25
		NoiseBus.emit_noise(global_position, dodge_noise_tiles * TILE, self)
		Sfx.play(("step_" + level.step_surface(global_position)) if level else "step_concrete", global_position, 0.1, 2.0)


func reset_to(spawn: Vector2) -> void:
	if is_hiding:
		_leave_locker_state()
	is_dead = false
	_invulnerable = 0.0
	refresh_outfit()
	dodging = 0.0
	_dodge_cd = 0.0
	if vaulting > 0.0:
		vaulting = 0.0
		collision_mask = MOVE_MASK
	combat.interrupt()
	global_position = spawn
	velocity = Vector2.ZERO
	facing = Vector2.UP
	sneaking = false
	_noise_timer = 0.0
	focus = null


# ── 生命、雜訊值（infection：被迴頻訊號覆寫的程度，變數名稱沿用）、受傷 ────────────────────────────────────

## 被敵人打到。躲在櫃子裡被打到 = 被拖出來。
func take_hit(damage: float, infection_amount: float, from_pos: Vector2) -> void:
	if _invulnerable > 0.0 or is_dead or dodging > 0.0:
		return
	if is_hiding:
		exit_hiding()
	WorldState.health -= damage * Gear.stat("armor") * WorldState.assist_mult()
	WorldState.infection += infection_amount * clampf(Gear.stat("armor") * 1.3, 0.0, 1.0) * WorldState.assist_mult()
	_invulnerable = hurt_invulnerability
	var away := (global_position - from_pos).normalized()
	velocity = (away if away != Vector2.ZERO else -facing) * knockback_speed * (0.3 if Gear.full_set() == "eod" else 1.0)
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
## 耐寒：失溫速度的倍率（主角受過極地訓練、穿著保暖內層，比一般人耐冷很多）
@export var cold_resistance := 0.45


func _update_body_temp(delta: float) -> void:
	if level == null:
		return
	var rate := level.exposure_at(global_position)
	if Fire.warm_at(get_tree(), global_position):
		rate = -fire_warmth
	elif rate > 0.0:
		rate *= cold_resistance
		if lighter_on:
			rate *= 0.7
		if gait == Gait.RUN:
			rate *= 0.8
		rate *= Gear.stat("warmth")
		if not level.is_indoor_at(global_position):
			rate *= float(Weather.value("cold"))
	WorldState.body_temp -= rate * delta
	if WorldState.body_temp <= 0.0 and rate > 0.0:
		WorldState.health -= freeze_drain * delta
		if WorldState.health <= 0.0:
			_die()


## 孢子區（區域資料 hazards）：沒穿防護裝備，感染值會一直上升（防護衣整套 = 完全不會）
@export var spore_infection_rate := 2.2
var in_spores := false


func _update_hazard(delta: float) -> void:
	in_spores = level != null and level.hazard_at(global_position) == "spores"
	if in_spores and not is_hiding:
		WorldState.infection += spore_infection_rate * Gear.stat("hazard") * delta * WorldState.assist_mult()


## 外型跟著裝備換（紙娃娃）
func refresh_outfit() -> void:
	if _sprite:
		_sprite.set_outfit(Gear.sprite_sets())


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


## 拖著走的屍體（BodyHandle）
var dragging: Enemy = null


func get_speed_mult() -> float:
	var mult := 1.0
	if dragging:
		mult *= 0.55
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
	mult *= Gear.stat("speed")
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
		"campfire":
			# 可燃物：用打火機在腳邊生一小堆火（取暖、照明；敵人也看得到光）
			if level == null or is_hiding:
				return false
			light_campfire(float(item.get("burn", 45.0)))
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


## 在腳邊（面前一點）生一堆火：不會燒到人，燒一陣子自己熄
func light_campfire(burn_time: float) -> Fire:
	var fire := Fire.new()
	fire.harmful = false
	fire.radius = 10.0
	fire.duration = burn_time
	fire.light_radius = 72.0
	fire.warm_radius = 48.0
	fire.campfire = true
	level.add_child(fire)
	var at := global_position + facing * 12.0
	# 面前是牆就生在腳邊
	if not Sight.is_clear(self, global_position, at):
		at = global_position
	fire.global_position = at
	Sfx.play("lighter_flick", global_position)
	return fire


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

## 直接指定光源："flashlight"、"lighter"、""（全關）
func set_light(which: String) -> void:
	flashlight_on = which == "flashlight"
	lighter_on = which == "lighter"
	_apply_flashlight()
	Sfx.play("lighter_flick" if lighter_on else "flashlight_click")


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


# ── 門縫窺視 ──────────────────────────────────────────

## 潛行（或輕推搖桿）靠近室內門時，門不會自己打開：要「往門推一下」才會開，或是按互動把門推開一條縫往裡面看。
## 從門縫只看得到正前方一個窄窄的扇形（看得到裡面的人面向哪裡），門還是關著的，裡面的人看不到你；
## 但門軸會響一小聲（就在門後面的會聽到）。離開門邊、門被打開、再按一次互動就結束。
var peeking: InteriorDoor = null
## 這一幀想往哪走（門用來判斷是不是「往門推」）
var move_intent := Vector2.ZERO
const PEEK_REACH := 21.0
const PEEK_HALF_ANGLE := 0.75
const PEEK_NOISE_TILES := 1.5


## 不會把門自動打開的走法：潛行中、站著不動潛行
func is_quiet() -> bool:
	return sneaking or gait == Gait.SNEAK


func peek_candidate() -> InteriorDoor:
	if is_hiding or is_carrying() or level == null or not is_quiet() or combat.aiming:
		return null
	var best: InteriorDoor = null
	var best_d := PEEK_REACH
	for door in level.get_inner_doors():
		if door.is_open or door.access > WorldState.access_level:
			continue
		var d := global_position.distance_to(door.global_position)
		if d < best_d:
			best = door
			best_d = d
	return best


func toggle_peek() -> bool:
	if peeking != null:
		stop_peek()
		return true
	var door := peek_candidate()
	if door == null:
		return false
	peeking = door
	door.ajar = true
	door.queue_redraw()
	NoiseBus.emit_noise(door.global_position, PEEK_NOISE_TILES * TILE, self)
	Sfx.play("door_open", door.global_position, 0.1, -16.0)
	return true


func stop_peek() -> void:
	if peeking != null and is_instance_valid(peeking):
		peeking.ajar = false
		peeking.queue_redraw()
	peeking = null


## 門縫另一邊的位置（視線從這裡出發）和往裡面看的方向
func peek_origin() -> Vector2:
	return peeking.global_position + peek_dir() * (TILE * 0.5 + 2.0)


func peek_dir() -> Vector2:
	var d := peeking.global_position - global_position
	# 門是橫的（上下通行）還是直的：只取通行的那個方向
	if peeking.is_horizontal():
		return Vector2(0, signf(d.y) if d.y != 0.0 else 1.0)
	return Vector2(signf(d.x) if d.x != 0.0 else 1.0, 0)


func _update_peek() -> void:
	if peeking == null:
		return
	if not is_instance_valid(peeking) or peeking.is_open or is_hiding or is_dead \
			or global_position.distance_to(peeking.global_position) > PEEK_REACH + 6.0:
		stop_peek()


## 從門縫、窗戶看進去的那幾格（RoomFog 用：那一間也要顯示出來）
func peek_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if level == null:
		return cells
	if peeking != null:
		cells.append(level.cell_of(peek_origin() + peek_dir() * 4.0))
	# 站在窗戶旁邊：看得到窗戶另一邊的房間
	var c := level.cell_of(global_position)
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if level.char_at(c + d) == "=":
			# 窗戶可能有好幾格厚：一直往前找到另一邊的地板
			var far: Vector2i = c + d * 2
			var n := 0
			while level.char_at(far) == "=" and n < 6:
				far += d
				n += 1
			cells.append(far)
	return cells


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
	# 拖著屍體時：互動鍵一定是「放下／塞進櫃子」（不會不小心躲進櫃子）
	if dragging:
		for item in level.get_interactables():
			if item is BodyHandle and item.body == dragging:
				return item
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


## 每一招的動作畫面播多久（秒；只影響畫面，比該招的冷卻短一點，連段才接得上）
const MELEE_POSE_TIME := {"slash": 0.31, "slash_back": 0.31, "stab": 0.34, "punch": 0.29, "hook": 0.32, "kick": 0.42,
	"jab_l": 0.22, "jab_r": 0.22, "cross_l": 0.29, "cross_r": 0.29, "hook_l": 0.32, "hook_r": 0.32,
	"slash_axe": 0.34, "slash_crowbar": 0.36}


## 這一招用哪組圖（還沒有那組圖時退回最接近的）
func _melee_anim(move: String) -> String:
	if _sprite.has_anim(move):
		return move
	match move:
		"slash_back", "stab", "slash_crowbar":
			return "slash_axe" if move == "slash_crowbar" and _sprite.has_anim("slash_axe") else "slash"
		"hook":
			return "punch"
	return move


func _update_sprite() -> void:
	if _sprite == null:
		return
	# 近戰動作（刀、拳、踢）優先，再來是舉槍瞄準
	var swing: Dictionary = combat.last_melee
	if not swing.is_empty() and swing.move in MELEE_POSE_TIME and swing.t < MELEE_POSE_TIME[swing.move]:
		_sprite.show_pose(_melee_anim(swing.move), swing.dir, true)
		return
	var shot: Dictionary = combat.last_shot
	if combat.aiming and combat.has_weapon() and not shot.is_empty() and shot.t < 0.18:
		_sprite.show_pose("shoot_" + combat.pose_weapon(), facing, true)
		return
	if combat.aiming and combat.has_weapon():
		# 舉著槍走：上半身瞄準、腳照樣走（沒有這組圖就退回站著瞄準）
		var walk_anim := "aimwalk_" + combat.pose_weapon()
		if velocity.length() > 8.0 and _sprite.has_anim(walk_anim):
			_sprite.show_pose(walk_anim, facing, true, clampf(velocity.length() / aim_move_speed, 0.6, 1.2))
		else:
			_sprite.show_pose("aim_" + combat.pose_weapon(), facing, true)
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
	if lit and Sight.is_clear(self, global_position, point):
		return true
	# 從門縫看：只有門後面正前方一個窄窄的扇形，而且要夠近或那邊有光
	if peeking != null:
		var from := peek_origin()
		var near := from.distance_to(point) <= dark_sight_radius * 1.3 or (level != null and level.is_lit_at(point)) \
			or Fire.lit_at(get_tree(), point)
		return near and Sight.in_cone(from, peek_dir(), point, PEEK_HALF_ANGLE, 9.0 * TILE) \
			and Sight.is_clear(self, from, point)
	return false


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
	mult *= Gear.stat("detect")
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
		if level and not level.is_indoor_at(global_position):
			radius *= float(Weather.value("noise"))  # 天氣：暴風雪的風聲蓋過腳步
		NoiseBus.emit_noise(global_position, radius * Gear.stat("noise"), self)
