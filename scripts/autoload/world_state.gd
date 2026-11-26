## 世界狀態：所有需要跨區域、跨重來保存的東西都放這裡。
## 撿過的物品、暖氣開關、任務進度、物品欄、生命值與感染值、死掉的敵人、取得的情報……
## 之後的存檔功能也只要把 data 存起來。
##
## 檢查點：每次進入一個區域時記錄一次。被抓到時回到最近的檢查點（區域入口）。
extends Node

## 遊戲事件（任務系統監聽）：kind = "enter_area" / "interact" / "collect"，id = 物件或區域名稱
signal game_event(kind: String, id: String)
signal changed
## 換了裝備（外型、能力要更新）
signal gear_changed
## 圖鑑多了一筆（敵人第一次看到、武器第一次拿到）
signal codex_unlocked(id: String)

const START_SLOTS := 8
const MAX_HEALTH := 100.0
const MAX_INFECTION := 100.0
const MAX_BODY_TEMP := 100.0

const SAVE_VERSION := 1

## 存檔位置（測試時可以改成別的檔名）
var save_path := "user://save.dat"
var data := {}
var _checkpoint := {}


## 玩家設定（不跟存檔走）：語言
const SETTINGS_PATH := "user://settings.cfg"
const LANGUAGES := ["zh_TW", "en"]
## 預設語言（第一次開遊戲）
const DEFAULT_LANGUAGE := "zh_TW"


func _ready() -> void:
	load_profile()
	new_game()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	TranslationServer.set_locale(cfg.get_value("game", "language", DEFAULT_LANGUAGE))
	load_options.call_deferred()


func language() -> String:
	return "en" if TranslationServer.get_locale().begins_with("en") else "zh_TW"


## 切換語言並記住（下次開遊戲也是這個語言）
func set_language(code: String) -> void:
	TranslationServer.set_locale(code)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("game", "language", code)
	cfg.save(SETTINGS_PATH)


## ── 選項（設定畫面，跟語言一起存在 settings.cfg 的 options 區段，不跟存檔走）──
## 依 iOS 同類遊戲的玩家評價加的（docs/IP_REVIEW.md）：音樂／音效分開調、觸控按鈕透明度與左右對調、
## 「聲音提示」（畫面邊緣顯示畫面外的腳步聲，沒戴耳機也能玩）、輔助模式（受傷和雜訊減半）、省電模式（30 FPS）。
const OPTION_DEFAULTS := {
	"music": 0.8, "sfx": 1.0, "touch_opacity": 0.22, "left_handed": false,
	"sound_cues": true, "assist": false, "battery_saver": false,
}
var options := OPTION_DEFAULTS.duplicate()
signal options_changed


func option(key: String) -> Variant:
	return options.get(key, OPTION_DEFAULTS.get(key))


func set_option(key: String, value: Variant, save := true) -> void:
	options[key] = value
	apply_options()
	if save:
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS_PATH)
		cfg.set_value("options", key, value)
		cfg.save(SETTINGS_PATH)
	options_changed.emit()


func load_options() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	for key in OPTION_DEFAULTS:
		options[key] = cfg.get_value("options", key, OPTION_DEFAULTS[key])
	apply_options()


func apply_options() -> void:
	Sfx.set_bus_volume("Music", float(option("music")))
	Sfx.set_bus_volume("SFX", float(option("sfx")))
	Sfx.set_bus_volume("Ambience", float(option("sfx")))
	Engine.max_fps = 30 if option("battery_saver") else 0


## 輔助模式：受到的傷害、累積的雜訊值乘上這個倍率
func assist_mult() -> float:
	return 0.5 if option("assist") else 1.0


## 過場動畫要不要播（測試、截圖工具會關掉）
var cutscenes := true
## 新遊戲時要不要給起始裝備（配槍）。行為測試關掉：測試從空手開始檢查撿槍、裝填。
var start_loadout := true
## 遊戲模式："story"（主線）、"survival"（生存模式「長夜」，見 SurvivalMode）
var mode := "story"
## 生存模式這一局的設定 {map, weapon}（生存選單設定）
var survival_setup := {}


# ── 玩家檔案（跨存檔、跨模式：殘響點數、解鎖、最高紀錄）。存在 user://profile.cfg，和主線存檔分開 ──

var profile_path := "user://profile.cfg"
var profile := {}


func load_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.load(profile_path)
	profile = {
		"points": cfg.get_value("profile", "points", 0),
		"unlocks": cfg.get_value("profile", "unlocks", []),
		"best": cfg.get_value("profile", "best", {}),
	}


func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "points", profile.points)
	cfg.set_value("profile", "unlocks", profile.unlocks)
	cfg.set_value("profile", "best", profile.best)
	cfg.save(profile_path)


## 開始一局生存模式：全新的遊戲資料、指定地圖、起始裝備（手槍＋選的武器＋解鎖的道具）
func start_survival(map: String, weapon: String) -> void:
	mode = "survival"
	survival_setup = {"map": map, "weapon": weapon}
	new_game()
	var m: Dictionary = SurvivalData.MAPS[map]
	data.area = map
	data.entry = m.entry
	if m.get("power", false):
		set_flag("power_on")
	inv_add("pistol", 1)
	set_loaded("pistol", 8)
	inv_add("ammo", 16)
	if weapon != "pistol":
		var l: Dictionary = SurvivalData.LOADOUTS[weapon]
		inv_add(weapon, 1)
		set_loaded(weapon, PlayerCombat.WEAPONS[weapon].mag)
		inv_add(l.ammo[0], l.ammo[1])
		equipped = weapon
	inv_add("med", 2 if is_unlocked("perk_med") else 1)
	inv_add("stone", 2)
	if is_unlocked("melee_axe"):
		inv_add("fire_axe", 1)
	_checkpoint = data.duplicate(true)


## 回到主線模式（標題畫面的新遊戲／繼續）
func start_story() -> void:
	mode = "story"
	survival_setup = {}


func reset_profile() -> void:
	profile = {"points": 0, "unlocks": [], "best": {}}
	save_profile()


func profile_points() -> int:
	return profile.points


func add_points(n: int) -> void:
	profile.points += n
	save_profile()


func is_unlocked(id: String) -> bool:
	return profile.unlocks.has(id)


## 花點數解鎖；點數不夠或已經有了回傳 false
func buy_unlock(id: String, cost: int) -> bool:
	if is_unlocked(id) or profile.points < cost:
		return false
	profile.points -= cost
	profile.unlocks.append(id)
	save_profile()
	return true


## 生存模式的最高紀錄（每張地圖）
func best_record(map: String) -> Dictionary:
	return profile.best.get(map, {})


## 記錄一局的成績；破紀錄回傳 true
func record_best(map: String, score: int, wave: int, rank: String) -> bool:
	var old: Dictionary = profile.best.get(map, {})
	var better: bool = old.is_empty() or score > old.get("score", 0)
	if better:
		profile.best[map] = {"score": score, "wave": maxi(wave, old.get("wave", 0)), "rank": rank}
	elif wave > old.get("wave", 0):
		old["wave"] = wave
	save_profile()
	return better


func new_game() -> void:
	data = {
		"area": Areas.START_AREA,
		"entry": Areas.START_ENTRY,
		"inventory": _empty_inventory(START_SLOTS),
		"health": MAX_HEALTH,
		"infection": 0.0,
		"loaded": {"pistol": 0, "shotgun": 0},
		"equipped": "pistol",
		"access_level": 0,
		"carrying": "",
		"storage": {},
		"flags": {},
		"ready_throw": "bottle",
		"extinguisher": 0,
		"body_temp": MAX_BODY_TEMP,
		"enemies": {},
		"codex": {},
		"quick_item": "light",
		"gear": Gear.START_EQUIPPED.duplicate(),
		"gear_owned": Gear.START_OWNED.duplicate(),
		"explored": {},
	}
	if mode == "story" and start_loadout:
		# 主線一開始身上就有配槍（一個彈匣＋一盒備彈）：這是一款以槍為主的潛行遊戲
		inv_add("pistol", 1)
		inv_add("ammo", 16)
		data.loaded.pistol = 8
		data.codex["pistol"] = true
	if mode == "story":
		for unlock in SurvivalData.STORY_CACHES:
			if is_unlocked(unlock):
				for item_id in SurvivalData.STORY_CACHES[unlock]:
					data.storage[item_id] = data.storage.get(item_id, 0) + SurvivalData.STORY_CACHES[unlock][item_id]
	_checkpoint = data.duplicate(true)


# ── 裝備（紙娃娃，見 Gear）──

func owns_gear(id: String) -> bool:
	return data.gear_owned.has(id)


func add_gear(id: String) -> void:
	if not owns_gear(id):
		data.gear_owned.append(id)


## 穿上（id = "" 時脫掉這個欄位，身體不能空著）
func equip_gear(slot: String, id: String) -> bool:
	if id != "" and (not owns_gear(id) or Gear.DATA[id].slot != slot):
		return false
	if id == "" and slot == "body":
		return false
	data.gear[slot] = id
	gear_changed.emit()
	return true


# ── 圖鑑（看過的敵人、拿過的武器）──

## 看到（或拿到）了：圖鑑上出現這一筆
func codex_see(id: String) -> void:
	if not data.codex.has(id):
		data.codex[id] = {"kills": 0}
		codex_unlocked.emit(id)


func codex_kill(id: String) -> void:
	codex_see(id)
	data.codex[id].kills += 1


func codex_has(id: String) -> bool:
	return data.codex.has(id)


func codex_kills(id: String) -> int:
	return data.codex[id].kills if data.codex.has(id) else 0


# ── 通用旗標 ──

func has_flag(key: String) -> bool:
	return data.flags.has(key)


func get_flag(key: String, default: Variant = null) -> Variant:
	return data.flags.get(key, default)


func set_flag(key: String, value: Variant = true) -> void:
	data.flags[key] = value
	changed.emit()


# ── 常用的包裝 ──

var health: float:
	get:
		return data.health
	set(value):
		data.health = clampf(value, 0.0, MAX_HEALTH)
		changed.emit()

var infection: float:
	get:
		return data.infection
	set(value):
		data.infection = clampf(value, 0.0, MAX_INFECTION)
		changed.emit()

var pistol_loaded: int:
	get:
		return get_loaded("pistol")
	set(value):
		set_loaded("pistol", value)


## 每把武器彈匣裡的子彈數
func get_loaded(weapon: String) -> int:
	return data.loaded.get(weapon, 0)


func set_loaded(weapon: String, value: int) -> void:
	data.loaded[weapon] = value
	changed.emit()


## 權限卡等級（取代一堆彩色鑰匙，見 GDD 8.3）
var access_level: int:
	get:
		return data.access_level
	set(value):
		data.access_level = maxi(data.access_level, value)
		changed.emit()


## 雙手搬運中的東西（例如 "fuel"），空字串 = 沒有
var carrying: String:
	get:
		return data.carrying
	set(value):
		data.carrying = value
		changed.emit()


## 準備投擲的東西（物品 id）
var ready_throw: String:
	get:
		return data.ready_throw
	set(value):
		data.ready_throw = value
		changed.emit()


## 手上滅火器剩下的噴射次數（carrying == "extinguisher" 時有意義）
var extinguisher_charge: int:
	get:
		return data.extinguisher
	set(value):
		data.extinguisher = maxi(value, 0)
		changed.emit()


## 體溫（0～100）。只有會失溫的氣候才會下降，見 Climates。
var body_temp: float:
	get:
		return data.body_temp
	set(value):
		data.body_temp = clampf(value, 0.0, MAX_BODY_TEMP)


## 研究站的電力（發電機）
var power_on: bool:
	get:
		return has_flag("power_on")


## 天線塔發出的訊號（結局方向）："rescue"、"quarantine"、"destroy"，還沒發就是空字串
const SIGNAL_CHOICES := ["rescue", "quarantine", "destroy"]


func signal_choice() -> String:
	return get_flag("signal", "")


var equipped: String:
	get:
		return data.equipped
	set(value):
		data.equipped = value
		changed.emit()


# ── 無線電頻率 ──

func is_freq_known(freq: int) -> bool:
	return has_flag("freq_known:%d" % freq) or Frequencies.by_freq(freq).get("known", false)


func learn_freq(freq: int) -> bool:
	if is_freq_known(freq):
		return false
	set_flag("freq_known:%d" % freq)
	return true


## 備忘錄：知道的頻率，由小到大
func known_freqs() -> Array[int]:
	var result: Array[int] = []
	for f in Frequencies.DATA:
		if is_freq_known(f.freq):
			result.append(f.freq)
	result.sort()
	return result

## 空瓶數（相容舊程式：其實是物品欄裡的 bottle 數量）
var bottles: int:
	get:
		return inv_count("bottle")
	set(value):
		var diff := value - inv_count("bottle")
		if diff > 0:
			inv_add("bottle", diff)
		elif diff < 0:
			inv_remove("bottle", -diff)


func is_enemy_dead(enemy_key: String) -> bool:
	return has_flag("dead:" + enemy_key)


## 記住死掉的位置，屍體會留在那裡
## 離開區域時記下活著的敵人在哪、在做什麼；回來時從這裡接著（不會全部回到原位）
func store_enemy(enemy_key: String, snapshot: Dictionary) -> void:
	data.enemies[enemy_key] = snapshot


func enemy_snapshot(enemy_key: String) -> Dictionary:
	return data.get("enemies", {}).get(enemy_key, {})


func mark_enemy_dead(enemy_key: String, position: Vector2) -> void:
	set_flag("dead:" + enemy_key, position)


func enemy_death_position(enemy_key: String, fallback: Vector2) -> Vector2:
	var p = get_flag("dead:" + enemy_key)
	return p if p is Vector2 else fallback


# ── 物品欄 ──
# 格子是陣列，每格是 {} （空）或 {"id": 物品, "count": 數量}。同種物品可以疊到 stack 上限。

static func _empty_inventory(slots: int) -> Array:
	var inv := []
	for i in slots:
		inv.append({})
	return inv


func inventory() -> Array:
	return data.inventory


func inv_count(item_id: String) -> int:
	var total := 0
	for slot in data.inventory:
		if slot.get("id") == item_id:
			total += slot.count
	return total


## 還能再放幾個這種物品
func inv_space_for(item_id: String) -> int:
	var stack: int = Items.get_item(item_id).stack
	var space := 0
	for slot in data.inventory:
		if slot.is_empty():
			space += stack
		elif slot.id == item_id:
			space += stack - slot.count
	return space


## 放進物品欄，回傳實際放進去幾個
func inv_add(item_id: String, count: int) -> int:
	var stack: int = Items.get_item(item_id).stack
	var left := count
	for slot in data.inventory:  # 先疊到已有的格子
		if left > 0 and slot.get("id") == item_id and slot.count < stack:
			var n := mini(left, stack - slot.count)
			slot.count += n
			left -= n
	for i in data.inventory.size():  # 再放進空格
		if left > 0 and data.inventory[i].is_empty():
			var n := mini(left, stack)
			data.inventory[i] = {"id": item_id, "count": n}
			left -= n
	changed.emit()
	return count - left


## 從物品欄拿掉，回傳實際拿掉幾個
func inv_remove(item_id: String, count: int) -> int:
	var left := count
	for i in range(data.inventory.size() - 1, -1, -1):
		var slot: Dictionary = data.inventory[i]
		if left > 0 and slot.get("id") == item_id:
			var n := mini(left, slot.count)
			slot.count -= n
			left -= n
			if slot.count <= 0:
				data.inventory[i] = {}
	changed.emit()
	return count - left


func is_taken(item_id: String) -> bool:
	return has_flag("taken:" + item_id)


func mark_taken(item_id: String) -> void:
	set_flag("taken:" + item_id)


func is_zone_heated(area_id: String, zone: String, default: bool) -> bool:
	return get_flag("heat:%s:%s" % [area_id, zone], default)


func set_zone_heated(area_id: String, zone: String, heated: bool) -> void:
	set_flag("heat:%s:%s" % [area_id, zone], heated)


func emit_event(kind: String, id: String) -> void:
	if id != "":
		game_event.emit(kind, id)


# ── 儲物箱（所有安全屋共用，不限格數）──

func storage() -> Dictionary:
	return data.storage


## 把物品欄某一格整格放進儲物箱
func store_slot(index: int) -> bool:
	var slot: Dictionary = data.inventory[index]
	if slot.is_empty():
		return false
	data.storage[slot.id] = data.storage.get(slot.id, 0) + slot.count
	data.inventory[index] = {}
	changed.emit()
	return true


## 從儲物箱拿出某種物品，能放多少拿多少，回傳拿了幾個
func retrieve(item_id: String) -> int:
	var have: int = data.storage.get(item_id, 0)
	var got := inv_add(item_id, mini(have, inv_space_for(item_id)))
	if got > 0:
		data.storage[item_id] = have - got
		if data.storage[item_id] <= 0:
			data.storage.erase(item_id)
		changed.emit()
	return got


# ── 存檔 ──

func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## 存到硬碟（Vector2 等 Godot 型別用 store_var 保存）
func save_to_disk() -> bool:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("存檔失敗：%s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_var({"version": SAVE_VERSION, "data": data})
	return true


func load_from_disk() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	var saved = f.get_var()
	if not (saved is Dictionary and saved.has("data")):
		return false
	data = _migrate(saved.data)
	_checkpoint = data.duplicate(true)
	changed.emit()
	return true


## 舊版存檔缺少的欄位補上預設值（之後加新欄位時在這裡處理）
func _migrate(old: Dictionary) -> Dictionary:
	var fresh := {
		"inventory": _empty_inventory(START_SLOTS),
		"health": MAX_HEALTH,
		"infection": 0.0,
		"loaded": {"pistol": 0, "shotgun": 0},
		"equipped": "pistol",
		"access_level": 0,
		"carrying": "",
		"storage": {},
		"flags": {},
		"ready_throw": "bottle",
		"extinguisher": 0,
		"body_temp": MAX_BODY_TEMP,
		"enemies": {},
		"codex": {},
		"quick_item": "light",
		"gear": Gear.START_EQUIPPED.duplicate(),
		"gear_owned": Gear.START_OWNED.duplicate(),
		"explored": {},
	}
	if old.has("pistol_loaded") and not old.has("loaded"):
		old["loaded"] = {"pistol": old.pistol_loaded, "shotgun": 0}
		old.erase("pistol_loaded")
	for key in fresh:
		if not old.has(key):
			old[key] = fresh[key]
	# 物品欄格數變多了：舊存檔補上空格
	while old.inventory.size() < START_SLOTS:
		old.inventory.append({})
	return old


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


# ── 檢查點 ──

## 進入區域時呼叫：記住現在的狀態，被抓到時回到這裡。
func save_checkpoint(area_id: String, entry: String) -> void:
	data.area = area_id
	data.entry = entry
	_checkpoint = data.duplicate(true)


func restore_checkpoint() -> void:
	data = _checkpoint.duplicate(true)
	changed.emit()


func checkpoint_area() -> String:
	return _checkpoint.area


func checkpoint_entry() -> String:
	return _checkpoint.entry


# ── 消音器（裝在手槍上：槍聲傳得近很多）──

func suppressor_on() -> bool:
	return data.get("suppressor", false) and inv_count("suppressor") > 0


func toggle_suppressor() -> bool:
	data["suppressor"] = not data.get("suppressor", false)
	return data.suppressor
