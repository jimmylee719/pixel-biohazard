## 主角的戰鬥：近戰（隨時可用）、槍械（手槍／散彈槍，舉槍自動鎖定、等越久越準）、裝填。
## 用哪把槍：WorldState.equipped（在物品欄「使用」武器就會裝備）。
## 瞄準採「朝向＋自動鎖定」，不需要滑鼠精準瞄準：鍵盤、手把、觸控都能玩。
## 所有輸入只透過 InputMap：aim、fire、switch_target、reload。
class_name PlayerCombat
extends Node

@export_group("近戰（小刀）")
@export var melee_damage := 20.0
@export var melee_range := 22.0
@export var melee_half_angle_deg := 55.0
@export var melee_cooldown := 0.5
@export var melee_stagger := 0.5
@export var melee_noise_tiles := 2.0
## 從背後偷襲沒察覺的敵人：傷害倍率（一刀解決一般值班者）
@export var takedown_mult := 4.0
## 連段：在 combo_window 秒內再按一次就接下一招（刀 → 拳 → 踢）
@export var combo_window := 0.5

@export_group("擒拿（CQC）")
## 從背後抓住沒察覺／被踢倒的敵人。抓住後：攻擊 = 解決、投擲 = 摔倒、互動 = 放開
@export var grab_reach := 18.0
## 怪物掙脫的時間（人類比較久）
@export var grab_hold_monster := 3.0
@export var grab_hold_human := 5.0
@export var slam_damage := 25.0
@export var slam_down_time := 2.5

## 近戰連段：每一招的傷害、距離、硬直、擊退力道（像素／秒）、冷卻、聲音
## knockdown = 踢倒（倒地時可以補刀）；擊退撞到牆會額外受傷、暈更久
const COMBO := [
	{"name": "slash", "damage": 20.0, "range": 22.0, "stagger": 0.5, "knock": 60.0, "cooldown": 0.32, "noise": 2.0},
	{"name": "punch", "damage": 12.0, "range": 18.0, "stagger": 0.6, "knock": 110.0, "cooldown": 0.3, "noise": 2.0},
	{"name": "kick", "damage": 18.0, "range": 21.0, "stagger": 1.1, "knock": 240.0, "cooldown": 0.55, "noise": 3.0,
		"knockdown": true},
]

@export_group("瞄準")
@export var aim_half_angle_deg := 45.0
## 舉槍後多久準心完全收束
@export var aim_focus_time := 0.8
## 邊走邊射時準心最多收到多少（0～1）
@export var moving_focus_cap := 0.6

## 槍械數值。falloff = 傷害隨距離下降（散彈槍）
const WEAPONS := {
	"pistol": {"ammo": "ammo", "mag": 8, "reload": 1.3, "cooldown": 0.35, "range": 170.0,
		"damage_min": 25.0, "damage_max": 55.0, "stagger": 0.35, "noise_tiles": 12.0, "falloff": false},
	"shotgun": {"ammo": "shells", "mag": 2, "reload": 1.8, "cooldown": 0.9, "range": 96.0,
		"damage_min": 70.0, "damage_max": 110.0, "stagger": 0.9, "noise_tiles": 14.0, "falloff": true},
	# 獵槍：射程最遠、一發很痛，但裝填慢、整座島都聽得到
	"rifle": {"ammo": "rifle_rounds", "mag": 5, "reload": 2.4, "cooldown": 1.1, "range": 260.0,
		"damage_min": 80.0, "damage_max": 140.0, "stagger": 1.0, "noise_tiles": 20.0, "falloff": false},
	# 釘槍：傷害低但幾乎沒聲音（潛入用）
	"nailgun": {"ammo": "nails", "mag": 12, "reload": 1.6, "cooldown": 0.22, "range": 110.0,
		"damage_min": 10.0, "damage_max": 20.0, "stagger": 0.15, "noise_tiles": 2.5, "falloff": false, "quiet": true},
	# 信號槍：打到的地方起火、照亮一大片（引開、燒怪、看清楚黑暗）
	"flare_gun": {"ammo": "flares", "mag": 1, "reload": 1.5, "cooldown": 0.8, "range": 150.0,
		"damage_min": 15.0, "damage_max": 25.0, "stagger": 0.6, "noise_tiles": 7.0, "falloff": false, "fire": true},
}
## 近戰武器：有的話第一下（揮砍）換成它（傷害倍率、可以一下劈開木箱木板）
const MELEE_WEAPONS := {"fire_axe": {"mult": 1.9, "noise": 3.0}}

## 目前武器的彈匣容量（沒有武器時為 0）
var magazine_size: int:
	get:
		var w := current_weapon()
		return WEAPONS[w].mag if w != "" else 0

var aiming := false
var target: Enemy = null
var aim_focus := 0.0
var reloading := false
## 最近一次開槍 {from, to, t, hit}，給畫面畫彈道用
var last_shot := {}
## 最近一次近戰 {pos, dir, t, takedown}
var last_melee := {}

var _cooldown := 0.0
var _reload_timer := 0.0
## 連段第幾招（0 = 刀）、距離上一招幾秒
var combo_step := 0
var _since_melee := 99.0
## 正在擒拿的敵人
var grabbed: Enemy = null
var _grab_timer := 0.0
var _grab_frame := -1

@onready var player: Player = get_parent()


func has_pistol() -> bool:
	return WorldState.inv_count("pistol") > 0


## 實際拿在手上的槍：裝備中的那把；如果它被放進儲物箱了，就換成身上有的另一把。
func current_weapon() -> String:
	if WorldState.inv_count(WorldState.equipped) > 0 and WEAPONS.has(WorldState.equipped):
		return WorldState.equipped
	for w in WEAPONS:
		if WorldState.inv_count(w) > 0:
			return w
	return ""


## 身上有的近戰武器（沒有 = 小刀）
func melee_weapon() -> String:
	for w in MELEE_WEAPONS:
		if WorldState.inv_count(w) > 0:
			return w
	return ""


func has_weapon() -> bool:
	return current_weapon() != ""


func stats() -> Dictionary:
	return WEAPONS.get(current_weapon(), {})


func reload_progress() -> float:
	return 1.0 - _reload_timer / stats().reload if reloading and has_weapon() else 0.0


## 被打到時中斷舉槍、裝填。
func interrupt() -> void:
	_release_grab()
	aiming = false
	target = null
	aim_focus = 0.0
	reloading = false


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_since_melee += delta
	for fx in [last_shot, last_melee]:
		if not fx.is_empty():
			fx.t += delta

	if not player.input_enabled or player.is_hiding or player.is_dead or player.is_carrying():
		interrupt()
		return
	if grabbed:
		_process_grab(delta)
		return

	if reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()

	aiming = Input.is_action_pressed("aim") and has_weapon() and not reloading
	if aiming:
		_update_aim(delta)
		if Input.is_action_just_pressed("fire"):
			shoot()
	else:
		target = null
		aim_focus = 0.0
		if Input.is_action_just_pressed("fire"):
			melee()

	if Input.is_action_just_pressed("reload"):
		start_reload()


# ── 瞄準 ──────────────────────────────────────────────

func _update_aim(delta: float) -> void:
	var targets := find_targets()
	if target == null or not targets.has(target):
		target = targets[0] if not targets.is_empty() else null
		aim_focus = 0.0
	if Input.is_action_just_pressed("switch_target") and targets.size() > 1:
		target = targets[(targets.find(target) + 1) % targets.size()]
		aim_focus = 0.0
	if target:
		player.facing = (target.global_position - player.global_position).normalized()
		# 邊走邊射：準心收得比較慢，而且收不到最準
		var moving := player.velocity.length() > 10.0
		var rate := 0.5 if moving else 1.0
		if player.is_shivering():
			rate *= 0.6  # 手在發抖
		var cap := moving_focus_cap if moving else 1.0
		aim_focus = minf(aim_focus + rate * delta / aim_focus_time, maxf(cap, minf(aim_focus, 1.0)))
		if moving:
			aim_focus = minf(aim_focus, cap)


## 主角面前、射程內、沒被牆擋住的活著的敵人，由近到遠。
func find_targets() -> Array[Enemy]:
	var result: Array[Enemy] = []
	var half := deg_to_rad(aim_half_angle_deg)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		# 睡著的凍眠體不會被鎖定：玩家要自己分辨牠和真正的屍體
		if enemy == null or enemy.is_dead or enemy.is_dormant:
			continue
		if not Sight.in_cone(player.global_position, player.facing, enemy.global_position, half, stats().get("range", 0.0)):
			continue
		if Sight.is_clear(player, player.global_position, enemy.global_position):
			result.append(enemy)
	result.sort_custom(func(a, b):
		return player.global_position.distance_squared_to(a.global_position) \
			< player.global_position.distance_squared_to(b.global_position))
	return result


# ── 開槍、裝填 ────────────────────────────────────────

func shoot() -> bool:
	var weapon := current_weapon()
	if weapon == "" or _cooldown > 0.0 or reloading:
		return false
	var s: Dictionary = WEAPONS[weapon]
	if WorldState.get_loaded(weapon) <= 0:
		if not start_reload():
			Sfx.play("gun_empty")
		return false
	WorldState.set_loaded(weapon, WorldState.get_loaded(weapon) - 1)
	_cooldown = s.cooldown
	var origin := player.global_position
	NoiseBus.emit_noise(origin, s.noise_tiles * Player.TILE, player)
	match weapon:
		"shotgun", "rifle":
			Sfx.play("shotgun_shot", origin, 0.04, 2.0 if weapon == "rifle" else 0.0)
		"nailgun":
			Sfx.play("knife_swing", origin, 0.1, -6.0)
		"flare_gun":
			Sfx.play("pistol_shot", origin, 0.1, -6.0)
		_:
			Sfx.play("pistol_shot", origin, 0.04)
	Sfx.rumble(60 if weapon == "pistol" else 110, 0.6)
	var hit := false
	var end: Vector2
	if target and not target.is_dead:
		var damage: float = lerpf(s.damage_min, s.damage_max, aim_focus)
		if s.falloff:
			var dist := origin.distance_to(target.global_position)
			damage *= clampf(1.3 - dist / s.range, 0.3, 1.0)
		target.take_damage(damage, origin, s.stagger)
		Sfx.play("bullet_hit_flesh", target.global_position)
		end = target.global_position
		hit = true
	else:
		end = Sight.cast(player, origin, origin + player.facing * s.range)
	last_shot = {"from": origin, "to": end, "t": 0.0, "hit": hit}
	if s.get("fire", false) and player.level:
		# 信號彈落點起火：燒幾秒、照亮一大片
		var fire := Fire.new()
		fire.radius = 16.0
		fire.duration = 9.0
		fire.light_radius = 130.0
		player.level.add_child(fire)
		fire.global_position = end - (end - origin).normalized() * 4.0
	aim_focus = minf(aim_focus, 0.3)  # 後座力：準心重新收束
	return true


func start_reload() -> bool:
	var weapon := current_weapon()
	if weapon == "" or reloading:
		return false
	var s: Dictionary = WEAPONS[weapon]
	if WorldState.get_loaded(weapon) >= s.mag or WorldState.inv_count(s.ammo) <= 0:
		return false
	reloading = true
	_reload_timer = s.reload
	Sfx.play("reload")
	return true


func _finish_reload() -> void:
	reloading = false
	var weapon := current_weapon()
	if weapon == "":
		return
	var s: Dictionary = WEAPONS[weapon]
	var got := WorldState.inv_remove(s.ammo, s.mag - WorldState.get_loaded(weapon))
	WorldState.set_loaded(weapon, WorldState.get_loaded(weapon) + got)


# ── 近戰 ──────────────────────────────────────────────

func melee() -> bool:
	if _cooldown > 0.0:
		return false
	combo_step = combo_step + 1 if _since_melee <= combo_window and combo_step < COMBO.size() - 1 else 0
	_since_melee = 0.0
	var move: Dictionary = COMBO[combo_step]
	_cooldown = move.cooldown
	var origin := player.global_position
	var half := deg_to_rad(melee_half_angle_deg)
	var reach: float = move.range if combo_step > 0 else melee_range
	var takedown := false
	var hit_any := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead:
			continue
		if not Sight.in_cone(origin, player.facing, enemy.global_position, half, reach):
			continue
		var damage: float = melee_damage if combo_step == 0 else move.damage
		if combo_step == 0 and melee_weapon() != "":
			damage *= MELEE_WEAPONS[melee_weapon()].mult
		if enemy.can_be_taken_down_by(player):
			damage *= takedown_mult
			takedown = true
		enemy.take_damage(damage, origin, move.stagger)
		enemy.apply_knockback(player.facing, move.knock, move.get("knockdown", false))
		hit_any = true
	match move.name:
		"slash":
			Sfx.play("knife_hit" if hit_any else "knife_swing", origin)
		"punch":
			Sfx.play("punch_hit" if hit_any else "knife_swing", origin, 0.1, -4.0)
		"kick":
			Sfx.play("kick_hit" if hit_any else "knife_swing", origin, 0.1, -2.0)
	if hit_any:
		Sfx.rumble(40 if combo_step < 2 else 90, 0.5)
	# 小刀割得開木箱、木板（安靜，但要割好幾下）；踢一腳直接踢破（比較大聲）
	if player.level:
		for item in player.level.get_interactables():
			if item is Breakable and item.enabled \
					and Sight.in_cone(origin, player.facing, item.global_position, half, reach + 8.0):
				if move.name == "kick" or (combo_step == 0 and melee_weapon() != ""):
					item.smash(4.0)
				else:
					item.cut()
	# 先結算傷害再發出聲音：不然被偷襲的敵人會在同一瞬間「聽到」揮刀聲而無法偷襲
	NoiseBus.emit_noise(origin, (melee_noise_tiles if combo_step == 0 else move.noise) * Player.TILE, player)
	last_melee = {"pos": origin, "dir": player.facing, "t": 0.0, "takedown": takedown, "move": move.name}
	return true


# ── 擒拿（CQC）────────────────────────────────────────

## 面前可以抓的敵人：沒察覺、在牠背後，或被踢倒在地上。Boss、睡著的不行。
func grab_target() -> Enemy:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead or enemy.is_dormant or enemy.is_boss():
			continue
		if not Sight.in_cone(player.global_position, player.facing, enemy.global_position, deg_to_rad(50.0), grab_reach):
			continue
		if enemy.can_be_taken_down_by(player) or enemy.knocked_down:
			return enemy
	return null


func grab() -> bool:
	if grabbed or player.is_carrying() or player.is_hiding:
		return false
	var enemy := grab_target()
	if enemy == null:
		return false
	grabbed = enemy
	_grab_frame = Engine.get_physics_frames()
	_grab_timer = grab_hold_human if enemy.faction == "human" else grab_hold_monster
	enemy.set_grabbed(true)
	Sfx.play("grab", enemy.global_position)
	Sfx.rumble(60, 0.6)
	return true


## 抓住時：敵人被拖在面前；攻擊 = 安靜解決、投擲 = 摔在地上、互動 = 放開。時間到敵人會掙脫。
func _process_grab(delta: float) -> void:
	if grabbed == null or not is_instance_valid(grabbed) or grabbed.is_dead:
		_release_grab()
		return
	grabbed.global_position = player.global_position + player.facing * 10.0
	if Engine.get_physics_frames() == _grab_frame:
		return  # 抓住的這一幀按下的互動鍵不算「放開」
	_grab_timer -= delta
	if Input.is_action_just_pressed("fire"):
		var e := grabbed
		_release_grab()
		e.take_damage(e.max_health * 2.0, player.global_position, 0.0)  # 從背後勒住解決，幾乎沒有聲音
		NoiseBus.emit_noise(player.global_position, 1.0 * Player.TILE, player)
		Sfx.play("knife_hit", e.global_position, 0.1, -6.0)
		last_melee = {"pos": player.global_position, "dir": player.facing, "t": 0.0, "takedown": true, "move": "choke"}
	elif Input.is_action_just_pressed("throw"):
		slam()
	elif Input.is_action_just_pressed("interact"):
		var e := grabbed
		_release_grab()
		e.apply_knockback(player.facing, 90.0, false)
	elif _grab_timer <= 0.0:
		var e := grabbed
		_release_grab()
		e.break_free(player.global_position)
		player.velocity = -player.facing * 120.0


## 摔倒：敵人倒地一段時間（可以補刀或趁機跑掉），會發出聲音
func slam() -> void:
	if grabbed == null:
		return
	var e := grabbed
	_release_grab()
	e.global_position = player.global_position + player.facing * 14.0
	e.take_damage(slam_damage, player.global_position, slam_down_time)
	e.apply_knockback(player.facing, 40.0, true)
	NoiseBus.emit_noise(player.global_position, 4.0 * Player.TILE, player)
	Sfx.play("body_slam", e.global_position)
	Sfx.rumble(120, 0.8)
	last_melee = {"pos": player.global_position, "dir": player.facing, "t": 0.0, "takedown": false, "move": "slam"}


func _release_grab() -> void:
	if grabbed and is_instance_valid(grabbed):
		grabbed.set_grabbed(false)
	grabbed = null
