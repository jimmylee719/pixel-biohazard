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

@export_group("瞄準")
@export var aim_half_angle_deg := 45.0
## 舉槍後多久準心完全收束
@export var aim_focus_time := 0.8

## 槍械數值。falloff = 傷害隨距離下降（散彈槍）
const WEAPONS := {
	"pistol": {"ammo": "ammo", "mag": 8, "reload": 1.3, "cooldown": 0.35, "range": 170.0,
		"damage_min": 25.0, "damage_max": 55.0, "stagger": 0.35, "noise_tiles": 12.0, "falloff": false},
	"shotgun": {"ammo": "shells", "mag": 2, "reload": 1.8, "cooldown": 0.9, "range": 96.0,
		"damage_min": 70.0, "damage_max": 110.0, "stagger": 0.9, "noise_tiles": 14.0, "falloff": true},
}

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


func has_weapon() -> bool:
	return current_weapon() != ""


func stats() -> Dictionary:
	return WEAPONS.get(current_weapon(), {})


func reload_progress() -> float:
	return 1.0 - _reload_timer / stats().reload if reloading and has_weapon() else 0.0


## 被打到時中斷舉槍、裝填。
func interrupt() -> void:
	aiming = false
	target = null
	aim_focus = 0.0
	reloading = false


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	for fx in [last_shot, last_melee]:
		if not fx.is_empty():
			fx.t += delta

	if not player.input_enabled or player.is_hiding or player.is_dead:
		interrupt()
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
		aim_focus = minf(aim_focus + delta / aim_focus_time, 1.0)


## 主角面前、射程內、沒被牆擋住的活著的敵人，由近到遠。
func find_targets() -> Array[Enemy]:
	var result: Array[Enemy] = []
	var half := deg_to_rad(aim_half_angle_deg)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead:
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
		start_reload()
		return false
	WorldState.set_loaded(weapon, WorldState.get_loaded(weapon) - 1)
	_cooldown = s.cooldown
	var origin := player.global_position
	NoiseBus.emit_noise(origin, s.noise_tiles * Player.TILE, player)
	var hit := false
	var end: Vector2
	if target and not target.is_dead:
		var damage: float = lerpf(s.damage_min, s.damage_max, aim_focus)
		if s.falloff:
			var dist := origin.distance_to(target.global_position)
			damage *= clampf(1.3 - dist / s.range, 0.3, 1.0)
		target.take_damage(damage, origin, s.stagger)
		end = target.global_position
		hit = true
	else:
		end = Sight.cast(player, origin, origin + player.facing * s.range)
	last_shot = {"from": origin, "to": end, "t": 0.0, "hit": hit}
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
	_cooldown = melee_cooldown
	var origin := player.global_position
	var half := deg_to_rad(melee_half_angle_deg)
	var takedown := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead:
			continue
		if not Sight.in_cone(origin, player.facing, enemy.global_position, half, melee_range):
			continue
		var damage := melee_damage
		if enemy.can_be_taken_down_by(player):
			damage *= takedown_mult
			takedown = true
		enemy.take_damage(damage, origin, melee_stagger)
	# 先結算傷害再發出聲音：不然被偷襲的敵人會在同一瞬間「聽到」揮刀聲而無法偷襲
	NoiseBus.emit_noise(origin, melee_noise_tiles * Player.TILE, player)
	last_melee = {"pos": origin, "dir": player.facing, "t": 0.0, "takedown": takedown}
	return true
