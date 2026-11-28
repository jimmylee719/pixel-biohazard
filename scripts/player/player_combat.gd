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
## knockdown = 打倒（倒地時可以補刀）；擊退撞到牆會額外受傷、暈更久；smash = 一下劈開木箱木板
## 手上拿什麼就打什麼（WorldState.melee()）：
##   knife    小刀：揮 → 反手揮 → 刺（最後一刺最痛）。安靜、割得開木箱（要割幾下）
##   fists    空手：刺拳 → 鉤拳 → 踢（踢倒在地）。傷害低，但能把人打退、打倒再抓住
##   fire_axe／crowbar  重兵器：一下一下揮，慢但很痛
const KNIFE_COMBO := [
	{"name": "slash", "damage": 20.0, "range": 22.0, "stagger": 0.5, "knock": 50.0, "cooldown": 0.32, "noise": 2.0},
	{"name": "slash_back", "damage": 20.0, "range": 22.0, "stagger": 0.5, "knock": 50.0, "cooldown": 0.32, "noise": 2.0},
	{"name": "stab", "damage": 32.0, "range": 25.0, "stagger": 0.9, "knock": 90.0, "cooldown": 0.5, "noise": 2.0},
]
const FIST_COMBO := [
	{"name": "punch", "damage": 12.0, "range": 18.0, "stagger": 0.6, "knock": 110.0, "cooldown": 0.3, "noise": 2.0},
	{"name": "hook", "damage": 15.0, "range": 18.0, "stagger": 0.7, "knock": 140.0, "cooldown": 0.34, "noise": 2.0},
	{"name": "kick", "damage": 18.0, "range": 21.0, "stagger": 1.1, "knock": 240.0, "cooldown": 0.55, "noise": 3.0,
		"knockdown": true, "smash": true},
]
## 重兵器（物品 kind = melee）：只有一招，連按就一直揮
const MELEE_WEAPONS := {
	"fire_axe": {"name": "slash_axe", "damage": 38.0, "range": 24.0, "stagger": 0.9, "knock": 120.0, "cooldown": 0.6,
		"noise": 3.0, "smash": true},
	"crowbar": {"name": "slash_crowbar", "damage": 30.0, "range": 28.0, "stagger": 1.0, "knock": 200.0, "cooldown": 0.55,
		"noise": 3.0, "smash": true, "knockdown": true},
}
## 舊名稱（空手的連段）
const COMBO := FIST_COMBO

@export_group("瞄準")
@export var aim_half_angle_deg := 45.0
## 舉槍後多久準心完全收束
@export var aim_focus_time := 0.8
## 邊走邊射時準心最多收到多少（0～1）
@export var moving_focus_cap := 0.6

## 槍械數值。falloff = 傷害隨距離下降（散彈槍）
## 裝了消音器的手槍：槍聲只傳這麼遠（格），沒裝是 12 格
const SUPPRESSED_NOISE_TILES := 3.5
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
	# 左輪：六發、一發幾乎什麼都停得下來；裝填很慢、非常大聲
	"revolver": {"ammo": "magnum_rounds", "mag": 6, "reload": 2.6, "cooldown": 0.6, "range": 190.0,
		"damage_min": 70.0, "damage_max": 125.0, "stagger": 0.9, "noise_tiles": 16.0, "falloff": false},
	# 衝鋒槍：按住扳機連發（auto），吃手槍子彈吃得很快；每一發傷害低、準心收不太起來
	"smg": {"ammo": "ammo", "mag": 24, "reload": 1.9, "cooldown": 0.1, "range": 150.0,
		"damage_min": 14.0, "damage_max": 26.0, "stagger": 0.18, "noise_tiles": 12.0, "falloff": false, "auto": true,
		"recoil": 0.55},
	# 十字弓：沒有聲音、很痛、一次一支；射中的箭可以從屍體上拔回來（retrieve）
	"crossbow": {"ammo": "bolts", "mag": 1, "reload": 1.7, "cooldown": 0.3, "range": 200.0,
		"damage_min": 60.0, "damage_max": 110.0, "stagger": 0.8, "noise_tiles": 1.5, "falloff": false, "quiet": true,
		"retrieve": true},
	# 特殊武器（要先找到藏寶圖，見 Extras）：pose = 用哪一把槍的姿勢和槍聲
	# 燈籠站卡賓槍：原廠消音的 1962 年卡賓槍，吃步槍彈、很安靜
	"carbine": {"ammo": "rifle_rounds", "mag": 8, "reload": 2.0, "cooldown": 0.45, "range": 220.0,
		"damage_min": 55.0, "damage_max": 100.0, "stagger": 0.7, "noise_tiles": 4.0, "falloff": false, "pose": "rifle", "muffled": true},
	# 捕鯨魚叉槍：一發、非常痛、幾乎什麼都打得穿，箭可以拔回來
	"harpoon": {"ammo": "bolts", "mag": 1, "reload": 2.4, "cooldown": 0.4, "range": 230.0,
		"damage_min": 130.0, "damage_max": 220.0, "stagger": 1.4, "noise_tiles": 6.0, "falloff": false, "retrieve": true, "pose": "crossbow"},
}
## 子彈穿牆：薄牆（連續牆格數 ≤ 第一個數字）打得穿，每穿一道牆傷害乘上第二個數字。
## 牆、櫃子、置物櫃、關著的門都算；厚的外牆、岩壁打不穿。散彈、釘槍、信號彈不會穿。
const PIERCE := {"pistol": [1, 0.55], "rifle": [2, 0.8], "revolver": [1, 0.75], "smg": [1, 0.5], "carbine": [1, 0.7], "harpoon": [2, 0.9]}
## 子彈打到敵人的判定寬度（像素）
const SHOT_HIT_WIDTH := 7.0

## 目前武器的彈匣容量（沒有武器時為 0）
var magazine_size: int:
	get:
		var w := current_weapon()
		return weapon_stats(w).mag if w != "" else 0

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


## 手上的重兵器（消防斧、鐵撬）；小刀、空手 = ""
func melee_weapon() -> String:
	var m := WorldState.melee()
	return m if MELEE_WEAPONS.has(m) else ""


## 現在這種近戰的連段
func melee_moves() -> Array:
	var m := WorldState.melee()
	if MELEE_WEAPONS.has(m):
		return [MELEE_WEAPONS[m]]
	return FIST_COMBO if m == "fists" else KNIFE_COMBO


func has_weapon() -> bool:
	return current_weapon() != ""


func stats() -> Dictionary:
	return weapon_stats(current_weapon())


## 這把槍實際的數值 = WEAPONS ＋ 已經裝上的改裝件（Items.MODS，旗標 mod:<id>）
static func weapon_stats(weapon: String) -> Dictionary:
	if not WEAPONS.has(weapon):
		return {}
	var s: Dictionary = WEAPONS[weapon].duplicate()
	if WorldState.has_flag("mod:ext_mag") and (weapon == "pistol" or weapon == "smg"):
		s.mag = int(s.mag * 1.5)
	if WorldState.has_flag("mod:foregrip"):
		s["recoil"] = minf(float(s.get("recoil", 0.3)) + 0.25, 0.9)
	return s


## 這把槍用哪一把的姿勢、動畫（特殊武器沿用現有的圖）
func pose_weapon() -> String:
	var w := current_weapon()
	return WEAPONS.get(w, {}).get("pose", w)


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
		if Input.is_action_just_pressed("fire") or (stats().get("auto", false) and Input.is_action_pressed("fire")):
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
	var switch := Input.is_action_just_pressed("switch_target") \
		or (Input.is_action_just_pressed("weapon") and not Input.is_action_just_pressed("switch_target"))
	if switch and targets.size() > 1:
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
		aim_focus = minf(aim_focus + rate * delta / (aim_focus_time * (0.55 if WorldState.has_flag("mod:red_dot") else 1.0)), maxf(cap, minf(aim_focus, 1.0)))
		if moving:
			aim_focus = minf(aim_focus, cap)


## 可以鎖定的敵人：射程內、沒被牆擋住、活著（睡著的凍眠體不算）。
## 面前的優先（由近到遠），再來是旁邊、背後的——背對敵人時按瞄準也會自動轉過去鎖定，可以邊後退邊開槍。
func find_targets() -> Array[Enemy]:
	var front: Array[Enemy] = []
	var other: Array[Enemy] = []
	var half := deg_to_rad(aim_half_angle_deg)
	var reach: float = stats().get("range", 0.0)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		# 睡著的凍眠體不會被鎖定：玩家要自己分辨牠和真正的屍體
		if enemy == null or enemy.is_dead or enemy.is_dormant:
			continue
		if player.global_position.distance_to(enemy.global_position) > reach:
			continue
		if not Sight.is_clear(player, player.global_position, enemy.global_position):
			continue
		if Sight.in_cone(player.global_position, player.facing, enemy.global_position, half, reach):
			front.append(enemy)
		else:
			other.append(enemy)
	var by_dist := func(a, b):
		return player.global_position.distance_squared_to(a.global_position) \
			< player.global_position.distance_squared_to(b.global_position)
	front.sort_custom(by_dist)
	other.sort_custom(by_dist)
	front.append_array(other)
	return front


# ── 開槍、裝填 ────────────────────────────────────────

func shoot() -> bool:
	var weapon := current_weapon()
	if weapon == "" or _cooldown > 0.0 or reloading:
		return false
	var s: Dictionary = weapon_stats(weapon)
	if WorldState.get_loaded(weapon) <= 0:
		if not start_reload():
			Sfx.play("gun_empty")
		return false
	WorldState.set_loaded(weapon, WorldState.get_loaded(weapon) - 1)
	_cooldown = s.cooldown
	var origin := player.global_position
	var silenced := weapon == "pistol" and WorldState.suppressor_on()
	NoiseBus.emit_noise(origin, (SUPPRESSED_NOISE_TILES if silenced else s.noise_tiles) * Player.TILE, player)
	match String(s.get("pose", weapon)) if not s.get("muffled", false) else "muffled":
		"muffled":
			Sfx.play("pistol_shot", origin, 0.05, -14.0)
			Sfx.play("knife_swing", origin, 0.1, -4.0)
		"shotgun", "rifle", "revolver":
			Sfx.play("shotgun_shot", origin, 0.04, 2.0 if weapon == "rifle" else 0.0)
		"nailgun", "crossbow":
			Sfx.play("knife_swing", origin, 0.1, -6.0)
		"flare_gun":
			Sfx.play("pistol_shot", origin, 0.1, -6.0)
		_:
			if silenced:
				Sfx.play("pistol_shot", origin, 0.05, -14.0)
				Sfx.play("knife_swing", origin, 0.1, -4.0)
			else:
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
		_stick_bolt(target, s)
		Sfx.play("bullet_hit_flesh", target.global_position)
		end = target.global_position
		hit = true
	var holes: Array[Vector2] = []
	if not hit:
		# 沒鎖定：子彈直直飛出去，路上的敵人會被打到；薄牆打得穿（穿過去的傷害變小）
		var trace := trace_shot(origin, player.facing, s.range, PIERCE.get(weapon, [0, 1.0]))
		end = trace.end
		holes = trace.holes
		var victim: Enemy = null
		var best := INF
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if enemy == null or enemy.is_dead:
				continue
			var along := (enemy.global_position - origin).dot(player.facing)
			if along <= 0.0 or along > origin.distance_to(end) or along >= best:
				continue
			if absf(player.facing.cross(enemy.global_position - origin)) <= SHOT_HIT_WIDTH:
				victim = enemy
				best = along
		if victim:
			var walls := 0
			for h in holes:
				if origin.distance_to(h) < best:
					walls += 1
			var dmg: float = s.damage_min * pow(PIERCE.get(weapon, [0, 1.0])[1], walls)
			victim.take_damage(dmg, origin, s.stagger * (0.5 if walls > 0 else 1.0))
			_stick_bolt(victim, s)
			Sfx.play("bullet_hit_flesh", victim.global_position)
			end = victim.global_position
			hit = true
			holes = holes.filter(func(h): return origin.distance_to(h) < best)
	last_shot = {"from": origin, "to": end, "t": 0.0, "hit": hit, "holes": holes}
	if weapon == "shotgun":
		# 散彈的彈丸（畫面表現）：往前扇形散開，各自打到牆或飛到射程
		var base_dir := (end - origin).normalized()
		var pellets: Array[Vector2] = [end]
		for i in 6:
			var d := base_dir.rotated(randf_range(-0.22, 0.22))
			pellets.append(Sight.cast(player, origin, origin + d * s.range * randf_range(0.6, 1.0)))
		last_shot["pellets"] = pellets
	if s.get("fire", false) and player.level:
		# 信號彈落點起火：燒幾秒、照亮一大片
		var fire := Fire.new()
		fire.radius = 16.0
		fire.duration = 9.0
		fire.light_radius = 130.0
		player.level.add_child(fire)
		fire.global_position = end - (end - origin).normalized() * 4.0
	aim_focus = minf(aim_focus, float(s.get("recoil", 0.3)))  # 後座力：準心重新收束
	return true


## 十字弓的箭插在敵人身上：牠倒下後可以拔回來（Enemy 死的時候 main 會在屍體旁放一個可以撿的箭）
func _stick_bolt(enemy: Enemy, s: Dictionary) -> void:
	if s.get("retrieve", false):
		enemy.set_meta("bolts", int(enemy.get_meta("bolts", 0)) + 1)
		if enemy.is_dead:
			drop_bolts(enemy)


## 把插在敵人身上的箭變成地上可以撿的東西
func drop_bolts(enemy: Enemy) -> void:
	var n := int(enemy.get_meta("bolts", 0))
	if n <= 0 or player.level == null:
		return
	enemy.set_meta("bolts", 0)
	var pickup := ItemPickup.new()
	pickup.pickup_item = "bolts"
	pickup.pickup_count = n
	pickup.item_id = "bolt:%d:%d" % [Time.get_ticks_msec(), enemy.get_instance_id()]
	pickup.position = enemy.global_position - player.level.global_position
	player.level.add_interactable(pickup)


## 沿著直線追子彈：碰到牆時，如果牆夠薄（連續牆格 ≤ pierce[0]）就穿過去繼續飛。
## 回傳 {end: 子彈停下的位置, holes: 子彈穿過的牆（入口的位置，畫彈孔火花用）}
func trace_shot(origin: Vector2, dir: Vector2, reach: float, pierce: Array) -> Dictionary:
	var level: Level = player.level
	var holes: Array[Vector2] = []
	if level == null:
		return {"end": Sight.cast(player, origin, origin + dir * reach), "holes": holes}
	var max_walls: int = pierce[0]
	const STEP := 2.0
	var d := 0.0
	var in_wall := 0
	var last_cell := level.cell_of(origin)
	var entry := origin
	while d < reach:
		d += STEP
		var p := origin + dir * d
		var cell := level.cell_of(p)
		if cell == last_cell:
			continue
		last_cell = cell
		if _blocks_shot(level, cell):
			if in_wall == 0:
				entry = p
			in_wall += 1
			if in_wall > max_walls:
				return {"end": entry, "holes": holes}
		elif in_wall > 0:
			holes.append(entry)
			in_wall = 0
	return {"end": entry if in_wall > 0 else origin + dir * reach, "holes": holes}


func _blocks_shot(level: Level, cell: Vector2i) -> bool:
	var ch := level.char_at(cell)
	if ch == "+":
		for door in level.get_inner_doors():
			if door.cell == cell:
				return not door.is_open
		return false
	return ch == "#" or ch == "C" or ch == "H" or ch == ""


func start_reload() -> bool:
	var weapon := current_weapon()
	if weapon == "" or reloading:
		return false
	var s: Dictionary = weapon_stats(weapon)
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
	var s: Dictionary = weapon_stats(weapon)
	var got := WorldState.inv_remove(s.ammo, s.mag - WorldState.get_loaded(weapon))
	WorldState.set_loaded(weapon, WorldState.get_loaded(weapon) + got)


# ── 近戰 ──────────────────────────────────────────────

func melee() -> bool:
	if _cooldown > 0.0:
		return false
	var moves := melee_moves()
	combo_step = combo_step + 1 if _since_melee <= combo_window and combo_step < moves.size() - 1 else 0
	combo_step = mini(combo_step, moves.size() - 1)
	_since_melee = 0.0
	var move: Dictionary = moves[combo_step]
	_cooldown = move.cooldown
	var origin := player.global_position
	var half := deg_to_rad(melee_half_angle_deg)
	# 刺是直直往前：範圍窄一點、遠一點
	if move.name == "stab":
		half *= 0.6
	var reach: float = move.range
	var takedown := false
	var hit_any := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead:
			continue
		if not Sight.in_cone(origin, player.facing, enemy.global_position, half, reach):
			continue
		var damage: float = move.damage
		if move.name == "kick":
			damage *= Gear.stat("kick")
		if enemy.can_be_taken_down_by(player):
			damage *= takedown_mult
			takedown = true
		enemy.take_damage(damage, origin, move.stagger)
		enemy.apply_knockback(player.facing, move.knock, move.get("knockdown", false))
		hit_any = true
	match move.name:
		"slash", "slash_back", "stab":
			Sfx.play("knife_hit" if hit_any else "knife_swing", origin)
		"punch", "hook":
			Sfx.play("punch_hit" if hit_any else "knife_swing", origin, 0.1, -4.0)
		"kick":
			Sfx.play("kick_hit" if hit_any else "knife_swing", origin, 0.1, -2.0)
		_:
			Sfx.play("kick_hit" if hit_any else "knife_swing", origin, 0.06, 0.0)
	if hit_any:
		Sfx.rumble(40 if not move.get("knockdown", false) else 90, 0.5)
	# 小刀割得開木箱、木板（安靜，但要割好幾下）；踢、斧頭、鐵撬一下就破（比較大聲）；拳頭打不開
	if player.level:
		for item in player.level.get_interactables():
			if item is Breakable and item.enabled \
					and Sight.in_cone(origin, player.facing, item.global_position, deg_to_rad(melee_half_angle_deg), reach + 8.0):
				if move.get("smash", false):
					item.smash(4.0)
				elif move.name.begins_with("slash") or move.name == "stab":
					item.cut()
	# 先結算傷害再發出聲音：不然被偷襲的敵人會在同一瞬間「聽到」揮刀聲而無法偷襲
	NoiseBus.emit_noise(origin, float(move.noise) * Player.TILE, player)
	last_melee = {"pos": origin, "dir": player.facing, "t": 0.0, "takedown": takedown, "move": move.name, "hit": hit_any}
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


## 可以從背後一擊解決的敵人（在近戰範圍內、沒發現主角、主角在他背後）；沒有 = null。給畫面提示用。
func takedown_target() -> Enemy:
	if player.is_hiding or grabbed != null:
		return null
	var best: Enemy = null
	var best_d := melee_range + 6.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead or enemy.is_boss():
			continue
		var d := player.global_position.distance_to(enemy.global_position)
		if d < best_d and enemy.can_be_taken_down_by(player):
			best = enemy
			best_d = d
	return best
